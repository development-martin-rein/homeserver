SystemMonitor Skripte

In diesem Ordner befinden sich zwei Bash-Skripte, die die Installation und Nutzung von System-Monitoring-Werkzeugen vereinfachen.

InstallSystemMonitor.sh

Dieses Skript installiert die benötigten Tools (zum Beispiel btop, s-tui, htop, atop, iftop, sysdig/csysdig, nvtop, perf, wavemon) über das Paketmanagement. Zusätzlich stellt es sicher, dass die Pfade /usr/sbin und /sbin im PATH vorhanden sind, da manche Tools dort liegen (zum Beispiel iftop). Optional kann ein Symlink erstellt werden, damit das Management-Skript später von überall als Kommando verfügbar ist.

Installation (einmalig):

chmod +x InstallSystemMonitor.sh SystemMonitor.sh
sudo ./InstallSystemMonitor.sh


Installation inkl. Symlink (empfohlen):

sudo ./InstallSystemMonitor.sh --install-symlink


Danach ist das Management-Skript von überall aufrufbar:

systemmonitor


Symlink entfernen:

sudo ./InstallSystemMonitor.sh --remove-symlink

SystemMonitor.sh

Dieses Skript ist das Management- und Startmenü. Es bietet eine einfache Auswahl, um die installierten Tools zu starten und typische Informationen anzuzeigen (zum Beispiel Netzwerkinterfaces, Versionscheck, iftop auf dem Standardinterface, atop-Logging und atop-Historie).

Start (ohne Symlink, aus dem Ordner heraus):

./SystemMonitor.sh


Start (mit Symlink, von überall):

systemmonitor

Hinweise

wavemon funktioniert nur, wenn ein WLAN-Interface vorhanden ist. Auf Servern ohne WLAN ist die Meldung „no supported wireless interfaces found“ normal.

Einige Tools benötigen Root-Rechte für vollständige Informationen (zum Beispiel iftop, atop, csysdig, perf). Das Menü startet diese bei Bedarf mit sudo.
