# Termux · proot · Debian · XFCE · Nordic

Eine komplette, portable Linux-Arbeitsumgebung auf dem Android-Smartphone — installiert mit **einem** Script. Debian 13 (Trixie) mit XFCE-Desktop im Nordic-Look, gestartet über Termux und Termux:X11, läuft in einem proot-Container ohne Root.

Gedacht als Ersatz für einen Laptop: programmieren, arbeiten und Server per SSH warten — alles aus einem Gerät, das in die Hosentasche passt.

**Leitprinzip dieses Setups:** einmal einrichten, und bei einem kompletten Ausfall in wenigen Minuten reproduzierbar neu aufsetzen. Alle Assets (Theme, Cursor, Schrift, Icons) liegen im eigenen Repo — sie können nicht durch tote Fremd-Links verschwinden.

---

## Was das Setup einrichtet

Automatisch beim Durchlauf:

- **Debian 13 (Trixie, ARM64)** im proot-Container
- **XFCE-Desktop** mit Standard-Panel, schlank gehalten (kein `xfce4-goodies`-Ballast, kein LibreOffice)
- **Alacritty** als Standard-Terminal (zeigt Nerd-Font-Symbole zuverlässig, anders als der VTE-Terminal)
- **Firefox ESR** als Browser
- **Claude Code** (im Dark Mode)
- **Nordic Theme** — bläulich, komplett eckig (keine Rundungen) für GTK und Fensterrahmen
- **Papirus Icon Theme** mit blauen Ordnern
- **Bibata Modern Ice** Cursor (weiß, Größe 32)
- **Space Mono Nerd Font** — systemweit als Standard- und Monospace-Schrift
- **Deutsch (Österreich)** für Locale, Tastatur und XFCE-Oberfläche
- **Japanische Schriften** (`fonts-noto-cjk`) für korrekte Anzeige in Firefox
- **Xarchiver** als Archiv-Manager
- **Android-Speicher** eingebunden unter `/root/android-storage`
- Start-Alias **`linuxdesk`** und ein **Termux:Widget**-Shortcut für den Homescreen

Bewusst **optional** ausgelagert (siehe unten), weil sie den Hauptlauf sonst stören können:

- **Panel-Anpassung** → Befehl `setup-panel`
- **Tailscale** (VPN für SSH-Zugriff auf den Heimserver) → Befehl `setup-tailscale`

---

## Voraussetzungen

### Gerät
- Android **8 oder neuer** (Vorgabe von Termux:X11)
- ARM64-Gerät (aarch64) — die Assets sind dafür gebaut
- Ausreichend Speicher (Debian + XFCE + Tools belegen rund 1–2 GB)

### Zwei Apps aus offiziellen Quellen

Beide von den offiziellen Termux-GitHub-Seiten installieren — **nicht** aus dem Play Store, dessen Version ist veraltet und inkompatibel:

- **Termux** (Terminal-App): https://github.com/termux/termux-app
  → APK aus den *Releases* laden (Version ≥ 0.118.0), passend zur CPU-Architektur.
- **Termux:X11** (X-Server für die grafische Oberfläche): https://github.com/termux/termux-x11
  → Die App-APK aus dem *nightly*-Release-Tag laden. Das dazugehörige Termux-Paket (`termux-x11-nightly`) installiert das Setup-Script selbst.

> Wichtig: Beide Apps müssen aus **derselben Quelle** stammen (beide von GitHub), sonst verweigern sie aus Signatur-Gründen die Zusammenarbeit.

---

## Installation

In Termux ausführen:

```bash
curl -fsSL https://raw.githubusercontent.com/dev0gig/linuxrice/main/termux-proot-debian-xfce-nordic/setup_debian_xfce.sh -o setup_debian_xfce.sh
bash setup_debian_xfce.sh
```

Das Script läuft unbeaufsichtigt durch — keine Eingaben nötig. Je nach Verbindung und Gerät dauert es **20–40 Minuten** (viele Pakete, Icon-Verarbeitung).

Der Download und die Ausführung sind bewusst zwei getrennte Zeilen: So siehst du erst, dass die Datei korrekt geladen wurde, bevor sie startet.

---

## Nach der Installation

Wenn das Script durch ist, erscheint diese Meldung:

```
=================================================
✅ BOOM! All-in-One Umgebung erfolgreich eingerichtet!
=================================================
Führe zuerst aus: source ~/.bashrc
Danach kannst du mit 'linuxdesk' oder dem Widget deine GUI starten.

💡 Was automatisch lief:
   ✓ Alacritty als Standard-Terminal, SpaceMono Nerd Font, Dark Theme
   ✓ Claude Code auf Dark Mode vorkonfiguriert
   ✓ Nordic Theme (blau) für GTK + Fensterrahmen, komplett eckig (keine Rundungen)
   ✓ Papirus Icon Theme mit blauen Ordnern
   ✓ Bibata Modern Ice Cursor (weiß, Größe 32)
   ✓ Desktop-Icons deaktiviert (leerer Desktop), Standard-Wallpaper bleibt
   ✓ XFCE mit Standard-Panel (keine Panel-Anpassungen — bewusst schlank gehalten)
   ✓ Xarchiver installiert
   ✓ Android-Speicher unter /root/android-storage in Debian verfügbar
   ✓ Locale + Tastatur + XFCE-Oberfläche auf Deutsch (Österreich)
   ✓ Japanische Schriften (fonts-noto-cjk)

📌  PANEL (optional, NICHT automatisch angewendet):
   Für das angepasste Panel (Uhren, Launcher, App-Menü, Papierkorb)
   im Debian einmalig ausführen:  setup-panel
   Danach XFCE neu starten oder:  xfce4-panel -r

🔗  TAILSCALE (optional, NICHT automatisch installiert):
   Falls du deinen Server per SSH über Tailscale erreichen willst,
   im Debian einmalig ausführen:  setup-tailscale
   Das installiert Tailscale + Autostart + Firefox-Proxy in einem Rutsch.
   Danach:  /root/start-tailscale.sh  und  tailscale up  (Login im Browser).

⚠️  EINMALIGE MANUELLE SCHRITTE (nicht automatisierbar):
   • In der Termux:X11-App (nicht Termux selbst) unter Keyboard-Einstellungen:
     'Intercept system shortcuts' UND 'Prefer scancodes when possible' aktivieren
     → Behebt fehlende Tastenkürzel (Strg/Alt/Meta-Kombis)
```

