# 품질 확인

## 2026-10-15 App Check 연결·데모 APK 빌드 12

- [빌드 12 Release](https://github.com/sideus223/Bob-pool/releases/tag/v1.0.0-build.12)는 App Check가 적용된 연결 APK와 Firebase 없이 동작하는 데모 APK를 제공한다. 기본 실행 진입점으로 빌드했으며 실기기 점검용 진입점은 배포 APK에 사용하지 않았다.
- 실기기에서 Play Integrity 토큰 발급과 앱 ID 일치, 기존 로그인 유지·토큰 갱신, 게시판 서버 조회를 확인했다. 같은 로그인에서 App Check 헤더만 바꾼 Firestore 요청은 포함 200·누락 403이었다. 같은 가짜 로그인 정보로 비교하면 포함 시 자격 검증 오류 400, 누락 시 App Check 오류 401이었다. 실제 신규 로그인·회원가입·모든 화면을 재검사한 결과는 아니다.
- 사용자 승인으로 Identity Platform으로 전환하고 Authentication과 Firestore의 App Check를 적용했다. 무료 Spark를 유지하며 인증에는 하루 활성 사용자 3,000명 제한이 적용된다. Firestore 권한 규칙을 이번에 변경하지 않았다.
- 기존 Flutter 테스트 106개와 추가 데모 초기화 테스트 1개 통과, 기존 건너뛰기 1개 유지. 정적 분석, 연결·데모 release 빌드 성공. APK 크기와 SHA-256은 [App Check 검증 요약](evaluations/APP_CHECK_2026-10-15.json)에 기록했다.
- 한국어·일본어 다운로드 페이지는 빌드 12를 안내한다. App Check 미지원 구버전 연결 APK는 업데이트가 필요하며, 일반 에뮬레이터에서는 데모 또는 별도 등록한 개발용 디버그 공급자를 사용한다. [설정과 제한](APP_CHECK.md)

<br><br><br>





## 자동 검사

- Flutter 테스트 107개 통과, 1개 건너뜀. 건너뛴 항목은 별도 플래그로 실행하는 원본 알고리즘 대량 비교입니다.
- Firestore 권한·이관 테스트 41개 통과.
- Dart 포맷과 정적 분석에 문제가 없습니다.
- 데모 APK 빌드를 확인했습니다.

GitHub 실행 결과는 [Actions](https://github.com/sideus223/Bob-pool/actions)에서 확인할 수 있습니다.

<br><br><br>





## 실기기와 서버 확인 범위

데모의 홈·조건 입력·추천 이유·찜·선택·레시피·재추천을 확인했습니다. 서버 연결 모드에서는 로그인 유지·게시판 조회·마이페이지·찜 목록·추천·계정 저장 안내를 확인했습니다.

실제 Firebase SDK로 학습·취향 기록의 저장, 새 세션 재조회, 모델 호환 동작을 확인했습니다. Mock·Emulator 결과와 실제 SDK·화면 확인을 구분합니다.

<br><br><br>





## 평가 범위

[원본 추천 비교](evaluations/ORIGINAL_RECOMMENDATION_COMPARISON.md)와 [학습 적용 전후 비교](evaluations/FEEDBACK_LEARNING_COMPARISON.md)는 가상 취향을 이용한 평가입니다. 실제 사용자 만족도나 추천 정확도로 해석하지 않습니다.

[게시판 데이터 수별 비교](evaluations/BOARD_SERVER_SCALE_COMPARISON.md)는 실기기·실서버의 첫 조회 응답 측정입니다. 앱 전체의 속도 개선율을 뜻하지 않습니다.

[APK와 사용 방법](APK.md)
