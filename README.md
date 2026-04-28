# Ubuntu xfce4 noVNC

A Docker image providing a full **XFCE4 desktop with audio** accessible through a browser via **noVNC** — based on **Ubuntu 22.04 LTS**, converted from the original Alpine Linux version by [novaspirit](https://github.com/novaspirit/Alpine_xfce4_noVNC).

<div align="center">

![preview](preview.png?raw=true "preview")

</div>

---

## What's inside

| Component | Package / version |
|-----------|------------------|
| Base OS | Ubuntu 22.04 LTS |
| Desktop | XFCE4 |
| VNC server | TigerVNC (`tigervnc-standalone-server`) |
| noVNC | latest from GitHub |
| Browser | Firefox (Mozilla PPA `.deb`, not Snap) |
| Audio | PulseAudio + audify bridge |
| Node.js | 18 LTS (NodeSource) |
| Icons | Papirus icon theme |

---

## Changes from the Alpine version

| Area | Alpine original | Ubuntu 22.04 |
|------|----------------|--------------|
| Base image | `alpine:3.16` | `ubuntu:22.04` |
| Package manager | `apk add` | `apt-get install` |
| VNC package | `tigervnc` | `tigervnc-standalone-server tigervnc-common` |
| Build tools | `build-base` + `alsa-lib-dev` | `build-essential` + `libasound2-dev` |
| ALSA plugins | `alsa-plugins-pulse` + `pulseaudio-alsa` | `libasound2-plugins` + `alsa-utils` |
| Icon theme | `faenza-icon-theme` | `papirus-icon-theme` |
| Node.js | Default Alpine package | Node.js 18 LTS via NodeSource |
| Firefox | `firefox` (apk) | `firefox` via Mozilla PPA `.deb`* |
| Default user | `alpine` | `ubuntu` |
| `xstartup` | Not marked executable | `chmod +x` applied |
| PulseAudio | `pulseaudio` | `pulseaudio --daemonize=no` (container-friendly) |
| Session extras | — | `dbus-x11`, `x11-xserver-utils` added |

> \* Ubuntu 22.04 ships Firefox as a **Snap** by default, which cannot run inside Docker containers. This image pins Firefox to the **Mozilla Team PPA** to get a proper `.deb` build.

---

## Build

```sh
git clone https://github.com/ctahok/Ubuntu_xfce4_noVNC.git
sudo docker build -t ubuntu-xfce4 Ubuntu_xfce4_noVNC/
```

The build takes a few minutes the first time (downloads XFCE4, Firefox, noVNC, and Node packages).

---

## Run

```sh
docker run -it -p 6080:6080 -p 56780:56780 --name ubuntu-novnc ubuntu-xfce4
```

| Port | Service |
|------|---------|
| `6080` | noVNC web interface |
| `56780` | Audio WebSocket (audify) |

---

## Connect

Open a modern browser and navigate to:

```
http://<docker-host-ip>:6080/vnc.html
```

The predefined VNC password is **`ubuntu`**.

---

## Ports summary

| Container port | Host port | Description |
|----------------|-----------|-------------|
| 6080 | 6080 | noVNC HTML5 client |
| 56780 | 56780 | Audify audio WebSocket |

---

## Licence

MIT
