# Fingerabdrucksensor (Synaptics 06cb:00e7)

Der Sensor im HP ENVY x360 13 meldet sich als `06cb:00e7 Synaptics, Inc.` —
ohne Namen, ohne Kernel-Treiber, und libfprint aus dem Void-Repo winkt ab:
`No driver found for USB device 06CB:00E7`. Er ist upstream ausdrücklich
nicht unterstützt ([libfprint #274](https://gitlab.freedesktop.org/libfprint/libfprint/-/issues/274)).

Er gehört zur Synaptics-Familie **„Tudor Match-in-Sensor"** (laut HPs
`synaWudfBioUsbUwp.inf` zusammen mit `00c9`, `00d1`, `00ff`, `0124`, `0169`):
Abgleich und Speicherung der Abdrücke laufen komplett im Chip, die
USB-Verbindung ist TLS-verschlüsselt und an eine einmalige Kopplung mit dem
Rechner gebunden. Genau deshalb kann der eingebaute `synaptics`-Treiber von
libfprint nichts damit anfangen — der erwartet Rohbilder.

## Der Weg, der hier läuft

[vojtapl/synaTudorMiS](https://github.com/vojtapl/synaTudorMiS): ein
reverse-engineerter, quelloffener libfprint-Treiber namens **`synatlsmoc`**
(LGPL, kein Windows-Blob), vom Autor auf `00e7` getestet. Er liegt in einem
[libfprint-Fork](https://github.com/vojtapl/libfprint), der zusätzlich eine
kleine API für „persistente Gerätedaten" mitbringt. Darüber legt der Treiber
die Kopplung (Host-Schlüssel, Client- und Sensor-Zertifikat) ab; damit
fprintd sie zwischen zwei Starts aufbewahrt, braucht es
`fprintd-persistent-data.patch` — der Originalpatch des Autors, bereinigt um
seinen hartkodierten Heimatpfad und die Debug-Ausgaben. Gespeichert wird
unter `/var/lib/fprint/0-persistent/synatlsmoc/0`.

Alternativen, die bewusst nicht genommen wurden:

| | Warum nicht |
| --- | --- |
| [Popax21/synaTudor](https://github.com/Popax21/synaTudor) | linkt den Windows-Treiber von Synaptics zur Laufzeit um — läuft, aber Binärcode im Auth-Stapel und eine Warnung vor kaputten Sensoren im README |
| [HansHoogerwerf/synaptics-00e7-fpdrv](https://github.com/HansHoogerwerf/synaptics-00e7-fpdrv) | eigener From-scratch-Treiber als libfprint-**TOD**-Modul; bräuchte den TOD-Fork von libfprint, den Void nicht hat, und ist ein Ein-Commit-Projekt |

## Was `einrichten.sh` macht

1. Build-Werkzeuge installieren, die Void-Pakete `fprintd`, `libfprint` und
   `libfprint-udev-rules` entfernen (beide Seiten wollen
   `/usr/lib/security/pam_fprintd.so`; `xbps-remove` würde später unsere
   Datei mitnehmen).
2. Den libfprint-Fork auf festem Stand bauen und nach `/usr/local` installieren.
3. fprintd v1.94.5 (Stand des Void-Pakets) patchen, gegen das Fork-libfprint
   bauen, nach `/usr/local` installieren — das PAM-Modul landet in
   `/usr/lib/security`, D-Bus-Dienst und polkit-Aktion unter `/usr/share`,
   weil dbus-daemon und polkitd nur dort suchen. Kein runit-Dienst nötig:
   D-Bus startet fprintd bei Bedarf und beendet ihn nach Leerlauf.
4. `50-fprintd-local.rules` nach `/etc/polkit-1/rules.d`. **Ohne sie geht
   nichts:** Void/i3 hat keinen Sitzungs-Tracker (elogind läuft nicht),
   polkit stuft den Benutzer daher nie als „aktive Sitzung" ein und lehnt
   Anlernen und Prüfen mit `Not Authorized` ab. Die Regel erlaubt beides für
   `wheel`; das Anlernen für *andere* Benutzer bleibt root vorbehalten.
5. `pam_fprintd.so` als `sufficient` vor das `include` in `/etc/pam.d/sudo`
   und `/etc/pam.d/login` (Sicherung daneben als `*.vor-void-i3`).
   `timeout=15`: so lange wartet sudo auf den Finger, dann kommt die
   Passwortfrage. Ohne angelernte Finger gibt das Modul sofort ab.

Das Sperrmenü (`config/.local/bin/i3-sitzung`) entsperrt i3lock auf
Fingertipp über eine kleine Schleife um `fprintd-verify` — i3lock selbst
bleibt bei `pam_unix`. Begründung im Skript.

## Anlernen und Prüfen

```sh
fprintd-enroll                          # rechter Zeigefinger, 11 Berührungen
fprintd-enroll -f left-index-finger     # weitere Finger
fprintd-verify                          # Gegenprobe
fprintd-list "$USER"                    # was angelernt ist
fprintd-delete "$USER"                  # alles löschen
```

Die Abdrücke liegen im Sensor, nicht auf der Platte — unter
`/var/lib/fprint/<benutzer>/synatlsmoc/0/` stehen nur Verweise darauf.

## Wenn es klemmt

- `sudo G_MESSAGES_DEBUG=all /usr/local/libexec/fprintd -t` zeigt den
  kompletten Ablauf: Kopplung laden, Zertifikat prüfen, TLS-Handshake,
  `Finger needed 1`.
- `Not Authorized` als Benutzer → polkit-Regel fehlt oder der Benutzer ist
  nicht in `wheel`.
- Nach Bereitschaft schlägt die erste Prüfung fehl — die TLS-Sitzung
  überlebt S3 nicht; der nächste Versuch koppelt neu.
- Kopplung verwerfen: `sudo rm /var/lib/fprint/0-persistent/synatlsmoc/0`,
  beim nächsten Öffnen koppelt der Treiber neu. Die Abdrücke im Sensor
  hängen an der Kopplung und sind dann ebenfalls weg.

## Rückbau

```sh
sudo ninja -C ~/.cache/void-i3-fingerabdruck/fprintd/build uninstall
sudo ninja -C ~/.cache/void-i3-fingerabdruck/libfprint/build uninstall
sudo rm /etc/polkit-1/rules.d/50-fprintd-local.rules
sudo mv /etc/pam.d/sudo.vor-void-i3 /etc/pam.d/sudo
sudo mv /etc/pam.d/login.vor-void-i3 /etc/pam.d/login
sudo xbps-install fprintd libfprint            # falls gewünscht
```

## Dual-Boot

Die Kopplung mit Linux macht eine vorhandene Windows-Hello-Kopplung ungültig
(und umgekehrt); Abdrücke lassen sich nicht teilen. Auf diesem Notebook liegt
nur Void, darum ist das hier egal — auf einem anderen Gerät vorher bedenken.
