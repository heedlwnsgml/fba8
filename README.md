# TravelPlanner

Flutter 프론트와 Spring Boot 백엔드, 원본 DB를 포함한 비공개 프로젝트입니다. 최신 로컬 수정본을 2026-10-21에 반영했습니다.

## 구성

- `A5front/`: 프론트 코드와 Android 백그라운드 일정 완료 알림.
- `TravelPlanner_Backend/`: 백엔드 코드, 일정 생성·경로 탐색·교통비·패스 비교 기능.
- `TravelPlanner_Backend/data/`: 교통·패스·국내선·숙소 캐시 등의 데이터와 원본 자료.
- `DB/`: 현재 장소·회원·일정 DB 및 보조 DB의 전체 SQL 백업 3개.
- `docs/PROJECT_MARKDOWN.zip`: 기존 Markdown 문서 전체. 원래 경로와 내용을 유지했으며 `DOCUMENT_INDEX.json`에서 목록과 해시를 확인할 수 있습니다.
- `UPLOAD_EXCLUSIONS.json`: 비밀키·비밀번호·브라우저 키 저장소 등 제외 목록.
- `UPLOAD_MANIFEST.json`: 업로드 파일 목록, 크기와 SHA-256.

## 다운로드

Git LFS를 설치하고 저장소 접근 권한이 있는 계정으로 받으세요.

```powershell
git clone https://github.com/heedlwnsgml/fba8.git
cd fba8
git lfs pull
```

실제 비밀키와 비밀번호는 제외했습니다. `TravelPlanner_Backend/config/*.example`을 참고해 개인 환경에 맞게 별도로 설정하세요. 다른 제외 파일은 `UPLOAD_EXCLUSIONS.json`에서 확인할 수 있습니다.

## 최신 변경

- 장기 일정 생성 시간 제한 제거 및 후보·교통망 탐색 최적화.
- Android 홈 화면 이동 후 일정 완료 알림과 알림에서 일정 열기.
- 지도 고정·해제: 접지 않고 고정 해제 시 목록과 함께 스크롤, 지도 아래 조작 버튼.
- 테마 문구·기본값 고정 안내 개선 및 이전 일정 화면 수정 사항 포함.

## DB와 문서

`DB/test_planner_20261019_update.sql`, `DB/test_planner_app_metadata.sql`, `DB/test_planner_collected_passes_20261012.sql`은 업로드 시점의 전체 백업입니다. 실행 중인 SQLite는 백업 API로 일관된 사본을 만들었습니다.

기존 개별 Markdown 파일은 저장소 사본에서 문서 ZIP으로 정리했습니다. 개발 중인 원본 폴더의 문서는 그대로 유지했습니다. 회원·일정 원본 데이터가 있으므로 저장소 비공개 상태를 유지하세요.
