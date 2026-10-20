# TravelPlanner 전체 업로드

최신 로컬 프론트·백엔드와 실행용 데이터의 사본입니다. 비공개 저장소이며, 링크만으로는 접근할 수 없습니다. 필요한 GitHub 계정을 Collaborator로 초대하세요.

## 다운로드

Git LFS를 설치한 다음 다음과 같이 받으세요. GitHub ZIP 다운로드 대신 clone을 권장합니다.

```powershell
git clone https://github.com/heedlwnsgml/fba8.git
cd fba8
git lfs pull
```

## 구성

- `A5front/`: Flutter 프론트 원본과 비밀키가 검출되지 않은 관련 파일.
- `TravelPlanner_Backend/`: Spring 백엔드 원본과 관련 파일.
- `TravelPlanner_Backend/data/`: 대중교통·패스·국내선·등산 접근·호텔 캐시 등 SQLite 및 원본 자료. 실행 중인 SQLite는 백업 API로 일관된 사본을 만들었습니다.
- `DB/test_planner_20261019_update.sql`: 현재 사용 중인 장소·회원·일정 DB 전체 원본 덤프.
- `DB/test_planner_app_metadata.sql`: 추가 회원 설정·숙박비·일정 정보 등 보조 DB.
- `DB/test_planner_collected_passes_20261012.sql`: 수집 패스 DB.
- `UPLOAD_EXCLUSIONS.json`: 키 또는 키 저장소 때문에 제외한 파일과 SQLite에 합쳐진 WAL/SHM 목록.
- `UPLOAD_MANIFEST.json`: 업로드 파일의 크기와 SHA-256.

## 비밀 설정

실제 API 키·비밀번호가 들어 있는 파일과 그런 내용을 포함한 압축파일·빌드 결과는 포함하지 않았습니다. 브라우저 테스트 프로필의 암호화 키·쿠키 저장소도 제외했습니다. `config/*.example`을 복사해 본인의 설정을 채우세요. 제외된 Android manifest 등은 목록을 확인해 로컬 환경에서 따로 복원해야 합니다.

DB에는 원본 회원·일정 데이터가 있으므로 저장소를 공개로 바꾸거나 외부에 재배포하지 마세요. 원본 DB와 로컬 프로젝트는 변경하지 않았습니다.
