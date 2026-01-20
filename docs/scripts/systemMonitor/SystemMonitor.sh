#!/usr/bin/env bash
set -euo pipefail

# SystemMonitor.sh
# Einfaches Management-Menü für System-Monitoring-Werkzeuge

export PATH="$PATH:/usr/sbin:/sbin:${HOME}/.local/bin"

log() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }

require_cmd() {
  local c="$1"
  if ! command -v "${c}" >/dev/null 2>&1; then
    warn "Befehl nicht gefunden: ${c}"
    return 1
  fi
  return 0
}

pick_default_iface() {
  # Nimm die erste "echte" UP-Schnittstelle, sonst fallback auf enp4s0.
  local iface
  iface="$(ip -br link | awk '$2 ~ /UP/ {print $1}' | grep -Ev '^(lo|docker0|cni0|flannel\.1|veth)' | head -n 1 || true)"
  if [[ -n "${iface}" ]]; then
    echo "${iface}"
  else
    echo "enp4s0"
  fi
}

show_interfaces() {
  echo
  log "Schnittstellen (kurz):"
  ip -br link
  echo
  log "Routing (kurz):"
  ip route || true
  echo
}

versions() {
  echo
  log "Versionen / Verfügbarkeit:"
  require_cmd btop   && btop --version || true
  require_cmd s-tui  && s-tui --version || true
  require_cmd htop   && htop --version || true
  require_cmd atop   && atop -V || true
  require_cmd iftop  && iftop -h | head -n 1 || true
  require_cmd sysdig && sysdig --version || true
  require_cmd csysdig && csysdig --version || true
  require_cmd nvtop  && nvtop --version || true
  require_cmd perf   && perf --version || true
  require_cmd wavemon && wavemon -h | head -n 1 || true
  echo
  log "pipx-Pakete (falls vorhanden):"
  if command -v pipx >/dev/null 2>&1; then
    pipx list | sed -n '1,120p' || true
  else
    warn "pipx nicht gefunden."
  fi
  echo
}

run_btop()   { require_cmd btop && btop; }
run_htop()   { require_cmd htop && htop; }
run_stui()   { require_cmd s-tui && s-tui; }
run_atop()   { require_cmd atop && sudo atop; }
run_csysdig(){ require_cmd csysdig && sudo csysdig; }
run_nvtop()  { require_cmd nvtop && nvtop; }
run_perf_top(){ require_cmd perf && sudo perf top; }

run_wavemon() {
  require_cmd wavemon || return 0
  if ! command -v iw >/dev/null 2>&1; then
    warn "iw ist nicht installiert. Ohne WLAN ist wavemon nicht sinnvoll."
  fi
  sudo wavemon || true
}

run_iftop_default() {
  require_cmd iftop || return 0
  local iface
  iface="$(pick_default_iface)"
  log "Starte iftop auf Schnittstelle: ${iface}"
  log "Optionen: keine DNS-Auflösung (-n), Ports anzeigen (-P)"
  sudo iftop -i "${iface}" -n -P
}

run_iftop_choose() {
  require_cmd iftop || return 0
  show_interfaces
  read -r -p "Welche Schnittstelle? (Beispiel: enp4s0) > " iface
  iface="${iface:-$(pick_default_iface)}"
  sudo iftop -i "${iface}" -n -P
}

atop_logs() {
  # Debian: /var/log/atop/atop_YYYYMMDD
  local dir="/var/log/atop"
  if [[ ! -d "${dir}" ]]; then
    warn "Verzeichnis nicht gefunden: ${dir} (atop-Logging eventuell nicht aktiviert)."
    return 0
  fi

  echo
  log "Verfügbare atop-Logdateien:"
  ls -1 "${dir}" | tail -n 20 || true
  echo
  read -r -p "Logdatei-Name eingeben (z. B. atop_20260120) > " f
  if [[ -z "${f}" ]]; then
    warn "Keine Datei angegeben."
    return 0
  fi
  if [[ ! -f "${dir}/${f}" ]]; then
    warn "Datei nicht gefunden: ${dir}/${f}"
    return 0
  fi
  sudo atop -r "${dir}/${f}"
}

enable_atop_logging() {
  if systemctl list-unit-files | grep -qE '^atop\.service'; then
    log "Aktiviere atop-Dienst (Logging)."
    sudo systemctl enable --now atop
  else
    warn "atop.service nicht gefunden. Live-Ansicht bleibt möglich über: sudo atop"
  fi
}

menu() {
  cat <<'EOF'

SystemMonitor - Menü
  1) Schnittstellen anzeigen (ip link / Routing)
  2) Versionen / Verfügbarkeit prüfen
  3) btop starten
  4) htop starten
  5) s-tui starten
  6) atop starten (Root)
  7) iftop starten (Standard-Schnittstelle)
  8) iftop starten (Schnittstelle wählen)
  9) csysdig starten (Root)
 10) nvtop starten
 11) perf top starten (Root)
 12) wavemon starten (Root, benötigt WLAN)
 13) atop-Logging aktivieren (systemd)
 14) atop-Logs ansehen (Historie)

  0) Beenden

EOF
}

main() {
  while true; do
    menu
    read -r -p "Auswahl > " choice
    case "${choice}" in
      1) show_interfaces ;;
      2) versions ;;
      3) run_btop ;;
      4) run_htop ;;
      5) run_stui ;;
      6) run_atop ;;
      7) run_iftop_default ;;
      8) run_iftop_choose ;;
      9) run_csysdig ;;
      10) run_nvtop ;;
      11) run_perf_top ;;
      12) run_wavemon ;;
      13) enable_atop_logging ;;
      14) atop_logs ;;
      0) exit 0 ;;
      *) warn "Ungültige Auswahl." ;;
    esac
  done
}

main "$@"
