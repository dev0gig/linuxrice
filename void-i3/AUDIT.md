# Security- und Qualitäts-Audit — `void-i3`

Prüfgegenstand: `void-i3/setup.sh` (1187 Zeilen, POSIX sh), `void-i3/fingerabdruck/einrichten.sh`
(193 Zeilen), alles unter `void-i3/system/` (wird nach `/` kopiert) und die privilegierten Helfer
unter `void-i3/config/.local/bin/`.

Maßstab: was ein DevOps-/Security-Team vor einem Rollout verlangen würde. Der Kontext ist ein
Ein-Benutzer-Notebook; Befunde, die einen zweiten lokalen Benutzer voraussetzen, sind als solche
markiert und entsprechend eingestuft.

Alle Aussagen unten wurden am Code belegt. Wo eine Shell-Semantik im Spiel war, wurde sie auf
einer Maschine gegengetestet (dash und bash) statt aus dem Gedächtnis behauptet — zwei
Verdachtsfälle sind dabei ausgeschieden und stehen deshalb nicht in dieser Liste.

---

## Zusammenfassung vorab

Das ist kein durchschnittliches Dotfiles-Skript. Es ist POSIX-sauber über alle 26 `sh`-Dateien,
es gibt kein einziges `eval`, `os.system`, `shell=True` oder `popen` im ganzen Baum, keine
Secrets, und die Kommentardichte an den kritischen Stellen liegt weit über dem Branchenüblichen.
Mehrere Dinge sind ausdrücklich vorbildlich gelöst (sudoers, SSID-Behandlung, die
Hardware-Vorprüfung).

Was fehlt, ist die Härtungsschicht, die ein Skript von „funktioniert bei mir" zu „darf
unbeaufsichtigt auf fremder Hardware laufen" hebt: **Integritätsnachweise auf dem
Download-Pfad**, **sichere temporäre Dateien**, und ein **ehrlicheres Verhalten beim zweiten
Lauf**. Details unten, Priorisierung am Ende.

---

## 1. Sicherheit

### K1 — Vorhersagbare `/tmp`-Dateien für Binaries, die anschließend Root-Rechte bekommen

**kritisch** · CWE-377 (Insecure Temporary File) + CWE-367 (TOCTOU)

| Stelle | Weg der Datei |
|---|---|
| `setup.sh:973-977` | `/tmp/tasten-led.$$` → `sudo install -m 750 -o root -g audio` → `setcap cap_sys_rawio+ep` |
| `setup.sh:992-995` | `/tmp/sperrsaver.$$` → `sudo install -m 755 /usr/local/bin/sperrsaver` |
| `fingerabdruck/einrichten.sh:165-167` | `/tmp/pam.$$` → `sudo install /etc/pam.d/sudo` **und** `/etc/pam.d/login` |

```sh
# setup.sh:973-976
if gcc -O2 -o "/tmp/tasten-led.$$" "$QUELLE/system/bin/tasten-led.c" 2>/dev/null; then
    sudo install -m 750 -o root -g audio "/tmp/tasten-led.$$" /usr/local/bin/tasten-led
    rm -f "/tmp/tasten-led.$$"
    sudo setcap cap_sys_rawio+ep /usr/local/bin/tasten-led
```

**Problem.** `$$` ist die PID — vollständig vorhersagbar und billig zu erraten (sequentiell, und
ein Angreifer kann einfach alle paar tausend Kandidatennamen vorbelegen). `/tmp` ist
world-writable.

**Risiko.** Ein zweiter lokaler Benutzer legt `/tmp/tasten-led.<pid>` vorab mit Modus 666 an. Er
ist damit Eigentümer — das Sticky-Bit schützt nur davor, *fremde* Dateien zu entfernen, nicht
davor, eigene bereitzustellen. `gcc -o` öffnet mit `O_CREAT|O_TRUNC` und schreibt in seine Datei.
Zwischen dem Ende von `gcc` und dem `sudo install` ersetzt er als Eigentümer den Inhalt durch ein
eigenes ELF. `install` kopiert den *Inhalt* nach `/usr/local/bin/tasten-led`, `setcap` verleiht
dem Ergebnis `CAP_SYS_RAWIO` — das ist root-äquivalent (Rohzugriff auf Speicher und I/O-Ports).

Bei `/tmp/pam.$$` ist der Weg noch kürzer: Inhaltskontrolle über den auth-Stack von `sudo` selbst.

**Einordnung.** Auf einem Notebook mit genau einem Benutzerkonto faktisch nicht ausnutzbar. Aber
es ist das Lehrbuchmuster, es ist in drei Zeilen behoben, und die Frage lautete ausdrücklich nach
Produktionsreife — deshalb steht es an erster Stelle.

**Fix.**

```sh
# setup.sh, Abschnitt "LEDs in F5 und F8"
BAUDIR=$(mktemp -d) || fehler "kein temporaeres Verzeichnis"
trap 'rm -rf "$BAUDIR"' EXIT INT TERM
if gcc -O2 -o "$BAUDIR/tasten-led" "$QUELLE/system/bin/tasten-led.c" 2>/dev/null; then
    sudo install -m 750 -o root -g audio "$BAUDIR/tasten-led" /usr/local/bin/tasten-led
    sudo setcap cap_sys_rawio+ep /usr/local/bin/tasten-led
    gut "/usr/local/bin/tasten-led gebaut und eingerichtet"
else
    warn "tasten-led liess sich nicht uebersetzen -- die LEDs in F5/F8 bleiben dunkel."
fi
```

Analog für `sperrsaver` und — wichtiger — für `pam_eintragen()` in `einrichten.sh`:

```sh
# fingerabdruck/einrichten.sh:159-167
tmp=$(mktemp) || { warn "kein temporaeres Verzeichnis"; return 1; }
awk '...' "$datei" > "$tmp"
# Gegenprobe, BEVOR die Datei nach /etc/pam.d geht: eine kaputte sudo-Datei
# sperrt dauerhaft aus.
grep -q '^auth.*pam_fprintd.so' "$tmp" || { rm -f "$tmp"; warn "$datei: Eintrag misslungen"; return 1; }
sudo install -m 644 -o root -g root "$tmp" "$datei"
rm -f "$tmp"
```

### K2 — Kein Integritätsnachweis auf dem gesamten Download-Pfad

**wichtig** — *herabgestuft, Begründung am Ende des Abschnitts*

```sh
# setup.sh:57-62 -- der Self-Bootstrap
xbps-fetch -o "$TMP/repo.tar.gz" \
    "https://codeload.github.com/dev0gig/linuxrice/tar.gz/refs/heads/main" \
    || fehler "Download fehlgeschlagen. Besteht eine Netzverbindung?"
tar xzf "$TMP/repo.tar.gz" -C "$TMP"
QUELLE="$TMP/linuxrice-main/void-i3"
```

**Problem.** Kein `sha256sum`, keine Signatur, und `refs/heads/main` ist eine *bewegliche*
Referenz. Aus `$QUELLE` läuft danach: `sudo cp` von 17 Systemdateien (`setup.sh:850`),
`sudo install` von sudoers-Schnipseln (`947`), `gcc` + `setcap` auf `system/bin/*.c` (`973-976`)
und `sh "$QUELLE/fingerabdruck/einrichten.sh"` (`1011`).

Dasselbe ohne Pin an zwei weiteren Stellen:

```sh
# setup.sh:756-759 -- ein Git-Tag lässt sich verschieben
xbps-fetch -o "$TMPF/rh.tar.gz" \
    "https://github.com/RedHatOfficial/RedHatFont/archive/refs/tags/5.0.0.tar.gz"

# setup.sh:793-798 -- kein Commit-Pin, danach sudo cp -r nach /usr/share/icons
git clone --depth 1 --filter=blob:none --sparse \
    https://github.com/vinceliuice/Colloid-icon-theme.git "$TMPC/colloid"
```

**Risiko.** Der empfohlene Einstieg (`setup.sh:10`, README) lädt `setup.sh` separat von `main`.
Der Nutzer liest also *einen* Abruf und führt *einen anderen* aus. Wird zwischen Lesen und Starten
auf `main` gepusht, bekommt das Skript den neuen Stand: ein zusätzliches
`system/etc/sudoers.d/99-x` mit `%wheel ALL=(ALL) NOPASSWD: ALL` würde `visudo -c` anstandslos
passieren und per `sudo install -m 440` landen. Das setzt ein kompromittiertes GitHub-Konto voraus
— aber genau davor schützen Pins und Prüfsummen.

Der praktisch häufigere Fall ist harmloser und trotzdem ärgerlich: der Nutzer bekommt immer
„gerade eben committet", nie einen freigegebenen Stand. Ein halbfertiger Zwischenstand auf `main`
läuft ungebremst über sein System.

**Bemerkenswert:** In `fingerabdruck/einrichten.sh:43` ist es *richtig* gemacht —
`LIBFPRINT_STAND=2f8b3e78…` pinnt auf einen Commit-Hash, mit der Begründung „Feste Staende, damit
der Build auch in einem Jahr noch dasselbe ergibt". Genau dieser Gedanke fehlt in `setup.sh`
vollständig.

**Fix.**

```sh
REPO_STAND=v1.0.0        # Tag oder Commit-Hash, nie refs/heads/main
REPO_SHA256=<hash>       # im README dokumentiert
xbps-fetch -o "$TMP/repo.tar.gz" \
    "https://codeload.github.com/dev0gig/linuxrice/tar.gz/$REPO_STAND" \
    || fehler "Download fehlgeschlagen. Besteht eine Netzverbindung?"
printf '%s  %s\n' "$REPO_SHA256" "$TMP/repo.tar.gz" | sha256sum -c - >/dev/null 2>&1 \
    || fehler "Pruefsumme des Repo-Archivs stimmt nicht -- Abbruch."
tar xzf "$TMP/repo.tar.gz" -C "$TMP"
```

Für Colloid genügt `git -C "$TMPC/colloid" checkout -q <commit>` nach dem Clone; für RedHatFont
ein `sha256sum -c`. Untergrenze, falls kein Release-Prozess gewünscht ist: wenigstens die
Prüfsumme des Archivs ausgeben und im README hinterlegen, damit ein Abweichen auffällt.

**Warum „wichtig" und nicht „kritisch" — und warum der Fix oben unvollständig ist.**
Dieser Punkt stand zuerst als kritisch in der Liste. Die Gegenprüfung hat zwei Einwände
hervorgebracht, die beide zutreffen:

1. `xbps-fetch` geht über TLS gegen `codeload.github.com`. Transportintegrität und
   Serverauthentizität sind also vorhanden; was fehlt, ist allein das Pinnen gegen eine
   Übernahme des Repos selbst.