### Die drei Schritte danach

**1. GUI starten**

```bash
source ~/.bashrc
linuxdesk
```

Dann in die **Termux:X11-App** wechseln — dort erscheint der XFCE-Desktop. Alternativ per Termux:Widget-Shortcut vom Homescreen.

**2. Tastenkürzel aktivieren (einmalig, wichtig)**

In der **Termux:X11-App** (nicht Termux) → Einstellungen → Keyboard:
- „Intercept system shortcuts" aktivieren
- „Prefer scancodes when possible" aktivieren

Ohne das fängt Android viele Strg-/Alt-/Meta-Kombis ab, bevor sie XFCE erreichen. Das ist eine App-Einstellung und lässt sich nicht per Script setzen.

**3. Optionale Extras nach Bedarf**

Beide werden **im Debian** ausgeführt (also nach `linuxdesk` in einem XFCE-Terminal, oder via `proot-distro login debian`):

Panel-Anpassung (Uhren, Launcher, App-Menü, Papierkorb):
```bash
setup-panel
xfce4-panel -r
```

Tailscale (für SSH auf den Heimserver):
```bash
setup-tailscale
/root/start-tailscale.sh
tailscale up
```

---

## Arbeiten mit der Umgebung

- **GUI starten:** in Termux `linuxdesk`, dann zur Termux:X11-App wechseln.
- **Nur Terminal (ohne GUI):** `proot-distro login debian` — nützlich für schnelle CLI-Arbeit, Git, SSH.
- **Server per SSH warten:** von Termux direkt `ssh benutzer@server`, oder aus Debian heraus (mit Tailscale für private Netze).
- **Dateiaustausch mit Android:** alles unter `/root/android-storage` im Debian entspricht dem gemeinsamen Android-Speicher.
- **GUI beenden:** in der Termux:X11-Benachrichtigung auf „Exit". Beachte, dass der `termux-x11`-Prozess in Termux danach noch weiterläuft.

---

## Wiederherstellung / Neu aufsetzen

Das ist der Kern des Prinzips: Bei Problemen einfach frisch aufsetzen.

Debian-Container komplett entfernen (Termux selbst bleibt):
```bash
proot-distro remove debian
```

Dann das Setup-Script erneut ausführen. Da alle Assets im eigenen Repo liegen, entsteht garantiert dasselbe Ergebnis — unabhängig davon, ob externe Projekte ihre Download-Links geändert haben.

---

## Aufbau des Repos

```
linuxrice/
└── termux-proot-debian-xfce-nordic/
    ├── setup_debian_xfce.sh     ← das Setup-Script
    ├── README.md                ← diese Datei
    └── assets/
        ├── SpaceMono.zip              (Nerd Font)
        ├── Nordic.tar.xz              (GTK/xfwm4 Theme)
        ├── Bibata-Modern-Ice.tar.xz   (Cursor)
        └── papirus-folders            (Script zum Einfärben der Ordner)
```

> Wird der Ordner umbenannt, ändern sich alle raw-Links im Script. Die zentrale Variable `ASSET_BASE` am Anfang des Scripts an einer Stelle anpassen.

---

## Bekannte Eigenheiten

- **`skullgirls`-Menü-Icon:** Die Panel-Config nutzt ein eigenes Icon für den App-Menü-Button. Es ist nicht Teil von Papirus — nach einem Neu-Aufsetzen zeigt das Menü daher ein Ersatz-Icon, bis das Icon manuell wieder hinterlegt wird.
- **Space Mono als UI-Schrift:** Da systemweit eine Monospace-Schrift gesetzt ist, wirken Menüs und Dialoge „technischer" (gleichbreite Zeichen). Das ist beabsichtigt.
- **Kein `systemd` in proot:** Dienste (z. B. Tailscale) laufen nicht als Systemdienst, sondern über die mitgelieferten Start-Skripte.

---

## Danksagung an die Projekte

- [Termux](https://github.com/termux/termux-app) und [Termux:X11](https://github.com/termux/termux-x11)
- [proot-distro](https://github.com/termux/proot-distro)
- [Nordic Theme](https://github.com/EliverLara/Nordic) von EliverLara
- [Bibata Cursor](https://github.com/ful1e5/Bibata_Cursor) von ful1e5
- [Papirus Icon Theme](https://github.com/PapirusDevelopmentTeam/papirus-icon-theme)
- [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts) (Space Mono)
