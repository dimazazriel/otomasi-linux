#!/usr/bin/env bash
# =============================================================================
# lib/arsip.sh — membuat, memverifikasi, dan memberi checksum pada arsip
#
# Alur aman yang dipakai:
#   1. tar menulis ke file SEMENTARA  (nama_arsip.tar.gz.tmp)
#   2. file sementara dibaca ulang untuk memastikan tidak rusak
#   3. baru setelah lolos, file diganti nama menjadi nama akhir (.tar.gz)
#   4. dibuat file checksum SHA-256 di sebelahnya
# Kalau gagal di langkah 1–2, file sementara dihapus otomatis (trap di backup.sh),
# jadi tidak pernah ada arsip rusak yang terlihat "seolah-olah berhasil".
# =============================================================================

ARSIP_SEMENTARA=""   # path file .tmp yang sedang ditulis
ARSIP_HASIL=""       # path arsip akhir (.tar.gz)
JUMLAH_ENTRI=0       # jumlah file + folder di dalam arsip
CHECKSUM=""          # nilai SHA-256 arsip

# siapkan_tujuan <folder_tujuan_absolut>
siapkan_tujuan() {
  local tujuan="$1"
  if [[ ! -d "$tujuan" ]]; then
    if ! mkdir -p -- "$tujuan" 2>/dev/null; then
      die "$EXIT_TUJUAN" "Gagal membuat folder tujuan: $tujuan"
    fi
    log_info "Folder tujuan dibuat: $tujuan"
  fi
}

# buat_arsip <sumber_absolut> <tujuan_absolut> <prefix>
buat_arsip() {
  local sumber="$1"
  local tujuan="$2"
  local prefix="$3"
  local waktu nama induk folder

  waktu="$(date '+%Y%m%d_%H%M%S')"
  nama="${prefix}_${waktu}.tar.gz"
  ARSIP_HASIL="$tujuan/$nama"

  # Jangan pernah menimpa arsip yang sudah ada
  if [[ -e "$ARSIP_HASIL" ]]; then
    die "$EXIT_TUJUAN" "Arsip dengan nama yang sama sudah ada, tidak akan ditimpa: $ARSIP_HASIL"
  fi

  # -C <induk> <folder>: arsip menyimpan path relatif (mis. data/file.txt),
  # bukan path absolut, sehingga aman & mudah dikembalikan (restore).
  induk="$(dirname -- "$sumber")"
  folder="$(basename -- "$sumber")"
  ARSIP_SEMENTARA="$ARSIP_HASIL.tmp"

  log_info "Membuat arsip dari $sumber ..."
  if ! tar -czf "$ARSIP_SEMENTARA" -C "$induk" -- "$folder" 2>>"$LOG_FILE"; then
    die "$EXIT_ARSIP" "tar gagal membuat arsip (detail pesan tar ada di file log)."
  fi
}

# verifikasi_arsip — baca ulang isi arsip sementara; gagal = arsip rusak
verifikasi_arsip() {
  local jumlah
  # pipefail (di backup.sh) membuat kegagalan tar terdeteksi walaupun wc berhasil
  if ! jumlah="$(tar -tzf "$ARSIP_SEMENTARA" 2>>"$LOG_FILE" | wc -l)"; then
    die "$EXIT_VERIFIKASI" "Arsip tidak bisa dibaca ulang (kemungkinan rusak)."
  fi
  JUMLAH_ENTRI="${jumlah//[[:space:]]/}"
  log_info "Verifikasi OK: arsip bisa dibaca ulang, berisi $JUMLAH_ENTRI entri (file + folder)."
}

# finalisasi_arsip — beri nama akhir lalu buat file checksum .sha256
finalisasi_arsip() {
  local folder nama

  if ! mv -- "$ARSIP_SEMENTARA" "$ARSIP_HASIL"; then
    die "$EXIT_ARSIP" "Gagal menyimpan arsip dengan nama akhirnya."
  fi
  ARSIP_SEMENTARA=""   # sudah aman, tidak perlu dihapus oleh trap

  folder="$(dirname -- "$ARSIP_HASIL")"
  nama="$(basename -- "$ARSIP_HASIL")"
  # cd ke folder arsip supaya isi file .sha256 memakai nama relatif;
  # dengan begitu `sha256sum -c` bisa dijalankan dari folder tersebut
  if ! (cd -- "$folder" && sha256sum -- "$nama" > "$nama.sha256"); then
    die "$EXIT_VERIFIKASI" "Gagal membuat file checksum untuk $ARSIP_HASIL"
  fi
  CHECKSUM="$(cut -d' ' -f1 < "$ARSIP_HASIL.sha256")"
}

# tampilkan_ringkasan — informasi hasil untuk pengguna & log
tampilkan_ringkasan() {
  local ukuran
  ukuran="$(du -h -- "$ARSIP_HASIL" | cut -f1)"
  log_info "Arsip    : $ARSIP_HASIL"
  log_info "Ukuran   : $ukuran"
  log_info "Isi      : $JUMLAH_ENTRI entri"
  log_info "SHA-256  : $CHECKSUM"
  log_info "Checksum : $ARSIP_HASIL.sha256"
}
