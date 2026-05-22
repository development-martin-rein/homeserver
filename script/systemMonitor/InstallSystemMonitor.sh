#!/usr/bin/env bash
set -euo pipefail

# InstallSystemMonitor.sh
# Installation von System-Monitoring-Werkzeugen auf Debian/Ubuntu
# Optional: Symlink-Installer nach /usr/local/bin/systemmonitor

log() { printf '%s\n' "[INFO] $*"; }
warn() { printf '%s\n' "[WARN] $*" >&2; }
err() { printf '%s\n' "[ERROR] $*" >&2; }

need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    err "Bitte mit sudo ausführen: sudo $0"
    exit 1
  fi
}

usage() {
  cat <<'EOF'
Verwendung:
  sudo ./InstallSystemMonitor.sh [OPTIONEN]

Optionen:
  --install-symlink        Erstellt/aktualisiert /usr/local/bin/systemmonitor -> SystemMonitor.sh
  --remove-symlink         Entfernt /usr/local/bin/systemmonitor
  --skip-atop-service      Aktiviert den atop-Dienst nicht
  --help                   Hilfe anzeigen

Hinweis:
  Das Skript geht davon aus, dass SystemMonitor.sh im gleichen Ordner liegt wie InstallSystemMonitor.sh.
EOF
}

detect_os() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    echo "${ID:-unknown}:${VERSION_ID:-unknown}"
  else
    echo "unknown:unknown"
  fi
}

ensure_path_for_sbin() {
  local line='export PATH="$PATH:/usr/sbin:/sbin"'
  local bashrc="${HOME}/.bashrc"
  local profile="${HOME}/.profile"

  if [[ -f "${bashrc}" ]]; then
    grep -qxF "${line}" "${bashrc}" || echo "${line}" >> "${bashrc}"
  else
    echo "${line}" >> "${bashrc}"
  fi

  if [[ -f "${profile}" ]]; then
    grep -qxF "${line}" "${profile}" || echo "${line}" >> "${profile}"
  else
    echo "${line}" >> "${profile}"
  fi

  log "PATH erweitert um /usr/sbin und /sbin (wirksam nach neuem Terminal oder erneutem Login)."
}

apt_update() {
  log "Paketlisten aktualisieren."
  apt-get update -y
}

install_packages() {
  log "Installiere System-Monitoring-Tools."
  apt-get install -y \
    btop \
    s-tui \
    htop \
    atop \
    iftop \
    sysdig \
    nvtop \
    wavemon \
    pipx

  local os_id
  os_id="$(detect_os)"

  case "${os_id}" in
    debian:*)
      log "Debian erkannt: installiere perf über linux-perf."
      apt-get install -y linux-perf || true
      ;;
    ubuntu:*)
      log "Ubuntu erkannt: versuche perf über linux-tools-*."
      apt-get install -y linux-tools-common linux-tools-generic "linux-tools-$(uname -r)" || true
      apt-get install -y linux-perf || true
      ;;
    *)
      warn "Unbekanntes System: versuche linux-perf."
      apt-get install -y linux-perf || true
      ;;
  esac
}

enable_atop_logging() {
  if systemctl list-unit-files | grep -qE '^atop\.service'; then
    log "Aktiviere atop-Dienst (Historie)."
    systemctl enable --now atop
  else
    warn "atop.service nicht gefunden. Live-Ansicht geht trotzdem über: sudo atop"
  fi
}

remove_asitop_if_present() {
  # asitop ist für Apple Silicon/macOS. Falls es aus Versehen installiert wurde: entfernen.
  if command -v pipx >/dev/null 2>&1; then
    if pipx list 2>/dev/null | grep -q 'package asitop'; then
      log "asitop gefunden (pipx). Entferne es, weil es auf diesem Linux-Server nicht sinnvoll ist."
      sudo -u "${SUDO_USER:-$USER}" pipx uninstall asitop || true
      sudo -u "${SUDO_USER:-$USER}" pipx prune || true
    fi
  fi
}

post_checks() {
  export PATH="$PATH:/usr/sbin:/sbin:${HOME}/.local/bin"

  log "Kurzcheck:"
  command -v btop >/dev/null && btop --version || true
  command -v s-tui >/dev/null && s-tui --version || true
  command -v htop >/dev/null && htop --version || true
  command -v atop >/dev/null && atop -V || true
  command -v iftop >/dev/null && iftop -h | head -n 1 || true
  command -v sysdig >/dev/null && sysdig --version || true
  command -v csysdig >/dev/null && csysdig --version || true
  command -v nvtop >/dev/null && nvtop --version || true
  command -v perf >/dev/null && perf --version || true
  command -v wavemon >/dev/null && wavemon -h | head -n 1 || true

  log "Hinweis: wavemon benötigt eine WLAN-Schnittstelle. Ohne WLAN ist die Meldung normal."
}

install_symlink() {
  local script_dir target link_path
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  target="${script_dir}/SystemMonitor.sh"
  link_path="/usr/local/bin/systemmonitor"

  if [[ ! -f "${target}" ]]; then
    err "SystemMonitor.sh nicht gefunden unter: ${target}"
    err "Lege InstallSystemMonitor.sh und SystemMonitor.sh in denselben Ordner."
    exit 1
  fi

  chmod +x "${target}" || true
  ln -sf "${target}" "${link_path}"
  log "Symlink gesetzt: ${link_path} -> ${target}"
  log "Ab jetzt kannst du von überall starten mit: systemmonitor"
}

remove_symlink() {
  local link_path="/usr/local/bin/systemmonitor"
  if [[ -L "${link_path}" || -f "${link_path}" ]]; then
    rm -f "${link_path}"
    log "Symlink entfernt: ${link_path}"
  else
    warn "Kein Symlink gefunden unter: ${link_path}"
  fi
}

main() {
  local DO_INSTALL_SYMLINK=0
  local DO_REMOVE_SYMLINK=0
  local SKIP_ATOP_SERVICE=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-symlink) DO_INSTALL_SYMLINK=1; shift ;;
      --remove-symlink)  DO_REMOVE_SYMLINK=1; shift ;;
      --skip-atop-service) SKIP_ATOP_SERVICE=1; shift ;;
      --help|-h) usage; exit 0 ;;
      *) err "Unbekannte Option: $1"; usage; exit 1 ;;
    esac
  done

  need_root

  if [[ "${DO_REMOVE_SYMLINK}" -eq 1 ]]; then
    remove_symlink
    exit 0
  fi

  ensure_path_for_sbin
  apt_update
  install_packages

  if [[ "${SKIP_ATOP_SERVICE}" -eq 0 ]]; then
    enable_atop_logging
  else
    log "atop-Dienst wurde übersprungen (--skip-atop-service)."
  fi

  remove_asitop_if_present
  post_checks

  if [[ "${DO_INSTALL_SYMLINK}" -eq 1 ]]; then
    install_symlink
  else
    log "Symlink wurde nicht gesetzt. Optional mit: sudo ./InstallSystemMonitor.sh --install-symlink"
  fi

  log "Fertig."
}

main "$@"
