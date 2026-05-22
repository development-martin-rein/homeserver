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


# SystemMonitor Werkzeug\FCbersicht

Dieses Dokument beschreibt die Werkzeuge, die \FCber `SystemMonitor.sh` gestartet oder gepr\FCft werden k\F6nnen.

Das Skript stellt ein einfaches Terminal-Men\FC bereit, um Monitoring-, Diagnose- und Analysewerkzeuge auf dem Server zentral aufzurufen.

---

## Ziel des Skripts

`SystemMonitor.sh` dient als zentrale Startoberfl\E4che f\FCr verschiedene Systemanalyse-Werkzeuge.

Es hilft dabei, schnell Informationen zu folgenden Bereichen zu erhalten:

- Prozessorlast
- Arbeitsspeicherverbrauch
- Prozesse
- Netzwerkverkehr
- Festplatten- und Eingabe-/Ausgabe-Last
- Container- und Systemaktivit\E4t
- WLAN-Signalqualit\E4t
- historische Systemlast
- Programmversionen und Verf\FCgbarkeit

Das Skript ersetzt die einzelnen Werkzeuge nicht, sondern b\FCndelt deren Aufruf in einem Men\FC.

---

## Allgemeine Bedienung

Skript starten:

`./SystemMonitor.sh`

Falls das Skript noch nicht ausf\FChrbar ist:

`chmod +x SystemMonitor.sh`

Starten:

`./SystemMonitor.sh`

Das Men\FC bietet nummerierte Eintr\E4ge. Durch Eingabe der Zahl wird das jeweilige Werkzeug gestartet.

---

## Men\FCeintr\E4ge im \DCberblick

```text
1) Schnittstellen anzeigen
2) Versionen / Verf\FCgbarkeit pr\FCfen
3) btop starten
4) htop starten
5) s-tui starten
6) atop starten
7) iftop starten auf Standard-Schnittstelle
8) iftop starten mit Schnittstellenauswahl
9) csysdig starten
10) nvtop starten
11) perf top starten
12) wavemon starten
13) atop-Logging aktivieren
14) atop-Logs ansehen
0) Beenden
```

---

## 1. Schnittstellen anzeigen

Men\FCpunkt:

`1) Schnittstellen anzeigen`

Ausgef\FChrte Befehle:

`ip -br link`

`ip route`

### Zweck

Dieser Men\FCpunkt zeigt die Netzwerkschnittstellen des Systems und die Routingtabelle an.

N\FCtzlich ist das zum Beispiel, wenn gepr\FCft werden soll:

- welche Netzwerkkarten vorhanden sind
- welche Schnittstellen aktiv sind
- welche Schnittstelle f\FCr den Standardgateway genutzt wird
- ob Docker, Kubernetes, Flannel oder andere virtuelle Schnittstellen vorhanden sind
- welche physische Schnittstelle f\FCr Werkzeuge wie `iftop` verwendet werden sollte

### Typische Ausgabe

Beispiele f\FCr Schnittstellen:

- `lo`
- `enp4s0`
- `docker0`
- `cni0`
- `flannel.1`
- `veth...`

F\FCr Monitoring des normalen Heimnetz-Traffics ist meistens die physische Schnittstelle relevant, zum Beispiel:

`enp4s0`

---

## 2. Versionen und Verf\FCgbarkeit pr\FCfen

Men\FCpunkt:

`2) Versionen / Verf\FCgbarkeit pr\FCfen`

### Zweck

Dieser Men\FCpunkt pr\FCft, welche Monitoring-Werkzeuge installiert und verf\FCgbar sind.

Das Skript verwendet daf\FCr intern `command -v`.

Wenn ein Werkzeug fehlt, erscheint eine Warnung:

`[WARN] Befehl nicht gefunden: <werkzeug>`

### Gepr\FCfte Werkzeuge

- `btop`
- `s-tui`
- `htop`
- `atop`
- `iftop`
- `sysdig`
- `csysdig`
- `nvtop`
- `perf`
- `wavemon`
- `pipx`

### Sinn

Dieser Men\FCpunkt eignet sich gut nach einer Neuinstallation oder einem Cluster-Neuaufbau, um zu pr\FCfen, ob alle Diagnosewerkzeuge verf\FCgbar sind.

---

## 3. btop

Men\FCpunkt:

`3) btop starten`

Befehl:

`btop`

### Was ist btop?

`btop` ist ein modernes Terminal-Monitoring-Werkzeug f\FCr Systemressourcen.

