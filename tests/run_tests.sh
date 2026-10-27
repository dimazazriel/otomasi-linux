#!/usr/bin/env bash
# =============================================================================
# tests/run_tests.sh — menjalankan test case backup.sh dan menyimpan
#                      HASIL AKTUAL ke folder bukti/
#
# Pemakaian (dari folder utama proyek):
#   bash tests/run_tests.sh
#
# Yang dihasilkan:
#   bukti/hasil_pengujian.txt  → perintah, exit status diharapkan vs aktual, output
#   bukti/log_pengujian.log    → isi log yang ditulis backup.sh selama pengujian
#
# Semua test berjalan di folder sementara (sandbox dari mktemp) yang dihapus
# otomatis setelah selesai, jadi data asli kalian tidak tersentuh.
# =============================================================================
# shellcheck disable=SC2329  # fungsi pemeriksaan dipanggil tidak langsung lewat `cek`
set -uo pipefail

TEST_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname -- "$TEST_DIR")"
SCRIPT="$ROOT_DIR/backup.sh"
BUKTI_DIR="$ROOT_DIR/bukti"
HASIL="$BUKTI_DIR/hasil_pengujian.txt"
LOG_UJI="$BUKTI_DIR/log_pengujian.log"

# Versi kode yang diuji (dicatat sebelum file bukti ditulis ulang)
VERSI="$(git -C "$ROOT_DIR" describe --always --dirty 2>/dev/null || echo "belum ada commit git")"

mkdir -p -- "$BUKTI_DIR"
: > "$HASIL"     # kosongkan hasil lama
: > "$LOG_UJI"

SANDBOX="$(mktemp -d)"
trap 'rm -rf -- "$SANDBOX"' EXIT   # sandbox selalu dihapus saat test selesai

# ---- Data contoh di dalam sandbox ------------------------------------------
mkdir -p "$SANDBOX/data/sub"
echo "catatan rapat contoh"     > "$SANDBOX/data/catatan.txt"
echo "id,nama_barang,jumlah"    > "$SANDBOX/data/sub/inventaris.csv"
echo "1,kabel HDMI,3"          >> "$SANDBOX/data/sub/inventaris.csv"

# Config untuk TC-01, formatnya sama dengan config/backup.conf.example
cat > "$SANDBOX/uji.conf" <<EOF
# config khusus pengujian (dibuat otomatis oleh run_tests.sh)
SUMBER=$SANDBOX/data
TUJUAN=$SANDBOX/hasil
PREFIX=uji
EOF

# ---- Fungsi bantu -----------------------------------------------------------
TOTAL=0
JUMLAH_SESUAI=0
TC_ID=""
TC_OK=1
RINGKASAN=()

# rapikan <teks> — ganti path panjang dengan label pendek supaya mudah dibaca
# (sekaligus tidak menampilkan nama folder home/pengguna)
rapikan() {
  local teks="$1"
  teks="${teks//$SANDBOX/<sandbox>}"
  teks="${teks//$ROOT_DIR/.}"
  echo "$teks"
}

catat() { rapikan "$*" | tee -a "$HASIL"; }

# mulai_test <id> <kondisi> <deskripsi>
mulai_test() {
  TC_ID="$1"
  TC_KONDISI="$2"
  TC_DESK="$3"
  TC_OK=1
  TOTAL=$((TOTAL + 1))
  catat ""
  catat "============================================================"
  catat "$TC_ID [$TC_KONDISI] $TC_DESK"
  catat "============================================================"
  echo "##### $TC_ID [$TC_KONDISI] $TC_DESK #####" >> "$LOG_UJI"
}

# jalankan <exit_diharapkan> <argumen untuk backup.sh...>
jalankan() {
  local harapan="$1"
  shift
  local output kode
  output="$("$SCRIPT" "$@" -l "$LOG_UJI" 2>&1)"
  kode=$?
  TC_HARAPAN="$harapan"
  TC_AKTUAL="$kode"
  catat "Perintah   : ./backup.sh $* -l bukti/log_pengujian.log"
  catat "Diharapkan : exit status $harapan"
  catat "Aktual     : exit status $kode"
  catat "Output     :"
  rapikan "$output" | sed 's/^/    /' | tee -a "$HASIL"
  if [[ "$kode" -ne "$harapan" ]]; then
    TC_OK=0
  fi
  catat "Pemeriksaan tambahan:"
}

# cek <keterangan> <perintah...> — perintah berhasil = [v], gagal = [x]
cek() {
  local keterangan="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    catat "  [v] $keterangan"
  else
    catat "  [x] $keterangan"
    TC_OK=0
  fi
}

akhiri_test() {
  local status="TIDAK SESUAI"
  if [[ $TC_OK -eq 1 ]]; then
    status="SESUAI"
    JUMLAH_SESUAI=$((JUMLAH_SESUAI + 1))
  fi
  catat "HASIL $TC_ID: $status"
  RINGKASAN+=("| $TC_ID | $TC_KONDISI | $TC_DESK | $TC_HARAPAN | $TC_AKTUAL | $status |")
}

