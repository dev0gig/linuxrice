# linuxrice Agent Instructions

Dieses Repo ist eine **reproduzierbare Konfiguration realer Geräte**, keine normale Anwendung.

## Bereiche
- `handy-fold7-termux-i3/` — Samsung Fold 7 / Termux + Termux:X11 + i3, ohne Root.
- `laptop-void-i3/` — Void Linux + i3.

## Regeln
- Vor Änderungen README und das betroffene Setup vollständig lesen.
- Handy- und Laptop-Regeln nicht vermischen.
- Setup-Skripte müssen auf einem frischen Zielsystem möglichst idempotent/reproduzierbar bleiben.
- Keine privaten Schlüssel, Tokens, Geräte-IDs oder persönliche Secrets einbauen.
- Keine destruktiven Paket-/Dateisystemaktionen hinzufügen, ohne sie explizit abzusichern und zu dokumentieren.
- Bestehende funktionierende Konfiguration nicht „modernisieren“, wenn der Auftrag dies nicht verlangt.
- Shell-Syntax prüfen; bei Änderungen möglichst statische Prüfung/Dry-Run der betroffenen Teile verwenden.

Eine Prompt-Queue ist für dieses Repo nicht nötig. Größere Umbauten können direkt als explizite Aufgaben erfolgen.