Es zeigt unter anderem:

- Prozessorlast
- Arbeitsspeicher
- Swap
- Prozesse
- Festplattenaktivit\E4t
- Netzwerkaktivit\E4t
- Prozessbaum
- Prozesssortierung

### Sinn

`btop` eignet sich sehr gut f\FCr einen schnellen Gesamt\FCberblick \FCber den Server.

Typische Fragen, die man damit beantworten kann:

- Welcher Prozess verbraucht gerade viel Arbeitsspeicher?
- Ist die Prozessorlast dauerhaft hoch?
- Gibt es auff\E4llige Prozesse?
- Wie stark ist der Server aktuell ausgelastet?
- Gibt es Netzwerkverkehr?

### Wann verwenden?

`btop` ist meistens der beste erste Einstieg, wenn man nur allgemein wissen will, was auf dem System los ist.

---

## 4. htop

Men\FCpunkt:

`4) htop starten`

Befehl:

`htop`

### Was ist htop?

`htop` ist ein interaktiver Prozessmonitor.

Er zeigt:

- laufende Prozesse
- Prozessorlast pro Kern
- Arbeitsspeicherverbrauch
- Swap-Nutzung
- Prozessnummern
- Benutzer
- Prozesspriorit\E4ten
- Prozessbefehle

### Sinn

`htop` ist besonders n\FCtzlich, wenn Prozesse gezielt beobachtet oder beendet werden sollen.

### Typische Nutzung

- Prozesse sortieren
- Prozesse suchen
- Prozessbaum anzeigen
- einzelne Prozesse beenden
- Lastverursacher finden

### Unterschied zu btop

`btop` ist moderner und \FCbersichtlicher f\FCr den Gesamtzustand.

`htop` ist klassisch, schlank und sehr gut f\FCr Prozessverwaltung.

---

## 5. s-tui

Men\FCpunkt:

`5) s-tui starten`

Befehl:

`s-tui`

### Was ist s-tui?

`s-tui` steht f\FCr Stress Terminal User Interface.

Es ist ein Terminal-Werkzeug zur Anzeige von Prozessorzustand und thermischem Verhalten.

Es zeigt typischerweise:

- Prozessorfrequenz
- Prozessorauslastung
- Temperatur
- m\F6gliche Drosselung
- L\FCfter- oder Sensordaten, falls verf\FCgbar

### Sinn

`s-tui` ist sinnvoll, wenn gepr\FCft werden soll, ob der Server thermisch stabil l\E4uft.

Typische Fragen:

- Wird der Prozessor zu hei\DF?
- Drosselt der Prozessor unter Last?
- Funktioniert die K\FChlung?
- Ist die Frequenz stabil?

### Wann verwenden?

- nach Hardware\E4nderungen
- bei auff\E4llig langsamer Leistung
- bei Verdacht auf Temperaturprobleme
- bei Dauerlasttests

---

## 6. atop

Men\FCpunkt:

`6) atop starten`

Befehl:

`sudo atop`

### Was ist atop?

`atop` ist ein sehr umfangreiches Systemmonitoring-Werkzeug.

Es zeigt nicht nur Prozesse, sondern auch systemweite Ressourcen.

Dazu geh\F6ren:

- Prozessorlast
- Arbeitsspeicher
- Swap
- Festplattenlast
- Netzwerkaktivit\E4t
- Prozessaktivit\E4t
- Eingabe-/Ausgabe-Verhalten
- historische Systemdaten, wenn Logging aktiviert ist

### Sinn

`atop` ist besonders stark, wenn man nicht nur sehen m\F6chte, was gerade passiert, sondern auch nachvollziehen m\F6chte, was fr\FCher passiert ist.

Beispiel:

- Der Server war nachts langsam.
- Ein Prozess hat kurzzeitig viel Last erzeugt.
- Ein Dienst hat viel Festplattenlast verursacht.
- Der Arbeitsspeicher war zu einem bestimmten Zeitpunkt voll.

Mit aktiviertem Logging kann man solche Zust\E4nde sp\E4ter untersuchen.

### Warum Root?

`atop` ben\F6tigt f\FCr viele Detailinformationen erh\F6hte Rechte.

Deshalb startet das Skript:

`sudo atop`

---

## 7. iftop auf Standard-Schnittstelle

Men\FCpunkt:

`7) iftop starten (Standard-Schnittstelle)`

Befehl im Skript:

`sudo iftop -i <schnittstelle> -n -P`

### Was ist iftop?

