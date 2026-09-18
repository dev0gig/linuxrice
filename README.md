# linuxrice

Linux-Arbeitsumgebungen zum Nachbauen. Dieses Repository enthält bewusst nur die zwei aktuell verwendeten Setups, klar nach Gerät getrennt.

## 📱 Handy — Samsung Galaxy Z Fold 7

### [`handy-fold7-termux-i3`](handy-fold7-termux-i3/)

Android → Termux + Termux:X11 + i3, ohne Root. Minimaler Desktop für das Fold 7 mit Terminal und Firefox.

Ein Befehl auf einem frischen Termux:

```bash
curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/handy-fold7-termux-i3/setup_i3.sh | bash
```

## 💻 Laptop — Void Linux

### [`laptop-void-i3`](laptop-void-i3/)

Void Linux mit i3 auf dem Laptop, ohne Display-Manager und ohne Desktop-Umgebung. Das Setup richtet Pakete, Dienste, Schriften, Tastatur, Touchpad und die i3-Arbeitsumgebung ein.

```sh
xbps-fetch -o setup.sh https://raw.githubusercontent.com/dev0gig/linuxrice/main/laptop-void-i3/setup.sh
sh setup.sh
```

## Struktur

- `handy-fold7-termux-i3/` → aktuelles Smartphone-Setup
- `laptop-void-i3/` → aktuelles Laptop-Setup

Veraltete Termux-Prototypen wurden aus dem aktuellen Repository entfernt. Ihre Historie bleibt über Git erhalten.
