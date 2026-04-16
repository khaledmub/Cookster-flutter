# Cookster Mobile — Technical Audit (Indexed) / التدقيق الفني المُفهرس

**Repository:** Cookster Flutter app  
**How to read locations:** Flutter/Dart projects use **file path + line number** (IDE / GitHub). There is no standard “page number” like a PDF.  
**Scope:** Deep indexed audit of **confirmed** issues from codebase scan + known CI/deployment history. Not a literal line-by-line proof of every statement in every file.

---

## Legend / مفتاح

| Tag | EN | AR |
|-----|----|----|
| **P0** | Stop-ship security | أمان يجب إيقافه فوراً |
| **P1** | High risk / prod stability | خطر عالي / استقرار |
| **P2** | Maintainability / debt | صيانة / دين تقني |

---

# Part A — English

## A0. Navigation index (sensitive files)

| Priority | File | Lines (approx.) | Category |
|----------|------|-----------------|----------|
| P0 | `lib/services/notificationService.dart` | 6–22 | Embedded Firebase service account JSON |
| P0 | `assets/appconfig.json` | 1–5 | Payment credentials in shipped assets |
| P0 | `lib/goLive/api_call.dart` | 6–8, 21–27 | Hardcoded VideoSDK JWT + API call |
| P0 | `lib/appUtils/apiEndPoints.dart` | 2–18 | Base URLs + Google Maps API key |
| P1 | `lib/services/apiClient.dart` | 34–38, 62–63, 86–87, 109–110 | Prints auth token |
| P1 | `lib/modules/landing/landingTabs/add/videoAddController/videoAddController.dart` | 61–62, 78–79 | Hardcoded bad-words URLs |
| P2 | Same controller | ~1811 lines total | “God file” / mixed responsibilities |

---

## A1. Security vulnerabilities (P0)

### A1.1 Firebase service account inside app code

- **File:** `lib/services/notificationService.dart`  
- **Lines:** **6–22** (`serviceAccountJson` map including `private_key`, `client_email`, `project_id`, …)  
- **Problem:** Anyone with repo or decompiled artifact can impersonate the service account.  
- **Real impact:** Messaging abuse, data access depending on IAM rules, quota burn, account takeover patterns.  
- **Root cause:** Secrets treated as source code, not as CI/runtime secrets.  
- **Fix:** Remove JSON from repo immediately; **rotate** compromised keys in Google Cloud; use server-side token minting or FCM v1 via your backend; for CI only, inject short-lived credentials via secrets.

### A1.2 Payment credentials in `assets/`

- **File:** `assets/appconfig.json`  
- **Lines:** **1–5** (`merchantKey`, `terminalPass`, `requestUrl`, …)  
- **Problem:** Bundled into APK/IPA; trivial to extract.  
- **Fix:** Never ship terminal secrets in the client; proxy payments through your backend; rotate merchant credentials after removal.

### A1.3 VideoSDK JWT hardcoded

- **File:** `lib/goLive/api_call.dart`  
- **Lines:** **6–8** (`String token = "eyJ..."`), **21–27** (Authorization header uses that token)  
- **Problem:** Long-lived client-side credential; abuse outside the app.  
- **Fix:** Mint short-lived tokens on server; pass to app via authenticated API; rotate exposed token.

### A1.4 Google Maps API key in Dart

- **File:** `lib/appUtils/apiEndPoints.dart`  
- **Line:** **18** (`googleMapApiKey`)  
- **Problem:** Key leakage, billing abuse.  
- **Fix:** Restrict key in Google Cloud (bundle id + APIs); prefer remote config / build-time `--dart-define` for non-secret identifiers only; never commit unrestricted keys.

### A1.5 Printing bearer tokens

- **File:** `lib/services/apiClient.dart`  
- **Lines:** **34–35**, **62–63**, **86–87**, **109–110** (`print("Token: $token")`)  
- **Problem:** Session leakage via logs / crash reports / device logcat.  
- **Fix:** Remove prints; use conditional logger stripped in release; never log secrets.

---

## A2. Hardcoded infrastructure & URLs (P1)

### A2.1 Central API + storage constants

- **File:** `lib/appUtils/apiEndPoints.dart`  
- **Lines:** **2–16** (`Common.baseUrl`, `imageBaseUrl`, `videoUrl`, `audioUrl`)  
- **Problem:** Environment changes require code edits + rebuild.  
- **Fix:** Single `AppConfig` loaded from remote or build flavors + `--dart-define`.

