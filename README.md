# Otomasi Backup Folder — Proyek 2: Otomasi dan Container Linux

Checkpoint P11 · Tag: `P2-CHECKPOINT-P11-v01`

Modul shell script untuk membackup sebuah folder menjadi arsip `.tar.gz` yang **diverifikasi**, diberi **checksum SHA-256**, dan **dicatat ke log**. Repository ini akan dilanjutkan pada P12–P15.

---

## 1. Use case dan tujuan otomasi

**Masalah.** Backup manual (copy-paste folder atau membuat zip sendiri) sering lupa dilakukan, nama filenya tidak konsisten, tidak ada bukti kapan dilakukan, dan tidak ada cara memastikan file backup tidak rusak.

**Solusi.** `backup.sh` mengotomasi pekerjaan administrasi tersebut:

1. memeriksa semua input sebelum melakukan apa pun;
2. membuat arsip `.tar.gz` dengan nama seragam: `<prefix>_<tanggal>_<jam>.tar.gz`;
3. membaca ulang arsip untuk memastikan tidak rusak;
4. membuat file checksum `.sha256` agar keutuhan arsip bisa dicek kapan saja;
5. mencatat setiap langkah, keberhasilan, dan kegagalan ke file log.

**Contoh pemakaian nyata.** Membackup folder dokumen organisasi/proyek kelompok secara rutin sebelum ada perubahan besar.

---

## 2. Struktur repository

```
.
├── backup.sh                  # script utama (entry point): alur langkah demi langkah
├── lib/
│   ├── log.sh                 # pencatatan log + fungsi die (berhenti dengan exit status)
│   ├── config.sh              # membaca file config KUNCI=nilai secara aman
│   ├── validasi.sh            # validasi dependensi, prefix, folder sumber & tujuan
│   └── arsip.sh               # membuat, memverifikasi, dan memberi checksum arsip
├── config/
│   └── backup.conf.example    # contoh konfigurasi (tanpa credential)
├── tests/
│   └── run_tests.sh           # 1 test case berhasil + 4 test case gagal
├── bukti/                     # hasil aktual pengujian (dibuat otomatis oleh run_tests.sh)
├── README.md
└── KONTRIBUSI.md              # catatan kontribusi anggota
```

---

## 3. Kebutuhan

- Linux (diuji di Ubuntu / WSL Ubuntu) dengan Bash 4 atau lebih baru
- `tar`, `gzip`, `sha256sum`, `realpath`, `du` — sudah tersedia di Ubuntu (paket `coreutils`, `tar`, `gzip`)
- Tidak butuh akses root/sudo, tidak butuh password atau credential apa pun

---

## 4. Cara menjalankan

```bash
# sekali saja: beri izin eksekusi
chmod +x backup.sh tests/run_tests.sh

# lihat bantuan
./backup.sh -h

# siapkan folder contoh untuk dicoba
mkdir -p ~/contoh_data && echo "halo" > ~/contoh_data/tes.txt

# coba dulu tanpa membuat file apa pun (dry-run)
./backup.sh -s ~/contoh_data -d ~/arsip_backup -n

# jalankan backup sungguhan
./backup.sh -s ~/contoh_data -d ~/arsip_backup -p data_kelompok
```

### Opsi

| Opsi | Arti | Default |
|------|------|---------|
| `-s <folder>` | folder sumber yang di-backup (wajib, kecuali diisi di config) | — |
| `-d <folder>` | folder tujuan arsip; dibuat otomatis kalau belum ada | `backups/` di dalam proyek |
| `-p <prefix>` | awalan nama arsip, hanya huruf/angka/`_`/`-`, maks. 50 karakter | `backup` |
| `-c <file>` | file konfigurasi | — |
| `-l <file>` | lokasi file log | `logs/backup.log` di dalam proyek |
| `-n` | dry-run: validasi & tampilkan rencana, tidak membuat arsip | mati |
| `-h` | tampilkan bantuan | — |

Prioritas nilai: **argumen > config > default**.

### Memakai file config

```bash
cp config/backup.conf.example config/backup.conf
nano config/backup.conf
./backup.sh -c config/backup.conf
```

Config dibaca baris per baris, **tidak** dijalankan dengan `source`, sehingga isi config tidak bisa menyisipkan perintah. Hanya kunci `SUMBER`, `TUJUAN`, `PREFIX` yang diterima.

