// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get crashCollect => 'Data diagnostik';

  @override
  String get crashCollectIntro =>
      'ServerBox mencatat apa yang terjadi saat berjalan agar masalah dapat diperbaiki. Pilih jumlah informasi yang dikirim.';

  @override
  String get crashCollectNone => 'Tidak ada';

  @override
  String get crashCollectNoneTip =>
      'Laporan tetap tersimpan di perangkat ini; setelah terjadi kerusakan, Anda dapat mengirimkannya secara manual.';

  @override
  String get crashCollectBasic => 'Informasi dasar';

  @override
  String get crashCollectBasicTip =>
      'Hanya informasi kerusakan yang disertakan; log dan data performa tidak disertakan. **Ini membantu kami menyempurnakan aplikasi dan memperbaiki bug.**';

  @override
  String get crashCollectFooter =>
      'Pada tingkat apa pun, nama server yang dikenal beserta alamat dan nama penggunanya diganti dengan placeholder saat dicatat. Tingkat pengumpulan dapat diubah nanti di Pengaturan.';

  @override
  String get privacy => 'Privasi';

  @override
  String get privacyPolicy => 'Kebijakan privasi';

  @override
  String get crashLastRunFailed =>
      'ServerBox berhenti secara tak terduga saat terakhir dijalankan.';

  @override
  String get crashReportTitle => 'Laporan kerusakan';

  @override
  String get crashReportHint =>
      'Ini adalah log dari sesi sebelumnya. Nama dan alamat server yang dikenal telah diganti dengan placeholder, tetapi detail lain mungkin tersisa. Baca dengan saksama sebelum mengirimkannya.';

  @override
  String get crashReportSubmit => 'Salin & laporkan';

  @override
  String get preReleaseUpdates => 'Terima pembaruan pra-rilis';

  @override
  String get addSystemPrivateKeyTip =>
      'Saat ini tidak memiliki kunci privat, apakah Anda menambahkan kunci yang disertakan dengan sistem (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Ditambahkan ke Daftar Tugas';

  @override
  String get askAi => 'Tanya AI';

  @override
  String get askAiInsertTerminal => 'Masukkan ke terminal';

  @override
  String get remoteDesktop => 'Desktop jarak jauh';

  @override
  String get askAiRiskReadOnly => 'Hanya baca';

  @override
  String get askAiRiskCaution => 'Mengubah sistem';

  @override
  String get askAiRiskUnvetted => 'Host belum diverifikasi';

  @override
  String get askAiRiskDestructive => 'Risiko tinggi';

  @override
  String get askAiAutoRunSafeCommands =>
      'Jalankan otomatis perintah hanya-baca';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Hanya jalan jika model dan pemeriksaan lokal sama-sama menyebutnya hanya-baca';

  @override
  String get askAiHistory => 'Riwayat percakapan';

  @override
  String get askAiNewConversation => 'Percakapan baru';

  @override
  String get askAiUntitledConversation => 'Tanpa judul';

  @override
  String get askAiRenameConversation => 'Ganti nama percakapan';

  @override
  String get askAiDeleteConversationTitle => 'Hapus percakapan ini?';

  @override
  String get askAiDeleteConversationTip =>
      'Menghapusnya dari perangkat ini. Tidak bisa dibatalkan.';

  @override
  String get agentNoHistory =>
      'Tidak ada percakapan Agent global yang tersimpan';

  @override
  String get agentClearHistoryTitle => 'Hapus riwayat Agent global?';

  @override
  String get agentClearHistoryTip =>
      'Semua percakapan Agent global akan dihapus dari perangkat ini.';

  @override
  String get agentCommandMayStillRun =>
      'Perintah yang dihentikan mungkin masih berjalan di server.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Baca berkas';

  @override
  String get agentToolWriteFile => 'Tulis berkas';

  @override
  String get floatOverTabs => 'Mengambang di atas tab lain';

  @override
  String get agentToolSshConnect => 'Sambungkan SSH';

  @override
  String get agentToolSshDisconnect => 'Putuskan SSH';

  @override
  String get agentSshConnectTitle => 'Sambungkan ke host baru';

  @override
  String get agentAuthMethod => 'Autentikasi';

  @override
  String get agentSshConnectTip =>
      'Agent ingin koneksi SSH. Masukkan kata sandi di sini';

  @override
  String get agentAdHocSessions => 'Koneksi sementara';

  @override
  String get agentSaveServerTitle => 'Simpan sebagai server';

  @override
  String get agentSaveServerTip =>
      'Host ini dan kata sandi yang dimasukkan disimpan di perangkat ini';

  @override
  String get agentMonitorOptional => 'Agen monitor (opsional)';

  @override
  String get authFailTip => 'Autentikasi gagal. Periksa datanya';

  @override
  String get autoBackupConflict =>
      'Hanya satu pencadangan otomatis yang dapat diaktifkan pada saat yang bersamaan.';

  @override
  String get autoConnect => 'Hubungkan otomatis';

  @override
  String get autoRun => 'Berjalan Otomatis';

  @override
  String get autoUpdateHomeWidget => 'Widget Rumah Pembaruan Otomatis';

  @override
  String get availableTabs => 'Tab Tersedia';

  @override
  String get backupEncrypted => 'Cadangan telah dienkripsi';

  @override
  String get backupNotEncrypted => 'Cadangan tidak dienkripsi';

  @override
  String get backupPassword => 'Kata sandi cadangan';

  @override
  String get backupPasswordRemoved => 'Kata sandi cadangan dihapus';

  @override
  String get backupPasswordSet => 'Kata sandi cadangan ditetapkan';

  @override
  String get backupPasswordTip =>
      'Setel kata sandi untuk mengenkripsi file cadangan. Biarkan kosong untuk menonaktifkan enkripsi.';

  @override
  String get backupPasswordWrong => 'Kata sandi cadangan salah';

  @override
  String get connectAll => 'Hubungkan semua';

  @override
  String get disconnectAll => 'Putuskan semua';

  @override
  String get distIcon => 'Tanda distribusi';

  @override
  String get distIconIntroLegal =>
      'Sebuah tanda hanya menyatakan apa yang dibaca perangkat ini dari sistem jarak jauh, yang bisa saja keliru atau usang, dan tidak menandakan turunan, hasil bangun ulang, maupun versi tertentu. Bila tidak dapat dikenali, ikon biasa yang digambar.\n\nSetiap tanda adalah merek dagang pemiliknya masing-masing dan di sini hanya dipakai untuk merujuk pada sistem yang ditandainya.';

  @override
  String get distIconTip =>
      'Tampilkan tanda kecil di samping setiap server untuk sistem yang tampaknya dijalankannya';

  @override
  String get distNameMap => 'Pemetaan nama';

  @override
  String get distNameMapTip =>
      'Hanya untuk distribusi yang nama berkasnya berbeda di tempat Anda menaruh tanda-tanda itu. Kuncinya adalah nama yang dipakai aplikasi ini; nilainya adalah nama yang akan diambil. Biarkan kosong selama tidak ada tanda yang hilang.';

  @override
  String get logoUrl => 'URL logo';

  @override
  String get logoUrlTip =>
      'Gambar besar di bagian atas halaman sebuah server, dengan warna aslinya.';

  @override
  String get globe => 'Bola dunia';

  @override
  String get locationTip =>
      'Tempat server ini digambar di bola dunia. Lintang lalu bujur, dalam derajat — misalnya 39.9042, 116.4074.';

  @override
  String get markUrl => 'URL tanda';

  @override
  String get markUrlTip =>
      'Tanda kecil di samping nama server pada daftar. Kosong berarti tidak ada.\n\nBukan gambar yang sama dengan logo';

  @override
  String get navTabMenuTip =>
      'Tekan lama sebuah tab — atau klik kanan — untuk menghubungkan atau memutuskan semuanya sekaligus.';

  @override
  String nTags(int count) {
    return '$count tag';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Cadangan jarak jauh memerlukan kata sandi cadangan yang tidak kosong';

  @override
  String get monitorHttpsRequired =>
      'Agen monitor jarak jauh butuh HTTPS, kecuali HTTP diizinkan untuknya.';

  @override
  String get monitorAllowInsecureHttp => 'Izinkan HTTP';

  @override
  String get plainHttpTitle => 'Agen ini disajikan lewat HTTP polos';

  @override
  String get plainHttpTip =>
      'Kata sandi dan semua yang diminta aplikasi ini akan dikirim tanpa enkripsi. Belum ada yang dikirim.';

  @override
  String get allowForThisServer => 'Izinkan untuk server ini';

  @override
  String get viewError => 'Lihat kesalahan';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Hanya di jaringan privat tepercaya yang mengenkripsi transportnya sendiri, misalnya Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Membaca status server ini dari HTTP API agen **monitor**, bukan menjalankan perintah lewat SSH.\n\nAgen harus dipasang di server terlebih dahulu; tren, aplikasi jam tangan, dan widget layar utama bergantung padanya.\n\n[Cara memasang agen monitor]($url)';
  }

  @override
  String get backupThemesNotRestored =>
      'Dipulihkan, kecuali tema-tema ini. Instal ulang dari toko tema atau dari file asalnya.';

  @override
  String get backupTip =>
      'Data yang diekspor dapat dienkripsi dengan kata sandi. \nHarap jaga keamanannya.';

  @override
  String get icloudBackupStatusTitle => 'Status cadangan';

  @override
  String get icloudBackupStatusLoading => 'Memuat status cadangan iCloud...';

  @override
  String get icloudBackupStatusError =>
      'Tidak dapat membaca metadata cadangan iCloud';

  @override
  String get icloudBackupStatusEmpty =>
      'Belum ada berkas cadangan iCloud yang ditemukan';

  @override
  String get icloudBackupStateUploading => 'Mengunggah';

  @override
  String get icloudBackupStateConflict => 'Terdeteksi konflik';

  @override
  String get icloudBackupStateUploaded => 'Terunggah';

  @override
  String get icloudBackupStateWaiting => 'Menunggu iCloud';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return 'Cadangan terakhir: $lastModified\nStatus: $remoteState';
  }

  @override
  String get bgRun => 'Jalankan di Backgroud';

  @override
  String get bgRunTip =>
      'Sakelar ini hanya berarti aplikasi akan mencoba berjalan di latar belakang, apakah aplikasi dapat berjalan di latar belakang tergantung pada apakah izin diaktifkan atau tidak. Untuk Android asli, nonaktifkan \"Pengoptimalan Baterai\" di aplikasi ini, dan untuk miui, ubah kebijakan penghematan daya ke \"Tidak Terbatas\".';

  @override
  String get trayReadings => 'Pembacaan';

  @override
  String get trayChart => 'Grafik';

  @override
  String get trayChartNone => 'Tidak ada';

  @override
  String get trayCompact => 'Baris ringkas';

  @override
  String get trayCompactTip =>
      'Satu baris per server, tanpa grafik. Linux selalu menggunakan tata letak satu baris karena menu panelnya dikirim melalui D-Bus, yang membawa label alih-alih tata letak khusus; grafik yang dipilih tetap dapat disertakan sebagai gambar.';

  @override
  String get trayKeepRunning => 'Tetap berjalan di baki sistem';

  @override
  String get trayKeepRunningTip =>
      'Menutup jendela akan membiarkan aplikasi tetap berjalan di bilah menu atau area notifikasi, dan tetap memantau server Anda. Nonaktifkan ini agar tombol tutup mengakhiri aplikasi.';

  @override
  String get bgRunNeedsNotification =>
      'Berjalan di latar belakang butuh notifikasi permanen, dan aplikasi ini tidak punya izin notifikasi. Ketuk untuk memberikannya.';

  @override
  String get clearAllStatsContent =>
      'Apakah Anda yakin ingin menghapus semua statistik koneksi server? Tindakan ini tidak dapat dibatalkan.';

  @override
  String get clearAllStatsTitle => 'Hapus Semua Statistik';

  @override
  String clearServerStatsContent(String serverName) {
    return 'Apakah Anda yakin ingin menghapus statistik koneksi untuk server \"$serverName\"? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return 'Hapus Statistik $serverName';
  }

  @override
  String get clearThisServerStats => 'Hapus Statistik Server Ini';

  @override
  String get closeAfterSave => 'Simpan dan tutup';

  @override
  String get collapseUITip =>
      'Apakah akan menciutkan daftar panjang yang ada di UI secara default atau tidak';

  @override
  String get connectionDetails => 'Detail Koneksi';

  @override
  String get connectionStats => 'Statistik Koneksi';

  @override
  String get connectionStatsDesc =>
      'Lihat tingkat keberhasilan koneksi server dan riwayat';

  @override
  String get containerTrySudoTip =>
      'Contohnya: Di dalam aplikasi, pengguna diatur sebagai aaa, tetapi Docker diinstal di bawah pengguna root. Dalam kasus ini, Anda perlu mengaktifkan opsi ini.';

  @override
  String get containerSudoPasswordRequired =>
      'Kata sandi sudo diperlukan untuk mengakses Docker. Silakan masukkan kata sandi Anda.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Kata sandi sudo salah atau tidak diizinkan. Silakan coba lagi.';

  @override
  String get copyPath => 'Path Copy';

  @override
  String get customCmd => 'Perintah kustom';

  @override
  String get deleteServers => 'Penghapusan server secara batch';

  @override
  String get deleteDirRecursive => 'Hapus folder beserta seluruh isinya';

  @override
  String get dirEmpty => 'Pastikan dir kosong.';

  @override
  String get discoverSshServers => 'Temukan Server SSH';

  @override
  String get discoveryFailed => 'Penemuan gagal';

  @override
  String get discoverySettings => 'Pengaturan Penemuan';

  @override
  String get distro => 'Distribusi';

  @override
  String get diskHealth => 'Kesehatan disk';

  @override
  String dl2Local(String fileName) {
    return 'Unduh $fileName ke lokal?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Tidak ada wadah yang sedang berjalan.\nHal ini dapat terjadi karena:\n- Pengguna instalasi Docker tidak sama dengan nama pengguna yang dikonfigurasi di dalam Aplikasi.\n- Variabel lingkungan DOCKER_HOST tidak terbaca dengan benar. Anda bisa mendapatkannya dengan menjalankan `echo \$DOCKER_HOST` di terminal.';

  @override
  String get dockerProjectOther => 'Lainnya';

  @override
  String get dockerPruneTip =>
      'Hapus data yang tidak digunakan untuk mengosongkan ruang disk';

  @override
  String get dockerStatistics => 'Statistik Docker';

  @override
  String get editVirtKeys => 'Kunci virtual';

  @override
  String get editorHighlightTip =>
      'Performa penyorotan kode saat ini lebih buruk, dan dapat dimatikan secara opsional untuk perbaikan.';

  @override
  String get enableMdns => 'Aktifkan mDNS';

  @override
  String get enableMdnsDesc =>
      'Gunakan mDNS/Bonjour untuk menemukan layanan SSH';

  @override
  String get envVars => 'Variabel lingkungan';

  @override
  String get extraArgs => 'Args ekstra';

  @override
  String get fallbackSshDest => 'Tujuan SSH mundur';

  @override
  String get fdroidReleaseTip =>
      'Jika Anda mengunduh aplikasi ini dari F-Droid, disarankan untuk mematikan opsi ini.';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return 'File \'$file\' terlalu besar $size, max $sizeMax';
  }

  @override
  String get fileDirGone => 'Folder ini sudah tidak ada';

  @override
  String get fileDirGoneTip => 'Sudah dihapus atau diganti nama';

  @override
  String get fullScreen => 'Layar penuh';

  @override
  String get fullScreenJitter => 'Jitter layar penuh';

  @override
  String get fullScreenJitterHelp => 'Untuk menghindari pembakaran layar';

  @override
  String get fullScreenTip =>
      'Apakah mode layar penuh diaktifkan ketika perangkat diputar ke modus lanskap? Opsi ini hanya berlaku untuk tab server.';

  @override
  String get githubGistIdOptional => 'ID Gist (opsional)';

  @override
  String get githubGistToken => 'Token GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'Token kosong';

  @override
  String get githubGistIdInvalid =>
      'Ini bukan ID Gist maupun tautan Gist. Gunakan bagian terakhir dari alamat gist (https://gist.github.com/<user>/<ID>), atau kosongkan agar gist rahasia baru dibuat saat pencadangan pertama.';

  @override
  String get githubGistNotFound =>
      'GitHub tidak menemukan gist dengan ID ini yang dapat dibaca oleh token ini: ID mungkin salah, gist mungkin telah dihapus, atau gist tersebut milik akun lain. Kosongkan ID agar gist rahasia baru dibuat saat pencadangan pertama.';

  @override
  String get githubGistTokenRejected =>
      'GitHub menolak token ini: token mungkin salah, kedaluwarsa, atau dicabut, atau tidak memiliki izin gist (classic token: scope \"gist\"; fine-grained token: Gists read and write).';

  @override
  String get goto => 'Pergi ke';

  @override
  String get homeTabs => 'Tab Beranda';

  @override
  String get homeTabsCustomizeDesc =>
      'Sesuaikan tab mana yang muncul di halaman beranda dan urutannya';

  @override
  String get ignoreCert => 'Abaikan sertifikat';

  @override
  String get image => 'Gambar';

  @override
  String get macDmgBody =>
      'App Store mengharuskan aplikasi ini berjalan dalam sandbox, dan sandbox tidak bisa membuka terminal. Versi DMG bisa.\n\nVersi App Store mungkin berhenti diperbarui.';

  @override
  String get macDmgImportDenied =>
      'macOS tidak mengizinkan membaca data versi sebelumnya';

  @override
  String get macDmgImported => 'Data versi sebelumnya diimpor';

  @override
  String get macDmgImportFailed => 'Tidak bisa membaca data versi sebelumnya';

  @override
  String get macDmgTip =>
      'Terminal lokal dan menjalankan snippet secara lokal (versi DMG)';

  @override
  String get macDmgTitle => 'Versi DMG';

  @override
  String get showHiddenFiles => 'Tampilkan berkas tersembunyi';

  @override
  String get sshKeyAlgorithm => 'Algoritme';

  @override
  String get sshKeyComment => 'Komentar';

  @override
  String get sshKeyGenerate => 'Buat pasangan kunci';

  @override
  String get sshKeyGenerating => 'Membuat…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'Kunci privat [$name] belum dibuka.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Opsional. Kunci dengan frasa sandi disimpan terenkripsi, dan frasa itu diminta saat koneksi pertama memakai kunci ini.';

  @override
  String get sshKeyPassphraseWrong => 'Frasa sandi salah.';

  @override
  String get sshKeyPublicKey => 'Kunci publik';

  @override
  String get sshKeyPublicKeyTip =>
      'Tambahkan baris ini ke ~/.ssh/authorized_keys di server.';

  @override
  String get sshKeyRecommended => 'Disarankan';

  @override
  String get rememberKeyPassphrase => 'Ingat frasa sandi kunci';

  @override
  String get rememberKeyPassphraseTip =>
      'Simpan frasa sandi kunci privat terenkripsi di keychain sistem perangkat ini agar tidak diminta lagi setelah aplikasi dimulai ulang. Kunci tetap terenkripsi di cadangan. Menonaktifkan ini menghapus frasa sandi yang tersimpan.';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Masukkan frasa sandi untuk kunci privat [$name].';
  }

  @override
  String get ungrouped => 'Tanpa grup';

  @override
  String get containerReclaimable => 'Reclaimable';

  @override
  String get unused => 'Tidak terpakai';

  @override
  String get dangling => 'Menggantung';

  @override
  String get pruneUnusedImages => 'Bersihkan gambar tidak terpakai';

  @override
  String get pruneDanglingImages => 'Bersihkan gambar menggantung';

  @override
  String get pruneImages => 'Bersihkan gambar';

  @override
  String get unusedTaggedImages => 'Bertag tidak digunakan';

  @override
  String get pruneDanglingImagesTip => 'Hanya menghapus image menggantung.';

  @override
  String get pruneUnusedImagesTip =>
      'Juga hapus gambar bertag yang tidak digunakan kontainer mana pun.';

  @override
  String get includeUnusedVolumesTip =>
      'Juga hapus volume yang tidak digunakan kontainer mana pun.';

  @override
  String get pruneCommandPreview => 'Pratinjau perintah';

  @override
  String get pruneForceSshTip =>
      '-f melewati konfirmasi interaktif dan selalu aktif untuk eksekusi SSH.';

  @override
  String get pruneVolumes => 'Bersihkan volume';

  @override
  String get pruneUnusedData => 'Bersihkan data yang tidak digunakan';

  @override
  String get pull => 'Tarik';

  @override
  String get invalidHostFormat =>
      'Format host tidak valid. Hanya karakter IPv4, IPv6, dan domain yang diizinkan.';

  @override
  String get jumpServer => 'Lompat server';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return 'Jump server tidak ditemukan untuk $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '\"$name\" sudah ada';
  }

  @override
  String get noJumpServerAvailable => 'Tidak ada jump server yang tersedia.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump server dan ProxyCommand tidak bisa dipakai bersamaan.';

  @override
  String get noConnectionMethod => 'Atur SSH, agen monitor, atau keduanya';

  @override
  String get keepForeground => 'Simpan Aplikasi Foreground!';

  @override
  String get keepStatusWhenErr => 'Menyimpan status server terakhir';

  @override
  String get keepStatusWhenErrTip =>
      'Hanya ketika terjadi kesalahan saat menjalankan skrip';

  @override
  String get keyAuth => 'Auth kunci';

  @override
  String get lastFailure => 'Gagal Terakhir';

  @override
  String get lastSuccess => 'Sukses Terakhir';

  @override
  String get letterCache => 'Input keyboard biasa';

  @override
  String get letterCacheTip =>
      'Saat diaktifkan, input akan melalui IME biasa, yang dapat menghindari prompt keyboard aman di terminal pada beberapa sistem.';

  @override
  String get linuxShellTip =>
      'Shell yang dipakai terminal. Kosong mengembalikan /bin/sh.';

  @override
  String get linuxNetTip => 'Server DNS. Kosong mengembalikan bawaan';

  @override
  String madeWithLove(String myGithub) {
    return 'Dibuat dengan ❤️ oleh $myGithub';
  }

  @override
  String get maxConcurrency => 'Konkurensi Maksimum';

  @override
  String get maxRetryCount => 'Jumlah penyambungan kembali server';

  @override
  String get mirror => 'Mirror';

  @override
  String get needRestart => 'Perlu memulai ulang aplikasi';

  @override
  String get newContainer => 'Wadah baru';

  @override
  String get noConnectionStatsData => 'Tidak ada data statistik koneksi';

  @override
  String get noPrivateKeyTip =>
      'Kunci privat tidak ada, mungkin telah dihapus atau ada kesalahan konfigurasi.';

  @override
  String get noPromptAgain => 'Jangan tanya lagi';

  @override
  String get openLastPath => 'Buka jalur terakhir';

  @override
  String get openLastPathTip =>
      'Server yang berbeda akan memiliki catatan yang berbeda, dan catatan tersebut adalah jalur menuju pintu keluar';

  @override
  String get parseContainerStatsTip =>
      'Parsing status okupansi oleh Docker agak lambat';

  @override
  String get privateKey => 'Kunci Pribadi';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return 'Kunci privat [$keyId] tidak ditemukan.';
  }

  @override
  String get bmcPowerOnAction => 'Nyalakan';

  @override
  String get bmcShutdown => 'Matikan';

  @override
  String get bmcForceOff => 'Paksa mati';

  @override
  String get restart => 'Mulai ulang';

  @override
  String get bmcPowerCycle => 'Siklus daya';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Kirim ini ke $server? Layanan akan diminta \"$resetType\"';
  }

  @override
  String get bmcPowerDone => 'Status daya berubah';

  @override
  String get bmcPowerAccepted =>
      'Diterima, tetapi status daya belum berubah. Operasi halus bergantung pada OS';

  @override
  String get bmcPowerUnsupported =>
      'Layanan ini tidak mengizinkan apa pun untuk tindakan itu';

  @override
  String get bmcUnauthorized => 'BMC menolak akun ini';

  @override
  String get bmcAccountMissing => 'Tidak ada akun yang diatur untuk BMC ini';

  @override
  String get bmcPowerOn => 'Menyala';

  @override
  String get bmcPowerOff => 'Mati';

  @override
  String get bmcCertRejected =>
      'Sertifikat ditolak — tinjau di pengaturan server';

  @override
  String get bmcNotAService => 'Tidak ada layanan Redfish di alamat ini';

  @override
  String get bmcNoSystem => 'Layanan tidak melaporkan sistem apa pun';

  @override
  String get bmcSensorsTruncated => 'Hanya sensor pertama yang ditampilkan';

  @override
  String get bmcMultipleSystems => 'Hanya sistem pertama yang ditampilkan';

  @override
  String get bmcTip =>
      'BMC adalah komputer terpisah di motherboard, tetap terjangkau saat sistem operasi host tidak. Dikonfigurasi di sini, ia melaporkan status daya dan sensor perangkat keras saat server mati atau macet. Perlu Redfish, yang ada pada sebagian besar perangkat keras enterprise sejak sekitar 2016.';

  @override
  String get bmcCert => 'Sertifikat';

  @override
  String get bmcCertPinned => 'Ditinjau dan disematkan';

  @override
  String get bmcCertUnreviewed =>
      'Belum ditinjau — ketuk untuk melihat sertifikat';

  @override
  String get bmcCertReview =>
      'Sertifikat yang ditandatangani sendiri. Bandingkan sebelum menerima. Setelah itu hanya yang ini dipercaya.';

  @override
  String get bmcCertChanged => 'Sertifikat tidak cocok. Periksa.';

  @override
  String get bmcCertExpired => 'Kedaluwarsa.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Diterima sebelumnya: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'Alamat BMC harus berupa URL, mis. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Build ini berjalan dalam sandbox: perintah mendapat home kosong, bukan milikmu, jadi apa pun yang membaca ~/.ssh gagal. Versi DMG tidak.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Tidak dapat membaca berkas kunci privat $path: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Build ini tidak dapat membaca berkas di luar kontainernya, sehingga kunci di $path tidak terjangkau. Impor kunci di Pengaturan, atau gunakan versi DMG.';
  }

  @override
  String get pushToken => 'Dorong token';

  @override
  String get liveActivity => 'Aktivitas Live';

  @override
  String get liveActivityTip =>
      'Tampilkan sesi terminal di Layar Terkunci dan Dynamic Island. Nama server dan status koneksi dapat dilihat tanpa membuka kunci perangkat.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS tidak mengizinkannya. Sakelarnya ada di Pengaturan › ServerBox › Aktivitas Live dan Pengaturan › Face ID & Kode Sandi › Aktivitas Live.';

  @override
  String get proxyCommandNeedsLinux =>
      'ProxyCommand berjalan di lingkungan Linux perangkat ini. Pasang sistem Linux terlebih dahulu.';

  @override
  String get proxyCommandMobileTip =>
      'Di ponsel, perintah dijalankan di sistem Linux yang dipilih. Pasang dulu alat yang dipakainya (nc, socat, …) di sana.';

  @override
  String get pveIgnoreCertTip =>
      'Tidak disarankan untuk diaktifkan, waspadai risiko keamanan! Jika Anda menggunakan sertifikat default dari PVE, Anda perlu mengaktifkan opsi ini.';

  @override
  String get pvePasswordRequired =>
      'Kata sandi PVE diperlukan. Atur di pengaturan server.';

  @override
  String get pveOtpRequired =>
      'Autentikasi dua faktor aktif di server PVE ini. Masukkan kode OTP.';

  @override
  String get pveOtpCodeRequired => 'Kode OTP wajib diisi.';

  @override
  String get pveOtpVerificationFailed =>
      'Verifikasi OTP gagal. Coba lagi dengan kode baru.';

  @override
  String get pveOtpTitle => 'Verifikasi OTP';

  @override
  String get pveOtpLabel => 'Kode OTP';

  @override
  String get pveInvalidResponseBody =>
      'Login PVE mengembalikan isi respons yang tidak valid.';

  @override
  String get pveInvalidResponseData =>
      'Respons login PVE tidak berisi data yang valid.';

  @override
  String get pveMissingAuthTicket =>
      'Login PVE berhasil, tetapi tidak ada tiket autentikasi yang dikembalikan.';

  @override
  String get pveLoadingConnect => 'Menghubungkan...';

  @override
  String get pvePassword => 'Kata sandi PVE';

  @override
  String get pvePasswordHint =>
      'Diperlukan saat memakai autentikasi SSH berbasis kunci';

  @override
  String get read => 'Baca';

  @override
  String get recentConnections => 'Koneksi Terkini';

  @override
  String get rememberPwdInMem => 'Ingat kata sandi di dalam memori';

  @override
  String get rememberPwdInMemTip =>
      'Digunakan untuk kontainer, menangguhkan, dll.';

  @override
  String get remotePath => 'Jalur jarak jauh';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '$distro $installed terpasang, ada $latest. Pembaruan mengganti seluruh kontainer: data $pm hilang';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'Tutup terminal di $name sebelum menghapusnya';
  }

  @override
  String get rootfsSubtitle => 'Lingkungan pengguna Linux di perangkat ini';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return 'Mengunduh $distro $version (sekitar $size MB) dan mengekstraknya di perangkat ini.';
  }

  @override
  String get sameIdServerExist => 'Server dengan ID yang sama sudah ada';

  @override
  String get second => 'S';

  @override
  String get serverFilesUnavailableTip =>
      'Perlu SSH ke server ini, atau server_box_monitor terpasang dengan API file aktif.';

  @override
  String get back => 'Kembali';

  @override
  String get history => 'Riwayat';

  @override
  String get homeDir => 'Beranda';

  @override
  String selected(int count) {
    return '$count dipilih';
  }

  @override
  String get sendTo => 'Kirim ke…';

  @override
  String get serverFuncBtns => 'Tombol fungsi server';

  @override
  String get serverOrder => 'Pesanan server';

  @override
  String get serverOverview => 'Ringkasan server';

  @override
  String get serverOverviewTip =>
      'Tampilkan ringkasan di atas daftar server, dan bilah server di atas server yang terbuka';

  @override
  String get serverTabEmpty => 'Belum ada server';

  @override
  String get serverTabConnBadge => 'Jumlah koneksi pada tab server';

  @override
  String get serverTabConnBadgeTip =>
      'Jumlah server yang terhubung, misalnya 2/4';

  @override
  String get serverTabRequired => 'Tab server tidak dapat dihapus';

  @override
  String get shareCodeHint =>
      'Sampaikan digit ini secara terpisah kepada penerima. Digit ini tidak disertakan dalam kode QR.';

  @override
  String get shareCodePrompt => 'Kode 6 digit';

  @override
  String get shareCodeTitle => 'Kode sekali pakai';

  @override
  String get shareExpired =>
      'Data yang dibagikan sudah kedaluwarsa. Minta yang baru.';

  @override
  String get shareImportFile => 'Dari file yang dibagikan';

  @override
  String get shareImportTitle => 'Impor server yang dibagikan';

  @override
  String get shareIncludesKey =>
      'Data yang dibagikan menyertakan kunci privat.';

  @override
  String get shareOmittedBmc =>
      'Kredensial BMC. Alamat disertakan, tetapi kredensial tidak.';

  @override
  String get shareOmittedJump =>
      'Server jump, karena disimpan sebagai server terpisah di perangkat ini.';

  @override
  String get shareOmittedKeyPath =>
      'File kunci, karena lokasinya hanya berlaku di perangkat ini.';

  @override
  String get shareOmittedMissingKey =>
      'Kunci privat, karena tidak ada di penyimpanan kunci perangkat ini.';

  @override
  String get shareOmittedTip =>
      'Tidak disertakan; penerima harus mengonfigurasi:';

  @override
  String get sharePassphraseTip =>
      'Frasa sandi ini mengenkripsi file. Penerima memerlukannya untuk mengimpor server dan frasa ini tidak dapat dipulihkan.';

  @override
  String shareQrTip(int minutes) {
    return 'Data koneksi dalam kode QR ini dienkripsi. Data yang dibagikan akan kedaluwarsa dalam $minutes menit.';
  }

  @override
  String get shareScanQr => 'Pindai kode QR';

  @override
  String shareServerExists(String name) {
    return '“$name” di perangkat ini sudah menggunakan alamat tersebut. Tetap impor?';
  }

  @override
  String get shareTooBigForQr =>
      'Terlalu besar untuk kode QR. Bagikan sebagai file.';

  @override
  String get shareTooNew =>
      'Data ini dibuat dengan versi ServerBox yang lebih baru. Perbarui aplikasi untuk membukanya.';

  @override
  String get shareUnreadable => 'Ini bukan data ServerBox yang valid.';

  @override
  String get shareVia => 'Bagikan melalui';

  @override
  String get sftpDlPrepare => 'Bersiap untuk terhubung ...';

  @override
  String get sftpEditorTip =>
      'Kosong memakai editor bawaan. Misalnya `vim` (disarankan membaca `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Gunakan `rm -r` untuk menghapus dir di SFTP';

  @override
  String get sftpSSHConnected => 'Sftp terhubung';

  @override
  String get sftpShowFoldersFirst => 'Folder ditampilkan lebih dulu';

  @override
  String get sftpUnavailableUseScp =>
      'Jika host ini tidak punya subsistem SFTP, seperti banyak perangkat tertanam, ubah transfer berkasnya menjadi SCP di pengaturan server.';

  @override
  String get sshFileTransportTip =>
      'SFTP cocok untuk perangkat masa kini. Pilih SCP untuk host lama atau tertanam yang server SSH-nya tidak punya subsistem SFTP: ia butuh perintah `scp` dan shell yang juga punya utilitas berkas umum (`find`, `stat`, `mv`, `chmod`).';

  @override
  String get specifyDev => 'Tentukan perangkat';

  @override
  String get specifyDevTip =>
      'Trafik jaringan menghitung semua perangkat; sebutkan satu di sini';

  @override
  String get tempIsCelsiusTip =>
      'Jika aktif, nilai suhu diperlakukan sebagai Celsius, bukan milicelsius. Aktifkan hanya bila suhu tampil keliru (misalnya 0,1 °C, bukan 58 °C).';

  @override
  String get diskCountsNetwork => 'Hitung sistem berkas jaringan dalam total';

  @override
  String get diskCountsNetworkTip =>
      'Mount NFS, SMB, dan sejenisnya selalu ditampilkan. Kapasitasnya milik mesin lain, sehingga secara bawaan tidak dihitung dalam total disk. Berlaku saat status dikumpulkan lewat SSH; lewat monitor agent, pengaturan agent itu sendiri yang menentukan.';

  @override
  String get diskCountsNetworkAgentTip =>
      'Mount NFS, SMB, dan sejenisnya selalu ditampilkan. Kapasitasnya milik mesin lain, sehingga secara bawaan tidak dihitung dalam total disk — nilai yang disimpan agent di riwayat dan dipakai untuk peringatan disk.';

  @override
  String spentTime(String time) {
    return 'Menghabiskan waktu: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return 'Semua server sudah ada (ditemukan $duplicateCount duplikat)';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount duplikat akan dilewati';
  }

  @override
  String get sshConfigFound => 'Kami menemukan konfigurasi SSH di sistem Anda';

  @override
  String sshConfigFoundServers(int totalCount) {
    return 'Ditemukan $totalCount server';
  }

  @override
  String get sshConfigImport => 'Impor Konfigurasi SSH';

  @override
  String get sshConfigImportPermission =>
      'Apakah Anda ingin memberikan izin untuk membaca ~/.ssh/config dan secara otomatis mengimpor pengaturan server?';

  @override
  String get sshConfigImportTip =>
      'Prompt untuk membaca ~/.ssh/config saat pembuatan server pertama';

  @override
  String sshConfigImported(int count) {
    return 'Berhasil mengimpor $count server dari konfigurasi SSH';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return 'Kunci host SSH untuk $serverName telah berubah. Lanjutkan hanya jika Anda mempercayai server ini.';
  }

  @override
  String get sshHostKeyType => 'Jenis kunci host SSH';

  @override
  String get sshKnownHostKeys => 'Host dikenal';

  @override
  String get sshKnownHostKeysTip =>
      'Kunci host yang sudah diterima aplikasi ini';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return 'Kunci host SSH baru diterima dari $serverName. Periksa sidik jarinya sebelum mempercayai.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return 'Sidik jari tersimpan: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Kode verifikasi';

  @override
  String get sshConfigManualSelect =>
      'Apakah Anda ingin memilih file konfigurasi SSH secara manual?';

  @override
  String get sshConfigNoServers =>
      'Tidak ada server yang ditemukan dalam konfigurasi SSH';

  @override
  String get sshConfigPermissionDenied =>
      'Tidak dapat mengakses file konfigurasi SSH karena izin macOS.';

  @override
  String sshConfigServersToImport(int importCount) {
    return '$importCount server akan diimpor';
  }

  @override
  String get sshTermHelp =>
      'Ketika terminal dapat digulirkan, menggeser secara horizontal dapat memilih teks. Mengklik tombol keyboard mengaktifkan/menonaktifkan keyboard. Ikon file membuka SFTP jalur saat ini. Tombol papan klip menyalin konten saat teks dipilih, dan menempelkan konten dari papan klip ke terminal saat tidak ada teks yang dipilih dan ada konten di papan klip. Ikon kode menempelkan potongan kode ke terminal dan mengeksekusinya.';

  @override
  String get sshVirtualKeyAutoOff => 'Switching Otomatis Kunci Virtual';

  @override
  String get supportFmtArgs => 'Parameter pemformatan berikut ini didukung:';

  @override
  String get suspendTip =>
      'Fungsi penangguhan memerlukan hak akses root dan dukungan systemd.';

  @override
  String switchTo(String val) {
    return 'Beralih ke $val';
  }

  @override
  String get syncAppSettings => 'Sinkronkan pengaturan aplikasi';

  @override
  String get syncAppSettingsTip =>
      'Sertakan tema, tata letak, editor, terminal, dan preferensi perangkat lain dalam sinkronisasi otomatis.';

  @override
  String get termFontSizeTip =>
      'Pengaturan ini akan memengaruhi ukuran terminal (lebar dan tinggi). Anda dapat melakukan zoom pada halaman terminal untuk menyesuaikan ukuran font sesi saat ini.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (ukuran asli), hanya berfungsi pada bagian halaman server font, tidak disarankan untuk diubah.';

  @override
  String get times => 'Waktu';

  @override
  String get trySudo => 'Cobalah menggunakan sudo';

  @override
  String get sudoPromptNotFound =>
      'Tidak ada permintaan kata sandi sudo yang aktif.';

  @override
  String get updateServerStatusInterval => 'Interval Pembaruan Status Server';

  @override
  String get useNoPwd => 'Tidak ada kata sandi yang akan digunakan';

  @override
  String get usePodmanByDefault => 'Menggunakan Podman sebagai bawaan';

  @override
  String get used => 'Digunakan';

  @override
  String get viewDetails => 'Lihat Detail';

  @override
  String get virtKeyHelpIME => 'Menyalakan/mematikan keyboard';

  @override
  String get virtKeyHelpSFTP => 'Buka direktori saat ini di SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Pilih sebuah snippet dan jalankan di terminal ini.';

  @override
  String get virtKeyHelpTmux => 'Berpindah antar sesi dan jendela tmux.';

  @override
  String get virtKeyIntroActions => 'Pintasan';

  @override
  String get virtKeyIntroActionsTip =>
      'Tombol-tombol ini tidak mengetik, melainkan membuka sesuatu. Tahan salah satunya untuk membaca fungsinya.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'Di pengaturan terminal kamu bisa mengubah urutannya, menyalakan tombol lain (file, sudo, F1–F12…), atau menyembunyikan yang tidak pernah dipakai.';

  @override
  String get virtKeyIntroModifiers => 'Tombol pengubah';

  @override
  String get virtKeyIntroModifiersTip =>
      'Ketuk satu untuk mengaktifkannya, lalu ketuk huruf di papan ketik. Berlaku untuk satu tombol itu saja.';

  @override
  String get virtKeyIntroNav => 'Navigasi';

  @override
  String get virtKeyIntroNavTip =>
      'Tombol-tombol ini menggerakkan kursor. Tahan tombol panah untuk mengulanginya.';

  @override
  String get virtKeyIntroSelect =>
      'Selama terminal masih bisa digulir, seret ke samping untuk memilih teks.';

  @override
  String get virtKeyRows => 'Baris yang tampil sekaligus';

  @override
  String get virtKeyRowsTip =>
      'Sisanya berada di halaman tersendiri, digeser ke samping.';

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
  String get wolTip =>
      'Setelah mengonfigurasi WOL (Wake-on-LAN), permintaan WOL dikirim setiap kali server terhubung.';

  @override
  String get write => 'Tulis';

  @override
  String get writeScriptFailTip =>
      'Penulisan ke skrip gagal, mungkin karena tidak ada izin atau direktori tidak ada.';

  @override
  String get writeScriptTip =>
      'Setelah terhubung ke server, sebuah skrip akan ditulis ke `~/.config/server_box` \n | `/tmp/server_box` untuk memantau status sistem. Anda dapat meninjau konten skrip tersebut.';

  @override
  String get menuGitHubRepository => 'Repositori GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'Emulasi Podman Docker terdeteksi. Silakan beralih ke Podman di pengaturan.';

  @override
  String get betaTip =>
      'Fitur ini masih dalam uji beta. Fungsinya belum dijamin.';

  @override
  String get portForward_startPrompt =>
      'Tambahkan aturan penerusan porta untuk memulai';

  @override
  String get portForward_localHost => 'Host lokal';

  @override
  String get portForward_localPort => 'Porta lokal';

  @override
  String get portForward_remoteHost => 'Host jarak jauh';

  @override
  String get portForward_remotePort => 'Porta jarak jauh';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return 'Hapus $name?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Menurut waktu ditambahkan';

  @override
  String get tmuxAutoAttach => 'Sambung otomatis ke tmux';

  @override
  String get tmuxAuto => 'tmux otomatis';

  @override
  String get tmuxAutoTip =>
      'Mulai atau sambungkan tmux secara otomatis saat terhubung lewat SSH';

  @override
  String get tmuxSessionSelector => 'Pemilih sesi';

  @override
  String get tmuxSessionSelectorTip =>
      'Tampilkan pemilih sesi saat menghubungkan';

  @override
  String get tmuxDefaultSessionName => 'Nama sesi bawaan';

  @override
  String get tmuxSessionName => 'Nama sesi';

  @override
  String get tmuxNewSession => 'Sesi baru';

  @override
  String get tmuxNewWindow => 'Jendela baru';

  @override
  String get tmuxNoWindowsFound => 'Tidak ada jendela yang ditemukan';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jendela',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Tersambung';

  @override
  String get tmuxSkip => 'Lewati';

  @override
  String get tmuxNotAvailable => 'tmux tidak tersedia';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Jumlah segmen respons kontainer tidak sesuai: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Operasi kontainer lain sedang berlangsung';

  @override
  String processCount(int count) {
    return '$count proses';
  }

  @override
  String get processParseUnsupportedOutput =>
      'Format daftar proses tidak didukung.';

  @override
  String get processParseInvalidRows =>
      'Beberapa entri proses tidak dapat dibaca.';

  @override
  String get processParseInvalidWindowsJson =>
      'Respons proses Windows tidak dapat dibaca.';

  @override
  String get processParseInvalidWindowsRows =>
      'Beberapa entri proses Windows tidak dapat dibaca.';

  @override
  String get processKillTargetChanged =>
      'Proses telah berubah atau berhenti. Segarkan daftar lalu coba lagi.';

  @override
  String get processSearchHint => 'Nama, pengguna, atau PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tampilkan $count thread kernel',
      one: 'Tampilkan 1 thread kernel',
    );
    return '$_temp0';
  }

  @override
  String get processForceKill => 'Force kill';

  @override
  String get processStarted => 'Started';

  @override
  String get processThreads => 'Threads';

  @override
  String get watchServers => 'Server di jam tangan';

  @override
  String get watchServersTip =>
      'Jam mengambil sendiri dari monitor, jadi hanya server yang punya monitor bisa dipilih.';

  @override
  String get watchNoMonitorServer =>
      'Tidak ada server dengan agen monitor terkonfigurasi';

  @override
  String get legacyStatusGoneTitle => 'URL status tidak berfungsi lagi';

  @override
  String get legacyStatusGoneBody =>
      'Aplikasi jam tangan dan widget layar utama membaca alamat `/status` yang diketik manual. Endpoint itu sudah dihapus: ia hanya bisa melaporkan nilai saat ini sebagai teks, itulah sebabnya keduanya tidak pernah bisa menampilkan grafik.\n\nSekarang keduanya membaca API monitor yang terautentikasi, sehingga bisa menggambar tren dan tetap selaras dengan aplikasi sendiri. Atur server sekali di aplikasi, dan setiap jam tangan dan widget akan mengambilnya.';

  @override
  String get services => 'Layanan';

  @override
  String get status => 'Status';

  @override
  String get enable => 'Aktifkan';

  @override
  String get disable => 'Nonaktifkan';

  @override
  String get starting => 'Memulai';

  @override
  String get stopping => 'Menghentikan';

  @override
  String get serviceManagerUnsupported => 'Pengelola layanan tidak didukung';

  @override
  String get serviceManagerUnsupportedTip =>
      'Server ini menggunakan pengelola layanan yang belum didukung ServerBox. Pengelola yang didukung: systemd, procd, dan OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Dikelola oleh $manager';
  }

  @override
  String get serviceListFailed => 'Tidak dapat menampilkan daftar layanan';

  @override
  String get serviceDetailsUnavailable =>
      'Beberapa detail layanan tidak tersedia';

  @override
  String get serviceDetailsUnavailableTip =>
      'Daftar layanan dapat digunakan, tetapi pengelola tidak memberikan semua informasi status atau mulai otomatis.';

  @override
  String get systemdUserScopeMissing => 'Unit pengguna tidak ditampilkan';

  @override
  String get systemdUserScopeMissingTip =>
      'Akun ini tidak memiliki bus sesi pengguna di server, jadi hanya unit sistem yang ditampilkan.';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unit lainnya',
      one: '1 unit lainnya',
    );
    return '$_temp0';
  }

  @override
  String get serviceUnit => 'Unit';

  @override
  String get serviceUnitType => 'Type';

  @override
  String get serviceScope => 'Scope';

  @override
  String get serviceStartup => 'Startup';

  @override
  String serviceUpFor(String duration) {
    return 'up $duration';
  }

  @override
  String serviceDownFor(String duration) {
    return 'down $duration';
  }

  @override
  String serviceNextIn(String duration) {
    return 'next $duration';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return 'Berhenti $duration lalu';
  }

  @override
  String serviceExitStatus(int code) {
    return 'status keluar $code';
  }

  @override
  String get serviceFullJournal => 'Full journal';

  @override
  String get serviceUnitFile => 'Unit file';

  @override
  String serviceJournalRecent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count baris terakhir',
      one: 'Baris terakhir',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable => 'Akun ini tidak dapat membaca journal';

  @override
  String get serverUnreachable =>
      'Tidak dapat menjalankan perintah di server ini';

  @override
  String get containerNoRuntime => 'Tidak ada runtime kontainer di sini';

  @override
  String get containerNoRuntimeTip =>
      'Baik `docker` maupun `podman` tidak merespons di mesin ini. Jika salah satunya terpasang untuk akun lain, aktifkan \"Cobalah menggunakan sudo\" di Pengaturan.';

  @override
  String get containerUnreadable =>
      'Runtime kontainer merespons dalam bentuk yang tidak terduga';

  @override
  String get power => 'Daya';

  @override
  String get fan => 'Kipas';

  @override
  String get clockSpeed => 'Clock';

  @override
  String get vendor => 'Vendor';

  @override
  String get continueInTerminal => 'Lanjutkan di terminal';

  @override
  String get askAiRiskUnknown => 'Tidak terklasifikasi';

  @override
  String get agentLocalExec => 'Jalankan perintah di perangkat ini';

  @override
  String get agentLocalExecTip =>
      'Membiarkan Agent bekerja di mesin yang menjalankan ServerBox. Perintah hanya-baca pun ditinjau';

  @override
  String get agentLocalExecRootfsTip =>
      'Membiarkan Agent bekerja lokal, terbatas pada kontainer Linux yang dipasang ServerBox';

  @override
  String macDmgImportedPartly(String path) {
    return 'Data dari versi yang terpasang sebelumnya telah diimpor. Berkas unduhan tetap berada di $path.';
  }

  @override
  String get bmcAccount => 'Akun';

  @override
  String get bmcAccountUnset =>
      'Belum dipilih — ketuk untuk memilih atau membuat';

  @override
  String bmcAccountShared(int count) {
    return 'Dipakai oleh $count server';
  }

  @override
  String get bmcAccounts => 'Akun BMC';

  @override
  String get bmcAccountSharedTip =>
      'Mengubahnya mengubah yang dipakai semuanya.';

  @override
  String bmcAccountInUse(int count) {
    return '$count server memakainya. Alamatnya tetap, akunnya hilang.';
  }

  @override
  String get bmcStaleWrite => 'BMC berubah saat proses tulis. Coba lagi.';

  @override
  String get privacyBlur => 'Privasi latar belakang';

  @override
  String get privacyBlurTip =>
      'Sembunyikan konten aplikasi di pengalih aplikasi';

  @override
  String get floatReturnToTab => 'Kembalikan ke tab';

  @override
  String get termInFloatWindow => 'Terminal ini ada di jendela mengambang';

  @override
  String get globeEnabledTip =>
      'Gambar server di bola dunia, di tempat alamatnya berada. Mati akan menghapus tombolnya dan menghentikan semua pencarian.';

  @override
  String get geoShardsConsentAttribution =>
      'Geolokasi IP oleh [DB-IP](https://db-ip.com), CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Alamat privat';

  @override
  String get geoMissNoData => 'Tidak ada data lokasi';

  @override
  String get globeGuide =>
      'Ketuk di sini untuk melihat server pada bola dunia, di lokasi alamatnya.';

  @override
  String get publicIp => 'IP publik';

  @override
  String get geoData => 'Data tingkat kota';

  @override
  String get geoDataTip =>
      'Setelah diunduh, semua pencarian lokasi menggunakan data yang tersimpan di perangkat ini. Alamat server dan aktivitas pencarian tidak dikirim ke layanan unduhan.';

  @override
  String get geoDataMissing => 'Belum diunduh';

  @override
  String get geoDataUnreachable => 'Tidak dapat mengambil data.';

  @override
  String get geoDataRemoveFailed => 'Tidak dapat menghapus data.';

  @override
  String geoDataCurrent(String month) {
    return '$month sudah terpasang.';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**Unduhan: $download · Penyimpanan di perangkat: $disk.** Seluruh kumpulan data disimpan di perangkat ini dan semua pencarian lokasi berikutnya dilakukan secara lokal. Alamat server dan aktivitas pencarian tidak dikirim ke layanan unduhan.\n\nDiperbarui setiap bulan. Versi yang lebih baru menggantikan data yang terpasang tanpa menyimpan salinan tambahan. Anda dapat menghapusnya kapan saja.';
  }

  @override
  String get benchmark => 'Uji performa';

  @override
  String get benchmarkIntro =>
      'Menjalankan Yet Another Bench Script di server ini untuk menguji disk, jaringan, dan CPU. Pengujian lengkap memerlukan 10–20 menit dan tetap berjalan jika Anda meninggalkan halaman ini atau menutup aplikasi.';

  @override
  String get benchmarkNoRuns => 'Belum ada uji performa.';

  @override
  String get benchmarkRunning => 'Uji performa sedang berjalan';

  @override
  String get benchmarkStartFailed => 'Tidak dapat memulai uji performa';

  @override
  String get benchmarkCancelConfirm =>
      'Hentikan pengujian ini? Semua hasil pengukuran sejauh ini akan hilang.';

  @override
  String get benchmarkDeleteConfirm => 'Hapus hasil pengujian ini?';

  @override
  String get benchmarkNothingSelected =>
      'Semua tahap dinonaktifkan. Pengujian hanya akan mengumpulkan informasi sistem dan selesai dalam beberapa detik.';

  @override
  String get benchmarkDiskTip =>
      'fio dengan empat ukuran blok; sekitar 3 menit. Menulis file uji 2 GB ke direktori kerja dan memerlukan ruang kosong sebesar itu.';

  @override
  String get benchmarkNetworkTip =>
      'iperf3 terhadap server publik; sekitar 4 menit.';

  @override
  String get benchmarkReducedNetwork => 'Lebih sedikit lokasi';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Tiga lokasi, bukan tujuh. Perkiraan lalu lintas berkurang dari $full menjadi $reduced.';
  }

  @override
  String get benchmarkCpuTip =>
      'Mengunduh Geekbench, program berpemilik, lalu **menerbitkan hasilnya pada halaman publik di geekbench.com**, termasuk model CPU, jumlah inti, dan memori.';

  @override
  String get benchmarkSensitiveOptions =>
      'Opsi di bawah mengunduh dan menjalankan perangkat lunak pihak ketiga di server ini atau mengirim informasi server kepada pihak ketiga. Opsi ini dinonaktifkan secara default.';

  @override
  String get benchmarkIpInfoTip =>
      'Mengirim alamat publik server ini ke ip-api.com melalui HTTP tanpa enkripsi.';

  @override
  String get benchmarkIpInfo => 'Cari pemilik IP';

  @override
  String get benchmarkPreferBin => 'Unduh fio dan iperf3';

  @override
  String get benchmarkPreferBinTip =>
      'Mengunduh keduanya dari GitHub alih-alih menggunakan paket milik host. Aktifkan hanya jika keduanya tidak terpasang di host.';

  @override
  String get benchmarkWorkDir => 'Direktori kerja';

  @override
  String get benchmarkWorkDirTip =>
      'Menentukan sistem file yang diukur oleh pengujian disk. Jika kosong, direktori home akun masuk akan digunakan.';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return 'Sekitar $minutes menit';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Sekitar $size lalu lintas';
  }

  @override
  String get benchmarkPhaseSystem => 'Membaca informasi sistem';

  @override
  String get benchmarkPhaseDisk => 'Menguji disk';

  @override
  String get benchmarkPhaseNetwork => 'Menguji jaringan';

  @override
  String get benchmarkPhaseCpu => 'Menguji CPU';

  @override
  String get benchmarkPhaseDone => 'Menyelesaikan';

  @override
  String get benchmarkResultUnreadable =>
      'Hasil ini tidak dapat dibaca sebagai JSON. Teks mentah ditampilkan di bawah.';

  @override
  String get benchmarkViewOnGeekbench => 'Lihat di Geekbench';

  @override
  String get benchmarkGeekbenchPublic =>
      'Hasil ini dipublikasikan melalui tautan di atas.';

  @override
  String get benchmarkSingleCore => 'Inti tunggal';

  @override
  String get benchmarkMultiCore => 'Multi-inti';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Unggah';

  @override
  String get benchmarkRecv => 'Unduh';

  @override
  String get benchmarkLatency => 'Latensi';

  @override
  String get benchmarkVirt => 'Virtualisasi';

  @override
  String get benchmarkRawLog => 'Log pengujian';

  @override
  String benchmarkUpstream(String version) {
    return 'Didukung oleh Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'Memulai';

  @override
  String get benchmarkNoOutputYet =>
      'Belum ada keluaran. Sebelum menampilkan baris pertama, YABS memeriksa apakah google.com dan icanhazip.com dapat dijangkau. Pada jaringan yang memblokir salah satu situs tersebut, proses ini dapat memerlukan beberapa menit.';

  @override
  String get tagsEmptyTip =>
      'Belum ada tag. Tambahkan tag saat mengedit server, dan tag tersebut akan muncul di sini.';

  @override
  String get benchmarkNoServers =>
      'Tambahkan server terlebih dahulu, lalu kembali untuk menjalankan benchmark.';

  @override
  String get schemaTooNewTitle => 'Data ini lebih baru daripada aplikasi';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Data ini ditulis oleh versi ServerBox yang lebih baru (penyimpanan v$stored); versi ini hanya dapat membaca hingga v$supported. Tidak ada yang diubah.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Instal kembali versi yang lebih baru itu agar semua data dapat dibuka seperti semula.';

  @override
  String get schemaTooNewExportPlain => 'Ekspor tanpa kata sandi';

  @override
  String get schemaTooNewPlainWarn =>
      'File ini akan menyimpan semua kunci privat SSH, kata sandi server, dan kunci API dalam teks biasa. Siapa pun yang mendapatkan file ini akan mendapatkan semuanya.';

  @override
  String get schemaTooNewWipe => 'Hapus semua data';

  @override
  String get schemaTooNewWipeConfirm =>
      'Semua server, kunci, cuplikan, dan pengaturan di perangkat ini akan dihapus dan tidak dapat dibatalkan. Cadangan yang diekspor di sini akan menjadi satu-satunya salinan yang tersisa.';

  @override
  String get schemaTooNewWipeDone =>
      'Data dihapus. Buka kembali aplikasi untuk memulai dari awal.';

  @override
  String get schemaTooNewWipeFailed =>
      'Sebagian data tidak dapat dihapus, dan versi ini masih tidak dapat membuka data yang tersisa. Instal kembali versi yang lebih baru untuk mengaksesnya.';

  @override
  String get systemUsers => 'Users';

  @override
  String get userManagerLinuxOnly =>
      'Pengelolaan pengguna sistem saat ini hanya mendukung server Linux.';

  @override
  String get userRegularAccount => 'Regular';

  @override
  String get userCurrentAccount => 'Current account';

  @override
  String get userSystemAccount => 'System account';

  @override
  String get userUid => 'UID';

  @override
  String get userLoginStatus => 'Status';

  @override
  String get userLoginEnabled => 'Login enabled';

  @override
  String get userDetailAccount => 'Account';

  @override
  String get userDetailSecurity => 'Security';

  @override
  String get userSshKeys => 'SSH keys';

  @override
  String get userExpires => 'Expires';

  @override
  String get userNever => 'Never';

  @override
  String get userPasswordSet => 'Set';

  @override
  String get userPasswordLocked => 'Locked';

  @override
  String get userPasswordNone => 'None';

  @override
  String get userSuperuser => 'Superuser';

  @override
  String get userOpenShell => 'Open shell';

  @override
  String get userRootChangesWarning =>
      'Perubahan pada root langsung berlaku di semua sesi.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Grup tambahan';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Buat direktori home';

  @override
  String get userMoveHome =>
      'Pindahkan direktori home yang ada saat path berubah';

  @override
  String get userRemoveHome => 'Hapus direktori home';

  @override
  String get userPasswordCreateTip =>
      'Kosongkan kata sandi untuk membuat akun yang tidak dapat masuk dengan kata sandi.';

  @override
  String get userPasswordEditTip =>
      'Kosongkan kata sandi untuk mempertahankan kata sandi yang ada.';

  @override
  String funcUnavailableFmt(String func) {
    return '$func tidak tersedia melalui koneksi server ini.';
  }

  @override
  String get rangeLive => 'Langsung';

  @override
  String get diskIo => 'I/O Disk';

  @override
  String get peak => 'puncak';

  @override
  String get hardware => 'Perangkat keras';

  @override
  String get cores => 'Inti';

  @override
  String get historyNoStored =>
      'Hanya agen monitor yang menyimpan riwayat. Koneksi ini hanya menyimpan apa yang dilihat aplikasi sejak terhubung.';

  @override
  String get noHistoryYet => 'Belum ada pengukuran';

  @override
  String get noData => 'tidak ada data';

  @override
  String get from => 'Dari';

  @override
  String get to => 'Sampai';

  @override
  String get beyondRetention => 'lebih lama dari yang disimpan agen ini';

  @override
  String agentRetentionFmt(String kept) {
    return 'Agen menyimpan $kept';
  }

  @override
  String get agentServerTools => 'Alat server';

  @override
  String get agentServerToolsTip =>
      'Menjalankan perintah serta membaca atau menulis berkas di server Anda, terhubung ke host lain lewat SSH, dan memakai tindakan ServerBox sendiri.';

  @override
  String get agentTerminalTools => 'Terminal';

  @override
  String get agentTerminalToolsTip =>
      'Di obrolan milik terminal: membaca apa yang ditampilkan terminal dan menjalankan perintah di servernya.';

  @override
  String get agentToolTerminalScreen => 'Baca layar';

  @override
  String get agentProviders => 'Penyedia';

  @override
  String get agentProvidersTip =>
      'Kunci API, model, dan model untuk obrolan baru';

  @override
  String get agentTools => 'Alat';

  @override
  String get agentToolsTip =>
      'Apa yang boleh dipakai Agent, dan server MCP-nya';

  @override
  String get agentSnippetToolsTip =>
      'Menampilkan, menambah, mengubah, dan menghapus snippet. Perubahan akan ditanyakan.';

  @override
  String get agentVirtToolsTip =>
      'Membaca VM dan kontainer yang dimuat tab Virtualisasi.';

  @override
  String get agentBenchmarkToolsTip =>
      'Membaca hasil benchmark; menjalankan atau menghentikan benchmark dengan persetujuanmu.';

  @override
  String get agentRemoteDesktopToolsTip =>
      'Menampilkan profil remote desktop; menghubungkan atau memutus dengan persetujuanmu.';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentSkillsTip =>
      'Petunjuk untuk tugas tertentu, dipasang dari GitHub atau tautan';

  @override
  String get agentPermissions => 'Izin';

  @override
  String get agentEmptyHint =>
      'Tanyakan tentang server Anda, atau minta Agent melakukan sesuatu di sana.';

  @override
  String get agentTerminalEmptyHint =>
      'Tanyakan tentang server ini. Agent dapat membaca terminal ini dan menjalankan perintah di sini.';

  @override
  String oldestSampleFmt(String time) {
    return 'sampel terlama $time';
  }

  @override
  String get rangeEndsBeforeItStarts => 'Akhir rentang harus setelah awalnya.';

  @override
  String get samples => 'sampel';

  @override
  String get unavailable => 'tidak tersedia';

  @override
  String get metricUnavailableTip =>
      'Bagian lain halaman ini tidak terpengaruh. Periksa perintah sumber pembacaan ini di host.';

  @override
  String get waitingFirstSample => 'Menunggu sampel pertama';

  @override
  String atTimeFmt(String time) {
    return 'pukul $time';
  }

  @override
  String get stored => 'tersimpan';

  @override
  String lastSampleFmt(String ago) {
    return 'sampel terakhir $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Semua di bawah ini berasal dari $time, $ago.';
  }

  @override
  String noDataBeforeFmt(String time) {
    return 'tidak ada data sebelum $time';
  }

  @override
  String loadingRangeFmt(String range) {
    return 'Memuat $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return 'Tidak ada riwayat tersimpan untuk $metric';
  }

  @override
  String devicesFmt(int count) {
    return '$count perangkat';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count perangkat · $name tersibuk';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$plotted dari $total perangkat';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count sensor · $name paling panas';
  }

  @override
  String get oneDeviceAtLeast =>
      'Setidaknya satu perangkat tetap ada di grafik.';

  @override
  String showAllFmt(int count) {
    return 'Tampilkan semua $count';
  }

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$shown dari $total $what';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count $what';
  }

  @override
  String get unitDevices => 'perangkat';

  @override
  String get unitSensors => 'sensor';

  @override
  String get unitBatteries => 'baterai';

  @override
  String get unitCommands => 'perintah';

  @override
  String get unitReadings => 'pembacaan';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => 'paling panas';

  @override
  String get oldest => 'paling lama';

  @override
  String get notApplicable => 'tidak berlaku';

  @override
  String get attributes => 'atribut';

  @override
  String get powerOnHours => 'Jam menyala';

  @override
  String get powerCycles => 'Siklus daya';

  @override
  String get lifeLeft => 'Sisa umur';

  @override
  String get lifetimeWrite => 'Total tulis';

  @override
  String get lifetimeRead => 'Total baca';

  @override
  String get averageErase => 'Rata-rata hapus';

  @override
  String get unsafeShutdowns => 'Mati tidak aman';

  @override
  String get diskAllPassed => 'semua PASSED';

  @override
  String diskWarningFmt(int count) {
    return '$count peringatan';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$wrong dari $total perangkat';
  }

  @override
  String get diskSmartSortedTip => 'Terburuk lebih dulu';

  @override
  String readAgoFmt(String ago) {
    return 'dibaca $ago';
  }

  @override
  String processesFmt(int count) {
    return '$count proses';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count bermasalah';
  }

  @override
  String get diskSmartOpenTip => 'Ketuk untuk melihat atributnya';

  @override
  String get cycle => 'Siklus';

  @override
  String get window => 'jendela';

  @override
  String ofFmt(String total) {
    return 'dari $total';
  }

  @override
  String get serverDetailCards => 'Kartu halaman detail';

  @override
  String get connection => 'Koneksi';

  @override
  String get connectionTip =>
      'Keduanya bisa aktif bersamaan. Urutannya adalah urutan pemanggilan.';

  @override
  String get transportNoneOn =>
      'Keduanya nonaktif — server ini tidak dapat dihubungi.';

  @override
  String get thisDevice => 'Perangkat ini';

  @override
  String get localServerTip =>
      'Membaca perangkat ini secara langsung dengan menjalankan skrip status di sini. SSH dan agen monitor tidak digunakan, dan pengaturannya tetap disimpan.';

  @override
  String get localServerUnsupported =>
      'Platform ini tidak dapat membaca perangkat ini sebagai server. Linux, Windows, dan versi DMG macOS mendukungnya.';

  @override
  String get remoteDesktopIntro =>
      'Buka desktop RDP atau VNC sebuah server di dalam aplikasi. Koneksi melewati koneksi SSH server atau agen Monitor-nya, jadi port desktop tidak perlu dapat dijangkau dari jaringan.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Simpan satu profil per desktop dari tombol Desktop jarak jauh pada server, atau dari tab Desktop jarak jauh.';

  @override
  String get localServerIntro =>
      'Tambahkan perangkat yang menjalankan ServerBox sebagai server. Status, proses, layanan, kontainer, terminal, dan berkas berfungsi tanpa SSH atau agen Monitor.';

  @override
  String get localServerAdd => 'Tambahkan perangkat ini';

  @override
  String get localServerIntroFooter =>
      'Ini juga bisa diaktifkan nanti, di halaman edit server pada bagian Koneksi.';

  @override
  String get transportSectionOff =>
      'Nonaktif. Kolom di bawah disimpan untuk saat Anda mengaktifkannya lagi.';

  @override
  String get monitorAgent => 'Agen monitor';

  @override
  String get plainHttpEditTip =>
      'Kredensial dan metrik melintasi jaringan tanpa enkripsi. Batasi pada LAN atau alamat Tailscale, atau tempatkan agen di belakang TLS.';

  @override
  String get behaviour => 'Perilaku';

  @override
  String get optional => 'Opsional';

  @override
  String get sshAdvanced => 'SSH lanjutan';

  @override
  String get sshAdvancedTip =>
      'Tujuan cadangan, ProxyCommand, server lompat, transport berkas, jalur jarak jauh';

  @override
  String get sshLegacyAlgorithms => 'Algoritma lama';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Untuk server SSH lama, seperti router atau switch, yang hanya menawarkan kunci host SHA-1 `ssh-rsa` atau pertukaran kunci SHA-1. Keamanannya lebih rendah; aktifkan hanya untuk host yang memerlukannya.';

  @override
  String get appearanceAndPlace => 'Tampilan & lokasi';

  @override
  String get appearanceAndPlaceTip => 'Logo, koordinat';

  @override
  String get statusCollection => 'Pengumpulan status';

  @override
  String get statusCollectionTip =>
      'Perintah mana yang berjalan, perintah kustom, perangkat mana yang dibaca';

  @override
  String get tagAllTags => 'Semua tag';

  @override
  String get tagMatching => 'Cocok';

  @override
  String get tagNewHint => 'Tag baru';

  @override
  String tagCreateFmt(String tag) {
    return 'Buat #$tag';
  }

  @override
  String get tagOnThisServer => 'di server ini';

  @override
  String tagServersFmt(int count) {
    return '$count server';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '$count di server ini';
  }

  @override
  String get tagMatchesTyped => 'cocok dengan yang Anda ketik';

  @override
  String get tagEditorTip =>
      'Mengetik akan menyaring daftar; tombolnya membuat tag dan langsung memasangnya di server ini. Pensil mengganti namanya di setiap server yang memakainya. Tag yang tidak dipakai server mana pun akan hilang saat disimpan.';

  @override
  String get tagRenamesOnSave => 'Penggantian nama diterapkan saat menyimpan';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'Pengelolaan tugas terjadwal saat ini hanya mendukung server Linux.';

  @override
  String get scheduledTaskUnavailable =>
      'crontab tidak tersedia di server ini.';

  @override
  String get scheduledTaskPreserveTip =>
      'Komentar, environment variable, dan baris yang tidak dikenali dalam crontab ini akan dipertahankan.';

  @override
  String get scheduledTaskSchedule => 'Schedule';

  @override
  String get scheduledTaskAdd => 'Add task';

  @override
  String get scheduledTaskNextRun => 'Next run';

  @override
  String scheduledTaskNextInFmt(String time) {
    return 'in $time';
  }

  @override
  String get scheduledTaskEnabled => 'Enabled';

  @override
  String get scheduledTaskCommentedOut => 'Commented out';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
    return '$total tugas · $enabled aktif';
  }

  @override
  String get scheduledTaskFilterHint => 'Filter tasks';

  @override
  String get scheduledTaskPreserved => 'Preserved lines';

  @override
  String get scheduledTaskRaw => 'Raw crontab';

  @override
  String get scheduledTaskEnableNow => 'Enable now';

  @override
  String get scheduledTaskEnableNowTip =>
      'Jika dimatikan, baris akan ditulis sebagai komentar.';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return 'Tidak ada tugas terjadwal untuk $user. Yang ditambahkan di sini akan ditulis ke crontab akun tersebut.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'Tanggal dalam bulan';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'Hari dalam minggu';

  @override
  String get cronErrScheduleEmpty => 'Jadwal wajib diisi.';

  @override
  String get cronErrCommandEmpty => 'Perintah wajib diisi.';

  @override
  String get cronErrLineBreak =>
      'Baris crontab tidak boleh berisi pergantian baris.';

  @override
  String get cronErrMacro => 'Macro terdiri dari satu kata, seperti @reboot.';

  @override
  String get cronErrFieldCount =>
      'Jadwal cron memiliki lima kolom, atau macro seperti @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(int minutes) {
    return 'Setiap $minutes menit';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'Setiap jam pada menit :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'Setiap $hours jam';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'Setiap $hours jam pada menit :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Setiap hari pukul $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'Pada hari kerja pukul $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Setiap $day pukul $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return 'Tanggal $day setiap bulan pukul $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart => 'Berlaku setelah agent dimulai ulang';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Interval siklus lanjutan';

  @override
  String get idlePause => 'Jeda saat tidak ada yang memantau';

  @override
  String get idlePauseTip =>
      'Siklus lanjutan menjalankan smartctl, sensors, dan amd-smi. Menjedanya saat tidak ada client yang meminta data mencegah disk dibangunkan untuk data yang tidak dibaca siapa pun.';

  @override
  String get idlePauseThreshold => 'Idle after';

  @override
  String get monitorAlerts => 'Alerts';

  @override
  String get monitoringRules => 'Alert rules';

  @override
  String get ruleMonitorType => 'Metric';

  @override
  String get ruleThreshold => 'Threshold';

  @override
  String get ruleMatcher => 'Matcher';

  @override
  String get ruleTip =>
      'Metrik: cpu / memory / swap / disk / network / temperature. Pencocok: cpu0 untuk satu core, used / free / avail untuk memori, rx / tx untuk jaringan; disk dan suhu mengabaikannya. Ambang: operator pembanding dan nilai, seperti >=80%, >=70c, atau >10m/s.';

  @override
  String get pushChannels => 'Saluran notifikasi';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Ditetapkan di agent, tidak ditampilkan';

  @override
  String get pushSecretKeep => 'Kosongkan untuk mempertahankan';

  @override
  String get pushTestTip =>
      'Mengirim satu notifikasi melalui channel ini dengan pengaturan saat ini, baik sudah disimpan maupun belum.';

  @override
  String get pushTestSent => 'Channel menerima notifikasi';

  @override
  String get pushTestFailed => 'Channel menolak notifikasi';

  @override
  String get pushTestMessage => 'Notifikasi uji dari ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'Agent ini tidak memiliki pengirim untuk jenis channel ini, sehingga pengaturannya tidak ditampilkan. Channel dapat dihapus di sini atau diedit dalam config.toml agent.';

  @override
  String get pushJsonInvalid => 'bukan JSON yang valid';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Jika dimatikan, agent tidak pernah menghapus data dan database akan terus membesar tanpa batas.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Jalankan pembersihan setiap';

  @override
  String get retentionMaxDbSize => 'Batas ukuran database';

  @override
  String get corsOrigins => 'Origin CORS yang diizinkan';

  @override
  String get corsOriginsTip =>
      'Origin yang boleh digunakan panel browser untuk memanggil agent ini. Kosong berarti hanya same-origin.';

  @override
  String get monitorNoRemoteAccess =>
      'Agen ini menolak semua hal selain pemantauan melalui HTTP tanpa enkripsi. Hubungkan melalui HTTPS, atau izinkan HTTP di agen ([remote_access] allow_insecure) dan di aplikasi ini.';

  @override
  String get monitorAgentTooOld =>
      'Agen Monitor ini lebih lama dari yang didukung versi ServerBox ini. Perbarui agen di server.';

  @override
  String get monitorClientTooOld =>
      'Agen Monitor ini tidak lagi mendukung versi ServerBox ini. Perbarui aplikasi.';

  @override
  String get alerts => 'Peringatan';

  @override
  String get online => 'online';

  @override
  String get densityCards => 'Kartu';

  @override
  String get densityRows => 'Baris';

  @override
  String get densityGrid => 'Kisi';

  @override
  String get connect => 'Hubungkan';

  @override
  String get disconnect => 'Putuskan';

  @override
  String get searchServerTip =>
      'Mencari nama dan alamat — dua hal yang pertama kali diminta editor.';

  @override
  String get addServerTip =>
      'Isi salah satunya, pindai kode QR, atau impor file yang dibagikan seseorang.';

  @override
  String get move => 'Pindahkan';

  @override
  String get moveToTop => 'Pindah ke atas';

  @override
  String get moveToBottom => 'Pindah ke bawah';

  @override
  String get groupByTag => 'Kelompokkan menurut tag';

  @override
  String get groupByTagTip => 'Tag diatur di halaman edit server.';

  @override
  String get connecting => 'Menghubungkan…';

  @override
  String get authShort => 'Auth';

  @override
  String get remoteDesktopFitToWindow => 'Sesuaikan dengan jendela';

  @override
  String get remoteDesktopActualSize => 'Ukuran sebenarnya';

  @override
  String get remoteDesktopZoom => 'Perbesar/perkecil';

  @override
  String get remoteDesktopViewOnly => 'Hanya lihat';

  @override
  String get remoteDesktopDisableViewOnly => 'Nonaktifkan hanya lihat';

  @override
  String get remoteDesktopSendClipboardText => 'Kirim teks papan klip';

  @override
  String get remoteDesktopShowKeyboard => 'Tampilkan keyboard';

  @override
  String get remoteDesktopMoreControls => 'Kontrol lainnya';

  @override
  String get remoteDesktopUseDirectPointer => 'Gunakan penunjuk langsung';

  @override
  String get remoteDesktopUseTouchpadPointer => 'Gunakan penunjuk touchpad';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Kirim Ctrl+Alt+Delete';

  @override
  String get remoteDesktopReconnect => 'Hubungkan kembali';

  @override
  String get remoteDesktopFullScreen => 'Layar penuh';

  @override
  String get remoteDesktopExitFullScreen => 'Keluar dari layar penuh';

  @override
  String get remoteDesktopCloseSession => 'Tutup sesi';

  @override
  String get remoteDesktopConnected => 'Terhubung';

  @override
  String get remoteDesktopConnecting => 'Menghubungkan';

  @override
  String get remoteDesktopReconnecting => 'Menghubungkan kembali';

  @override
  String get remoteDesktopDisconnected => 'Terputus';

  @override
  String get remoteDesktopGuideTouch => 'Touchpad';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Satu jari menggerakkan penunjuk seperti touchpad, dan ketukan mengeklik. Ketuk dengan dua jari untuk klik kanan, seret dengan dua jari untuk menggulir, dan cubit untuk memperbesar. Ketuk dua kali dan tahan jari untuk menyeret.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Membuka keyboard layar. Yang Anda ketik dikirim ke desktop jarak jauh.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Berhenti mengirim penunjuk dan tombol, sehingga Anda bisa melihat tanpa tidak sengaja mengeklik.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Ctrl+Alt+Delete, sambung ulang, dan layar penuh ada di sini.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'Begitu juga penunjuk langsung, di mana jari mengeklik tempat yang disentuhnya.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'Clipboard VNC hanya mendukung teks Latin-1.';

  @override
  String get remoteDesktopAddProfile => 'Tambah profil';

  @override
  String get remoteDesktopNoProfiles => 'Tidak ada profil desktop jarak jauh';

  @override
  String get remoteDesktopAdd => 'Tambah desktop jarak jauh';

  @override
  String get remoteDesktopEdit => 'Edit desktop jarak jauh';

  @override
  String get remoteDesktopTargetTip =>
      'Target diresolusikan dari server SSH atau agen Monitor. localhost mengacu pada mesin itu.';

  @override
  String get remoteDesktopDomain => 'Domain (opsional)';

  @override
  String get remoteDesktopPassword => 'Kata sandi (opsional)';

  @override
  String get remoteDesktopSavePassword => 'Simpan kata sandi';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Disimpan di basis data terenkripsi. Cadangan menyertakan kata sandi tersimpan, dan hanya dienkripsi bila kata sandi cadangan ditetapkan.';

  @override
  String get remoteDesktopShareSession => 'Bagikan sesi';

  @override
  String get remoteDesktopProtocol => 'Protokol';

  @override
  String get remoteDesktopUniqueName =>
      'Nama profil harus unik untuk server ini.';

  @override
  String get remoteDesktopNameRequired => 'Masukkan nama profil.';

  @override
  String get remoteDesktopHostRequired => 'Masukkan host target.';

  @override
  String get remoteDesktopPortRequired => 'Masukkan port yang valid.';

  @override
  String get remoteDesktopUsernameRequired => 'Masukkan nama pengguna RDP.';

  @override
  String get remoteDesktopNameInvalid =>
      'Nama profil paling banyak 64 karakter dan tidak boleh berisi baris baru.';

  @override
  String get remoteDesktopHostInvalid =>
      'Host tujuan tidak boleh berisi spasi atau baris baru.';

  @override
  String get remoteDesktopCredentialInvalid =>
      'Nama pengguna dan domain paling banyak 256 karakter dan tidak boleh berisi baris baru.';

  @override
  String get remoteDesktopVncPasswordHint =>
      'VNC klasik hanya menggunakan 8 karakter pertama';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Kata sandi VNC klasik hanya boleh berisi karakter ASCII.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Konfirmasi sertifikat diperlukan';

  @override
  String get remoteDesktopWaiting => 'Menunggu desktop…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Sertifikat desktop jarak jauh berubah';

  @override
  String get remoteDesktopTrustCertificate => 'Percayai sertifikat?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'Sidik jari sertifikat tidak lagi cocok dengan nilai tersimpan. Verifikasi sidik jari baru sebelum mengganti kepercayaan.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'Sistem tidak dapat memverifikasi sertifikat ini. Verifikasi sidik jari SHA-256-nya sebelum melanjutkan.';

  @override
  String get remoteDesktopReplaceTrust => 'Ganti kepercayaan';

  @override
  String get remoteDesktopTrustReconnect => 'Percayai dan sambungkan ulang';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'Hapus profil desktop jarak jauh “$name”?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Menghubungkan kembali ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Sebelumnya dipercaya\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Subjek: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Penerbit: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Berlaku: $start – $end';
  }

  @override
  String get pveAuthToken => 'Token API';

  @override
  String get pveVersionLow =>
      'Fitur ini saat ini sedang dalam tahap pengujian dan hanya diuji pada PVE 8+. Gunakan dengan hati-hati.';

  @override
  String get pveTokenId => 'ID token';

  @override
  String get pveTokenSecret => 'Rahasia token';

  @override
  String get pveTokenTip =>
      'Buat di PVE pada Datacenter → Permissions → API Tokens. Token memerlukan VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit, dan Sys.Audit pada jalur yang ingin ditampilkan; jika pemisahan hak aktif, berikan hak tersebut ke token itu sendiri.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'Token $account tidak dapat melihat apa pun di host ini. Token dengan pemisahan hak akses tidak mewarisi izin penggunanya; berikan izin di host PVE:\n$command\natau hapus centang \"Privilege Separation\" pada token.';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account tidak dapat melihat apa pun di host ini. Berikan izin di host PVE:\n$command';
  }

  @override
  String get pveTokenIdInvalid => 'ID token harus berbentuk user@realm!tokenid';

  @override
  String get pvePasswordAuthTip =>
      'Masuk sebagai pengguna SSH di realm PAM, dengan kata sandi SSH, atau dengan kata sandi PVE di bawah jika SSH memakai kunci. Kode dua faktor diminta bila diperlukan.';

  @override
  String get pveCertUnpinned =>
      'Belum ada yang dikonfirmasi. Kecuali ditandatangani CA tepercaya, koneksi berikutnya menampilkan sertifikat untuk dikonfirmasi.';

  @override
  String get pveCertForget => 'Lupakan sertifikat';

  @override
  String get pveCertForgetTip =>
      'Koneksi berikutnya akan menampilkan sertifikat PVE lagi untuk dikonfirmasi.';

  @override
  String get virtualization => 'Virtualisasi';

  @override
  String get virtIntro =>
      'Kelola mesin virtual dan kontainer di host Proxmox VE dan libvirt/KVM: status, aksi daya, dan konsol.';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE telah pindah dari halaman server ke tab ini. Kartu PVE sebuah server membukanya di sini.';

  @override
  String get virtIntroLibvirt =>
      'Server dengan virsh dari libvirt terpasang muncul sebagai host, beserta mesin virtual QEMU/KVM-nya.';

  @override
  String get virtIntroTransports =>
      'Keduanya bekerja lewat SSH, melalui agen Monitor, atau di perangkat ini.';

  @override
  String get virtIntroTokens =>
      'PVE dapat masuk dengan token API alih-alih kata sandi. Atur di halaman edit server, pada bagian PVE.';

  @override
  String get virtIntroInBar => 'Tab ini telah ditambahkan ke bilah tab.';

  @override
  String get virtIntroInMore =>
      'Tab ini ada di Lainnya. Tab Beranda di Pengaturan dapat memindahkannya ke bilah tab.';

  @override
  String get virtGuests => 'Mesin virtual';

  @override
  String get virtHosts => 'Host';

  @override
  String get virtCheckServer => 'Periksa server ini';

  @override
  String get virtCheckAll => 'Periksa semua server';

  @override
  String get virtProbeNotChecked => 'Belum diperiksa';

  @override
  String get virtProbeAbsent => 'Bukan host';

  @override
  String virtProbeContainer(String kind) {
    return 'Kontainer $kind';
  }

  @override
  String get virtProbeContainerTip =>
      'Server ini berjalan di dalam kontainer, jadi merupakan tamu, bukan host. Kelola dari host yang menjalankannya.';

  @override
  String get virtProbePve => 'PVE, belum disiapkan';

  @override
  String virtPveSetupTip(String version) {
    return '$version berjalan di server ini. Isi akses API-nya di pengaturan server (disarankan token API) untuk mengelola mesin virtual dan kontainernya di sini.';
  }

  @override
  String get virtNoHosts => 'Tidak ada host virtualisasi';

  @override
  String get virtNoHostsTip =>
      'Server yang menjalankan Proxmox VE dengan akses API terisi adalah host, begitu juga server tempat virsh merespons. Server lainnya dapat diperiksa dari pengalih host.';

  @override
  String get virtNoGuests => 'Tidak ada mesin virtual atau kontainer';

  @override
  String get virtPaused => 'Dijeda';

  @override
  String get virtStarting => 'Memulai…';

  @override
  String get virtStopping => 'Menghentikan…';

  @override
  String get virtRebooting => 'Memulai ulang…';

  @override
  String get virtMigrating => 'Memigrasi…';

  @override
  String get virtBackingUp => 'Mencadangkan…';

  @override
  String get virtResume => 'Lanjutkan';

  @override
  String get virtOverview => 'Ikhtisar';

  @override
  String get virtConsole => 'Konsol';

  @override
  String get virtConsoleNone =>
      'Tidak ada konsol yang dikonfigurasi untuk tamu ini';

  @override
  String get virtConsoleGraphical => 'Grafis';

  @override
  String get virtVncPasswordNeeded => 'Tampilan ini meminta kata sandi';

  @override
  String get virtConsoleSerialTip =>
      'Membuka konsol serial tamu dengan virsh di host. Putuskan, atau Ctrl+], kembali ke shell host.';

  @override
  String virtConsoleVia(String transport) {
    return 'melalui $transport';
  }

  @override
  String get virtConsoleEnterTip => 'Tidak ada keluaran? Tekan Enter';

  @override
  String virtConsoleAutoEnter(int seconds) {
    return 'Enter akan ditekan dalam $seconds detik untuk menampilkan prompt';
  }

  @override
  String get virtConsoleEnterNow => 'Sekarang';

  @override
  String get virtOffTip =>
      'Jalankan untuk melihat CPU, memori, disk, dan jaringan secara langsung di sini.';

  @override
  String get virtAllocated => 'Dialokasikan';

  @override
  String virtRunningCount(int running, int total) {
    return '$running berjalan · $total total';
  }

  @override
  String get virtTemplate => 'Templat';

  @override
  String get virtAutostart => 'Mulai bersama host';

  @override
  String get virtErrUnreachable => 'Tidak dapat menjangkau host ini';

  @override
  String get virtErrNotConfigured => 'Pengaturan PVE server ini belum lengkap';

  @override
  String get virtErrNotConfiguredTip =>
      'Periksa alamat, serta kata sandi atau token API, di pengaturan server.';

  @override
  String get virtErrAuthFailed => 'Host menolak login';

  @override
  String get virtErrCertUnconfirmed => 'Konfirmasi sertifikat host';

  @override
  String get virtErrCertChanged => 'Sertifikat host telah berubah';

  @override
  String get virtErrRelayNotGranted => 'Agent Monitor tidak meneruskan koneksi';

  @override
  String get virtErrExecNotGranted =>
      'Agent Monitor tidak menjalankan perintah';

  @override
  String get virtErrNotInstalled => 'virsh tidak terpasang di server ini';

  @override
  String get virtErrServerRemoved => 'Server ini sudah tidak ada';

  @override
  String get virtErrSudoRequired =>
      'sudo memerlukan kata sandi untuk mengakses libvirt';

  @override
  String get virtErrSudoRejected => 'sudo menolak kata sandi';

  @override
  String get virtErrInvalidResponse =>
      'Host menjawab dalam bentuk yang tidak terduga';

  @override
  String get virtErrActionFailed => 'Host menolak tindakan tersebut';

  @override
  String get remoteSessionIdleTimeout => 'Tutup saat ditinggalkan';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'Berapa lama desktop jarak jauh atau konsol tamu tetap terhubung setelah Anda meninggalkannya. Sebelum ditutup, pemberitahuan memberi Anda 10 detik untuk mempertahankannya.';

  @override
  String get remoteSessionKeepAlive => 'Pertahankan';

  @override
  String get remoteSessionClosedAway => 'Ditutup karena tidak aktif';

  @override
  String remoteSessionClosingIn(int seconds) {
    return 'Ditutup dalam $seconds dtk';
  }

  @override
  String get virtSnapshots => 'Snapshot';

  @override
  String get virtSnapshotCreate => 'Ambil snapshot';

  @override
  String get virtSnapshotNone => 'Belum ada snapshot';

  @override
  String get virtSnapshotWithMemory => 'Disk dan memori';

  @override
  String get virtSnapshotDiskOnly => 'Hanya disk';

  @override
  String get virtSnapshotParent => 'Induk';

  @override
  String get virtSnapshotRevert => 'Kembalikan';

  @override
  String get virtSnapshotMemory => 'Sertakan memori';

  @override
  String get virtSnapshotMemoryTip =>
      'Mengembalikan akan melanjutkan guest dari saat ini.';

  @override
  String get virtSnapshotMemoryAlways =>
      'Di sini snapshot guest yang berjalan selalu menyertakan memorinya.';

  @override
  String get virtSnapshotMemoryOff =>
      'Guest tidak berjalan, jadi hanya disknya yang disimpan.';

  @override
  String get virtSnapshotNameInvalid =>
      'Diawali huruf, lalu huruf, angka, - atau _; 2 sampai 40 karakter.';

  @override
  String get virtSnapshotNameTaken => 'Snapshot dengan nama ini sudah ada.';

  @override
  String get virtSnapshotRevertTip =>
      'Mengembalikan akan membuang semua perubahan sejak snapshot.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return 'Kembalikan $guest ke $snapshot? Semua perubahan sejak itu akan hilang.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'Snapshot ini tanpa memori: $guest akan dihentikan.';
  }

  @override
  String get virtSnapshotStartAfter => 'Jalankan setelahnya';

  @override
  String get virtVolumes => 'Volume';

  @override
  String get virtNoPools => 'Tidak ada pool penyimpanan';

  @override
  String get virtNoNetworks => 'Tidak ada jaringan';

  @override
  String get virtPoolInactive =>
      'Pool tidak aktif, jadi volumenya tidak dapat dicantumkan.';

  @override
  String get virtShared => 'Dibagi antar node';

  @override
  String get virtBackingFile => 'Berkas dasar';

  @override
  String get virtNetIsolated => 'Terisolasi';

  @override
  String get virtNetBridged => 'Bridge';

  @override
  String get virtNetRouted => 'Dirutekan';

  @override
  String get virtBridge => 'Bridge';

  @override
  String get virtPorts => 'Port';

  @override
  String get virtAttachedGuests => 'Guest di dalamnya';

  @override
  String get virtNoAttachedGuests => 'Tidak ada guest di dalamnya';

  @override
  String get virtCreateVm => 'Mesin virtual baru';

  @override
  String get virtCreateLxc => 'Kontainer baru';

  @override
  String get virtCreateGuest => 'Mesin virtual atau kontainer baru';

  @override
  String get virtKindVm => 'Mesin virtual';

  @override
  String get virtKindLxc => 'Kontainer';

  @override
  String get virtHostname => 'Nama host';

  @override
  String get virtInstallMedia => 'Media instalasi';

  @override
  String get virtNoIsos => 'Tidak ada image ISO di host ini';

  @override
  String get virtNoTemplates =>
      'Tidak ada templat kontainer di host ini. CT Templates pada sebuah penyimpanan di PVE dapat mengunduhnya.';

  @override
  String get virtNoDiskStorage =>
      'Tidak ada penyimpanan di host ini yang menerima disk baru';

  @override
  String get virtStartAfterCreate => 'Jalankan setelah dibuat';

  @override
  String get virtUnprivileged => 'Kontainer tanpa hak istimewa';

  @override
  String get virtUnprivilegedTip => 'root-nya adalah pengguna biasa di host.';

  @override
  String get virtSshKeys => 'Kunci publik SSH';

  @override
  String get virtCredentialsTip => 'Kata sandi root, kunci SSH, atau keduanya.';

  @override
  String virtCreated(String name) {
    return '$name dibuat';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '$name dibuat tetapi tidak berjalan';
  }

  @override
  String get virtErrExists => 'Tamu atau disk dengan nama ini sudah ada';

  @override
  String get virtCreateNameInvalidLibvirt =>
      'Huruf, angka, ., _ dan -, diawali huruf atau angka; hingga 63 karakter.';

  @override
  String get virtCreateNameInvalidPve =>
      'Huruf, angka dan -, dalam bagian yang dipisahkan titik; hingga 63 karakter.';

  @override
  String get virtCreateNameTaken => 'Sudah ada tamu dengan nama ini.';

  @override
  String get virtCreateVmidTaken => 'VMID ini sudah dipakai.';

  @override
  String get virtCreateCoresInvalid =>
      'Lebih banyak core daripada yang diizinkan host ini.';

  @override
  String get virtCreateMemoryInvalid => 'Memori tidak cukup.';

  @override
  String get virtCreateStorageMissing => 'Pilih tempat disknya.';

  @override
  String get virtCreateDiskInvalid => 'Dari 1 GiB sampai 64 TiB.';

  @override
  String get virtCreateTemplateMissing => 'Pilih templat.';

  @override
  String get virtCreateCredentialsMissing =>
      'Atur kata sandi root atau kunci SSH.';

  @override
  String virtCreatePasswordShort(int min) {
    return 'Minimal $min karakter.';
  }

  @override
  String get virtCreateSshKeysInvalid => 'Satu kunci publik OpenSSH per baris.';

  @override
  String get virtDeleteDisks => 'Hapus juga disknya';

  @override
  String get virtDeleteDisksPve =>
      'Disknya ikut dihapus; media instalasi tetap disimpan.';

  @override
  String virtDeleted(String name) {
    return '$name dihapus';
  }

  @override
  String get pveTokenTipCreate =>
      'Membuat dan menghapus tamu juga memerlukan VM.Allocate, VM.Config.*, Datastore.AllocateSpace dan SDN.Use.';

  @override
  String get pveTokenTipHardware =>
      'Mengedit perangkat keras memerlukan VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.CDROM, VM.Config.Network, dan VM.Config.Options; disk dan antarmuka baru juga memerlukan Datastore.AllocateSpace dan SDN.Use. Kartu grafis serta perangkat USB dan PCI juga membutuhkan VM.Config.HWType; perangkat lewat pemetaan sumber daya membutuhkan Mapping.Use padanya, dan Mapping.Audit untuk mendaftar pemetaan.';

  @override
  String get pveTokenTipBackup =>
      'Klon memerlukan VM.Clone, backup dan pemulihan VM.Backup, dan menjadikan template VM.Allocate; tugas backup juga memerlukan Sys.Audit untuk membacanya dan Sys.Modify pada / untuk membuat, mengedit, dan menghapusnya, dengan Datastore.AllocateSpace di tempat salinan atau backup pergi.';

  @override
  String get virtErrConflict => 'Diubah di tempat lain';

  @override
  String get virtErrConflictTip =>
      'Seseorang mengubah konfigurasi ini setelah dibaca di sini, jadi tidak ada yang diubah. Konfigurasi telah dibaca ulang: ulangi perubahan jika masih diperlukan.';

  @override
  String get virtHardware => 'Perangkat keras';

  @override
  String get virtHwAddDisk => 'Tambah disk';

  @override
  String get virtHwAddMount => 'Tambah titik kait';

  @override
  String get virtHwAddNic => 'Tambah antarmuka jaringan';

  @override
  String get virtHwAppliesOnRestart =>
      'Tersimpan. Berlaku saat mulai berikutnya.';

  @override
  String get virtHwAutostart => 'Mulai bersama host';

  @override
  String get virtHwAutostartPve => 'onboot · dijalankan menurut urutan VMID';

  @override
  String get virtHwBalloonLibvirt => 'Memori saat ini';

  @override
  String get virtHwBalloonNote =>
      'Memungkinkan host mengambil kembali memori menganggur tamu saat memori menipis';

  @override
  String get virtHwBoot => 'Boot';

  @override
  String get virtHwBootOrder => 'Urutan boot';

  @override
  String get virtHwBootTip =>
      'Panah memindahkan perangkat; ketuk untuk mengaktifkan atau menonaktifkan boot darinya.';

  @override
  String get virtHwCdrom => 'CD-ROM';

  @override
  String get virtHwConfigFile => 'Berkas konfigurasi';

  @override
  String get virtHwCores => 'Inti';

  @override
  String get virtHwCpuTypeDefault => 'Bawaan';

  @override
  String get virtHwDeleteVolume => 'Hapus juga volumenya';

  @override
  String get virtHwDetach => 'Lepas';

  @override
  String get virtHwDiskHotplug => 'Hot-plug: bisa ditambah saat berjalan';

  @override
  String get virtHwDisksLxc => 'Disk root dan titik kait';

  @override
  String get virtHwEject => 'Keluarkan';

  @override
  String get virtHwEmpty => 'Tanpa media';

  @override
  String get virtHwFirewall => 'Firewall';

  @override
  String virtHwFree(String size) {
    return '$size bebas';
  }

  @override
  String get virtHwGrow => 'Perbesar';

  @override
  String get virtHwGrowNote => 'Disk hanya bisa diperbesar.';

  @override
  String get virtHwGrowNoteRunning =>
      'Disk hanya bisa diperbesar. Jika diperbesar saat berjalan, partisi harus diperbesar di dalam tamu.';

  @override
  String get virtHwGuestUsed => 'Dipakai tamu';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'Host $threads thread · $allocated dialokasikan';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'Host $total · $allocated dialokasikan';
  }

  @override
  String get virtHwHotplugNow => 'Hot-plug: langsung berlaku.';

  @override
  String get virtHwIssueBootEmpty => 'Centang minimal satu perangkat';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'Total 1 hingga $max vCPU';
  }

  @override
  String get virtHwIssueCpuOnline => 'vCPU aktif: dari 1 hingga total';

  @override
  String get virtHwIssueDiskShrink =>
      'Lebih besar dari sekarang: disk hanya bisa diperbesar';

  @override
  String get virtHwIssueDiskSize => 'Dari 1 hingga 65536 GiB';

  @override
  String virtHwIssueMemory(int min, int max) {
    return 'Dari $min hingga $max MiB';
  }

  @override
  String get virtHwIssueMemoryMin => 'Tidak lebih dari memori';

  @override
  String get virtHwIssueMountPoint => 'Jalur absolut, seperti /data';

  @override
  String get virtHwIssueStorageSpace => 'Lebih dari ruang kosong penyimpanan';

  @override
  String get virtHwLater => 'Berlaku setelah mulai ulang';

  @override
  String get virtHwLess => 'Kurangi';

  @override
  String get virtHwLinkDown => 'Terputus';

  @override
  String get virtHwLinkNote =>
      'Mati, tamu melihat kabel dicabut; tidak perlu mulai ulang';

  @override
  String get virtHwLinkUp => 'Terhubung';

  @override
  String get virtHwMac => 'Alamat MAC';

  @override
  String get virtHwModel => 'Model';

  @override
  String get virtHwMore => 'Tambah';

  @override
  String get virtHwMountFromPool =>
      'Titik kait dialokasikan langsung dari penyimpanan';

  @override
  String get virtHwMountPoint => 'Titik kait';

  @override
  String get virtHwMoveDown => 'Turun';

  @override
  String get virtHwMoveUp => 'Naik';

  @override
  String get virtHwNewDisk => 'Disk baru';

  @override
  String get virtHwNewMount => 'Titik kait baru';

  @override
  String get virtHwNewNic => 'Antarmuka jaringan baru';

  @override
  String get virtHwNicHotplug => 'NIC virtio mendukung hot-plug';

  @override
  String get virtHwNics => 'Antarmuka jaringan';

  @override
  String get virtHwNoMedia => 'Tanpa media';

  @override
  String get virtHwNoNetworks => 'Tidak ada jaringan atau bridge di sini';

  @override
  String get virtHwNoStorage =>
      'Tidak ada penyimpanan di sini yang menampung disk';

  @override
  String get virtHwOnline => 'vCPU aktif';

  @override
  String get virtHwPendingBanner =>
      'Sebagian perubahan perangkat keras berlaku setelah mulai ulang';

  @override
  String get virtHwPickNet => 'Pilih jaringan';

  @override
  String get virtHwPickPool => 'Pilih penyimpanan dan ukuran';

  @override
  String get virtHwProcessor => 'Prosesor';

  @override
  String get virtHwRemove => 'Hapus';

  @override
  String get virtHwRemoveCdrom => 'Hapus CD-ROM';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return 'Lepas $disk dari $guest?';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return 'Lepas $nic dari $guest?';
  }

  @override
  String get virtHwResources => 'Sumber daya';

  @override
  String get virtHwRestartNow => 'Mulai ulang sekarang';

  @override
  String get virtHwRevert => 'Kembalikan';

  @override
  String get virtHwRevertAll => 'Kembalikan semua';

  @override
  String get virtSetRenameStopped =>
      'Matikan tamu untuk mengganti namanya: libvirt hanya mengganti nama tamu yang tidak berjalan.';

  @override
  String virtSetIssueDescription(int max) {
    return 'Paling banyak $max byte (UTF-8), tanpa karakter kontrol.';
  }

  @override
  String get virtSetManualStart => 'Dimulai manual';

  @override
  String get virtSetProtection => 'Perlindungan';

  @override
  String get virtSetProtectionNote =>
      'Mencegah penghapusan tamu dan perubahan disknya';

  @override
  String get virtSetIrreversible => 'Tidak dapat dibatalkan';

  @override
  String get virtSetDeleteStopFirst => 'Matikan sebelum menghapusnya.';

  @override
  String get virtSetDeleteProtected =>
      'Perlindungan aktif: matikan dulu di Umum.';

  @override
  String get virtSetDeleteAgain => 'Tekan lagi untuk mengonfirmasi';

  @override
  String virtSetDeleteConfirm(String name) {
    return 'Hapus $name';
  }

  @override
  String get virtSetDeleteVm => 'Hapus mesin virtual';

  @override
  String get virtSetDeleteLxc => 'Hapus kontainer';

  @override
  String get virtHwSockets => 'Soket';

  @override
  String get virtHwSource => 'Sumber';

  @override
  String get virtHwSwap => 'Swap';

  @override
  String get virtHwTopology => 'Soket × inti';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets soket × $cores inti × $threads thread';
  }

  @override
  String virtHwTotal(String size) {
    return '$size total';
  }

  @override
  String get virtHwVolumeKept =>
      'Dilepas, tetapi tamu yang berjalan masih memakai disk itu, jadi volumenya disimpan. Disk akan dilepas saat mulai berikutnya.';

  @override
  String get virtHwBus => 'Bus';

  @override
  String get virtHwCache => 'Cache';

  @override
  String get virtHwBusStopped => 'Bus hanya bisa diganti saat tamu berhenti.';

  @override
  String get virtHwMacGenerate => 'Buat';

  @override
  String get virtHwIssueMac =>
      'Harus alamat MAC unicast, misalnya 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => 'Hentikan tamu dulu';

  @override
  String get virtHwIssueStorageMissing => 'Pilih penyimpanan dulu';

  @override
  String get virtHwIssueDevice => 'Pilih perangkat dulu';

  @override
  String get virtHwDevices => 'CD-ROM dan passthrough';

  @override
  String get virtHwDevicesEmpty => 'Passthrough USB dan PCI, CD-ROM, TPM';

  @override
  String get virtHwAddDevice => 'Tambah perangkat';

  @override
  String get virtHwNewDevice => 'Perangkat baru';

  @override
  String get virtHwUsbHotplug => 'Passthrough USB mendukung hot-plug.';

  @override
  String get virtHwPci => 'Passthrough PCI';

  @override
  String get virtHwIommuOffTitle => 'Host tidak punya IOMMU';

  @override
  String get virtHwIommuOffBody =>
      'Aktifkan dulu VT-d atau AMD-Vi di BIOS host dan IOMMU di kernelnya. Sampai saat itu, tamu yang diberi perangkat PCI tidak akan menyala.';

  @override
  String get virtHwPciTitle => 'Butuh IOMMU di host';

  @override
  String get virtHwPciBody =>
      'Setelah diteruskan, host tidak bisa memakai perangkat itu dan tamu tidak bisa dimigrasi saat berjalan.';

  @override
  String virtHwIommuGroup(int group) {
    return 'Grup IOMMU $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '$count perangkat berbagi grup IOMMU-nya dan diteruskan bersama';
  }

  @override
  String get virtHwNoHostDevices =>
      'Tidak ada perangkat untuk diteruskan di host ini';

  @override
  String get virtHwMappingsOnly =>
      'Di sini hanya pemetaan sumber daya yang bisa dipakai: PVE hanya mengizinkan root@pam yang masuk dengan kata sandinya meneruskan perangkat mentah. Buat pemetaan di Datacenter → Resource Mappings.';

  @override
  String get virtHwTpmNote => 'Windows 11 membutuhkan TPM 2.0.';

  @override
  String get virtHwDisplay => 'Tampilan';

  @override
  String get virtHwProtocol => 'Protokol';

  @override
  String get virtHwListen => 'Dengar';

  @override
  String get virtHwGpu => 'Kartu grafis';

  @override
  String get virtHwListenAllTitle => 'Konsol terbuka ke jaringan';

  @override
  String get virtHwListenAllBody =>
      'Mendengar di semua alamat membuat siapa pun yang menjangkau host bisa membuka konsol. Tetap di 127.0.0.1 dan sambungkan lewat terowongan SSH.';

  @override
  String get virtHwFirmware => 'Firmware';

  @override
  String get virtHwUefiSub =>
      'OVMF · mendukung Secure Boot, dibutuhkan Windows 11';

  @override
  String get virtHwBiosSub => 'SeaBIOS · sistem lama dan disk MBR';

  @override
  String get virtHwSecureBootNote =>
      'Hanya mem-boot kernel dan boot loader bertanda tangan';

  @override
  String get virtHwFirmwareWarnTitle =>
      'Jangan ganti firmware sistem yang sudah terpasang';

  @override
  String get virtHwFirmwareWarnBody =>
      'Berpindah antara UEFI dan BIOS membuat sistem terpasang tidak bisa boot.';

  @override
  String get virtHwFirmwareStopped =>
      'Firmware hanya bisa diganti saat tamu berhenti.';

  @override
  String get virtHwSecureBootVars =>
      'Menyalakan atau mematikan Secure Boot membuat ulang variabel EFI; entri boot yang tersimpan di dalamnya akan hilang.';

  @override
  String get virtHwEfiStorage => 'Tempat variabel EFI';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return 'Ganti $guest ke $firmware?';
  }

  @override
  String get virtCloneName => 'Nama baru';

  @override
  String get virtCloneFull => 'Klon penuh';

  @override
  String get virtCloneCopyDisks => 'Salin isi disk';

  @override
  String get virtCloneLinkedNote =>
      'Mati: klon tertaut, bergantung pada disk templat';

  @override
  String get virtCloneFullOnly =>
      'Hanya templat yang dapat dikloning sebagai klon tertaut';

  @override
  String get virtCloneEmptyNote => 'Mati: disk kosong baru berukuran sama';

  @override
  String get virtCloneStopFirst => 'Matikan sebelum mengkloning.';

  @override
  String get virtCloneFullShort => 'Penuh';

  @override
  String get virtCloneLinkedShort => 'Tertaut';

  @override
  String get virtCloneEmptyShort => 'Disk kosong';

  @override
  String get virtCloning => 'Mengkloning…';

  @override
  String virtCloned(String name) {
    return 'Dikloning sebagai $name';
  }

  @override
  String get virtBackupPlan => 'Jadwal';

  @override
  String get virtBackupPlanWhere => 'Pusat data → Cadangan';

  @override
  String get virtBackupNoPlanShort => 'Tanpa jadwal';

  @override
  String get virtBackupNoPlan =>
      'Tidak ada tugas cadangan terjadwal yang mencakup tamu ini.';

  @override
  String get virtBackupKeep => 'Simpan';

  @override
  String get virtBackupJobDisabled => 'Tugas ini dinonaktifkan.';

  @override
  String virtBackupCount(int count) {
    return '$count cadangan';
  }

  @override
  String virtSnapshotCount(int count) {
    return '$count snapshot';
  }

  @override
  String get virtBackupNoStorage =>
      'Tidak ada penyimpanan di node ini yang menampung cadangan.';

  @override
  String get virtBackupLiveTip => 'Berjalan: mode snapshot, tanpa henti';

  @override
  String get virtBackupStoppedTip => 'Mati: dicadangkan apa adanya';

  @override
  String get virtBackupNow => 'Cadangkan sekarang';

  @override
  String get virtBackupNotes => 'Catatan';

  @override
  String get virtBackupProtected =>
      'Dilindungi: tidak dapat dihapus sampai perlindungan dicabut di PVE.';

  @override
  String virtBackupVerified(String state) {
    return 'Verifikasi: $state';
  }

  @override
  String get virtBackupRestoreOverwrites => 'Memulihkan menimpa disk saat ini';

  @override
  String get virtBackupStopFirst => 'Matikan sebelum memulihkan.';

  @override
  String get virtBackupRestoreAgain =>
      'Disk dan konfigurasi tamu diganti dengan milik cadangan.';

  @override
  String get virtBackupDeleteConfirm => 'Hapus cadangan';

  @override
  String get virtBackupRestoreNew => 'Pulihkan sebagai baru';

  @override
  String get virtBackupRestoreConfirm => 'Pulihkan menimpa';

  @override
  String get virtBackupDone => 'Pencadangan selesai';

  @override
  String get virtBackupDeleted => 'Cadangan dihapus';

  @override
  String virtBackupRestored(String time) {
    return 'Dipulihkan dari $time';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return '$account tidak memiliki $privilege pada $path. Berikan di host PVE:\n$command';
  }

  @override
  String get virtCanDelete => 'Dapat dihapus';

  @override
  String get virtInUse => 'Sedang digunakan';

  @override
  String get virtOps => 'Operasi';

  @override
  String get virtPool => 'Pool penyimpanan';

  @override
  String get virtPoolNew => 'Pool penyimpanan baru';

  @override
  String get virtStorageAdd => 'Tambah penyimpanan';

  @override
  String virtPoolUsedPct(String pct) {
    return '$pct% terpakai';
  }

  @override
  String get virtPoolInUse =>
      'Sebuah VM memakai volume di sini, jadi pool tidak dapat dihentikan atau dihapus.';

  @override
  String get virtPoolDelete => 'Hapus pool';

  @override
  String get virtStorageRemove => 'Hapus penyimpanan';

  @override
  String virtPoolDeleteAsk(String name) {
    return 'Hapus pool $name? Definisinya dihapus; volumenya tetap di tempatnya.';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return 'Hapus penyimpanan $name dari konfigurasi PVE? Isinya tetap ada.';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return '$count volumenya tetap disimpan di disk.';
  }

  @override
  String get virtPoolDeleteStorage =>
      'Hapus juga direktorinya (hanya jika kosong)';

  @override
  String virtPoolStopAsk(String name) {
    return 'Hentikan pool $name? Volumenya tidak dapat didaftar atau dibuat sampai dijalankan lagi.';
  }

  @override
  String get virtStorageClusterWide =>
      'Ini berlaku untuk setiap node di klaster yang memiliki penyimpanan ini.';

  @override
  String get virtStorageDisable => 'Nonaktifkan';

  @override
  String get virtStorageEnable => 'Aktifkan';

  @override
  String virtStorageDisableAsk(String name) {
    return 'Nonaktifkan penyimpanan $name? VM dengan disk di sana tidak dapat dijalankan sampai diaktifkan lagi.';
  }

  @override
  String get virtPoolLogicalNote =>
      'Volume group yang ada dipakai apa adanya; tidak ada yang diformat.';

  @override
  String get virtPoolMountPoint => 'Titik kait';

  @override
  String get virtPoolSourceNfs => 'Sumber (host:/path)';

  @override
  String get virtPoolSourceVg => 'Volume group';

  @override
  String get virtPoolSourceThin => 'Grup volume / thin pool';

  @override
  String get virtPoolSourceZfs => 'Pool ZFS';

  @override
  String get virtPoolTypeVg => 'Volume group LVM';

  @override
  String get virtResNameEmpty => 'Masukkan nama';

  @override
  String get virtResNotFound => 'Sudah tidak ada di host ini';

  @override
  String get virtResUnsupported => 'Host ini tidak mendukungnya';

  @override
  String get virtResNameInvalid =>
      'Bukan nama yang diterima host ini (huruf, angka, . _ -)';

  @override
  String get virtResSourceInvalid => 'Bukan path atau sumber yang valid';

  @override
  String get virtResTargetInvalid => 'Path absolut';

  @override
  String get virtResCidrInvalid =>
      'Alamat dengan prefiks, mis. 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid =>
      'Dua alamat di jaringan, berurutan, tanpa alamat host';

  @override
  String get virtResSubnetTaken => 'Jaringan lain di sini memakai subnet ini';

  @override
  String get virtResBridgeInvalid => 'Bukan nama antarmuka';

  @override
  String get virtResFormat => 'Pool ini tidak mendukung format itu';

  @override
  String get virtVolNew => 'Volume baru';

  @override
  String virtVolCount(int count) {
    return '$count volume';
  }

  @override
  String get virtVolNone => 'Pool ini belum punya volume.';

  @override
  String get virtVolEmptyAttach =>
      'Volume baru bisa dipasang ke VM mana pun nanti';

  @override
  String get virtVolEmptyUpload => 'ISO juga bisa diunggah langsung';

  @override
  String get virtVolPveName =>
      'PVE menamai volume sesuai VM-nya: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => 'Dipakai oleh';

  @override
  String get virtVolAllocated => 'Teralokasi';

  @override
  String get virtVolGrowFromGuest =>
      'Dipakai sebuah VM: perbesar dari tampilan Perangkat Keras VM itu';

  @override
  String get virtVolInUse => 'Sebuah VM memakai volume ini';

  @override
  String virtVolBackingOf(String names) {
    return 'Berkas dasar untuk $names';
  }

  @override
  String get virtVolIsBase =>
      'Volume lain dibuat di atas volume ini; menghapusnya akan merusaknya';

  @override
  String get virtVolAttach => 'Pasang ke VM';

  @override
  String get virtVolAttachNote =>
      'Dipasang sebagai disk baru, di bus disk pertamanya';

  @override
  String virtVolAttached(String name) {
    return 'Terpasang ke $name';
  }

  @override
  String get virtVolInsert => 'Masukkan ke CD-ROM';

  @override
  String virtVolInserted(String name) {
    return 'Dimasukkan ke CD-ROM $name';
  }

  @override
  String virtVolNoCdrom(String name) {
    return '$name tidak punya CD-ROM';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return 'Hapus volume $name dari $pool? Isinya hilang selamanya.';
  }

  @override
  String get virtUploadIso => 'Unggah ISO';

  @override
  String virtUploadTo(String pool) {
    return 'Unggah ke $pool';
  }

  @override
  String virtUploadDone(String name) {
    return '$name terunggah';
  }

  @override
  String get virtNetConfig => 'Konfigurasi';

  @override
  String get virtNetConfigFile => 'Berkas konfigurasi';

  @override
  String get virtNetInternal => 'Internal';

  @override
  String get virtNetBridgePorts => 'Port bridge';

  @override
  String get virtNetHostBridge => 'Bridge host';

  @override
  String get virtNetPortsHint => 'eno2; kosongkan untuk bridge internal';

  @override
  String get virtNetDhcpRange => 'Rentang DHCP';

  @override
  String get virtNetDhcpTip => 'dnsmasq memberi alamat ke VM';

  @override
  String get virtNetVlanTip => 'NIC VM boleh membawa tag VLAN';

  @override
  String get virtNetNatTip =>
      'Lewat host: VM bisa keluar, dari luar tidak bisa masuk';

  @override
  String get virtNetRoutedTip =>
      'Dirutekan host tanpa NAT: LAN perlu rute balik';

  @override
  String get virtNetIsolatedTip => 'Hanya VM dan host yang saling terhubung';

  @override
  String get virtNetBridgedTip =>
      'VM bergabung ke bridge host, di jaringan fisiknya';

  @override
  String get virtNetNew => 'Jaringan baru';

  @override
  String get virtNetNewBridge => 'Linux bridge baru';

  @override
  String get virtNetVirtual => 'Jaringan virtual';

  @override
  String get virtNetDelete => 'Hapus jaringan';

  @override
  String virtNetDeleteAsk(String name) {
    return 'Hapus jaringan $name? Jaringan dihentikan dan definisinya dihapus.';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return 'Hapus bridge $name dari $node? Dihapus dari konfigurasi tertunda sekarang, dan dari host setelah diterapkan.';
  }

  @override
  String virtNetInUse(int count) {
    return 'VM di dalamnya: $count. Tidak dapat dihapus.';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return 'Hentikan $name? $count VM di dalamnya kehilangan jaringan sampai dijalankan lagi.';
  }

  @override
  String get virtNetInactivePve =>
      'Tidak aktif: bridge baru menunggu di konfigurasi tertunda sampai diterapkan.';

  @override
  String get virtNetPveApplyNote =>
      'Disimpan sebagai perubahan tertunda: berlaku saat konfigurasi diterapkan (ifreload -a).';

  @override
  String get virtNetPendingSaved =>
      'Disimpan sebagai tertunda: terapkan konfigurasi agar berlaku';

  @override
  String virtNetPendingTitle(String node) {
    return 'Perubahan jaringan tertunda di $node';
  }

  @override
  String get virtNetPendingTip =>
      'PVE menyimpan perubahan jaringan di interfaces.new sampai diterapkan.';

  @override
  String get virtNetPendingShow => 'Lihat perubahan';

  @override
  String get virtNetApply => 'Terapkan konfigurasi';

  @override
  String virtNetApplyAsk(String node) {
    return 'Terapkan konfigurasi jaringan tertunda di $node? PVE memuat ulang jaringan host (ifreload -a): kesalahan bisa memutus host.';
  }

  @override
  String virtNetRevertAsk(String node) {
    return 'Buang konfigurasi jaringan tertunda di $node?';
  }

  @override
  String get pveTokenTipStorage =>
      'Mengelola penyimpanan butuh Datastore.Allocate pada /storage (tambah, nonaktifkan, hapus), Datastore.AllocateSpace (volume) dan Datastore.AllocateTemplate (unggahan); Linux bridge dan menerapkan konfigurasi jaringan butuh Sys.Modify pada node.';

  @override
  String get virtCreateUnnamed => 'Tanpa nama';

  @override
  String get virtCreateNotChosen => 'Belum dipilih';

  @override
  String get virtCreateKindVmSub => 'qm · mesin virtual KVM penuh';

  @override
  String get virtCreateKindLxcSub => 'pct · berbagi kernel host, lebih ringan';

  @override
  String get virtCloudImage => 'Image cloud';

  @override
  String get virtCloudImageTip =>
      'Disk yang sudah berisi sistem: disalin, diperbesar ke ukuran di Penyimpanan, dan diatur oleh cloud-init saat boot pertama. Image-nya sendiri tidak diubah.';

  @override
  String get virtNoCloudImagesLibvirt =>
      'Tidak ada image cloud di sini: taruh image qcow2 atau raw di sebuah pool (unggah di Penyimpanan) yang tidak dipakai VM mana pun.';

  @override
  String get virtNoCloudImagesPve =>
      'Tidak ada image cloud di sini: unggah image qcow2, raw, atau vmdk ke penyimpanan dengan tipe konten Import (PVE 8.2+).';

  @override
  String get virtCreateWindowsTitle =>
      'Windows 11 membutuhkan UEFI dan TPM 2.0';

  @override
  String get virtCreateWindowsBody => 'Pilih UEFI dan aktifkan TPM di atas.';

  @override
  String get virtCreateWindowsNoTpm =>
      'Host ini tidak punya TPM perangkat lunak (swtpm): pasang agar VM bisa diberi TPM.';

  @override
  String virtCreateImageSize(String size) {
    return 'Image-nya $size: disk harus minimal sebesar itu.';
  }

  @override
  String get virtCreateImageMissing => 'Pilih image cloud.';

  @override
  String get virtCreateIncomplete =>
      'Lengkapi dulu bagian yang ditandai oranye.';

  @override
  String virtCreateOn(String host) {
    return 'Dibuat di $host';
  }

  @override
  String get virtCiTip =>
      'Akun dengan sudo, masuk dengan kata sandi, kunci SSH, atau keduanya.';

  @override
  String get virtCiUserInvalid =>
      'Huruf kecil, angka, _ dan -, diawali huruf atau _';

  @override
  String get virtCiCredentialsMissing => 'Atur kata sandi atau kunci SSH.';

  @override
  String get virtCiHostnamePve => 'Nama host adalah nama VM.';

  @override
  String get virtCiStatic => 'Statis';

  @override
  String get virtCiAddressInvalid =>
      'Alamat IPv4 dengan prefiksnya, seperti 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'Alamat IPv4, seperti 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => 'Kosong: dari DHCP';

  @override
  String get virtCiDnsInvalid => 'Alamat IP, dipisahkan spasi atau koma';

  @override
  String get virtCiSearch => 'Domain pencarian';

  @override
  String get virtCiSeedNote =>
      'Ditulis ke ISO kecil di sebelah disk, dipasang sebagai CD-ROM, dan dihapus bersama VM. Hanya hash kata sandi yang disimpan.';

  @override
  String get virtCiNoToolTitle =>
      'Tidak ada alat di host untuk membuat data cloud-init';

  @override
  String virtCiNoToolBody(String tools) {
    return 'Pasang salah satu dari $tools di host. Tanpa cloud-init, image berjalan tanpa akun untuk masuk.';
  }

  @override
  String get virtHwCloudInitNote =>
      'Data yang dibaca cloud-init saat boot pertama. Bukan media instalasi: tidak ada yang dimasukkan di sini.';

  @override
  String get virtHwCdromLater =>
      'Selama berjalan, drive ditambahkan saat start berikutnya (SATA dan IDE tidak mendukung hot-plug).';

  @override
  String virtCreateDiskKept(String size) {
    return 'Disk tetap $size, ukuran image itu sendiri, lebih besar dari yang diminta: disk tidak pernah dipotong di bawah sistem di dalamnya.';
  }

  @override
  String get virtCiEditTip =>
      'Yang diatur cloud-init di VM ini: akun dengan sudo, cara masuk ke akun itu, hostname, dan alamat.';

  @override
  String get virtCiForeignTitle =>
      'Seed ini berisi lebih dari yang ditulis aplikasi ini';

  @override
  String get virtCiForeignBody =>
      'Pengaturan yang dibuat di tempat lain (paket, perintah, akun lain) tidak ditampilkan di sini. Menyimpan akan mengganti seed dengan yang ditampilkan.';

  @override
  String get virtCiPasswordKept =>
      'Sudah diatur. Biarkan kosong untuk mempertahankannya';

  @override
  String get virtCiRemovePassword => 'Hapus kata sandi';

  @override
  String get virtCiRemovePasswordNote => 'Masuk hanya dengan kunci SSH';

  @override
  String get virtCiKeysAdded =>
      'Kunci ditambahkan ke akun. Kunci yang dihapus di sini tetap ada di sistem sampai dihapus di sana, dan nama pengguna baru membuat akun baru di samping akun lama.';

  @override
  String get virtCiEffectTitle => 'Berlaku saat boot berikutnya';

  @override
  String get virtCiEffectLibvirt =>
      'Menyimpan menulis seed baru dengan ID instans baru.';

  @override
  String get virtCiEffectPve =>
      'PVE langsung menulis ulang drive cloud-init-nya, dengan ID instans yang diturunkan dari pengaturan ini, jadi setiap perubahan di sini membuat ID baru.';

  @override
  String get virtCiNewInstance =>
      'Saat boot berikutnya, cloud-init memperlakukan sistem sebagai instans baru: mengatur ulang hostname, membuat akun jika belum ada, mengatur kata sandinya, menambahkan kunci, dan menulis ulang konfigurasi jaringan. Ia juga membuat kunci host SSH baru, sehingga klien SSH akan memperingatkan bahwa kunci host berubah. Tidak ada yang berubah sebelum boot itu.';

  @override
  String get virtCiSaved => 'Tersimpan. Berlaku saat boot berikutnya.';

  @override
  String get virtSnapshotExternal => 'Hanya disk saat berjalan';

  @override
  String get virtSnapshotExternalTip =>
      'Guest tetap berjalan. Setiap disk mendapat overlay qcow2 di pool terpilih; guest berada pada rantai.';

  @override
  String get virtSnapshotFormInternal => 'Internal (di dalam image)';

  @override
  String get virtSnapshotOverlayPool => 'Pool overlay';

  @override
  String get virtSnapshotOverlayBeside => 'Di samping setiap disk';

  @override
  String get virtSnapshotExternalNoMemory =>
      'Snapshot eksternal tidak pernah menyimpan memori: guest tidak dihentikan.';

  @override
  String get virtSnapshotChain => 'Rantai disk';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count lapisan';
  }

  @override
  String get virtSnapshotChainFile => 'Berkas';

  @override
  String get virtSnapshotChainActive => 'Sedang dipakai';

  @override
  String get virtSnapshotChainBase => 'Image dasar';

  @override
  String get virtSnapshotNoSupport =>
      'Penyimpanan guest tidak mendukung snapshot, jadi tidak ada yang bisa dibuat.';

  @override
  String get virtSnapshotRevertChain =>
      'Mengembalikan pada rantai menggabungkan overlay yang berjalan ke dalam image dan membuat snapshot berikutnya tidak terpakai. Hanya snapshot terbaru yang bisa dikembalikan.';

  @override
  String get virtSnapshotRevertHasChildren =>
      'Ditolak selama snapshot berikutnya berada di atas yang ini.';

  @override
  String get virtSnapshotDiff => 'Perbedaan dari sekarang';

  @override
  String get virtSnapshotDiffNone =>
      'Konfigurasi tidak berubah sejak snapshot ini.';

  @override
  String get virtSnapshotDiffShow => 'Bandingkan dengan sekarang';

  @override
  String get virtSnapshotDiffGroupCpu => 'Prosesor';

  @override
  String get virtSnapshotDiffGroupMemory => 'Memori';

  @override
  String get virtSnapshotDiffGroupDisks => 'Disk';

  @override
  String get virtSnapshotDiffGroupNic => 'Antarmuka';

  @override
  String get virtSnapshotDiffGroupFirmware => 'Firmware';

  @override
  String get virtSnapshotDiffGroupBoot => 'Boot';

  @override
  String get virtSnapshotDiffGroupOther => 'Lainnya';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => 'dihapus';

  @override
  String get virtSnapshotDiffAdded => 'ditambahkan';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return 'Apa yang berubah jika Anda mengembalikan ke $snapshot:';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return 'Host tidak dapat mengatakan apa yang berbeda: $error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return 'Guest sudah berada di $count lapisan; snapshot ini menambah satu lagi.';
  }

  @override
  String get virtToTemplate => 'Jadikan template';

  @override
  String get virtToTemplateNote =>
      'Template tidak dapat dijalankan dan tidak dapat dikembalikan menjadi guest. Disk-nya menjadi image dasar, yang dibagi oleh klon tertaut.';

  @override
  String virtToTemplateConfirm(String name) {
    return 'Jadikan $name template?';
  }

  @override
  String get virtToTemplateIrreversible =>
      'Ini tidak dapat dibatalkan: template tidak dapat dikembalikan menjadi guest.';

  @override
  String get virtToTemplateStopped => 'Matikan dulu.';

  @override
  String get virtToTemplateSnapshots =>
      'Guest dengan snapshot tidak dapat menjadi template.';

  @override
  String virtTemplateCreated(String name) {
    return '$name kini template';
  }

  @override
  String get virtTemplateTip => 'Template hanya berjalan setelah diklon.';

  @override
  String get virtCloneStorageSame => 'Sama seperti sumber';

  @override
  String get virtCloneNodeSame => 'Sama seperti sumber';

  @override
  String get virtCloneStorageContent =>
      'Penyimpanan ini tidak menyimpan disk VM.';

  @override
  String get virtCloneStorageShared =>
      'Menyalin ke node lain memerlukan penyimpanan bersama.';

  @override
  String get virtCloneNodeUnknown => 'Host ini tidak memiliki node tersebut.';

  @override
  String get virtCloneLinkedTarget =>
      'Klon tertaut berbagi disk template, jadi tidak dapat menyebut penyimpanan atau node.';

  @override
  String get virtBackupJobs => 'Tugas backup';

  @override
  String get virtBackupJobsNone =>
      'Tidak ada tugas backup terjadwal. Tambahkan satu untuk mencadangkan guest secara berkala.';

  @override
  String get virtBackupJobNew => 'Tugas baru';

  @override
  String get virtBackupJobRun => 'Jalankan sekarang';

  @override
  String get virtBackupJobRunAsk => 'Mulai tugas backup ini sekarang?';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return 'Hapus tugas backup $id? Backup yang dibuat tetap ada.';
  }

  @override
  String get virtBackupJobSaved => 'Tugas disimpan';

  @override
  String get virtBackupJobDeleted => 'Tugas dihapus';

  @override
  String get virtBackupJobStarted => 'Tugas backup dimulai';

  @override
  String get virtBackupSchedule => 'Jadwal';

  @override
  String get virtBackupScheduleHelp =>
      'Subset dari peristiwa kalender systemd: 02:30, mon..fri 02:30, sat 03:00, daily, hourly, */15.';

  @override
  String get virtBackupScheduleInvalid => 'Jadwal ini tidak diterima host.';

  @override
  String virtBackupScheduleNext(String times) {
    return 'Jalan berikutnya: $times';
  }

  @override
  String get virtBackupSelection => 'Guest';

  @override
  String get virtBackupSelectionAll => 'Semua guest';

  @override
  String get virtBackupSelectionList => 'Guest terpilih';

  @override
  String get virtBackupSelectionNone => 'Pilih setidaknya satu guest.';

  @override
  String get virtBackupMail => 'Notifikasi';

  @override
  String get virtBackupNotesTemplate => 'Catatan backup';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return 'Catatan ditambahkan ke setiap backup tugas. Digantikan: $vars.';
  }

  @override
  String get virtBackupPrune => 'Retensi';

  @override
  String get virtBackupPruneTip =>
      'Opsi retensi PVE, mis. keep-last=7,keep-daily=4. Kosong: milik penyimpanan atau node.';

  @override
  String get virtBackupJobNode => 'Node';

  @override
  String get virtBackupJobNodeAny => 'Semua node';

  @override
  String get virtBackupEnabled => 'Aktif';

  @override
  String get virtBackupOptions => 'Opsi';

  @override
  String get virtBackupProtect => 'Lindungi';

  @override
  String get virtBackupProtectTip =>
      'Backup yang dilindungi tidak dipangkas dan tidak dapat dihapus selama dilindungi.';

  @override
  String get virtBackupEditNotes => 'Catatan';

  @override
  String get virtBackupSaveNotes => 'Simpan';

  @override
  String get virtBackupEdited => 'Backup diperbarui';

  @override
  String get virtBackupRestoreStorage => 'Pulihkan ke penyimpanan';

  @override
  String get virtBackupRestoreStorageSame => 'Seperti di backup';

  @override
  String get virtCloneStorageMissing =>
      'Tidak ada penyimpanan di node ini yang menyimpan disk VM.';

  @override
  String get virtBackupCompress => 'Kompresi';

  @override
  String get virtBackupUnprotect => 'Buka perlindungan';

  @override
  String get virtBackupModeStops =>
      'suspend dan stop menghentikan sementara guest yang berjalan saat disalin.';

  @override
  String get virtBackupScheduleValidate => 'Periksa ke host';

  @override
  String virtBackupSelected(int count) {
    return '$count dipilih';
  }

  @override
  String get virtBackupExcludeTip =>
      'Semua guest di node diambil. Matikan satu untuk mengecualikannya.';

  @override
  String virtNetEditAsk(int count) {
    return 'Jaringan yang berjalan mempertahankan kondisinya sampai dimulai ulang. Mulai ulang memutus VM di dalamnya ($count).';
  }

  @override
  String get virtNetEditAskNoGuest =>
      'Jaringan yang berjalan mempertahankan kondisinya sampai dimulai ulang.';

  @override
  String get virtNetEditRestart => 'Mulai ulang untuk menerapkan sekarang';

  @override
  String get virtNetEditRestartNote =>
      'VM di dalamnya kehilangan jaringan selama dimulai ulang.';

  @override
  String get virtNetEditPending =>
      'Definisi berisi perubahan yang belum dipakai jaringan yang berjalan.';

  @override
  String get virtNetRestart => 'Mulai ulang';

  @override
  String virtNetRestartAsk(String name, int count) {
    return 'Mulai ulang $name? VM di dalamnya ($count) kehilangan jaringan sampai kembali.';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return 'Mulai ulang $name? Tidak ada yang terhubung.';
  }

  @override
  String get virtNetHosts => 'Alamat statis';

  @override
  String get virtNetHostAdd => 'Tambah alamat';

  @override
  String get virtNetHostMac => 'MAC';

  @override
  String get virtNetHostIp => 'Alamat';

  @override
  String get virtNetHostName => 'Nama (opsional)';

  @override
  String get virtNetHostEmpty =>
      'Tidak ada MAC yang diberi alamat sendiri: setiap VM mendapat alamat dari rentang DHCP.';

  @override
  String get virtNetHostOthers =>
      'Setiap VM lainnya mendapat alamat dari rentang DHCP.';

  @override
  String get virtNetHostInvalid =>
      'MAC, alamat, atau nama yang akan ditolak host, atau MAC yang sama dua kali.';

  @override
  String get virtNetManagementIface =>
      'Antarmuka ini membawa alamat host sendiri. Mengedit atau menerapkannya akan memutus host.';

  @override
  String get virtNetManagementTip =>
      'Antarmuka ini membawa lalu lintas manajemen host, atau berada di bawah antarmuka yang membawanya: aplikasi tidak mengeditnya.';

  @override
  String get virtNetPhysicalTip =>
      'Antarmuka fisik milik host sendiri: aplikasi hanya mengedit bridge.';

  @override
  String get virtNetVlanAware => 'VLAN aware';

  @override
  String get virtCiExpire => 'Kata sandi kedaluwarsa';

  @override
  String get virtCiExpireNote =>
      'Login pertama dengannya harus menetapkan kata sandi baru. Hanya libvirt: PVE menulis \"expire: false\" dan tidak punya opsi untuk ini.';

  @override
  String get virtCiSearchHint => 'lab.example dev.lab.example';

  @override
  String get virtCiSearchTip =>
      'Beberapa, dipisahkan spasi; resolv.conf menyimpan beberapa yang pertama.';

  @override
  String virtCiNicsTip(int count) {
    return '$count NIC di konfigurasi jaringan seed; formulir mengedit yang pertama.';
  }

  @override
  String get virtUsbByVendor => 'Menurut vendor dan produk';

  @override
  String get virtUsbByAddress => 'Menurut alamat';

  @override
  String get virtUsbAddressTip =>
      'Perangkat mengikuti alamat ini: apa pun yang dicolok di sana diberikan ke VM. libvirt menamai hostdev USB dengan nomor bus dan perangkat.';

  @override
  String virtUsbPortNote(int bus, String port) {
    return 'bus $bus · port $port';
  }

  @override
  String get virtSbUnsupported =>
      'Deskriptor firmware host tidak memiliki firmware Secure Boot dengan kunci terdaftar, jadi domain yang memakainya tidak dapat dimulai.';

  @override
  String get virtCreateSecureBoot => 'Secure Boot';

  @override
  String get virtCreateSecureBootNote =>
      'Hanya kernel dan bootloader bertanda tangan yang di-boot.';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return 'bus $bus · perangkat $device';
  }

  @override
  String get virtHwRevertPendingTitle => 'Buang perubahan tertunda';

  @override
  String virtHwRevertPendingBody(String name) {
    return '$name dikembalikan ke yang sedang berjalan: definisi ditulis ulang dari yang berjalan, dan start berikutnya mendapat persis yang dimiliki saat ini. File NVRAM dan firmware-nya tetap seperti semula.';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return 'Buang semua perubahan yang menunggu start berikutnya dari $name?';
  }

  @override
  String get virtBackupPlanNew => 'Rencana baru';

  @override
  String get virtBackupPlanNewTip => 'Jadwal yang mencadangkan tamu ini saja.';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Juga mencadangkan $count tamu lain',
      zero: 'Tidak ada tamu lain',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => 'Kurangi gerakan';

  @override
  String get copyLink => 'Salin tautan';

  @override
  String funcNeedsAgentHttps(String func) {
    return '$func memerlukan HTTPS ke Monitor agent ini, atau HTTP diizinkan di agent dan aplikasi ini.';
  }

  @override
  String get monitorAccess => 'Akses';

  @override
  String get monitorChangePassword => 'Ubah kata sandi';

  @override
  String get monitorNewPassword => 'Kata sandi baru';

  @override
  String get monitorCurrentPassword => 'Kata sandi Anda saat ini';

  @override
  String get monitorPasswordTooShort => 'Minimal 8 karakter';

  @override
  String get monitorPasswordMismatch => 'Kata sandi tidak cocok';

  @override
  String get monitorErrReauth => 'Kata sandi Anda salah.';

  @override
  String get monitorPasswordNotSaved =>
      'Kata sandi sudah diubah di agen, tetapi aplikasi gagal menyimpannya. Perbarui kata sandi Monitor di pengaturan server ini.';

  @override
  String get firewall => 'Firewall';

  @override
  String get firewallLinuxOnly =>
      'Pengelolaan firewall mendukung server Linux dengan ufw atau firewalld.';

  @override
  String get firewallNeedsRoot =>
      'Membaca aturan firewall memerlukan root. Masukkan kata sandi sudo untuk melanjutkan.';

  @override
  String get firewallIncoming => 'Masuk';

  @override
  String get firewallOutgoing => 'Keluar';

  @override
  String get firewallRouted => 'Diteruskan';

  @override
  String get firewallDefaultPolicy => 'Kebijakan bawaan';

  @override
  String get firewallLogging => 'Pencatatan';

  @override
  String get firewallRules => 'Aturan';

  @override
  String get firewallRule => 'Aturan';

  @override
  String get firewallAddRule => 'Tambah aturan';

  @override
  String get firewallAnywhere => 'Di mana saja';

  @override
  String firewallFromFmt(String source) {
    return 'dari $source';
  }

  @override
  String get firewallFrom => 'Dari';

  @override
  String get firewallTo => 'Ke';

  @override
  String get firewallProtocol => 'Protokol';

  @override
  String get firewallInterface => 'Antarmuka';

  @override
  String get firewallComment => 'Komentar';

  @override
  String get firewallAppProfile => 'Profil aplikasi';

  @override
  String get firewallPrepend => 'Letakkan sebelum semua aturan lain';

  @override
  String get firewallIpv6Off =>
      'IPv6 nonaktif (IPV6=no): aturan v6 tidak dimuat.';

  @override
  String get firewallReload => 'Muat ulang';

  @override
  String get firewallNothingMatched =>
      'Masukkan port, profil aplikasi, alamat, atau antarmuka.';

  @override
  String get firewallInvalidPort =>
      'Port tidak valid. Gunakan 22, 80,443, atau 6000:6010.';

  @override
  String get firewallTooManyPorts =>
      'Paling banyak 15 port; satu rentang dihitung dua.';

  @override
  String get firewallPortsNeedProtocol =>
      'Daftar atau rentang port memerlukan tcp atau udp.';

  @override
  String get firewallInvalidAddress =>
      'Alamat tidak valid. Gunakan alamat IP atau jaringan seperti 192.168.1.0/24.';

  @override
  String get firewallMixedIpVersions =>
      'Dari dan Ke harus sama-sama IPv4 atau sama-sama IPv6.';

  @override
  String get firewallInvalidInterface => 'Nama antarmuka tidak valid.';

  @override
  String get firewallInvalidComment =>
      'Komentar tidak boleh berisi \' atau baris baru.';

  @override
  String get firewallInvalidProtocol => 'Protokol tidak didukung.';

  @override
  String get firewallInterfaceIn => 'Antarmuka masuk';

  @override
  String get firewallInterfaceOut => 'Antarmuka keluar';

  @override
  String get firewallSourcePort => 'Port sumber';

  @override
  String get firewallMoreOptions => 'Opsi lainnya';

  @override
  String get firewallNoneInstalled =>
      'ufw maupun firewalld tidak terpasang di server ini. Pasang salah satunya dengan pengelola paket sistem, misalnya `apt install ufw` atau `dnf install firewalld`.';

  @override
  String get firewallKeepAccess =>
      'Biarkan port aplikasi ini tetap terbuka terlebih dahulu';

  @override
  String firewallWillRefuseFmt(String access) {
    return '$access: koneksi baru dari aplikasi ini akan ditolak. Koneksi yang sedang dipakai tetap berjalan sampai terputus.';
  }

  @override
  String firewallMayRefuseFmt(String access) {
    return '$access: koneksi baru dari aplikasi ini mungkin ditolak. Hal itu bergantung pada alamat atau antarmuka yang dilaluinya, yang tidak dapat diketahui aplikasi ini.';
  }

  @override
  String firewallRateLimitedFmt(String access) {
    return '$access: koneksi akan dibatasi lajunya. Alamat yang membuka 6 koneksi atau lebih dalam 30 detik akan ditolak, dan aplikasi ini mungkin menyambung ulang sesering itu.';
  }

  @override
  String get firewallConflict =>
      'ufw dan firewalld sama-sama aktif. Keduanya menulis aturan kernel, dan yang dimuat terakhir menentukan apa yang lolos.';

  @override
  String get firewallDefaultZone => 'Zone bawaan';

  @override
  String get firewallZone => 'Zone';

  @override
  String get firewallTarget => 'Target';

  @override
  String get firewallMasquerade => 'Masquerade';

  @override
  String get firewallServices => 'Layanan';

  @override
  String get firewallPorts => 'Port';

  @override
  String get firewallSources => 'Sumber';

  @override
  String get firewallInterfaces => 'Antarmuka';

  @override
  String get firewallRichRules => 'Rich rules';

  @override
  String get firewallForwardPorts => 'Port yang diteruskan';

  @override
  String get firewallRuntimeOnly => 'hanya runtime';

  @override
  String get firewallPermanentOnly => 'hanya permanent';

  @override
  String get firewallThisConnection => 'koneksi ini';

  @override
  String get firewallDefaultTag => 'bawaan';

  @override
  String get firewallDrift =>
      'Konfigurasi yang berlaku berbeda dari yang tersimpan. Reload atau boot ulang akan menggantinya dengan konfigurasi tersimpan.';

  @override
  String firewallDriftLockoutFmt(String access) {
    return 'Setelah reload atau boot ulang, $access akan ditolak: konfigurasi tersimpan tidak mengizinkannya.';
  }

  @override
  String get firewallSaveRuntime => 'Simpan sebagai permanent';

  @override
  String get firewallReloadLoses =>
      'Perubahan yang tidak disimpan sebagai permanent akan hilang.';

  @override
  String get firewallPanic => 'Mode panic aktif: semua paket dibuang.';

  @override
  String get firewallPanicOff => 'Matikan mode panic';

  @override
  String get firewallStoppedNote =>
      'firewalld berhenti. Perubahan disimpan dan berlaku saat dijalankan.';

  @override
  String get firewallInvalidSource =>
      'Sumber tidak valid. Gunakan alamat, jaringan seperti 192.168.1.0/24, ipset:NAMA, atau alamat MAC.';

  @override
  String get firewallInvalidRichRule =>
      'Rich rule diawali \"rule\" dan hanya satu baris.';

  @override
  String get firewallInvalidForwardPort =>
      'Gunakan port=80:proto=tcp:toport=8080, dengan toport, toaddr, atau keduanya.';

  @override
  String get monitorSyncNeedsServer =>
      'Pilih server yang agen monitornya menyimpan cadangan.';

  @override
  String get monitorBackupUnsupported =>
      'Agen monitor ini tidak dapat menyimpan cadangan. Perbarui agen.';

  @override
  String monitorBackupTooLarge(String max) {
    return 'Cadangan lebih besar dari yang diterima agen monitor ($max).';
  }

  @override
  String get monitorBackupTooMany =>
      'Agen monitor sudah menyimpan cadangan sebanyak yang diizinkan. Hapus satu terlebih dahulu.';

  @override
  String get virtCreateVmidInvalid => 'VMID dari 100 sampai 999999999.';

  @override
  String get virtCreateNodeOffline => 'Node itu tidak online.';

  @override
  String get virtCreateMediaMissing =>
      'Media instalasi itu tidak ada di host ini.';

  @override
  String get virtCreateNetworkMissing =>
      'Guest baru tidak dapat memakai jaringan itu.';

  @override
  String get virtCreateNotOffered =>
      'Host ini tidak menyediakan itu untuk VM baru.';

  @override
  String get virtCreateSecureBootNeedsUefi => 'Secure Boot memerlukan UEFI.';

  @override
  String get virtGuestNotStopped => 'Matikan terlebih dahulu.';

  @override
  String get virtGuestIsTemplate => 'Sudah menjadi templat.';

  @override
  String get virtCreateImageBigger =>
      'Image lebih besar dari disk: buat disk setidaknya sebesar itu.';

  @override
  String get virtBackupIssueStorage =>
      'Penyimpanan itu tidak menyimpan cadangan di node ini.';

  @override
  String get virtBackupIssueOption =>
      'Bukan mode atau kompresi yang diterima PVE.';

  @override
  String get virtBackupIssueNodeOffline => 'Node tugas ini tidak online.';

  @override
  String get programWaiting => 'Menunggu Anda';

  @override
  String get programWaitingPermission => 'Menunggu persetujuan Anda';

  @override
  String get programWaitingQuestion => 'Menunggu jawaban Anda';

  @override
  String get programWaitingAuth => 'Menunggu Anda masuk';

  @override
  String get programStatus => 'Status program';

  @override
  String get programIdle => 'Tidak aktif';

  @override
  String get programThisShell => 'Shell ini';

  @override
  String get programProgress => 'Progres';

  @override
  String get programCommandRunning => 'Perintah sedang berjalan';

  @override
  String get programCommandSucceeded => 'Perintah terakhir berhasil';

  @override
  String programCommandFailed(int code) {
    return 'Perintah terakhir berakhir dengan kode $code';
  }

  @override
  String get programStatusAlerts => 'Beri tahu saat program membutuhkan Anda';

  @override
  String get programStatusAlertsTip =>
      'Untuk terminal yang tidak terlihat: saat program melaporkan bahwa program menunggu Anda, selesai, atau gagal (OSC 7501, OSC 9;4), atau saat perintah yang berjalan selama setidaknya 30 detik berakhir (OSC 133).';

  @override
  String get termLineHeight => 'Tinggi baris';

  @override
  String get termLineHeightTip =>
      'Ruang yang digunakan satu baris terminal, sebagai kelipatan ukuran font dari 1,0 hingga 2,0. Seperti ukuran font, pengaturan ini memengaruhi jumlah baris yang dapat ditampilkan.';

  @override
  String get termFontTip =>
      'Jika tidak ada file font yang dipilih, terminal menggunakan font monospace sistem, lalu font dengan glif CJK dan emoji untuk karakter yang tidak tersedia.';

  @override
  String get netSpeed => 'Kecepatan jaringan';

  @override
  String get inRange => 'dalam rentang';

  @override
  String threadsFmt(int count) {
    return '$count thread';
  }

  @override
  String get workspace => 'Ruang kerja';

  @override
  String get workspaceTroubleshoot => 'Pemecahan masalah';

  @override
  String workspaceNotConnected(String server) {
    return '$server tidak terhubung';
  }

  @override
  String get workspaceConnectHint =>
      'Server ini diatur agar tidak terhubung saat aplikasi dibuka.';

  @override
  String workspaceAllTabs(int count) {
    return 'Semua tab ($count)';
  }

  @override
  String get workspaceAsleep => 'Tidak terhubung';

  @override
  String workspaceClosed(String what) {
    return '$what ditutup';
  }

  @override
  String get workspaceClosePane => 'Tutup panel';

  @override
  String get workspaceClosePaneHint =>
      'Menutup semua tab di dalamnya; dapat dibatalkan';

  @override
  String get workspaceDropLeft => 'Kiri';

  @override
  String get workspaceDropRight => 'Kanan';

  @override
  String get workspaceDropTop => 'Atas';

  @override
  String get workspaceDropBottom => 'Bawah';

  @override
  String get workspaceDropMerge => 'Gabungkan ke panel ini';

  @override
  String get workspaceEmpty => 'Ruang kerja kosong';

  @override
  String get workspaceEmptyTemplate =>
      'Ruang kerja kosong tidak punya tata letak untuk disimpan';

  @override
  String workspaceFromTemplate(String template, String server) {
    return 'Ruang kerja baru dari “$template” di $server';
  }

  @override
  String get workspaceHidden => 'Tersembunyi';

  @override
  String get workspaceMaximize => 'Maksimalkan';

  @override
  String workspaceMaximized(int pane, int hidden) {
    return 'Panel $pane dimaksimalkan, $hidden disembunyikan';
  }

  @override
  String workspaceMaximizeHint(String keys) {
    return '$keys, atau klik dua kali bilah tab';
  }

  @override
  String get workspaceNewEmpty => 'Ruang kerja kosong baru';

  @override
  String get workspaceNewPane => 'Panel baru';

  @override
  String get workspaceNewTab => 'Tab baru';

  @override
  String get workspaceNewTabFocused => 'Tab baru · di panel yang difokuskan';

  @override
  String get workspaceNoMatch => 'Tidak ada yang cocok';

  @override
  String get workspaceNothingToReopen => 'Tidak ada yang bisa dibuka kembali';

  @override
  String workspacePane(int index) {
    return 'Panel $index';
  }

  @override
  String get workspacePaneActions => 'Tindakan panel';

  @override
  String workspacePaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panel',
    );
    return '$_temp0';
  }

  @override
  String get workspacePanes => 'Panel';

  @override
  String workspacePanesHead(String workspace) {
    return '$workspace · dua panel ditampilkan; panel yang diketuk mendapat fokus';
  }

  @override
  String workspacePaneTabs(int index) {
    return 'Tab panel $index';
  }

  @override
  String workspacePickView(String server) {
    return 'Tab baru di $server · pilih tampilan';
  }

  @override
  String get workspaceQuickOpen => 'Buka cepat';

  @override
  String get workspaceQuickOpenHead =>
      'Buka cepat · Enter membuka yang pertama';

  @override
  String get workspaceQuickOpenHint =>
      'Server, tampilan, tab, atau ruang kerja, mis. db docker';

  @override
  String get workspaceRestore => 'Pulihkan';

  @override
  String get workspaceSaveTemplate => 'Simpan tata letak sebagai templat';

  @override
  String get workspaceSeamTip =>
      'Seret untuk mengubah ukuran, klik dua kali untuk menyamakan';

  @override
  String get workspaceSplitDown => 'Pisah ke bawah';

  @override
  String get workspaceSplitRight => 'Pisah ke kanan';

  @override
  String get workspaceSwitchTo => 'Beralih ke';

  @override
  String get workspaceSwitchWorkspace => 'Ganti ruang kerja';

  @override
  String workspaceSyncBar(int count) {
    return 'Sinkronkan input: ketikan dikirim ke $count terminal di ruang kerja ini';
  }

  @override
  String get workspaceSyncOff => 'Hentikan sinkronisasi input';

  @override
  String get workspaceSyncOn => 'Sinkronkan input ke semua terminal';

  @override
  String get workspaceSyncOnToast =>
      'Sinkronisasi input aktif: ketikan di terminal mana pun dikirim ke semua terminal di ruang kerja ini';

  @override
  String get workspaceSyncOffToast => 'Sinkronisasi input nonaktif';

  @override
  String workspaceTemplateOf(String workspace) {
    return 'Tata letak $workspace';
  }

  @override
  String workspaceTemplateSaved(String name) {
    return 'Templat “$name” disimpan';
  }

  @override
  String get workspaceTemplatesHead =>
      'Templat tata letak · ruang kerja baru di server panel yang difokuskan';

  @override
  String get workspaceMoveTo => 'Pindahkan ke ruang kerja, tetap terhubung';

  @override
  String workspaceMoved(String server, String workspace) {
    return 'Terminal $server dipindahkan ke “$workspace”, tetap terhubung';
  }

  @override
  String get workspaceNew => 'Ruang kerja baru';

  @override
  String get workspaceIntoFocused => 'Ke panel yang difokuskan';

  @override
  String get keybindings => 'Pintasan keyboard';

  @override
  String get kbSearchHint => 'Cari perintah, tombol, atau cakupan';

  @override
  String get kbOnlyModified => 'Hanya yang diubah';

  @override
  String get kbResetAll => 'Atur ulang semua ke bawaan';

  @override
  String get kbResetAllAsk =>
      'Atur ulang semua pintasan di platform ini ke bawaan?';

  @override
  String get kbResetDone => 'Pintasan bawaan dipulihkan';

  @override
  String get kbResetOne => 'Atur ulang ke bawaan';

  @override
  String get kbUnassigned => 'Belum ditetapkan';

  @override
  String get kbFixed => 'Tetap';

  @override
  String get kbModified => 'Diubah';

  @override
  String get kbDefault => 'Bawaan';

  @override
  String get kbFixedHint => 'Tombol ini tidak dapat diubah';

  @override
  String get kbNote =>
      'Terminal di ruang kerja menyerahkan kombinasi ruang kerja dan kombinasi global kepada aplikasi; kombinasi lain di sini tetap diteruskan ke shell. Perintah dengan cakupan berbeda dapat memakai kombinasi yang sama.';

  @override
  String kbCurrent(String keys, String scope) {
    return 'Saat ini: $keys · Cakupan: $scope';
  }

  @override
  String get kbPress => 'Tekan kombinasi tombol';

  @override
  String get kbRecordHint =>
      'Enter untuk konfirmasi, Esc untuk batal. Jika fokus berpindah, ketuk kotak di atas lalu tekan lagi.';

  @override
  String kbConflict(String name, String scope) {
    return 'Bentrok dengan “$name” ($scope)';
  }

  @override
  String get kbConflictNote =>
      'Mengonfirmasi akan menghapus kombinasi ini dari perintah yang bentrok.';

  @override
  String get kbRemove => 'Hapus pintasan';

  @override
  String kbChanged(String name, String keys) {
    return '“$name” sekarang $keys';
  }

  @override
  String get kbScopeGlobal => 'Global';

  @override
  String get kbScopeSettings => 'Halaman pengaturan';

  @override
  String get kbScopeServerTab => 'Tab server';

  @override
  String get kbWsSplitRight => 'Ruang kerja: pisah ke kanan';

  @override
  String get kbWsSplitDown => 'Ruang kerja: pisah ke bawah';

  @override
  String get kbWsFocusLeft => 'Ruang kerja: fokus ke panel kiri';

  @override
  String get kbWsFocusRight => 'Ruang kerja: fokus ke panel kanan';

  @override
  String get kbWsFocusUp => 'Ruang kerja: fokus ke panel atas';

  @override
  String get kbWsFocusDown => 'Ruang kerja: fokus ke panel bawah';

  @override
  String get kbWsNewTab => 'Ruang kerja: tab baru';

  @override
  String get kbWsCloseTab => 'Ruang kerja: tutup tab';

  @override
  String get kbWsNextTab => 'Ruang kerja: tab berikutnya';

  @override
  String get kbWsPrevTab => 'Ruang kerja: tab sebelumnya';

  @override
  String get kbWsTabs => 'Ruang kerja: tab di panel yang difokuskan';

  @override
  String get kbWsReopenTab => 'Ruang kerja: buka kembali tab yang ditutup';

  @override
  String get kbWsMaximize => 'Ruang kerja: maksimalkan atau pulihkan panel';

  @override
  String get kbWsSync => 'Ruang kerja: sinkronkan input ke semua terminal';

  @override
  String get kbWsQuickOpen => 'Ruang kerja: buka cepat';

  @override
  String get kbWsSwitcher => 'Ruang kerja: ganti ruang kerja';

  @override
  String get kbHomeTab => 'Beranda: ke tab 1–9';

  @override
  String get kbAppSettings => 'Buka pengaturan';

  @override
  String get kbSettingsSearch => 'Pengaturan: cari';

  @override
  String get kbServerPrev => 'Server: server sebelumnya';

  @override
  String get kbServerNext => 'Server: server berikutnya';

  @override
  String get kbServerList => 'Server: daftar server';

  @override
  String get kbServerClose => 'Server: tutup detail';

  @override
  String get storageTitle => 'Penyimpanan';

  @override
  String get storageLinuxOnly =>
      'Storage management currently supports Linux servers.';

  @override
  String get storageDisks => 'Disk';

  @override
  String get storageRaid => 'Array RAID';

  @override
  String get storagePools => 'Pool ZFS';

  @override
  String get storageNoFilesystem => 'Tidak ada sistem berkas';

  @override
  String storageUsage(Object total, Object used) {
    return '$used dari $total';
  }

  @override
  String storageFree(Object size) {
    return '$size free';
  }

  @override
  String get storageBusyMounted => 'Sedang digunakan';

  @override
  String get storageBusySwap => 'Memori swap';

  @override
  String get storageBusyRaid => 'Dalam array RAID';

  @override
  String get storageBusyPool => 'Dalam pool';

  @override
  String get storageBusyVolume => 'Memuat volume';

  @override
  String get storageBusyReadOnly => 'Hanya baca';

  @override
  String get storageBusySystem => 'Partisi sistem';

  @override
  String get storageSystemMount =>
      'Sistem menggunakan titik kait ini; titik kait tetap terpasang.';

  @override
  String get storageNotMounted => 'Tidak ada lagi yang terpasang di sana.';

  @override
  String get storageMount => 'Pasang';

  @override
  String get storageUnmount => 'Lepas';

  @override
  String get storageFormat => 'Format disk';

  @override
  String get storageInitialize => 'Inisialisasi';

  @override
  String get storageSmartTest => 'Tes SMART';

  @override
  String get storageFilesystem => 'Sistem berkas';

  @override
  String get storageLabel => 'Label volume';

  @override
  String get storageMountpoint => 'Titik kait';

  @override
  String get storageMountPersist =>
      'Pasang kembali setiap kali mulai (/etc/fstab)';

  @override
  String get storageMountOwn =>
      'Izinkan ServerBox menulis di sini (untuk cadangan)';

  @override
  String get storageName => 'Nama';

  @override
  String get storageLevel => 'Tingkat RAID';

  @override
  String get storageLayout => 'Tata letak';

  @override
  String storagePickDevices(Object count) {
    return 'Pilih sedikitnya $count perangkat. Isinya akan hilang.';
  }

  @override
  String get storageCreateRaid => 'Buat array RAID';

  @override
  String storageCreateRaidBody(Object devices, Object level, Object name) {
    return 'Membuat /dev/$name (RAID $level) dari $devices. Semua data di dalamnya akan hilang.';
  }

  @override
  String get storageCreatePool => 'Buat pool';

  @override
  String storageCreatePoolBody(Object devices, Object layout, Object name) {
    return 'Membuat pool $name ($layout) dari $devices. Semua data di dalamnya akan hilang.';
  }

  @override
  String storageFormatBody(Object device) {
    return 'Membuat sistem berkas baru di $device. Semua datanya akan hilang.';
  }

  @override
  String storageInitializeBody(Object device) {
    return 'Menghapus $device dan membuat satu partisi yang menggunakan seluruh disk. Semua datanya akan hilang.';
  }

  @override
  String storageMountBody(Object device, Object mountpoint) {
    return 'Memasang $device di $mountpoint.';
  }

  @override
  String storageUnmountBody(Object mountpoint) {
    return 'Melepas $mountpoint dan menghentikan pemasangan saat mulai.';
  }

  @override
  String storageSmartTestBody(Object device) {
    return 'Memulai uji mandiri singkat pada $device. Prosesnya perlu beberapa menit; progres dan hasilnya muncul di sini.';
  }

  @override
  String get storageAddMember => 'Tambah disk';

  @override
  String storageAddMemberBody(Object array, Object device) {
    return 'Menambahkan $device ke /dev/$array: menggantikan anggota yang gagal atau menunggu sebagai cadangan. Isinya akan hilang.';
  }

  @override
  String get storageRemoveMember => 'Hapus';

  @override
  String storageRemoveMemberBody(Object array, Object device) {
    return 'Menandai $device gagal dan mengeluarkannya dari /dev/$array. Array tetap berjalan tanpanya; statusnya degraded jika perangkat itu anggota aktif.';
  }

  @override
  String get storageDeleteRaid => 'Hapus array RAID';

  @override
  String storageDeleteRaidBody(Object array) {
    return 'Menghentikan /dev/$array dan menghapus tanda RAID pada anggotanya. Datanya akan hilang.';
  }

  @override
  String get storageDestroyPool => 'Hancurkan pool';

  @override
  String storageDestroyPoolBody(Object name) {
    return 'Menghancurkan pool $name dan semua isinya.';
  }

  @override
  String get storageScrub => 'Pemeriksaan dan perbaikan';

  @override
  String storageScrubBody(Object name) {
    return 'Membaca seluruh pool $name dan memperbaiki bagian yang dapat diperbaiki. Berjalan di latar belakang.';
  }

  @override
  String get storageState => 'Status';

  @override
  String get storageHealthy => 'Sehat';

  @override
  String get storageDegraded => 'Menurun';

  @override
  String storageSync(Object action) {
    return 'Sinkronisasi ($action)';
  }

  @override
  String get storageFaulty => 'Gagal';

  @override
  String get storageSpare => 'Cadangan';

  @override
  String get storageActive => 'Aktif';

  @override
  String get storageScan => 'Pemindaian terakhir';

  @override
  String storageErrors(Object count) {
    return '$count kesalahan';
  }

  @override
  String get storageNoDisks => 'Tidak ada disk';

  @override
  String get storageNoArrays => 'Tidak ada array';

  @override
  String get storageNoPools => 'Tidak ada pool';

  @override
  String get storageNoMdadm =>
      'mdadm belum dipasang: array tidak dapat dibuat atau diubah di sini.';

  @override
  String get storageNoZfs => 'ZFS (zfsutils) belum dipasang.';

  @override
  String storageTypeToConfirm(Object word) {
    return 'Ketik $word untuk mengonfirmasi';
  }

  @override
  String get storageConfirmationMismatch =>
      'The confirmation text did not match.';

  @override
  String storageInUse(Object device) {
    return '$device sedang digunakan.';
  }

  @override
  String get storageBusy => 'Perubahan disk lain sedang berjalan.';

  @override
  String get storageHealthRead => 'Baca kesehatan disk';

  @override
  String get storageHealthWearing => 'Aus';

  @override
  String get storageHealthFailing => 'Bermasalah';

  @override
  String get storageHealthAsleep => 'Tidur';

  @override
  String get storageHealthUnsupported => 'Tanpa SMART';

  @override
  String storageTemperature(Object value) {
    return '$value °C';
  }

  @override
  String storagePowerOn(Object hours) {
    return 'Menyala selama $hours jam';
  }

  @override
  String storageBadSectors(Object count) {
    return '$count sektor rusak';
  }

  @override
  String storageTesting(Object percent) {
    return 'Uji mandiri: tersisa $percent%';
  }

  @override
  String get storageGrowPartition => 'Perbesar partisi';

  @override
  String storageGrowPartitionBody(Object device) {
    return 'Perbesar $device ke ruang kosong setelahnya. Perbesar sistem berkasnya setelah itu.';
  }

  @override
  String get storageEncrypt => 'Enkripsi (LUKS)';

  @override
  String get storagePassphrase => 'Frasa sandi';

  @override
  String get storagePassphraseAgain => 'Ulangi';

  @override
  String get storagePassphraseHint =>
      'Minimal 8 karakter. Tanpanya data tidak dapat dibaca: simpan dengan aman.';

  @override
  String get storageInvalidPassphrase =>
      'Frasa sandi harus terdiri dari 8 hingga 512 karakter dalam satu baris.';

  @override
  String get storagePassphrasesDiffer => 'Frasa sandi tidak sama.';

  @override
  String get storageEncrypted => 'Terenkripsi';

  @override
  String get storageLocked => 'Terkunci';

  @override
  String get storageUnlock => 'Buka kunci';

  @override
  String storageUnlockBody(Object device) {
    return 'Buka $device dengan frasa sandinya.';
  }

  @override
  String get storageLock => 'Kunci';

  @override
  String storageLockBody(Object device) {
    return 'Tutup $device. Sistem berkasnya harus dilepas terlebih dahulu.';
  }

  @override
  String get storageReplace => 'Ganti';

  @override
  String storageReplaceBody(Object name, Object old, Object replacement) {
    return 'Ganti $old di pool $name dengan $replacement. Pool menyalin data ke sana; isi $replacement akan hilang.';
  }

  @override
  String get storageAttach => 'Cerminkan';

  @override
  String storageAttachBody(Object existing, Object replacement) {
    return 'Cerminkan $existing ke $replacement. Isi $replacement akan hilang.';
  }

  @override
  String get storageAddSpare => 'Tambah cadangan';

  @override
  String storageAddSpareBody(Object devices, Object name) {
    return 'Tambahkan $devices ke pool $name sebagai perangkat cadangan. Isinya akan hilang.';
  }

  @override
  String get storageRemoveDevice => 'Hapus';

  @override
  String storageRemoveDeviceBody(Object device, Object name) {
    return 'Keluarkan $device dari pool $name.';
  }

  @override
  String get storageOnline => 'Aktifkan kembali';

  @override
  String storageOnlineBody(Object device, Object name) {
    return 'Masukkan $device kembali ke pool $name, lalu perluas hingga seluruh disk.';
  }

  @override
  String get storageDetails => 'Detail';

  @override
  String get storageAttributes => 'Atribut';

  @override
  String get storageAttrValue => 'Nilai';

  @override
  String get storageAttrWorst => 'Terburuk';

  @override
  String get storageAttrThresh => 'Ambang';

  @override
  String get storageSelfTests => 'Uji mandiri';

  @override
  String get storageTestShort => 'Singkat';

  @override
  String get storageTestLong => 'Panjang';

  @override
  String get storageTestPassed => 'Lulus';

  @override
  String get storageTestFailed => 'Gagal';

  @override
  String get storageTestAborted => 'Dihentikan';

  @override
  String storageAtHours(Object hours) {
    return 'pada $hours jam';
  }

  @override
  String get storageNothingToShow => 'Tidak ada yang ditampilkan';

  @override
  String get storageLongTest => 'Uji panjang';

  @override
  String storageSmartLongTestBody(Object device) {
    return 'Mulai uji mandiri panjang pada $device. Uji membaca seluruh disk: dapat memakan waktu berjam-jam.';
  }

  @override
  String get storageMountedInside => 'Lepas sistem berkasnya terlebih dahulu.';

  @override
  String get storageNotRemovable =>
      'Hanya perangkat cadangan atau cache yang dapat dilepas di sini.';

  @override
  String get storageNotGrowable => 'This device cannot be grown here.';

  @override
  String get storageOverlapping => 'Choose devices that do not overlap.';

  @override
  String get storageInvalidDevice =>
      'The device is invalid or no longer available.';

  @override
  String get storageInvalidMountpoint => 'The mount point is invalid.';

  @override
  String get storageInvalidName => 'The name is invalid.';

  @override
  String get storageInvalidFilesystem => 'The filesystem is not supported.';

  @override
  String get storageInvalidLabel => 'The label is invalid.';

  @override
  String get storageInvalidLevel => 'The RAID level or pool layout is invalid.';

  @override
  String get storageTooFewDevices => 'Not enough valid devices were selected.';

  @override
  String get storageExpand => 'Perluas';

  @override
  String storageExpandBody(Object device) {
    return 'Memperluas sistem berkas pada $device hingga memenuhi seluruh perangkat. Perangkat tetap terpasang.';
  }

  @override
  String get storageGrowRaid => 'Perbesar';

  @override
  String storageGrowRaidBody(Object array, Object device) {
    return 'Menambahkan $device ke /dev/$array sebagai anggota aktif tambahan. RAID 1 mendapat satu cermin lagi; RAID 5 dan 6 mendapat ruang tambahan setelah proses penyusunan ulang selesai, yang dapat memerlukan waktu berjam-jam. Setelah itu, perluas sistem berkasnya. Isi $device akan hilang.';
  }

  @override
  String get storageAddToPool => 'Tambah disk';

  @override
  String storageAddToPoolBody(Object devices, Object layout, Object name) {
    return 'Menambahkan $devices dengan tata letak $layout ke pool $name untuk menambah ruang. Disk tidak dapat dilepas lagi dan isinya akan hilang.';
  }

  @override
  String get sharingTitle => 'Berbagi';

  @override
  String get sharingSmb => 'SMB';

  @override
  String get sharingNfs => 'NFS';

  @override
  String get sharingService => 'Layanan';

  @override
  String get sharingRunning => 'Berjalan';

  @override
  String get sharingStopped => 'Berhenti';

  @override
  String get sharingNfsServer => 'Server NFS';

  @override
  String get sharingNoSamba =>
      'Samba belum dipasang. Windows, macOS, dan Linux dapat membuka berbagi SMB.';

  @override
  String get sharingNoNfs =>
      'Server NFS belum dipasang. Linux dan macOS dapat memasang ekspor NFS.';

  @override
  String get sharingInstallSamba => 'Pasang Samba';

  @override
  String get sharingInstallSambaBody =>
      'Memasang Samba dengan pengelola paket mesin.';

  @override
  String get sharingInstallNfs => 'Pasang server NFS';

  @override
  String get sharingInstallNfsBody =>
      'Memasang server NFS dengan pengelola paket mesin.';

  @override
  String get sharingAddShare => 'Tambah berbagi';

  @override
  String get sharingAddExport => 'Tambah ekspor';

  @override
  String get sharingEdit => 'Edit';

  @override
  String get sharingRemove => 'Hapus';

  @override
  String get sharingSave => 'Simpan';

  @override
  String sharingSaveSmbBody(Object name, Object path) {
    return 'Membagikan $path melalui SMB dengan nama $name, lalu memuat ulang Samba.';
  }

  @override
  String sharingSaveNfsBody(Object path) {
    return 'Mengekspor $path melalui NFS, lalu memuat ulang daftar ekspor.';
  }

  @override
  String sharingRemoveSmbBody(Object name) {
    return 'Berhenti membagikan $name. Folder dan berkasnya tetap ada.';
  }

  @override
  String sharingRemoveNfsBody(Object path) {
    return 'Berhenti mengekspor $path. Folder dan berkasnya tetap ada.';
  }

  @override
  String get sharingElsewhere => 'Atur di luar ServerBox';

  @override
  String get sharingNoShares => 'Tidak ada berbagi SMB';

  @override
  String get sharingNoExports => 'Tidak ada ekspor NFS';

  @override
  String get sharingReadOnly => 'Hanya baca';

  @override
  String get sharingReadWrite => 'Baca dan tulis';

  @override
  String get sharingGuest => 'Tamu';

  @override
  String get sharingGuestLabel =>
      'Izinkan siapa pun di jaringan mengakses tanpa akun';

  @override
  String get sharingUsersHint =>
      'Akun yang diizinkan (tidak ada yang dicentang: semua akun dengan kata sandi SMB):';

  @override
  String get sharingFolder => 'Folder';

  @override
  String get sharingFolderHint =>
      'Folder di server, misalnya disk yang dipasang melalui Storage.';

  @override
  String get sharingComment => 'Deskripsi';

  @override
  String get sharingPasswords => 'Kata sandi SMB';

  @override
  String get sharingPasswordsBody =>
      'Samba menyimpan kata sandinya sendiri: tetapkan satu kata sandi untuk setiap akun yang terhubung.';

  @override
  String get sharingSetPassword => 'Tetapkan kata sandi';

  @override
  String get sharingNewPassword => 'Kata sandi SMB baru';

  @override
  String get sharingNewPasswordAgain => 'Ulangi kata sandi';

  @override
  String get sharingPasswordsDiffer => 'Kedua kata sandi berbeda.';

  @override
  String get sharingClientsHint =>
      'Siapa yang boleh memasangnya: * untuk siapa pun, host, alamat, atau jaringan seperti 192.168.1.0/24.';

  @override
  String get sharingClient => 'Klien';

  @override
  String get sharingAddClient => 'Tambah klien';

  @override
  String get sharingSquashRoot => 'root menjadi nobody';

  @override
  String get sharingSquashAll => 'Semua orang menjadi nobody';

  @override
  String get sharingSquashNone => 'root tetap root';

  @override
  String sharingNotAFolder(Object path) {
    return '$path bukan folder di server.';
  }

  @override
  String sharingRefused(Object detail) {
    return 'Konfigurasi ditolak dan konfigurasi sebelumnya dipulihkan: $detail';
  }

  @override
  String get sharingDuplicate =>
      'Berbagi lain sudah menggunakan nama atau folder ini.';

  @override
  String get sharingInvalidName =>
      'Nama hanya boleh berisi huruf, angka, dan _ . - (maksimal 32 karakter).';

  @override
  String get sharingInvalidPath =>
      'Folder harus berupa jalur absolut tanpa tanda kutip, garis miring terbalik, atau ..';

  @override
  String get sharingInvalidClient =>
      'Klien dapat berupa *, host, alamat, atau jaringan.';

  @override
  String get sharingInvalidPassword => 'Kata sandi ini tidak dapat digunakan.';

  @override
  String get sharingTimeMachineOption => 'Cadangan Time Machine (Mac)';

  @override
  String get sharingRecycleOption => 'Simpan berkas yang dihapus di .recycle';

  @override
  String get sharingTimeMachine => 'Time Machine';

  @override
  String get sharingRecycle => 'Tempat sampah';

  @override
  String get sharingConnectedNow => 'Terhubung sekarang';

  @override
  String get sharingNobodyConnected => 'Tidak ada yang terhubung';

  @override
  String get sharingShowConnections => 'Tampilkan koneksi';

  @override
  String get sharingShowConnectionsBody => 'Membaca koneksi sebagai root.';

  @override
  String get sharingConnectionsLinuxOnly =>
      'Sharing management currently supports Linux servers.';

  @override
  String get agentThisDevice => 'Perangkat ini';

  @override
  String get agentSource => 'Sumber';

  @override
  String agentDeleteRemoteTip(String server) {
    return 'Tugas akan dihapus di $server.';
  }

  @override
  String get agentPlan => 'Rencana';

  @override
  String get agentRemoteGone => 'Tugas ini sudah tidak ada di server.';

  @override
  String agentRemoteReplyHint(String server) {
    return 'Balas tugas di $server';
  }

  @override
  String agentRemoteStatus(String server, String status) {
    String _temp0 = intl.Intl.selectLogic(status, {
      'queued': 'Dalam antrean',
      'running': 'Berjalan',
      'waiting': 'Menunggu tanggapan Anda',
      'done': 'Selesai',
      'failed': 'Gagal',
      'cancelled': 'Dihentikan',
      'other': '',
    });
    return '$server · $_temp0';
  }

  @override
  String agentRemoteAlways(String rule) {
    return 'Selalu izinkan $rule';
  }

  @override
  String agentRemoteTypeToRun(String name) {
    return 'Ketik $name untuk menjalankan';
  }

  @override
  String get agentRemoteRunAnyway => 'Tetap jalankan';

  @override
  String agentRemoteSudoFor(String user) {
    return 'Kata sandi $user';
  }

  @override
  String get agentRemoteSudoWrong => 'Kata sandi salah';

  @override
  String get agentRemoteSudoRemember => 'Ingat selama 15 menit';

  @override
  String agentNewOn(String place) {
    return 'Percakapan baru: $place';
  }

  @override
  String agentRemoteNewHint(String server) {
    return 'Ajukan pertanyaan kepada agent di $server, atau berikan tugas.';
  }

  @override
  String get agentPermissionMode => 'Mode izin';

  @override
  String get agentModeAuto => 'Otomatis';

  @override
  String get agentModeManual => 'Manual';

  @override
  String get agentModeBypass => 'Izinkan semua';

  @override
  String get agentModeBypassOff => 'Dinonaktifkan di server ini';

  @override
  String get agentModeBypassWarn =>
      'Izinkan semua: penghapusan, mulai ulang, dan perubahan konfigurasi dijalankan tanpa konfirmasi.';

  @override
  String get webApps => 'Aplikasi web';

  @override
  String get webAppUnhealthy => 'Tidak sehat';

  @override
  String get webAppDown => 'Mati';

  @override
  String get webAppInstalling => 'Menginstal';

  @override
  String get webAppsEmpty =>
      'Belum ada aplikasi web. Pasang dari App Store di panel Monitor.';

  @override
  String get deskAppOpensInPanel => 'Dibuka di panel';

  @override
  String get webAppVersion => 'Versi';

  @override
  String get webAppHomepage => 'Situs web';

  @override
  String webAppUpdate(String version) {
    return 'Versi $version tersedia. Perbarui dari panel Monitor.';
  }

  @override
  String noticeStackDown(String app) {
    return '$app sedang tidak berjalan';
  }

  @override
  String noticeStackDownBody(String services) {
    return 'Tidak berjalan: $services.';
  }

  @override
  String get noticeStackDownBodyEmpty => 'Tidak ada kontainer yang berjalan.';

  @override
  String noticeStackUnhealthy(String app) {
    return '$app bermasalah';
  }

  @override
  String noticeStackUnhealthyBody(String services) {
    return 'Pemeriksaan kesehatan gagal: $services.';
  }

  @override
  String noticeStackBack(String app) {
    return '$app berjalan kembali';
  }

  @override
  String get noticeStackBackBody => 'Semua kontainer berjalan.';

  @override
  String noticeStackUpdate(String app) {
    return 'Pembaruan untuk $app tersedia';
  }

  @override
  String noticeStackUpdateBody(String project, String version, String current) {
    return '$project $version dapat dipasang (saat ini: $current).';
  }

  @override
  String noticeStorageArrayDegraded(String array) {
    return '/dev/$array mengalami penurunan';
  }

  @override
  String get noticeStorageArrayDegradedBody =>
      'Satu anggota gagal atau hilang; array berjalan tanpa redundansi.';

  @override
  String noticeStorageArrayBack(String array) {
    return '/dev/$array kembali sehat';
  }

  @override
  String get noticeStorageArrayBackBody => 'Semua anggota berfungsi.';

  @override
  String noticeStoragePoolUnhealthy(String pool, String health) {
    return 'Pool $pool $health';
  }

  @override
  String get noticeStoragePoolUnhealthyBody =>
      'Buka Storage untuk melihat perangkat yang bermasalah.';

  @override
  String noticeStoragePoolBack(String pool) {
    return 'Pool $pool kembali online';
  }

  @override
  String get noticeStoragePoolBackBody => 'Semua perangkat berfungsi.';

  @override
  String noticeStorageDiskFailing(String device) {
    return '$device mengalami kerusakan';
  }

  @override
  String get noticeStorageDiskFailingBody =>
      'Pemeriksaan SMART atau uji mandirinya gagal: salin isinya ke tempat lain dan ganti disk tersebut.';

  @override
  String noticeStorageDiskSectors(String device, int count) {
    return '$device memiliki $count sektor rusak';
  }

  @override
  String noticeStorageDiskSectorsBody(int was) {
    return 'Sebelumnya ada $was. Disk yang kehilangan sektor sering segera mengalami kerusakan.';
  }

  @override
  String noticeStorageMaintenanceFailed(String task) {
    return 'Pemeliharaan storage tidak berjalan: $task';
  }

  @override
  String get storageTaskScrub => 'Periksa pool dan array';

  @override
  String get storageTaskSmartShort => 'Uji SMART singkat';

  @override
  String get storageTaskSmartLong => 'Uji SMART panjang';

  @override
  String get storageNeedsSudo =>
      'sudo meminta kata sandi: jalankan agent sebagai root atau izinkan perintah di atas.';

  @override
  String get monitorTab => 'Monitor';

  @override
  String get monitorOverview => 'Ringkasan';

  @override
  String get monitorNotices => 'Notifikasi';

  @override
  String get monitorAudit => 'Log audit';

  @override
  String get monitorLive => 'Sesi & perangkat';

  @override
  String get monitorNoAgents =>
      'Belum ada server yang terhubung melalui agen Monitor.';

  @override
  String get monitorNotOffered =>
      'Versi agen ini tidak menyediakannya. Perbarui agen.';

  @override
  String get monitorAlertsNotOffered =>
      'Versi agen ini tidak melaporkan peringatan.';

  @override
  String get monitorAlertsNone => 'Tidak ada aturan yang terpicu.';

  @override
  String monitorFiringFor(String duration) {
    return 'aktif selama $duration';
  }

  @override
  String monitorAgentVersion(String version) {
    return 'Agen $version';
  }

  @override
  String monitorAgentUpdate(String version) {
    return '$version tersedia';
  }

  @override
  String monitorUnread(int count) {
    return '$count belum dibaca';
  }

  @override
  String monitorAppsUnwell(int count) {
    return 'Aplikasi bermasalah: $count';
  }

  @override
  String monitorAppsUpdates(int count) {
    return 'Pembaruan aplikasi: $count';
  }

  @override
  String get monitorUpdatesOnly => 'Hanya pembaruan';

  @override
  String get monitorNoUpdates => 'Tidak ada aplikasi yang punya pembaruan.';

  @override
  String get monitorNoticesEmpty => 'Tidak ada notifikasi.';

  @override
  String get monitorMarkAllRead => 'Tandai semua sudah dibaca';

  @override
  String get monitorAuditExec => 'Perintah';

  @override
  String get monitorAuditMachine => 'Manajemen mesin';

  @override
  String get monitorAuditListen => 'Port yang didengarkan';

  @override
  String get monitorAuditTicket => 'Tiket koneksi';

  @override
  String get monitorAuditPush => 'Saluran notifikasi';

  @override
  String get monitorAuditAdmin => 'Akun';

  @override
  String get monitorAuditDenied => 'Ditolak';

  @override
  String get monitorLoadMore => 'Muat lebih banyak';

  @override
  String get monitorLiveSessions => 'Sesi terminal';

  @override
  String get monitorLiveConnections => 'Koneksi';

  @override
  String get monitorLiveWatchTokens => 'Token jam tangan dan widget';

  @override
  String get monitorLiveDevices => 'Perangkat yang masuk';

  @override
  String get monitorLiveDevicesTip =>
      'Melupakan perangkat membuat proses masuk berikutnya dihitung dalam batas percobaan gagal seluruh akun. Ini tidak mengeluarkan perangkat: perangkat yang punya kata sandi akan masuk lagi. Ubah kata sandi untuk menolak sebuah perangkat.';

  @override
  String get monitorLiveAttached => 'Terhubung';

  @override
  String get monitorLiveDetached => 'Terputus';

  @override
  String get monitorLiveEnd => 'Akhiri';

  @override
  String get monitorLiveRevoke => 'Cabut';

  @override
  String get monitorLiveForget => 'Lupakan';

  @override
  String monitorLiveEndSessionConfirm(String name) {
    return 'Akhiri sesi terminal \"$name\"? Yang berjalan di dalamnya akan berhenti.';
  }

  @override
  String monitorLiveEndConnectionConfirm(String name) {
    return 'Akhiri koneksi ke $name?';
  }

  @override
  String monitorLiveRevokeConfirm(String name) {
    return 'Cabut token $name? Pembaruan berhenti sampai disiapkan lagi.';
  }

  @override
  String monitorLiveForgetConfirm(String name) {
    return 'Lupakan $name?';
  }

  @override
  String monitorLiveExpires(String time) {
    return 'Kedaluwarsa $time';
  }

  @override
  String get monitorLiveStream => 'Koneksi yang diteruskan';

  @override
  String get monitorLiveAccepted => 'Koneksi yang diteruskan masuk';

  @override
  String get monitorLiveConsole => 'Konsol';

  @override
  String monitorAgentsCount(int count) {
    return '$count agen';
  }

  @override
  String get monitorStatOnline => 'Daring';

  @override
  String get monitorStatFiring => 'Peringatan aktif';

  @override
  String get monitorStatUnread => 'Belum dibaca';

  @override
  String get monitorStatUpdates => 'Pembaruan aplikasi';

  @override
  String get monitorAuditEmpty => 'Tidak ada catatan yang cocok.';

  @override
  String get monitorLiveNoSessions => 'Tidak ada sesi terminal yang terbuka.';

  @override
  String get monitorLiveNoConnections => 'Tidak ada yang diteruskan.';

  @override
  String get monitorLiveNoTokens =>
      'Tidak ada jam tangan atau widget yang dipasangkan.';

  @override
  String get monitorLiveNoDevices => 'Belum ada perangkat yang masuk.';

  @override
  String get monitorUpdateAgent => 'Perbarui agen';

  @override
  String get monitorAgentTooOldTip =>
      'Langkah memperbaruinya ada di tab Monitor.';

  @override
  String get monitorAgentTooOldBody =>
      'Agen ini dari sebelum hanya memakai satu kata sandi, dan aplikasi tidak bisa masuk. Setelah diperbarui, kata sandinya adalah milik akun admin tertuanya.';

  @override
  String monitorAgentOutdatedBody(String latest, String running) {
    return '$latest telah rilis; agen ini menjalankan $running.';
  }

  @override
  String get monitorUpdateRunHint =>
      'Jalankan di server, dengan akun yang dipakai memasang agen:';

  @override
  String get monitorUpdateSshHint =>
      'Terminal menjalankannya. Jika agen dipasang untuk seluruh sistem dan terminal lewat SSH, sudo akan meminta kata sandinya di sana.';

  @override
  String get monitorUpdateNoSsh =>
      'Aplikasi tidak dapat membuka terminal di server ini: jalankan sendiri di sana.';

  @override
  String get monitorUpdateDocker =>
      'Di Docker? Tarik image baru lalu buat ulang kontainernya.';

  @override
  String get monitorUpdateAfter =>
      'Setelah dimulai ulang, segarkan tab Monitor.';

  @override
  String get monitorUpdateInTerminal => 'Jalankan di terminal';

  @override
  String get monitorHowToUpdate => 'Cara memperbarui';

  @override
  String get monitorUpdateNix =>
      'Dipasang lewat modul NixOS: perbarui melalui konfigurasi sistem lalu rebuild.';

  @override
  String get noticeAgentUpdate => 'Ada pembaruan untuk agen';

  @override
  String get monitorUpdateLegacyUser => 'Nama akun';

  @override
  String get monitorUpdateLegacyHint =>
      'Agen ini masih masuk dengan nama akun dan kata sandi: nama yang dulu dipakai aplikasi ini (biasanya admin) dan kata sandi tersimpan.';

  @override
  String get monitorUpdateNow => 'Perbarui sekarang';

  @override
  String get monitorUpdating => 'Memperbarui…';

  @override
  String get monitorUpdateRestarting =>
      'Agen sedang dimulai ulang; koneksi kembali dalam beberapa detik…';

  @override
  String monitorUpdateDone(String version) {
    return 'Diperbarui: agen menjalankan $version.';
  }

  @override
  String get monitorUpdateFailed => 'Pembaruan gagal. Keluarannya ada di atas.';

  @override
  String get monitorUpdateAgentHint =>
      'Agen menjalankan penginstal terpisah dari dirinya, jadi mulai ulang tidak menghentikan pembaruan. Selama itu koneksi terputus beberapa detik; jendela ini mengikuti pembaruan melewati mulai ulang.';

  @override
  String get monitorUpdateSudoPassword => 'Kata sandi sudo';

  @override
  String get monitorUpdateSudoHint =>
      'Di sini penginstal perlu root (layanan OpenRC). Kata sandi dipakai sekali dan tidak disimpan.';

  @override
  String get monitorUpdateSudoRefused => 'sudo tidak menerima kata sandi ini.';

  @override
  String get monitorUpdateNoAnswer => 'Agen tidak kembali. Periksa di server.';

  @override
  String get keyArrowDown => 'Panah bawah';

  @override
  String get keyArrowLeft => 'Panah kiri';

  @override
  String get keyArrowRight => 'Panah kanan';

  @override
  String get keyArrowUp => 'Panah atas';

  @override
  String get keyControl => 'Control';

  @override
  String get keyEscape => 'Escape';

  @override
  String get keyPageDown => 'Halaman bawah';

  @override
  String get keyPageUp => 'Halaman atas';

  @override
  String get termTextView => 'Lihat sebagai teks';

  @override
  String termTextLetGo(int count) {
    return 'Baris sebelumnya tidak lagi disimpan: $count';
  }

  @override
  String get systemGroups => 'Grup';

  @override
  String get userGid => 'GID';

  @override
  String get userGroupMembers => 'Anggota';

  @override
  String get userPrimaryMembers => 'Anggota utama';

  @override
  String get userSystemGroup => 'Grup sistem';

  @override
  String get userMembersHint => 'alice,bob';

  @override
  String get userRegularGroup => 'Regular';

  @override
  String get termMetricsBar => 'Pembacaan server di bawah terminal';

  @override
  String get termMetricsBarTip =>
      'CPU, memori, jaringan, dan disk, seperti pada kartu server. Di ponsel, di atas tombol virtual.';

  @override
  String get launchFailedTitle => 'ServerBox tidak dapat dimulai';

  @override
  String get launchFailedBody =>
      'Salin galat di bawah dan laporkan di issue GitHub, beserta berkas log.';

  @override
  String launchFailedLogs(String path) {
    return 'Log: $path';
  }

  @override
  String get reconnect => 'Sambungkan ulang';

  @override
  String get reconnectEndsShell =>
      'Tidak ada sesi tmux untuk dipasang kembali, jadi menyambungkan ulang akan mengakhiri shell ini dan semua yang masih berjalan di dalamnya, serta menghapus keluarannya dari layar.';

  @override
  String get handedness => 'Tangan dominan';

  @override
  String get handednessLeft => 'Tangan kiri';

  @override
  String get handednessRight => 'Tangan kanan';

  @override
  String get handednessTip =>
      'Di sisi tangan yang memegang perangkat, tab berada di kolom di samping bilah status, seperti bilah milik sistem.';

  @override
  String get storeUnreadableTitle => 'Data sebelumnya tidak dapat dibuka';

  @override
  String get storeUnreadableKeyLost =>
      'Kunci yang mengenkripsi data ServerBox sudah tidak ada di penyimpanan kunci sistem. Ini terjadi ketika sistem mengatur ulang penyimpanan kunci, ketika layanan keyring tidak tersedia, atau ketika data aplikasi disalin dari perangkat lain, misalnya dengan alat migrasi. Tanpa kunci itu data tidak dapat didekripsi, jadi ServerBox dimulai tanpa data.';

  @override
  String get storeUnreadableKeyRejected =>
      'Kunci di penyimpanan kunci sistem tidak membuka data ServerBox: data dienkripsi dengan kunci lain, atau berkasnya rusak. ServerBox dimulai tanpa data.';

  @override
  String storeUnreadableKept(String path) {
    return 'Berkas lama disimpan di:\n$path\nPulihkan cadangan untuk mendapatkan kembali server Anda.';
  }

  @override
  String get storeKeyLostAsk =>
      'Kunci yang mengenkripsi data ServerBox tidak ada di penyimpanan kunci sistem. Jika penyimpanan kunci atau keyring hanya sedang tidak tersedia, misalnya belum dibuka kuncinya, coba lagi. Jika tidak, ServerBox dapat dimulai tanpa data; file lama tetap disimpan.';

  @override
  String get storeKeyLostStartEmpty => 'Mulai tanpa data';

  @override
  String get storeVaultFailedAsk =>
      'Penyimpanan kunci sistem tidak dapat mendekripsi kunci yang mengenkripsi data ServerBox. Jika kesalahan ini hanya sekali, coba lagi, bila perlu setelah memulai ulang perangkat. Jika selalu gagal, data tidak dapat didekripsi dan ServerBox dapat dimulai tanpa data; file lama tetap disimpan. Memulai tanpa data juga menghapus kata sandi cadangan, kredensial WebDAV dan GitHub, serta kata sandi sudo yang tersimpan.';

  @override
  String get storeVaultFailedRootHint =>
      'Pada perangkat yang di-root, modul yang mencegat penyimpanan kunci (seperti TrickyStore) menyebabkan kesalahan ini. Hapus aplikasi ini dari daftar target modul, lalu mulai tanpa data.';

  @override
  String get storeUnreadableVaultFailed =>
      'Penyimpanan kunci sistem tidak dapat mendekripsi kunci yang mengenkripsi data ServerBox, sehingga ServerBox mengatur ulang entrinya di penyimpanan kunci dan dimulai tanpa data. Kata sandi cadangan, kredensial WebDAV dan GitHub, serta kata sandi sudo yang tersimpan harus dimasukkan lagi.';

  @override
  String get hostCertAuthorities => 'Otoritas sertifikat host';

  @override
  String get hostCertAuthoritiesTip =>
      'Host yang sertifikatnya ditandatangani salah satu otoritas ini dipercaya tanpa ditanya, seperti @cert-authority OpenSSH; host lain ditanyakan saat koneksi pertama seperti sebelumnya. Host adalah pola yang dipisahkan koma dengan * dan ?, serta ! untuk mengecualikan; port selain 22 dicocokkan sebagai [host]:port.';

  @override
  String get hostCertAuthorityInvalid =>
      'Bukan kunci publik SSH yang didukung (ssh-ed25519, ssh-rsa, atau ecdsa-sha2-*)';

  @override
  String get hostCertAuthorityNoHosts =>
      'Masukkan host yang dijaminnya, misalnya *';

  @override
  String get hostCertAuthorityExists => 'Sudah ada di daftar';
}
