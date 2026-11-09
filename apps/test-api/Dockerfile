FROM python:3.12-alpine3.21
LABEL org.opencontainers.image.source="https://github.com/arifraza128/K3s_Production_stack"
LABEL org.opencontainers.image.description="Phoenix Platform Test API (hardened, non-root, read-only rootfs)"

# Upgrade all Alpine OS packages and remove unused package managers (pip/setuptools/wheel)
# to eliminate OS & Python packaging CVEs flagged by Trivy HIGH/CRITICAL gate
RUN apk update && \
    apk upgrade --no-cache && \
    pip uninstall -y pip setuptools wheel || true && \
    rm -rf /root/.cache /var/cache/apk/* && \
    addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

WORKDIR /app
COPY --chown=10001:10001 app.py /app/app.py

ENV PORT=8080 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8080
USER 10001:10001

ENTRYPOINT ["python3", "/app/app.py"]
