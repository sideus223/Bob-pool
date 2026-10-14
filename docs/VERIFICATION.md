# 품질 확인

<br><br><br>





## 자동 검사

- Flutter 테스트 106개 통과, 1개 건너뜀. 건너뛴 항목은 별도 플래그로 실행하는 원본 알고리즘 대량 비교입니다.
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
