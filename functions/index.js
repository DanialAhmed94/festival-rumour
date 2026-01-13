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
