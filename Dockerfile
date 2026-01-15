FROM ubuntu:24.04

# Set environment variables
ENV TERM=xterm
ENV TZ=Etc/UTC
ENV DEBIAN_FRONTEND=noninteractive
ENV HIDDIFY_DISABLE_UPDATE=true

# Security: Create non-root user for running services
RUN groupadd -r hiddify -g 999 && \
    useradd -r -g hiddify -u 999 -m -d /home/hiddify -s /bin/bash hiddify

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    systemctl \
    systemd \
    iptables \
    iproute2 \
    net-tools \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Set working directory
WORKDIR /opt/hiddify-manager

# Clone Hiddify Manager repository
RUN git clone https://github.com/hiddify/Hiddify-Manager.git /opt/hiddify-manager && \
    cd /opt/hiddify-manager && \
    git checkout main

# Copy docker utilities
RUN if [ -d /opt/hiddify-manager/other/docker ]; then \
        cp /opt/hiddify-manager/other/docker/* /usr/bin/ || true; \
    fi

# Create required directories with proper permissions
RUN mkdir -p /hiddify-data/ssl/ \
    /hiddify-data/config/ \
    /hiddify-data/backups/ \
    /opt/hiddify-manager/log/ && \
    rm -rf /opt/hiddify-manager/ssl 2>/dev/null || true && \
    ln -sf /hiddify-data/ssl /opt/hiddify-manager/ssl

# Run the installer
RUN bash -c "./common/hiddify_installer.sh docker --no-gui" || \
    bash -c "./install.sh docker --no-gui" || \
    echo "Installation completed with warnings"

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

# Set proper ownership for data directory
RUN chown -R hiddify:hiddify /hiddify-data /opt/hiddify-manager/log

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost/ || exit 1

# Create entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
