# OAuth 로그인 설정 — 코드 적용 완료

Google/카카오/네이버 버튼과 Spring Security 콜백을 연결했습니다. 로그인 브라우저에는 JWT를 노출하지 않으며 앱은 5분 내에 일회용 결과를 POST로 조회합니다. 브라우저 흐름의 state 검증을 유지합니다. 계정을 이메일 일치만으로 다른 가입 방식과 합치지 않습니다. 키가 없는 공급자는 정확한 설정 변수명을 안내하고 이메일 로그인은 그대로 작동합니다.

## 필요한 값
| 공급자 | Client ID에 넣을 값 | Client Secret에 넣을 값 | 콘솔에 등록할 콜백 |
|---|---|---|---|
| Google | 웹 애플리케이션 OAuth Client ID | 같은 클라이언트의 Client Secret | http://localhost:8080/login/oauth2/code/google |
| 카카오 | REST API 키 | 해당 REST API 키의 활성화된 Client Secret | http://localhost:8080/login/oauth2/code/kakao |
| 네이버 | 네이버 로그인 애플리케이션 Client ID | 같은 애플리케이션 Client Secret | http://localhost:8080/login/oauth2/code/naver |

Google Maps API 키는 로그인용 OAuth Client ID가 아닙니다. Google은 동의 화면/앱 정보와 테스트 상태의 테스트 사용자도 설정하세요. 카카오는 로그인 사용 설정과 닉네임 동의 항목을 켜고 Redirect URI를 등록하세요. 네이버는 네이버 로그인 API, 서비스 URL, Callback URL 및 개발 상태의 테스트 계정을 설정하세요. 이메일을 제공받지 못하는 카카오/네이버 계정은 공급자 ID로 내부 계정을 구분합니다.

## 가장 간단한 로컬 설정
백엔드 폴더에서 다음 명령을 한 번 실행합니다. 이미 oauth-local.properties가 있으면 덮어쓰지 말고 기존 파일을 수정하세요.

```powershell
cd C:\Users\USER\Desktop\TravelPlanner_GitHub_refresh\TravelPlanner_Backend
Copy-Item .\config\oauth-local.properties.example .\config\oauth-local.properties
notepad .\config\oauth-local.properties
```

발급받은 값을 해당 공급자의 client-id/client-secret 항목에 기입합니다. 사용할 공급자만 채워도 됩니다. 빈 공급자는 비활성화됩니다. 실제 키 파일은 .gitignore에 추가했으며 프론트나 APK에 넣지 않습니다.

파일을 만들지 않으려면 백엔드를 실행하는 PowerShell에서 아래 환경변수로 설정할 수 있습니다. ‘발급값’은 각 콘솔의 실제 값으로 바꾸세요.

```powershell
$env:OAUTH_GOOGLE_CLIENT_ID='발급값'
$env:OAUTH_GOOGLE_CLIENT_SECRET='발급값'
$env:OAUTH_KAKAO_CLIENT_ID='REST API 키'
$env:OAUTH_KAKAO_CLIENT_SECRET='발급값'
$env:OAUTH_NAVER_CLIENT_ID='발급값'
$env:OAUTH_NAVER_CLIENT_SECRET='발급값'
```

설정 후 기존 백엔드를 Ctrl+C로 중지하고 기존 시작 명령으로 재시작합니다. 프론트도 q로 중지 후 다시 실행하세요.

```powershell
cd C:\Users\USER\Desktop\TravelPlanner_GitHub_refresh\A5front
powershell -ExecutionPolicy Bypass -File .\run_mobile_usb.ps1
```

휴대폰 브라우저 콜백은 USB reverse 8080 연결이 필요합니다. 로그인용 브라우저 주소는 localhost로 통일합니다. 웹에서는 공급자 버튼을 누른 뒤 ‘브라우저 로그인 열기’를 눌러 새 탭에서 로그인하고 원래 탭으로 돌아오세요. 휴대폰에서는 브라우저를 자동으로 엽니다. 로그인 취소 버튼과 5분 만료 처리가 있습니다.

## 서버 배포 시
실제 HTTPS 서버 도메인으로 oauth.public-base-url을 설정하고 공급자 콜백도 같은 도메인으로 등록합니다. 다중 서버에서는 현재 메모리 교환 데이터/브라우저 세션을 공유하거나 해당 로그인 흐름을 같은 서버로 보내는 구성이 필요합니다. 이번 구현은 현재 단일 로컬 백엔드를 대상으로 검증했습니다.

## 확인한 결과
백엔드 단위 테스트: 잘못된 조회 비밀값 거절, 시작 키 재사용 거절, 만료/취소 후 접근 거절, JWT 일회용 수령, 공급자 일치 확인, 다른 가입 방식의 계정 연결 거절, Google 인증된 이메일 검사.
프론트 테스트: 성공 토큰 처리, 취소/이전 세션 응답 무시, 실패 및 잘못된 토큰 거절.
임시 서버: 가짜 Google Client ID/Secret으로 올바른 인가 주소와 콜백을 확인했습니다. 잘못된 state를 실제 Spring Security 필터에서 거절했고 실패를 앱에 전달했으며, 인증 없는 일정 조회는 401이었습니다. 외부 공급자 토큰을 발급받는 로그인은 실행하지 않았습니다.
실제 Client ID/Secret이 없으므로 공급자 로그인 완료는 아직 검증하지 못했습니다.

공식 설정 문서:
- https://developers.google.com/identity/protocols/oauth2/web-server
- https://developers.kakao.com/docs/ko/kakaologin/rest-api
- https://developers.naver.com/docs/login/devguide/devguide.md
