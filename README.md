# linuxrice

Linux-Arbeitsumgebungen zum Nachbauen. Die `termux-*`-Ordner sind vier
Anläufe auf dem Samsung Galaxy Z Fold 7 — über Termux, ohne Root,
chronologisch; nur der erste in dieser Liste ist aktuell. Daneben steht mit
`void-i3` das Setup eines gewöhnlichen Notebooks.

## 🖥️ Notebook

### [`void-i3`](void-i3/)

Void Linux mit i3. Bisher darin: [`workspaces-vitals`](void-i3/workspaces-vitals/)
— Arbeitsfläche 4 als festes Systemmonitor-Dashboard aus btop, glances,
bandwhich und einer selbstgezeichneten Uhr, gehalten von einer
zellij-Sitzung in einem randlosen Alacritty-Fenster.

## ✅ In Benutzung — Termux

### [`termux-i3-minimal`](termux-i3-minimal/)

**Der aktuelle Stand (seit 16.8.2026).** i3 statt Desktop-Umgebung. In der
Sitzung laufen genau zwei Programme: ein Terminal und Firefox. Kein Panel,
kein Compositor, kein Theme-Dienst, kein Launcher, kein Wallpaper — und kein
einziger Hintergrunddienst.

Ein Befehl auf einem frischen Termux richtet alles ein:

```bash
curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-i3-minimal/setup_i3.sh | bash
```

Der Zuschnitt kommt aus dem tatsächlichen Nutzungsverhalten: Das Terminal ist
im Wesentlichen ein SSH-Fenster zum Server, die eigentliche Arbeit passiert
dort. Ein Desktop drumherum bringt dafür nichts.

## 📦 Archiv

Diese Ordner bleiben wegen ihrer Fehlersuchen stehen, sind aber nicht mehr in
Benutzung.

### [`termux-xfce-gpu-desktop`](termux-xfce-gpu-desktop/)

XFCE nativ in Termux, mit GPU-Beschleunigung über Zink/turnip. Lief ein Woche
im Alltag. Enthält zwei Untersuchungen, die weiterhin gelten und aus dem
i3-Setup verlinkt sind:

- **Warum Firefox trotz Turnip auf Software rendert** — komplette
  Ausschlussliste. Kurzfassung: Firefox spricht EGL, unter Termux-X11
  funktioniert nur GLX. Deshalb ist `backdrop-filter: blur()` auf diesem Gerät
  dauerhaft langsam, unabhängig vom Fenstermanager.
- **Warum die Panel-Config nach jedem Neustart weg war** — der Dienst
  `xfconfd` hält alle Einstellungen im Speicher und kippt sie beim Beenden
  über die Dateien. Der Hauptgrund für den Wechsel zu i3.

### [`termux-wayland-labwc`](termux-wayland-labwc/)

Machbarkeitsanalyse: Wayland statt X11, um Browsern doch noch die GPU
zugänglich zu machen. **Grafisch erfolgreich, bedienbar gescheitert** — zwei
Wege getestet, beide verworfen. Tastatur und Maus werden nicht erkannt, ein
seit über einem Jahr offener Fehler im Termux-Paket.

Festgehalten für den Fall, dass sich das ändert: Der Rest des Weges ist
erprobt und dokumentiert.

### [`termux-proot-debian-xfce-nordic`](termux-proot-debian-xfce-nordic/)

Der erste Anlauf: vollständiges Debian im proot-Container mit XFCE im
Nordic-Look. Zu schwer und ohne Zugriff auf die GPU.
