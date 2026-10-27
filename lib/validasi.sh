#!/usr/bin/env bash
# =============================================================================
# lib/validasi.sh — pemeriksaan input SEBELUM ada file yang dibuat
#
# Prinsip: lebih baik menolak di awal dengan pesan jelas daripada gagal
# di tengah jalan dan meninggalkan file setengah jadi.
# =============================================================================

SUMBER_ABS=""   # path absolut folder sumber (diisi validasi_sumber)
TUJUAN_ABS=""   # path absolut folder tujuan (diisi validasi_tujuan)

# cek_dependensi <program...>
# Pastikan semua program yang dibutuhkan tersedia di sistem.
cek_dependensi() {
  local program
  for program in "$@"; do
    if ! command -v "$program" >/dev/null 2>&1; then
      die "$EXIT_DEPENDENSI" "Program pendukung '$program' tidak ditemukan di sistem."
    fi
  done
}

# validasi_prefix <prefix>
# Prefix menjadi bagian nama file arsip. Hanya huruf, angka, _ dan - yang
# diizinkan, supaya tidak bisa dipakai untuk menulis ke folder lain
# (mis. prefix "../../x" = path traversal) atau menyisipkan karakter aneh.
validasi_prefix() {
  local prefix="$1"
  local pola='^[A-Za-z0-9_-]{1,50}$'

  if [[ -z "$prefix" ]]; then
    die "$EXIT_PARAMETER" "Prefix nama arsip tidak boleh kosong."
  fi
  if [[ ! "$prefix" =~ $pola ]]; then
    die "$EXIT_PARAMETER" "Prefix '$prefix' tidak valid. Hanya boleh huruf, angka, _ dan - (maks. 50 karakter)."
  fi
}

# validasi_sumber <folder_sumber>
validasi_sumber() {
  local sumber="$1"

  if [[ -z "$sumber" ]]; then
    die "$EXIT_PARAMETER" "Folder sumber belum diisi. Gunakan -s <folder> atau SUMBER= di config."
  fi
  if [[ ! -e "$sumber" ]]; then
    die "$EXIT_SUMBER" "Folder sumber tidak ditemukan: $sumber"
  fi
  if [[ ! -d "$sumber" ]]; then
    die "$EXIT_SUMBER" "Sumber bukan sebuah folder: $sumber"
  fi
  if [[ ! -r "$sumber" || ! -x "$sumber" ]]; then
    die "$EXIT_SUMBER" "Folder sumber tidak bisa dibaca (cek izin akses): $sumber"
  fi

  SUMBER_ABS="$(realpath -- "$sumber")"
  if [[ "$SUMBER_ABS" == "/" ]]; then
    die "$EXIT_SUMBER" "Demi keamanan, folder root (/) tidak boleh di-backup dengan script ini."
  fi
}

# validasi_tujuan <folder_tujuan> <sumber_absolut>
validasi_tujuan() {
  local tujuan="$1"
  local sumber_abs="$2"

  if [[ -z "$tujuan" ]]; then
    die "$EXIT_PARAMETER" "Folder tujuan tidak boleh kosong."
  fi

  # realpath -m: ubah ke path absolut walaupun foldernya belum ada
  TUJUAN_ABS="$(realpath -m -- "$tujuan")"

  # Tujuan di dalam sumber = arsip ikut mengarsipkan dirinya sendiri
  if [[ "$TUJUAN_ABS/" == "$sumber_abs/"* ]]; then
    die "$EXIT_TUJUAN" "Folder tujuan ($TUJUAN_ABS) berada di dalam folder sumber ($sumber_abs). Pilih tujuan di luar sumber."
  fi
  if [[ -e "$TUJUAN_ABS" && ! -d "$TUJUAN_ABS" ]]; then
    die "$EXIT_TUJUAN" "Tujuan sudah ada tetapi bukan folder: $TUJUAN_ABS"
  fi
  if [[ -d "$TUJUAN_ABS" && ! -w "$TUJUAN_ABS" ]]; then
    die "$EXIT_TUJUAN" "Folder tujuan tidak bisa ditulisi (cek izin akses): $TUJUAN_ABS"
  fi
}
