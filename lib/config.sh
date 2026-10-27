#!/usr/bin/env bash
# =============================================================================
# lib/config.sh — membaca file konfigurasi berformat KUNCI=nilai secara AMAN
# =============================================================================

CFG_SUMBER=""
CFG_TUJUAN=""
CFG_PREFIX=""
CFG_EXCLUDE=""

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
    baris="${baris%$'\r'}"

    if [[ "$baris" =~ $pola_komentar ]]; then
      continue
    fi

    if [[ ! "$baris" =~ $pola_isi ]]; then
      die "$EXIT_CONFIG" "Format config salah di baris $nomor (harus KUNCI=nilai): $file"
    fi
    kunci="${BASH_REMATCH[1]}"
    nilai="${BASH_REMATCH[2]:-}"

    if [[ "$nilai" =~ ^\"(.*)\"$ || "$nilai" =~ ^\'(.*)\'$ ]]; then
      nilai="${BASH_REMATCH[1]}"
    fi
    nilai="${nilai/#\~/$HOME}"

    case "$kunci" in
      SUMBER) CFG_SUMBER="$nilai" ;;
      TUJUAN) CFG_TUJUAN="$nilai" ;;
      PREFIX) CFG_PREFIX="$nilai" ;;
      EXCLUDE) CFG_EXCLUDE="$nilai" ;;
      *) log_warn "Config baris $nomor: kunci '$kunci' tidak dikenal, diabaikan." ;;
    esac
  done < "$file"
}