### A2.2 Distributed web/share links (examples)

| File | Line(s) | Hardcoded pattern |
|------|---------|-------------------|
| `lib/modules/landing/landingTabs/add/videoAddController/videoAddController.dart` | **61–62**, **78–79** | `https://cookster.org/badwords/...` |
| `lib/modules/singleVideoView/singleVideoController.dart` | **299** | `https://cookster.org/web/visitSingleVideo?...` |
| `lib/modules/landing/landingTabs/home/homeView/reelsVideoScreen.dart` | **1517** | same pattern |
| `lib/modules/singleVideoVisit/singleVideoVisit.dart` | **633** | same pattern |
| `lib/modules/singleVideoView/singleVideoView.dart` | **1141** | same pattern |

**Fix:** `Uri` builder from `AppConfig.webBaseUrl`.

### A2.3 Third-party endpoints

| File | Lines | Notes |
|------|-------|------|
| `lib/goLive/api_call.dart` | **22** | `https://api.videosdk.live/v2/rooms` |
| `lib/modules/landing/tawkLiveChat/tawkLiveChat.dart` | **17–18** | Tawk widget URLs |
| `lib/modules/chatScreen/chatModel/chatModel.dart` | **93** | FCM REST path includes fixed project id |
| `lib/modules/landing/landingController/landingController.dart` | **117–119** | Store listing URLs |

---

## A3. Architecture & structure (P2)

### A3.1 “God file” — `videoAddController.dart`

- **Size:** **1811** lines (`wc -l` on workspace copy).  
- **Symptoms:** upload + validation + payment flow + HTTP + state in one class.  
- **Impact:** hard to test, high regression risk.  
- **Fix:** Split into `VideoUploadRepository`, `VideoDraftState`, `PaymentCoordinator`, thin controller.

### A3.2 Mixed state approaches

- GetX + `setState` across many widgets/controllers increases inconsistency.  
- **Examples of incomplete TODOs:**  
  - `lib/modules/landing/landingTabs/add/uploadVideoWidgets/uploadVideoStep2.dart` **37**  
  - `lib/modules/landing/landingTabs/profile/profileView/profileView.dart` **56**  
  - `lib/modules/landing/landingTabs/reportContent/reportContentView/reportContentView.dart` **38**

### A3.3 Naming collision risk

- `lib/services/notificationService.dart` vs `lib/services/notificationServices.dart` — confusing; risk of duplicate logic / wrong import.

---

## A4. Logging disaster

- **Metric:** `grep -R "\\bprint(" lib --include='*.dart' | wc -l` → **919** occurrences (workspace snapshot).  
- **Heavy files (print counts from prior scan):** `homeController.dart` **69**, `signUpController.dart` **56**, `videoAddController.dart` **56**, `profileController.dart` **52**, `professionalProfileController.dart` **47**, …  
- **Impact:** noise, accidental PII in logs, minor perf overhead.  
- **Fix:** `logger` package + tree-shaken no-op in release; ban `print` via lint.

---

## A5. Magic numbers (example)

- **File:** `lib/modules/landing/landingTabs/nearBusiness/nearBusinessController/nearBusinessController.dart`  
- **Line:** **11** — `radius = 10.0` km default without named config.

---

## A6. Backend / “new server without DB” symptoms (conceptual)

When API exists but DB seed/migrations are missing, the app often shows:

- Empty lists (valid JSON, zero rows).  
- HTTP 500 on endpoints expecting reference rows (`site_settings`, categories, etc.).  
- Null parsing crashes if responses omit fields and models assume presence.

**Code-side mitigation:** defensive parsing (`tryParse`, nullable models), empty-state UI, retry/backoff — but **root fix** is server data + contracts.

**Note on “No FFmpeg / iPhone videos fail”:** the project **does** depend on `ffmpeg_kit_flutter_new` (see `pubspec.yaml`); do not document as “no FFmpeg” unless verified for a specific flow.

---

## A7. CI/CD issues encountered (historical)

| Platform | Issue | Mitigation done / required |
|----------|-------|----------------------------|
| Android | Gradle / NDK / Kotlin plugin conflicts | Version bumps, overrides, namespace workaround |
| Android | Disk full on GitHub runner | Free disk step in workflow |
| Android | Play API disabled / no permission | Enable `androidpublisher.googleapis.com`; grant Play Console role to service account |
| iOS | Invalid workflow YAML | Heredoc indentation broke parsing — fixed |
| iOS | Manual signing profile mismatch | Moved toward API-key automatic signing |
| iOS | `rive_native` / linker | Dependency pin / removal of chain |
| iOS | Empty App Store Connect secrets | Fail-fast validation |

