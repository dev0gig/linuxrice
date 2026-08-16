# Termux Wayland Desktop (labwc) — Machbarkeitsanalyse

**Stand: 16.8.2026 — reine Analyse, noch nichts gebaut.**

Die Frage: Lässt sich auf dem Fold7 ein Wayland-Desktop nativ unter Termux
betreiben, statt X11 über Termux-X11? Und zwar so, dass Browser die GPU
tatsächlich nutzen können?

**Antwort: Ja, sehr wahrscheinlich. Und einfacher als gedacht.**

## Warum die Frage überhaupt aufkam

Im Nachbarordner [`termux-xfce-gpu-desktop`](../termux-xfce-gpu-desktop/) läuft
XFCE über Termux-X11. Zink/turnip auf der Adreno 830 funktioniert dort
nachweislich — aber **nur für Programme, die OpenGL über GLX ansprechen**.
Firefox braucht EGL, und dieser Weg ist unter Termux-X11 nicht befahrbar.
Die vollständige Diagnose steht dort unter „Warum Firefox trotz Turnip auf
Software rendert".

Unter Wayland entfällt X11 als Zwischenschicht komplett. Der EGL-Weg dort ist
ein völlig anderer Codepfad — deshalb die Hoffnung, dass Browser damit an die
GPU kommen.

## Der entscheidende Befund

Das wlroots-Paket in Termux bringt ein **eigenes Backend für Termux:GUI** mit.
Beim Start von `labwc` sieht man es versuchen:

```
backend/termuxgui/backend.c:148  Failed to create tgui_connection
Could not connect to socket: No such file or directory
backend/backend.c:116  Cannot create session: disabled at compile-time
backend/backend.c:438  Failed to start a DRM session
```

Gescheitert ist es also **nicht mangels Weg**, sondern weil die Gegenstelle
fehlt: die App **Termux:GUI** ist nicht installiert. Sie spielt hier dieselbe
Rolle, die im X11-Setup die App Termux-X11 spielt — sie bringt das Bild auf den
Android-Bildschirm.

Die beiden folgenden Fehlerzeilen sind die erwarteten Rückfallebenen (libseat
ist nicht einkompiliert, DRM/KMS gibt es auf Android ohne Root nicht) und
brauchen niemanden zu beunruhigen.

## Was bereits vorhanden ist

Alles über die normalen Termux-Repos, nichts Exotisches:

| Baustein | Version | Status |
|---|---|---|
| `labwc` | 0.8.2-2 | installiert |
| `wlroots` (mit termuxgui-Backend) | 0.18.2-1 | installiert (Abhängigkeit) |
| `termux-gui-c` | 0.1.3-7 | installiert (Abhängigkeit) |
| `xwayland` | 24.1.13 | installiert (Abhängigkeit) |
| `sway` (Alternative zu labwc) | 1.10.1-1 | verfügbar |
| `swaybg` | 1.2.2 | verfügbar |
| Zink/turnip auf Adreno 830 | Mesa 26.0.6 | läuft bereits |

Die Versionen passen zueinander — labwc 0.8 und sway 1.10 wollen beide
wlroots 0.18. Genau daran scheitert es sonst oft.

## Was noch fehlt

1. **Die App Termux:GUI** (`com.termux.gui`). ⚠️ Sie muss aus **derselben Quelle
   stammen wie Termux selbst** (F-Droid oder GitHub) — Android prüft die
   Signatur, und Add-ons aus fremder Quelle lassen sich nicht installieren
   bzw. können nicht mit Termux reden. Das ist die klassische Falle bei
   Termux-Zusatz-Apps.
2. **`XDG_RUNTIME_DIR`** muss gesetzt sein, sonst startet labwc gar nicht:
   ```
   export XDG_RUNTIME_DIR=$PREFIX/tmp
   ```
3. **Launcher und Panel.** `wofi`, `fuzzel` und `waybar` gibt es in Termux
   **nicht**. Für einen ersten Start egal, danach zu klären. Rofi könnte über
   XWayland weiterlaufen.

## Was offen bleibt (und erst der Versuch klärt)

- **Startet labwc mit Termux:GUI überhaupt durch?**
- **Kommt der Browser dann an die GPU?** Das ist der ganze Zweck der Übung —
  und bisher nur eine begründete Vermutung, keine Messung.
- **Wie gut ist die Eingabe?** Tastatur, Maus und Touch über Termux:GUI sind
  unbekanntes Terrain.

## Was von XFCE nicht mitkommt

Bewusst festhalten, damit später keine Enttäuschung entsteht:

- **`xfwm4` kann kein Wayland.** Fenstersteuerung, Compositing-Schalter, Schatten
  und Theme aus `rice.sh` greifen dort nicht.
- **`sxhkd` entfällt** — labwc bringt Tastenkürzel selbst mit. Das ist eine
  Vereinfachung, kein Verlust.
- **`xfconfd` entfällt ebenfalls** — und damit der größte Ärger des X11-Setups:
  labwc liest eine XML-Datei beim Start, es gibt keinen Dienst, der
  Einstellungen im Speicher hält und beim Beenden zurückschreibt. Die ganze
  Vorlagen- und `killall`-Choreografie aus dem Nachbarordner wird überflüssig.

## Risiken

- Das termuxgui-Backend stammt aus einem sehr kleinen Projekt
  ([`xMeM/wlroots-termux`](https://github.com/xMeM/wlroots-termux), Zweig
  `termuxgui`). Termux- oder Mesa-Updates können es brechen.
- Es ist kein offiziell unterstützter Pfad — dieselbe Einschränkung, die schon
  für Zink/turnip im X11-Setup gilt.

## Nächster Schritt

Termux:GUI installieren (passende Quelle beachten), dann:

```
export XDG_RUNTIME_DIR=$PREFIX/tmp
labwc
```

Ziel des ersten Versuchs ist ausdrücklich **nur**: kommt ein Fenstermanager auf
den Schirm, und rendert Firefox darin mit GPU. Kein Panel, kein Theme, kein
Launcher — das ist erst danach interessant.

**Das X11-Setup im Nachbarordner bleibt davon unberührt** und funktioniert
weiter. Die beiden Ansätze stehen nebeneinander, nicht gegeneinander.
