# shudack/thumbor Docker Image

[
  ![](https://img.shields.io/docker/v/shudack/thumbor?style=plastic&sort=date)
  ![](https://img.shields.io/docker/pulls/shudack/thumbor?style=plastic)
  ![](https://img.shields.io/docker/stars/shudack/thumbor?style=plastic)
  ![](https://img.shields.io/docker/image-size/shudack/thumbor?style=plastic)
  ![](https://img.shields.io/github/actions/workflow/status/shudack/thumbor-docker/build.yml?branch=main&style=plastic)
](https://hub.docker.com/r/shudack/thumbor)
[
  ![](https://img.shields.io/github/last-commit/shudack/thumbor-docker?style=plastic)
](https://github.com/shudack/thumbor-docker)

# Overview
This is an unofficial [Thumbor](https://github.com/thumbor/thumbor) Docker image. Thumbor is an on-demand image service: crop, resize, filter and optimize images by changing the URL.

The image is built on Debian 13 (Trixie) with Python 3.12 and is rebuilt automatically: a scheduled GitHub Actions workflow checks PyPI every day and publishes a new image as soon as a new Thumbor release appears. Images are published for `linux/amd64` and `linux/arm64`.

- Docker Hub: [shudack/thumbor](https://hub.docker.com/r/shudack/thumbor)
- Thumbor docs: [thumbor.readthedocs.io](https://thumbor.readthedocs.io)

# Tags
- `latest` — the most recent Thumbor release.
- `X.Y.Z` — a specific Thumbor release (e.g. `7.7.7`), matching the version on PyPI.

# Features
- Automatic Release Builds — A new image is published whenever a new Thumbor version lands on PyPI.
- Multi-stage Build — Build tooling stays in the builder stage; the runtime image is based on `python:slim-trixie`.
- Runs as Non-root — Thumbor runs as the `thumbor` user.
- Configuration via Environment Variables — `thumbor.conf` is generated from a template at startup, no config file needed.
- Bundled Extensions — Includes `tc-core`, `tc_redis` (Redis storage), `remotecv` and OpenCV (face and feature detection), `cairosvg` (SVG support) and `pycurl`.
- Image Tooling Included — `gifsicle`, `jpegtran` and `ffmpeg` are installed in the image.

# Ports
- 8888 — Thumbor HTTP (exposed by the image)

Thumbor listens on the port set by `THUMBOR_PORT`, which **defaults to `80`** inside the container. To use the exposed port, set `THUMBOR_PORT=8888` and map it, or map your host port to container port 80.

# Volumes
`/data` — Default location for the file loader (`/data/loader`), file storage (`/data/storage`) and result storage (`/data/result_storage`). Mount it if you want images and cached results to survive container restarts.

# Configuration
Every setting in [conf/thumbor.conf.tpl](conf/thumbor.conf.tpl) can be overridden with an environment variable of the same name. Anything you don't set falls back to the default in the template.

| Variable | Default | Description |
|---|---|---|
| `THUMBOR_PORT` | `80` | Port Thumbor listens on |
| `THUMBOR_NUM_PROCESSES` | `1` | Number of Thumbor processes |
| `LOG_LEVEL` | unset | Log level passed to Thumbor |
| `SECURITY_KEY` | `MY_SECURE_KEY` | Key used to sign URLs. **Change this in production.** |
| `ALLOW_UNSAFE_URL` | `True` | Allow the `/unsafe/` URL form. Set to `False` in production. |
| `ALLOWED_SOURCES` | `[]` | List of regexes for domains the HTTP loader may fetch from |
| `LOADER` | `thumbor.loaders.http_loader` | Image loader module |
| `STORAGE` | `thumbor.storages.file_storage` | Storage for original images |
| `RESULT_STORAGE` | `thumbor.result_storages.file_storage` | Storage for generated images |
| `AUTO_WEBP` / `AUTO_AVIF` | `False` | Serve WebP/AVIF when the `Accept` header allows it |
| `DETECTORS` | `[]` | Detectors for smart cropping |
| `HEALTHCHECK_ROUTE` | unset | Enables a health check route at this path |

Settings for the Redis, MongoDB, Memcache, AWS S3 (`tc_aws`), Google Cloud Storage, Sentry, StatsD, Prometheus and HTTP loader options are available the same way. See the template for the full list.

Values are inserted into a Python config file, so lists and booleans are written as Python literals, e.g. `DETECTORS=['thumbor.detectors.face_detector']` and `AUTO_WEBP=True`.

If you mount your own file at `/app/thumbor.conf`, the template is skipped and your file is used as is.

# Docker run example
```
docker run -d --name thumbor \
  -p 8888:8888 \
  -e THUMBOR_PORT=8888 \
  -e SECURITY_KEY=change-me \
  -e ALLOW_UNSAFE_URL=False \
  -v /path/to/data:/data \
  shudack/thumbor:latest
```

Then request a signed URL, or with `ALLOW_UNSAFE_URL=True`:
```
http://localhost:8888/unsafe/300x200/https://example.com/image.jpg
```

# Docker-compose examples
Environment variables are written as `NAME: value` (no spaces around `=`), and `THUMBOR_PORT` is set so Thumbor listens on the mapped port 8888.

## Redis as storage
```
services:
  thumbor:
    image: shudack/thumbor:latest
    container_name: thumbor
    restart: unless-stopped
    environment:
      THUMBOR_PORT: 8888
      STORAGE: tc_redis.storages.redis_storage
      REDIS_STORAGE_IGNORE_ERRORS: "True"
      REDIS_STORAGE_SERVER_PORT: 6379
      REDIS_STORAGE_SERVER_HOST: redis
      REDIS_STORAGE_SERVER_DB: 0
      REDIS_STORAGE_SERVER_PASSWORD: "None"
      REDIS_STORAGE_MODE: single_node
      RESULT_STORAGE: tc_redis.result_storages.redis_result_storage
      REDIS_RESULT_STORAGE_IGNORE_ERRORS: "True"
      REDIS_RESULT_STORAGE_SERVER_PORT: 6379
      REDIS_RESULT_STORAGE_SERVER_HOST: redis
      REDIS_RESULT_STORAGE_SERVER_DB: 0
      REDIS_RESULT_STORAGE_SERVER_PASSWORD: "None"
      REDIS_RESULT_STORAGE_MODE: single_node
    links:
      - redis:redis
    ports:
      - 8888:8888
    depends_on:
      - redis

  redis:
    image: redis:latest
    container_name: redis
    restart: unless-stopped
    ports:
      - 6379:6379
```

## Local storage
```
services:
  thumbor:
    image: shudack/thumbor:latest
    container_name: thumbor
    restart: unless-stopped
    environment:
      THUMBOR_PORT: 8888
    volumes:
      - /opt/docker/thumbor/data:/data
    ports:
      - 8888:8888
```

The repository's [docker-compose.yml](docker-compose.yml) builds the image locally instead.

# Building locally
`THUMBOR_VERSION` is a required build argument:
```
docker build --build-arg THUMBOR_VERSION=7.7.7 -t thumbor .
```
`PYTHON_VERSION` (default `3.12`) can also be overridden.

# Default Command
```
thumbor --port=$THUMBOR_PORT --conf=/app/thumbor.conf --processes=$THUMBOR_NUM_PROCESSES --log-level=warning --app tc_core.app.App
```
Passing any other command to the container runs it instead of Thumbor.

# Security
The defaults are meant for trying things out. Before exposing Thumbor publicly, set your own `SECURITY_KEY`, set `ALLOW_UNSAFE_URL=False`, and restrict `ALLOWED_SOURCES`.

# Release notes

### 2024-01-29
**UPDATE**
- Update the Thumbor version to 7.7.7
- Update the Python version to 3.13

### 2024-03-05
**UPDATE**
- Update the Thumbor version to 7.7.4

### 2024-01-29
**UPDATE**
- Update the Thumbor version to 7.7.3

### 2023-11-07
**UPDATE**
- Update the Thumbor version to 7.7.0
- Update the Python version to 3.9

### 2023-10-12
**UPDATE**
- Update the Thumbor version to 7.6.0

### 2023-07-11
**UPDATE**
- Update the Thumbor version to 7.5.2

### 2023-07-04
**UPDATE**
- Update the Thumbor version to 7.5.1

### 2023-06-13
**UPDATE**
- Update the Thumbor version to 7.5.0

### 2023-02-04
**UPDATE**
- Update the thumbor.conf.tpl file with the variable `ENV HTTP_LOADER_DEFAULT_USER_AGENT=Thumbor/7.0.0`

### 2023-02-03
**NEW**
- Create the docker image for thumbor
