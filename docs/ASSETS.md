# 에셋 출처

메뉴 데이터와 앱 아이콘은 졸업작품 자료입니다. 기존 음식 사진과 아이콘은 프로젝트 소유자가 직접 제작하거나 AI로 생성했습니다.

2026-10-19 음식 사진 100장을 개선본으로 교체했습니다. 내장 imagegen으로 47장을 복원하고 53장을 재생성했으며, 모두 1448×1086픽셀입니다. 음식의 식별 가능성과 구도·화질을 검수하고 기존 메뉴 ID와 파일 경로를 유지했습니다. 메뉴별 해시·해상도·검수 범위는 [사진 검수 기록](food-photo-audit.json)에 정리했습니다.

| 자료 | 위치 | 출처 |
|---|---|---|
| 음식 사진 | `assets/images/menus/1.jpg` ~ `100.jpg` | 프로젝트 소유자 자료를 바탕으로 2026-10-18 내장 imagegen으로 복원·재생성한 메뉴 설명용 AI 이미지. 실제 식당 촬영 사진이 아님 |
| 앱 아이콘 | `assets/icon/app_icon.png` 및 Android 아이콘 | 프로젝트 소유자의 직접 제작 또는 AI 생성 자료 |
| 메뉴·레시피 | `assets/data/menus_dataset.json` | 졸업작품 데이터셋. 실제 식당 가격·평점 데이터가 아님 |
| 앱 화면 | `docs/images/home.png`, `recommendation.png`, `recipe.png` | 홈은 Android 실기기, 추천·레시피는 Pixel 7 데모 화면 |
| 추천·학습 설명 그림 | `recommendation-algorithm*.png`, `recommendation-details*.png`, `learning-model*.png` | 코드와 설계를 바탕으로 내장 imagegen으로 제작 |
| 데이터 구조 | `erd.png`, `erd-ja.png` | 계정·게시판·취향 저장 구조와 메뉴 JSON을 바탕으로 내장 imagegen으로 제작 |
| 게시판 처리 그림 | `board-async-state.png`, `board-async-state-ja.png` | Mermaid 원본을 Pillow로 렌더링. `tools/render_board_async_diagram.py`와 `tools/board-async-state*.mmd`로 재생성 가능 |

메뉴 ID와 이미지의 대응 및 레시피 존재 여부를 자동 테스트합니다. 음식 사진이 모든 재료와 완전히 일치하거나 레시피·가격이 외부 검증을 거쳤다는 의미는 아닙니다.

제작 도구의 이용 조건과 팀 결과물의 공개 범위는 프로젝트 소유자가 관리합니다. 프로젝트 전체에 임의의 오픈소스 라이선스를 부여하지 않았습니다.

개인 포트폴리오, 디자인 참고 원본, 생성 프롬프트와 로컬 보관 자료는 GitHub 업로드 대상에서 제외합니다.