`iftop` zeigt aktuellen Netzwerkverkehr pro Verbindung an.

Es beantwortet Fragen wie:

- Welche Hosts kommunizieren gerade mit dem Server?
- Wie viel Datenverkehr l\E4uft gerade?
- Welche Verbindung verursacht Traffic?
- Welche Ports sind beteiligt?

### Optionen

`-i <schnittstelle>`

Legt die Netzwerkschnittstelle fest.

`-n`

Keine Domain Name System Aufl\F6sung. Dadurch bleibt die Anzeige schneller und eindeutiger.

`-P`

Ports anzeigen.

### Standard-Schnittstelle

Das Skript versucht automatisch die erste aktive echte Schnittstelle zu finden.

Ausgeschlossen werden unter anderem:

- `lo`
- `docker0`
- `cni0`
- `flannel.1`
- `veth...`

Falls keine passende Schnittstelle gefunden wird, wird als Fallback verwendet:

`enp4s0`

### Sinn

Dieser Men\FCpunkt ist gut f\FCr eine schnelle Netzwerkanalyse ohne manuelle Schnittstellenauswahl.

---

## 8. iftop mit Schnittstellenauswahl

Men\FCpunkt:

`8) iftop starten (Schnittstelle w\E4hlen)`

### Zweck

Dieser Men\FCpunkt zeigt zuerst die Netzwerkschnittstellen an und fragt dann, welche Schnittstelle verwendet werden soll.

Das ist n\FCtzlich, wenn der automatische Fallback nicht die richtige Schnittstelle w\E4hlt.

### Typische Schnittstellen

Physische Netzwerkkarte:

`enp4s0`

Kubernetes oder Container-Netzwerke:

`cni0`

`flannel.1`

Docker:

`docker0`

### Empfehlung

F\FCr normalen Heimnetz-Traffic meistens die physische Schnittstelle w\E4hlen.

F\FCr Kubernetes-internen Traffic k\F6nnen virtuelle Schnittstellen interessant sein, sollten aber gezielt analysiert werden.

---

## 9. csysdig

Men\FCpunkt:

`9) csysdig starten`

Befehl:

`sudo csysdig`

### Was ist csysdig?

`csysdig` ist eine interaktive Oberfl\E4che f\FCr Sysdig.

Sysdig beobachtet Systemaufrufe und kann sehr detailliert zeigen, was auf dem System passiert.

Es kann unter anderem analysieren:

- Prozesse
- Dateien
- Netzwerkverbindungen
- Container
- Systemaufrufe
- Eingabe-/Ausgabe-Verhalten

### Sinn

`csysdig` ist deutlich tiefergehend als `htop` oder `btop`.

Es ist n\FCtzlich, wenn man wissen will:

- welcher Prozess welche Dateien \F6ffnet
- welche Prozesse Netzwerkverbindungen aufbauen
- was Container im Detail tun
- welche Systemaufrufe h\E4ufig passieren

### Wann verwenden?

- bei tiefer Fehlersuche
- bei Container-Analyse
- bei ungew\F6hnlichem Systemverhalten
- bei Sicherheitsanalyse

---

## 10. nvtop

Men\FCpunkt:

`10) nvtop starten`

Befehl:

`nvtop`

### Was ist nvtop?

`nvtop` ist ein Monitoring-Werkzeug f\FCr Grafikkarten.

Es zeigt je nach Hardware und Treiber:

- Grafikkartenauslastung
- Speicherverbrauch der Grafikkarte
- Prozesse auf der Grafikkarte
- Temperatur
- Leistungsaufnahme, falls unterst\FCtzt

### Sinn

`nvtop` ist sinnvoll, wenn der Server eine unterst\FCtzte Grafikkarte besitzt.

Typische Anwendungsf\E4lle:

- Machine Learning
- Videotranskodierung
- Hardwarebeschleunigung
- grafische Anwendungen
- Compute-Workloads

### Hinweis

Auf einem reinen Server ohne relevante Grafikkarte kann `nvtop` fehlen oder keinen gro\DFen Nutzen haben.

---

## 11. perf top

Men\FCpunkt:

`11) perf top starten`

Befehl:

`sudo perf top`

### Was ist perf?

`perf` ist ein Linux Performance Analysewerkzeug.

`perf top` zeigt live, welche Funktionen und Kernelbereiche gerade Prozessorzeit verbrauchen.

### Sinn

`perf` ist ein Werkzeug f\FCr tiefe Leistungsanalyse.

