FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DEFAULT_TIMEOUT=1000 \
    GARAK_VERSION=0.14.1

RUN apt-get update \
    && apt-get install -y --no-install-recommends bash ca-certificates tini \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --index-url https://download.pytorch.org/whl/cpu "torch>=2.8,<2.9"

RUN pip install "garak==${GARAK_VERSION}"

WORKDIR /workspace

COPY docker/garak/entrypoint.sh /usr/local/bin/garak-entrypoint
RUN chmod +x /usr/local/bin/garak-entrypoint

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/garak-entrypoint"]
