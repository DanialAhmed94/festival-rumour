// HTTPS via Cloud Functions 2nd gen (matches GCP GEN_2 + firebase-functions manifest).
// Firestore comment push lives in `functions_comment/` (codebase comment_push).
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");
const cors = require("cors")({ origin: true });

admin.initializeApp();

// ─────────────────────────────────────────────────────────────────────────────
// SMTP secrets (Hostinger mailbox info@thefestivalapps.com).
// Set with: firebase functions:secrets:set SMTP_HOST  (etc.)
//   SMTP_HOST = smtp.hostinger.com
//   SMTP_PORT = 465        (SSL; use 587 for STARTTLS)
//   SMTP_USER = info@thefestivalapps.com
//   SMTP_PASS = <mailbox password>
// ─────────────────────────────────────────────────────────────────────────────
const SMTP_HOST = defineSecret("SMTP_HOST");
const SMTP_PORT = defineSecret("SMTP_PORT");
const SMTP_USER = defineSecret("SMTP_USER");
const SMTP_PASS = defineSecret("SMTP_PASS");

/** Match existing deployed sizing (Firestore + FCM workloads). */
const httpOptions = {
    region: "us-central1",
    maxInstances: 3,
    memory: "256MiB",
    timeoutSeconds: 60,
};

// ─────────────────────────────────────────────────────────────────────────────
// Referral Reward System
// ─────────────────────────────────────────────────────────────────────────────
const APP_IDENTIFIER = "festivalrumor";
// Unambiguous uppercase alphabet (no 0/O, 1/I/L). 6 chars => ~1.07B combinations.
const CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const CODE_LENGTH = 6;
const REFERRAL_MILESTONE = 25;
const BADGE_TTL_MS = 365 * 24 * 60 * 60 * 1000; // 1 year
// Base URL for invite links. Must match AppStrings.inviteDomainBaseUrl and
// ReferralService.inviteBaseUrl on the client. Hosted on Hostinger (thefestivalapps.com).
const INVITE_BASE_URL = "https://thefestivalapps.com/invite/";

/** Read the verified uid from an "Authorization: Bearer <idToken>" header. Throws on failure. */
async function verifyBearer(req) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
        const err = new Error("Missing or invalid Authorization header");
        err.code = 401;
        throw err;
    }
    const idToken = authHeader.split("Bearer ")[1];
    const decoded = await admin.auth().verifyIdToken(idToken);
    return decoded.uid;
}

/** Mirror of functions_comment getFcmTokensForUser: one token per user, app-gated. */
async function getFcmTokensForUser(uid) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) return [];
    const userData = userDoc.data() || {};
    if (userData.appIdentifier !== APP_IDENTIFIER) return [];
    let token = userData.fcmToken;
    if (!token && Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
        token = userData.fcmTokens[0];
    }
    return token ? [token] : [];
}

/** Best-effort push to a single user. All FCM data values must be strings. */
async function sendFcmToUser(uid, { title, body, data }) {
    try {
        const tokens = [...new Set(await getFcmTokensForUser(uid))];
        if (tokens.length === 0) return { sentCount: 0 };
        const payload = {
            notification: { title, body },
            android: {
                priority: "high",
                notification: {
                    channelId: "chat_messages",
                    priority: "high",
                    sound: "default",
                    icon: "ic_notification",
                    color: "#FC2E95",
                },
            },
            apns: { payload: { aps: { sound: "default", badge: 1 } } },
            data: data || {},
        };
        const resp = await admin.messaging().sendEachForMulticast({ tokens, ...payload });
        return { sentCount: resp.successCount, failedCount: resp.failureCount };
    } catch (e) {
        console.error("[REFERRAL] sendFcmToUser error", uid, e.message);
        return { sentCount: 0, error: e.message };
    }
}

function generateReferralCode() {
    const bytes = crypto.randomBytes(CODE_LENGTH);
    let s = "";
    for (let i = 0; i < CODE_LENGTH; i++) {
        s += CODE_ALPHABET[bytes[i] % CODE_ALPHABET.length];
    }
    return s;
}

/** Sanitize a client-supplied device id into a safe Firestore doc id. Returns null if empty. */
function sanitizeDeviceId(raw) {
    if (!raw || typeof raw !== "string") return null;
    const trimmed = raw.trim();
    if (!trimmed) return null;
    // Hash to a stable, doc-id-safe hex string (avoids "/" and length issues).
    return crypto.createHash("sha256").update(trimmed).digest("hex").slice(0, 40);
}

