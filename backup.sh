#!/usr/bin/env bash
# =============================================================================
# backup.sh — Otomasi backup sebuah folder menjadi arsip .tar.gz
#             + verifikasi arsip + checksum SHA-256 + pencatatan log
#
# Proyek 2: Otomasi dan Container Linux — Checkpoint P11
#
# Pemakaian singkat:
#   ./backup.sh -s <folder_sumber> [-d <folder_tujuan>] [-p <prefix>]
#               [-c <file_config>] [-l <file_log>] [-n] [-h]
#
# Penjelasan lengkap ada di README.md
# =============================================================================

# -u        : berhenti dengan error kalau memakai variabel yang belum diisi
#             (mencegah salah ketik nama variabel diam-diam jadi string kosong)
# pipefail  : kalau salah satu perintah di dalam pipa (a | b) gagal,
#             seluruh pipa dianggap gagal
# Sengaja TIDAK memakai -e: setiap kegagalan kami periksa sendiri,
# supaya exit status yang keluar selalu bermakna (lihat daftar di bawah).
set -uo pipefail

# -----------------------------------------------------------------------------
# Daftar exit status (kode keluar). 0 = berhasil, selain 0 = gagal.
# Setiap jenis kegagalan punya nomor sendiri supaya penyebabnya bisa dikenali.
# -----------------------------------------------------------------------------
readonly EXIT_OK=0            # berhasil
readonly EXIT_UMUM=1          # error umum / tidak terduga (mis. log tidak bisa ditulis)
readonly EXIT_PARAMETER=2     # parameter salah, kurang, atau tidak aman
readonly EXIT_CONFIG=3        # file config tidak ada / tidak bisa dibaca / formatnya salah
readonly EXIT_SUMBER=4        # folder sumber tidak ada / bukan folder / tidak bisa dibaca
readonly EXIT_TUJUAN=5        # folder tujuan bermasalah (di dalam sumber, tidak bisa ditulisi, dll.)
readonly EXIT_ARSIP=6         # tar gagal membuat arsip
readonly EXIT_VERIFIKASI=7    # arsip tidak bisa dibaca ulang / checksum gagal dibuat
readonly EXIT_DEPENDENSI=8    # program pendukung (tar, sha256sum, ...) tidak ada
readonly EXIT_DIBATALKAN=130  # dihentikan pengguna (Ctrl+C) atau sinyal TERM

# Folder tempat script ini berada → script bisa dijalankan dari folder mana pun
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Nilai bawaan (default) kalau tidak diisi lewat argumen maupun config
readonly TUJUAN_DEFAULT="$SCRIPT_DIR/backups"
readonly PREFIX_DEFAULT="backup"
readonly LOG_DEFAULT="$SCRIPT_DIR/logs/backup.log"

