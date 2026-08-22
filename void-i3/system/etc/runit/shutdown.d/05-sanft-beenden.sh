# Programme (Browser, Editor, dann der Rest der Sitzung) geordnet beenden,
# bevor 10-sv-stop.sh die Dienste stoppt und 70-pkill.sh nach einer Sekunde
# SIGKILL schickt. Siehe /usr/local/sbin/sanft-beenden.
if [ -x /usr/local/sbin/sanft-beenden ]; then
    msg "Beende Programme geordnet..."
    timeout 45 /usr/local/sbin/sanft-beenden --jetzt
fi
