FROM nousresearch/hermes-agent:latest@sha256:ef85c5dacd99413f4824a09673fc2d67505746716f2d531012306b1ba1005fb7

USER root

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    DEBIAN_FRONTEND=noninteractive

# Layer 1: bootstrap pip in the venv
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl ca-certificates \
 && curl -sSL https://bootstrap.pypa.io/get-pip.py | /opt/hermes/.venv/bin/python

# Layer 2: install scrapling
RUN /opt/hermes/.venv/bin/pip install --no-cache-dir "scrapling[all]"

# Layer 3: chromium + its system deps
RUN /opt/hermes/.venv/bin/python -m playwright install --with-deps chromium \
 && chmod -R a+rX /opt/ms-playwright
