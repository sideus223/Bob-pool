# APK 다운로드와 사용 방법

서버 연결 버전과 데모 버전을 [Release](https://github.com/sideus223/Bob-pool/releases/tag/v1.0.0)에서 제공합니다. 두 버전은 같은 추천 알고리즘과 음식 특징 146개를 사용하는 학습 모델을 포함합니다.

| 파일 | 사용 방법 | 기록 저장 |
|---|---|---|
| [서버 연결 APK](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0/bob-pool.apk) | 앱에서 회원가입·로그인, 인터넷 연결 필요 | 계정별 Firestore |
| [데모 APK](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0/bob-pool-demo.apk) | 로그인 없이 추천·찜·선택·레시피 체험 | 기기 내 SharedPreferences |

<br><br><br>





## 설치

Android 7.0 이상에서 APK를 내려받아 설치합니다. 서버 연결 APK에는 밥풀 서버 설정이 포함되어 있어 이용자가 Firebase를 설정할 필요가 없습니다. 데모에서는 실제 로그인과 서버 게시판을 사용하지 않습니다.

두 APK는 같은 앱 ID를 사용하므로 별도 앱으로 함께 설치되지 않습니다. 같은 개발용 인증서로 서명한 APK는 기존 앱을 제거하지 않고 업데이트할 수 있습니다. Google Play 배포용 서명이 아닌 검토용 APK입니다.

<br><br><br>





## 파일 확인

- 앱 버전: `1.0.0`, 앱 ID `com.babpool.app`, Android API 24 이상.
- 지원 아키텍처: arm64-v8a·armeabi-v7a·x86_64.
- 서버 연결: 56,088,478 bytes. 데모: 54,299,238 bytes.
- APK Signature Scheme v2 서명을 확인했습니다.
- 다운로드 파일의 해시는 [SHA256SUMS.txt](https://github.com/sideus223/Bob-pool/releases/download/v1.0.0/SHA256SUMS.txt)로 확인할 수 있습니다.

[검증 범위](VERIFICATION.md)
