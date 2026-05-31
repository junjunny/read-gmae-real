const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

const ROOM = "0516";
const SITE = "https://junjunny.github.io/read-gmae-real/";
const nick = (uid) => (uid === "0421" ? "주니" : "히수");

/** 콕 찌르기: rooms/{room}/pokes 문서가 생기면 상대에게 즉시 푸시(커스텀 멘트) */
exports.onPoke = onDocumentCreated("rooms/{room}/pokes/{id}", async (event) => {
  const d = event.data && event.data.data();
  if (!d) return;
  const to = d.to;
  const msg = (d.message && String(d.message).trim()) || "콕! 👈";
  const tdoc = await db.doc(`rooms/${event.params.room}/meta/tokens`).get();
  const token = (tdoc.data() || {})[to];
  if (token) {
    try {
      await admin.messaging().send({
        token,
        notification: { title: `${nick(d.from)}님의 콕! 💗`, body: msg },
        webpush: { fcmOptions: { link: SITE } },
      });
    } catch (e) {
      console.error("poke send fail", e);
    }
  }
  // 처리된 poke 정리
  try { await event.data.ref.delete(); } catch (_) {}
});

/** 매일 19시(KST) 기본 알림 — 각자 다른 멘트 랜덤 */
const NUDGE = {
  "0421": ["주니 얼른 그림 그려! 🎨", "주니야 오늘 그림 그렸어? ✏️", "주니 미니게임 한 판 ㄱㄱ 🎮", "주니 오늘 주제 확인했어? 👀"],
  "0118": ["히수 얼른 그림 그려! 🎨", "히수야 오늘 그림 그렸어? ✏️", "히수 미니게임 도전! 🎮", "히수 오늘 주제 확인했어? 👀"],
};

exports.dailyNudge = onSchedule(
  { schedule: "0 19 * * *", timeZone: "Asia/Seoul" },
  async () => {
    const tdoc = await db.doc(`rooms/${ROOM}/meta/tokens`).get();
    const tokens = tdoc.data() || {};
    for (const uid of ["0421", "0118"]) {
      const tk = tokens[uid];
      if (!tk) continue;
      const pool = NUDGE[uid];
      const body = pool[Math.floor(Math.random() * pool.length)];
      try {
        await admin.messaging().send({
          token: tk,
          notification: { title: "JHS", body },
          webpush: { fcmOptions: { link: SITE } },
        });
      } catch (e) {
        console.error("nudge send fail", uid, e);
      }
    }
  }
);