---

# Part B — العربية (نفس المحتوى باختصار أوضح للتنفيذ)

## B0. فهرس الملفات الحساسة

| الأولوية | الملف | الأسطر التقريبية | الفئة |
|----------|-------|-------------------|--------|
| P0 | `lib/services/notificationService.dart` | 6–22 | حساب خدمة Firebase داخل الكود |
| P0 | `assets/appconfig.json` | 1–5 | أسرار دفع داخل الأصول |
| P0 | `lib/goLive/api_call.dart` | 6–8 و 21–27 | JWT ثابت لـ VideoSDK |
| P0 | `lib/appUtils/apiEndPoints.dart` | 2–18 | روابط API + مفتاح خرائط |
| P1 | `lib/services/apiClient.dart` | 34–38 وما شابه | طباعة التوكن |
| P1 | `videoAddController.dart` | 61–62 و 78–79 | روابط كلمات سيئة ثابتة |
| P2 | `videoAddController.dart` | ~1811 سطر | ملف “إله” ضخم |

## B1. الثغرات الأمنية (P0) — ماذا يحدث وليه خطر؟

1. **`notificationService.dart` (6–22):** مفتاح خاص كامل داخل التطبيق → يجب **حذفه من الكود فوراً** + **تدوير المفتاح في Google Cloud** لأن تاريخ Git قد يكون كاشفاً.  
2. **`appconfig.json` (1–5):** أسرار تُبنى مع APK → يجب نقل الدفع للسيرفر.  
3. **`api_call.dart` (6–8):** JWT ثابت → توليد من الباكند بمدة قصيرة.  
4. **`apiEndPoints.dart` (18):** مفتاح خرائط → تقييد في Google Console + عدم تخزينه في Git بشكل مكشوف.  
5. **`apiClient.dart`:** طباعة التوكن = تسريب جلسة عبر اللوجات.

## B2. البنية التحتية الثابتة (Hardcoded)

- كل الـ base URLs في `apiEndPoints.dart` (2–16).  
- روابط المشاركة و`badwords` موزعة على عدة ملفات (انظر جدول القسم A2.2).  
- روابط طرف ثالث: VideoSDK، Tawk، FCM path، متاجر التطبيقات.

**الإصلاح:** طبقة `AppConfig` واحدة + نكهات build (`dev/staging/prod`).

## B3. المعمارية والهيكل

- **`videoAddController.dart` ~1811 سطر:** يجمع رفع فيديو + دفع + تحقق + شبكة → يصعب الاختبار.  
- **خلط GetX و `setState`:** يزيد التعقيد.  
- **TODO غير مكتملة:** `uploadVideoStep2.dart:37`، `profileView.dart:56`، `reportContentView.dart:38`.  
- **تشابه أسماء:** `notificationService` و `notificationServices`.

## B4. كارثة اللوج (`print`)

- **919** استدعاء `print` تحت `lib/` (عدّ بـ `grep` كما في الأعلى).  
- ملفات ثقيلة بالطباعة ترفع خطر تسريب بيانات وصعوبة التشخيص.

## B5. أعراض سيرفر جديد بدون قاعدة بيانات جاهزة

قوائم فارغة، 500، شاشات بيضاء عند افتراض وجود حقول — الحل الجذري عند السيرفر (Seeding/Migrations)، والتطبيق يحتاج parsing دفاعي ورسائل واضحة للمستخدم.

## B6. مشاكل CI/CD التي مرّت بنا

انظر جدول القسم A7 (أندرويد: مساحة، API، صلاحيات — iOS: YAML، توقيع، أسرار فارغة، تبعيات).

---

## B7. خطة إصلاح مقترحة (مراحل)

| Phase | EN | AR |
|-------|----|----|
| **1** | Remove secrets from `notificationService`, `assets/appconfig.json`, rotate keys | إزالة الأسرار من الملفات المذكورة + تدوير المفاتيح |
| **2** | Central config (`dart-define` / remote config) + stop logging tokens | إعدادات مركزية + إيقاف طباعة التوكن |
| **3** | Split `videoAddController` into modules + repositories | تفكيك الملف الضخم |

---

## Document maintenance / صيانة الوثيقة

- After each security remediation, **update line numbers** (they shift).  
- Prefer linking to Git commit SHA in future audits.

---

**End of document / نهاية الوثيقة**
