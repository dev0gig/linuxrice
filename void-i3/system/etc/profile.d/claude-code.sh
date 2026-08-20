# Selbstaktualisierung von Claude Code abschalten.
# Grund: das Auto-Update laeuft ueber "npm install -g @anthropic-ai/claude-code@latest".
# npm 11 fuehrt das Postinstall standardmaessig nicht aus und der latest-Tag des
# Hauptpakets kann dem des Native-Pakets vorauslaufen -- in beiden Faellen bleibt
# statt des ~334-MB-Binaries ein 500-Byte-Platzhalter zurueck und claude startet
# nicht mehr. Updates darum bewusst von Hand:
#   npm install -g @anthropic-ai/claude-code@<version>
export DISABLE_AUTOUPDATER=1
