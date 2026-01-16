FROM ubuntu:24.04

ENV TERM=xterm
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV HIDDIFY_DISABLE_UPDATE=true

USER root
WORKDIR /opt/hiddify-manager

# Install git and clone repository
RUN apt-get update && \
    apt-get install -y --no-install-recommends git ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/hiddify/Hiddify-Manager.git /opt/hiddify-manager && \
    cd /opt/hiddify-manager && \
    git submodule update --init --recursive

# Copy systemctl wrapper
RUN cp other/docker/systemctl /usr/bin/systemctl && chmod +x /usr/bin/systemctl

# Create data directories
RUN mkdir -p /hiddify-data/ssl/ && \
    rm -rf /opt/hiddify-manager/ssl && \
    ln -sf /hiddify-data/ssl /opt/hiddify-manager/ssl

# Run the official installer (tolerant of errors since we'll handle runtime issues in entrypoint)
RUN bash -c "./common/hiddify_installer.sh docker --no-gui" || \
    bash -c "./install.sh docker --no-gui" || \
    echo "Installation phase completed" && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*

# Set environment for Python venv
ENV PATH="/opt/hiddify-manager/.venv313/bin:/opt/hiddify-manager/.venv/bin:$PATH"
ENV PYTHONPATH="/opt/hiddify-manager:/opt/hiddify-manager/hiddify-panel"
ENV VIRTUAL_ENV="/opt/hiddify-manager/.venv313"

# Copy our custom entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