2. Der Vertrauensanker ist dasselbe Repo, dessen `setup.sh` der Nutzer ohnehin freiwillig mit
   `sudo` ausführt. Wer dort pushen kann, kann auch Tags verschieben **und den Hash im README
   ändern** — die oben vorgeschlagene Prüfsumme ist damit teilweise selbstbezüglich. Sie schließt
   real nur das Fenster zwischen „`setup.sh` geladen und gelesen" und „`setup.sh` gestartet".

Was unstrittig bleibt und den Aufwand trägt, ist deshalb weniger Sicherheit als
**Reproduzierbarkeit**: der Nutzer bekommt immer den letzten, womöglich halbfertigen Commit eines
Skripts, das `/etc/sudoers.d`, `/etc/rc.local` und den PAM-Stack anfasst. Ein Tag statt `main`
kostet nichts und behebt genau das. Ein signierter Tag (`git tag -s`) plus der `sha256` von
`setup.sh` selbst im README wäre die Fassung, die auch den Selbstbezug auflöst.

### K3 — Root schreibt und `chown`t in einen benutzerkontrollierten Pfad (Symlink-Angriff)

**kritisch** · CWE-59 (Link Following) · umgeht die Passwortpflicht des Systems

```sh
# system/etc/zzz.d/resume/10-fingerabdruck:84-90 -- laeuft als root aus /usr/bin/zzz
if [ -n "$heim" ] && pgrep -x xsecurelock >/dev/null 2>&1; then
    zustandsdatei="$heim/.cache/sperrbild/zustand"
    if [ -f "$zustandsdatei" ] && echo aufwachen > "$zustandsdatei" 2>/dev/null; then
        chown "$benutzer" "$zustandsdatei" 2>/dev/null
```

**Problem.** Der Hook läuft als root. `$heim` kommt aus `getent passwd`, der Pfad darunter gehört
vollständig dem Benutzer. Weder die Existenzprüfung noch die Umleitung noch `chown` folgen dem
Symlink *nicht* — alle drei tun es.

**Risiko.** Ablauf, vollständig ohne Passwort und ohne Fingerabdruck:

```sh
ln -sf /etc/sv/wpa_supplicant/run ~/.cache/sperrbild/zustand
# Deckel zu, Deckel auf -- der Resume-Hook laeuft
```

`[ -f ]` folgt dem Link und ist wahr. Root schreibt `aufwachen` hinein (die Datei ist damit
zerstört) und `chown`t sie anschließend dem Benutzer. Dem gehört jetzt ein Skript, das beim
nächsten Boot als root ausgeführt wird. Mit `/etc/shadow` als Ziel ist es kein Rechtegewinn,
sondern schlicht ein zerstörtes System — niemand kann sich mehr anmelden.

**Einordnung — hier liegt der eigentliche Punkt.** Der Benutzer ist in `wheel` und käme über
`sudo` ohnehin an root. Der Unterschied ist die **Authentifizierung**: `sudo` verlangt Passwort
oder Finger, und `sudoers.d/20-zeitfenster` setzt `timestamp_timeout=0`, damit das *jedes Mal*
gilt. Genau diese Zusicherung hebt der Hook auf. Jeder Code, der als Desktop-Benutzer läuft —
ein `npm`-Postinstall (das Setup installiert nodejs und Claude Code global über npm), ein
Ausbruch aus dem Chrome-Flatpak — bekommt root, ohne das Passwort zu kennen, indem er einen
Symlink legt und auf das nächste Zuklappen wartet.

Das ist damit der einzige Befund im Repo, der eine bewusst errichtete Sicherheitsgrenze
tatsächlich durchlöchert.

**Fix.** Nicht als root in einen fremden Pfad schreiben. Der Hook hat den Benutzernamen bereits:

```sh
# Als der Benutzer schreiben, nicht als root -- dann ist ein Symlink des
# Benutzers auf eine Systemdatei wirkungslos, und der chown entfaellt ganz.
if [ -n "$benutzer" ] && pgrep -x xsecurelock >/dev/null 2>&1; then
    su "$benutzer" -c 'd="${XDG_CACHE_HOME:-$HOME/.cache}/sperrbild"
                       [ -f "$d/zustand" ] || exit 0
                       printf aufwachen > "$d/zustand"' 2>/dev/null \
        && notiere "Ladekreis an"
fi
```

Dieselbe Prüfung lohnt für `system/etc/acpi/deckel.sh:45-47` und
`system/etc/zzz.d/resume/20-funk:39` — siehe N7.

### K4 — Die Sicherungskopie reaktiviert genau das, was das Skript entschärft

**kritisch** · trifft jeden Erstinstallierer · hebt die Deckel-Sperre und die Einschalttasten-Sperre auf

```sh
# setup.sh:826-828 und 848-851
sichern_system() {
    [ -e "$1" ] && [ ! -e "$1.vor-void-i3" ] && sudo cp -a "$1" "$1.vor-void-i3" || true
}
...
    sudo mkdir -p "/$(dirname "$rel")"
    sichern_system "/$rel"                      # legt die Sicherung DANEBEN
    sudo cp "$QUELLE/system/$rel" "/$rel"
```

**Problem.** Die Sicherung landet im selben Verzeichnis wie das Original. Für die meisten Ziele
ist das harmlos — sie lesen nur bestimmte Endungen. Für genau zwei nicht:

| Zielverzeichnis | liest | Sicherung wirksam? |
|---|---|---|
| `/etc/udev/rules.d/`, `/etc/X11/xorg.conf.d/`, `/etc/fonts/conf.d/` | nur `*.rules` / `*.conf` | nein |
| `/etc/profile.d/`, `/etc/runit/shutdown.d/` | nur `*.sh` | nein |
| **`/etc/acpi/events/`** | **jede Datei, egal wie sie heißt** | **ja** |
| **`/etc/zzz.d/resume/`** | **jede ausführbare Datei** | **ja** |

Beide Male steht die Begründung im Repo selbst. Für acpid, in
`system/etc/acpi/events/anything:10-12` — vom Autor geschrieben:

> „Das Original liegt unveraendert in `/etc/acpi/anything.original` — **NICHT in diesem
> Verzeichnis**: acpid liest hier jede Datei, egal wie sie heisst, und eine Sicherungskopie neben
> der Regel waere die Regel selbst."

Für zzz, in `setup.sh:872-873`:

> „`/usr/bin/zzz` laeuft die Verzeichnisse `/etc/zzz.d/suspend` und `/etc/zzz.d/resume` durch und
> ruft daraus **nur auf, was ausfuehrbar ist**"

Die Gefahr ist also erkannt und exakt beschrieben — und `sichern_system` tut in beiden
Verzeichnissen genau das, wovor der Kommentar warnt.

**Risiko 1 — `/etc/acpi/events/`, ab dem ersten Lauf.** `acpid` kommt aus der Paketliste, also
existiert `/etc/acpi/events/anything` (die Sammelregel des Pakets) bereits, wenn Zeile 849
darüberläuft. `sichern_system` kopiert sie nach `anything.vor-void-i3` — **im selben
Verzeichnis** — und Zeile 850 ersetzt danach `anything` durch die entschärfte Fassung. acpid liest
beide. Die Sammelregel bleibt damit dauerhaft aktiv, und mit ihr die drei Dinge, die das Repo
ausdrücklich abstellen wollte:

```
#   * Einschalttaste -> sofortiges "shutdown -P now", ohne Rueckfrage
#   * Deckel zu      -> zzz ohne vorheriges Sperren (doppelt zu deckel)
#   * Netzteil rein/raus -> schreibt in scaling_setspeed
```

Der Deckel-Fall ist der ernste: ein Deckelereignis löst jetzt **beide** Regeln aus —
`deckel.sh` (sperren, dann schlafen) und `handler.sh` (schlafen, ohne zu sperren). Wer zuerst bei
`zzz` ist, gewinnt. Kommt `handler.sh` durch, schläft der Rechner, bevor `xsecurelock` steht, und
wacht **entsperrt** auf. Die gesamte Sperre-beim-Zuklappen-Konstruktion — der Grund für
`deckel.sh`, `events/deckel` und den Aufwach-Hook — ist damit ein Münzwurf. Und die
Einschalttaste fährt den Rechner wieder ohne Rückfrage herunter.

**Risiko 2 — `/etc/zzz.d/resume/`, ab dem zweiten Lauf.** In Lauf 1 gibt es die Hooks noch nicht,
`sichern_system` tut nichts. In Lauf 2 existieren sie — mit Modus 755 aus Zeile 874-875 — und
`cp -a` **erhält den Modus**. Es entsteht ein ausführbares
`/etc/zzz.d/resume/10-fingerabdruck.vor-void-i3`, das `zzz` von da an bei jedem Aufwachen
mitausführt: zwei `pkill fprintd`, zwei USB-Unbind/Bind-Zyklen am Fingerabdruckleser, zwei
Escape-Schleifen, die sich gegenseitig in die Quere kommen. Dasselbe für `20-funk`. Ändert sich
der Hook später im Repo, läuft die eingefrorene alte Fassung für immer neben der neuen weiter.

**Fix.** Die Sicherung aus dem gelesenen Verzeichnis heraushalten — so, wie der Autor es für
`anything.original` schon vorgesehen hat:

```sh
# Sicherungen sammeln sich unter /var/backups/void-i3/ statt neben dem Original.
# Zwei Zielverzeichnisse lesen JEDE Datei -- /etc/acpi/events (jede) und
# /etc/zzz.d/resume (jede ausfuehrbare). Eine Kopie daneben waere dort die
# Regel bzw. der Hook selbst, ein zweites Mal.
SICHERUNG=/var/backups/void-i3
sichern_system() {
    [ -e "$1" ] || return 0
    ziel="$SICHERUNG/${1#/}"
    [ -e "$ziel" ] && return 0
    sudo mkdir -p "$(dirname "$ziel")"
    sudo cp -a "$1" "$ziel"
}
```

Und einmalig aufräumen, was frühere Läufe hinterlassen haben:

```sh
sudo rm -f /etc/acpi/events/*.vor-void-i3 /etc/zzz.d/resume/*.vor-void-i3
sudo sv restart acpid
```

### W0 — `nullok` im PAM-Stack des Sperrbildschirms

**wichtig** · fail-open, sofern die Vorbedingung zutrifft

```
# system/etc/pam.d/xsecurelock:30
auth  [success=2 default=ignore]  pam_unix.so   try_first_pass nullok
```

**Problem.** `nullok` weist `pam_unix` an, ein **leeres Passwort zu akzeptieren**, wenn das
Passwortfeld des Kontos in `/etc/shadow` leer ist. In einem Sperrbildschirm-Stack heißt das:
Enter drücken genügt.

