> 이 문서는 별도 VM의 kubeadm 확장안입니다. 현재 구축한 단일 VM kind 클러스터와 이미지 실행은 [README-ACTUAL.md](README-ACTUAL.md)를 참고하세요.

# Kubernetes 전환 단계 (현재 실행하지 않음)

현재 Docker VM과 별도인 빈 노드를 먼저 확인한다. 기존 containerd 설정을 대체하고 swap을 끄므로 `kube_allow_host_reconfiguration=true`는 해당 변경 영향 검토와 승인 후에만 사용한다. CentOS10/Docker 공식 repository가 준비된 노드가 대상이다. 현재 minikube VM에는 이 플레이북을 적용하지 않는다.

1. `ansible/inventory`의 control plane·worker 실제 IP를 확인해 입력한다. 예시의 빈 그룹은 의도적이다. Docker VM은 제외한다.
2. 공식 Kubernetes 문서와 CNI 제공자의 호환 표를 확인해 minor·CNI·pod CIDR을 정한다. CNI manifest를 내려받아 검토하고 SHA256을 기록한다. `ansible/kubernetes.yml`에 필요한 변수를 전달한다. repo URL은 minor별로 분리한다.
3. `ansible-playbook -i <실제inventory> kubernetes.yml -e @<비공개전환변수파일>`로 구성한다. 기존 클러스터 초기화·reset은 하지 않는다. control plane init/worker join에는 creates 조건이 있다.
4. DB와 SQLite를 migration 스크립트로 백업한다. 단일 저장 노드에 shared 데이터를 복원하고 Compose를 완전히 정지한 뒤 옮긴다. 같은 MariaDB 디렉터리를 Docker/Kubernetes에서 동시에 열면 안 된다.
5. 저장 노드에 `kubectl label node <노드명> travelplanner-storage=true --overwrite`를 적용한다. 다른 노드는 같은 label을 주지 않는다. 현재 파일은 단일 노드 저장용 hostPath 방식이며 다중 노드 HA를 의미하지 않는다. HA 전환 시 실제 StorageClass를 확인한 뒤 PVC로 변경해야 한다.
6. namespace 적용 후 비공개 파일에서 `planner-db` Secret(db_password, db_root_password)와 `planner-config` Secret(application-secret.yml, application-docker.properties)을 생성한다. Secret 값을 Git에 넣지 않는다. application 설정 파일에는 Docker와 동일한 DB 및 데이터 경로를 사용한다.
7. `application.yml`의 세 IMAGE_DIGEST를 검증된 images.lock.env 값으로 치환해 apply한다. 비공개 registry이면 imagePullSecrets를 별도 설정한다. `kubectl rollout status deployment/backend -n travelplanner`와 frontend·DB 상태를 확인한다.
8. 로컬 사용은 `kubectl -n travelplanner port-forward service/backend 8080:8080` 및 frontend `8081:8080`으로 검증하고 기존 USB ADB reverse를 재사용한다.

이 단계의 클러스터 구축·Secret 적용·Pod 실행은 별도 전환 시 검증한다. 소스 YAML이 준비됐다는 것을 실제 배포 성공으로 간주하지 않는다.

애플리케이션 배포도 ansible/kubernetes-deploy.yml로 자동화했다. kube_confirm_storage_migrated=true, 실제 저장 노드명, 세 image digest, VM 내 비공개 설정 경로를 전달한다. 전용 노드 IP와 검증된 CNI가 확인되기 전에는 실행하지 않는다.
