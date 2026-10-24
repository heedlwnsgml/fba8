# TravelPlanner

Flutter 프론트, Spring Boot 백엔드와 실행용 DB 사본입니다. 최신 반영: 2026-10-25.

## 다운로드

Git LFS를 설치한 뒤 받으세요. 대용량 데이터는 GitHub ZIP 다운로드 대신 clone을 권장합니다.

```powershell
git clone https://github.com/heedlwnsgml/fba8.git
cd fba8
git lfs pull
```

## 구성

- `A5front/`: 프론트 코드와 비밀 설정을 제외한 관련 파일.
- `TravelPlanner_Backend/`: 백엔드 코드 및 교통/숙소 데이터.
- `DB/`: 장소·회원·일정, 부가 설정, 수집 패스 SQL 백업 3개.
- `docs/PROJECT_MARKDOWN.zip`: 기존 문서를 경로별로 보관한 ZIP. `DOCUMENT_INDEX.json`에 목록과 해시가 있습니다.
- `UPLOAD_EXCLUSIONS.json`: 비밀 설정·키·브라우저 프로필 등의 제외 목록.
- `UPLOAD_MANIFEST.json`: 업로드 파일 목록과 SHA-256.

실제 API 키와 DB 비밀번호는 제외했습니다. `TravelPlanner_Backend/config/*.example`을 참고해 로컬 설정을 준비하세요. 저장소는 소유자 요청에 따라 공개 상태입니다.

## 최신 변경

- 원본 백엔드 3a6ffef 통합: 섬 교통 연결, 도시 순서 개선, 숙소 복귀 시간을 고려한 식사 배치.
- 일정 생성 중 식당 검색 범위 확대 및 실제 영업·이동 조건을 만족하는 식사 자리 보완.
- 선호/금지 테마 중복 선택 금지, 금지 테마 색상 및 제외 개수 정렬.
- 일정 지도 기본 고정 해제, 지도 높이 75%, 고정 상태에 따른 상단 도구 영역 표시.
- 일정 삭제 API, 네이티브 Google 지도 iframe 수정, 다음 날 09:00 출발 유지.
- 프론트 204개 및 백엔드 395개 회귀 테스트 통과. 외부 환경/옵트인 테스트와 기존 스키마 미호환 테스트는 제외했습니다.

원본 회원·일정 DB가 포함되어 있습니다. SQLite는 실행 중인 DB의 백업 API로 일관된 사본을 만들었습니다.

## 2026-10-25 변경

- 생성 당일 숙소 최저가 저장, 조회 실패 시 저장 요금 사용, Gemini → OpenAI 웹 검색 보완.
- 관리자 마이페이지 하단에 5회 이상 요금 조회 실패한 숙소명 표시.
- 도시 선택 화면 간소화, 지도 최초 포커싱, 공항 승차 안내 필드 구분, 사용자 안내 및 PDF 정리.
- USB 연결 주소 처리와 관리자 설정 복원. 실제 비밀 설정은 저장소에 포함하지 않습니다.
- Docker/Kubernetes/Ansible 구성과 이미지 주소는 `codex/docker-deployment` 브랜치에 있습니다. Docker 이미지는 Docker Hub에서 받습니다.
- 이번 코드 갱신에는 운영 중인 VM DB 원본을 새로 업로드하지 않았습니다. 기존 DB 백업은 기존 버전 그대로입니다.
