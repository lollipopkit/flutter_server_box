import 'l10n.dart';

/// The translations for Indonesian (`id`).
class SId extends S {
  SId([String locale = 'id']) : super(locale);

  @override
  String get about => 'Tentang';

  @override
  String get aboutThanks => 'Terima kasih kepada orang -orang berikut yang berpartisipasi.';

  @override
  String get add => 'Menambahkan';

  @override
  String get addAServer => 'tambahkan server';

  @override
  String get addPrivateKey => 'Tambahkan kunci pribadi';

  @override
  String get addSystemPrivateKeyTip => 'Saat ini tidak memiliki kunci privat, apakah Anda menambahkan kunci yang disertakan dengan sistem (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Ditambahkan ke Daftar Tugas';

  @override
  String get all => 'Semua';

  @override
  String get alreadyLastDir => 'Sudah di direktori terakhir.';

  @override
  String get alterUrl => 'Alter url';

  @override
  String askContinue(Object msg) {
    return '$msg, lanjutkan?';
  }

  @override
  String get attention => 'Perhatian';

  @override
  String get authRequired => 'Auth diperlukan';

  @override
  String get auto => 'Auto';

  @override
  String get autoCheckUpdate => 'Periksa pembaruan otomatis';

  @override
  String get autoConnect => 'Hubungkan otomatis';

  @override
  String get autoUpdateHomeWidget => 'Widget Rumah Pembaruan Otomatis';

  @override
  String get backup => 'Cadangan';

  @override
  String get backupAndRestore => 'Cadangan dan Pulihkan';

  @override
  String get backupTip => 'Data yang diekspor hanya dienkripsi.\nTolong jaga keamanannya.';

  @override
  String get backupVersionNotMatch => 'Versi cadangan tidak cocok.';

  @override
  String get bgRun => 'Jalankan di Backgroud';

  @override
  String get bioAuth => 'Biosertifikasi';

  @override
  String get canPullRefresh => 'Anda dapat menarik untuk menyegarkan.';

  @override
  String get cancel => 'Membatalkan';

  @override
  String get choose => 'Memilih';

  @override
  String get chooseFontFile => 'Pilih file font';

  @override
  String get choosePrivateKey => 'Pilih Kunci Pribadi';

  @override
  String get clear => 'Jernih';

  @override
  String get close => 'Menutup';

  @override
  String get cmd => 'Memerintah';

  @override
  String get conn => 'Koneksi';

  @override
  String get connected => 'Terhubung';

  @override
  String get containerName => 'Nama kontainer';

  @override
  String get containerStatus => 'Status wadah';

  @override
  String get convert => 'Mengubah';

  @override
  String get copy => 'Menyalin';

  @override
  String get copyPath => 'Path Copy';

  @override
  String get createFile => 'Buat file';

  @override
  String get createFolder => 'Membuat folder';

  @override
  String get dark => 'Gelap';

  @override
  String get debug => 'Debug';

  @override
  String get decode => 'Membaca sandi';

  @override
  String get decompress => 'Dekompresi';

  @override
  String get delete => 'Menghapus';

  @override
  String get deleteScripts => 'Menghapus skrip server secara bersamaan';

  @override
  String get deleteServers => 'Penghapusan server secara batch';

  @override
  String get dirEmpty => 'Pastikan dir kosong.';

  @override
  String get disabled => 'Dengan disabilitas';

  @override
  String get disconnected => 'Terputus';

  @override
  String get disk => 'Disk';

  @override
  String get diskIgnorePath => 'Abaikan jalan untuk disk';

  @override
  String get displayName => 'Nama tampilan';

  @override
  String dl2Local(Object fileName) {
    return 'Unduh $fileName ke lokal?';
  }

  @override
  String get dockerEditHost => 'Edit Docker_host';

  @override
  String get dockerEmptyRunningItems => 'Tidak ada wadah yang berjalan.\nMungkin saja env DOCKER_HOST tidak dibaca dengan benar. Anda dapat menemukannya dengan menjalankan `echo \$DOCKER_HOST` di terminal.';

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
  String get download => 'Unduh';

