# syntax=docker/dockerfile:1
FROM docker:29.8.2-cli AS dockercli
FROM python:3.12-slim-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl bash openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir ansible-core==2.21.5 PyYAML==6.0.3
COPY --from=dockercli /usr/local/bin/docker /usr/local/bin/docker
ARG KIND_VERSION=v0.33.0
ARG KIND_SHA256=aee6151561422756b764a4ae28e7f44cda5af5a9eead3cc9985112b1de8d8e0d
ARG KUBECTL_VERSION=v1.37.1
RUN curl -fsSL "https://github.com/kubernetes-sigs/kind/releases/download/${KIND_VERSION}/kind-linux-amd64" -o /usr/local/bin/kind \
    && echo "${KIND_SHA256}  /usr/local/bin/kind" | sha256sum -c - \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" -o /usr/local/bin/kubectl \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256" -o /tmp/kubectl.sha256 \
    && echo "$(cat /tmp/kubectl.sha256)  /usr/local/bin/kubectl" | sha256sum -c - \
    && chmod 755 /usr/local/bin/kind /usr/local/bin/kubectl
WORKDIR /opt/travelplanner-deploy
COPY deploy ./deploy
COPY images.lock.env ./images.lock.env
RUN chmod +x deploy/tooling/entrypoint.sh
ENV KUBECONFIG=/opt/travelplanner/k8s/kubeconfig
ENTRYPOINT ["/opt/travelplanner-deploy/deploy/tooling/entrypoint.sh"]
