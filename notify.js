// JHS 알림 발송기 (GitHub Actions 무료 크론에서 10분마다 실행)
// - 콕 찌르기 큐(rooms/0516/pokes) 처리 → 상대에게 FCM
// - 매일 19시(KST) 데일리 알림 (하루 1회)
const admin = require("firebase-admin");
admin.initializeApp({ credential: admin.credential.cert(JSON.parse(process.env.FIREBASE_SA)) });
const db = admin.firestore();

const ROOM = "0516";
const SITE = "https://junjunny.github.io/read-gmae-real/";
const nick = (u) => (u === "0421" ? "주니" : "히수");
const NUDGE = {
  "0421": ["주니 얼른 그림 그려! 🎨", "주니야 오늘 그림 그렸어? ✏️", "주니 미니게임 한 판 ㄱㄱ 🎮", "주니 오늘 주제 확인했어? 👀"],
  "0118": ["히수 얼른 그림 그려! 🎨", "히수야 오늘 그림 그렸어? ✏️", "히수 미니게임 도전! 🎮", "히수 오늘 주제 확인했어? 👀"],
};

async function tokenOf(uid) {
  const td = await db.doc(`rooms/${ROOM}/meta/tokens`).get();
  return (td.data() || {})[uid];
}
async function sendTo(uid, title, body) {
  const token = await tokenOf(uid);
  if (!token) return false;
  try {
    await admin.messaging().send({ token, notification: { title, body }, webpush: { fcmOptions: { link: SITE } } });
    return true;
  } catch (e) {
    console.error("send fail", uid, e.code || e.message);
    if (e.code === "messaging/registration-token-not-registered") {
      await db.doc(`rooms/${ROOM}/meta/tokens`).update({ [uid]: admin.firestore.FieldValue.delete() }).catch(() => {});
    }
    return false;
  }
}

(async () => {
  // 1) 콕 찌르기 큐 — 전송 성공 시에만 삭제(실패 시 재시도, 24시간 지나면 만료 삭제)
  const pokes = await db.collection(`rooms/${ROOM}/pokes`).limit(30).get();
  const nowMs = Date.now();
  for (const p of pokes.docs) {
    const d = p.data() || {};
    const ok = await sendTo(d.to, `${nick(d.from)}님의 콕! 💗`, (d.message && String(d.message)) || "콕! 👈");
    const ageMs = d.createdAt && d.createdAt.toMillis ? nowMs - d.createdAt.toMillis() : 0;
    if (ok || ageMs > 24 * 3600 * 1000) {
      await p.ref.delete().catch(() => {});
    }
  }

  // 2) 19시(KST) 데일리 (하루 1회)
  const kst = new Date(Date.now() + 9 * 3600 * 1000);
  const today = `${kst.getUTCFullYear()}-${String(kst.getUTCMonth() + 1).padStart(2, "0")}-${String(kst.getUTCDate()).padStart(2, "0")}`;
  const hour = kst.getUTCHours();
  const stateRef = db.doc(`rooms/${ROOM}/meta/state`);
  const last = (await stateRef.get()).data()?.lastNudgeDate;
  if (hour >= 19 && hour < 24 && last !== today) {
    for (const uid of ["0421", "0118"]) {
      const pool = NUDGE[uid];
      await sendTo(uid, "JHS 💌", pool[Math.floor(Math.random() * pool.length)]);
    }
    await stateRef.set({ lastNudgeDate: today }, { merge: true });
  }
  console.log("notify done", today, hour, "pokes:", pokes.size);
})().catch((e) => { console.error(e); process.exit(1); });