  @override
  String get edit => 'Edit';

  @override
  String get editVirtKeys => 'Edit kunci virtual';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'Performa penyorotan kode saat ini lebih buruk, dan dapat dimatikan secara opsional untuk perbaikan.';

  @override
  String get encode => 'Menyandi';

  @override
  String get error => 'Kesalahan';

  @override
  String get exampleName => 'Nama contoh';

  @override
  String get experimentalFeature => 'Fitur eksperimental';

  @override
  String get export => 'Ekspor';

  @override
  String get extraArgs => 'Args ekstra';

  @override
  String get failed => 'Gagal';

  @override
  String get feedback => 'Masukan';

  @override
  String get feedbackOnGithub => 'Jika Anda memiliki pertanyaan, silakan umpan balik tentang GitHub.';

  @override
  String get fieldMustNotEmpty => 'Bidang -bidang ini tidak boleh kosong.';

  @override
  String fileNotExist(Object file) {
    return '$file tidak ada';
  }

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'File \'$file\' terlalu besar $size, max $sizeMax';
  }

  @override
  String get files => 'File';

  @override
  String get finished => 'Selesai';

  @override
  String get followSystem => 'Ikuti sistem';

  @override
  String get font => 'Font';

  @override
  String get fontSize => 'Ukuran huruf';

  @override
  String foundNUpdate(Object count) {
    return 'Menemukan $count pembaruan';
  }

  @override
  String get fullScreen => 'Mode Layar Penuh';

  @override
  String get fullScreenJitter => 'Jitter layar penuh';

  @override
  String get fullScreenJitterHelp => 'Untuk menghindari pembakaran layar';

  @override
  String get getPushTokenFailed => 'Tidak bisa mengambil token dorong';

  @override
  String get gettingToken => 'Mendapatkan token ...';

  @override
  String get goBackQ => 'Datang kembali?';

  @override
  String get goto => 'Pergi ke';

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
  String get icloudSynced => 'iCloud disinkronkan dan beberapa pengaturan mungkin memerlukan pengaktifan ulang aplikasi agar dapat diterapkan.';

  @override
  String get image => 'Gambar';

  @override
  String get imagesList => 'Daftar gambar';

  @override
  String get import => 'Impor';

  @override
  String get inner => 'Batin';

  @override
  String get inputDomainHere => 'Input domain di sini';

  @override
  String get install => 'Install';

  @override
  String get installDockerWithUrl => 'Silakan https://docs.docker.com/engine/install Docker pertama.';

  @override
  String get invalidJson => 'JSON tidak valid';

  @override
  String get invalidVersion => 'Versi tidak valid';

  @override
  String invalidVersionHelp(Object url) {
    return 'Pastikan Docker diinstal dengan benar, atau Anda menggunakan versi yang tidak dikompilasi. Jika Anda tidak memiliki masalah di atas, silakan kirimkan masalah pada $url.';
  }

  @override
  String get isBusy => 'Sibuk sekarang';

  @override
  String get jumpServer => 'Lompat server';

  @override
  String get keepForeground => 'Simpan Aplikasi Foreground!';

  @override
  String get keyAuth => 'Auth kunci';

  @override
  String get keyboardCompatibility => 'Mungkin untuk meningkatkan kompatibilitas metode input';

  @override
  String get keyboardType => 'Tipe Keyborad';

  @override
  String get language => 'Bahasa';

  @override
  String get languageName => 'Indonesia';

  @override
  String get lastTry => 'Percobaan terakhir';

  @override
  String get launchPage => 'Halaman peluncuran';

  @override
  String get license => 'Lisensi';

  @override
  String get light => 'Terang';

  @override
  String get loadingFiles => 'Memuat file ...';

  @override
  String get location => 'Lokasi';

  @override
  String get log => 'Catatan';

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
  String get moveOutServerFuncBtnsHelp => 'Aktif: dapat ditampilkan di bawah setiap kartu pada halaman Tab Server. Nonaktif: dapat ditampilkan di bagian atas halaman Rincian Server.';

  @override
  String get ms => 'MS';

  @override
  String get name => 'Nama';

  @override
  String get needRestart => 'Perlu memulai ulang aplikasi';

  @override
  String get net => 'Net';

  @override
  String get netViewType => 'Jenis tampilan bersih';

  @override
  String get newContainer => 'Wadah baru';

  @override
  String get noClient => 'Tidak ada klien';

  @override
  String get noInterface => 'Tidak ada antarmuka';

  @override
  String get noOptions => 'Tidak ada opsi';

  @override
  String get noResult => 'Tidak ada hasil';

  @override
  String get noSavedPrivateKey => 'Tidak ada kunci pribadi yang disimpan.';

  @override
  String get noSavedSnippet => 'Tidak ada cuplikan yang disimpan.';

  @override
  String get noServerAvailable => 'Tidak ada server yang tersedia.';

  @override
  String get noTask => 'Tidak bertanya';

  @override
  String get noUpdateAvailable => 'Tidak ada pembaruan yang tersedia';

  @override
  String get notSelected => 'Tidak terpilih';

  @override
  String get note => 'Catatan';

  @override
  String get nullToken => 'Token NULL';

  @override
  String get ok => 'OKE';

  @override
  String get onServerDetailPage => 'Di halaman detail server';

  @override
  String get open => 'Membuka';

  @override
  String get openLastPath => 'Buka jalur terakhir';

  @override
  String get openLastPathTip => 'Server yang berbeda akan memiliki catatan yang berbeda, dan catatan tersebut adalah jalur menuju pintu keluar';

  @override
  String get paste => 'Tempel';

  @override
  String get path => 'Jalur';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% dari $size';
  }

  @override
  String get pickFile => 'Pilih file';

  @override
  String get pingAvg => 'Rata -rata:';

  @override
  String get pingInputIP => 'Harap masukkan IP / domain target.';

  @override
  String get pingNoServer => 'Tidak ada server untuk melakukan ping.\nHarap tambahkan server di tab Server.';

  @override
  String get pkg => 'Pkg';

  @override
  String get platformNotSupportUpdate => 'Platform saat ini tidak mendukung pembaruan aplikasi.\nSilakan bangun dari sumber dan instal.';

  @override
  String get plzEnterHost => 'Harap masukkan host.';

  @override
  String get plzSelectKey => 'Pilih kunci.';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Pratinjau';

  @override
  String get primaryColorSeed => 'Warna utama';

  @override
  String get privateKey => 'Kunci Pribadi';

  @override
  String get process => 'Proses';

  @override
  String get pushToken => 'Dorong token';

  @override
  String get pwd => 'Kata sandi';

  @override
  String get read => 'Baca';

  @override
  String get reboot => 'Reboot';

  @override
  String get remotePath => 'Jalur jarak jauh';

  @override
  String get rename => 'Ganti nama';

  @override
  String reportBugsOnGithubIssue(Object url) {
    return 'Harap laporkan bug di $url';
  }

  @override
  String get restart => 'Mengulang kembali';

  @override
  String get restore => 'Memulihkan';

  @override
  String get restoreSuccess => 'Kembalikan kesuksesan. Mulai ulang aplikasi untuk diterapkan.';

  @override
  String get result => 'Hasil';

  @override
  String get rotateAngel => 'Sudut rotasi';

  @override
  String get run => 'Berlari';

  @override
  String get save => 'Menyimpan';

  @override
  String get saved => 'Diselamatkan';

  @override
  String get second => 'S';

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
  String get serverTabConnecting => 'Menghubungkan ...';

  @override
  String get serverTabEmpty => 'Tidak ada server.\nKlik fab untuk menambahkan satu.';

  @override
  String get serverTabFailed => 'Gagal';

  @override
  String get serverTabLoading => 'Memuat...';

  @override
  String get serverTabPlzSave => 'Harap \'simpan\' kunci pribadi ini lagi.';

  @override
  String get serverTabUnkown => 'Negara yang tidak diketahui';

  @override
  String get setting => 'Pengaturan';

  @override
  String get sftpDlPrepare => 'Bersiap untuk terhubung ...';

  @override
  String get sftpRmrDirSummary => 'Gunakan `rm -r` untuk menghapus dir di SFTP';

  @override
  String get sftpSSHConnected => 'Sftp terhubung';

  @override
  String get showDistLogo => 'Tampilkan logo distribusi';

  @override
  String get shutdown => 'Matikan';

  @override
  String get snippet => 'Snippet';

  @override
  String get speed => 'Kecepatan';

  @override
  String spentTime(Object time) {
    return 'Menghabiskan waktu: $time';
  }

  @override
  String sshTip(Object url) {
    return 'Fungsi ini sekarang dalam tahap eksperimen.\n\nHarap laporkan bug di $url atau bergabunglah dengan pengembangan kami.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Switching Otomatis Kunci Virtual';

  @override
  String get start => 'Awal';

  @override
  String get stats => 'Statistik';

  @override
  String get stop => 'Berhenti';

  @override
  String get success => 'Kesuksesan';

  @override
  String get suspend => 'Suspend';

  @override
  String get suspendTip => 'Fungsi penangguhan memerlukan hak akses root dan dukungan systemd.';

  @override
  String get syncTip => 'Pengaktifan ulang mungkin diperlukan agar beberapa perubahan dapat diterapkan.';

  @override
  String get system => 'Sistem';

  @override
  String get tag => 'Tag';

  @override
  String get temperature => 'Suhu';

  @override
  String get terminal => 'Terminal';

  @override
  String get theme => ' Tema';

  @override
  String get themeMode => 'Mode tema';

  @override
  String get times => 'Waktu';

  @override
  String get traffic => 'Lalu lintas';

  @override
  String get ttl => 'ttl';

  @override
  String get unknown => 'Tidak dikenal';

  @override
  String get unknownError => 'Kesalahan yang tidak diketahui';

  @override
  String get unkownConvertMode => 'Mode Konversi Tidak Diketahui';

  @override
  String get update => 'Memperbarui';

  @override
  String get updateAll => 'Perbarui semua';

  @override
  String get updateIntervalEqual0 => 'Anda mengatur ke 0, tidak akan memperbarui secara otomatis.\nTidak dapat menghitung status CPU.';

  @override
  String get updateServerStatusInterval => 'Interval Pembaruan Status Server';

  @override
  String updateTip(Object newest) {
    return 'UPDATE: v1.0.$newest';
  }

  @override
  String updateTipTooLow(Object newest) {
    return 'Versi saat ini terlalu rendah, harap perbarui ke v1.0.$newest';
  }

  @override
  String get upload => 'Mengunggah';

  @override
  String get upsideDown => 'Terbalik';

  @override
  String get urlOrJson => 'URL atau JSON';

  @override
  String get useNoPwd => 'Tidak ada kata sandi yang akan digunakan.';

  @override
  String get user => 'Username';

  @override
  String versionHaveUpdate(Object build) {
    return 'Ditemukan: v1.0.$build, klik untuk memperbarui';
  }

  @override
  String versionUnknownUpdate(Object build) {
    return 'Saat ini: v1.0.$build. Klik untuk memeriksa pembaruan.';
  }

  @override
  String versionUpdated(Object build) {
    return 'Saat ini: v1.0.$build, mutakhir';
  }

  @override
  String get viewErr => 'Lihat kesalahan';

  @override
  String get virtKeyHelpClipboard => 'Salin ke clipboard jika terminal yang dipilih tidak kosong, jika tidak, tempel isi clipboard ke terminal.';

  @override
  String get virtKeyHelpSFTP => 'Buka direktori saat ini di SFTP.';

  @override
  String get waitConnection => 'Harap tunggu koneksi akan dibuat.';

  @override
  String get watchNotPaired => 'Tidak ada Apple Watch yang dipasangkan';

  @override
  String get whenOpenApp => 'Saat membuka aplikasi';

  @override
  String get willTakEeffectImmediately => 'Akan segera berlaku';

  @override
  String get write => 'Tulis';
}
