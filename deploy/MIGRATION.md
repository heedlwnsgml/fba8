# 다른 컴퓨터로 이전

실행용 이미지는 Docker Hub의 `leejunhee021210/travelplanner-backend`와 `leejunhee021210/travelplanner-frontend`를 사용한다. 업로드가 성공하면 `images.lock.env`에 실제 SHA256 digest를 기록한다. 태그만 같고 내용이 달라지는 문제를 방지하며 새 컴퓨터에서는 Flutter·Java·Gradle 없이 실행할 수 있다. 이미지에는 API 키, 비밀번호, 회원 정보, SQL 및 SQLite DB를 포함하지 않는다.

1. 빌드 컴퓨터/VM에서 `bash deploy/scripts/build-images.sh` 실행 후 `docker login -u leejunhee021210 --password-stdin`으로 인증한다. 토큰은 표준 입력으로 전달하며 저장소 파일에 적지 않는다.
2. `bash deploy/scripts/push-images.sh`를 실행한다. 성공해야 다음 단계로 진행한다. Docker Hub 저장소가 공개이면 누구나 이미지를 내려받을 수 있으므로 비밀 설정을 포함하지 않는다. 비공개 저장소이면 새 컴퓨터에서도 인증해야 한다.
3. 정상 실행 중인 VM에서 `bash deploy/scripts/export-migration.sh /안전한/새폴더`를 실행한다. 백엔드의 쓰기를 잠시 중단하고 SQL과 SQLite·설정·비밀키를 함께 백업한 다음 백엔드를 다시 시작한다. 이 폴더는 개인정보와 인증정보가 있으므로 암호화된 저장 장치 또는 SSH/SFTP로만 옮긴다. GitHub나 Docker Hub에 올리지 않는다.
4. 새 Linux VM에 Docker/Compose를 준비한다. CPU 아키텍처는 현재 빌드 대상인 linux/amd64여야 한다. ARM 컴퓨터는 amd64 Linux VM 또는 별도 ARM 이미지 빌드가 필요하다.
5. 새 VM에서 `bash <백업폴더>/deploy/scripts/import-migration.sh <백업폴더> <새버전명>`을 실행한다. 기존 데이터가 있으면 자동으로 덮어쓰지 않고 거부한다. 이미지 digest를 내려받고 빈 MariaDB에 논리 백업을 복원한다.
6. `http://127.0.0.1:8081` 웹과 `http://127.0.0.1:8080/api/v1/auth/health/ready`를 확인한다. Windows에서 VM을 사용하는 경우 SSH 포트 전달을 연결한다. 휴대폰은 해당 컴퓨터의 ADB USB 연결을 새로 설정해야 한다.

DB 복원은 애플리케이션 버전 복구와 별도다. 배포 rollback은 이미지와 설정 버전을 되돌리며 DB를 과거 상태로 덮어쓰지 않는다. 두 컴퓨터에서 같은 계정·일정을 계속 수정하면 데이터가 분기하므로 이전 후 사용할 서버 한 곳을 정한다. 공개 인터넷 노출은 기본 구성에 포함하지 않는다.

이미지 업로드와 동일 VM의 별도 빈 저장소 복원 검증 결과는 VERIFICATION.md에 기록한다. 다른 물리 컴퓨터에서의 검증은 실제 이전 후 별도로 진행한다.
