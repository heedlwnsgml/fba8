# Docker / Kubernetes 배포 브랜치

이 브랜치는 main의 최신 앱 코드에 Dockerfile, Kubernetes, Ansible, 배포·복구 및 USB 연결 스크립트를 추가합니다.

## 현재 배포 이미지

- backend: `leejunhee021210/travelplanner-backend:20261025-hotel03`
- frontend: `leejunhee021210/travelplanner-frontend:20261025-web05`
- 배포 도구: `leejunhee021210/travelplanner-deployer:20261025-k8s06`

이미지 자체는 Docker Hub에 있습니다. 변경되지 않는 정확한 digest는 루트 `images.lock.env`와 `deployer-image.lock.env`를 사용합니다. `deploy/images.lock.env`도 같은 버전입니다.

## 다른 컴퓨터로 이전

```powershell
git clone --branch codex/docker-deployment https://github.com/heedlwnsgml/fba8.git
cd fba8
git lfs pull
```

1. CentOS VM의 Docker 준비 및 기존 데이터 보존 여부를 확인합니다.
2. 최신 운영 데이터 백업을 별도로 복원합니다. 이 커밋은 VM 운영 DB를 GitHub에 새로 업로드하지 않았습니다. 기존 `DB/` 덤프는 이전 시점의 자료입니다.
3. API 설정·DB 비밀번호·SSH 비밀키는 별도의 비공개 파일로 전달합니다. 관리자 이메일 설정도 비공개 런타임 설정에 유지해야 합니다.
4. `deploy/kubernetes/README-ACTUAL.md`, `deploy/MIGRATION.md`의 복원/배포 절차를 따릅니다. 현재 운영은 단일 CentOS VM의 kind Kubernetes입니다.
5. Android USB 통신은 `deploy/windows/Connect-Phone.ps1` 및 `Open-ServerTunnel.ps1`를 사용합니다.

`deploy/config/application-docker.properties`에는 비밀값이 없는 기본 설정만 있습니다. 실제 `application-secret.yml`, DB 비밀번호, Docker 로그인 정보, SSH 키는 저장소에 포함하지 않습니다. Docker 인증은 필요한 컴퓨터에서 `docker login --password-stdin`으로 별도 설정합니다.

## 검증 기록

현재 실행 결과는 `deploy/ADMIN-HOTEL-PRICES-20261025.md` 및 `deploy/VERIFICATION.md`에 있습니다. 서버 이미지와 휴대폰 앱에 적용되었고 관련 회귀 테스트·HTTP 준비 상태·관리자 접근 검증을 통과했습니다. 전체 여행 신규 생성과 모든 실기기 화면의 시각 검증을 완료했다는 의미는 아닙니다.
