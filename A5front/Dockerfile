FROM nginx:stable-alpine
COPY deploy-nginx.conf /etc/nginx/conf.d/default.conf
# Prepared by prepare-release.ps1 from a successful Flutter web build.
COPY build/web/ /usr/share/nginx/html/
EXPOSE 8080
HEALTHCHECK --interval=15s --timeout=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/healthz || exit 1