---

## 5. Exit status

| Kode | Nama di script | Arti |
|------|----------------|------|
| 0 | `EXIT_OK` | berhasil |
| 1 | `EXIT_UMUM` | error umum (mis. file log tidak bisa ditulis, modul hilang) |
| 2 | `EXIT_PARAMETER` | parameter salah, kurang, atau tidak aman |
| 3 | `EXIT_CONFIG` | file config tidak ada / tidak bisa dibaca / formatnya salah |
| 4 | `EXIT_SUMBER` | folder sumber tidak ada / bukan folder / tidak bisa dibaca / root (`/`) |
| 5 | `EXIT_TUJUAN` | folder tujuan bermasalah (di dalam sumber, bukan folder, tidak bisa ditulisi, arsip sudah ada) |
| 6 | `EXIT_ARSIP` | `tar` gagal membuat arsip |
| 7 | `EXIT_VERIFIKASI` | arsip tidak bisa dibaca ulang / checksum gagal dibuat |
| 8 | `EXIT_DEPENDENSI` | program pendukung tidak ditemukan |
| 130 | `EXIT_DIBATALKAN` | dihentikan pengguna (Ctrl+C) atau sinyal TERM |

Cek exit status terakhir dengan `echo $?` tepat setelah menjalankan script.

---

## 6. Logging

- Lokasi default: `logs/backup.log` (bisa diganti dengan `-l`).
- Format: `YYYY-MM-DD HH:MM:SS [LEVEL] [pid N] pesan`, level `INFO`, `WARN`, `ERROR`.
- Setiap run dicatat dari `=== Mulai backup ===` sampai `=== Selesai: BERHASIL/GAGAL (exit status N) ===`.
- Pesan error dari `tar` ikut masuk ke file log.

---

## 7. Error handling

- **Validasi di awal**: semua input dicek sebelum ada file yang dibuat; kegagalan validasi tidak meninggalkan perubahan apa pun.
- **`die <kode> <pesan>`**: setiap kegagalan dicatat sebagai `ERROR` lalu script berhenti dengan exit status yang sesuai.
- **File sementara**: arsip ditulis dulu sebagai `*.tar.gz.tmp`, baru diganti nama setelah lolos verifikasi.
- **`trap ... EXIT`**: saat script berhenti karena alasan apa pun, file `.tmp` setengah jadi dihapus dan exit status akhir dicatat.
- **`trap ... INT TERM`**: Ctrl+C dicatat dan script keluar dengan kode 130.
- **Tidak menimpa**: arsip dengan nama yang sama tidak akan ditimpa.

---

## 8. Pengujian

```bash
bash tests/run_tests.sh
```

Pengujian berjalan di folder sementara (`mktemp -d`) yang dihapus otomatis, jadi tidak menyentuh data asli. Hasil aktual tersimpan di:

- `bukti/hasil_pengujian.txt` — perintah, exit status diharapkan vs aktual, output, pemeriksaan tambahan, tabel ringkasan
- `bukti/log_pengujian.log` — log kondisi berhasil dan gagal

| ID | Kondisi | Skenario | Exit diharapkan | Pemeriksaan tambahan |
|----|---------|----------|-----------------|----------------------|
| TC-01 | Berhasil | backup folder memakai file config | 0 | arsip terbentuk, checksum cocok, isi arsip lengkap, tidak ada `.tmp`, log mencatat BERHASIL |
| TC-02 | Gagal | folder sumber tidak ada | 4 | folder tujuan tidak dibuat, ERROR tercatat |
| TC-03 | Gagal | prefix `../../jahat` (path traversal) | 2 | tidak ada file di luar tujuan, ERROR tercatat |
| TC-04 | Gagal | folder tujuan di dalam folder sumber | 5 | folder tujuan tidak dibuat, ERROR tercatat |
| TC-05 | Gagal | file config tidak ditemukan | 3 | ERROR tercatat |

### Hasil aktual

> **TODO kelompok:** salin tabel `RINGKASAN` dari bagian akhir `bukti/hasil_pengujian.txt` ke sini, lengkap dengan sistem yang dipakai (baris "Sistem" di file tersebut). Jangan isi dengan hasil yang tidak benar-benar dijalankan.

### Interpretasi singkat

