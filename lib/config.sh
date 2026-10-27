#!/usr/bin/env bash
# =============================================================================
# lib/config.sh — membaca file konfigurasi berformat KUNCI=nilai secara AMAN
#
# Kenapa tidak memakai `source backup.conf`?
#   `source` akan MENJALANKAN isi file sebagai perintah. Kalau ada orang menulis
#   `rm -rf ~` di file config, perintah itu ikut jalan. Di sini file hanya
#   DIBACA baris per baris, dan hanya kunci yang dikenal yang diterima:
#   SUMBER, TUJUAN, PREFIX. Kunci lain diabaikan dengan peringatan.
#
# Aturan format:
#   - satu pengaturan per baris: KUNCI=nilai
#   - baris kosong dan baris yang diawali # dianggap komentar
#   - nilai boleh diapit tanda kutip "..." atau '...'
#   - ~ di awal nilai diganti dengan folder home
# =============================================================================

CFG_SUMBER=""
CFG_TUJUAN=""
CFG_PREFIX=""

# muat_config <path_file_config>
muat_config() {
  local file="$1"
  local baris kunci nilai nomor=0
  local pola_komentar='^[[:space:]]*(#.*)?$'
  local pola_isi='^[[:space:]]*([A-Z_]+)[[:space:]]*=[[:space:]]*(.*[^[:space:]])?[[:space:]]*$'

  if [[ ! -f "$file" ]]; then
    die "$EXIT_CONFIG" "File config tidak ditemukan: $file"
  fi
  if [[ ! -r "$file" ]]; then
    die "$EXIT_CONFIG" "File config tidak bisa dibaca (cek izin akses): $file"
  fi

  while IFS= read -r baris || [[ -n "$baris" ]]; do
    nomor=$((nomor + 1))
    baris="${baris%$'\r'}"   # buang karakter CR kalau file sempat diedit di Windows

    # Lewati baris kosong dan komentar
    if [[ "$baris" =~ $pola_komentar ]]; then
      continue
    fi

    # Baris harus berbentuk KUNCI=nilai
    if [[ ! "$baris" =~ $pola_isi ]]; then
      die "$EXIT_CONFIG" "Format config salah di baris $nomor (harus KUNCI=nilai): $file"
    fi
    kunci="${BASH_REMATCH[1]}"
    nilai="${BASH_REMATCH[2]:-}"

    # Buang tanda kutip pembungkus, lalu ganti ~ di awal dengan $HOME
    if [[ "$nilai" =~ ^\"(.*)\"$ || "$nilai" =~ ^\'(.*)\'$ ]]; then
      nilai="${BASH_REMATCH[1]}"
    fi
    nilai="${nilai/#\~/$HOME}"

    case "$kunci" in
      SUMBER) CFG_SUMBER="$nilai" ;;
      TUJUAN) CFG_TUJUAN="$nilai" ;;
      PREFIX) CFG_PREFIX="$nilai" ;;
      *) log_warn "Config baris $nomor: kunci '$kunci' tidak dikenal, diabaikan." ;;
    esac
  done < "$file"
}
