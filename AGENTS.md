# 밥풀 프로젝트 규칙

## 프로젝트 정보
- Flutter 기반 안드로이드 앱
- 안드로이드만 개발
- Material 3 사용
- 한국어 UI 우선

## 폴더 규칙
- 화면: lib/screens/
- 공통 위젯: lib/widgets/
- 라우팅: lib/routes/
- 모델: lib/models/
- 서비스: lib/services/

## 코딩 규칙
- 한 파일에 너무 많은 위젯을 넣지 말 것
- 재사용 가능한 버튼과 입력창은 widgets로 분리
- 화면 이동은 Navigator.pushNamed 사용
- 가능한 StatelessWidget 우선 사용
- 빌드 가능한 상태 유지
- 디자인은 피그마 시안을 최대한 따를 것

## 우선 작업 순서
1. login_page
2. home_page
3. random_menu_picker_page
4. board_page
5. mypage