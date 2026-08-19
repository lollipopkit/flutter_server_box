// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get acceptBeta => 'Terima pembaruan versi uji coba';

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
      'Masukkan URL dasar layanan atau endpoint lengkap Chat Completions maupun Responses. ServerBox melengkapi jalurnya sesuai protokol yang dipilih.';

  @override
  String get askAiProtocolTip =>
      'Otomatis memakai Responses untuk endpoint resmi OpenAI dan Chat Completions untuk penyedia yang kompatibel.';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

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
  String get askAiAgentTitle => 'Agent SSH';

  @override
  String get askAiAgentWelcome => 'Apa yang akan kita lakukan di server ini?';

  @override
  String get askAiAgentWelcomeTip =>
      'Minta diagnosis atau sebuah tugas. Agent mengusulkan satu perintah setiap kali dan menunggu tinjauan Anda sebelum mengubah apa pun.';

  @override
  String get askAiAgentPromptHint =>
      'Minta Agent memeriksa atau memperbaiki sesuatu...';

  @override
  String get askAiAgentSend => 'Kirim ke Agent';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analisis isi terminal yang dipilih, jelaskan apa yang terjadi, dan usulkan langkah berikutnya yang paling aman jika perlu tindakan.';

  @override
  String get askAiTerminalContext => 'Konteks terminal';

  @override
  String get askAiReviewNeeded => 'Tinjau';

  @override
  String get askAiReviewAction => 'Tinjau perintah yang diusulkan';

  @override
  String get askAiReviewBeforeContinuing =>
      'Tinjau atau tolak dulu perintah yang diusulkan';

  @override
  String get askAiApproveRun => 'Setujui & jalankan';

  @override
  String get askAiDecline => 'Tolak';

  @override
  String get askAiActionDeclined => 'Perintah yang diusulkan ditolak.';

  @override
  String get askAiInterrupted => 'Respons Agent terputus.';

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
      'Perintah ini dapat menghapus data, menghentikan layanan, atau sulit dibatalkan. Tinjau dengan cermat sebelum menjalankannya.';

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
      'Hanya dijalankan otomatis bila model dan pemeriksaan keamanan lokal sama-sama menilai perintah itu hanya-baca. Perintah yang mengubah sistem tetap perlu ditinjau.';

  @override
  String get askAiSendOnEnter => 'Enter mengirim';

  @override
  String get askAiSendOnEnterTip =>
      'Enter mengirim pesan, Shift+Enter membuat baris baru. Jika dimatikan, keduanya bertukar: Enter membuat baris baru dan Cmd/Ctrl+Enter mengirim.';

  @override
  String get askAiApiKeyOptional =>
      'Opsional untuk endpoint lokal atau tanpa autentikasi';

  @override
  String get askAiHistory => 'Riwayat percakapan';

  @override
  String get askAiNewConversation => 'Percakapan baru';

  @override
  String get askAiNoHistory =>
      'Tidak ada percakapan tersimpan untuk server ini';

  @override
  String get askAiNoHistoryMessages => 'Belum ada pesan';

  @override
  String get askAiUntitledConversation => 'Percakapan baru';

  @override
  String get askAiRenameConversation => 'Ganti nama percakapan';

  @override
  String get askAiDeleteConversationTitle => 'Hapus percakapan ini?';

  @override
  String get askAiDeleteConversationTip =>
      'Percakapan akan dihapus dari perangkat ini dan tidak bisa dikembalikan.';

  @override
  String get askAiClearHistoryTitle => 'Hapus riwayat Agent untuk server ini?';

  @override
  String get askAiClearHistoryTip =>
      'Semua percakapan Agent yang tersimpan untuk server ini akan dihapus dari perangkat ini.';

  @override
  String get askAiRestoredReview =>
      'Dipulihkan dari riwayat. Tinjau lagi sebelum menjalankan; perintah ini tidak akan pernah berjalan sendiri.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => 'Apa yang akan kita lakukan di server Anda?';

  @override
  String get agentWelcomeTip =>
      'Minta diagnosis atau tugas operasional. Agent memakai kondisi ServerBox terkini dan mengusulkan satu tindakan yang ditinjau setiap kali.';

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
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Eksekusi alat gagal.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count panggilan alat';
  }

  @override
  String get agentFloat => 'Mengambang di atas tab lain';

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
      'Agent ingin membuka koneksi SSH. Ketik kata sandi di sini, jangan di percakapan, karena di sana kata sandi akan tersimpan dan dikirim ke model.';

  @override
  String get agentAdHocSessions => 'Koneksi sementara';

  @override
  String get agentSaveServerTitle => 'Simpan sebagai server';

  @override
  String get agentSaveServerTip =>
      'Host ini dan kata sandi yang dimasukkan akan disimpan di perangkat ini.';

  @override
  String get agentMonitorOptional => 'Agen monitor (opsional)';

  @override
  String get atLeastOneTab => 'Setidaknya satu tab harus dipilih';

  @override
  String get authFailTip =>
      'Otentikasi gagal, silakan periksa apakah kata sandi/kunci/host/pengguna, dll, salah.';

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
  String get compactDatabase => 'Kompres Database';

  @override
  String compactDatabaseContent(Object size) {
    return 'Ukuran database: $size\n\nIni akan mengatur ulang database untuk mengurangi ukuran file. Tidak ada data yang akan dihapus.';
  }

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
  String dockerImagesFmt(Object count) {
    return '$count gambar';
  }

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
  String get editVirtKeys => 'Edit kunci virtual';

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
  String get fileDirGoneTip =>
      'Folder ini dihapus atau diganti nama. Gunakan bilah di bawah untuk kembali, ke beranda, atau menuju tempat lain.';

  @override
  String get fullScreen => 'Mode Layar Penuh';

  @override
  String get fullScreenJitter => 'Jitter layar penuh';

  @override
  String get fullScreenJitterHelp => 'Untuk menghindari pembakaran layar';

  @override
  String get fullScreenTip =>
      'Apakah mode layar penuh diaktifkan ketika perangkat diputar ke modus lanskap? Opsi ini hanya berlaku untuk tab server.';

  @override
  String get githubGist => 'GitHub Gist';

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
  String get homeWidgetUrlConfig => 'Konfigurasi URL Widget Rumah';

  @override
  String get ignoreCert => 'Abaikan sertifikat';

  @override
  String get image => 'Gambar';

  @override
  String get macDmgBody =>
      'App Store mewajibkan aplikasi ini berjalan dalam sandbox, dan proses dalam sandbox tidak bisa membuka pseudo-terminal. Karena itu versi App Store tidak punya terminal di Mac ini dan tidak bisa menjalankan snippet atau perintah agent di sini. Versi DMG adalah aplikasi yang sama, ditandatangani tanpa sandbox, dan memilikinya.\n\nVersi App Store tetap berfungsi dan tetap diperbarui. Nanti pembaruannya bisa berhenti.\n\nKedua versi menyimpan datanya di tempat berbeda. Versi DMG menyalinnya saat pertama dijalankan, jadi server, kunci, dan riwayat ikut pindah. Jika gagal, akan diberitahukan, dan Anda bisa pindah lewat berkas cadangan (Cadangan, di pengaturan).';

  @override
  String get macDmgImportDenied =>
      'macOS tidak mengizinkan pembacaan data versi yang terpasang sebelumnya. Berikan Akses Disk Penuh lalu buka ulang aplikasi, atau ekspor cadangan di sana dan pulihkan di sini.';

  @override
  String get macDmgImported =>
      'Data versi yang terpasang sebelumnya telah diimpor.';

  @override
  String get macDmgImportFailed =>
      'Tidak bisa membaca data versi yang terpasang sebelumnya. Ekspor cadangan di sana, lalu pulihkan di sini.';

  @override
  String get macDmgTip =>
      'Terminal di Mac ini dan menjalankan snippet di sini hanya ada pada versi DMG.';

  @override
  String get macDmgTitle => 'Versi DMG';

  @override
  String get showHiddenFiles => 'Tampilkan berkas tersembunyi';

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
  String get pruneDanglingImagesTip =>
      'Hanya hapus gambar menggantung (lapisan tanpa tag).';

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
    return '\"$name\" already exists';
  }

  @override
  String get noJumpServerAvailable => 'Tidak ada jump server yang tersedia.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump server dan ProxyCommand tidak bisa dipakai bersamaan.';

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
  String get onlyOneLine =>
      'Hanya tampilkan sebagai satu baris (dapat digulir)';

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
  String get proxyCommandSandboxed =>
      'Build ini berjalan dalam sandbox: perintah melihat direktori home kosong alih-alih milik Anda, sehingga apa pun yang membaca ~/.ssh (ssh -W, cloudflared) gagal — sering kali sebagai batas waktu yang menyebut host yang salah. Perintah yang hanya memakai jaringan tetap berfungsi. Versi DMG tidak punya sandbox.';

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
  String rootfsUpdateTip(Object installed, Object latest) {
    return 'Alpine $installed terpasang dan $latest tersedia. Memperbarui akan mengunduhnya lagi dan mengganti kontainer: semua yang dipasang di dalamnya dengan apk akan hilang. Jika dilewati, yang sekarang tetap berfungsi.';
  }

  @override
  String get rootfsSubtitle => 'Lingkungan pengguna Linux di perangkat ini';

  @override
  String rootfsInstallTip(Object version) {
    return 'Unduh Alpine Linux $version (sekitar 3 MB) dan ekstrak di perangkat ini. Ini memberi aplikasi ini shell dengan manajer paket, dan dapat dihapus kapan saja.';
  }

  @override
  String get sameIdServerExist => 'Server dengan ID yang sama sudah ada';

  @override
  String get second => 'S';

  @override
  String get serverFilesUnavailableTip =>
      'Dapat dijangkau melalui SSH server ini, atau melalui agen monitor dengan API berkasnya diaktifkan.';

  @override
  String get back => 'Kembali';

  @override
  String get history => 'Riwayat';

  @override
  String get homeDir => 'Beranda';

  @override
  String get selectItem => 'Pilih';

  @override
  String selected(Object count) {
    return '$count dipilih';
  }

  @override
  String get sendTo => 'Kirim ke…';

  @override
  String get serverDetailOrder => 'Detail pesanan widget halaman';

  @override
  String get serverFuncBtns => 'Tombol fungsi server';

  @override
  String get serverOrder => 'Pesanan server';

  @override
  String get serverTabRequired => 'Tab server tidak dapat dihapus';

  @override
  String get shareServerRiskTip =>
      'Kode QR ini berisi pengaturan koneksi server dalam teks biasa, termasuk kata sandi. Siapa pun yang memindai atau memotretnya dapat terhubung ke server ini.';

  @override
  String get sftpDlPrepare => 'Bersiap untuk terhubung ...';

  @override
  String get sftpEditorTip =>
      'Jika kosong, gunakan editor file bawaan aplikasi. Jika ada nilai, gunakan editor server jarak jauh, misalnya `vim` (disarankan untuk mendeteksi secara otomatis sesuai `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Gunakan `rm -r` untuk menghapus dir di SFTP';

  @override
  String get sftpSSHConnected => 'Sftp terhubung';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Folder ditampilkan lebih dulu';

  @override
  String get specifyDev => 'Tentukan perangkat';

  @override
  String get specifyDevTip =>
      'Misalnya, statistik lalu lintas jaringan secara default adalah untuk semua perangkat. Anda dapat menentukan perangkat tertentu di sini.';

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
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Sidik jari (MD5 Base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Sidik jari (MD5 hex): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'Jenis kunci host SSH';

  @override
  String get sshKnownHostKeys => 'Kunci host yang dikenal';

  @override
  String get sshKnownHostKeysTip =>
      'Kunci host yang telah diterima aplikasi ini. Hapus satu agar ditanyakan lagi saat koneksi berikutnya.';

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
  String get system => 'Sistem';

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
  String get virtKeyHelpClipboard =>
      'Salin ke clipboard jika terminal yang dipilih tidak kosong, jika tidak, tempel isi clipboard ke terminal.';

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
  String get portForwardBeta =>
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
  String get systemd => 'Systemd';

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
  String get watchServers => 'Server di jam tangan';

  @override
  String get watchServersTip =>
      'Jam tangan membaca server ini langsung dari agen monitor-nya, jadi hanya server yang sudah dikonfigurasi monitor yang bisa dipilih.';

  @override
  String get watchNoMonitorServer =>
      'Tidak ada server dengan agen monitor terkonfigurasi';

  @override
  String get watchLegacyUrls => 'URL status lama';

  @override
  String get accessoryWidgetServer => 'Server widget layar kunci';

  @override
  String get systemdMissing => 'Tidak ada systemd di server ini';

  @override
  String get systemdMissingTip =>
      '`systemctl` tidak terpasang di sini, jadi tidak ada unit untuk ditampilkan.';

  @override
  String initSystemFmt(String init) {
    return 'Mesin ini tampaknya menggunakan $init.';
  }

  @override
  String get systemdListFailed => 'Tidak dapat menampilkan daftar unit';

  @override
  String get systemdUserScopeMissing => 'Unit pengguna tidak ditampilkan';

  @override
  String get systemdUserScopeMissingTip =>
      'Akun ini tidak memiliki bus sesi pengguna di server, jadi hanya unit sistem yang ditampilkan.';

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
  String get continueInTerminal => 'Lanjutkan di terminal';

  @override
  String get askAiRiskUnknown => 'Tidak terklasifikasi';

  @override
  String get agentLocalExec => 'Jalankan perintah di perangkat ini';

  @override
  String get agentLocalExecTip =>
      'Memungkinkan Agent bekerja di mesin tempat ServerBox berjalan, bukan hanya di server. Tidak ada yang berjalan tanpa pengawasan di sini: setiap perintah perlu ditinjau.';

  @override
  String get agentLocalExecRootfsTip =>
      'Memungkinkan Agent bekerja di perangkat ini, di dalam kontainer Alpine Linux yang dipasang ServerBox. Ia tidak dapat melihat sistem berkas perangkat itu sendiri, data aplikasi, atau berkas Anda. Setiap perintah tetap perlu ditinjau.';

  @override
  String macDmgImportedPartly(String path) {
    return 'Data dari versi yang terpasang sebelumnya telah diimpor. Berkas unduhan tetap berada di $path.';
  }
}