exports.deleteAuthAccount = onRequest(httpOptions, (req, res) => {
    cors(req, res, async () => {
        try {
            // 🔒 Allow only POST
            if (req.method !== "POST") {
                return res.status(405).json({
                    success: false,
                    error: "Method Not Allowed",
                });
            }

            // 🔑 Read Authorization header
            const authHeader = req.headers.authorization;
            if (!authHeader || !authHeader.startsWith("Bearer ")) {
                return res.status(401).json({
                    success: false,
                    error: "Missing or invalid Authorization header",
                });
            }

            const idToken = authHeader.split("Bearer ")[1];

            // ✅ VERIFY Firebase ID token
            const decodedToken = await admin.auth().verifyIdToken(idToken);
            const uid = decodedToken.uid;

            console.log(`🗑️ Deleting Firebase Auth user: ${uid}`);

            // 🔥 DELETE USER FROM FIREBASE AUTH
            await admin.auth().deleteUser(uid);

            return res.status(200).json({
                success: true,
                message: "User deleted successfully",
            });
        } catch (error) {
            console.error("❌ deleteAuthAccount error:", error);

            return res.status(401).json({
                success: false,
                error: error.message || "Unauthorized",
            });
        }
    });
});

exports.sendNotification = onRequest(httpOptions, (req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                return res.status(405).json({
                    success: false,
                    error: "Method Not Allowed. Use POST with JSON body.",
                });
            }

            const { userIds, title, message, chatRoomId, chatRoomName, festivalId } = req.body;
            console.log("[NOTIF] Function: request received", { userIdsCount: userIds?.length, title, messageLength: message?.length, chatRoomId, chatRoomName, festivalId });

            if (!userIds || !Array.isArray(userIds) || userIds.length === 0) {
                return res.status(400).json({
                    success: false,
                    error: "userIds array is required",
                });
            }

            if (!message) {
                return res.status(400).json({
                    success: false,
                    error: "message is required",
                });
            }

            const uniqueUserIds = [...new Set(userIds)];
            const tokens = [];

            for (const uid of uniqueUserIds) {
                const userDoc = await admin.firestore().collection("users").doc(uid).get();

                if (!userDoc.exists) continue;

                const userData = userDoc.data();

                if (userData.appIdentifier !== "festivalrumor") continue;

                let token = userData.fcmToken;
                if (!token && userData.fcmTokens && Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
                    token = userData.fcmTokens[0];
                }
                if (token) {
                    tokens.push(token);
                }
            }

            const uniqueTokens = [...new Set(tokens)];

            if (uniqueTokens.length === 0) {
                console.log("[NOTIF] Function: no valid FCM tokens found for userIds", uniqueUserIds);
                return res.status(200).json({
                    success: true,
                    message: "No valid FCM tokens found",
                    sentCount: 0,
                });
            }
            console.log("[NOTIF] Function: sending to", uniqueTokens.length, "token(s) (one per user)");

            const notificationTitle = chatRoomName && chatRoomName.trim()
                ? `${chatRoomName.trim()} · ${title || "New Message"}`
                : (title || "New Message");

            const payload = {
                notification: {
                    title: notificationTitle,
                    body: message,
                },
                android: {
                    priority: "high",
                    notification: {
                        channelId: "chat_messages",
                        priority: "high",
                        sound: "default",
                        icon: "ic_notification",
                        color: "#FC2E95",
                    },
                },
                apns: {
                    payload: {
                        aps: {
                            sound: "default",
                            badge: 1,
                        },
                    },
                },
                data: {
                    type: "custom_message",
                    timestamp: Date.now().toString(),
                    ...(chatRoomId ? { chatRoomId: String(chatRoomId) } : {}),
                    ...(festivalId ? { festivalId: String(festivalId) } : {}),
                },
            };

            const response = await admin.messaging().sendEachForMulticast({
                tokens: uniqueTokens,
                ...payload,
            });
            console.log("[NOTIF] Function: FCM result", { sentCount: response.successCount, failedCount: response.failureCount });
            if (response.failureCount > 0) {
                response.responses.forEach((r, i) => {
                    if (!r.success) console.log("[NOTIF] Function: token failed", i, r.error?.message || r.error);
                });
            }

            return res.status(200).json({
                success: true,
                message: "Notifications processed",
                sentCount: response.successCount,
                failedCount: response.failureCount,
            });

        } catch (error) {
            console.error("❌ Error sending notification:", error);

            return res.status(500).json({
                success: false,
                error: error.message,
            });
        }
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// getOrCreateReferralCode — idempotent: returns the caller's referral code,
// generating a collision-checked unique one on first call.
// ─────────────────────────────────────────────────────────────────────────────
exports.getOrCreateReferralCode = onRequest(httpOptions, (req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                return res.status(405).json({ success: false, error: "Method Not Allowed" });
            }
            const uid = await verifyBearer(req);
            const db = admin.firestore();
            const userRef = db.collection("users").doc(uid);

            // Fast path: code already assigned.
            const userSnap = await userRef.get();
            if (userSnap.exists && userSnap.data().referralCode) {
                const code = userSnap.data().referralCode;
                return res.status(200).json({
                    success: true,
                    referralCode: code,
                    inviteUrl: INVITE_BASE_URL + code,
                });
            }

            // Generate a unique code, enforcing uniqueness via referralCodes/{CODE}.
            let finalCode = null;
            for (let attempt = 0; attempt < 6 && !finalCode; attempt++) {
                const candidate = generateReferralCode();
                try {
                    await db.runTransaction(async (t) => {
                        const codeRef = db.collection("referralCodes").doc(candidate);
                        const codeSnap = await t.get(codeRef);
                        if (codeSnap.exists) throw new Error("COLLISION");
                        const uSnap = await t.get(userRef);
                        if (uSnap.exists && uSnap.data().referralCode) {
                            // Assigned by a concurrent call — use that one.
                            finalCode = uSnap.data().referralCode;
                            return;
                        }
                        const now = admin.firestore.Timestamp.now();
                        t.set(codeRef, { uid, createdAt: now });
                        t.set(userRef, { referralCode: candidate, updatedAt: now }, { merge: true });
                        finalCode = candidate;
                    });
                } catch (e) {
                    if (e.message === "COLLISION") continue;
                    throw e;
                }
            }

            if (!finalCode) {
                return res.status(500).json({ success: false, error: "CODE_GENERATION_FAILED" });
            }
            return res.status(200).json({
                success: true,
                referralCode: finalCode,
                inviteUrl: INVITE_BASE_URL + finalCode,
            });
        } catch (error) {
            console.error("❌ getOrCreateReferralCode error:", error);
            return res.status(error.code === 401 ? 401 : 500).json({
                success: false,
                error: error.message || "Unauthorized",
            });
        }
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// redeemReferral — credits a referrer when a new user submits their code.
// Server is the source of truth (rules are spoofable). Anti-fraud: self-referral
// block, one-per-account (referrals/{callerUid} doc id), device dedupe.
// Grants the 1-year Pioneer badge atomically at the 25-referral milestone.
// ─────────────────────────────────────────────────────────────────────────────
exports.redeemReferral = onRequest(httpOptions, (req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                return res.status(405).json({ success: false, error: "Method Not Allowed" });
            }
            const callerUid = await verifyBearer(req);
            const db = admin.firestore();

            const rawCode = (req.body && req.body.code) || "";
            const code = String(rawCode).trim().toUpperCase();
            if (!code) {
                return res.status(400).json({ success: false, error: "MISSING_CODE" });
            }
            const deviceId = sanitizeDeviceId(req.body && req.body.deviceId);

            // Resolve code -> referrer (codes are immutable, so a plain read is safe).
            const codeSnap = await db.collection("referralCodes").doc(code).get();
            if (!codeSnap.exists) {
                return res.status(400).json({ success: false, error: "INVALID_CODE" });
            }
            const referrerId = codeSnap.data().uid;
            if (referrerId === callerUid) {
                return res.status(400).json({ success: false, error: "SELF_REFERRAL" });
            }

            const result = await db.runTransaction(async (t) => {
                // ── READS ──
                const callerReferralRef = db.collection("referrals").doc(callerUid);
                const callerReferralSnap = await t.get(callerReferralRef);
                const callerUserRef = db.collection("users").doc(callerUid);
                const callerUserSnap = await t.get(callerUserRef);

                if (callerReferralSnap.exists ||
                    (callerUserSnap.exists && callerUserSnap.data().referredBy)) {
                    return { alreadyRedeemed: true };
                }

                const referrerRef = db.collection("users").doc(referrerId);
                const referrerSnap = await t.get(referrerRef);
                if (!referrerSnap.exists) {
                    return { error: "INVALID_CODE" };
                }

                let deviceRef = null;
                if (deviceId) {
                    deviceRef = db.collection("referralDevices").doc(deviceId);
                    const deviceSnap = await t.get(deviceRef);
                    if (deviceSnap.exists && deviceSnap.data().referredUid !== callerUid) {
                        return { error: "DEVICE_ALREADY_USED" };
                    }
                }

                // ── COMPUTE ──
                const referrerData = referrerSnap.data() || {};
                const currentCount = referrerData.referralCount || 0;
                const newCount = currentCount + 1;
                const now = admin.firestore.Timestamp.now();
                const hasBadge = referrerData.pioneerBadge && referrerData.pioneerBadge.earnedAt;
                let badgeGranted = false;

                // ── WRITES ──
                t.create(callerReferralRef, {
                    referrerId,
                    referredUid: callerUid,
                    code,
                    createdAt: now,
                    status: "credited",
                    deviceId: deviceId || null,
                });
                if (deviceRef) {
                    t.set(deviceRef, { referredUid: callerUid, createdAt: now });
                }
                t.set(callerUserRef, { referredBy: referrerId, updatedAt: now }, { merge: true });

                const referrerUpdate = {
                    referralCount: admin.firestore.FieldValue.increment(1),
                    updatedAt: now,
                };
                if (newCount >= REFERRAL_MILESTONE && !hasBadge) {
                    referrerUpdate.pioneerBadge = {
                        earnedAt: now,
                        expiresAt: admin.firestore.Timestamp.fromMillis(now.toMillis() + BADGE_TTL_MS),
                        active: true,
                    };
                    badgeGranted = true;
                }
                t.set(referrerRef, referrerUpdate, { merge: true });

                return { credited: true, referrerId, newCount, badgeGranted };
            });

            if (result.alreadyRedeemed) {
                return res.status(200).json({ success: true, alreadyRedeemed: true });
            }
            if (result.error) {
                return res.status(400).json({ success: false, error: result.error });
            }

            // Best-effort notifications (after commit; failures never roll back the credit).
            try {
                const callerDoc = await db.collection("users").doc(callerUid).get();
                const referredName =
                    (callerDoc.exists && callerDoc.data().displayName) || "Someone";
                await sendFcmToUser(referrerId, {
                    title: "New referral 🎉",
                    body: `${referredName} joined using your invite code`,
                    data: {
                        type: "referral_joined",
                        referredUid: String(callerUid),
                        referredName: String(referredName),
                        referralCount: String(result.newCount),
                        timestamp: Date.now().toString(),
                    },
                });
                if (result.badgeGranted) {
                    const now = admin.firestore.Timestamp.now();
                    await sendFcmToUser(referrerId, {
                        title: "1-Year Pioneer Badge unlocked 🏆",
                        body: "You've referred 25 people! Your Pioneer badge is active and premium features are unlocked.",
                        data: {
                            type: "badge_earned",
                            badge: "pioneer",
                            earnedAt: now.toMillis().toString(),
                            expiresAt: (now.toMillis() + BADGE_TTL_MS).toString(),
                            timestamp: Date.now().toString(),
                        },
                    });
                }
            } catch (notifyErr) {
                console.error("[REFERRAL] notify error:", notifyErr.message);
            }

            return res.status(200).json({
                success: true,
                referrerId: result.referrerId,
                referralCount: result.newCount,
                badgeGranted: result.badgeGranted,
            });
        } catch (error) {
            console.error("❌ redeemReferral error:", error);
            return res.status(error.code === 401 ? 401 : 500).json({
                success: false,
                error: error.message || "Unauthorized",
            });
        }
    });
});

