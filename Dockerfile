# Debian 13 (Trixie) is LTS until 2030
ARG PYTHON_VERSION=3.12
FROM python:${PYTHON_VERSION}-trixie AS builder-image

ARG DEBIAN_FRONTEND=noninteractive
# Required: the workflow passes the latest PyPI release
ARG THUMBOR_VERSION
RUN test -n "${THUMBOR_VERSION}" || (echo "THUMBOR_VERSION build arg is required" && exit 1)

RUN apt-get update && \
    apt-get -y upgrade && \
    apt-get -y autoremove && \
    apt-get install --no-install-recommends -y \
        curl \
        libssl-dev \
        libcurl4-openssl-dev \
        libjpeg-dev \
        libwebp-dev \
        libjpeg-progs \
        zlib1g-dev \
        gifsicle \
        gcc \
        libcairo2-dev \
        build-essential && \
	apt-get clean && rm -rf /var/lib/apt/lists/*

RUN python3 -m venv /home/thumbor/venv
ENV PATH="/home/thumbor/venv/bin:$PATH"

COPY requirements.txt .

RUN pip3 install --no-cache-dir wheel && \
    pip3 install --no-cache-dir -r requirements.txt && \
    pip3 install --no-cache-dir thumbor==${THUMBOR_VERSION}

FROM python:${PYTHON_VERSION}-slim-trixie AS runner-image

WORKDIR /app
RUN mkdir -p /data

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        curl \
        gifsicle \
        libcairo2 \
        libjpeg-turbo-progs \
        ffmpeg && \
	apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home thumbor
COPY --from=builder-image /home/thumbor/venv /home/thumbor/venv

RUN chown thumbor:thumbor /app
RUN chown thumbor:thumbor /data

USER thumbor

EXPOSE 8888

ENV PYTHONUNBUFFERED=1

ENV VIRTUAL_ENV=/home/thumbor/venv
ENV PATH="/home/thumbor/venv/bin:$PATH"

COPY conf/thumbor.conf.tpl /app/thumbor.conf.tpl

COPY --chmod=755 docker-entrypoint.sh /
CMD ["thumbor"]
ENTRYPOINT ["/docker-entrypoint.sh"]
