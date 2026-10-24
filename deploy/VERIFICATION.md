# 실제 검증 결과 (2026-10-24)

| 항목 | 결과 |
|---|---|
| 수업 자료 분석 | 06_Docker·07_Kubernetes의 HWP/HWPX 36개, 기존 소스·VM 검사 |
| VM | minikube만 실행, CentOS Stream10 / 8vCPU / 8GB 설정 / 60GB 디스크 |
| root SSH | 승인된 공개키 추가, 기존 키 보존, 키 인증 성공 |
| Docker 이미지 빌드 | backend Java25 multi-stage 성공, frontend Flutter web release + nginx 성공 |
| 이미지 크기 | backend 약 693MiB, frontend 약 144MiB (Docker 보고 비압축 크기) |
| 공개 이미지 비밀값 검사 | 빌드 context allowlist, 설정/DB 제외. 소스 및 웹 빌드의 Google/OpenAI/GitHub 키 패턴 미발견 |
| Docker Hub push | backend·frontend 20261024-docker01 성공. images.lock.env digest 기록 |
| 익명 pull | 임시 registry 인증 삭제 후 저장된 digest로 pull 성공 |
| SQL 및 SQLite 복원 | Windows 원본 파일 변경 없이 새 VM 저장공간에 SQL3개·SQLite backup 복원 |
| 초기 Compose 실행 | 세 서비스 healthy 검증 완료. 현재는 Kubernetes로 전환해 Compose 컨테이너를 정지하고 원본 DB를 보존 |
| HTTP | 웹 index200, nginx 경유 readiness200, API SELECT1 성공 |
| 자동화 구문 | Compose / Bash / YAML / Ansible5개 playbook 통과 |
| Ansible 멱등성 | 최종 재실행 ok8 changed0 failed0 |
| 재배포 멱등성 | 정상 버전 반복 실행 DEPLOY_CHANGED=0 |
| 실패 복구 | 즉시 종료하는 검증용 웹 이미지 배포 실패 후 이전 정상 버전 자동 복원, health 및 current 포인터 확인 |
| 이전용 백업 | VM의 현재 SQL·SQLite·설정·비밀 파일을 쓰기 중단 후 일관성 백업, backend 재개 |
| 복원 검증 | 같은 VM 내 별도 프로젝트·포트·빈 저장소에 이미지 pull + DB 복원 + 세 서비스 healthy 확인. 검증 컨테이너는 정지하고 데이터 보존 |
| 임시 Docker 인증 | /run의 작업 전용 인증 폴더 제거 확인 |
| firewalld | 기존 disabled/inactive 유지 |
| SELinux | 2026-10-24 재부팅 후 Disabled 확인, 커널 부팅 인자 selinux=0 확인 |
| 휴대폰 USB | 2026-10-24 S24(SM-S926N) Windows ADB device 확인. SSH tunnel + ADB reverse 8080/5173 구성, PC 경유 API UP·웹200 확인, 휴대폰 Chrome 실행 명령 성공. guest 직접 passthrough·로그인/일정 생성은 미검증 |
| 다른 물리 컴퓨터 | 아직 옮기지 않았으므로 실제 다른 컴퓨터 검증은 미완료 |
| Kubernetes | kind0.33.0 / Kubernetes1.37.0 실제 클러스터 구축. 백엔드·프론트·DB Pod 모두 Running/Ready. 구축 도구 Docker 이미지 실행 검증 |
| 앱 전체 일정 생성 | 이번 Docker 검증에서 로그인·일정 생성 끝까지의 UI 검증은 미실행 |
| 푸시 알림 | Firebase 서비스 계정 파일이 현재 없어 FCM 미초기화. 알림 전송 미검증 |

현재 실행: Kubernetes API VM127.0.0.1:18080 / 웹18081. Windows SSH tunnel은 PC8080→VM18080, PC5173→VM18081로 연결한다. 공유 설정의 원본 SQL 기준은 10월22일이며 현재 Windows MariaDB의 최신 상태를 직접 dump한 것은 아니다.

운영 데이터: /opt/travelplanner/shared. 이전용 비공개 백업: /opt/travelplanner/backups/migration-20261024. 검증용 복원 데이터: /opt/travelplanner-restore-test-v2/shared. 검증 실패 때의 초기 복사본도 보존했다. 이 경로의 DB·secret 파일을 공개 저장소나 이미지에 올리지 않는다.

