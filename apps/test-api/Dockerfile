FROM python:3.12-alpine3.20

# Create non-root group and user (UID 10001)
RUN addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

WORKDIR /app
COPY --chown=10001:10001 app.py /app/app.py

ENV PORT=8080 \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

EXPOSE 8080
USER 10001:10001

ENTRYPOINT ["python3", "/app/app.py"]