> **TODO kelompok:** tulis ulang berdasarkan hasil aktual kalian. Contoh kerangka (hapus bagian yang tidak sesuai):
>
> TC-01 menunjukkan script dapat membuat arsip yang utuh: arsip bisa dibaca ulang, checksum SHA-256 cocok, dan isinya sesuai folder sumber. TC-02 sampai TC-05 menunjukkan input yang salah ditolak **sebelum** ada file yang dibuat, setiap jenis kegagalan menghasilkan exit status yang berbeda sehingga penyebabnya dapat dikenali, dan setiap kegagalan tercatat di log dengan level ERROR. TC-03 secara khusus menunjukkan validasi prefix mencegah penulisan file ke luar folder tujuan.

---

## 9. Verifikasi hasil backup

```bash
cd ~/arsip_backup
ls -lh                                       # lihat arsip & file .sha256
sha256sum -c data_kelompok_<tanggal_jam>.tar.gz.sha256   # harus tampil: OK
tar -tzf data_kelompok_<tanggal_jam>.tar.gz              # lihat daftar isi arsip
tail -n 20 ~/<folder-proyek>/logs/backup.log             # lihat catatan log
```

---

## 10. Membersihkan

```bash
rm -rf backups/ logs/          # hasil & log dari pemakaian dengan lokasi default
rm -rf ~/arsip_backup          # folder tujuan yang dipakai saat mencoba (sesuaikan)
rm -rf ~/contoh_data           # folder contoh (kalau tadi dibuat)
```

Pengujian (`tests/run_tests.sh`) membersihkan folder sementaranya sendiri. Hati-hati dengan `rm -rf`: periksa path dua kali sebelum menekan Enter.

---

## 11. Rollback

`backup.sh` **tidak pernah mengubah atau menghapus data sumber**. Setiap run hanya **menambah** tiga hal: satu file arsip, satu file `.sha256`, dan beberapa baris log. Jadi:

**Membatalkan hasil sebuah run** — hapus pasangan file dari run tersebut (nama lengkapnya tercatat di log, baris `Arsip :`):

```bash
rm ~/arsip_backup/data_kelompok_20261027_130501.tar.gz \
   ~/arsip_backup/data_kelompok_20261027_130501.tar.gz.sha256
```

**Mengembalikan data dari arsip (restore)** — ekstrak ke folder baru dulu, periksa, baru salin ke tempat asli, supaya data yang ada tidak tertimpa:

```bash
sha256sum -c ~/arsip_backup/<nama>.tar.gz.sha256     # pastikan arsip utuh
mkdir -p ~/restore_uji
tar -xzf ~/arsip_backup/<nama>.tar.gz -C ~/restore_uji
ls -R ~/restore_uji
```

**Rollback kode** — kembali ke versi checkpoint ini dengan `git checkout P2-CHECKPOINT-P11-v01`.

---

## 12. Keamanan

- Tidak ada password, token, private key, atau credential di repository; script juga tidak membutuhkannya.
- Config dibaca sebagai data (bukan `source`), hanya kunci yang dikenal yang diterima.
- Prefix divalidasi dengan pola `^[A-Za-z0-9_-]{1,50}$` untuk mencegah path traversal.
- Folder root (`/`) ditolak sebagai sumber; tujuan di dalam sumber ditolak.
- Arsip menyimpan path relatif (`data/...`), bukan path absolut.
- Tidak butuh sudo; berjalan dengan hak akses pengguna biasa.
- `.gitignore` mencegah `backups/`, `logs/`, dan `config/backup.conf` ikut ter-commit.

---

## 13. Batasan saat ini & rencana P12–P15

Batasan:
- Kesalahan penulisan opsi (mis. opsi tidak dikenal) hanya tampil di terminal, belum masuk log, karena lokasi log baru diketahui setelah opsi dibaca.
- Belum ada penjadwalan otomatis dan penghapusan arsip lama (retensi).
- Belum ada opsi mengecualikan file tertentu (exclude).
- Komentar di config hanya boleh di baris tersendiri, tidak di belakang nilai.

Rencana pengembangan:
- P12–P13: penjadwalan dengan `cron`/`systemd timer`, retensi arsip lama, opsi exclude.
- P14–P15: menjalankan script di dalam container (Dockerfile + volume untuk folder sumber/tujuan).

---

## 14. Kontribusi

Lihat [KONTRIBUSI.md](KONTRIBUSI.md).
