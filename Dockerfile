FROM ubuntu:24.04

ENV TERM=xterm
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV HIDDIFY_DISABLE_UPDATE=true
ENV MODE=docker

USER root
WORKDIR /opt/hiddify-manager

# Install system dependencies required by Hiddify
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        apt-transport-https ca-certificates curl wget git unzip \
        python3 python3-pip python3-venv python3-dev \
        build-essential libssl-dev pkg-config libev-dev libevdev2 \
        default-libmysqlclient-dev \
        redis-tools mariadb-client \
        nginx cron sudo \
        iproute2 iptables jq locales lsb-release gnupg2 \
        software-properties-common && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Clone Hiddify Manager repository
RUN git clone https://github.com/hiddify/Hiddify-Manager.git /opt/hiddify-manager && \
    cd /opt/hiddify-manager && \
    git submodule update --init --recursive

# Install uv (Python package installer required by Hiddify)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    ln -s /root/.cargo/bin/uv /usr/local/bin/uv

# Create systemctl wrappers from the official repo
RUN if [ -f "/opt/hiddify-manager/other/docker/systemctl" ]; then \
        cp /opt/hiddify-manager/other/docker/systemctl /usr/bin/systemctl && \
        chmod +x /usr/bin/systemctl; \
    else \
        printf '#!/bin/bash\ncase "$1" in\n  start|stop|restart|reload|enable|disable|is-active|status|kill)\n    exit 0\n    ;;\n  *)\n    exit 0\n    ;;\nesac\n' > /usr/bin/systemctl && \
        chmod +x /usr/bin/systemctl; \
    fi

# Create systemd-cat wrapper if it exists
RUN if [ -f "/opt/hiddify-manager/other/docker/systemd-cat" ]; then \
        cp /opt/hiddify-manager/other/docker/systemd-cat /usr/bin/systemd-cat && \
        chmod +x /usr/bin/systemd-cat; \
    fi

# Create data directories
RUN mkdir -p /hiddify-data/ssl/ \
             /opt/hiddify-manager/log/system/ && \
    rm -rf /opt/hiddify-manager/ssl && \
    ln -sf /hiddify-data/ssl /opt/hiddify-manager/ssl

# Set locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Run the official Hiddify installer in docker mode
RUN bash -c "cd /opt/hiddify-manager && ./common/hiddify_installer.sh docker --no-gui" || \
    echo "Installation completed with warnings"

# Set environment for Python venv
ENV PATH="/opt/hiddify-manager/.venv313/bin:/opt/hiddify-manager/.venv/bin:$PATH"
ENV PYTHONPATH="/opt/hiddify-manager:/opt/hiddify-manager/hiddify-panel"
ENV VIRTUAL_ENV="/opt/hiddify-manager/.venv313"

# Cleanup
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# Copy custom entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
