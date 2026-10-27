#!/usr/bin/env bash
# =============================================================================
# backup.sh — Otomasi backup sebuah folder menjadi arsip .tar.gz
# =============================================================================

set -uo pipefail

readonly EXIT_OK=0
readonly EXIT_UMUM=1
readonly EXIT_PARAMETER=2
readonly EXIT_CONFIG=3
readonly EXIT_SUMBER=4
readonly EXIT_TUJUAN=5
readonly EXIT_ARSIP=6
readonly EXIT_VERIFIKASI=7
readonly EXIT_DEPENDENSI=8
readonly EXIT_DIBATALKAN=130

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

readonly TUJUAN_DEFAULT="$SCRIPT_DIR/backups"
readonly PREFIX_DEFAULT="backup"
readonly LOG_DEFAULT="$SCRIPT_DIR/logs/backup.log"

source "$SCRIPT_DIR/lib/log.sh"      || { echo "ERROR: modul lib/log.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }
source "$SCRIPT_DIR/lib/config.sh"   || { echo "ERROR: modul lib/config.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }
source "$SCRIPT_DIR/lib/validasi.sh" || { echo "ERROR: modul lib/validasi.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }
source "$SCRIPT_DIR/lib/arsip.sh"    || { echo "ERROR: modul lib/arsip.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }

ARG_SUMBER=""
ARG_TUJUAN=""
ARG_PREFIX=""
ARG_EXCLUDE=""
ARG_CONFIG=""
ARG_LOG=""
DRY_RUN=0

tampilkan_bantuan() {
  cat <<'TEKS'
Pemakaian: backup.sh -s <folder_sumber> [opsi]

Opsi:
  -s <folder>  Folder sumber yang akan di-backup
  -d <folder>  Folder tujuan arsip
  -p <prefix>  Awalan nama arsip
  -e <pola>    Pola file/folder yang dikecualikan (mis: "*.tmp,*.log,cache")
  -c <file>    File konfigurasi
  -l <file>    Lokasi file log
  -n           Dry-run
  -h           Tampilkan bantuan ini
TEKS
}

baca_argumen() {
  if [[ $# -eq 0 ]]; then
    tampilkan_bantuan >&2
    exit "$EXIT_PARAMETER"
  fi

  local opsi OPTIND=1
  while getopts ":s:d:p:e:c:l:nh" opsi; do
    case "$opsi" in
      s) ARG_SUMBER="$OPTARG" ;;
      d) ARG_TUJUAN="$OPTARG" ;;
      p) ARG_PREFIX="$OPTARG" ;;
      e) ARG_EXCLUDE="$OPTARG" ;;
      c) ARG_CONFIG="$OPTARG" ;;
      l) ARG_LOG="$OPTARG" ;;
      n) DRY_RUN=1 ;;
      h) tampilkan_bantuan; exit "$EXIT_OK" ;;
      :) die "$EXIT_PARAMETER" "Opsi -$OPTARG membutuhkan nilai." ;;
      \?) die "$EXIT_PARAMETER" "Opsi tidak dikenal: -$OPTARG." ;;
    esac
  done
  shift $((OPTIND - 1))

  if [[ $# -gt 0 ]]; then
    die "$EXIT_PARAMETER" "Argumen tidak dikenal: $*."
  fi
}

saat_keluar() {
  local kode=$?
  if [[ -n "${ARSIP_SEMENTARA:-}" && -e "$ARSIP_SEMENTARA" ]]; then
    rm -f -- "$ARSIP_SEMENTARA"
    log_warn "File arsip setengah jadi dihapus: $ARSIP_SEMENTARA"
  fi
  if [[ -n "$LOG_FILE" ]]; then
    if [[ $kode -eq 0 ]]; then
      log_info "=== Selesai: BERHASIL (exit status 0, durasi ${SECONDS} detik) ==="
    else
      log_error "=== Selesai: GAGAL (exit status $kode) ==="
    fi
  fi
  exit "$kode"
}
trap saat_keluar EXIT
trap 'log_error "Dibatalkan oleh pengguna."; exit "$EXIT_DIBATALKAN"' INT TERM

main() {
  baca_argumen "$@"

  mulai_log "${ARG_LOG:-$LOG_DEFAULT}"
  log_info "=== Mulai backup (pid $$) ==="

  if [[ -n "$ARG_CONFIG" ]]; then
    muat_config "$ARG_CONFIG"
    log_info "Config dimuat: $ARG_CONFIG"
  fi

  local sumber tujuan prefix exclude
  sumber="${ARG_SUMBER:-$CFG_SUMBER}"
  tujuan="${ARG_TUJUAN:-${CFG_TUJUAN:-$TUJUAN_DEFAULT}}"
  prefix="${ARG_PREFIX:-${CFG_PREFIX:-$PREFIX_DEFAULT}}"
  exclude="${ARG_EXCLUDE:-$CFG_EXCLUDE}"

  cek_dependensi tar gzip sha256sum realpath du
  validasi_prefix "$prefix"
  validasi_sumber "$sumber"
  validasi_tujuan "$tujuan" "$SUMBER_ABS"
  log_info "Sumber : $SUMBER_ABS"
  log_info "Tujuan : $TUJUAN_ABS"
  log_info "Prefix : $prefix"
  if [[ -n "$exclude" ]]; then
    log_info "Exclude: $exclude"
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "DRY-RUN: tidak ada file yang dibuat."
    exit "$EXIT_OK"
  fi

  siapkan_tujuan "$TUJUAN_ABS"
  buat_arsip "$SUMBER_ABS" "$TUJUAN_ABS" "$prefix" "$exclude"
  verifikasi_arsip
  finalisasi_arsip
  tampilkan_ringkasan

  exit "$EXIT_OK"
}

main "$@"