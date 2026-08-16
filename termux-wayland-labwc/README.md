# Termux Wayland Desktop (labwc) — Machbarkeitsanalyse

**Stand: 16.8.2026 — zwei Wege praktisch getestet, beide verworfen. Es bleibt bei X11.**

Die Frage: Lässt sich auf dem Fold7 ein Wayland-Desktop nativ unter Termux
betreiben, statt X11 über Termux-X11? Und zwar so, dass Browser die GPU
tatsächlich nutzen können?

**Kurzantwort: Grafisch ja — bedienbar nein.** Der Grafikpfad funktioniert und
löst genau das Problem, an dem das X11-Setup scheitert. Aber Tastatur und Maus
werden nicht erkannt, und das ist ein bekannter, seit über einem Jahr offener
Fehler im Termux-Paket. Damit ist es aktuell kein benutzbarer Desktop.

## Warum die Frage überhaupt aufkam

Im Nachbarordner [`termux-xfce-gpu-desktop`](../termux-xfce-gpu-desktop/) läuft
XFCE über Termux-X11. Zink/turnip auf der Adreno 830 funktioniert dort
nachweislich — aber **nur für Programme, die OpenGL über GLX ansprechen**.
Firefox braucht EGL, und dieser Weg ist unter Termux-X11 nicht befahrbar.
Die vollständige Diagnose steht dort unter „Warum Firefox trotz Turnip auf
Software rendert".

Unter Wayland entfällt X11 als Zwischenschicht. Der EGL-Weg dort ist ein
anderer Codepfad — daher die Hoffnung, dass Browser damit an die GPU kommen.

## Ergebnis des Praxistests

| Stufe | Ergebnis |
|---|---|
| Wayland-Compositor startet | ✅ labwc läuft |
| Bild kommt auf den Android-Schirm | ✅ über die App Termux:GUI |
| GPU wird genutzt | ✅ mit dem Vulkan-Renderer |
| Firefox startet in der Sitzung | ✅ |
| **Firefox bekommt einen GL-Kontext** | ✅ **keine EGL-Fehler mehr** |
| Tastatur | ❌ wird nicht erkannt |
| Maus | ❌ wird nicht erkannt |

Der vorletzte Punkt ist der eigentliche Erfolg: Unter X11 spuckt Firefox
seitenweise `Failed to create EGL library display` und `Fallback WR to SW-WR`
aus. In der Wayland-Sitzung **kein einziger Grafikfehler** — nur harmlose
Tastaturlayout-Warnungen von XWayland. Der Beweis, dass der Ansatz trägt.

## Der Weg dorthin — was tatsächlich nötig war

Alles über normale Termux-Repos, kein Fremdprojekt, kein proot, kein Root:

```bash
pkg install labwc          # zieht wlroots, termux-gui-c, xwayland mit
export XDG_RUNTIME_DIR=$PREFIX/tmp
WLR_RENDERER=vulkan labwc -s "env MOZ_ENABLE_WAYLAND=1 firefox"
```

Dazu muss die App **Termux:GUI** (`com.termux.gui`) installiert sein.
⚠️ Sie muss aus **derselben Quelle stammen wie Termux selbst** (F-Droid oder
GitHub) — Android prüft die Signatur, Add-ons aus fremder Quelle funktionieren
nicht.

### Die zwei Fallen, die es zu umgehen galt

**1. `XDG_RUNTIME_DIR` fehlt.** Ohne die Variable startet labwc gar nicht:

```
[ERROR] XDG_RUNTIME_DIR is unset
```

**2. Der Standard-Renderer scheitert.** labwc nimmt von sich aus den
GLES2-Renderer, und der will über EGL einen GBM-Zugang zur Grafikhardware —
also `/dev/dri`, das es auf Android ohne Root nicht gibt:

```
[EGL] eglInitialize, error: EGL_NOT_INITIALIZED, message: "DRI2: failed to create gbm device"
render/gles2/renderer.c:499  Could not initialize EGL
Aborted
```

**`WLR_RENDERER=vulkan` löst das.** Vulkan spricht über turnip direkt mit der
Adreno, ohne EGL und ohne GBM dazwischen. Danach läuft labwc fehlerfrei durch.
Das ist der zentrale Kniff dieses ganzen Ansatzes.

## Woran es scheitert

**Tastatur und Maus werden nicht erkannt.** Das ist kein Konfigurationsfehler,
sondern ein bekannter Fehler des Termux-Pakets:

