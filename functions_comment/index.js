/**
 * Firestore comment notifications (Cloud Functions 2nd gen).
 * Uses v2 Firestore triggers so deploy works with firebase-functions v6 (avoids Gen1 CPU manifest errors).
 */
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

/**
 * @param {string} uid
 * @returns {Promise<string[]>}
 */
async function getFcmTokensForUser(uid) {
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) return [];
    const userData = userDoc.data() || {};
    if (userData.appIdentifier !== "festivalrumor") return [];
    let token = userData.fcmToken;
    if (!token && userData.fcmTokens && Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
        token = userData.fcmTokens[0];
    }
    return token ? [token] : [];
}

/**
 * Notification rules (single recipient per new comment doc):
 * - Top-level comment (no parent): notify the POST owner only — Facebook-style.
 * - Reply (has parentCommentId): notify the PARENT COMMENT author only — Instagram-style.
 * Post owner is not notified for replies (unless they authored the parent comment).
 */
exports.onCommentCreated = onDocumentCreated(
    {
        document: "{collectionId}/{postId}/comments/{commentId}",
        region: "us-central1",
    },
    async (event) => {
        const snap = event.data;
        if (!snap) {
            console.log("[NOTIF] onCommentCreated: no snapshot data, skip");
            return null;
        }

        const comment = snap.data() || {};
        const { collectionId, postId } = event.params;
        const authorId = comment.userId;
        const username = comment.username || "Someone";
        const rawParent = comment.parentCommentId;
        const parentCommentId =
            rawParent != null && String(rawParent).trim() !== ""
                ? String(rawParent).trim()
                : null;
        const isReply = parentCommentId != null;

        if (!authorId) {
            console.log("[NOTIF] onCommentCreated: no userId, skip");
            return null;
        }

        const postRef = admin.firestore().collection(collectionId).doc(postId);
        const postSnap = await postRef.get();
        if (!postSnap.exists) {
            console.log("[NOTIF] onCommentCreated: post missing", collectionId, postId);
            return null;
        }
        const post = postSnap.data() || {};
        const postOwnerId = post.userId;
        if (!postOwnerId) {
            console.log("[NOTIF] onCommentCreated: post has no userId, skip");
            return null;
        }

        let recipientId = null;
        let notifType = "post_comment";
        let title = "New comment";
        let body = `${username} commented on your post`;
        let dataParentCommentId = "";

        if (isReply) {
            notifType = "comment_reply";
            title = "New reply";
            body = `${username} replied to your comment`;
            dataParentCommentId = parentCommentId;
            const parentSnap = await postRef.collection("comments").doc(parentCommentId).get();
            if (!parentSnap.exists) {
                console.log("[NOTIF] onCommentCreated: parent missing", parentCommentId);
                return null;
            }
            const parent = parentSnap.data() || {};
            const parentAuthorId = parent.userId;
            if (!parentAuthorId) {
                console.log("[NOTIF] onCommentCreated: parent has no userId");
                return null;
            }
            recipientId = parentAuthorId;
        } else {
            recipientId = postOwnerId;
        }

        if (!recipientId || recipientId === authorId) {
            console.log("[NOTIF] onCommentCreated: skip self or no recipient");
            return null;
        }

        const tokenList = await getFcmTokensForUser(recipientId);
        const uniqueTokens = [...new Set(tokenList)];
        if (uniqueTokens.length === 0) {
            console.log("[NOTIF] onCommentCreated: no FCM token for recipient", recipientId);
            return null;
        }

        const payload = {
            notification: {
                title,
                body,
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
                type: notifType,
                postId: String(postId),
                collectionName: String(collectionId),
                parentCommentId: dataParentCommentId,
                timestamp: Date.now().toString(),
            },
        };

        const response = await admin.messaging().sendEachForMulticast({
            tokens: uniqueTokens,
            ...payload,
        });
        console.log("[NOTIF] onCommentCreated", {
            notifType,
            recipientKind: isReply ? "parent_comment_author" : "post_owner",
            sentCount: response.successCount,
            failedCount: response.failureCount,
        });
        return null;
    },
);
