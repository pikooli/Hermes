FROM nousresearch/hermes-agent:latest

USER root

ENV PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    ca-certificates \
    fonts-liberation \
    fonts-noto-color-emoji \
    fonts-noto-cjk \
    libnss3 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libpangocairo-1.0-0 \
    libgtk-3-0 \
    xdg-utils \
  && rm -rf /var/lib/apt/lists/*

RUN /opt/hermes/.venv/bin/python3 -m ensurepip --upgrade \
  && /opt/hermes/.venv/bin/python3 -m pip install --upgrade pip \
  && /opt/hermes/.venv/bin/python3 -m pip install "scrapling[all]" \
  && /opt/hermes/.venv/bin/scrapling install \
  && chmod -R a+rX /opt/ms-playwright
