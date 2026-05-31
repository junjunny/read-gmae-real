const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// 아기자기한 랜덤 주제 풀
const TOPICS = [
  "자고 있는 연인의 모습을 그려줘",
  "지금 생각나는 동물 그리기",
  "오늘 먹은 음식 그리기",
  "서로의 첫인상 그리기",
  "오늘의 기분을 색으로 표현하기",
  "10년 뒤 우리의 모습",
  "지금 입고 있는 옷 그리기",
  "가장 좋아하는 우리의 추억",
  "오늘 하늘 그리기",
  "상대에게 주고 싶은 선물",
];

function todayKST() {
  const now = new Date(Date.now() + 9 * 3600 * 1000); // UTC+9
  return now.toISOString().slice(0, 10); // yyyy-MM-dd
}

// 날짜 문자열 → 결정적 인덱스 (커플마다 같은 날 같은 주제 동기화)
function topicForDate(dateStr, salt) {
  let h = 0;
  const s = dateStr + salt;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
  return TOPICS[h % TOPICS.length];
}

/** 매일 오전 8시(KST) 모든 커플에게 그날의 주제 기록 + 푸시 */
exports.dailyTopic = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Asia/Seoul" },
  async () => {
    const date = todayKST();
    const couples = await db.collection("couples").get();
    const batch = db.batch();

    for (const c of couples.docs) {
      const topic = topicForDate(date, c.id);
      batch.set(c.ref.collection("dailyTopics").doc(date), {
        topic,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // FCM 푸시 (topic 구독 기반)
    await messaging.send({
      topic: "daily",
      notification: {
        title: "🎨 오늘의 그림 주제 도착!",
        body: "지금 열어서 오늘의 미션을 확인해보세요.",
      },
    });
  }
);

/** 상대가 그림을 보내면 푸시 알림 (위젯은 클라이언트 리스너가 갱신) */
exports.onNewDrawing = onDocumentCreated(
  "couples/{coupleId}/drawings/{drawingId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    // 보낸 사람 제외 상대에게 알림: 멤버 토큰 조회 후 전송
    const coupleId = event.params.coupleId;
    const couple = await db.collection("couples").doc(coupleId).get();
    const members = (couple.data()?.members || []).filter((u) => u !== data.authorUid);

    const tokens = [];
    for (const uid of members) {
      const u = await db.collection("users").doc(uid).get();
      const t = u.data()?.fcmToken;
      if (t) tokens.push(t);
    }
    if (tokens.length === 0) return;

    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: `💌 ${data.authorName}님이 그림을 보냈어요`,
        body: data.topic,
      },
      data: { type: "new_drawing", drawingId: event.params.drawingId },
    });
  }
);