Der Stack ist ansonsten sorgfältig gebaut — der `success=2`-Sprung ist korrekt, beide Zweige sind
laut Kommentar (`xsecurelock:23-25`) einzeln durchgemessen worden. `nullok` stammt mit hoher
Wahrscheinlichkeit aus Voids `system-auth`, aus dem der Stack herausgelöst wurde; dort ist es
Konvention, in einem Lock-Screen hat es nichts zu suchen. `try_first_pass` ist an dieser Stelle
außerdem wirkungslos: es gibt kein vorangehendes Modul, das ein Token gesetzt haben könnte.

**Risiko.** Nur real, wenn das Konto tatsächlich kein Passwort hat. Das ist unwahrscheinlich, aber
für den Nutzer unsichtbar — und die Folge wäre ein Sperrbildschirm, der bei Enter aufgeht.
Prüfen mit:

```sh
passwd -S "$(id -un)"   # zweites Feld muss P sein, nicht NP
```

**Fix.** Beide Schlüsselwörter streichen — der Stack verliert dadurch nichts:

```
auth  [success=2 default=ignore]  pam_unix.so
```

### W-A — `tasten-led` ist für den Benutzer nicht ausführbar

**wichtig** · Funktionsausfall mit irreführender Fehlermeldung

```sh
# setup.sh:974 -- Gruppe audio
sudo install -m 750 -o root -g audio "/tmp/tasten-led.$$" /usr/local/bin/tasten-led
# setup.sh:743 -- der Benutzer wird aber nur in input aufgenommen
sudo usermod -aG input "$BENUTZER"
```

**Problem.** Modus `750 root:audio` bedeutet: nur root und Mitglieder der Gruppe `audio` dürfen
ausführen. Das Skript nimmt den Benutzer aber nirgends in `audio` auf, und Void tut das beim
Anlegen eines Kontos nicht von sich aus — PipeWire braucht die Gruppe nicht, sie fehlt auf einem
frischen System also typischerweise.

**Risiko.** Der gesamte Aufwand um `tasten-led` (das C-Programm, die Codec-Erkennung, `setcap`,
die Subsystem-Prüfung im Hardware-Block) läuft ins Leere: die LEDs in F5 und F8 bleiben dunkel.
Und die Fehlermeldung führt in die Irre —

```sh
# config/.local/bin/mikro-led:18
[ -x "$HELFER" ] || { echo "${0##*/}: $HELFER fehlt" >&2; exit 1; }
```

`-x` ist ohne Gruppenzugehörigkeit falsch, obwohl die Datei existiert. Gemeldet wird
„`/usr/local/bin/tasten-led` **fehlt**". Wer das liest, sucht nach einem gescheiterten Build —
nicht nach einer Gruppenzugehörigkeit. Aufgerufen wird es aus `exec_always` in der i3-Config
(`config/.config/i3/config:134-135`), also bei jedem Start und jedem Reload, wo die Meldung
niemandem auffällt.

**Fix.** Beides:

```sh
# setup.sh, Abschnitt "Gruppenzugehoerigkeit" -- audio dazu, weil tasten-led
# mit 750 root:audio installiert wird.
for g in input audio; do
    if id -nG "$BENUTZER" | tr ' ' '\n' | grep -qx "$g"; then
        info "$BENUTZER ist bereits in der Gruppe $g"
    else
        sudo usermod -aG "$g" "$BENUTZER"
        gut "$BENUTZER zur Gruppe $g hinzugefuegt (wirkt nach der naechsten Anmeldung)"
    fi
done
```

```sh
# config/.local/bin/mikro-led:18 und ton-led -- die Ursache benennen
if [ ! -e "$HELFER" ]; then
    echo "${0##*/}: $HELFER fehlt -- setup.sh hat es nicht gebaut" >&2; exit 1
elif [ ! -x "$HELFER" ]; then
    echo "${0##*/}: $HELFER nicht ausfuehrbar -- Gruppe audio fehlt? (id -nG)" >&2; exit 1
fi
```

### W-B — VS Code wird unbeaufsichtigt mit `filesystems=host` installiert

**wichtig** · bewusste Entscheidung, aber ohne Hinweis an den Nutzer

```sh
# setup.sh:525-526
sudo flatpak install -y flathub com.google.Chrome com.brave.Browser \
     com.visualstudio.code
```

Der Kommentar darüber (`setup.sh:522-524`) benennt es korrekt: „Der Flatpak hat
`filesystems=host`, kommt also ohne Zusatzrechte an alle Dateien." Mit `-y` wird genau das ohne
Rückfrage bestätigt. Der Sandkasten ist für diese Anwendung damit keiner — was für einen Editor
vertretbar ist, aber in der Schlussliste (`setup.sh:1149 ff.`) nicht auftaucht, obwohl dort
sieben andere Nachbereitungen stehen.

**Fix.** Kein Codewechsel nötig, ein Satz in der Schlussliste genügt — oder, falls die
Host-Rechte nicht gebraucht werden, eine Einschränkung auf die Projektverzeichnisse:

```sh
flatpak override --user com.visualstudio.code \
    --nofilesystem=host --filesystem=~/Projekte --filesystem=~/.ssh:ro
```

### Was hier **nicht** steht (weil geprüft und in Ordnung)

- **Kein `curl | sh`.** Der Bootstrap lädt in eine Datei und extrahiert; kein Pipe-in-Shell.
- **Keine Secrets.** Grep über Passwort/Token/Key/Private-Key: nur Fließtext in Kommentaren.
- **Kein `chmod 777`**, nichts world-writable durch explizite Modi.
- **Kein `eval`, `os.system`, `shell=True`, `popen`** im ganzen Baum.
- **SSIDs aus der Luft werden sauber behandelt.** `config/.local/bin/netz` ruft `wpa_cli` über
  argv-Listen auf (keine Shell), kodiert die SSID vor `set_network` als Hex (`netz:363`),
  rechnet das Passwort per PBKDF2 in den Schlüssel um statt es im Klartext abzulegen (`netz:370`)
  und escaped im SAE-Fall korrekt (`netz:368`). Das ist die Stelle mit den fremdesten Eingaben im
  ganzen Repo, und sie ist die am besten geschützte.
- **`sudoers` vorbildlich:** `visudo -c` vor der Installation, dann
  `install -m 440 -o root -g root`, jede Datei einzeln, mit passender Fehlermeldung je Schnipsel
  (`setup.sh:944-957`). Genau so gehört es gemacht.
- **`tasten-led.c`** nimmt keine freien Verbs entgegen (festes `argc`/`strcmp`-Gate, `main:160-166`),
  schreibt nur festverdrahtete Register und hat keine unbegrenzten Puffer.
- **`sperrsaver.c`** ist fail-safe: `char puffer[32]` mit korrekt begrenztem `fread`
  (`lies_zustand:116-121`), `argc != 5`-Prüfung, und fehlende Bilder ergeben `NULL` → leerer
  Hintergrund. Ein Absturz des Savers öffnet die Sperre nicht.

---

## 2. Robustheit / Fehlerbehandlung

### W1 — `acpid` läuft, bevor die entschärfte Regel liegt

**wichtig** · Reihenfolgefehler mit physischer Wirkung

- `setup.sh:657` schaltet `acpid` ein (in der Dienste-Schleife).
- `setup.sh:839` kopiert erst danach die neutralisierte Sammelregel `etc/acpi/events/anything`.
- `setup.sh:886` startet `acpid` dann neu.

Dazwischen liegen: die Scanner-Schleife (bis 12 s `sleep`), `sudo xbps-reconfigure -f
glibc-locales`, ein Schrift-Download und ein `git clone` — realistisch **1–3 Minuten**.

In diesem Fenster gilt die Regel des Pakets. Was die dann tut, steht im Repo selbst, in
`system/etc/acpi/events/anything:5-7`:

> ```
> #   * Einschalttaste -> sofortiges "shutdown -P now", ohne Rueckfrage
> #   * Deckel zu      -> zzz ohne vorheriges Sperren
> ```

**Risiko.** Auf einem frischen Void lief `acpid` vorher nicht — das Skript schaltet diese Gefahr
also selbst erst ein. Wer in diesen 1–3 Minuten den Deckel zuklappt, um Kaffee zu holen, bekommt
einen ungesperrten Suspend mitten in der Installation; wer die Einschalttaste streift, ein
sofortiges Aus mit halb installiertem System. Der Autor kennt die Gefahr und beschreibt sie präzise
— aktiviert den Dienst aber vorher.

**Fix.** `acpid` aus der Dienste-Schleife herausnehmen und erst nach dem Systemdateien-Abschnitt
aktivieren:

```sh
# setup.sh:657 -- acpid entfernen:
for d in dbus dhcpcd wpa_supplicant tailscaled bluetoothd alsa rtkit avahi-daemon; do

# ... und nach dem Kopieren der Systemdateien (nach Zeile 880):
if [ ! -e /var/service/acpid ]; then
    sudo ln -sf /etc/sv/acpid /var/service/
    gut "acpid eingeschaltet -- jetzt mit der eigenen Deckel-Regel"
elif ...
```

### W2 — Teil-Upgrade durch `xbps-install -Syu || true`

**wichtig** · Void-spezifisch

```sh
# setup.sh:498-500
sudo xbps-install -Syu || true          # erster Lauf aktualisiert ggf. nur xbps
# shellcheck disable=SC2086
sudo xbps-install -Sy $PAKETE
```

**Problem — dreifach.**

1. **Kein zweiter Lauf.** Der Kommentar benennt das Verhalten korrekt und zieht dann nicht die
   Konsequenz. Ist `xbps` selbst veraltet, aktualisiert Void ausschließlich `xbps` und verlangt
   einen zweiten Lauf. Der bleibt aus. `-Sy $PAKETE` installiert danach neue Pakete gegen ein nur
   halb aktualisiertes System — der klassische Weg zu `shared library not found`.

2. **Kein `-y` in Zeile 498.** Zeile 500 hat `-Sy`, Zeile 498 nur `-Syu`. Die
   Systemaktualisierung fragt also interaktiv zurück (`Do you want to continue? [Y/n]`) — der
   Installationsschritt eine Zeile später nicht. Im unbeaufsichtigten Modus ist das folgenreich:
   `setup.sh:360-361` schaltet bei fehlendem Terminal an stdin auf `UNATTENDED=1`, die Rückfrage
   bekommt dann EOF, `xbps-install` bricht ab — und `|| true` verschluckt es. Ergebnis: das
   System wird **überhaupt nicht** aktualisiert, gemeldet wird nichts.

3. **`|| true` verschluckt jeden echten Fehler** — kein Netz, kaputter Mirror, voller
   Datenträger.

**Fix.**

