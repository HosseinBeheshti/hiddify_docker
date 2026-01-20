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

# Create simple entrypoint
RUN echo '#!/bin/bash' > /usr/local/bin/docker-entrypoint.sh && \
    echo 'set -e' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Fix hostname resolution' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "127.0.0.1 $(hostname)" >> /etc/hosts' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Fix permissions for mounted volume' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'mkdir -p /home/vncuser/.vnc' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'chown -R vncuser:vncuser /home/vncuser' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'chmod 700 /home/vncuser/.vnc' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Restore VNC password if missing' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'if [ ! -f /home/vncuser/.vnc/passwd ]; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "vncpass" | vncpasswd -f > /home/vncuser/.vnc/passwd' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  chmod 600 /home/vncuser/.vnc/passwd' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  chown vncuser:vncuser /home/vncuser/.vnc/passwd' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Restore xstartup if missing' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'if [ ! -f /home/vncuser/.vnc/xstartup ]; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "#!/bin/sh" > /home/vncuser/.vnc/xstartup' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "unset SESSION_MANAGER" >> /home/vncuser/.vnc/xstartup' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "unset DBUS_SESSION_BUS_ADDRESS" >> /home/vncuser/.vnc/xstartup' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "exec startxfce4" >> /home/vncuser/.vnc/xstartup' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  chmod +x /home/vncuser/.vnc/xstartup' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  chown vncuser:vncuser /home/vncuser/.vnc/xstartup' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Start VNC as vncuser' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'exec su - vncuser -c "vncserver :5 -geometry 1920x1080 -depth 24 -localhost no -fg"' >> /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /home/${USER}

EXPOSE 5905

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
