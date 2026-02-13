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

            const { userIds, title, message } = req.body;

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

            const tokens = [];

            // 🔥 Fetch users from Firestore
            for (const uid of userIds) {
                const userDoc = await admin.firestore().collection("users").doc(uid).get();

                if (!userDoc.exists) continue;

                const userData = userDoc.data();

                // ✅ Check correct app
                if (userData.appIdentifier !== "festivalrumor") continue;

                // ✅ Check token exists
                if (userData.fcmToken) {
                    tokens.push(userData.fcmToken);
                }
            }

            if (tokens.length === 0) {
                return res.status(200).json({
                    success: true,
                    message: "No valid FCM tokens found",
                    sentCount: 0,
                });
            }

            const payload = {
                notification: {
                    title: title || "New Message",
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
                },
            };

            // 🔥 Send to multiple tokens
            const response = await admin.messaging().sendEachForMulticast({
                tokens: tokens,
                ...payload,
            });

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
