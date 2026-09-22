# Debian 13 (Trixie) is LTS until 2030
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-trixie AS builder-image

ARG DEBIAN_FRONTEND=noninteractive
# Required: the workflow passes the latest PyPI release
ARG THUMBOR_VERSION
RUN test -n "${THUMBOR_VERSION}" || (echo "THUMBOR_VERSION build arg is required" && exit 1)

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        libssl-dev \
        libcurl4-openssl-dev \
        libjpeg-dev \
        libwebp-dev \
        zlib1g-dev \
        libcairo2-dev \
        build-essential && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /home/thumbor/venv
ENV PATH="/home/thumbor/venv/bin:$PATH"
ENV PIP_NO_CACHE_DIR=1

COPY requirements.txt .

RUN pip3 install wheel && \
    pip3 install -r requirements.txt && \
    pip3 install thumbor==${THUMBOR_VERSION}

FROM python:${PYTHON_VERSION}-slim-trixie AS runner-image

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        curl \
        libcurl4t64 \
        gifsicle \
        libcairo2 \
        libjpeg-turbo-progs \
        ffmpeg && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home thumbor && \
    install -d -o thumbor -g thumbor /app /data

WORKDIR /app

COPY --from=builder-image --chown=thumbor:thumbor /home/thumbor/venv /home/thumbor/venv

USER thumbor

EXPOSE 8888

ENV PYTHONUNBUFFERED=1
ENV VIRTUAL_ENV=/home/thumbor/venv
ENV PATH="/home/thumbor/venv/bin:$PATH"

COPY --chown=thumbor:thumbor conf/thumbor.conf.tpl /app/thumbor.conf.tpl

# Uses the same default port as docker-entrypoint.sh
HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD ["sh", "-c", "curl -fs http://localhost:${THUMBOR_PORT:-80}/healthcheck || exit 1"]

COPY --chmod=755 docker-entrypoint.sh /
CMD ["thumbor"]
ENTRYPOINT ["/docker-entrypoint.sh"]
