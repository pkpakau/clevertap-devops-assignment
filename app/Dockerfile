# ─────────────────────────────────────────
# Build stage
# ─────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# Install dependencies into a separate dir so we can copy cleanly
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ─────────────────────────────────────────
# Runtime stage — minimal image, no build tools
# ─────────────────────────────────────────
FROM python:3.12-slim AS runtime

# Non-root user — never run as root in prod
RUN groupadd -r appuser && useradd -r -g appuser appuser

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application source
COPY src/ .

# Drop all linux capabilities at runtime
USER appuser

EXPOSE 8000

# Use exec form — signals forwarded correctly (SIGTERM for graceful shutdown)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
