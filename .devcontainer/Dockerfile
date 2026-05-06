FROM ghcr.io/rails/devcontainer/images/ruby:4.0.3

ARG WATCHMAN_VERSION=v2026.05.04.00

USER root

COPY install-watchman.sh /tmp/install-watchman.sh
RUN WATCHMAN_VERSION="$WATCHMAN_VERSION" sh /tmp/install-watchman.sh

USER vscode
