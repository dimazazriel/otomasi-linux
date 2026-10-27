#!/usr/bin/env bash
# =============================================================================
# lib/arsip.sh — membuat, memverifikasi, dan memberi checksum pada arsip
# =============================================================================

ARSIP_SEMENTARA=""
ARSIP_HASIL=""
JUMLAH_ENTRI=0
CHECKSUM=""

siapkan_tujuan() {
  local tujuan="$1"
  if [[ ! -d "$tujuan" ]]; then
    if ! mkdir -p -- "$tujuan" 2>/dev/null; then
      die "$EXIT_TUJUAN" "Gagal membuat folder tujuan: $tujuan"
    fi
    log_info "Folder tujuan dibuat: $tujuan"
  fi
}

# buat_arsip <sumber_absolut> <tujuan_absolut> <prefix> [pola_exclude]
buat_arsip() {
  local sumber="$1"
  local tujuan="$2"
  local prefix="$3"
  local exclude="${4:-}"
  local waktu nama induk folder

  waktu="$(date '+%Y%m%d_%H%M%S')"
  nama="${prefix}_${waktu}.tar.gz"
  ARSIP_HASIL="$tujuan/$nama"

  if [[ -e "$ARSIP_HASIL" ]]; then
    die "$EXIT_TUJUAN" "Arsip dengan nama yang sama sudah ada, tidak akan ditimpa: $ARSIP_HASIL"
  fi

  induk="$(dirname -- "$sumber")"
  folder="$(basename -- "$sumber")"
  ARSIP_SEMENTARA="$ARSIP_HASIL.tmp"

  local cmd_tar=(tar -czf "$ARSIP_SEMENTARA")
  if [[ -n "$exclude" ]]; then
    IFS=',' read -ra ADDR <<< "$exclude"
    for item in "${ADDR[@]}"; do
      item="$(echo "$item" | xargs)"
      if [[ -n "$item" ]]; then
        cmd_tar+=(--exclude="$item")
      fi
    done
    log_info "Mengecualikan pola: $exclude"
  fi

  cmd_tar+=(-C "$induk" -- "$folder")

  log_info "Membuat arsip dari $sumber ..."
  if ! "${cmd_tar[@]}" 2>>"$LOG_FILE"; then
    die "$EXIT_ARSIP" "tar gagal membuat arsip (detail pesan tar ada di file log)."
  fi
}

verifikasi_arsip() {
  local jumlah
  if ! jumlah="$(tar -tzf "$ARSIP_SEMENTARA" 2>>"$LOG_FILE" | wc -l)"; then
    die "$EXIT_VERIFIKASI" "Arsip tidak bisa dibaca ulang (kemungkinan rusak)."
  fi
  JUMLAH_ENTRI="${jumlah//[[:space:]]/}"
  log_info "Verifikasi OK: arsip bisa dibaca ulang, berisi $JUMLAH_ENTRI entri (file + folder)."
}

finalisasi_arsip() {
  local folder nama

  if ! mv -- "$ARSIP_SEMENTARA" "$ARSIP_HASIL"; then
    die "$EXIT_ARSIP" "Gagal menyimpan arsip dengan nama akhirnya."
  fi
  ARSIP_SEMENTARA=""

  folder="$(dirname -- "$ARSIP_HASIL")"
  nama="$(basename -- "$ARSIP_HASIL")"
  if ! (cd -- "$folder" && sha256sum -- "$nama" > "$nama.sha256"); then
    die "$EXIT_VERIFIKASI" "Gagal membuat file checksum untuk $ARSIP_HASIL"
  fi
  CHECKSUM="$(cut -d' ' -f1 < "$ARSIP_HASIL.sha256")"
}

tampilkan_ringkasan() {
  local ukuran
  ukuran="$(du -h -- "$ARSIP_HASIL" | cut -f1)"
  log_info "Arsip    : $ARSIP_HASIL"
  log_info "Ukuran   : $ukuran"
  log_info "Isi      : $JUMLAH_ENTRI entri"
  log_info "SHA-256  : $CHECKSUM"
  log_info "Checksum : $ARSIP_HASIL.sha256"
}