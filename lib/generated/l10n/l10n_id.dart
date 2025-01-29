import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get aboutThanks => 'Terima kasih kepada orang -orang berikut yang berpartisipasi.';

  @override
  String get acceptBeta => 'Terima pembaruan versi uji coba';

  @override
  String get addSystemPrivateKeyTip => 'Saat ini tidak memiliki kunci privat, apakah Anda menambahkan kunci yang disertakan dengan sistem (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Ditambahkan ke Daftar Tugas';

  @override
  String get addr => 'Alamat';

  @override
  String get alreadyLastDir => 'Sudah di direktori terakhir.';

  @override
  String get authFailTip => 'Otentikasi gagal, silakan periksa apakah kata sandi/kunci/host/pengguna, dll, salah.';

  @override
  String get autoBackupConflict => 'Hanya satu pencadangan otomatis yang dapat diaktifkan pada saat yang bersamaan.';

  @override
  String get autoConnect => 'Hubungkan otomatis';

  @override
  String get autoRun => 'Berjalan Otomatis';

  @override
  String get autoUpdateHomeWidget => 'Widget Rumah Pembaruan Otomatis';

  @override
  String get backupTip => 'Data yang diekspor hanya dienkripsi.\nTolong jaga keamanannya.';

  @override
  String get backupVersionNotMatch => 'Versi cadangan tidak cocok.';

  @override
  String get battery => 'Baterai';

  @override
  String get bgRun => 'Jalankan di Backgroud';

  @override
  String get bgRunTip => 'Sakelar ini hanya berarti aplikasi akan mencoba berjalan di latar belakang, apakah aplikasi dapat berjalan di latar belakang tergantung pada apakah izin diaktifkan atau tidak. Untuk Android asli, nonaktifkan \"Pengoptimalan Baterai\" di aplikasi ini, dan untuk miui, ubah kebijakan penghematan daya ke \"Tidak Terbatas\".';

  @override
  String get closeAfterSave => 'Simpan dan tutup';

  @override
  String get cmd => 'Memerintah';

  @override
  String get collapseUITip => 'Apakah akan menciutkan daftar panjang yang ada di UI secara default atau tidak';

  @override
  String get conn => 'Koneksi';

  @override
  String get container => 'Wadah';

  @override
  String get containerTrySudoTip => 'Contohnya: Di dalam aplikasi, pengguna diatur sebagai aaa, tetapi Docker diinstal di bawah pengguna root. Dalam kasus ini, Anda perlu mengaktifkan opsi ini.';

  @override
  String get convert => 'Mengubah';

  @override
  String get copyPath => 'Path Copy';

  @override
  String get cpuViewAsProgressTip => 'Tampilkan tingkat penggunaan setiap CPU dalam gaya bilah kemajuan (gaya lama)';

  @override
  String get cursorType => 'Jenis kursor';

  @override
  String get customCmd => 'Perintah kustom';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Nama Perintah\": \"Perintah\"';

  @override
  String get decode => 'Membaca sandi';

  @override
  String get decompress => 'Dekompresi';

  @override
  String get deleteServers => 'Penghapusan server secara batch';

  @override
  String get dirEmpty => 'Pastikan dir kosong.';

  @override
  String get disconnected => 'Terputus';

  @override
  String get disk => 'Disk';

  @override
  String get diskIgnorePath => 'Abaikan jalan untuk disk';

  @override
  String get displayCpuIndex => 'Tampilkan indeks CPU';

  @override
  String dl2Local(Object fileName) {
    return 'Unduh $fileName ke lokal?';
  }

  @override
  String get dockerEmptyRunningItems => 'Tidak ada wadah yang sedang berjalan.\nHal ini dapat terjadi karena:\n- Pengguna instalasi Docker tidak sama dengan nama pengguna yang dikonfigurasi di dalam Aplikasi.\n- Variabel lingkungan DOCKER_HOST tidak terbaca dengan benar. Anda bisa mendapatkannya dengan menjalankan `echo \$DOCKER_HOST` di terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count gambar';
  }

  @override
  String get dockerNotInstalled => 'Docker tidak terpasang';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount running, $stoppedCount container stopped.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count wadah berjalan.';
  }

  @override
  String get doubleColumnMode => 'Mode kolom ganda';

  @override
  String get doubleColumnTip => 'Opsi ini hanya mengaktifkan fitur, apakah itu benar-benar dapat diaktifkan tergantung pada lebar perangkat';

  @override
  String get editVirtKeys => 'Edit kunci virtual';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'Performa penyorotan kode saat ini lebih buruk, dan dapat dimatikan secara opsional untuk perbaikan.';

  @override
  String get encode => 'Menyandi';

  @override
  String get envVars => 'Variabel lingkungan';

  @override
  String get experimentalFeature => 'Fitur eksperimental';

  @override
  String get extraArgs => 'Args ekstra';

  @override
  String get fallbackSshDest => 'Tujuan SSH mundur';

  @override
  String get fdroidReleaseTip => 'Jika Anda mengunduh aplikasi ini dari F-Droid, disarankan untuk mematikan opsi ini.';

  @override
  String get fgService => 'Layanan Latar Depan';

  @override
  String get fgServiceTip => 'Setelah diaktifkan, beberapa model perangkat mungkin crash. Menonaktifkannya dapat menyebabkan beberapa model tidak dapat mempertahankan koneksi SSH di latar belakang. Harap izinkan perizinan notifikasi ServerBox, menjalankan di latar belakang, dan bangun mandiri di pengaturan sistem.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'File \'$file\' terlalu besar $size, max $sizeMax';
  }

  @override
  String get followSystem => 'Ikuti sistem';

  @override
  String get font => 'Font';

  @override
  String get fontSize => 'Ukuran huruf';

  @override
  String get force => 'sukarela';

  @override
  String get fullScreen => 'Mode Layar Penuh';

  @override
  String get fullScreenJitter => 'Jitter layar penuh';

  @override
  String get fullScreenJitterHelp => 'Untuk menghindari pembakaran layar';

  @override
  String get fullScreenTip => 'Apakah mode layar penuh diaktifkan ketika perangkat diputar ke modus lanskap? Opsi ini hanya berlaku untuk tab server.';

  @override
  String get goBackQ => 'Datang kembali?';

  @override
  String get goto => 'Pergi ke';

  @override
  String get hideTitleBar => 'Sembunyikan bilah judul';

  @override
  String get highlight => 'Sorotan kode';

  @override
  String get homeWidgetUrlConfig => 'Konfigurasi URL Widget Rumah';

  @override
  String get host => 'Host';

  @override
  String httpFailedWithCode(Object code) {
    return 'Permintaan gagal, kode status: $code';
  }

  @override
  String get ignoreCert => 'Abaikan sertifikat';

  @override
  String get image => 'Gambar';

  @override
  String get imagesList => 'Daftar gambar';

  @override
  String get init => 'Menginisialisasi';

  @override
  String get inner => 'Batin';

  @override
  String get install => 'Install';

  @override
  String get installDockerWithUrl => 'Silakan https://docs.docker.com/engine/install Docker pertama.';

  @override
  String get invalid => 'Tidak valid';

  @override
  String get jumpServer => 'Lompat server';

  @override
  String get keepForeground => 'Simpan Aplikasi Foreground!';

  @override
  String get keepStatusWhenErr => 'Menyimpan status server terakhir';

  @override
  String get keepStatusWhenErrTip => 'Hanya ketika terjadi kesalahan saat menjalankan skrip';

  @override
  String get keyAuth => 'Auth kunci';

  @override
  String get letterCache => 'Caching huruf';

  @override
  String get letterCacheTip => 'Direkomendasikan untuk menonaktifkan, tetapi setelah dinonaktifkan, tidak mungkin untuk memasukkan karakter CJK.';

  @override
  String get license => 'Lisensi';

  @override
  String get location => 'Lokasi';

  @override
  String get loss => 'kehilangan';

  @override
  String madeWithLove(Object myGithub) {
    return 'Dibuat dengan ❤️ oleh $myGithub';
  }

  @override
  String get manual => 'Manual';

  @override
  String get max => 'Max';

  @override
  String get maxRetryCount => 'Jumlah penyambungan kembali server';

  @override
  String get maxRetryCountEqual0 => 'Akan mencoba lagi lagi dan lagi.';

  @override
  String get min => 'Min';

  @override
  String get mission => 'Misi';

  @override
  String get more => 'Lebih Banyak';

  @override
  String get moveOutServerFuncBtnsHelp => 'Aktif: dapat ditampilkan di bawah setiap kartu pada halaman Tab Server. Nonaktif: dapat ditampilkan di bagian atas halaman Rincian Server.';

  @override
  String get ms => 'MS';

  @override
  String get needHomeDir => 'Jika Anda pengguna Synology, [lihat di sini](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Pengguna sistem lain perlu mencari cara membuat direktori home.';

  @override
  String get needRestart => 'Perlu memulai ulang aplikasi';

  @override
  String get net => 'Jaringan';

  @override
  String get netViewType => 'Jenis tampilan bersih';

  @override
  String get newContainer => 'Wadah baru';

  @override
  String get noLineChart => 'Jangan gunakan grafik garis';

  @override
  String get noLineChartForCpu => 'Jangan gunakan diagram garis untuk CPU';

  @override
  String get noPrivateKeyTip => 'Kunci privat tidak ada, mungkin telah dihapus atau ada kesalahan konfigurasi.';

  @override
  String get noPromptAgain => 'Jangan tanya lagi';

  @override
  String get node => 'Node';

  @override
  String get notAvailable => 'Tidak tersedia';

  @override
  String get onServerDetailPage => 'Di halaman detail server';

  @override
  String get onlyOneLine => 'Hanya tampilkan sebagai satu baris (dapat digulir)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Berlaku hanya ketika jumlah inti > 8';

  @override
  String get openLastPath => 'Buka jalur terakhir';

  @override
  String get openLastPathTip => 'Server yang berbeda akan memiliki catatan yang berbeda, dan catatan tersebut adalah jalur menuju pintu keluar';

  @override
  String get parseContainerStatsTip => 'Parsing status okupansi oleh Docker agak lambat';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% dari $size';
  }

  @override
  String get permission => 'Izin';

  @override
  String get pingAvg => 'Rata -rata:';

  @override
  String get pingInputIP => 'Harap masukkan IP / domain target.';

  @override
  String get pingNoServer => 'Tidak ada server untuk melakukan ping.\nHarap tambahkan server di tab Server.';

  @override
  String get pkg => 'Pkg';

  @override
  String get plugInType => 'Jenis Penyisipan';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Pratinjau';

  @override
  String get privateKey => 'Kunci Pribadi';

  @override
  String get process => 'Proses';

  @override
  String get pushToken => 'Dorong token';

  @override
  String get pveIgnoreCertTip => 'Tidak disarankan untuk diaktifkan, waspadai risiko keamanan! Jika Anda menggunakan sertifikat default dari PVE, Anda perlu mengaktifkan opsi ini.';

  @override
  String get pveLoginFailed => 'Login gagal. Tidak dapat mengautentikasi dengan nama pengguna/kata sandi dari konfigurasi server untuk login Linux PAM.';

  @override
  String get pveVersionLow => 'Fitur ini saat ini sedang dalam tahap pengujian dan hanya diuji pada PVE 8+. Gunakan dengan hati-hati.';

  @override
  String get pwd => 'Kata sandi';

  @override
  String get read => 'Baca';

  @override
  String get reboot => 'Reboot';

  @override
  String get rememberPwdInMem => 'Ingat kata sandi di dalam memori';

  @override
  String get rememberPwdInMemTip => 'Digunakan untuk kontainer, menangguhkan, dll.';

  @override
  String get rememberWindowSize => 'Ingat ukuran jendela';

  @override
  String get remotePath => 'Jalur jarak jauh';

  @override
  String get restart => 'Mengulang kembali';

  @override
  String get result => 'Hasil';

  @override
  String get rotateAngel => 'Sudut rotasi';

  @override
  String get route => 'Routing';

  @override
  String get run => 'Berlari';

  @override
  String get running => 'berlari';

  @override
  String get sameIdServerExist => 'Server dengan ID yang sama sudah ada';

  @override
  String get save => 'Menyimpan';

  @override
  String get saved => 'Diselamatkan';

  @override
  String get second => 'S';

  @override
  String get sensors => 'Sensor';

  @override
  String get sequence => 'Urutan';

  @override
  String get server => 'Server';

  @override
  String get serverDetailOrder => 'Detail pesanan widget halaman';

  @override
  String get serverFuncBtns => 'Tombol fungsi server';

  @override
  String get serverOrder => 'Pesanan server';

  @override
  String get sftpDlPrepare => 'Bersiap untuk terhubung ...';

  @override
  String get sftpEditorTip => 'Jika kosong, gunakan editor file bawaan aplikasi. Jika ada nilai, gunakan editor server jarak jauh, misalnya `vim` (disarankan untuk mendeteksi secara otomatis sesuai `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Gunakan `rm -r` untuk menghapus dir di SFTP';

  @override
  String get sftpSSHConnected => 'Sftp terhubung';

  @override
  String get sftpShowFoldersFirst => 'Folder ditampilkan lebih dulu';

  @override
  String get showDistLogo => 'Tampilkan logo distribusi';

  @override
  String get shutdown => 'Matikan';

  @override
  String get size => 'Ukuran';

  @override
  String get snippet => 'Snippet';

  @override
  String get softWrap => 'Pembungkus lembut';

  @override
  String get specifyDev => 'Tentukan perangkat';

  @override
  String get specifyDevTip => 'Misalnya, statistik lalu lintas jaringan secara default adalah untuk semua perangkat. Anda dapat menentukan perangkat tertentu di sini.';

  @override
  String get speed => 'Kecepatan';

  @override
  String spentTime(Object time) {
    return 'Menghabiskan waktu: $time';
  }

  @override
  String get sshTermHelp => 'Ketika terminal dapat digulirkan, menggeser secara horizontal dapat memilih teks. Mengklik tombol keyboard mengaktifkan/menonaktifkan keyboard. Ikon file membuka SFTP jalur saat ini. Tombol papan klip menyalin konten saat teks dipilih, dan menempelkan konten dari papan klip ke terminal saat tidak ada teks yang dipilih dan ada konten di papan klip. Ikon kode menempelkan potongan kode ke terminal dan mengeksekusinya.';

  @override
  String sshTip(Object url) {
    return 'Fungsi ini sekarang dalam tahap eksperimen.\n\nHarap laporkan bug di $url atau bergabunglah dengan pengembangan kami.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Switching Otomatis Kunci Virtual';

  @override
  String get start => 'Awal';

  @override
  String get stat => 'Statistik';

  @override
  String get stats => 'Statistik';

  @override
  String get stop => 'Berhenti';

  @override
  String get stopped => 'dihentikan';

  @override
  String get storage => 'Penyimpanan';

  @override
  String get supportFmtArgs => 'Parameter pemformatan berikut ini didukung:';

  @override
  String get suspend => 'Suspend';

  @override
  String get suspendTip => 'Fungsi penangguhan memerlukan hak akses root dan dukungan systemd.';

  @override
  String switchTo(Object val) {
    return 'Beralih ke $val';
  }

  @override
  String get sync => 'Sinkronisasi';

  @override
  String get syncTip => 'Pengaktifan ulang mungkin diperlukan agar beberapa perubahan dapat diterapkan.';

  @override
  String get system => 'Sistem';

  @override
  String get tag => 'Tag';

  @override
  String get temperature => 'Suhu';

  @override
  String get termFontSizeTip => 'Pengaturan ini akan memengaruhi ukuran terminal (lebar dan tinggi). Anda dapat melakukan zoom pada halaman terminal untuk menyesuaikan ukuran font sesi saat ini.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'pengujian';

  @override
  String get textScaler => 'Penskalaan font';

  @override
  String get textScalerTip => '1.0 => 100% (ukuran asli), hanya berfungsi pada bagian halaman server font, tidak disarankan untuk diubah.';

  @override
  String get theme => ' Tema';

  @override
  String get time => 'Waktu';

  @override
  String get times => 'Waktu';

  @override
  String get total => 'Total';

  @override
  String get traffic => 'Lalu lintas';

  @override
  String get trySudo => 'Cobalah menggunakan sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Tidak dikenal';

  @override
  String get unkownConvertMode => 'Mode Konversi Tidak Diketahui';

  @override
  String get update => 'Memperbarui';

  @override
  String get updateIntervalEqual0 => 'Anda mengatur ke 0, tidak akan memperbarui secara otomatis.\nTidak dapat menghitung status CPU.';

  @override
  String get updateServerStatusInterval => 'Interval Pembaruan Status Server';

  @override
  String get upload => 'Mengunggah';

  @override
  String get upsideDown => 'Terbalik';

  @override
  String get uptime => 'Uptime';

  @override
  String get useCdn => 'Menggunakan CDN';

  @override
  String get useCdnTip => 'Pengguna non-Cina disarankan menggunakan CDN. Apakah Anda ingin menggunakannya?';

  @override
  String get useNoPwd => 'Tidak ada kata sandi yang akan digunakan';

  @override
  String get usePodmanByDefault => 'Menggunakan Podman sebagai bawaan';

  @override
  String get used => 'Digunakan';

  @override
  String get view => 'Tampilan';

  @override
  String get viewErr => 'Lihat kesalahan';

  @override
  String get virtKeyHelpClipboard => 'Salin ke clipboard jika terminal yang dipilih tidak kosong, jika tidak, tempel isi clipboard ke terminal.';

  @override
  String get virtKeyHelpIME => 'Menyalakan/mematikan keyboard';

  @override
  String get virtKeyHelpSFTP => 'Buka direktori saat ini di SFTP.';

  @override
  String get waitConnection => 'Harap tunggu koneksi akan dibuat.';

  @override
  String get wakeLock => 'Tetap terjaga';

  @override
  String get watchNotPaired => 'Tidak ada Apple Watch yang dipasangkan';

  @override
  String get webdavSettingEmpty => 'Pengaturan webdav kosong';

  @override
  String get whenOpenApp => 'Saat membuka aplikasi';

  @override
  String get wolTip => 'Setelah mengonfigurasi WOL (Wake-on-LAN), permintaan WOL dikirim setiap kali server terhubung.';

  @override
  String get write => 'Tulis';

  @override
  String get writeScriptFailTip => 'Penulisan ke skrip gagal, mungkin karena tidak ada izin atau direktori tidak ada.';

  @override
  String get writeScriptTip => 'Setelah terhubung ke server, sebuah skrip akan ditulis ke ~/.config/server_box untuk memantau status sistem. Anda dapat meninjau konten skrip tersebut.';
}
