# 에셋 출처

메뉴 데이터 100개, 음식 사진 100개, 앱 아이콘은 졸업작품 자료입니다. 음식 사진과 아이콘은 프로젝트 소유자가 직접 제작하거나 AI로 생성한 자료입니다. 개별 파일의 제작 방식과 도구를 특정하지 않습니다.

| 자료 | 위치 | 출처 |
|---|---|---|
| 음식 사진 | `assets/images/menus/1.jpg` ~ `100.jpg` | 프로젝트 소유자의 직접 제작 또는 AI 생성 자료 |
| 앱 아이콘 | `assets/icon/app_icon.png` 및 Android 아이콘 | 프로젝트 소유자의 직접 제작 또는 AI 생성 자료 |
| 메뉴·레시피 | `assets/data/menus_dataset.json` | 졸업작품 데이터셋. 실제 식당 가격·평점 데이터가 아님 |
| 앱 화면 | `docs/images/home.png`, `recommendation.png`, `recipe.png` | 홈은 Android 실기기, 추천·레시피는 Pixel 7 데모 화면 |
| 추천·학습 설명 그림 | `recommendation-algorithm*.png`, `recommendation-details*.png`, `learning-model*.png` | 코드와 설계를 바탕으로 내장 imagegen으로 제작 |
| 데이터 구조 | `erd.png`, `erd-ja.png` | 계정·게시판·취향 저장 구조와 메뉴 JSON을 바탕으로 내장 imagegen으로 제작 |
| 게시판 처리 그림 | `board-async-state.png`, `board-async-state-ja.png` | Mermaid 원본을 Pillow로 렌더링. `tools/render_board_async_diagram.py`와 `tools/board-async-state*.mmd`로 재생성 가능 |

메뉴 ID와 이미지의 대응 및 레시피 존재 여부를 자동 테스트합니다. 음식 사진이 모든 재료와 완전히 일치하거나 레시피·가격이 외부 검증을 거쳤다는 의미는 아닙니다.

제작 도구의 이용 조건과 팀 결과물의 공개 범위는 프로젝트 소유자가 관리합니다. 프로젝트 전체에 임의의 오픈소스 라이선스를 부여하지 않았습니다.

개인 포트폴리오, 디자인 참고 원본, 생성 프롬프트와 로컬 보관 자료는 GitHub 업로드 대상에서 제외합니다.
