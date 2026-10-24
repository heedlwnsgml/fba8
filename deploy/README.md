> 현재 앱은 실제 Kubernetes Pod로 배포했습니다. 최신 운영·이전 절차는 [Kubernetes 실제 실행 안내](kubernetes/README-ACTUAL.md)를 따르세요. 아래 Compose 구성은 초기 검증 및 복구용 기록입니다.

# TravelPlanner 서버 구성

## 실제 환경

2026-10-24 확인: VMware minikube VM 192.168.10.14, CentOS Stream 10, 8 vCPU, 메모리 약 7.5 GiB, 디스크 60 GB. Docker 29.8.2, Compose 5.6.0, containerd 2.3.6, Ansible core 2.21.5. 다른 실습 VM과 기존 이미지는 보존했다.

Docker VM 한 대에서 MariaDB·백엔드·nginx 웹을 각각 분리한다. Java 25 JDK 빌드 단계와 JRE 실행 단계를 분리하고 Gradle 캐시 및 Docker context allowlist를 사용한다. 프론트는 Windows에서 Flutter release 빌드를 만든 뒤 nginx 이미지에 정적 파일만 넣는다. 현재 대상 아키텍처는 linux/amd64다.

## 선택한 배포 방식

직접 업로드·빌드·배포를 사용한다. 단일 프로젝트 시연에 Jenkins 서버·플러그인·상시 메모리를 추가할 필요가 작다. 빌드→상태 확인→Docker Hub push→digest 기록→대상 컴퓨터 pull→health 검증으로 같은 결과를 재현한다. Jenkins가 필요해지면 동일 scripts를 파이프라인에서 호출할 수 있다.

## 파일과 데이터 분리

- release: `/opt/travelplanner/releases/<버전>`: Docker 실행 설정과 immutable 이미지 참조
- persistent: `/opt/travelplanner/shared/data`, `mariadb`: SQLite와 MariaDB
- private: `shared/config`, `shared/secrets`: API·JWT·DB 설정 (이미지/Git 업로드 금지)
- current/previous: 성공한 배포 버전과 이전 버전 포인터

Windows 원본 DB는 변경하지 않고 10월22일 SQL 백업 3개와 10월24일 SQLite backup API 복사본을 VM에 복원했다. 소스 MariaDB의 현재 실시간 데이터와 동기화한 것으로 간주하지 않는다. 이후 다른 컴퓨터 이전에는 실행 중인 VM의 export-migration.sh로 최신 일관성 백업을 만든다.

## 실행과 장애 확인

`release.env`에 이미지 이름, shared 절대 경로, 포트를 지정하고 `bash deploy/scripts/deploy.sh <버전>`을 실행한다. 처음엔 빈 새 DB 디렉터리만 사용한다. 기본 API 127.0.0.1:8080, 웹 127.0.0.1:8081, DB 외부 포트는 미개방이다. Windows에서는 windows/Open-ServerTunnel.ps1로 5173→VM8081과 8080→VM8080을 전달한다. 웹은 같은 origin `/`로 API를 호출하므로 새 컴퓨터 주소를 소스에 넣지 않는다.

`docker compose --env-file release.env -f deploy/compose.yaml ps` 및 `logs --tail=100 <서비스>`로 확인한다. API readiness는 `/api/v1/auth/health/ready`, nginx는 `/healthz`다. readiness는 DB SELECT 1도 확인하며 상세 환경정보는 노출하지 않는다. `bash deploy/scripts/rollback.sh`는 previous 버전으로 복구한다. DB 스키마를 파괴하는 migration은 이 구성에서 자동 실행하지 않는다.

## 자동화

전용 Linux Python venv에 ansible-core 2.21.5를 설치해 사용했다. `ansible-playbook -i <실제 인벤토리> provision.yml`로 호스트를 준비한다. root 키는 각 컴퓨터에서 별도로 보호하고 host key를 확인한다. 실제 인벤토리·개인키는 공유 저장소에서 제외한다. SELinux 완전 비활성화와 재부팅은 기존 부팅 설정 변경 승인을 받은 뒤 tp_disable_selinux, tp_allow_reboot를 true로 적용한다. 2026-10-24 사용자 재부팅 후 SELinux Disabled 및 selinux=0을 확인했다. firewalld는 disabled/inactive다.

Kubernetes는 별도 전환 단계다. 현재 Docker VM에 kubeadm을 초기화하지 않는다. 상세는 kubernetes/README.md를 따른다.

## USB

Windows 소유 USB: 폰 USB 디버깅·PC 인증 → SSH 포트 전달 → windows/Connect-Phone.ps1 -Serial <기기번호>. Windows ADB reverse tcp:8080이 VM 백엔드로 연결된다. SSH 터널을 계속 유지한다. 포트가 점유됐으면 임의 종료하지 말고 기존 프로세스를 확인한다.

VM 소유 USB: VMware 메뉴에서 해당 휴대폰만 guest로 Connect한다. guest `lsusb`로 VID/PID를 확인하고 공식 Android platform-tools의 ADB로 기기 인증 후 `adb -s <serial> reverse tcp:8080 tcp:8080`을 설정한다. host와 guest가 같은 USB를 동시에 점유할 수 없으며 마우스·키보드를 자동 연결하지 않는다. 기기 교체 시 serial과 USB 소유 위치만 변경한다. 현재 폰이 연결되지 않아 passthrough·모바일 주요 기능은 미검증이다.

## 자료 및 공식 문서 반영

수업 자료 06_Docker 및 07_Kubernetes의 이미지·Compose·CRI·볼륨 분리 원칙을 참고했다. 예전 버전 고정보다 공식 CentOS10 설치 및 containerd2 설정을 우선했다.

- Docker CentOS: https://docs.docker.com/engine/install/centos/
- Docker 빌드: https://docs.docker.com/build/building/best-practices/
- kubeadm: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
- containerd/CRI: https://kubernetes.io/docs/setup/production-environment/container-runtimes/
- Ansible 지원 버전: https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html
- SELinux10: https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/10/html/using_selinux/changing-selinux-states-and-modes
- ADB: https://developer.android.com/tools/adb
- VMware USB: https://knowledge.broadcom.com/external/article/343950/automatically-connecting-usb-devices-at.html

다른 컴퓨터 이전은 MIGRATION.md를 따른다. 실제 검증 결과는 VERIFICATION.md에 구분한다.