# Pemeriksaan-pemeriksaan kecil yang dipakai `cek`
# (dipanggil tidak langsung lewat `cek`)
ada_arsip()      { compgen -G "$1/$2_*.tar.gz" >/dev/null; }
tidak_ada()      { [[ ! -e "$1" ]]; }
tidak_ada_pola() { ! compgen -G "$1" >/dev/null; }
checksum_cocok() { local f; f="$(compgen -G "$1/*.sha256" | head -n 1)"; [[ -n "$f" ]] && (cd "$1" && sha256sum -c -- "$(basename "$f")"); }
arsip_berisi()   { local a; a="$(compgen -G "$1/*.tar.gz" | head -n 1)"; [[ -n "$a" ]] && tar -tzf "$a" | grep -x -- "$2" >/dev/null; }
log_berisi()     { grep -F -- "$1" "$LOG_UJI" >/dev/null; }

# ---- Header -----------------------------------------------------------------
catat "HASIL PENGUJIAN backup.sh"
catat "Waktu uji  : $(date '+%Y-%m-%d %H:%M:%S %Z')"
catat "Sistem     : $(uname -sr)"
catat "Bash       : $BASH_VERSION"
catat "Versi kode : $VERSI"
catat "Catatan    : <sandbox> = folder sementara (mktemp), dihapus otomatis setelah pengujian."

# ---- TC-01: kondisi BERHASIL ------------------------------------------------
mulai_test "TC-01" "BERHASIL" "Backup folder memakai file config"
jalankan 0 -c "$SANDBOX/uji.conf"
cek "file arsip uji_*.tar.gz terbentuk di folder tujuan"   ada_arsip "$SANDBOX/hasil" uji
cek "checksum SHA-256 cocok (sha256sum -c)"               checksum_cocok "$SANDBOX/hasil"
cek "arsip berisi data/catatan.txt"                       arsip_berisi "$SANDBOX/hasil" "data/catatan.txt"
cek "arsip berisi data/sub/inventaris.csv"                arsip_berisi "$SANDBOX/hasil" "data/sub/inventaris.csv"
cek "tidak ada file .tmp tersisa"                         tidak_ada_pola "$SANDBOX/hasil/*.tmp"
cek "log mencatat 'Selesai: BERHASIL'"                    log_berisi "Selesai: BERHASIL"
akhiri_test

# ---- TC-02: kondisi GAGAL — folder sumber tidak ada ------------------------
mulai_test "TC-02" "GAGAL" "Folder sumber tidak ada"
jalankan 4 -s "$SANDBOX/folder_tidak_ada" -d "$SANDBOX/hasil_tc02"
cek "folder tujuan tidak dibuat (gagal sebelum ada perubahan)" tidak_ada "$SANDBOX/hasil_tc02"
cek "log mencatat ERROR 'Folder sumber tidak ditemukan'"   log_berisi "Folder sumber tidak ditemukan"
akhiri_test

# ---- TC-03: kondisi GAGAL — prefix tidak aman (path traversal) -------------
mulai_test "TC-03" "GAGAL" "Prefix berisi ../ (mencoba menulis ke luar folder tujuan)"
jalankan 2 -s "$SANDBOX/data" -d "$SANDBOX/a/b" -p "../../jahat"
cek "tidak ada file jahat_* yang terbentuk di luar tujuan" tidak_ada_pola "$SANDBOX/jahat_*"
cek "folder tujuan tidak dibuat"                          tidak_ada "$SANDBOX/a"
cek "log mencatat ERROR 'Prefix ... tidak valid'"         log_berisi "tidak valid. Hanya boleh huruf"
akhiri_test

# ---- TC-04: kondisi GAGAL — tujuan berada di dalam sumber ------------------
mulai_test "TC-04" "GAGAL" "Folder tujuan berada di dalam folder sumber"
jalankan 5 -s "$SANDBOX/data" -d "$SANDBOX/data/backup"
cek "folder data/backup tidak dibuat" tidak_ada "$SANDBOX/data/backup"
cek "log mencatat ERROR 'berada di dalam folder sumber'" log_berisi "berada di dalam folder sumber"
akhiri_test

# ---- TC-05: kondisi GAGAL — file config tidak ditemukan --------------------
mulai_test "TC-05" "GAGAL" "File config tidak ditemukan"
jalankan 3 -c "$SANDBOX/tidak_ada.conf"
cek "log mencatat ERROR 'File config tidak ditemukan'" log_berisi "File config tidak ditemukan"
akhiri_test

# ---- Ringkasan ---------------------------------------------------------------
catat ""
catat "============================================================"
catat "RINGKASAN: $JUMLAH_SESUAI dari $TOTAL test case SESUAI harapan"
catat "============================================================"
catat "| ID | Kondisi | Skenario | Exit diharapkan | Exit aktual | Status |"
catat "|----|---------|----------|-----------------|-------------|--------|"
for baris in "${RINGKASAN[@]}"; do
  catat "$baris"
done
catat ""
catat "File hasil : bukti/hasil_pengujian.txt"
catat "File log   : bukti/log_pengujian.log"

# Rapikan juga path di file log (sembunyikan path sandbox & folder home)
sed -i -e "s#$SANDBOX#<sandbox>#g" -e "s#$ROOT_DIR#.#g" "$LOG_UJI"

if [[ $JUMLAH_SESUAI -eq $TOTAL ]]; then
  exit 0
fi
exit 1