> [termux/termux-packages#23751 — „[Bug][TGUI]: Labwc and Sway does not support
> a physical keyboard"](https://github.com/termux/termux-packages/issues/23751)
> Gemeldet 12.3.2025, seitdem offen und „untriaged", kein Maintainer
> zugewiesen, keine Lösung in Sicht.

Passend dazu meldet labwc beim Öffnen eines Fensters:

```
[view.c:860] view has no output, not positioning
```

Das termuxgui-Backend registriert den Bildschirm also nicht sauber — Eingabe
und Ausgabe-Geometrie hängen am selben unfertigen Stück.

**Nicht getestet:** ob Touch-Eingabe direkt am Handybildschirm funktioniert.
Der Fehlerbericht spricht ausdrücklich von *physischen* Tastaturen. Für die
Arbeit über DeX mit Maus und Tastatur hilft das allerdings ohnehin nicht.

## Bewertung

**Der Ansatz ist bewiesen, aber unfertig.** Was hier fehlt, kann man nicht
konfigurieren — es müsste im Backend programmiert werden. Das liegt bei einem
sehr kleinen Projekt ([`xMeM/wlroots-termux`](https://github.com/xMeM/wlroots-termux),
Zweig `termuxgui`), das diese Lücke seit über einem Jahr nicht geschlossen hat.

Deshalb: **nicht weiterverfolgen, aber im Auge behalten.** Sollte die Eingabe
irgendwann funktionieren, ist der Rest bereits erprobt und in diesem Dokument
festgehalten — dann sind es nur noch ein paar Zeilen bis zum laufenden Desktop.

**Der Alltag bleibt bei XFCE über Termux-X11** im Nachbarordner. Dort ist das
Ruckeln über abgeschaltetes Compositing gelöst; Browser rendern auf der CPU,
was mit sparsamem CSS (kein `backdrop-filter: blur()`) gut auszuhalten ist.

## Was von XFCE bei einem späteren Umstieg nicht mitkäme

- **`xfwm4` kann kein Wayland.** Fenstersteuerung, Compositing-Schalter,
  Schatten und Theme aus `rice.sh` greifen dort nicht.
- **`sxhkd` entfällt** — labwc bringt Tastenkürzel selbst mit. Vereinfachung.
- **`xfconfd` entfällt** — und damit der größte Ärger des X11-Setups: labwc
  liest eine XML-Datei beim Start, kein Dienst hält Einstellungen im Speicher
  und schreibt sie beim Beenden zurück. Die ganze Vorlagen- und
  `killall`-Choreografie wäre überflüssig.
- **Launcher und Panel fehlen:** `wofi`, `fuzzel` und `waybar` gibt es in
  Termux nicht. Rofi könnte über XWayland weiterlaufen.

## TAWC ebenfalls getestet — auch kein Ersatz

Weil beim Termux:GUI-Weg die Eingabe fehlt, wurde am selben Tag noch
[TAWC](https://github.com/wmww/tawc) ausprobiert. Es bringt eine eigene App,
einen eigenen Compositor und lädt eine echte Debian-Umgebung herunter.

**Was gut lief:**

- Installation und Debian-Download problemlos
- ✅ **Externe Tastatur funktioniert** — genau das, was dem Termux:GUI-Weg fehlt
- Firefox ließ sich installieren und starten

**Woran es scheiterte:**

- **Chromium kommt nicht hoch.** Er verbindet sich zwar mit dem Compositor,
  scheitert dann aber endlos beim Anlegen eines GPU-Kontexts:
  ```
  ContextResult::kFatalFailure: Failed to create shared context for virtualization.
  SharedImageStub: unable to create context
  ```
  Das wiederholt sich unbegrenzt, der Browser startet nie. Auch mit
  `--no-sandbox --disable-dev-shm-usage --in-process-gpu` nicht.
- Firefox startete, meldete aber `No GPUs detected via PCI` und
  `vaapitest: failed to open renderDeviceFD` — ob er die GPU am Ende genutzt
  hätte, wurde nicht mehr zu Ende gemessen.

**Stolperstein für einen späteren Anlauf:** TAWC legt den Wayland-Socket an
einer ungewöhnlichen Stelle ab — nicht unter `/run/user/…`, sondern:

```
XDG_RUNTIME_DIR=/usr/share/tawc WAYLAND_DISPLAY=wayland-0 <programm>
```

Ohne diese beiden Variablen findet kein Programm den Compositor, und die
Fehlermeldung („Failed to connect to Wayland display") führt in die Irre.

**Entscheidung am 16.8.2026: Es bleibt bei X11.** Der Aufwand steht in keinem
Verhältnis zum Gewinn, und mit abgeschaltetem Compositing ist das
Ausgangsproblem ausreichend entschärft.

## Geprüfte Alternativen (nicht nötig gewesen)

Vor dem Fund des eingebauten Termux:GUI-Weges wurden diese Projekte untersucht.
Sie lösen dasselbe Problem über Androids eigene Grafik-Infrastruktur
(AHardwareBuffer/gralloc bzw. libhybris) statt über DRM/KMS:

| Projekt | Ansatz |
|---|---|
| [Anland](https://github.com/lfdevs/anland-termux) | Wayland in nativem Termux, Turnip auf Snapdragon |
| [TAWC](https://github.com/wmww/tawc) | Eigenständige App, libhybris, Smithay |
| [wlroots-android-bridge](https://github.com/Xtr126/wlroots-android-bridge/) | wlroots über gralloc/SurfaceFlinger, labwc |
| [Local Desktop](https://github.com/localdesktop/localdesktop.github.io) | Fertige App, Compositor im NDK, XFCE-Wayland in proot |

Falls der Termux-Weg dauerhaft an der Eingabe hängen bleibt, wären das die
nächsten Kandidaten — insbesondere TAWC, das am aktivsten gepflegt wird.
