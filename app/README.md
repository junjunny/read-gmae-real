# 그림핑퐁 — Flutter 앱 (Android/iOS)

핑퐁 컨셉의 크로스플랫폼 그림 공유 앱. 매일 랜덤 주제 → 그림 → 홈 위젯 실시간 공유 → 평생 보관.

## 구현된 기능 (Phase 0~4)
- ✏️ **캔버스**: 베지어 스무딩 드로잉, 색상/배경/굵기/지우개/Undo·Redo/전체삭제
- 💾 **고화질 PNG 저장**: 사진첩 저장 (pixelRatio 3.0)
- 🔐 **인증 & 커플 페어링**: 이메일 가입 → 초대 코드로 1:1 연결 (기기 변경해도 유지)
- ☁️ **클라우드 동기화**: Firestore(메타) + Storage(원본 PNG) — 평생 아카이빙
- 🎯 **매일 주제**: Cloud Function이 매일 08시(KST) 동일 주제 배포 + FCM 푸시
- 🖼️ **히스토리 갤러리**: 월별 그룹 + 그리드 + 풀스크린 상세/다운로드
- 📲 **홈 위젯**: Android(RemoteViews) / iOS(WidgetKit). 상대 전송 시 실시간 갱신, 탭하면 캔버스로 딥링크

---

# 🚀 실제 앱으로 사용하는 방법 (A~F 순서대로)

## A. 개발 환경 설치
```bash
# 1) Flutter SDK 설치 (https://docs.flutter.dev/get-started/install)
flutter --version          # 정상 출력 확인
flutter doctor             # 안내되는 항목(Android Studio, Xcode 등) 설치

# 2) 이 repo의 app/ 폴더에서 네이티브 프로젝트 뼈대 생성
cd app
flutter create .           # android/ ios/ 폴더 자동 생성 (lib/는 유지됨)
flutter pub get
```
> ⚠️ iOS 빌드/배포에는 **Mac + Xcode**가 필요합니다. Android만이면 Windows/Linux로 충분.

## B. Firebase 프로젝트 연결
```bash
# 1) https://console.firebase.google.com 에서 프로젝트 생성
# 2) FlutterFire CLI로 자동 연결 (firebase_options.dart 자동 생성)
dart pub global activate flutterfire_cli
flutterfire configure
```
Firebase 콘솔에서 **활성화**할 것:
- **Authentication → 이메일/비밀번호** 사용 설정
- **Firestore Database** 생성 (프로덕션 모드)
- **Storage** 생성
- (선택) **Cloud Messaging** — 푸시 알림용

보안 규칙 배포:
```bash
# repo 루트에서
firebase deploy --only firestore:rules,storage
```
(`firestore.rules`, `storage.rules` 가 repo 루트에 있음)

## C. 매일 주제 Cloud Function 배포 (Phase 2)
```bash
cd functions
npm install
cd ..
firebase deploy --only functions     # dailyTopic(매일8시) + onNewDrawing(알림) 배포
```

## D. 홈 위젯 네이티브 설정 (Phase 4)

### Android
1. `android/app/src/main/AndroidManifest.xml` 의 `<application>` 안에 추가:
```xml
<receiver android:name=".GrimWidgetProvider" android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
        <action android:name="es.antonborri.home_widget.action.LAUNCH" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
        android:resource="@xml/grim_widget_info" />
</receiver>
```
2. 딥링크: `MainActivity` 가 있는 `<activity>` 에 추가:
```xml
<intent-filter>
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="grimpingpong" android:host="canvas" />
</intent-filter>
```
3. `android/app/build.gradle` → `minSdkVersion 21` (하위 호환)
4. 위젯 코드는 이미 `android/app/src/main/kotlin/com/example/grim_pingpong/GrimWidgetProvider.kt` 에 있음. (패키지명은 본인 applicationId에 맞게 수정)

### iOS (Mac/Xcode 필요)
1. Xcode에서 `Runner` 프로젝트 열기 → **File ▸ New ▸ Target ▸ Widget Extension** → 이름 `GrimWidget`
2. 생성된 파일을 `ios/GrimWidget/GrimWidget.swift` 내용으로 교체
3. **App Groups** 추가 (Runner + GrimWidget 두 타깃 모두): `group.com.example.grimPingpong`
   - `widget_service.dart` 의 `_appGroupId` 와 동일해야 함
4. 딥링크: `ios/Runner/Info.plist` 에 URL Scheme `grimpingpong` 등록
5. iOS Deployment Target: 앱 본체 12.0, 위젯은 14.0 이상

## E. 디바이스에서 실행/테스트
```bash
flutter devices            # 연결된 기기 확인
flutter run                # 디버그 실행
```

## F. 실제 배포 (프라이빗 사용)

| 목적 | Android | iOS |
|---|---|---|
| **둘이서만 쓰기(가장 간단)** | `flutter build apk --release` → 생성된 `app-release.apk`를 상대 폰에 전송 후 설치(알 수 없는 출처 허용) | **TestFlight** 권장: `flutter build ipa` → App Store Connect 업로드 → 상대를 테스터로 초대 |
| **필요 계정** | 없음(사이드로드) / 또는 Play Console($25 1회) | **Apple Developer Program($99/년) 필수** |
| **앱스토어 정식 출시** | `flutter build appbundle` → Play Console 업로드 | `flutter build ipa` → App Store 심사 |

### 가장 현실적인 프라이빗 운영 추천
- **Android**: release APK를 만들어 카톡/메일로 상대에게 보내 설치 → 무료, 즉시.
- **iOS**: Apple Developer 가입($99/년) 후 **TestFlight**로 상대 1명 초대 → 심사 거의 없이 90일 단위로 사용. (가장 핑퐁스럽게 둘이서만 쓰기 좋음)

- 둘 다 **같은 Firebase 프로젝트**를 바라보므로 OS가 달라도 완벽히 연동됩니다.

---

## 참고: 폴더 구조
```
app/
├── lib/
│   ├── main.dart                 # Firebase init + 한국어 로케일
│   ├── firebase_options.dart     # flutterfire configure로 교체 필요
│   ├── models/  (stroke, drawing)
│   ├── services/ (auth, couple, drawing, widget, app_session)
│   ├── screens/  (auth_gate, auth, pairing, home_shell, today, canvas, gallery, detail)
│   └── widgets/  (drawing_painter)
├── android/.../GrimWidgetProvider.kt + res/layout/grim_widget.xml
└── ios/GrimWidget/GrimWidget.swift
functions/index.js                # 매일 주제 + 알림
firestore.rules / storage.rules   # 보안 규칙
docs/기획서.md                     # 전체 기획·설계
```