# -----------------------------------------------------------------------------
# Muat modul dari folder lib/ (setiap file punya satu tanggung jawab)
# -----------------------------------------------------------------------------
# `source` = baca & jalankan isi file lain di proses yang sama, sehingga fungsi
# dan variabel di dalamnya bisa dipakai di sini. Kalau modul hilang → exit 1.
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"      || { echo "ERROR: modul lib/log.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }
# shellcheck source=lib/config.sh
source "$SCRIPT_DIR/lib/config.sh"   || { echo "ERROR: modul lib/config.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }
# shellcheck source=lib/validasi.sh
source "$SCRIPT_DIR/lib/validasi.sh" || { echo "ERROR: modul lib/validasi.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }
# shellcheck source=lib/arsip.sh
source "$SCRIPT_DIR/lib/arsip.sh"    || { echo "ERROR: modul lib/arsip.sh tidak bisa dimuat." >&2; exit "$EXIT_UMUM"; }

# Nilai dari argumen baris perintah (diisi oleh baca_argumen)
ARG_SUMBER=""
ARG_TUJUAN=""
ARG_PREFIX=""
ARG_CONFIG=""
ARG_LOG=""
DRY_RUN=0

# -----------------------------------------------------------------------------
tampilkan_bantuan() {
  cat <<'TEKS'
Pemakaian: backup.sh -s <folder_sumber> [opsi]

Membuat arsip .tar.gz dari sebuah folder, memverifikasi arsip tersebut,
membuat file checksum SHA-256, dan mencatat aktivitas ke file log.

Opsi:
  -s <folder>  Folder sumber yang akan di-backup (wajib, kecuali diisi di config)
  -d <folder>  Folder tujuan arsip (default: folder backups/ di dalam proyek)
  -p <prefix>  Awalan nama arsip: huruf, angka, _ dan - saja (default: backup)
  -c <file>    File konfigurasi (contoh: config/backup.conf.example)
  -l <file>    Lokasi file log (default: logs/backup.log di dalam proyek)
  -n           Dry-run: hanya menampilkan rencana, tidak membuat file apa pun
  -h           Tampilkan bantuan ini

Prioritas nilai: argumen > config > default.

Exit status:
  0 berhasil              5 folder tujuan bermasalah
  1 error umum            6 gagal membuat arsip
  2 parameter salah       7 verifikasi arsip gagal
  3 config bermasalah     8 program pendukung tidak ada
  4 folder sumber salah   130 dibatalkan (Ctrl+C)
TEKS
}

# -----------------------------------------------------------------------------
# baca_argumen "$@" — membaca opsi -s -d -p -c -l -n -h memakai getopts
# -----------------------------------------------------------------------------
baca_argumen() {
  if [[ $# -eq 0 ]]; then
    tampilkan_bantuan >&2
    exit "$EXIT_PARAMETER"
  fi

  local opsi OPTIND=1
  while getopts ":s:d:p:c:l:nh" opsi; do
    case "$opsi" in
      s) ARG_SUMBER="$OPTARG" ;;
      d) ARG_TUJUAN="$OPTARG" ;;
      p) ARG_PREFIX="$OPTARG" ;;
      c) ARG_CONFIG="$OPTARG" ;;
      l) ARG_LOG="$OPTARG" ;;
      n) DRY_RUN=1 ;;
      h) tampilkan_bantuan; exit "$EXIT_OK" ;;
      :) die "$EXIT_PARAMETER" "Opsi -$OPTARG membutuhkan nilai. Lihat: ./backup.sh -h" ;;
      \?) die "$EXIT_PARAMETER" "Opsi tidak dikenal: -$OPTARG. Lihat: ./backup.sh -h" ;;
    esac
  done
  shift $((OPTIND - 1))

  if [[ $# -gt 0 ]]; then
    die "$EXIT_PARAMETER" "Argumen tidak dikenal: $*. Lihat: ./backup.sh -h"
  fi
}

# -----------------------------------------------------------------------------
# saat_keluar — dipanggil OTOMATIS setiap kali script berhenti (trap EXIT),
# baik berhasil maupun gagal. Tugasnya: bersihkan file setengah jadi dan
# mencatat exit status akhir ke log.
# -----------------------------------------------------------------------------
# shellcheck disable=SC2329  # dipanggil tidak langsung lewat trap
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
trap 'log_error "Dibatalkan oleh pengguna atau sinyal sistem."; exit "$EXIT_DIBATALKAN"' INT TERM

# -----------------------------------------------------------------------------
# main — alur utama, dibaca dari atas ke bawah seperti daftar langkah
# -----------------------------------------------------------------------------
main() {
  # 1. Baca argumen
  baca_argumen "$@"

  # 2. Mulai mencatat log (sejak titik ini semua kejadian tercatat)
  mulai_log "${ARG_LOG:-$LOG_DEFAULT}"
  log_info "=== Mulai backup (pid $$) ==="

  # 3. Baca config kalau diberikan
  if [[ -n "$ARG_CONFIG" ]]; then
    muat_config "$ARG_CONFIG"
    log_info "Config dimuat: $ARG_CONFIG"
  fi

  # 4. Gabungkan nilai: argumen > config > default
  local sumber tujuan prefix
  sumber="${ARG_SUMBER:-$CFG_SUMBER}"
  tujuan="${ARG_TUJUAN:-${CFG_TUJUAN:-$TUJUAN_DEFAULT}}"
  prefix="${ARG_PREFIX:-${CFG_PREFIX:-$PREFIX_DEFAULT}}"

  # 5. Validasi — semua dicek SEBELUM ada file yang dibuat
  cek_dependensi tar gzip sha256sum realpath du
  validasi_prefix "$prefix"
  validasi_sumber "$sumber"              # mengisi SUMBER_ABS
  validasi_tujuan "$tujuan" "$SUMBER_ABS" # mengisi TUJUAN_ABS
  log_info "Sumber : $SUMBER_ABS"
  log_info "Tujuan : $TUJUAN_ABS"
  log_info "Prefix : $prefix"

  # 6. Dry-run: tampilkan rencana lalu berhenti
  if [[ $DRY_RUN -eq 1 ]]; then
    log_info "DRY-RUN: arsip akan dibuat sebagai $TUJUAN_ABS/${prefix}_<tanggal_jam>.tar.gz"
    log_info "DRY-RUN: tidak ada file yang dibuat."
    exit "$EXIT_OK"
  fi

  # 7. Kerjakan backup
  siapkan_tujuan "$TUJUAN_ABS"
  buat_arsip "$SUMBER_ABS" "$TUJUAN_ABS" "$prefix"
  verifikasi_arsip
  finalisasi_arsip
  tampilkan_ringkasan

  exit "$EXIT_OK"
}

main "$@"