```sh
info "xbps wird aufgefrischt -- ggf. mehrfach, bis nichts mehr aussteht."
n=0
while [ $n -lt 3 ]; do
    # -y, weil Zeile 500 es auch hat -- sonst haengt der unbeaufsichtigte Lauf
    # an der Rueckfrage bzw. bricht bei EOF wortlos ab.
    aus=$(sudo xbps-install -Syuy 2>&1) || fehler "xbps-install -Syu ist gescheitert:
       $aus"
    printf '%s\n' "$aus" | grep -q 'up to date\|Nothing to do' && break
    n=$((n + 1))
done
[ $n -lt 3 ] || warn "xbps kommt nach 3 Laeufen nicht zur Ruhe -- bitte von Hand pruefen."
```

### W3 — Der zweite Lauf überschreibt eigene Änderungen ohne Sicherung

**wichtig** · Datenverlust

```sh
# setup.sh:1024-1031
sichern() {   # sichern <repo-datei> <ziel>
    [ -e "$2" ] || return 0
    cmp -s "$1" "$2" && return 0
    [ -e "$2.vor-void-i3" ] || cp -a "$2" "$2.vor-void-i3"     # <-- nur beim ERSTEN Mal
}
# setup.sh:1052
cp -r "$QUELLE/config/." "$HOME/"                              # <-- bedingungslos
```

**Risiko.** Lauf 1 sichert das Original nach `.vor-void-i3` — richtig. Der Nutzer passt danach
eine Woche lang `~/.config/i3/config` an. Lauf 2: `cmp` sieht den Unterschied, aber
`.vor-void-i3` existiert bereits → **keine neue Sicherung** → `cp -r` überschreibt die Woche
Arbeit. Ohne Warnung, ohne Rückfrage, ohne Wiederherstellungsmöglichkeit.

Der Kopf des Skripts (`setup.sh:14-15`) verspricht dabei:

> „Es ist mehrfach ausfuehrbar: bestehende Dateien werden vor dem Ueberschreiben nach
> `<datei>.vor-void-i3` gesichert."

Das gilt nur für den ersten Lauf. Der Zähler (`1046`, `1051`) zählt außerdem *vorhandene*
`.vor-void-i3`-Dateien, nicht in diesem Lauf gesicherte — die Meldung „N Dateien liegen als
.vor-void-i3 gesichert" erscheint also auch dann, wenn gerade nichts gesichert wurde. (Die
Formulierung ist streng genommen korrekt gewählt, im Kontext liest sie sich trotzdem als
Entwarnung.)

**Zweite, gegenläufige Wirkung derselben Logik.** Für Dateien, die es *vor* Lauf 1 gar nicht gab
— alle Skripte in `~/.local/bin`, die i3-Config, `i3status/config` —, greift in Lauf 1
`[ -e "$2" ] || return 0`: keine Sicherung, richtig so. In Lauf 2 existieren sie aber, und `cmp`
sieht einen Unterschied zur Repo-Vorlage, weil Lauf 1 die Platzhalter ersetzt hat
(`setup.sh:1066-1102`). Es entsteht also eine `.vor-void-i3`-Datei, die **die Ausgabe von Lauf 1
enthält** — nicht den Zustand „vor void-i3", wie der Name behauptet. Nebenbei landen diese
Dateien in `~/.local/bin`, das im `PATH` liegt, und bekommen von `setup.sh:1053` auch noch
`chmod 755`.

Die Design-Entscheidung — `.vor-void-i3` soll der Stand *vor dem ersten Lauf* bleiben — ist
nachvollziehbar. Die beiden Folgen daraus sind nur nirgends benannt.

**Fix.** Der ersten Sicherung eine zweite zur Seite stellen:

```sh
sichern() {   # sichern <repo-datei> <ziel>
    [ -e "$2" ] || return 0
    cmp -s "$1" "$2" && return 0
    if [ -e "$2.vor-void-i3" ]; then
        # Nach dem ersten Lauf abgewichen: das ist eigene Arbeit, die sonst
        # verloren ginge. Zeitgestempelt daneben legen.
        cp -a "$2" "$2.vor-$(date +%Y%m%d-%H%M%S)"
        EIGENE=$((EIGENE + 1))
    else
        cp -a "$2" "$2.vor-void-i3"
    fi
}
# ... nach der Schleife:
[ "$EIGENE" -eq 0 ] || warn "$EIGENE Dateien wichen von der Vorlage ab und wurden zeitgestempelt
       gesichert, bevor sie ueberschrieben wurden."
```

### W4 — `flatpak update` erreicht die Browser nicht

**wichtig** · trifft die Begründung des Designs

```sh
# setup.sh:520-526 -- systemweite Installation
sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak install -y flathub com.google.Chrome com.brave.Browser com.visualstudio.code
```

Die Begründung dafür steht in `setup.sh:507-510`:

> „jedes Sicherheitsupdate muesste man von Hand nachbauen — bei einem Browser alle paar Wochen.
> Flatpak aktualisiert stattdessen mit `flatpak update` mit."

**Problem.** `sudo flatpak install` legt in die **System**-Installation. Ein `flatpak update` als
normaler Benutzer erreicht nur die **User**-Installation; für die System-Installation verlangt
Flatpak eine polkit-Autorisierung. Im ganzen Setup wird **kein polkit-Authentifizierungsagent**
installiert oder gestartet — geprüft in der Paketliste (`setup.sh:391-500`) und in allen
`exec`/`exec_always`-Zeilen der i3-Config.

**Risiko.** Der Browser ist die größte Angriffsfläche des Systems, und der dokumentierte
Update-Weg funktioniert für ihn nicht. Er rostet still vor sich hin. Genau das Szenario, das die
Flatpak-Entscheidung vermeiden sollte.

**Fix.** Entweder als Benutzer installieren (dann greift `flatpak update` wie beschrieben):

```sh
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub com.google.Chrome com.brave.Browser com.visualstudio.code
```

— das passt auch besser zu den `flatpak override --user`-Aufrufen in `540` und `599`, die ohnehin
schon auf die User-Ebene zielen. Oder bei der Systeminstallation bleiben und die Schlussliste
(`setup.sh:1149 ff.`) um einen Punkt ergänzen: `sudo flatpak update` gehört dann in denselben
Rhythmus wie `xbps-install -Su`.

### W5 — `sed -i` meldet Erfolg, auch wenn es nichts ersetzt hat

**wichtig** · betrifft 6 Stellen

`sed -i` liefert 0, unabhängig davon, ob eine Ersetzung stattgefunden hat. Das Muster
„`sed -i …` gefolgt von `gut "…"`" behauptet damit an sechs Stellen einen Erfolg, den es nicht
geprüft hat: `setup.sh:615-617`, `692`, `720`, `729`, `912-916`, `928`.

Am folgenreichsten bei Bluetooth:

```sh
# setup.sh:614-617
if grep -q '^AutoEnable=false' /etc/bluetooth/main.conf; then
    info "Bluetooth startet bereits ausgeschaltet"
else
    sudo sed -i 's/^#\?AutoEnable=true$/AutoEnable=false/' /etc/bluetooth/main.conf
    gut "Bluetooth startet ausgeschaltet"
fi
```

**Risiko.** Neuere bluez-Fassungen schreiben `AutoEnable = true` (mit Leerzeichen um das
Gleichheitszeichen) bzw. führen den Schlüssel unter `[Policy]`. Der Ausdruck trifft dann nicht,
der Wächter `grep -q '^AutoEnable=false'` findet ebenfalls nichts — und das Skript meldet
`gut "Bluetooth startet ausgeschaltet"`, während der Adapter beim nächsten Boot trotzdem angeht.
Der Nutzer hält eine Einstellung für gesetzt, die es nicht ist. Bei Bluetooth ist das eine
Angriffsfläche, die stillschweigend offen bleibt.

**Fix** — nach der Änderung nachsehen statt annehmen:

```sh
sudo sed -i -E 's/^#?[[:space:]]*AutoEnable[[:space:]]*=[[:space:]]*true[[:space:]]*$/AutoEnable=false/' \
    /etc/bluetooth/main.conf
if grep -qE '^AutoEnable[[:space:]]*=[[:space:]]*false' /etc/bluetooth/main.conf; then
    gut "Bluetooth startet ausgeschaltet"
else
    warn "AutoEnable liess sich nicht setzen -- Bluetooth geht beim Booten an.
       Bitte in /etc/bluetooth/main.conf von Hand pruefen (Abschnitt [Policy])."
fi
```

Dasselbe Muster gehört an die fünf übrigen Stellen.

### W6 — Kein Rollback beim Fingerabdruck-Build

**wichtig**

```sh
# fingerabdruck/einrichten.sh:80-85 -- VOR dem Build
for p in fprintd libfprint libfprint-udev-rules; do
    if xbps-query "$p" >/dev/null 2>&1; then
        sudo xbps-remove -y "$p" >/dev/null
```

**Risiko.** Die Void-Pakete fliegen raus, bevor der Ersatz existiert. Bricht danach irgendetwas ab
— Netz weg beim `git clone` (`92`, `112`), Compile-Fehler, `meson` findet eine Abhängigkeit nicht
— bleibt das System **ganz ohne** `fprintd` und `libfprint`. `setup.sh:1011-1014` fängt das nur mit
einem `warn` ab und läuft weiter, sodass der Fehler in der langen Ausgabe untergeht.

Die Begründung im Kommentar (beide legen `pam_fprintd.so` ab) ist sachlich richtig — die
Reihenfolge folgt daraus aber nicht.

**Fix.** Erst bauen, dann in einem Zug entfernen und installieren:

```sh
ninja -C "$BAU/libfprint/build" -j "$JOBS" >/dev/null
ninja -C "$BAU/fprintd/build"   -j "$JOBS" >/dev/null
# Ab hier steht alles fertig gebaut bereit -- erst jetzt die Void-Pakete weg.
for p in fprintd libfprint libfprint-udev-rules; do
    xbps-query "$p" >/dev/null 2>&1 && sudo xbps-remove -y "$p" >/dev/null
done
sudo ninja -C "$BAU/libfprint/build" install >/dev/null
sudo ninja -C "$BAU/fprintd/build"   install >/dev/null
```

### W-C — Die Schriftinstallation kann sich dauerhaft selbst blockieren

**wichtig** · Idempotenzfalle + falsche Erfolgsmeldung

```sh
# setup.sh:752-765
if [ -d /usr/share/fonts/redhat-mono ]; then
    info "liegt schon unter /usr/share/fonts/redhat-mono"
else
    ...
    tar xzf "$TMPF/rh.tar.gz" -C "$TMPF"
    sudo mkdir -p /usr/share/fonts/redhat-mono          # <-- vor dem Kopieren
    find "$TMPF" -name 'RedHatMono-*.ttf' -exec sudo cp {} /usr/share/fonts/redhat-mono/ \;
    ...
    gut "$(ls /usr/share/fonts/redhat-mono/*.ttf | wc -l) Schnitte installiert"
fi
```

