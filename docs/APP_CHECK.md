# App Check 설정

연결 모드에서는 Firebase 초기화 직후, Authentication과 Firestore를 사용하기 전에 App Check를 활성화한다. Android의 기본 인증 공급자는 Play Integrity이며 토큰은 SDK가 자동 갱신한다. 로컬 데모는 Firebase와 App Check를 초기화하지 않는다.

## 적용 상태 (2026-10-15)

- Play Integrity API 활성화와 배포 APK의 SHA-256 서명 등록 완료.
- Firestore: `ENFORCED`. 로그인은 같은 상태로 유지하고 App Check 헤더만 바꾼 조회에서 **토큰 포함 200 / 토큰 없음 403**을 실기기로 확인했다.
- Authentication: 사용자 승인으로 Identity Platform으로 전환하고 `ENFORCED`로 설정했다. 무료 Spark 플랜을 유지한다. 동일한 가짜 로그인 정보로 비교했을 때 토큰을 넣으면 App Check를 통과해 `INVALID_LOGIN_CREDENTIALS`(400), 빼면 App Check 단계에서 `APP_CHECK_TOKEN_INVALID`(401)로 거부됐다. 기존 로그인 유지·토큰 갱신과 토큰을 포함한 계정 정보 조회도 확인했다.
- 휴대폰은 기본 실행 진입점의 연결 APK `1.0.0+12`로 업데이트했다. 점검용 진입점은 배포 APK에 사용하지 않았다. [빌드 12 Release](https://github.com/sideus223/Bob-pool/releases/tag/v1.0.0-build.12)에서 연결·데모 APK를 제공한다.
- 연결·데모 release APK 빌드, 기존 Flutter 테스트 106개와 추가 데모 초기화 테스트 1개 통과. 기존 건너뛰기 1개는 유지한다. 정적 분석 통과.

[검증 결과](evaluations/APP_CHECK_2026-10-15.json)에 토큰·사용자 정보 없이 결과와 APK 해시를 기록했다. App Check 미지원 구버전 연결 APK는 업데이트가 필요하다.

## APK 직접 배포 설정

Firebase 프로젝트와 같은 Google Cloud 프로젝트에서 Play Integrity API를 활성화하고 약관에 동의해야 한다. Firebase Android 앱에 **배포 APK의 SHA-256 서명 지문**을 등록한다. 서명 키가 바뀌면 새 지문도 등록하고 실기기 인증을 다시 확인한다.

현재처럼 Google Play 외부에서 APK를 배포할 때는 다음 정책을 사용한다.

| 항목 | 설정 |
|---|---|
| Play에서 인식한 앱 버전 요구 | 사용하지 않음 (`allowUnrecognizedVersion: true`) |
| Play 구매·설치 라이선스 요구 | 사용하지 않음 (`requireLicensed: false`) |
| 기기 무결성 | `MEETS_DEVICE_INTEGRITY` |
| App Check 토큰 유효기간 | 1시간 |

직접 설치를 허용하므로 Play에서 배포한 바이너리인지까지 보증하는 정책은 아니다. 기기 무결성 검증과 기존 로그인·Firestore 권한 규칙을 함께 사용한다. 루팅·변조 기기나 Google Play 서비스가 없는 환경에서는 인증이 실패할 수 있다.

## 배포와 차단 적용 순서

1. Firestore를 `UNENFORCED`로 설정해 요청을 관찰한다. Authentication 보호에는 Firebase Authentication with Identity Platform이 필요하므로 서비스 종류도 확인한다.
2. App Check를 포함한 연결 APK를 배포한다.
3. 실기기에서 Play Integrity 토큰 발급, 인증 요청, 서버 조회를 확인한다.
4. 사용할 기기와 설치본이 준비된 뒤 `ENFORCED`로 전환한다. 기존 App Check 미지원 APK는 서버 요청이 차단되므로 업데이트가 필요하다.

App Check의 클라이언트 초기화만으로 서버 차단이 켜지지는 않는다. Firebase Console의 App Check에서 각 서비스의 적용 상태를 확인해야 한다. 인증 실패 시 공급자를 자동으로 debug로 바꾸지 않는다.

Authentication은 일반 Firebase Authentication에서 Identity Platform으로 업그레이드해야 App Check가 적용된다. 관리 API에 `ENFORCED` 값이 저장됐다는 사실만으로 로그인 차단이 작동한다고 판단하지 않는다. Identity Platform은 Spark에서도 사용할 수 있지만 이메일·소셜 등 로그인은 하루 활성 사용자 3,000명 제한이 생기므로 별도로 결정한다. [공식 조건](https://firebase.google.com/docs/auth/faq-and-troubleshooting#enable_and_enforce_app_check) · [사용량 제한](https://firebase.google.com/docs/auth#usage_limits)

## 개발과 실기기 확인

에뮬레이터 개발에만 다음 옵션을 사용할 수 있다. 생성된 debug 토큰은 Firebase Console에 개인적으로 등록하고 저장소·문서·배포 APK에 넣지 않는다. 이 옵션은 debug 빌드에서만 동작하며 profile/release 빌드는 항상 Play Integrity를 사용한다.

```sh
flutter run --dart-define=DEMO_MODE=false --dart-define=APP_CHECK_DEBUG=true
```

실기기 점검용 진입점은 기존 로그인 상태를 유지하며 토큰 발급, 인증 토큰 갱신, 게시판 서버 조회를 검사한다. 같은 로그인 자격 증명으로 Firestore 요청의 App Check 헤더만 바꿔 200/403을 비교한다. 로그인 요청은 예약 도메인의 가짜 계정 정보로 헤더만 바꿔 400/401을 비교하며 계정을 생성하지 않는다. 로그에는 성공 여부·오류 코드만 출력하고 토큰·사용자 정보·게시글 내용은 출력하지 않는다. 로그인 상태가 없으면 인증·게시판 검사는 생략되므로 로그인 후 다시 실행해야 한다.

```sh
flutter run --release --target=tools/app_check_probe_main.dart \
  --dart-define=DEMO_MODE=false \
  --dart-define=RUN_APP_CHECK_PROBE=true \
  --dart-define=EXPECTED_FIREBASE_PROJECT=<프로젝트-ID>
```

점검 후 배포용 APK는 기본 진입점으로 빌드한다.

```sh
flutter build apk --release --dart-define=DEMO_MODE=false
```

SDK는 기존 Firebase 의존성과 테스트 도구의 호환성을 유지하도록 `firebase_app_check: 0.4.4+1`로 고정했다. Firebase SDK를 올릴 때는 이 버전과 테스트 도구도 함께 검토한다.

설정 근거: [Flutter App Check 초기화](https://firebase.google.com/docs/app-check/flutter/default-providers), [외부 APK용 Play Integrity 정책](https://firebase.google.com/docs/app-check/android/play-integrity-provider), [Google Cloud API 활성화](https://developer.android.com/google/play/integrity/setup).
