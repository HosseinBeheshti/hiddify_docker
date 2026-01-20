FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV USER=vncuser
ENV DISPLAY=:5

# Install TigerVNC and basic desktop environment
RUN apt-get update && \
    apt-get install -y \
        tigervnc-standalone-server \
        tigervnc-common \
        xfce4 \
        xfce4-goodies \
        dbus-x11 \
        sudo \
        wget \
        curl \
        vim \
        nano \
        firefox \
        iptables \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create VNC user
RUN useradd -m -s /bin/bash ${USER} && \
    echo "${USER}:password" | chpasswd && \
    echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Create VNC directory
RUN mkdir -p /home/${USER}/.vnc

# Set VNC password (default: 'vncpass')
RUN echo "vncpass" | vncpasswd -f > /home/${USER}/.vnc/passwd && \
    chmod 600 /home/${USER}/.vnc/passwd && \
    chown -R ${USER}:${USER} /home/${USER}/.vnc

# Create xstartup file
RUN echo '#!/bin/sh' > /home/${USER}/.vnc/xstartup && \
    echo 'unset SESSION_MANAGER' >> /home/${USER}/.vnc/xstartup && \
    echo 'unset DBUS_SESSION_BUS_ADDRESS' >> /home/${USER}/.vnc/xstartup && \
    echo 'exec startxfce4' >> /home/${USER}/.vnc/xstartup && \
    chmod +x /home/${USER}/.vnc/xstartup && \
    chown ${USER}:${USER} /home/${USER}/.vnc/xstartup

# Create firewall script to block localhost access
RUN echo '#!/bin/bash' > /usr/local/bin/setup-firewall.sh && \
    echo 'set -e' >> /usr/local/bin/setup-firewall.sh && \
    echo '' >> /usr/local/bin/setup-firewall.sh && \
    echo '# Flush existing rules' >> /usr/local/bin/setup-firewall.sh && \
    echo 'iptables -F OUTPUT 2>/dev/null || true' >> /usr/local/bin/setup-firewall.sh && \
    echo '' >> /usr/local/bin/setup-firewall.sh && \
    echo '# Allow loopback for VNC display :5' >> /usr/local/bin/setup-firewall.sh && \
    echo 'iptables -A OUTPUT -o lo -p tcp --dport 5905 -j ACCEPT' >> /usr/local/bin/setup-firewall.sh && \
    echo 'iptables -A OUTPUT -o lo -p tcp --dport 6005 -j ACCEPT' >> /usr/local/bin/setup-firewall.sh && \
    echo '' >> /usr/local/bin/setup-firewall.sh && \
    echo '# Block access to all other localhost services' >> /usr/local/bin/setup-firewall.sh && \
    echo 'iptables -A OUTPUT -d 127.0.0.0/8 -j REJECT' >> /usr/local/bin/setup-firewall.sh && \
    echo 'iptables -A OUTPUT -d ::1/128 -j REJECT' >> /usr/local/bin/setup-firewall.sh && \
    echo '' >> /usr/local/bin/setup-firewall.sh && \
    echo '# Allow all external traffic (internet)' >> /usr/local/bin/setup-firewall.sh && \
    echo 'iptables -A OUTPUT -j ACCEPT' >> /usr/local/bin/setup-firewall.sh && \
    echo '' >> /usr/local/bin/setup-firewall.sh && \
    echo 'echo "Firewall configured: Localhost blocked (except VNC :5), Internet allowed"' >> /usr/local/bin/setup-firewall.sh && \
    chmod +x /usr/local/bin/setup-firewall.sh

# Create entrypoint script
RUN echo '#!/bin/bash' > /usr/local/bin/docker-entrypoint.sh && \
    echo 'set -e' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Setup firewall (requires NET_ADMIN capability)' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '/usr/local/bin/setup-firewall.sh' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Switch to vncuser and start VNC' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'exec su - vncuser -c "vncserver :5 -geometry 1920x1080 -depth 24 -localhost no -fg"' >> /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /home/${USER}

EXPOSE 5905

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
