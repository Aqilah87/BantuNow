// functions/index.js

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// ✅ Trigger bila ada post bantuan baru (Firebase Functions v2)
exports.notifyAvailableHelpers = onDocumentCreated(
    "bantuan/{docId}",
    async (event) => {
      const data = event.data.data();

      // Hanya proses kalau jenis 'request'
      if (data.type !== "request") return null;

      const areaId = data.area_id;
      const title = data.title;
      const area = data.area;
      const category = data.category;
      const docId = event.params.docId;

      if (!areaId) return null;

      try {
        // Cari semua helper yang available dalam kawasan sama
        const helpersSnap = await admin.firestore()
            .collection("users")
            .where("availability_status", "==", "available")
            .where("area_id", "==", areaId)
            .get();

        if (helpersSnap.empty) {
          console.log("Tiada helper available dalam kawasan:", areaId);
          return null;
        }

        // Kumpul FCM tokens
        const tokens = [];
        helpersSnap.forEach((doc) => {
          const fcmToken = doc.data().fcm_token;
          const uid = doc.id;
          if (fcmToken && uid !== data.posted_by_uid) {
            tokens.push(fcmToken);
          }
        });

        if (tokens.length === 0) {
          console.log("Tiada token FCM untuk dihantar");
          return null;
        }

        // Hantar notification
        const message = {
          notification: {
            title: "🙋 Request Bantuan Baru!",
            body: `${title} — ${area}`,
          },
          data: {
            type: "new_request",
            post_id: docId,
            area_id: areaId,
            category: category ?? "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          tokens: tokens,
        };

        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Notification: ${response.successCount} berjaya, ${response.failureCount} gagal`);

        return null;
      } catch (error) {
        console.error("Error:", error);
        return null;
      }
    }
);