// ─────────────────────────────────────────────────────────────────────────────
// expirePioneerBadges — daily sweep flipping active:false on expired badges.
// Secondary to the client's on-read expiry check (which is authoritative).
// Requires the users (pioneerBadge.active ASC + pioneerBadge.expiresAt ASC) index.
// ─────────────────────────────────────────────────────────────────────────────
exports.expirePioneerBadges = onSchedule(
    {
        schedule: "every 24 hours",
        region: "us-central1",
        timeZone: "Etc/UTC",
        memory: "256MiB",
    },
    async () => {
        const db = admin.firestore();
        const now = admin.firestore.Timestamp.now();
        let processed = 0;
        // Paginate in batches; re-query each loop since updated docs leave the result set.
        // eslint-disable-next-line no-constant-condition
        while (true) {
            const snap = await db
                .collection("users")
                .where("pioneerBadge.active", "==", true)
                .where("pioneerBadge.expiresAt", "<=", now)
                .limit(400)
                .get();
            if (snap.empty) break;
            const batch = db.batch();
            snap.docs.forEach((d) => batch.update(d.ref, { "pioneerBadge.active": false }));
            await batch.commit();
            processed += snap.size;
            if (snap.size < 400) break;
        }
        console.log(`[REFERRAL] expirePioneerBadges: deactivated ${processed} badge(s)`);
        return null;
    },
);

