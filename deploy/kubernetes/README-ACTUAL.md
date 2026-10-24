# 실제 실행 중인 Kubernetes 구성

2026-10-24부터 CentOS10 VM의 Docker 위에 kind 0.33.0 / Kubernetes1.37.0 단일 노드 클러스터를 구축한다. 노드 이름은 travelplanner-control-plane, namespace는 travelplanner다. 학습·졸업작품 시연용 구성으로, 별도 master/worker VM을 사용하는 HA 클러스터는 아니다. 기존 host containerd/실습 kubelet 설정을 대체하지 않는다.

## 포함된 Docker 이미지

- 앱: leejunhee021210/travelplanner-backend:20261024-docker01
- 웹: leejunhee021210/travelplanner-frontend:20261024-web02
- 구축 도구: leejunhee021210/travelplanner-deployer:20261024-k8s03

구축 도구 이미지에는 Docker CLI, kind, kubectl, Ansible, 실제 클러스터 구성 YAML, Pod 배포·검증·백업·복원 스크립트가 포함된다. API 키·DB·SSH 개인키는 포함하지 않는다. VM의 Docker socket 권한으로 노드 컨테이너를 만들기 때문에 신뢰하는 관리자가 명시적으로 실행한다. 앱 시작 때마다 클러스터를 중복 생성하지 않는다.

## VM에서 확인

```bash
export KUBECONFIG=/opt/travelplanner/k8s/kubeconfig
kubectl get nodes
kubectl get pods -n travelplanner
kubectl get pods -A
```

웹은 VM127.0.0.1:18081, API는18080이다. kind의 NodePort30081/30080을 해당 호스트 포트로 전달한다. Windows USB 전달은 기존 PC5173→VM18081, PC8080→VM18080으로 바꾸면 휴대폰 주소가 유지된다.

## 다른 컴퓨터에서 이미지로 구축

먼저 linux/amd64 Docker가 실행 중인 VM을 준비하고 비공개 백업을 SSH 또는 암호화 저장매체로 옮긴다. 아래 경로를 유지한다. 기본 데이터 위치는 /opt/travelplanner/k8s/shared이고, kind extraMount도 이 경로와 연결되어 있다. 기존 데이터가 있으면 복원 스크립트가 거부한다.

```bash
docker pull leejunhee021210/travelplanner-deployer:20261024-k8s03
# 처음 데이터 복원: /안전한/백업폴더를 실제 경로로 변경한다.
docker run --rm --network host -v /var/run/docker.sock:/var/run/docker.sock -v /opt/travelplanner:/opt/travelplanner -v /안전한/백업폴더:/import:ro leejunhee021210/travelplanner-deployer:20261024-k8s03 restore
# 실제 클러스터 생성과 앱 배포
docker run --rm --network host -v /var/run/docker.sock:/var/run/docker.sock -v /opt/travelplanner:/opt/travelplanner leejunhee021210/travelplanner-deployer:20261024-k8s03 bootstrap
```

반복 bootstrap은 기존 클러스터를 재생성하지 않고 선언적 apply를 실행한다. Pod health와 nginx→API 프록시까지 확인한다. Docker Hub의 immutable digest는 별도 lock 파일에 기록한다. Ansible의 kind.yml이 실제 위 절차를 실행하며, 기존 kubernetes.yml은 별도 VM kubeadm 전환용이다.

## 현재 데이터 백업

```bash
docker run --rm --network host -v /var/run/docker.sock:/var/run/docker.sock -v /opt/travelplanner:/opt/travelplanner leejunhee021210/travelplanner-deployer:20261024-k8s03 backup /opt/travelplanner/k8s/backups/새이름
```

백업 동안 backend를0개로 줄여 쓰기를 중단하고 SQL·SQLite를 복사한 뒤 원래 replica 수로 복구한다. 백업에 회원 정보·비밀키가 있으므로 공개 업로드하지 않는다. 다른 호스트에는 kubeconfig를 복사하지 말고 도구 이미지로 새 클러스터를 만든다.

기존 Compose와 Kubernetes의 DB 저장소는 별도다. 운영 중인 한 쪽만 기준으로 사용해야 데이터가 갈라지지 않는다. 앱 버전 실패 복구는 previous-good manifest를 재적용하며 DB 자체는 과거 상태로 덮어쓰지 않는다. DB 이전·스키마 변경이 필요한 경우 별도 백업/복원 절차를 따른다.

공식 근거: https://kind.sigs.k8s.io/docs/user/quick-start/ 및 https://kind.sigs.k8s.io/docs/user/configuration/
