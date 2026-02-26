const functions = require("firebase-functions");
const admin = require("firebase-admin");
const cors = require("cors")({ origin: true });

admin.initializeApp();

exports.deleteAuthAccount = functions.https.onRequest((req, res) => {
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

exports.sendNotification = functions.https.onRequest((req, res) => {
    cors(req, res, async () => {
        try {
            if (req.method !== "POST") {
                return res.status(405).json({
                    success: false,
                    error: "Method Not Allowed. Use POST with JSON body.",
                });
            }

            const { userIds, title, message, chatRoomId, chatRoomName } = req.body;
            console.log("[NOTIF] Function: request received", { userIdsCount: userIds?.length, title, messageLength: message?.length, chatRoomId, chatRoomName });

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

            // One notification per user: dedupe so same user is never processed twice (avoids duplicate pushes when client/room has duplicate member ids).
            const uniqueUserIds = [...new Set(userIds)];

            const tokens = [];

            // 🔥 Fetch one token per user from Firestore (one FCM send per user)
            for (const uid of uniqueUserIds) {
                const userDoc = await admin.firestore().collection("users").doc(uid).get();

                if (!userDoc.exists) continue;

                const userData = userDoc.data();

                // ✅ Check correct app
                if (userData.appIdentifier !== "festivalrumor") continue;

                // ✅ Check token: fcmToken (string) or fcmTokens (array) — take at most one token per user
                let token = userData.fcmToken;
                if (!token && userData.fcmTokens && Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
                    token = userData.fcmTokens[0];
                }
                if (token) {
                    tokens.push(token);
                }
            }

            // Dedupe tokens so the same device never gets the same notification twice (e.g. same token stored in fcmToken and fcmTokens[0], or duplicate userIds before uniqueUserIds).
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
                },
            };

            // 🔥 Send one message per token (each recipient gets exactly one notification)
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
