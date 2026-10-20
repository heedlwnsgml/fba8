# 백엔드 GitHub 업데이트 반영 — 2026-10-04

수정 위치: `C:\Users\USER\Desktop\TravelPlanner_GitHub_refresh\TravelPlanner_Backend`

기준 GitHub 브랜치: [NaDongHwi/TravelPlanner_Backend — refactor](https://github.com/NaDongHwi/TravelPlanner_Backend/tree/refactor)

기존 패키지 기준 `12344f2` 이후 최신 `b74d02f`까지 세 커밋을 확인했습니다.

- `8c5a545`: 일정 응답에 주소·전화번호·방문 요일 영업시간 추가. 원본은 Google Places 실시간 조회이며 DB를 갱신하지 않습니다.
- `b74d02f`: 장소 수집 시 리뷰 수 기준 완화. 일반 명소는 평점 4.0/리뷰 100개, 대형 명소는 평점 3.6/리뷰 300개 기준을 적용했습니다. 기존 로컬 도시 경계·중복 필터는 유지합니다.
- `e1f7571`: 소셜 로그인 이메일 누락 대응. 카카오·네이버의 이메일이 없는 경우 공급자 ID를 사용합니다. 기존 계정 연결을 보호하기 위해 이미 제공되는 네이버 이메일은 원본 변경처럼 강제 교체하지 않았습니다.

## 반영된 동작

새 일정 생성·저장 일정 조회·경로 재계산 응답에서 누락된 상세정보를 Google Places로 보완합니다. 현재 프런트가 사용하는 `address` 필드를 유지하고 원본의 `formattedAddress`도 함께 제공합니다. 영업일은 주간 정보, 영업시간은 방문 요일의 정보로 표시합니다.

응답 표시 과정은 DB 엔티티를 변경하지 않습니다. 실제 DB를 보완하는 별도 API는 `local` 프로필에서 제공하며 이메일 로그인 인증을 요구합니다. 도시별·ID 순으로 최대 100개씩 처리하고 성공·실패·변경 없음·건너뜀 건수와 다음 ID를 반환합니다. Google 응답에 없는 값으로 기존 정보를 지우지 않습니다.

반복 상세 조회는 최대 512개까지 메모리에 캐시합니다. 성공은 30분, 실패는 1분 유지합니다. 공항/고정일정 등 시스템 기록과 자유시간 기록은 Google 조회에서 제외합니다. HTTP 연결 제한은 5초, 응답 제한은 10초입니다.

Google이 주소·전화·영업정보를 제공하지 않는 장소는 여전히 정보가 없을 수 있습니다. 표시하는 영업시간은 **정규 주간 영업시간**이며 미래 방문일의 공휴일·임시 휴무를 보장하지 않습니다. 요일 배열 순서는 언어별로 다를 수 있어 요일 이름을 대조하며, 판별할 수 없으면 주간 정보 전체를 유지합니다. [Google Places 필드 설명](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places#OpeningHours)

## 실행

1. 기존 백엔드를 실행하던 창에서 Ctrl+C 후, 기존 DB 환경변수를 그대로 사용해 다시 시작합니다.

```powershell
cd "C:\Users\USER\Desktop\TravelPlanner_GitHub_refresh\TravelPlanner_Backend"
.\gradlew.bat bootRun --args="--spring.profiles.active=local"
```

2. 기존 저장 일정을 열거나 새 일정을 만들면 누락 상세정보 조회가 작동합니다. Google Places API 키 및 API 사용 권한이 필요하고, 사용량에 따라 과금될 수 있습니다.

3. DB에도 보완 정보를 저장하려면 서버가 실행된 상태에서 아래 도구를 실행합니다. 이메일은 실제 앱 로그인 이메일로 바꿉니다. 비밀번호는 별도 입력을 받으며 출력하지 않습니다.

```powershell
.\tools\backfill_place_details.ps1 -City '도쿄' -Email '본인 앱 이메일' -Limit 20 -MaxBatches 1
```

기본은 20개 행을 확인하는 한 묶음입니다. `done`이 false이면 다음 실행에서 반환된 `nextAfterId` 값을 `-AfterId`에 넣습니다. `failed`가 있으면 서버 로그/API 설정을 확인하고 실패한 구간의 시작 ID부터 재시도합니다. Google 조회는 정보가 부족한 실제 장소만 수행합니다. 전체 도시를 처리하려면 `-MaxBatches`를 명시적으로 늘릴 수 있습니다.

로컬 프로필의 상세 수집/표시는 기본 켜짐입니다. 끄려면 서버 시작 전에 환경변수 `PLACE_DETAILS_ENABLED=false`, `PLACE_DISPLAY_ENABLED=false`를 설정합니다. DB 보완 API는 도구를 명시적으로 실행할 때만 동작합니다.

주소/전화/영업일 컬럼이 없다는 오류가 난다면 기존 `database\upgrade_place_details.sql`의 대상 DB 이름을 실제 DB와 확인한 후 적용합니다. 이 스크립트는 컬럼만 추가하며 실제 값은 위 보완 작업으로 채웁니다. 전체 DB 덤프를 다시 가져올 필요는 없습니다.

## 검증과 실행 범위

Java 메인 코드 및 테스트 코드를 컴파일하고, 관련 회귀 테스트 14개가 모두 통과했습니다. DB 연결을 요구하는 전체 Spring 컨텍스트 테스트는 실행하지 않았습니다. 실제 사용자 DB의 일괄 갱신과 실제 Google API 호출은 실행하지 않았습니다. 따라서 이번 변경은 코드 반영 완료이며 DB 전체의 상세정보가 이미 채워졌다는 의미는 아닙니다. 서버 재시작 후 실제 연동을 확인해야 합니다.

GitHub 원격 저장소에는 업로드하지 않았습니다. 수정 전 소스는 현재 작업의 `work/backend-before-update/src`에 백업했습니다.