Es hilft bei Fragen wie:

- Wo wird wirklich Prozessorzeit verbraucht?
- Liegt die Last im Kernel?
- Verursacht ein bestimmter Prozess viele Systemaufrufe?
- Gibt es Engp\E4sse auf Funktions- oder Kernel-Ebene?

### Wann verwenden?

`perf top` ist eher f\FCr fortgeschrittene Analyse gedacht.

F\FCr normale Kontrolle reichen meist `btop`, `htop` oder `atop`.

---

## 12. wavemon

Men\FCpunkt:

`12) wavemon starten`

Befehl:

`sudo wavemon`

### Was ist wavemon?

`wavemon` ist ein Terminal-Werkzeug zur \DCberwachung von WLAN-Verbindungen.

Es zeigt unter anderem:

- Signalst\E4rke
- Verbindungsqualit\E4t
- Rauschwerte
- Bitrate
- WLAN-Schnittstelle
- Access Point Informationen

### Sinn

`wavemon` ist n\FCtzlich, wenn der Server \FCber WLAN angebunden ist.

### Hinweis

F\FCr einen per Kabel angebundenen Server ist `wavemon` meistens nicht relevant.

Das Skript pr\FCft zus\E4tzlich, ob `iw` vorhanden ist, weil WLAN-Informationen dar\FCber abgefragt werden k\F6nnen.

---

## 13. atop Logging aktivieren

Men\FCpunkt:

`13) atop-Logging aktivieren (systemd)`

Befehl im Skript:

`sudo systemctl enable --now atop`

### Was passiert dabei?

Dieser Men\FCpunkt aktiviert den systemd Dienst von `atop`.

Dadurch l\E4uft `atop` im Hintergrund als Logging-Dienst und schreibt regelm\E4\DFig Systemzust\E4nde in Logdateien.

Typischer Speicherort unter Debian oder Ubuntu:

`/var/log/atop`

Typische Logdateien:

`atop_YYYYMMDD`

Beispiel:

`atop_20260514`

### Wof\FCr ist das gut?

Mit aktiviertem Logging kann man sp\E4ter pr\FCfen, was zu einem fr\FCheren Zeitpunkt auf dem System passiert ist.

Das ist hilfreich, wenn ein Problem nicht genau in dem Moment untersucht werden kann, in dem es auftritt.

Beispiele:

- Server war nachts langsam
- Kubernetes Pods wurden unerwartet neugestartet
- Festplatte war kurzzeitig stark ausgelastet
- Arbeitsspeicher war kurzzeitig voll
- Prozessorlast war ungew\F6hnlich hoch

---

## 14. atop Logs ansehen

Men\FCpunkt:

`14) atop-Logs ansehen (Historie)`

Befehl im Skript:

`sudo atop -r /var/log/atop/<datei>`

### Zweck

Dieser Men\FCpunkt zeigt vorhandene `atop` Logdateien an und \F6ffnet eine ausgew\E4hlte Datei.

Damit kann man historische Systemlast untersuchen.

### Ablauf

Das Skript zeigt die letzten Logdateien aus:

`/var/log/atop`

Dann fragt es nach einem Dateinamen, zum Beispiel:

`atop_20260514`

Danach wird die Datei ge\F6ffnet mit:

`sudo atop -r /var/log/atop/atop_20260514`

---

## Frage: Schaltet sich atop Logging automatisch ab?

Nein.

Wenn `atop` \FCber systemd aktiviert wurde, l\E4uft der Logging-Dienst unabh\E4ngig vom Men\FCskript weiter.

Das Beenden von `SystemMonitor.sh` beendet nicht automatisch das `atop` Logging.

Auch das Beenden der Live-Ansicht `sudo atop` beendet nicht automatisch den systemd Logging-Dienst.

### Unterschied zwischen Live-Ansicht und Logging-Dienst

Live-Ansicht:

`sudo atop`

- l\E4uft nur solange das Programm ge\F6ffnet ist
- zeigt aktuelle Systeminformationen
- endet beim Beenden der Anwendung

Logging-Dienst:

`sudo systemctl enable --now atop`

- l\E4uft dauerhaft im Hintergrund
- startet automatisch beim Systemstart
- schreibt regelm\E4\DFig Logdateien
- bleibt aktiv, auch wenn das Men\FCskript beendet wird

---

## Ist atop Logging ein Ringpuffer?

Nicht im einfachen Sinne wie ein klassischer Ringpuffer im Arbeitsspeicher.