추가 확인(2026-10-24): 사용자가 VM 재부팅 후 root SSH로 직접 접속해 Docker active, 세 컨테이너 자동 시작 및 healthy, 웹200·API 프록시200을 재검증했다. guest USB 목록에 휴대폰은 아직 없다.

휴대폰 연결 추가(2026-10-24): Windows 소유 USB 방식으로 연결했다. 휴대폰 Chrome 주소는 http://127.0.0.1:5173/, API는 http://127.0.0.1:8080이다. USB 케이블과 Windows SSH 터널을 유지해야 한다. VM guest USB 소유권은 전환하지 않았다.

## Kubernetes 실제 구축 추가 검증 (2026-10-24)

- 기존 CentOS host containerd 설정 및 실습 자료를 덮어쓰지 않고 Docker 기반 단일 kind 클러스터를 만들었다.
- 노드 travelplanner-control-plane Ready, namespace travelplanner에 backend·frontend·database-0 Pod를 배포했다.
- Docker 이미지의 Ansible bootstrap을 두 번 실행해 두 번째 ok3 changed0 failed0을 확인했다.
- DB 준비 대기 initContainer와 서비스 계정 토큰 자동 마운트 비활성화를 적용했다.
- 웹18081 및 API18080, nginx를 거치는 API readiness HTTP200을 확인했다.
- 원본 Compose의 회원·일정·장소 DB와 Pod DB의 논리 데이터 SHA256이 일치함을 확인했다.
- 도구 이미지 backup/restore 명령을 실행해 SQL·SQLite·설정의 일관성 백업과 별도 빈 디렉터리 복원을 확인했다. 백엔드 replica 수 복구와 health도 확인했다.
- Docker API socket과 host network는 관리용 deployer 이미지 실행 때만 사용한다. 앱 Pod에 Docker socket을 주지 않는다.
- Kubernetes Secret의 원본 호스트 파일은 root 소유0600이다. API 키나 DB를 registry 이미지에 넣지 않았다.
- kind는 시연용 단일 노드 Kubernetes이며 별도 VM 다중 노드 HA를 검증한 것은 아니다. 다른 물리 컴퓨터의 실제 재구축은 아직 미검증이다.

노드 컨테이너 재시작 후 모든 시스템/앱 Pod와 데이터가 복구되고 API200을 확인했다. 초기 네트워크 복구 지연에 대응하도록 health 검증에 제한된 재시도를 추가했다.

최종 확인: deployer:20261024-k8s03를 Docker Hub에 push했고 임시 인증 없이 digest로 pull했다. 이미지 내부의 cluster/deploy/Ansible/backup/restore 파일 존재와 도구 버전을 확인했다. 최종 구성은 노드 재시작 후 K8S_NODE_RESTART_RECOVERY_OK, 잘못된 배포 설정 거부 후 K8S_FAILED_APPLY_RECOVERY_OK를 통과했다. Windows USB 터널을 Pod NodePort로 전환해 API UP·웹200 및 휴대폰 ADB reverse 두 포트를 확인했다. 기존 Compose 컨테이너는 정지 상태로 보존했다. 기본 root kubectl context는 kind-travelplanner, namespace는 travelplanner다.

다른 물리 컴퓨터에서 실제 재구축 및 휴대폰에서 로그인/일정 생성 전체 흐름은 아직 미검증이다. Kubernetes 클러스터·Pod·HTTP·USB 전달 계층의 동작 확인과 구분한다.

## 연결 오류 수정 (2026-10-24)

서버와 USB 전달은 정상인데 클라이언트의 API_BASE_URL=/ 값이 잘못 해석되는 문제를 수정했다. Dio가 /와 /api 경로를 합치면 //api/... 형태가 될 수 있어, 웹은 현재 페이지의 origin으로 바꾸고 네이티브는 절대 USB 주소를 사용한다. 회귀/기존 로그인 테스트13개 통과, Android debug APK를 API_BASE_URL=http://127.0.0.1:8080으로 빌드해 기존 데이터 보존 설치(-r) 후 실행했다. 웹 이미지20261024-web02와 이를 포함한 구축 이미지20261024-k8s03를 push하고 Kubernetes frontend를 갱신했다. 빈 로그인 요청이 프록시를 통해400 검증 응답을 반환함을 확인했으며 실제 계정의 로그인 성공 자체는 사용자가 재시도해야 한다.