**Problem.** Das Verzeichnis wird angelegt, **bevor** feststeht, dass etwas hineinkommt. Der
Wächter in Zeile 752 prüft aber nur auf das Verzeichnis, nicht auf seinen Inhalt.

**Risiko.** Ändert sich die Struktur des Archivs (der Tag ist verschiebbar, siehe K2), findet
`find` nichts. Dann:

1. Das Verzeichnis existiert und ist leer.
2. `ls …/*.ttf` scheitert, `wc -l` liefert `0`, und die Meldung lautet — als `gut`, also grün —
   „**0 Schnitte installiert**".
3. **Jeder weitere Lauf** springt in den `if`-Zweig und meldet „liegt schon unter …". Die Schrift
   wird nie wieder nachinstalliert, auch nicht nach einer Korrektur.

Da Red Hat Mono in `alacritty.toml`, `i3status`, `dunstrc` und im Sperrbild verwendet wird, fällt
überall auf Ersatzschriften zurück — und der einzige Weg zurück ist, das leere Verzeichnis von
Hand zu löschen. Nichts im Skript sagt das.

**Fix.** Auf den Inhalt prüfen, nicht auf das Verzeichnis, und den Fehlschlag benennen:

```sh
if [ -n "$(find /usr/share/fonts/redhat-mono -name '*.ttf' 2>/dev/null | head -n1)" ]; then
    info "liegt schon unter /usr/share/fonts/redhat-mono"
else
    TMPF=$(mktemp -d) || fehler "kein temporaeres Verzeichnis"
    trap 'rm -rf "$TMPF"' EXIT INT TERM
    xbps-fetch -o "$TMPF/rh.tar.gz" "$RH_URL" || fehler "Red Hat Mono konnte nicht geladen werden."
    printf '%s  %s\n' "$RH_SHA256" "$TMPF/rh.tar.gz" | sha256sum -c - >/dev/null 2>&1 \
        || fehler "Pruefsumme von RedHatFont stimmt nicht."
    tar xzf "$TMPF/rh.tar.gz" -C "$TMPF"
    # Erst zaehlen, dann anlegen: ein leeres Verzeichnis wuerde jeden
    # weiteren Lauf an dieser Stelle vorbeischicken.
    anzahl=$(find "$TMPF" -name 'RedHatMono-*.ttf' | wc -l)
    [ "$anzahl" -gt 0 ] || fehler "Im Archiv steckt keine RedHatMono-*.ttf --
       hat sich der Aufbau des Repos geaendert? Stand in setup.sh pruefen."
    sudo mkdir -p /usr/share/fonts/redhat-mono
    find "$TMPF" -name 'RedHatMono-*.ttf' \
        -exec sudo install -m 644 -o root -g root {} /usr/share/fonts/redhat-mono/ \;
    gut "$anzahl Schnitte installiert"
fi
```

Dasselbe Muster („Verzeichnis existiert" als Beleg für „ist eingerichtet") steht auch bei
`setup.sh:787` für das Cursor-Theme und trägt dort dasselbe Risiko.

### W-D — Die udev-Regel für `/dev/rfkill` wird nie angewandt

**wichtig**

```sh
# setup.sh:893-894
sudo udevadm hwdb --update
sudo udevadm trigger --sysname-match="event*"
```

**Problem.** Der Trigger greift nur Geräte, deren sysname auf `event*` passt — also
`/sys/class/input/event*`, die Tastaturen für den hwdb-Remap. Die zweite Regel in derselben
soeben kopierten Datei betrifft aber ein ganz anderes Gerät:

```
# etc/udev/rules.d/60-rfkill-unblock.rules:15
KERNEL=="rfkill", SUBSYSTEM=="misc", GROUP="wheel", MODE="0660"
```

Dessen sysname ist `rfkill` im Subsystem `misc` — von `--sysname-match="event*"` nicht erfasst.
`/dev/rfkill` behält also `root:root 0644` bis zum nächsten Neustart.

**Risiko.** Genau daran hängt laut Kommentar in `config/.local/bin/netz:19-21` das Ein- und
Ausschalten des Funks per Leistenklick — für WLAN wie für Bluetooth. Nach dem Setup funktioniert
das nicht, und die Schlussliste (`setup.sh:1149 ff.`) rät zu **Abmelden und neu anmelden**, nicht
zum Neustart. Wer der Anleitung folgt, hat einen toten Funk-Klick und keinen Anhaltspunkt, warum.

**Fix.** Die Regeln neu einlesen und breiter triggern:

```sh
sudo udevadm control --reload
sudo udevadm trigger --sysname-match="event*"                      # hwdb / Tastatur
sudo udevadm trigger --subsystem-match=misc --sysname-match=rfkill # /dev/rfkill an wheel
info "Tastatur-Remap und rfkill-Rechte aktiv"
```

### W-E — `bereitschaft()` legt den Rechner auch dann schlafen, wenn das Sperren scheitert

**wichtig**

```sh
# config/.local/bin/i3-sitzung:279-284
bereitschaft() {
    # Erst sperren, dann schlafen -- sonst liegt der entsperrte Schirm beim
    # Aufwachen offen da. sperren kehrt zurueck, sobald die Sperre steht.
    sperren
    sudo zzz
}
```

