FROM ubuntu:24.04

ENV TERM=xterm
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV HIDDIFY_DISABLE_UPDATE=true

USER root
WORKDIR /opt/hiddify-manager

# Install basic system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git ca-certificates curl wget unzip \
        python3 python3-pip python3-venv python3-dev \
        build-essential libssl-dev pkg-config \
        default-libmysqlclient-dev \
        redis-tools mysql-client \
        nginx supervisor cron \
        iproute2 iptables jq && \
    rm -rf /var/lib/apt/lists/*

# Clone Hiddify Manager repository
RUN git clone --depth 1 https://github.com/hiddify/Hiddify-Manager.git /opt/hiddify-manager && \
    cd /opt/hiddify-manager && \
    git submodule update --init --recursive || true

# Install Python dependencies in virtual environment
RUN python3 -m venv /opt/hiddify-manager/.venv313 && \
    /opt/hiddify-manager/.venv313/bin/pip install --no-cache-dir --upgrade pip wheel && \
    /opt/hiddify-manager/.venv313/bin/pip install --no-cache-dir \
        Flask Flask-SQLAlchemy mysqlclient redis celery \
        gunicorn requests cryptography pyyaml python-dotenv || \
    echo "Some pip packages failed, continuing..."

# Install hiddify-panel if available
RUN if [ -d "/opt/hiddify-manager/hiddify-panel/src" ]; then \
        /opt/hiddify-manager/.venv313/bin/pip install --no-cache-dir \
        /opt/hiddify-manager/hiddify-panel/src || true; \
    fi

# Create necessary directories
RUN mkdir -p /hiddify-data/ssl/ \
             /opt/hiddify-manager/log/system/ \
             /opt/hiddify-manager/ssl && \
    ln -sf /hiddify-data/ssl /opt/hiddify-manager/ssl

# Create a simple systemctl wrapper for Docker
RUN printf '#!/bin/bash\n\ncase "$1" in\n  start|stop|restart|reload|enable|disable|is-active|status)\n    echo "systemctl $@: OK (Docker mode)"\n    exit 0\n    ;;\n  *)\n    echo "systemctl $@"\n    exit 0\n    ;;\nesac\n' > /usr/bin/systemctl && \
    chmod +x /usr/bin/systemctl

# Set environment for Python venv
ENV PATH="/opt/hiddify-manager/.venv313/bin:$PATH"
ENV PYTHONPATH="/opt/hiddify-manager:/opt/hiddify-manager/hiddify-panel"
ENV VIRTUAL_ENV="/opt/hiddify-manager/.venv313"

# Copy custom entrypoint
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 80 443

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
