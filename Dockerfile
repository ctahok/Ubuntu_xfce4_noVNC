FROM ubuntu:22.04

LABEL maintainer="IJ <ij@klaud.uk>"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ── Stage 1: base tools + repo setup ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common \
        curl \
        ca-certificates \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# Node.js 18 LTS via NodeSource (Ubuntu 22.04 ships v12 by default, too old for audify)
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash -

# Firefox: Ubuntu 22.04 ships firefox as a Snap which cannot run inside Docker.
# The Mozilla PPA provides a proper .deb build.
RUN add-apt-repository -y ppa:mozillateam/ppa \
    && printf 'Package: firefox*\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 501\n' \
       > /etc/apt/preferences.d/mozillateamppa

# ── Stage 2: install all packages ─────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        sudo git wget \
        # Desktop environment
        xfce4 xfce4-terminal xfce4-pulseaudio-plugin \
        # Icons  (replaces faenza-icon-theme, which is not in Ubuntu repos)
        papirus-icon-theme \
        # Python
        python3 \
        # VNC server  (replaces Alpine's "tigervnc" metapackage)
        tigervnc-standalone-server tigervnc-common \
        # Browser
        firefox \
        # Build tools  (replaces Alpine's "build-base" + "alsa-lib-dev")
        cmake build-essential \
        libasound2 libasound2-dev libasound2-plugins \
        # Audio
        pulseaudio pavucontrol \
        alsa-utils \
        # Node.js (installed from NodeSource repo above)
        nodejs \
        # Extras needed for a stable XFCE4 session inside Docker
        dbus-x11 x11-xserver-utils \
    && rm -rf /var/lib/apt/lists/*

# ── Stage 3: create user + fetch noVNC ────────────────────────────────────────
RUN useradd -m -s /bin/bash -d /home/ubuntu ubuntu \
    && echo "ubuntu:ubuntu" | chpasswd \
    && echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && git clone https://github.com/novnc/noVNC /opt/noVNC \
    && git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify \
    && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/script.js    -O /opt/noVNC/script.js \
    && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/audify.js    -O /opt/noVNC/audify.js \
    && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/vnc.html     -O /opt/noVNC/vnc.html \
    && wget https://raw.githubusercontent.com/novaspirit/Alpine_xfce4_noVNC/dev/pcm-player.js -O /opt/noVNC/pcm-player.js

# ── Stage 4: install Node.js dependencies ─────────────────────────────────────
RUN npm install --prefix /opt/noVNC ws
RUN npm install --prefix /opt/noVNC audify

# ── Stage 5: configure VNC as the ubuntu user ─────────────────────────────────
USER ubuntu
WORKDIR /home/ubuntu

RUN mkdir -p /home/ubuntu/.vnc \
    && echo "-SecurityTypes=none" > /home/ubuntu/.vnc/config \
    && printf '#!/bin/bash\nstartxfce4 &\n' > /home/ubuntu/.vnc/xstartup \
    && chmod +x /home/ubuntu/.vnc/xstartup \
    && printf "ubuntu\nubuntu\nn\n" | vncpasswd

# ── Stage 6: write the entrypoint script ──────────────────────────────────────
USER root

RUN printf '#!/bin/bash\n\
/usr/bin/vncserver :99 2>&1 | sed "s/^/[Xtigervnc ] /" &\n\
sleep 1\n\
/usr/bin/pulseaudio --daemonize=no 2>&1 | sed "s/^/[pulseaudio] /" &\n\
sleep 1\n\
/usr/bin/node /opt/noVNC/audify.js 2>&1 | sed "s/^/[audify    ] /" &\n\
/opt/noVNC/utils/novnc_proxy --vnc localhost:5999 2>&1 | sed "s/^/[noVNC     ] /"\n' \
> /entry.sh \
&& chmod +x /entry.sh

USER ubuntu

ENTRYPOINT [ "/bin/bash", "/entry.sh" ]
