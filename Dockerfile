FROM ubuntu:22.04

LABEL maintainer="Don <novaspirit@novaspirit.com>"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# ── Stage 1: base tools + repo setup ──────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
        software-properties-common \
        curl \
        ca-certificates \
        gnupg \
    && rm -rf /var/lib/apt/lists/*

# Node.js 22 LTS via NodeSource (audify's node-abi dependency requires >=22.12.0)
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash -

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
        tigervnc-standalone-server tigervnc-common tigervnc-tools \
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
RUN useradd -m -s /bin/bash -d /home/yubuntu yubuntu \
    && echo "yubuntu:yubuntu" | chpasswd \
    && echo 'yubuntu ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && git clone https://github.com/novnc/noVNC /opt/noVNC \
    && git clone https://github.com/novnc/websockify /opt/noVNC/utils/websockify \
    && wget https://raw.githubusercontent.com/ctahok/Ubuntu_xfce4_noVNC/latest/script.js    -O /opt/noVNC/script.js \
    && wget https://raw.githubusercontent.com/ctahok/Ubuntu_xfce4_noVNC/latest/audify.js    -O /opt/noVNC/audify.js \
    && wget https://raw.githubusercontent.com/ctahok/Ubuntu_xfce4_noVNC/latest/vnc.html     -O /opt/noVNC/vnc.html \
    && wget https://raw.githubusercontent.com/ctahok/Ubuntu_xfce4_noVNC/latest/pcm-player.js -O /opt/noVNC/pcm-player.js

# ── Stage 4: update npm, then install Node.js dependencies ────────────────────
# --loglevel=error  hides deprecation/warn noise from transitive packages
# --no-fund --no-audit  suppress advisory and funding messages
RUN npm install -g npm@latest --loglevel=error --no-fund
RUN npm install --prefix /opt/noVNC ws     --loglevel=error --no-fund --no-audit
RUN npm install --prefix /opt/noVNC audify --loglevel=error --no-fund --no-audit

# ── Stage 5: configure VNC as the yubuntu user ─────────────────────────────────
USER yubuntu
WORKDIR /home/yubuntu

RUN mkdir -p /home/yubuntu/.vnc \
    && printf '#!/bin/bash\nstartxfce4 &\n' > /home/yubuntu/.vnc/xstartup \
    && chmod +x /home/yubuntu/.vnc/xstartup \
    && printf "yubuntu\nyubuntu\nn\n" | /usr/bin/tigervncpasswd \
    && echo "SecurityTypes=VncAuth" > /home/yubuntu/.vnc/config

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

USER yubuntu

ENTRYPOINT [ "/bin/bash", "/entry.sh" ]
