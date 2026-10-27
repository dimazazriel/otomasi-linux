# Folder bukti/

Isi folder ini **dibuat otomatis** oleh `bash tests/run_tests.sh`, bukan ditulis tangan:

- `hasil_pengujian.txt` — setiap test case: perintah, exit status diharapkan vs aktual, output, pemeriksaan tambahan, dan tabel ringkasan.
- `log_pengujian.log` — log yang ditulis `backup.sh` selama pengujian (berisi kondisi berhasil dan gagal).

Jalankan ulang test setiap kali kode berubah, lalu commit hasil terbaru. Path folder sementara dan folder proyek otomatis disamarkan (`<sandbox>`, `.`) supaya tidak menampilkan nama pengguna.