// ─────────────────────────────────────────────────────────────────────────────
// Festival Organiser invite email (Create Post → "Tag Festival Organiser")
// ─────────────────────────────────────────────────────────────────────────────

/** Our family of apps, used to build the invite email body. */
const FESTIVAL_APPS = [
    {
        name: "The Festival App",
        android: "https://play.google.com/store/apps/details?id=com.festival_rumour",
        ios: "https://apps.apple.com/us/app/the-festival-app/id6753773348",
    },
    {
        name: "Festival Organiser",
        android: "https://play.google.com/store/apps/details?id=com.crapadviser.orgnaizer",
        ios: "https://apps.apple.com/us/app/festival-organiser/id6686404949",
    },
    {
        name: "Festival Toilet",
        android: "https://play.google.com/store/apps/details?id=com.crapadviser.user",
        ios: "https://apps.apple.com/us/app/festival-toilet-app/id6738211790",
    },
    {
        name: "Festival Foodie",
        android: "https://play.google.com/store/apps/details?id=com.festiefoodie.app",
        ios: "https://apps.apple.com/us/app/festival-foodie/id6744639737",
    },
];

const ORGANISER_INVITE_FROM_NAME = "The Festival App";
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Minimal HTML escape so user-supplied names can't inject markup. */
function escapeHtml(str) {
    return String(str || "")
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

/** Build the plain-text + HTML bodies for the organiser invite email. */
function buildOrganiserInviteEmail({ inviterName, festivalName }) {
    const who = inviterName && inviterName.trim() ? inviterName.trim() : "A user";
    const festivalLine = festivalName && festivalName.trim()
        ? ` for ${festivalName.trim()}`
        : "";

    const featured = FESTIVAL_APPS.slice(0, 2); // The Festival App + Festival Organiser
    const suite = FESTIVAL_APPS.slice(2); // Festival Toilet + Festival Foodie

    // ── Plain text ──
    const textApp = (a) => `${a.name}\n  • Android: ${a.android}\n  • iOS: ${a.ios}`;
    const text = [
        "Hello,",
        "",
        "We're the team behind The Festival App — a platform that connects festival-goers, organisers and vendors, helping fans discover festivals, follow line-ups and live buzz, and chat with other attendees.",
        "",
        `${who} on our platform${festivalLine} has asked you to register and join us as a festival organiser.`,
        "",
        "Get started with these apps:",
        "",
        featured.map(textApp).join("\n\n"),
        "",
        "We also build a whole suite of apps to make festivals easier for everyone:",
        "",
        suite.map(textApp).join("\n\n"),
        "",
        "We'd love to have you on board.",
        "",
        "— The Festival App team",
        "info@thefestivalapps.com",
    ].join("\n");

    // ── HTML ──
    const htmlApp = (a) => `
        <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;width:100%;">
          <tr><td style="font-size:15px;font-weight:600;color:#1a1a1a;padding-bottom:6px;">${escapeHtml(a.name)}</td></tr>
          <tr><td style="font-size:14px;color:#444;line-height:1.6;">
            📱 <a href="${a.android}" style="color:#FC2E95;text-decoration:none;">Download on Google Play</a><br/>
            🍎 <a href="${a.ios}" style="color:#FC2E95;text-decoration:none;">Download on the App Store</a>
          </td></tr>
        </table>`;

    const html = `
    <div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#1a1a1a;">
      <h2 style="margin:0 0 16px 0;font-size:20px;">Hello,</h2>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 16px 0;">
        We're the team behind <strong>The Festival App</strong> — a platform that connects
        festival-goers, organisers and vendors, helping fans discover festivals, follow
        line-ups and live buzz, and chat with other attendees.
      </p>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 24px 0;">
        <strong>${escapeHtml(who)}</strong> on our platform${escapeHtml(festivalLine)} has asked you to
        register and join us as a festival organiser.
      </p>
      <p style="font-size:15px;font-weight:600;color:#1a1a1a;margin:0 0 12px 0;">Get started with these apps:</p>
      ${featured.map(htmlApp).join("")}
      <p style="font-size:15px;line-height:1.6;color:#333;margin:8px 0 12px 0;">
        We also build a whole suite of apps to make festivals easier for everyone:
      </p>
      ${suite.map(htmlApp).join("")}
      <p style="font-size:15px;line-height:1.6;color:#333;margin:16px 0 0 0;">We'd love to have you on board.</p>
      <p style="font-size:14px;color:#888;margin:24px 0 0 0;">— The Festival App team<br/>
        <a href="mailto:info@thefestivalapps.com" style="color:#FC2E95;text-decoration:none;">info@thefestivalapps.com</a>
      </p>
    </div>`;

    return { text, html };
}

/**
 * Build the plain-text + HTML bodies for the "list your festival" invite — sent
 * when a user searches a festival that isn't listed yet and invites its organiser.
 * Leads with the Festival Organiser app (where they list/manage festivals), then
 * the rest of the suite.
 */
function buildListingInviteEmail({ festivalName, inviterName }) {
    const festival = festivalName && festivalName.trim()
        ? `"${festivalName.trim()}"`
        : "your festival";
    const who = inviterName && inviterName.trim() ? inviterName.trim() : "A user";

    const organiser = FESTIVAL_APPS[1]; // Festival Organiser
    const suite = [FESTIVAL_APPS[0], FESTIVAL_APPS[2], FESTIVAL_APPS[3]]; // The Festival App, Toilet, Foodie

    // ── Plain text ──
    const textApp = (a) => `${a.name}\n  • Android: ${a.android}\n  • iOS: ${a.ios}`;
    const text = [
        "Hello,",
        "",
        "We're the team behind The Festival App — a platform that helps festival-goers discover festivals, follow line-ups and live buzz, and chat with other attendees.",
        "",
        `${who} on our platform wants you to list ${festival} in The Festival App.`,
        "",
        "You can list and manage your festival with the Festival Organiser app:",
        "",
        textApp(organiser),
        "",
        "We also build a whole suite of apps to make festivals easier for everyone:",
        "",
        suite.map(textApp).join("\n\n"),
        "",
        "We'd love to see your festival on the platform.",
        "",
        "— The Festival App team",
        "info@thefestivalapps.com",
    ].join("\n");

    // ── HTML ──
    const htmlApp = (a) => `
        <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;width:100%;">
          <tr><td style="font-size:15px;font-weight:600;color:#1a1a1a;padding-bottom:6px;">${escapeHtml(a.name)}</td></tr>
          <tr><td style="font-size:14px;color:#444;line-height:1.6;">
            📱 <a href="${a.android}" style="color:#FC2E95;text-decoration:none;">Download on Google Play</a><br/>
            🍎 <a href="${a.ios}" style="color:#FC2E95;text-decoration:none;">Download on the App Store</a>
          </td></tr>
        </table>`;

    const html = `
    <div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#1a1a1a;">
      <h2 style="margin:0 0 16px 0;font-size:20px;">Hello,</h2>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 16px 0;">
        We're the team behind <strong>The Festival App</strong> — a platform that helps
        festival-goers discover festivals, follow line-ups and live buzz, and chat with
        other attendees.
      </p>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 24px 0;">
        <strong>${escapeHtml(who)}</strong> on our platform wants you to list <strong>${escapeHtml(festival)}</strong> in The Festival App.
      </p>
      <p style="font-size:15px;font-weight:600;color:#1a1a1a;margin:0 0 12px 0;">List and manage your festival with the Festival Organiser app:</p>
      ${htmlApp(organiser)}
      <p style="font-size:15px;line-height:1.6;color:#333;margin:8px 0 12px 0;">
        We also build a whole suite of apps to make festivals easier for everyone:
      </p>
      ${suite.map(htmlApp).join("")}
      <p style="font-size:15px;line-height:1.6;color:#333;margin:16px 0 0 0;">We'd love to see your festival on the platform.</p>
      <p style="font-size:14px;color:#888;margin:24px 0 0 0;">— The Festival App team<br/>
        <a href="mailto:info@thefestivalapps.com" style="color:#FC2E95;text-decoration:none;">info@thefestivalapps.com</a>
      </p>
    </div>`;

    return { text, html };
}

/**
 * Sends an invite email to a festival organiser.
 * Authenticated (Firebase ID token). Body: { organiserEmail, inviterName?, festivalName?, inviteType? }.
 * inviteType "listing" → "list your festival" email (search → not found);
 * anything else → the default "register / join us" invite (Create Post tag).
 */
exports.sendOrganiserInvite = onRequest(
    { ...httpOptions, secrets: [SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS] },
    (req, res) => {
        cors(req, res, async () => {
            try {
                if (req.method !== "POST") {
                    return res.status(405).json({ success: false, error: "Method Not Allowed" });
                }

                // Require a logged-in caller (mirrors the other endpoints).
                await verifyBearer(req);

                const body = req.body || {};
                const organiserEmail = String(body.organiserEmail || "").trim();
                if (!EMAIL_RE.test(organiserEmail)) {
                    return res.status(400).json({ success: false, error: "Invalid organiser email" });
                }

                const host = process.env.SMTP_HOST;
                const user = process.env.SMTP_USER;
                const pass = process.env.SMTP_PASS;
                const port = parseInt(process.env.SMTP_PORT || "465", 10);
                if (!host || !user || !pass) {
                    console.error("❌ sendOrganiserInvite: SMTP secrets not configured");
                    return res.status(500).json({ success: false, error: "Email service not configured" });
                }

                const transporter = nodemailer.createTransport({
                    host,
                    port,
                    secure: port === 465, // 465 = implicit SSL, 587 = STARTTLS
                    auth: { user, pass },
                });

                const isListing = String(body.inviteType || "") === "listing";
                const inviter = String(body.inviterName || "").trim();
                const festival = String(body.festivalName || "").trim();
                const { text, html } = isListing
                    ? buildListingInviteEmail({ festivalName: festival, inviterName: inviter })
                    : buildOrganiserInviteEmail({
                        inviterName: inviter,
                        festivalName: festival,
                    });

                // Listing subject carries the searched festival name + the requester's name.
                const listingSubject =
                    `${inviter || "A user"} wants to list ${festival ? `"${festival}"` : "a festival"} on The Festival App`;

                await transporter.sendMail({
                    from: `"${ORGANISER_INVITE_FROM_NAME}" <${user}>`,
                    to: organiserEmail,
                    subject: isListing
                        ? listingSubject
                        : "You're invited to join The Festival App",
                    text,
                    html,
                });

                console.log(`✉️ sendOrganiserInvite (${isListing ? "listing" : "register"}): invite sent to ${organiserEmail}`);
                return res.status(200).json({ success: true, message: "Invite email sent" });
            } catch (error) {
                console.error("❌ sendOrganiserInvite error:", error);
                return res.status(error.code === 401 ? 401 : 500).json({
                    success: false,
                    error: error.message || "Failed to send invite",
                });
            }
        });
    },
);

// ─────────────────────────────────────────────────────────────────────────────
// Welcome email for new users (fires once when users/{uid} is first created —
// covers email signup, Google and Apple, all of which funnel through
// FirestoreService.saveUserData(). Returning logins only update an existing doc,
// so they never re-trigger.)
// ─────────────────────────────────────────────────────────────────────────────

const WELCOME_EMAIL_FROM_NAME = "The Festival App";

/** Build the plain-text + HTML bodies for the new-user welcome email. */
function buildWelcomeEmail({ displayName }) {
    const name = displayName && String(displayName).trim()
        ? String(displayName).trim()
        : "there";

    const textApp = (a) => `${a.name}\n  • Android: ${a.android}\n  • iOS: ${a.ios}`;
    const text = [
        `Hey ${name}! 🎉🎪`,
        "",
        "Thanks for downloading The Festival App and joining our community of early starters — you're a true pioneer! 🚀",
        "",
        "Our apps are crowd-driven and built for you, the festival community. Come along for the ride and help shape the app into exactly what you want — the infrastructure is built in, just waiting for your input. 🛠️✨",
        "",
        "We're a tiny crew of festival veterans chasing the true festival spirit — old-school ethic meets modern tech — and we're gonna need a little help. 🤝🎶",
        "",
        "We can't offer much in return, but pioneers get perks 🎁 — just invite 25 festie besties to download the app to earn your Pioneer badge! 💌",
        "",
        "Explore our suite of festival apps 👇",
        "",
        FESTIVAL_APPS.map(textApp).join("\n\n"),
        "",
        "See you in the crowd 🎶",
        "— The Festival App team",
        "info@thefestivalapps.com",
    ].join("\n");

    const htmlApp = (a) => `
        <table role="presentation" cellpadding="0" cellspacing="0" style="margin:0 0 16px 0;width:100%;">
          <tr><td style="font-size:15px;font-weight:600;color:#1a1a1a;padding-bottom:6px;">${escapeHtml(a.name)}</td></tr>
          <tr><td style="font-size:14px;color:#444;line-height:1.6;">
            📱 <a href="${a.android}" style="color:#FC2E95;text-decoration:none;">Download on Google Play</a><br/>
            🍎 <a href="${a.ios}" style="color:#FC2E95;text-decoration:none;">Download on the App Store</a>
          </td></tr>
        </table>`;

    const html = `
    <div style="font-family:-apple-system,Segoe UI,Roboto,Helvetica,Arial,sans-serif;max-width:560px;margin:0 auto;padding:24px;color:#1a1a1a;">
      <h2 style="margin:0 0 16px 0;font-size:20px;">Hey ${escapeHtml(name)}! 🎉🎪</h2>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 16px 0;">
        Thanks for downloading <strong>The Festival App</strong> and joining our community of early starters — you're a true <strong>pioneer</strong>! 🚀
      </p>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 16px 0;">
        Our apps are crowd-driven and built for you, the festival community. Come along for the ride and help shape the app into exactly what you want — the infrastructure is built in, just waiting for your input. 🛠️✨
      </p>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 16px 0;">
        We're a tiny crew of festival veterans chasing the true festival spirit — old-school ethic meets modern tech — and we're gonna need a little help. 🤝🎶
      </p>
      <p style="font-size:15px;line-height:1.6;color:#333;margin:0 0 24px 0;">
        We can't offer much in return, but pioneers get perks 🎁 — just invite <strong>25 festie besties</strong> to download the app to earn your Pioneer badge! 💌
      </p>
      <p style="font-size:15px;font-weight:600;color:#1a1a1a;margin:0 0 12px 0;">Explore our suite of festival apps 👇</p>
      ${FESTIVAL_APPS.map(htmlApp).join("")}
      <p style="font-size:15px;line-height:1.6;color:#333;margin:16px 0 0 0;">See you in the crowd 🎶</p>
      <p style="font-size:14px;color:#888;margin:8px 0 0 0;">— The Festival App team<br/>
        <a href="mailto:info@thefestivalapps.com" style="color:#FC2E95;text-decoration:none;">info@thefestivalapps.com</a>
      </p>
    </div>`;

    return { text, html };
}

/**
 * Sends the welcome / greeting email. Authenticated (Firebase ID token).
 * The client calls this after a successful Google or Apple sign-in (every time)
 * and once after a new email/password signup. The recipient address is taken
 * from the verified account (admin.auth().getUser) — never from the request —
 * so a caller can only ever email themselves. Optional body: { displayName }.
 */
exports.sendWelcomeEmail = onRequest(
    { ...httpOptions, secrets: [SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS] },
    (req, res) => {
        cors(req, res, async () => {
            try {
                if (req.method !== "POST") {
                    return res.status(405).json({ success: false, error: "Method Not Allowed" });
                }

                const uid = await verifyBearer(req);
                const userRecord = await admin.auth().getUser(uid);
                const to = String(userRecord.email || "").trim();
                if (!EMAIL_RE.test(to)) {
                    return res.status(400).json({ success: false, error: "No email on account" });
                }

                const host = process.env.SMTP_HOST;
                const user = process.env.SMTP_USER;
                const pass = process.env.SMTP_PASS;
                const port = parseInt(process.env.SMTP_PORT || "465", 10);
                if (!host || !user || !pass) {
                    console.error("❌ sendWelcomeEmail: SMTP secrets not configured");
                    return res.status(500).json({ success: false, error: "Email service not configured" });
                }

                const transporter = nodemailer.createTransport({
                    host,
                    port,
                    secure: port === 465, // 465 = implicit SSL, 587 = STARTTLS
                    auth: { user, pass },
                });

                const body = req.body || {};
                const displayName = (body.displayName && String(body.displayName).trim())
                    ? String(body.displayName).trim()
                    : userRecord.displayName;

                const { text, html } = buildWelcomeEmail({ displayName });

                await transporter.sendMail({
                    from: `"${WELCOME_EMAIL_FROM_NAME}" <${user}>`,
                    to,
                    subject: "🎉 Welcome to The Festival App — you're a pioneer!",
                    text,
                    html,
                });

                console.log(`✉️ sendWelcomeEmail: welcome email sent to ${to} (${uid})`);
                return res.status(200).json({ success: true, message: "Welcome email sent" });
            } catch (error) {
                console.error("❌ sendWelcomeEmail error:", error);
                return res.status(error.code === 401 ? 401 : 500).json({
                    success: false,
                    error: error.message || "Failed to send welcome email",
                });
            }
        });
    },
);
