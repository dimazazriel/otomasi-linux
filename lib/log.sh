#!/usr/bin/env bash
# =============================================================================
# lib/log.sh — pencatatan aktivitas (logging) dan penghentian script (die)
#
# File ini TIDAK dijalankan langsung. Ia dimuat oleh backup.sh dengan `source`,
# sehingga fungsi-fungsi di bawah bisa dipakai oleh script utama dan modul lain.
#
# Format satu baris log:
#   2026-10-27 13:05:01 [INFO] [pid 4321] pesan
# =============================================================================

LOG_FILE=""   # kosong = log belum aktif (pesan hanya tampil di terminal)

# mulai_log <path_file_log>
# Menyiapkan folder & file log. Kalau gagal, script berhenti (exit 1).
mulai_log() {
  local file="$1"
  local folder
  folder="$(dirname -- "$file")"

  if ! mkdir -p -- "$folder" 2>/dev/null || ! touch -- "$file" 2>/dev/null; then
    echo "ERROR: file log tidak bisa dibuat/ditulisi: $file" >&2
    exit "$EXIT_UMUM"
  fi
  LOG_FILE="$file"
}

# _tulis_log <LEVEL> <pesan...>  (fungsi internal, dipakai oleh log_info dkk.)
# - Selalu tampil di terminal: INFO ke stdout, WARN/ERROR ke stderr
# - Ditambahkan (>>) ke file log kalau log sudah aktif
_tulis_log() {
  local level="$1"
  shift
  local baris
  baris="$(date '+%Y-%m-%d %H:%M:%S') [$level] [pid $$] $*"

  if [[ "$level" == "INFO" ]]; then
    echo "$baris"
  else
    echo "$baris" >&2
  fi

  if [[ -n "$LOG_FILE" ]]; then
    echo "$baris" >> "$LOG_FILE"
  fi
}

log_info()  { _tulis_log "INFO"  "$@"; }
log_warn()  { _tulis_log "WARN"  "$@"; }
log_error() { _tulis_log "ERROR" "$@"; }

# die <exit_status> <pesan...>
# Catat pesan sebagai ERROR, lalu hentikan script dengan exit status tertentu.
# Contoh: die "$EXIT_SUMBER" "Folder sumber tidak ditemukan"
die() {
  local kode="$1"
  shift
  log_error "$*"
  exit "$kode"
}
