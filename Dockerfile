# =============================================================
# Stage 1 — Builder
# Install dependencies in an isolated build environment.
# This stage is discarded; only its /install output is copied.
# =============================================================
FROM python:3.12-slim AS builder

WORKDIR /build

# Copy only requirements first to leverage Docker layer caching.
# Rebuilds only when requirements.txt changes.
COPY app/requirements.txt .

# Install packages into a prefix directory so they can be
# cleanly copied into the final stage without pip metadata.
RUN pip install --upgrade pip \
    && pip install --prefix=/install --no-cache-dir -r requirements.txt


# =============================================================
# Stage 2 — Runtime (final image)
# Minimal image; no build tools, no pip, no root user.
# =============================================================
FROM python:3.12-slim AS runtime

# Security: create a non-root user and group
RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

WORKDIR /app

# Copy installed packages from the builder stage
COPY --from=builder /install /usr/local

# Copy application source code
COPY app/ .

# Drop to non-root user — all subsequent RUN/CMD execute as appuser
USER appuser

# Document the port the app listens on (informational; does not publish it)
EXPOSE 5000

# Health check so Docker / orchestrators can detect unhealthy containers
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:5000/health')"

# Use Gunicorn (production WSGI server) instead of Flask's dev server
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "30", "app:app"]
