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
  String get crashCollectFull => 'Informasi lengkap';

  @override
  String get crashCollectFullTip =>
      'Selain log kerusakan, data performa dan penggunaan fitur juga disertakan: **Berguna untuk menemukan apa yang lambat dan fitur mana yang benar-benar dipakai.**';

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
  String get askAiAwaitingResponse => 'Menunggu respons AI...';

  @override
  String get askAiEndpointTip =>
      'Domain atau URL lengkap. Path dilengkapi dari protokol yang dipilih.';

  @override
  String get askAiProtocolTip =>
      'Auto mencoba Responses, lalu Chat Completions.';

  @override
  String get askAiCommandInserted => 'Perintah dimasukkan ke terminal';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Harap konfigurasikan $fields di Pengaturan.';
  }

  @override
  String get askAiDisclaimer => 'AI bisa saja salah. Gunakan dengan hati-hati.';

  @override
  String get askAiInsertTerminal => 'Masukkan ke terminal';

  @override
  String get askAiNoResponse => 'Tidak ada respons';

  @override
  String get remoteDesktop => 'Remote desktop';

  @override
  String get askAiAgentWelcome => 'Apa yang akan kita lakukan di server ini?';

  @override
  String get askAiAgentPromptHint =>
      'Minta Agent memeriksa atau memperbaiki sesuatu...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analisis keluaran terminal yang dipilih dan jelaskan apa yang terjadi';

  @override
  String get askAiTerminalContext => 'Konteks terminal';

  @override
  String get askAiReviewNeeded => 'Tinjau';

  @override
  String get askAiReviewAction => 'Tinjau perintah yang diusulkan';

  @override
  String get askAiReviewBeforeContinuing =>
      'Tinjau atau tolak saran saat ini dulu';

  @override
  String get askAiApproveRun => 'Setujui & jalankan';

  @override
  String get askAiDecline => 'Tolak';

  @override
  String get askAiActionDeclined => 'Perintah yang diusulkan ditolak.';

  @override
  String get askAiInterrupted => 'Respons Agent terputus.';

  @override
  String get askAiResend => 'Resend';

  @override
  String get askAiResendTip =>
      'Everything after this message is discarded — the replies, the commands and their results.';

  @override
  String get askAiDeleteTip =>
      'This message and everything after it are removed — the replies, the commands and their results.';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'Context sizes by model name, from models.dev. One ships with the app; tap to fetch a newer one.';

  @override
  String get askAiContextFallback => 'not in the table';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      'How full the model’s context gets before earlier turns are summarised. Earlier loses detail sooner; later risks a request the model refuses.';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'How many tokens this model holds. Automatic looks it up by name; set a number when your provider serves a shorter window than the model has.';

  @override
  String get askAiConversationCompacted =>
      'Earlier messages were summarised to keep the conversation going.';

  @override
  String get askAiRiskReadOnly => 'Hanya baca';

  @override
  String get askAiRiskCaution => 'Mengubah sistem';

  @override
  String get askAiRiskUnvetted => 'Host belum diverifikasi';

  @override
  String get askAiRiskDestructive => 'Risiko tinggi';

  @override
  String get askAiHighRiskConfirmTitle => 'Jalankan perintah berisiko tinggi?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Perintah ini bisa membuat perubahan yang sulit dibatalkan. Periksa baik-baik.';

  @override
  String get askAiNoCommandOutput => 'Perintah selesai tanpa keluaran.';

  @override
  String get askAiOutputTruncated =>
      'Keluaran panjang dipotong sebelum dikirim kembali ke Agent.';

  @override
  String get askAiAutoApproved => 'Disetujui otomatis';

  @override
  String get askAiAutoRunSafeCommands =>
      'Jalankan otomatis perintah hanya-baca';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Hanya jalan jika model dan pemeriksaan lokal sama-sama menyebutnya hanya-baca';

  @override
  String get askAiSendOnEnter => 'Enter mengirim';

  @override
  String get askAiSendOnEnterTip =>
      'Enter mengirim, Shift+Enter baris baru. Mati: Enter baris baru, Cmd/Ctrl+Enter mengirim.';

  @override
  String get askAiApiKeyOptional =>
      'Kosongkan untuk lokal atau tanpa autentikasi';

  @override
  String get askAiAllowInsecure => 'Izinkan HTTP tanpa enkripsi';

  @override
  String get askAiAllowInsecureTip =>
      'Mengizinkan koneksi http:// ke model yang di-host sendiri pada alamat selain localhost. Kunci API dan konteks terminal akan dikirim tanpa enkripsi; localhost tidak terpengaruh.';

  @override
  String get askAiInsecureEndpoint =>
      'Endpoint ini menggunakan http://. Aktifkan “Izinkan HTTP tanpa enkripsi” di pengaturan AI untuk menggunakannya.';

  @override
  String get askAiHistory => 'Riwayat percakapan';

  @override
  String get askAiNewConversation => 'Percakapan baru';

  @override
  String get askAiNoHistory => 'Belum ada percakapan tersimpan';

  @override
  String get askAiNoHistoryMessages => 'Belum ada pesan';

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
  String get askAiClearHistoryTitle => 'Hapus riwayat Agent untuk server ini?';

  @override
  String get askAiClearHistoryTip =>
      'Semua percakapan Agent tersimpan untuk server ini akan dihapus.';

  @override
  String get askAiRestoredReview => 'Perintah ini dari riwayat. Tinjau lagi';

  @override
  String get agentWelcome => 'Apa yang akan kita lakukan di server Anda?';

  @override
  String get agentWelcomeTip =>
      'Biarkan Agent mendiagnosis masalah atau menjalankan tugas';

  @override
  String get agentPromptHint =>
      'Minta Agent memeriksa atau mengoperasikan server Anda...';

  @override
  String get agentNoHistory =>
      'Tidak ada percakapan Agent global yang tersimpan';

  @override
  String get agentClearHistoryTitle => 'Hapus riwayat Agent global?';

  @override
  String get agentClearHistoryTip =>
      'Semua percakapan Agent global akan dihapus dari perangkat ini.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Baca berkas';

  @override
  String get agentToolWriteFile => 'Tulis berkas';

  @override
  String get agentToolFailed => 'Eksekusi alat gagal.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count panggilan alat';
  }

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
  String nTags(Object count) {
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
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
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
  String clearServerStatsContent(Object serverName) {
    return 'Apakah Anda yakin ingin menghapus statistik koneksi untuk server \"$serverName\"? Tindakan ini tidak dapat dibatalkan.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
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
  String get cpuViewAsProgressTip =>
      'Tampilkan tingkat penggunaan setiap CPU dalam gaya bilah kemajuan (gaya lama)';

  @override
  String get customCmd => 'Perintah kustom';

  @override
  String get deleteServers => 'Penghapusan server secara batch';

  @override
  String get deleteDirRecursive => 'Hapus folder beserta seluruh isinya';

  @override
  String get desktopTerminalTip =>
      'Perintah yang digunakan untuk membuka emulator terminal saat memulai sesi SSH.';

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
  String get displayCpuIndex => 'Tampilkan indeks CPU';

  @override
  String dl2Local(Object fileName) {
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
  String get doubleColumnMode => 'Mode kolom ganda';

  @override
  String get doubleColumnTip =>
      'Opsi ini hanya mengaktifkan fitur, apakah itu benar-benar dapat diaktifkan tergantung pada lebar perangkat';

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
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
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Jump server tidak ditemukan untuk $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
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
  String get preferredTransport => 'Coba lebih dulu';

  @override
  String get preferredTransportTip =>
      'Dari mana status dibaca, dan koneksi mana yang dibuka perintah lebih dulu. Yang lain tetap tersedia.';

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
  String madeWithLove(Object myGithub) {
    return 'Dibuat dengan ❤️ oleh $myGithub';
  }

  @override
  String get maxConcurrency => 'Konkurensi Maksimum';

  @override
  String get maxRetryCount => 'Jumlah penyambungan kembali server';

  @override
  String mismatchSystem(Object system) {
    return 'Sistem tidak cocok: $system';
  }

  @override
  String get mirror => 'Mirror';

  @override
  String get needRestart => 'Perlu memulai ulang aplikasi';

  @override
  String get netViewType => 'Jenis tampilan bersih';

  @override
  String get newContainer => 'Wadah baru';

  @override
  String get noConnectionStatsData => 'Tidak ada data statistik koneksi';

  @override
  String get noLineChart => 'Jangan gunakan grafik garis';

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
  String get plugInType => 'Jenis Penyisipan';

  @override
  String get preferDiskAmount => 'Prioritaskan tampilan kapasitas disk';

  @override
  String get privateKey => 'Kunci Pribadi';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
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
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand hanya didukung di platform desktop.';

  @override
  String get pveIgnoreCertTip =>
      'Tidak disarankan untuk diaktifkan, waspadai risiko keamanan! Jika Anda menggunakan sertifikat default dari PVE, Anda perlu mengaktifkan opsi ini.';

  @override
  String get pveServerClientMissing =>
      'Klien SSH untuk server ini tidak tersedia.';

  @override
  String get pveAddressMissing =>
      'Alamat PVE belum diisi. Atur di pengaturan server.';

  @override
  String get pvePasswordRequired =>
      'Kata sandi PVE diperlukan. Atur di pengaturan server.';

  @override
  String get pveOtpRequired =>
      'Autentikasi dua faktor aktif di server PVE ini. Masukkan kode OTP.';

  @override
  String get pveOtpChallengeExpired =>
      'Tantangan OTP sudah kedaluwarsa. Segarkan lalu coba lagi.';

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
  String get pveVersionLow =>
      'Fitur ini saat ini sedang dalam tahap pengujian dan hanya diuji pada PVE 8+. Gunakan dengan hati-hati.';

  @override
  String get pveLoadingForwarding => 'Membangun terowongan SSH...';

  @override
  String get pveLoadingLogin => 'Mengautentikasi ke PVE...';

  @override
  String get pveLoadingData => 'Mengambil data klaster...';

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
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed terpasang, ada $latest. Pembaruan mengganti seluruh kontainer: data $pm hilang';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Tutup terminal di $name sebelum menghapusnya';
  }

  @override
  String get rootfsSubtitle => 'Lingkungan pengguna Linux di perangkat ini';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
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
  String selected(Object count) {
    return '$count dipilih';
  }

  @override
  String get sendTo => 'Kirim ke…';

  @override
  String get serverFuncBtns => 'Tombol fungsi server';

  @override
  String get serverOrder => 'Pesanan server';

  @override
  String get serverTabEmpty => 'Belum ada server';

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
  String spentTime(Object time) {
    return 'Menghabiskan waktu: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Semua server sudah ada (ditemukan $duplicateCount duplikat)';
  }

  @override
  String get sshConnectionModeTip =>
      'Bawaan: memakai terminal aplikasi. SSH sistem: menjalankan perintah ssh sistem di terminal eksternal.';

  @override
  String get sshConnectionModeUseBuiltin => 'Pakai terminal bawaan';

  @override
  String get sshConnectionModeUseSystem => 'Pakai SSH sistem';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount duplikat akan dilewati';
  }

  @override
  String get sshConfigFound => 'Kami menemukan konfigurasi SSH di sistem Anda';

  @override
  String sshConfigFoundServers(Object totalCount) {
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
  String sshConfigImported(Object count) {
    return 'Berhasil mengimpor $count server dari konfigurasi SSH';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
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
  String sshHostKeyNewDesc(Object serverName) {
    return 'Kunci host SSH baru diterima dari $serverName. Periksa sidik jarinya sebelum mempercayai.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
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
  String sshConfigServersToImport(Object importCount) {
    return '$importCount server akan diimpor';
  }

  @override
  String get sshTermHelp =>
      'Ketika terminal dapat digulirkan, menggeser secara horizontal dapat memilih teks. Mengklik tombol keyboard mengaktifkan/menonaktifkan keyboard. Ikon file membuka SFTP jalur saat ini. Tombol papan klip menyalin konten saat teks dipilih, dan menempelkan konten dari papan klip ke terminal saat tidak ada teks yang dipilih dan ada konten di papan klip. Ikon kode menempelkan potongan kode ke terminal dan mengeksekusinya.';

  @override
  String get sshVirtualKeyAutoOff => 'Switching Otomatis Kunci Virtual';

  @override
  String get sshA11yMode => 'Accessibility mode';

  @override
  String get sshA11yModeTip =>
      'Render terminal output as plain text with an input field and labeled keys, for screen reader users.';

  @override
  String get sshA11yInputHint => 'Type a command, then press Enter';

  @override
  String get sshA11yCursorPrefix => 'Selected';

  @override
  String get sshA11yCopyAll => 'Copy all';

  @override
  String get sshA11ySelectText => 'Select text';

  @override
  String get supportFmtArgs => 'Parameter pemformatan berikut ini didukung:';

  @override
  String get suspendTip =>
      'Fungsi penangguhan memerlukan hak akses root dan dukungan systemd.';

  @override
  String switchTo(Object val) {
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
  String get view => 'Tampilan';

  @override
  String get viewDetails => 'Lihat Detail';

  @override
  String get virtKeyA11yTmux => 'tmux';

  @override
  String get virtKeyA11ySudo => 'Sudo password';

  @override
  String get virtKeyA11ySnippet => 'Snippet';

  @override
  String get virtKeyA11ySFTP => 'SFTP';

  @override
  String get virtKeyA11yIME => 'Keyboard';

  @override
  String get virtKeyA11yClipboard => 'Clipboard';

  @override
  String get virtKeyHelpClipboard =>
      'Salin ke clipboard jika terminal yang dipilih tidak kosong, jika tidak, tempel isi clipboard ke terminal.';

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
      'Di pengaturan terminal kamu bisa mengubah urutannya, atau menyembunyikan yang tidak pernah dipakai.';

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
  String portForward_deleteConfirmFmt(Object name) {
    return 'Hapus $name?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Menurut waktu ditambahkan';

  @override
  String get serverHistory => 'Riwayat server';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

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
  String get tmuxExistingSessions => 'Sesi yang ada';

  @override
  String get tmuxNewSession => 'Sesi baru';

  @override
  String get tmuxWindows => 'Jendela';

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
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panel',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Tersambung';

  @override
  String get tmuxActive => 'Aktif';

  @override
  String tmuxActiveAt(String time) {
    return 'aktif: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'tersambung: $time';
  }

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
  String get processSearchHint => 'Name, user or PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count kernel threads',
      one: 'Show 1 kernel thread',
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
      other: '$count other units',
      one: '1 other unit',
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
    return 'Stopped $duration ago';
  }

  @override
  String serviceExitStatus(String code) {
    return 'exit status $code';
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
      other: 'Last $count lines',
      one: 'Last line',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable => 'This account cannot read the journal';

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
  String get send => 'Kirim';

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
  String geoDataCurrent(Object month) {
    return '$month sudah terpasang.';
  }

  @override
  String geoDataConsent(Object download, Object disk) {
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
  String benchmarkEstimatedTime(String minutes) {
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
      'System user management currently supports Linux servers.';

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
      'Changes to root take effect in every session at once.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Supplementary groups';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Create home directory';

  @override
  String get userMoveHome =>
      'Move the existing home directory when the path changes';

  @override
  String get userRemoveHome => 'Remove the home directory';

  @override
  String get userPasswordCreateTip =>
      'Leave the password empty to create a password-locked account.';

  @override
  String get userPasswordEditTip =>
      'Leave the password empty to keep the existing password.';

  @override
  String funcUnavailableFmt(Object func) {
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
  String agentRetentionFmt(Object kept) {
    return 'Agen menyimpan $kept';
  }

  @override
  String oldestSampleFmt(Object time) {
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
  String atTimeFmt(Object time) {
    return 'pukul $time';
  }

  @override
  String get stored => 'tersimpan';

  @override
  String lastSampleFmt(Object ago) {
    return 'sampel terakhir $ago';
  }

  @override
  String staleSinceFmt(Object ago, Object time) {
    return 'Semua di bawah ini berasal dari $time, $ago.';
  }

  @override
  String noDataBeforeFmt(Object time) {
    return 'tidak ada data sebelum $time';
  }

  @override
  String loadingRangeFmt(Object range) {
    return 'Memuat $range…';
  }

  @override
  String noStoredHistoryFor(Object metric) {
    return 'Tidak ada riwayat tersimpan untuk $metric';
  }

  @override
  String devicesFmt(Object count) {
    return '$count perangkat';
  }

  @override
  String devicesBusiestFmt(Object count, Object name) {
    return '$count perangkat · $name tersibuk';
  }

  @override
  String devicesPlottedFmt(Object plotted, Object total) {
    return '$plotted dari $total perangkat';
  }

  @override
  String sensorsHottestFmt(Object count, Object name) {
    return '$count sensor · $name paling panas';
  }

  @override
  String get oneDeviceAtLeast =>
      'Setidaknya satu perangkat tetap ada di grafik.';

  @override
  String shownOfFmt(Object shown, Object total, Object what) {
    return '$shown dari $total $what';
  }

  @override
  String countOfFmt(Object count, Object what) {
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
  String diskWarningFmt(num count) {
    return '$count peringatan';
  }

  @override
  String diskWrongOfFmt(Object total, Object wrong) {
    return '$wrong dari $total perangkat';
  }

  @override
  String get diskSmartSortedTip => 'Terburuk lebih dulu';

  @override
  String readAgoFmt(Object ago) {
    return 'dibaca $ago';
  }

  @override
  String processesFmt(Object count) {
    return '$count proses';
  }

  @override
  String diskFailingFmt(Object count) {
    return '$count bermasalah';
  }

  @override
  String get diskSmartOpenTip => 'Ketuk untuk melihat atributnya';

  @override
  String get cycle => 'Siklus';

  @override
  String get window => 'jendela';

  @override
  String ofFmt(Object total) {
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
  String transportOrderFmt(Object first, Object second) {
    return 'Seret untuk mengubah urutan. $first dipanggil lebih dulu; jika tidak menjawab, $second menanggung sesi sendirian.';
  }

  @override
  String transportOnlyFmt(Object name) {
    return 'Hanya $name yang aktif, jadi tidak ada cadangan.';
  }

  @override
  String get transportNoneOn =>
      'Keduanya nonaktif — server ini tidak dapat dihubungi.';

  @override
  String get transportOffKept =>
      'nonaktif — pengaturan disimpan, tidak pernah dipanggil';

  @override
  String get transportDialledFirst => 'dipanggil lebih dulu';

  @override
  String get transportFallback => 'cadangan';

  @override
  String get transportOnlyMethod => 'satu-satunya cara';

  @override
  String get transportOff => 'nonaktif';

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
  String get optionalTip =>
      'Tidak ada di sini yang diperlukan untuk terhubung. Buka salah satu dan kolomnya mengambil alih formulir.';

  @override
  String get sshAdvanced => 'SSH lanjutan';

  @override
  String get sshAdvancedTip =>
      'Tujuan cadangan, ProxyCommand, server lompat, transport berkas, jalur jarak jauh';

  @override
  String get sshLegacyAlgorithms => 'Legacy algorithms';

  @override
  String get sshLegacyAlgorithmsTip =>
      'For an old SSH daemon (a router, a switch) that only offers the SHA-1 `ssh-rsa` host key or a SHA-1 key exchange. Less secure; turn it on only for a host that needs it.';

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
  String tagCreateFmt(Object tag) {
    return 'Buat #$tag';
  }

  @override
  String get tagOnThisServer => 'di server ini';

  @override
  String tagServersFmt(Object count) {
    return '$count server';
  }

  @override
  String tagOnThisServerFmt(Object count) {
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
      'Scheduled task management currently supports Linux servers.';

  @override
  String get scheduledTaskUnavailable =>
      'crontab is not available on this server.';

  @override
  String get scheduledTaskPreserveTip =>
      'Comments, environment variables, and unrecognized lines in this crontab are preserved.';

  @override
  String get scheduledTaskSchedule => 'Schedule';

  @override
  String get scheduledTaskAdd => 'Add task';

  @override
  String get scheduledTaskNextRun => 'Next run';

  @override
  String scheduledTaskNextInFmt(Object time) {
    return 'in $time';
  }

  @override
  String get scheduledTaskEnabled => 'Enabled';

  @override
  String get scheduledTaskCommentedOut => 'Commented out';

  @override
  String scheduledTaskSummaryFmt(Object enabled, Object total) {
    return '$total tasks · $enabled enabled';
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
  String get scheduledTaskEnableNowTip => 'Off writes the line commented out.';

  @override
  String scheduledTaskEmptyFmt(Object user) {
    return 'No scheduled tasks for $user. What is added here is written into that account\'s crontab.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'Day of month';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'Day of week';

  @override
  String get cronErrScheduleEmpty => 'A schedule is required.';

  @override
  String get cronErrCommandEmpty => 'A command is required.';

  @override
  String get cronErrLineBreak => 'A crontab line cannot contain line breaks.';

  @override
  String get cronErrMacro => 'A macro is one word, such as @reboot.';

  @override
  String get cronErrFieldCount =>
      'A cron schedule has five fields, or a macro such as @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(Object minutes) {
    return 'Every $minutes minutes';
  }

  @override
  String cronHourlyAtFmt(Object minute) {
    return 'Every hour at :$minute';
  }

  @override
  String cronEveryHoursFmt(Object hours) {
    return 'Every $hours hours';
  }

  @override
  String cronEveryHoursAtFmt(Object hours, Object minute) {
    return 'Every $hours hours at :$minute';
  }

  @override
  String cronDailyAtFmt(Object time) {
    return 'Every day at $time';
  }

  @override
  String cronWeekdaysAtFmt(Object time) {
    return 'On weekdays at $time';
  }

  @override
  String cronWeekdayAtFmt(Object day, Object time) {
    return 'Every $day at $time';
  }

  @override
  String cronMonthlyAtFmt(Object day, Object time) {
    return 'Day $day of every month at $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart => 'Takes effect after the agent restarts';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Extended cycle interval';

  @override
  String get idlePause => 'Pause when nothing is watching';

  @override
  String get idlePauseTip =>
      'The extended cycle runs smartctl, sensors and amd-smi. Pausing it while no client is polling keeps a disk from being woken for data nobody is reading.';

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
      'Metric: cpu / memory / swap / disk / network / temperature. Matcher: cpu0 for one core, used / free / avail for memory, rx / tx for network; disk and temperature ignore it. Threshold: a comparator and a value, such as >=80%, >=70c or >10m/s.';

  @override
  String get pushChannels => 'Notification channels';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Set on the agent, not shown';

  @override
  String get pushSecretKeep => 'Leave blank to keep';

  @override
  String get pushTestTip =>
      'Sends one notification through this channel as it stands here, saved or not.';

  @override
  String get pushTestSent => 'The channel accepted it';

  @override
  String get pushTestFailed => 'The channel refused it';

  @override
  String get pushTestMessage => 'Test notification from ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'This agent has no sender for this channel type, so its settings are not shown. It can be removed here, or edited in the agent\'s config.toml.';

  @override
  String get pushJsonInvalid => 'is not valid JSON';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Off means the agent never deletes anything and its database grows without limit.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Run cleanup every';

  @override
  String get retentionMaxDbSize => 'Database size cap';

  @override
  String get corsOrigins => 'CORS allowed origins';

  @override
  String get corsOriginsTip =>
      'Origins a browser panel may call this agent from. Empty means same-origin only.';

  @override
  String get monitorNoRemoteAccess =>
      'Agen ini hanya dikonfigurasi untuk pemantauan. Anda tidak dapat membuka terminal, menjalankan perintah, atau menjelajahi berkas dari sini. Untuk mengaktifkan fitur tersebut, edit [remote_access] dalam config.toml agen.';
}
