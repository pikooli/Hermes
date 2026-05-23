FROM nousresearch/hermes-agent:latest

USER root

RUN apt-get update && apt-get install -y \
  chromium \
  chromium-driver \
  ca-certificates \
  fonts-liberation \
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