`atop` schreibt historische Daten in Dateien unter:

`/var/log/atop`

Diese Dateien werden normalerweise durch die Systemkonfiguration, Logrotation oder die `atop` eigene Aufbewahrung verwaltet.

Das bedeutet:

- Die Daten liegen auf der Festplatte.
- Sie bleiben auch nach einem Neustart erhalten.
- Alte Dateien k\F6nnen automatisch gel\F6scht oder rotiert werden.
- Das Verhalten h\E4ngt von der installierten Distribution und Konfiguration ab.

### Speicherbedarf

`atop` Logs sind normalerweise nicht riesig, k\F6nnen aber bei langer Aufbewahrung Speicherplatz belegen.

Pr\FCfen:

`sudo du -sh /var/log/atop`

Dateien anzeigen:

`ls -lh /var/log/atop`

---

## atop Logging manuell deaktivieren

Das aktuelle Skript kann `atop` Logging aktivieren, aber noch nicht deaktivieren.

Manuell deaktivieren:

`sudo systemctl disable --now atop`

Status pr\FCfen:

`systemctl status atop`

Nur stoppen, aber beim n\E4chsten Systemstart wieder starten lassen:

`sudo systemctl stop atop`

Dauerhaft deaktivieren und sofort stoppen:

`sudo systemctl disable --now atop`

---

## Empfehlung f\FCr dein Skript

Es ist sinnvoll, einen zus\E4tzlichen Men\FCpunkt einzubauen:

```text
15) atop-Logging deaktivieren
```

Dazu kann diese Funktion erg\E4nzt werden:

```bash
disable_atop_logging() {
  if systemctl list-unit-files | grep -qE '^atop\.service'; then
    log "Deaktiviere atop-Dienst (Logging)."
    sudo systemctl disable --now atop
  else
    warn "atop.service nicht gefunden."
  fi
}
```

Im Men\FC erg\E4nzen:

```text
15) atop-Logging deaktivieren (systemd)
```

Im `case` Block erg\E4nzen:

```bash
15) disable_atop_logging ;;
```

---

## Wann sollte atop Logging aktiviert bleiben?

Aktiviert lassen, wenn:

- der Server dauerhaft beobachtet werden soll
- nach Neustarts oder Abst\FCrzen Ursachen gesucht werden sollen
- sporadische Lastprobleme auftreten
- Kubernetes oder Longhorn Probleme sp\E4ter nachvollzogen werden sollen
- genug Speicherplatz vorhanden ist

Deaktivieren, wenn:

- keine historische Analyse ben\F6tigt wird
- m\F6glichst wenige Hintergrunddienste laufen sollen
- Speicherplatz knapp ist
- das System nur tempor\E4r getestet wird

F\FCr einen Homeserver mit Kubernetes, Longhorn, Nextcloud und GitLab ist aktiviertes `atop` Logging grunds\E4tzlich sinnvoll.

---

## Sinnvolle Reihenfolge bei Problemen

Bei unbekanntem Problem zuerst:

1. `btop`
2. `htop`
3. `atop`
4. `iftop`
5. `kubectl get pods -A`
6. `kubectl top pods -A`
7. `kubectl describe pod ...`
8. `journalctl`
9. `csysdig` oder `perf top` f\FCr tiefe Analyse

---

## Kurze Werkzeugauswahl nach Fragestellung

### Allgemeine Systemlast

- `btop`
- `htop`
- `atop`

### Historische Analyse

- `atop` Logging
- `atop -r`

### Netzwerkverkehr

- `iftop`

### WLAN

- `wavemon`

### Grafikkarte

- `nvtop`

### Tiefe Prozess- und Systemanalyse

- `csysdig`
- `perf top`

### Prozessor und Temperatur

- `s-tui`

---

## Zusammenfassung

Das Skript `SystemMonitor.sh` ist eine praktische zentrale Oberfl\E4che f\FCr Serverdiagnose.

F\FCr den normalen Betrieb sind besonders wichtig:

- `btop` f\FCr den schnellen \DCberblick
- `htop` f\FCr Prozesse
- `atop` f\FCr detaillierte und historische Systemanalyse
- `iftop` f\FCr Netzwerkverkehr
- `s-tui` f\FCr Temperatur und Prozessorverhalten

`atop` Logging muss bewusst aktiviert und bei Bedarf auch bewusst wieder deaktiviert werden.

Das Beenden der Anwendung oder des Men\FCs deaktiviert den `atop` systemd Dienst nicht automatisch.

