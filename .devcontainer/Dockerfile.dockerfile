FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash-completion \
        ca-certificates \
        curl \
        direnv \
#       gcc \
        git \
#       jq \
#       less \
#       libaom3 \
#       libatomic1 \
#       libc6 \
#       libexpat1 \
#       libffi-dev \
#       libglib2.0-0 \
#       libgnutls30 \
#       libkrb5-3 \
#       libsndfile1 \
#       libssl3 \
#       libssl-dev \
#       libxml2 \
#       libxslt1.1 \
#       musl-dev \
#       nano \
#       openssl \
#       pkg-config \
        sudo \
        tzdata \
        wget \
        xz-utils \
    && rm -rf /var/lib/apt/lists/*

#RUN python -m venv ${HOME}/venv

#RUN python -m pip install build uv hatchling

#RUN uv install -r requirements.txt

#RUN npm install -g npm@latest tar@7.5.11 glob@11.1.0 @isaacs/brace-expansion@5.0.1 minimatch@10.2.4 diff@8.0.3 

RUN printf '%s\n' \
  '' \
  '# mise and direnv hooks for non-root interactive bash shells' \
  'if [ -n "${BASH_VERSION:-}" ] && [ "$EUID" -ne 0 ] && command -v direnv >/dev/null 2>&1; then' \
  '  eval "$(direnv hook bash)"' \
  '  eval "$(mise activate bash)"' \
  '  eval "$(mise trust .)"' \
  '  eval "$(mise install)"' \
  'fi' \
  >> /etc/bash.bashrc

USER vscode