**Problem.** `sperren()` liefert bei einem Fehlschlag ausdrücklich `1` zurück
(`i3-sitzung:150-153`: „xsecurelock kam nicht hoch — Schirm bleibt offen"). `bereitschaft()`
prüft diesen Rückgabewert nicht, und das Skript hat kein `set -e`. Der Kommentar direkt darüber
benennt das Ziel — „sonst liegt der entsperrte Schirm beim Aufwachen offen da" — und der Code
stellt es nicht sicher.

**Risiko.** Kommt `xsecurelock` nicht hoch — laut Kommentar in `i3-sitzung:41-44` etwa, weil
gerade ein rofi die Tastatur greift —, schläft der Rechner trotzdem und wacht mit offenem
Schreibtisch auf.

Zum Vergleich: `/etc/acpi/deckel.sh:45-49` behandelt exakt denselben Fall bewusst und schreibt
ihn wenigstens ins Log („Sperre kam nicht hoch — es wird trotzdem geschlafen"). In
`bereitschaft()` passiert nicht einmal das.

**Fix.**

```sh
bereitschaft() {
    if ! sperren; then
        notify-send -u critical "Bereitschaft abgebrochen" \
            "Der Sperrbildschirm kam nicht hoch -- der Rechner bleibt wach." 2>/dev/null
        logger -t i3-sitzung "Sperre kam nicht hoch -- Bereitschaft abgebrochen"
        return 1
    fi
    sudo zzz
}
```

### W7 — `timestamp_timeout=0` wird mitten im Lauf scharf geschaltet

**wichtig** · Reihenfolge

`setup.sh:944-947` installiert `20-zeitfenster` mit `Defaults timestamp_timeout=0`. Ab diesem
Moment fragt **jeder** weitere `sudo`-Aufruf erneut nach dem Passwort — unter anderem die rund
zehn `sudo`-Aufrufe im minutenlangen Fingerabdruck-Build (`einrichten.sh`), der direkt danach
startet (`setup.sh:1011`).

Das widerspricht dem Versprechen im Kopf des Skripts (`setup.sh:17-18`):

> „mit `VOID_I3_UNATTENDED=1` laeuft es ohne jede Rueckfrage durch"

**Fix.** Die sudoers-Schnipsel als **letzten** Schritt ablegen (nach dem Fingerabdruck-Abschnitt),
oder vorher eine Anmeldung auffrischen und offen halten. Das Einfachste ist die Umsortierung: die
Regeln werden erst nach dem nächsten Login gebraucht, nicht während der Installation.

### W8 — Der `INT`-Trap räumt das Quellverzeichnis weg, beendet das Skript aber nicht

**wichtig**

```sh
# setup.sh:55-56
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT INT TERM
```

**Problem.** Der Handler löscht `$TMP` und ruft **kein `exit`** auf. POSIX sh setzt die Ausführung
nach einem Signal-Handler hinter dem unterbrochenen Befehl fort. `$TMP` ist im Bootstrap-Fall aber
genau das Verzeichnis, in dem `$QUELLE` liegt — das Skript arbeitet danach gegen einen gelöschten
Quellbaum weiter.

Gegengetestet, weil die Semantik gern falsch angenommen wird:

```
$ sh t5.sh &   # danach kill -INT
quelle liegt in /tmp/tmp.bSHx3rqDmx
  [trap] raeume /tmp/tmp.bSHx3rqDmx weg
  WEITER: Skript laeuft nach Strg+C weiter
  QUELLE noch da? NEIN
exit=0
```

**Risiko.** Meist fängt `set -e` das eine Zeile später ab, weil der nächste Zugriff auf `$QUELLE`
scheitert. An den Stellen, an denen der Rückgabewert maskiert ist, greift das aber nicht — allen
voran `setup.sh:498` (`sudo xbps-install -Syu || true`). Ein Ctrl-C während des minutenlangen
Paketdownloads löscht dort den Quellbaum, `|| true` schluckt den Abbruch, und das Skript läuft mit
`$QUELLE` ins Leere weiter — bis irgendwann eine Meldung kommt, die mit der Ursache nichts mehr zu
tun hat. Am Ende steht `exit=0`: ein abgebrochener Lauf meldet Erfolg.

**Fix.** Abbruchsignale müssen beenden, und die beiden anderen `mktemp`-Verzeichnisse brauchen
denselben Schutz (`setup.sh:755` für `TMPF`, `790` für `TMPC` haben gar keinen `trap` — beim
Aufruf aus einem geklonten Repo ist damit überhaupt keiner aktiv, und bei `TMPC` bleibt ein
Git-Clone liegen):

```sh
# Eine Liste, ein Handler -- Abbruchsignale beenden das Skript, EXIT nur aufraeumen.
TEMPORAER=""
aufraeumen() { [ -z "$TEMPORAER" ] || rm -rf $TEMPORAER; }
trap aufraeumen EXIT
trap 'aufraeumen; exit 130' INT     # 128 + SIGINT
trap 'aufraeumen; exit 143' TERM    # 128 + SIGTERM

# und an jeder mktemp-Stelle:
TMPF=$(mktemp -d) || fehler "kein temporaeres Verzeichnis"
TEMPORAER="$TEMPORAER $TMPF"
```

### Was hier **nicht** steht

- **`set -eu` ist gesetzt** (`setup.sh:29`, `einrichten.sh:28`). `pipefail` gibt es in POSIX sh
  nicht — der Verzicht ist korrekt, siehe N3 für die Restlücke.
- Zwei Verdachtsfälle rund um `set -e` in AND-Listen (`setup.sh:1046` und `1132`) wurden
  **gegengetestet und verworfen**: weder dash noch bash brechen dort ab. Sie stehen deshalb nicht
  in der Liste.
- **Netzausfall** ist an jeder Download-Stelle abgefangen (`|| fehler …`, Zeilen 59, 758, 795).
- **Die Hardware-Vorprüfung** (`setup.sh:69-220`) läuft vollständig vor der ersten Änderung und
  vor der ersten Frage. Das ist genau die richtige Stelle dafür.

---

## 3. Code-Qualität

### W9 — Wallpaper mit Leerzeichen zerlegt den Sperrbildschirm

**wichtig** · einziger unquotierter Wert im Repo

```sh
# config/.local/bin/sperrbild:151-160
grundlage="$wallpaper -resize ${breite}x${hoehe}^ -gravity center …"
...
# shellcheck disable=SC2086  -- $grundlage soll in Woerter zerfallen
magick $grundlage \
```

**Risiko.** Das Wortsplitting ist beabsichtigt — es soll die Optionen trennen. Es trennt aber auch
den Dateinamen. Ein Bild namens `Mein Bild.jpg` — sehr wahrscheinlich, `setup.sh:1110` legt
`~/Bilder/Wallpapers` an und fordert eigene Bilder ausdrücklich an — zersplittert den Aufruf,
`magick` scheitert, `2>/dev/null` (`sperrbild:174`) verschluckt die Meldung, und `echo "$ziel"`
liefert trotzdem den Pfad einer Datei, die nie entstanden ist. Ergebnis: Sperrbildschirm ohne
Hintergrund, ohne jeden Hinweis, warum.

**Fix** — Argumentliste statt Zeichenkette:

```sh
if [ -n "$wallpaper" ] && [ -f "$wallpaper" ]; then
    klein_b=$(( breite / 8 )); klein_h=$(( hoehe / 8 ))
    set -- "$wallpaper" -resize "${breite}x${hoehe}^" -gravity center \
           -extent "${breite}x${hoehe}" -resize "${klein_b}x${klein_h}!" -blur 0x2 \
           -resize "${breite}x${hoehe}!" -fill black -colorize "${ABDUNKLUNG}%"
else
    set -- -size "${breite}x${hoehe}" "xc:#161616"
fi
magick "$@" -gravity north …
```

### W10 — `chmod 755` trifft auch fremde Dateien

**wichtig**

```sh
# setup.sh:1053
chmod 755 "$HOME"/.local/bin/* "$HOME/.config/i3/wallpaper.sh"
```

Der Glob trifft *alles* in `~/.local/bin`, auch eigene Skripte des Nutzers, die bewusst `700`
waren. Ein privates Skript mit einem API-Token darin wird damit world-readable.

**Fix** — nur die Dateien aus dem Repo:

```sh
(cd "$QUELLE/config/.local/bin" && find . -type f) | while read -r f; do
    chmod 755 "$HOME/.local/bin/${f#./}"
done
chmod 755 "$HOME/.config/i3/wallpaper.sh"
```

### W11 — Rechte im Home hängen von der umask ab

**wichtig** · Härtung

`setup.sh:1052` (`cp -r`) setzt nirgends explizite Modi. Gegengetestet:

| umask | Ergebnis |
|---|---|
| 022 (Void-Standard) | 644 / 755 — in Ordnung |
| 002 | 644 / 755 |
| 000 | **666 / 777** — world-writable |

Auch `setup.sh:761-762` kopiert die Schriften mit `sudo cp` ohne Modus; ausgerechnet einen Block
weiter (`798-801`) macht das Skript es für das Cursor-Theme richtig, mit explizitem `chown` und
getrenntem `chmod` für Verzeichnisse und Dateien. Für `sudoers` (`947`) ebenfalls vorbildlich —
im Home und bei den Schriften fehlt es.

**Fix.** Für die Schriften `install` statt `cp`:

```sh
find "$TMPF" -name 'RedHatMono-*.ttf' \
    -exec sudo install -m 644 -o root -g root {} /usr/share/fonts/redhat-mono/ \;
```

Für das Home eine umask setzen, bevor kopiert wird:

```sh
umask 022      # ganz oben, direkt nach "set -eu": die Rechte im Home sollen
               # nicht von der Umgebung abhaengen, aus der das Skript startet
```

### N1 — Die Kontrolle am Ende prüft zu wenig und schweigt im Fehlerfall

**nice-to-have**

```sh
# setup.sh:1131-1133
for s in "$HOME"/.local/bin/vitals-btop "$HOME"/.local/bin/wallpaper "$HOME/.config/i3/wallpaper.sh"; do
    [ -f "$s" ] && { sh -n "$s" && info "ok: $(basename "$s")"; }
done
```

Zwei Lücken:

1. **Schlägt `sh -n` fehl**, gibt es weder ein `ok:` noch eine Warnung — nur die rohe
   Shell-Meldung auf stderr, ohne Einordnung. Die i3-Prüfung direkt darüber (`1125-1130`) macht es
   richtig und warnt ausdrücklich.
2. Geprüft werden **3 von rund 25** Skripten — und die Python-Dateien gar nicht. Dabei bekommt
   ausgerechnet die Python-Datei `i3-workspace-names` einen `sed`-Eingriff ab (`1066`, `1094`,
   `1101`). Wenn der etwas Ungültiges einsetzt, merkt es niemand.

**Fix.**

```sh
for s in "$HOME"/.local/bin/*; do
    [ -f "$s" ] || continue
    case "$(head -n1 "$s")" in
        *python*) python3 -m py_compile "$s" 2>/dev/null \
                      && info "ok: $(basename "$s")" \
                      || warn "Syntaxfehler in $(basename "$s")" ;;
        *sh)      sh -n "$s" 2>/dev/null \
                      && info "ok: $(basename "$s")" \
                      || warn "Syntaxfehler in $(basename "$s")" ;;
    esac
done
```

### N2 — Zeilenumbruch überlebt `name_saeubern`

**nice-to-have**

```sh
# setup.sh:246
name_saeubern() { printf '%s' "$1" | tr -d '|&\\"'"'"; }
```

Die Blacklist (`| & \ " '`) ist gut gewählt und schließt die Wege in `sed`-Ersetzung und
Antwortdatei sauber — das wurde durchgespielt und hält. Nur der **Zeilenumbruch** bleibt übrig.
Über `read -r` kann er nicht hereinkommen, über die Umgebungsvariable schon:

```sh
VOID_I3_WS2=$'lokal\nboese' sh setup.sh
```

führt bei `setup.sh:1066` zu `sed: unterminated 's' command` und damit zum Abbruch — **nachdem**
bereits nach `$HOME` kopiert wurde (`1052`). Halb eingerichtetes System, Fehlermeldung ohne Bezug
zur Ursache.

`ziel_saeubern` (`setup.sh:249`) macht es bereits richtig: `tr -cd` mit Whitelist. Derselbe Ansatz
für `name_saeubern` schließt die Lücke und ist zugleich leichter zu prüfen:

```sh
# Whitelist statt Blacklist: alles, was ein Arbeitsflaechenname braucht.
# Umlaute bleiben (tr arbeitet byteweise, UTF-8 faellt nicht unter [:cntrl:]).
name_saeubern() { printf '%s' "$1" | tr -d '|&\\"'"'" | tr -d '[:cntrl:]'; }
```

### N3 — Kein `pipefail`-Ersatz

**nice-to-have**

POSIX sh kennt `set -o pipefail` nicht — der Verzicht ist also richtig. Die Restlücke sollte man
trotzdem kennen: Der Rückgabewert einer Pipeline ist der des *letzten* Glieds. Beispiel
`setup.sh:761` (im Text von `gut`):

```sh
gut "$(ls /usr/share/fonts/redhat-mono/*.ttf | wc -l) Schnitte installiert"
```

Sind keine `.ttf` angekommen, scheitert `ls`, `wc -l` liefert `0`, und die Meldung lautet
freundlich „0 Schnitte installiert". An kritischen Pipelines das Ergebnis prüfen statt der
Pipeline:

```sh
anzahl=$(find /usr/share/fonts/redhat-mono -name '*.ttf' | wc -l)
[ "$anzahl" -gt 0 ] || fehler "Red Hat Mono wurde entpackt, aber keine .ttf gefunden."
gut "$anzahl Schnitte installiert"
```

### N4 — Duplizierter Ausgabe-Header

**nice-to-have**

`setup.sh:31-42` und `fingerabdruck/einrichten.sh:30-39` sind bis auf eine Zeile identisch
(Farben + `schritt`/`info`/`gut`/`warn`/`fehler`). Eine gemeinsame `void-i3/lib/ausgabe.sh`, von
beiden mit `.` eingelesen, spart die Doppelpflege. Beim Bootstrap-Fall (`setup.sh:57`) muss sie
mit im Archiv liegen — das ist sie automatisch.

### N5 — Kein `shellcheck`, kein CI

**nice-to-have**

Im Repo gibt es keine `.github/workflows`, kein `shellcheckrc`, keinen Lint-Lauf. Für ein
Skript, das mit `sudo` über ein ganzes System läuft, ist ein Lint-Gate der billigste denkbare
Schutz — und die vorhandenen `# shellcheck disable=`-Kommentare (`setup.sh:255`, `499`,
`sperrbild:159`) zeigen, dass shellcheck ohnehin schon benutzt wird, nur eben von Hand.

```yaml
# .github/workflows/lint.yml
name: lint
on: [push, pull_request]
jobs:
  shellcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: |
          sudo apt-get update && sudo apt-get install -y shellcheck
          # -s sh: als POSIX-Shell pruefen, nicht als bash
          find void-i3 -type f \( -name '*.sh' -o -path '*/.local/bin/*' \) \
            -exec sh -c 'head -n1 "$1" | grep -q "^#!/bin/sh" && shellcheck -s sh "$1"' _ {} \;
```

### N7 — `su …-c` baut eine Shell-Zeile aus Werten aus `/proc/<pid>/environ`

**nice-to-have** · hier ohne Rechtegewinn, aber ein Muster, das ein Review anhält

```sh
# system/etc/acpi/deckel.sh:45-47 -- laeuft als root
su "$benutzer" -c \
   "DISPLAY='$anzeige' XAUTHORITY='$cookie' ~/.local/bin/i3-sitzung sperren"
```

`$anzeige` und `$cookie` werden aus der Prozessumgebung des laufenden i3 gelesen
(`deckel.sh:35-37`) und dann in **einfache Anführungszeichen innerhalb einer Shell-Zeichenkette**
gesetzt, die `su -c` als Shell-Befehl auswertet. Ein `'` in `DISPLAY` bricht aus. Dasselbe in
`system/etc/zzz.d/resume/10-fingerabdruck:152-154` und `20-funk:39`.

**Warum es hier trotzdem nur nice-to-have ist:** die Umgebung gehört dem Benutzer, als der `su`
ausführt — wer sie manipulieren kann, führt damit Code als sich selbst aus. Keine Grenze wird
überschritten. Das gilt aber nur, solange genau ein Mensch das i3 betreibt; auf einem
Mehrbenutzersystem wäre es der direkte Weg von Benutzer A zu Benutzer B.

**Fix** — Werte als Umgebung übergeben statt in die Befehlszeile einzusetzen:

```sh
su "$benutzer" -c 'exec "$HOME/.local/bin/i3-sitzung" sperren' \
    DISPLAY="$anzeige" XAUTHORITY="$cookie"
# bzw. portabler:
DISPLAY="$anzeige" XAUTHORITY="$cookie" \
    setpriv --reuid="$benutzer" --regid="$benutzer" --init-groups \
    "$heim/.local/bin/i3-sitzung" sperren
```

### N8 — WLAN-Passphrase und PSK stehen in der Prozessliste

**nice-to-have**

```python
# config/.local/bin/netz:367-372 -- der Wert landet als argv in wpa_cli
gut = gut and ok("set_network", nummer, "psk",
                 '"' + passwort.replace("\\", "\\\\").replace('"', '\\"') + '"')
```

Argumente eines Prozesses stehen in `/proc/<pid>/cmdline` und sind für jeden lokalen Benutzer
lesbar, solange `wpa_cli` läuft. Im SAE-Fall ist es die Klartext-Passphrase, sonst der
abgeleitete PSK (der zum Verbinden genauso genügt).

Das ist deutlich besser als der übliche Weg über `wpa_passphrase` in eine Datei, und auf einem
Ein-Benutzer-Notebook ohne Belang. Sauber wäre `wpa_cli` im interaktiven Modus über stdin zu
füttern, sodass nichts in `argv` landet.

### N9 — `sudo ninja install` in einem benutzerschreibbaren Baum

**nice-to-have**

```sh
# fingerabdruck/einrichten.sh:48, 104, 126
BAU=${BAU:-$HOME/.cache/void-i3-fingerabdruck}
...
sudo ninja -C "$BAU/libfprint/build" install >/dev/null
```

`ninja install` führt Regeln aus `build.ninja` aus — als root, aus einem Verzeichnis, das dem
Benutzer gehört und zwischen Build und Install beschreibbar bleibt. Dieselbe Einordnung wie N7:
Der Benutzer hat ohnehin `sudo`, es wird keine Grenze überschritten. Es ist trotzdem das Muster,
das man in einem Build-Skript nicht sehen möchte, und `BAU` ist zusätzlich per Umgebungsvariable
überschreibbar (`BAU=/beliebig/pfad sh einrichten.sh`).

### Was hier **nicht** steht

- **Kein einziger Bashismus** in allen 26 `#!/bin/sh`-Dateien. Geprüft auf `[[`, `local`, `==`,
  `+=`, `<<<`, `source`, `echo -e`, Arrays, `$RANDOM`, `declare`, `shopt`, `read -a` — alle
  Treffer lagen ausschließlich in eingebetteten `awk`- und `python`-Heredocs. Auf einem System, wo
  `/bin/sh` dash ist, ist das die richtige und konsequent durchgehaltene Entscheidung.
- **Quoting ist sonst durchgehend korrekt.** Der einzige unquotierte Wert im ganzen Baum ist
  `magick $grundlage` (W9), und der ist mit einem `shellcheck disable` bewusst gesetzt.
- **Git-Modi stimmen:** 36 × `100755`, 40 × `100644`, keine falsch gesetzten Bits. Auch die
  bewusst nicht-ausführbaren Dateien sind richtig (`etc/runit/shutdown.d/05-sanft-beenden.sh`
  wird eingelesen, nicht ausgeführt; `etc/profile.d/claude-code.sh` ebenso).

---

## 4. Void-Linux-Spezifisches

### W12 — Eine Paketdatei wird per `sed` verändert

**wichtig**

```sh
# setup.sh:909-916
if [ -f /etc/sv/wpa_supplicant/run ]; then
    if grep -q 'chown -R root:root /run/wpa_supplicant' /etc/sv/wpa_supplicant/run; then
        sichern_system /etc/sv/wpa_supplicant/run
        sudo sed -i -e 's|install -m 700 …|install -m 750 -g wheel …|' …
```

**Problem.** `/etc/sv/wpa_supplicant/run` gehört dem Paket `wpa_supplicant` und ist kein
`conf_file` im Sinne von xbps. Beim nächsten `xbps-install -Su` wird es ersetzt.

**Risiko.** Die Öffnung des Control-Sockets für `wheel` fällt still zurück. `~/.local/bin/netz`
kommt danach nicht mehr an `wpa_supplicant` — der WLAN-Klick in der Leiste tut nichts, ohne
erkennbaren Grund, Wochen nach der Installation. Die Fehlersuche führt garantiert nicht zu einem
Paketupdate.

Zu prüfen mit: `xbps-query -f wpa_supplicant | grep /etc/sv`

**Fix.** Der Void-konforme Weg ist ein eigener Dienst, der das Paket nicht anfasst:

```sh
# Eigener Dienst statt Eingriff in die Paketdatei -- xbps-Updates fassen
# /etc/sv/wpa_supplicant-void-i3 nicht an.
sudo mkdir -p /etc/sv/wpa_supplicant-void-i3
sudo cp /etc/sv/wpa_supplicant/run /etc/sv/wpa_supplicant-void-i3/run
sudo sed -i -e 's|install -m 700 -g root -o root -d|install -m 750 -g wheel -o root -d|' \
            -e 's|chown -R root:root /run/wpa_supplicant|chown -R root:wheel /run/wpa_supplicant\nchmod 750 /run/wpa_supplicant|' \
    /etc/sv/wpa_supplicant-void-i3/run
sudo chmod 755 /etc/sv/wpa_supplicant-void-i3/run
```

Minimalvariante, wenn der Eingriff bleiben soll: `netz` beim Start prüfen lassen, ob der Socket
erreichbar ist, und im Fehlerfall auf genau diese Ursache hinweisen — das Skript hat mit
`erreichbar()` (`netz:129`) bereits die passende Funktion dafür.

### N6 — Ein falscher Paketname bricht die gesamte Installation ab

**nice-to-have**

```sh
# setup.sh:500
sudo xbps-install -Sy $PAKETE
```

`xbps` installiert bei einem unbekannten Paketnamen **gar nichts** und bricht mit
`Package 'foo' not found in repository pool` ab. Zusammen mit `set -e` endet das Skript dort —
das ist an sich richtig (kein halb installiertes System), aber die 40+ Namen in der Liste sind
ein einziger Punkt, an dem eine Umbenennung im Void-Repo das ganze Setup lahmlegt, ohne dass der
Nutzer sieht, welcher Name schuld ist.

```sh
# Erst pruefen, welche Namen es im Repo wirklich gibt -- eine Umbenennung
# soll nicht die ganze Liste lahmlegen.
fehlend=""
for p in $PAKETE; do
    xbps-query -Rs "$p" 2>/dev/null | grep -q "^\[-\] $p-" || fehlend="$fehlend $p"
done
[ -z "$fehlend" ] || fehler "Diese Pakete gibt es im Repo nicht (mehr):$fehlend
       Bitte die Liste in setup.sh anpassen."
sudo xbps-install -Sy $PAKETE
```

### Was hier **nicht** steht

- **runit ist korrekt bedient.** `ln -sf /etc/sv/$d /var/service/` (`setup.sh:663`) ist die
  Void-Konvention; die Existenzprüfungen davor (`658`, `660`) machen die Schleife idempotent, und
  fehlende Dienste werden gemeldet statt verschluckt.
- **Die Reihenfolge stimmt an den meisten Stellen.** `dbus reload` statt `restart` (`685`, mit
  ausführlicher Begründung, warum ein Neustart die laufende Sitzung zerlegen würde), `acpid
  restart` nach dem Ablegen der Regeln (`886`), `udevadm hwdb --update` + `trigger` (`893-894`),
  `fc-cache` nach der Schriftinstallation (`853`), Gruppe `input` mit Hinweis auf die nötige
  Neuanmeldung (`744`).
- **`/etc/rc.local`, `/etc/runit/shutdown.d/`, `/etc/zzz.d/resume/`** sind alle
  bestimmungsgemäß genutzt, und jede überschriebene Datei wird vorher per `sichern_system`
  (`setup.sh:826-828`) gesichert.
- **Die ausführbaren Bits** werden nach dem `cp` explizit gesetzt (`setup.sh:858-880`), mit der
  richtigen Begründung: `cp` behält den Modus einer bereits vorhandenen Zieldatei. Das ist ein
  Detail, das in vergleichbaren Skripten fast immer fehlt.
- **`etc/acpi/events/anything`** wird korrekt behandelt: das Original liegt bewusst *außerhalb*
  des Verzeichnisses, weil acpid dort jede Datei liest — inklusive einer Sicherungskopie. Sauber
  durchdacht.

---

## Priorisierte Liste

### Kritisch — vor dem nächsten Lauf, erst recht auf fremder Hardware

| # | Befund | Stelle | Aufwand |
|---|---|---|---|
| **K3** | Root schreibt und `chown`t in einen benutzerkontrollierten Pfad — Symlink-Angriff, umgeht die Passwortpflicht vollständig | `zzz.d/resume/10-fingerabdruck:84-90` | ~8 Zeilen |
| **K4** | Die Sicherungskopie reaktiviert die entschärfte acpid-Sammelregel — Deckel schläft ungesperrt, Einschalttaste fährt ohne Rückfrage herunter | `setup.sh:826-828`, `849` | ~10 Zeilen |
| K1 | Vorhersagbare `/tmp`-Dateien für Binaries, die `setcap`/root-Rechte bekommen | `setup.sh:973-977`, `992-995`, `einrichten.sh:165-167` | ~15 Zeilen |

K3 und K4 heben beide eine Zusicherung auf, die das Setup an anderer Stelle mühsam aufbaut — K3
die Passwortpflicht, K4 die Sperre beim Zuklappen. Beide sind zugleich unter den billigsten Fixes
im ganzen Bericht. Sie gehören zuerst behoben.

### Wichtig — vor „production-grade"

| # | Befund | Stelle |
|---|---|---|
| W0 | `nullok` im PAM-Stack des Sperrbildschirms | `pam.d/xsecurelock:30` |
| K2 | Kein Integritätsnachweis auf dem Download-Pfad (`main` ungepinnt) — s. Herabstufung dort | `setup.sh:57-62`, `756`, `793` |
| W-A | `tasten-led` für den Benutzer nicht ausführbar (Gruppe `audio` fehlt), Meldung sagt „fehlt" | `setup.sh:743` vs. `974`, `mikro-led:18` |
| W-C | Schriftinstallation kann sich dauerhaft selbst blockieren, meldet dabei Erfolg | `setup.sh:752-765` |
| W1 | `acpid` läuft 1–3 min mit der gefährlichen Sammelregel | `setup.sh:657` vs. `839` |
| W2 | Teil-Upgrade durch `xbps-install -Syu \|\| true` | `setup.sh:498-500` |
| W3 | Zweiter Lauf überschreibt eigene Änderungen ohne Sicherung | `setup.sh:1024-1031`, `1052` |
| W4 | `flatpak update` erreicht die systemweit installierten Browser nicht | `setup.sh:520-526` |
| W5 | `sed -i` meldet Erfolg ohne Treffer (6 Stellen, Bluetooth am kritischsten) | `setup.sh:615-617` u. a. |
| W6 | Kein Rollback beim Fingerabdruck-Build (Pakete weg vor dem Build) | `einrichten.sh:80-85` |
| W-D | udev-Regel für `/dev/rfkill` wird nie angewandt — Funk-Klick tot bis zum Neustart | `setup.sh:893-894` |
| W-E | `bereitschaft()` schläft auch, wenn das Sperren scheitert | `i3-sitzung:279-284` |
| W7 | `timestamp_timeout=0` mitten im Lauf → Passwortfragen im „unattended"-Modus | `setup.sh:944-947` |
| W8 | `INT`-Trap löscht den Quellbaum, beendet aber nicht — abgebrochener Lauf meldet Erfolg | `setup.sh:55-56`, `755`, `790` |
| W9 | Wallpaper mit Leerzeichen zerlegt den Sperrbildschirm | `sperrbild:160` |
| W10 | `chmod 755` auf alle Fremddateien in `~/.local/bin` | `setup.sh:1053` |
| W11 | Rechte im Home hängen von der umask ab | `setup.sh:1052`, `761-762` |
| W12 | Paketdatei `/etc/sv/wpa_supplicant/run` per `sed` verändert | `setup.sh:909-916` |
| W-B | VS Code mit `filesystems=host` ohne Rückfrage und ohne Hinweis | `setup.sh:525-526` |

### Nice-to-have

| # | Befund | Stelle |
|---|---|---|
| N1 | Endkontrolle prüft 3 von ~25 Skripten und schweigt im Fehlerfall | `setup.sh:1131-1133` |
| N2 | Zeilenumbruch überlebt `name_saeubern` | `setup.sh:246` |
| N3 | Kein `pipefail`-Ersatz an den Stellen, wo es zählt | `setup.sh:761` |
| N4 | Ausgabe-Header dupliziert | `setup.sh:31-42` ≙ `einrichten.sh:30-39` |
| N5 | Kein shellcheck, kein CI | Repo-Wurzel |
| N6 | Ein falscher Paketname bricht die ganze Liste | `setup.sh:500` |
| N7 | `su …-c` baut eine Shell-Zeile aus `/proc/<pid>/environ` | `deckel.sh:45-47` u. a. |
| N8 | WLAN-Passphrase/PSK stehen in `/proc/<pid>/cmdline` | `netz:367-372` |
| N9 | `sudo ninja install` in einem benutzerschreibbaren Baum | `einrichten.sh:48`, `104`, `126` |

**Vorschlag für die Reihenfolge.** K3, W0 und W-A sind zusammen unter einer Stunde und decken
den größten Teil des Sicherheitsgewinns ab. K1 und K2 sind der zweite Block. Alles Übrige lässt
sich stückweise nachziehen, ohne dass jemand darauf warten müsste.

---

## Ist das Skript production-ready?

**Noch nicht — aber der Abstand ist kleiner, als der Umfang dieses Berichts vermuten lässt.**

Die Substanz stimmt. Das ist ein Skript, das erkennbar von jemandem geschrieben wurde, der die
Fehler, gegen die es sich absichert, alle einmal selbst hatte: die Hardware-Vorprüfung vor der
ersten Änderung, das explizite `chmod` nach jedem `cp` mit der richtigen Begründung, `visudo -c`
vor dem Ablegen der sudoers-Schnipsel, die Hex-Kodierung der SSID vor `wpa_cli`, das Pinnen des
libfprint-Forks auf einen Commit-Hash, `dbus reload` statt `restart`, weil ein Neustart die
laufende Sitzung zerlegen würde. Solche Details stehen in kaum einem vergleichbaren Repo. Der
Kommentarstil — *warum* etwas so ist, nicht *was* die Zeile tut, oft mit Messwert und Datum — ist
besser als in den meisten kommerziellen Codebasen. Und die Stelle mit den fremdesten Eingaben im
ganzen System, die WLAN-Auswahl in `netz`, ist zugleich die am saubersten geschützte.

Vier Dinge trennen es von „production-grade":

1. **Zwei Befunde heben eine Zusicherung auf, die das Setup an anderer Stelle mühsam aufbaut.**
   K3 gibt jedem Code, der als Desktop-Benutzer läuft, root ohne Passwort — während
   `timestamp_timeout=0` und der Fingerabdruck-Stack eigens dafür da sind, genau das zu
   verhindern. K4 stellt über die eigene Sicherungskopie die acpid-Sammelregel wieder her, gegen
   die `events/deckel`, `deckel.sh` und der Aufwach-Hook gebaut wurden — der Deckel schläft damit
   im Münzwurf ungesperrt. Beides sind keine Härtungsdetails, das sind Widersprüche im
   Sicherheitsmodell. Und beide Male steht die richtige Überlegung bereits als Kommentar im
   Repo; sie ist nur an der Stelle nicht angewandt worden, wo sie greifen müsste.
2. **Vertrauen wird angenommen, nicht nachgewiesen.** Der Download-Pfad hat keine
   Integritätsprüfung, und der Einstieg lädt zweimal unabhängig von einem beweglichen Branch. Dass
   das Repo an einer Stelle (`einrichten.sh:43`) genau richtig gepinnt ist, zeigt: der Gedanke war
   da, er wurde nur nicht zu Ende geführt.
3. **Temporäre Dateien folgen einem Muster, das in keinem Security-Review durchgeht.** Drei
   Stellen — während `mktemp` an vier anderen Stellen desselben Skripts bereits korrekt im Einsatz
   ist. Reine Inkonsistenz, keine Wissenslücke.
4. **Das Skript meldet öfter Erfolg, als es welchen geprüft hat.** `sed -i` ohne Treffer (W5),
   „0 Schnitte installiert" als grüne Meldung (W-C), `gut "Bluetooth startet ausgeschaltet"` ohne
   Gegenprobe. Dazu zwei Versprechen im Kopf des Skripts, die der Code nicht hält: „mehrfach
   ausführbar mit Sicherung" gilt nur für den ersten Lauf (W3), „ohne jede Rückfrage" nur bis
   Zeile 947 (W7). In einem Audit wiegt diese Sorte Abweichung am schwersten, weil sie den Nutzer
   in Sicherheit wiegt, statt ihn auf ein Problem zu stoßen.

Keiner der Befunde ist strukturell. Es gibt keinen Umbau, keine Architekturfrage, nichts, das ein
Neuschreiben nötig machte. K3 sind acht Zeilen. K1 und K2 zusammen etwa fünfunddreißig. Die
wichtige Kategorie ist größtenteils Umsortieren (W1, W7) und Fehlerprüfung nachziehen (W2, W5,
W8, W-C). Danach würde das Skript ein Review in einem professionellen Umfeld bestehen — mit
Anmerkungen zum Stil, nicht zur Sicherheit.

**Einschätzung: 7/10 heute, 9/10 nach den drei kritischen und den neunzehn wichtigen Punkten.**
Gefunden wurde viel, weil überall genau nachgesehen wurde — nicht, weil viel kaputt wäre.

---

## Methodik

Geprüft wurde in zwei unabhängigen Durchgängen: eine manuelle Lesung des gesamten Baums und
sechs parallele Prüfer entlang getrennter Dimensionen (Supply-Chain, Rechte/PAM, Robustheit,
Shell-Qualität, Void-Spezifika, C-Code und privilegierte Helfer), deren Befunde anschließend
gegen den echten Code nachgeprüft wurden.

Shell-Semantik wurde gemessen statt erinnert. Fünf Verdachtsfälle sind dabei ausgeschieden und
stehen bewusst **nicht** in diesem Bericht:

- `set -e` bricht bei `[ -e datei ] && n=$((n+1))` am Schleifenende **nicht** ab (gegengetestet in
  dash und bash) — `setup.sh:1046` und `1132` sind in Ordnung.
- Ebenso wenig bricht es bei `[ -e /var/service/avahi-daemon ] && sudo sv restart …` auf oberster
  Ebene ab (`setup.sh:689`). Ein Prüfer hatte hier einen stummen Abbruch mitten im Lauf gemeldet;
  der Gegentest in dash und bash widerlegt das — beide laufen weiter. `set -e` greift nur beim
  *letzten* Befehl einer AND-OR-Liste, und der wird bei fehlgeschlagenem `[ … ]` nie erreicht.
- Die Zeichensäuberung in `name_saeubern` (`setup.sh:246`) hält gegen `sed`-Ersetzung *und* gegen
  das spätere Einlesen der Antwortdatei per `.` — durchgespielt für `|`, `&`, `\`, `"`, `'`, `` ` ``
  und `$`. Nur der Zeilenumbruch bleibt übrig (N2).
- `cp` überträgt keine zu weiten Rechte, solange die umask stimmt — gemessen für 022, 002 und 000.
  Der Befund ist deshalb als Härtung eingestuft (W11), nicht als Fehler.
- Ein Prüfer meldete, `netz` löse die SSID-Escapes **nach** dem Zeilen-Regex auf, sodass ein
  Zeilenumbruch in einer fremden SSID die Auswertung verschieben könne (`netz:66-83`, `218-226`).
  Das ist falsch herum: `wpa_cli` gibt SSIDs bereits printf-escaped aus, ein Zeilenumbruch kommt
  also als die zwei Zeichen `\n` an und kann `re.M` nicht brechen. Erst danach zu entwirren ist
  die *richtige* Reihenfolge — der Autor schreibt genau das in `netz:71`.

Ein Befund ist umgekehrt gegen die erste Einschätzung **härter** geworden: K4 wurde als
Doppelausführung der zzz-Hooks gemeldet. Beim Nachsehen betrifft dasselbe Muster auch
`/etc/acpi/events/`, und dort schon im ersten Lauf — mit deutlich schwereren Folgen. Ein weiterer
wurde **herabgestuft**: K2, siehe die Begründung dort.
