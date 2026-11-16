# ---- builder: install deps into an isolated venv ----
FROM python:3.11-slim AS builder

WORKDIR /build

# Copy only what pip needs so layer cache survives source-only changes
COPY pyproject.toml .
COPY src/ src/

RUN python -m venv /venv \
    && /venv/bin/pip install --no-cache-dir --upgrade pip \
    && /venv/bin/pip install --no-cache-dir .

# ---- final image ----
FROM python:3.11-slim

ENV PATH="/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Non-root user; -r = system account (no login shell, no home dir by default)
# Pin to UID/GID 1000 so K8s securityContext.runAsUser can reference a known value
RUN groupadd -r -g 1000 pulsewatch && useradd -r -u 1000 -g 1000 -d /app pulsewatch

WORKDIR /app

COPY --from=builder /venv /venv

# Bundle a default config; override at runtime with a volume mount
COPY config/ config/

RUN chown -R pulsewatch:pulsewatch /app

USER pulsewatch

EXPOSE 8000

ENTRYPOINT ["pulsewatch"]
CMD ["--config", "config/targets.yaml", "--port", "8000"]
