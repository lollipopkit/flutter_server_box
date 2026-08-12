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
  String get addr => 'Alamat';

  @override
  String get askAi => 'Tanya AI';

  @override
  String get ai => 'AI';

  @override
  String get askAiApiKey => 'Kunci API';

  @override
  String get askAiAwaitingResponse => 'Menunggu respons AI...';

  @override
  String get askAiBaseUrl => 'URL dasar';

  @override
  String get askAiEndpointTip =>
      'Enter a service base URL or a full Chat Completions or Responses endpoint. ServerBox completes the path for the selected protocol.';

  @override
  String get askAiProtocol => 'API protocol';

  @override
  String get askAiProtocolTip =>
      'Auto uses Responses for the official OpenAI endpoint and Chat Completions for compatible providers.';

  @override
  String get askAiProtocolAuto => 'Auto';

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
  String get askAiConfirmExecute => 'Konfirmasi sebelum menjalankan';

  @override
  String get askAiConversation => 'Percakapan AI';

  @override
  String get askAiDisclaimer => 'AI bisa saja salah. Gunakan dengan hati-hati.';

  @override
  String get askAiFollowUpHint => 'Ajukan pertanyaan lanjutan...';

  @override
  String get askAiInsertTerminal => 'Masukkan ke terminal';

  @override
  String get askAiNoResponse => 'Tidak ada respons';

  @override
  String get askAiRecommendedCommand => 'Perintah yang disarankan AI';

  @override
  String get askAiSelectedContent => 'Konten yang dipilih';

  @override
  String get askAiUsageHint => 'Digunakan di Terminal SSH';

  @override
  String get askAiAgentTitle => 'SSH Agent';

  @override
  String get askAiAgentWelcome => 'What should we do on this server?';

  @override
  String get askAiAgentWelcomeTip =>
      'Ask for a diagnosis or a task. The Agent proposes one command at a time and waits for review before making changes.';

  @override
  String get askAiAgentPromptHint =>
      'Ask the Agent to inspect or fix something...';

  @override
  String get askAiAgentSend => 'Send to Agent';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analyze the selected terminal content, explain what happened, and propose the safest next step if action is needed.';

  @override
  String get askAiTerminalContext => 'Terminal context';

  @override
  String get askAiReady => 'Ready';

  @override
  String get askAiThinking => 'Thinking';

  @override
  String get askAiRunningCommand => 'Running';

  @override
  String get askAiReviewNeeded => 'Review';

  @override
  String get askAiReviewAction => 'Review proposed command';

  @override
  String get askAiReviewBeforeContinuing =>
      'Review or decline the proposed command first';

  @override
  String get askAiApproveRun => 'Approve & run';

  @override
  String get askAiDecline => 'Decline';

  @override
  String get askAiActionDeclined => 'The proposed command was declined.';

  @override
  String get askAiInterrupted => 'Agent response was interrupted.';

  @override
  String get askAiRiskReadOnly => 'Read-only';

  @override
  String get askAiRiskCaution => 'Changes system';

  @override
  String get askAiRiskDestructive => 'High risk';

  @override
  String get askAiHighRiskConfirmTitle => 'Run high-risk command?';

  @override
  String get askAiHighRiskConfirmBody =>
      'This command may delete data, stop services, or otherwise be difficult to undo. Review it carefully before running.';

  @override
  String get askAiCommandCancelled => 'Cancelled';

  @override
  String get askAiCommandTimedOut => 'Timed out';

  @override
  String get askAiNoCommandOutput => 'Command completed without output.';

  @override
  String get askAiOutputTruncated =>
      'Long output was truncated before it was sent back to the Agent.';

  @override
  String get askAiAutoApproved => 'Auto-approved';

  @override
  String get askAiAutoRunSafeCommands => 'Auto-run read-only commands';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Only auto-run when both the model and local safety checks classify the command as read-only. Commands that change the system still require review.';

  @override
  String get askAiSendOnEnter => 'Enter sends';

  @override
  String get askAiSendOnEnterTip =>
      'Enter sends the message, Shift+Enter starts a new line. Off swaps them: Enter starts a new line and Cmd/Ctrl+Enter sends.';

  @override
  String get askAiApiKeyOptional =>
      'Optional for local or unauthenticated endpoints';

  @override
  String get askAiHistory => 'Conversation history';

  @override
  String get askAiHistoryLocalOnly =>
      'Encrypted on this device and excluded from backup and sync';

  @override
  String get askAiNewConversation => 'New conversation';

  @override
  String get askAiNoHistory => 'No saved conversations for this server';

  @override
  String get askAiNoHistoryMessages => 'No messages yet';

  @override
  String get askAiUntitledConversation => 'New conversation';

  @override
  String get askAiRenameConversation => 'Rename conversation';

  @override
  String get askAiDeleteConversationTitle => 'Delete this conversation?';

  @override
  String get askAiDeleteConversationTip =>
      'This removes the conversation from this device and cannot be undone.';

  @override
  String get askAiClearHistory => 'Clear history';

  @override
  String get askAiClearHistoryTitle => 'Clear this server\'s Agent history?';

  @override
  String get askAiClearHistoryTip =>
      'All Agent conversations saved for this server will be removed from this device.';

  @override
  String get askAiRestoredReview =>
      'Restored from history. Review it again before running; it will never run automatically.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => 'What should we do across your servers?';

  @override
  String get agentWelcomeTip =>
      'Ask for a diagnosis or an operational task. The Agent uses live ServerBox state and proposes one reviewed action at a time.';

  @override
  String get agentPromptHint =>
      'Ask the Agent to inspect or operate your servers...';

  @override
  String get agentNoServers => 'No configured servers';

  @override
  String get agentNoHistory => 'No saved global Agent conversations';

  @override
  String get agentClearHistoryTitle => 'Clear global Agent history?';

  @override
  String get agentClearHistoryTip =>
      'All global Agent conversations will be removed from this device.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Read file';

  @override
  String get agentToolWriteFile => 'Write file';

  @override
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Tool execution failed.';

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
  String get icloudBackupStatusTitle => 'Backup status';

  @override
  String get icloudBackupStatusLoading => 'Loading iCloud backup status...';

  @override
  String get icloudBackupStatusError => 'Unable to read iCloud backup metadata';

  @override
  String get icloudBackupStatusEmpty => 'No iCloud backup file found yet';

  @override
  String get icloudBackupStateUploading => 'Uploading';

  @override
  String get icloudBackupStateConflict => 'Conflict detected';

  @override
  String get icloudBackupStateUploaded => 'Uploaded';

  @override
  String get icloudBackupStateWaiting => 'Waiting for iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Last backup: $lastModified\nStatus: $remoteState';
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
  String get configured => 'Configured';

  @override
  String get customCmd => 'Perintah kustom';

  @override
  String get deleteServers => 'Penghapusan server secara batch';

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
  String get discoverySummary => 'Ringkasan Penemuan';

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
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount running, $stoppedCount container stopped.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count wadah berjalan.';
  }

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
  String get finishedAt => 'Selesai pada';

  @override
  String get followSystem => 'Ikuti sistem';

  @override
  String get fontSize => 'Ukuran huruf';

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
  String get githubGistIdOptional => 'Gist ID (optional)';

  @override
  String get githubGistToken => 'GitHub Gist token';

  @override
  String get githubGistTokenEmpty => 'Token is empty';

  @override
  String get goBackQ => 'Datang kembali?';

  @override
  String get goto => 'Pergi ke';

  @override
  String get hideTitleBar => 'Sembunyikan bilah judul';

  @override
  String get highlight => 'Sorotan kode';

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
  String get imagesList => 'Daftar gambar';

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
  String get volume => 'Volume';

  @override
  String get pull => 'Tarik';

  @override
  String get invalid => 'Tidak valid';

  @override
  String get invalidUrl => 'Invalid URL';

  @override
  String get invalidHostFormat =>
      'Invalid host format. Only IPv4, IPv6, and domain characters are allowed.';

  @override
  String get jumpServer => 'Lompat server';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Jump servers not found for $serverName: $jumpIds';
  }

  @override
  String get noJumpServerAvailable => 'No jump server available.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Jump server and ProxyCommand cannot be used together.';

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
  String get more => 'Lebih Banyak';

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
  String get shellSourceNone => 'Tanpa shell';

  @override
  String get forceSinglePane => 'Satu kolom';

  @override
  String get forceSinglePaneTip =>
      'Tetap satu kolom seberapa pun lebar jendela, alih-alih menampilkan detail di samping daftar.';

  @override
  String get passwordlessTerminal => 'Terminal tanpa kredensial';

  @override
  String get passwordlessTerminalTip =>
      'Buka terminal melalui agen monitor tanpa kredensial SSH. Shell berjalan sebagai akun tempat agen berjalan, jadi kata sandi monitor saja sudah cukup untuk mendapatkannya — autentikasi, pencatatan, dan faktor kedua milik sshd tidak berlaku. Agen yang menentukan apakah ini diizinkan. Hanya menyediakan terminal: SFTP, penerusan port, kontainer, proses, dan systemd tetap membutuhkan SSH.';

  @override
  String get passwordlessTerminalNeedsMonitor =>
      'Terminal tanpa kredensial memerlukan alamat monitor.';

  @override
  String get passwordlessTerminalConflictsWithSsh =>
      'Terminal tanpa kredensial tidak dapat digabungkan dengan kredensial SSH.';

  @override
  String get passwordlessTerminalRefused =>
      'Agen ini tidak menyediakan terminal tanpa kredensial.';

  @override
  String get passwordlessTerminalInsecure =>
      'Agen ini hanya menyajikan terminal melalui TLS atau loopback, sedangkan koneksi ini HTTP polos.';

  @override
  String get permission => 'Izin';

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
  String get pushToken => 'Dorong token';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand is only supported on desktop platforms.';

  @override
  String get pveIgnoreCertTip =>
      'Tidak disarankan untuk diaktifkan, waspadai risiko keamanan! Jika Anda menggunakan sertifikat default dari PVE, Anda perlu mengaktifkan opsi ini.';

  @override
  String get pveServerClientMissing =>
      'The SSH client for this server is not available.';

  @override
  String get pveAddressMissing =>
      'The PVE address is missing. Please configure it in server settings.';

  @override
  String get pvePasswordRequired =>
      'PVE password is required. Please set it in server settings.';

  @override
  String get pveOtpRequired =>
      'Two-factor authentication is enabled on this PVE server. Please enter the OTP code.';

  @override
  String get pveOtpChallengeExpired =>
      'The OTP challenge has expired. Please refresh and try again.';

  @override
  String get pveOtpCodeRequired => 'OTP code is required.';

  @override
  String get pveOtpVerificationFailed =>
      'OTP verification failed. Please try again with a fresh code.';

  @override
  String get pveOtpTitle => 'OTP Verification';

  @override
  String get pveOtpLabel => 'OTP Code';

  @override
  String get pveInvalidResponseBody =>
      'PVE login returned an invalid response body.';

  @override
  String get pveInvalidResponseData =>
      'PVE login response did not contain a valid data payload.';

  @override
  String get pveMissingAuthTicket =>
      'PVE login succeeded but no authentication ticket was returned.';

  @override
  String get pveVersionLow =>
      'Fitur ini saat ini sedang dalam tahap pengujian dan hanya diuji pada PVE 8+. Gunakan dengan hati-hati.';

  @override
  String get pveLoadingForwarding => 'Establishing SSH tunnel...';

  @override
  String get pveLoadingLogin => 'Authenticating with PVE...';

  @override
  String get pveLoadingData => 'Fetching cluster data...';

  @override
  String get pveLoadingConnect => 'Connecting...';

  @override
  String get pvePassword => 'PVE Password';

  @override
  String get pvePasswordHint =>
      'Required when using key-based SSH authentication';

  @override
  String get read => 'Baca';

  @override
  String get recentConnections => 'Koneksi Terkini';

  @override
  String get reconnecting => 'Menghubungkan kembali...';

  @override
  String get rememberPwdInMem => 'Ingat kata sandi di dalam memori';

  @override
  String get rememberPwdInMemTip =>
      'Digunakan untuk kontainer, menangguhkan, dll.';

  @override
  String get remotePath => 'Jalur jarak jauh';

  @override
  String get sameIdServerExist => 'Server dengan ID yang sama sudah ada';

  @override
  String get save => 'Menyimpan';

  @override
  String get second => 'S';

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
  String get size => 'Ukuran';

  @override
  String get softWrap => 'Pembungkus lembut';

  @override
  String get specifyDev => 'Tentukan perangkat';

  @override
  String get specifyDevTip =>
      'Misalnya, statistik lalu lintas jaringan secara default adalah untuk semua perangkat. Anda dapat menentukan perangkat tertentu di sini.';

  @override
  String get tempIsCelsiusTip =>
      'When enabled, the temperature value will be treated as Celsius instead of millicelsius. Turn on only if the temperature displays incorrectly (e.g., showing 0.1°C instead of 58°C).';

  @override
  String get speed => 'Kecepatan';

  @override
  String spentTime(Object time) {
    return 'Menghabiskan waktu: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Semua server sudah ada (ditemukan $duplicateCount duplikat)';
  }

  @override
  String get ssh => 'SSH';

  @override
  String get sshConnectionModeTip =>
      'Built-in: use the app\'s terminal. System SSH: launch the system ssh command in an external terminal.';

  @override
  String get sshConnectionModeUseBuiltin => 'Use built-in terminal';

  @override
  String get sshConnectionModeUseSystem => 'Use system SSH';

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
  String get sshViaMonitor => 'SSH lewat monitor';

  @override
  String get sshViaMonitorTip =>
      'Menjangkau SSH server ini lewat agen monitor-nya, untuk host yang port SSH-nya tidak bisa dihubungi langsung. Agen hanya meneruskan byte: sesi tetap terenkripsi ujung ke ujung dan host key-nya tetap diverifikasi di sini. Alamat tujuan diatur pada agen dan tidak bisa dipilih dari aplikasi.';

  @override
  String get sshViaMonitorNeedsMonitor =>
      'SSH lewat monitor membutuhkan alamat monitor.';

  @override
  String get sshViaMonitorConflictsWithOtherTransport =>
      'SSH lewat monitor tidak bisa digabung dengan jump server, ProxyCommand, atau alamat cadangan.';

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
  String get stat => 'Statistik';

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
  String get syncAppSettings => 'Sync app settings';

  @override
  String get syncAppSettingsTip =>
      'Include theme, layout, editor, terminal and other device preferences in automatic sync.';

  @override
  String get system => 'Sistem';

  @override
  String get termFontSizeTip =>
      'Pengaturan ini akan memengaruhi ukuran terminal (lebar dan tinggi). Anda dapat melakukan zoom pada halaman terminal untuk menyesuaikan ukuran font sesi saat ini.';

  @override
  String get textScaler => 'Penskalaan font';

  @override
  String get textScalerTip =>
      '1.0 => 100% (ukuran asli), hanya berfungsi pada bagian halaman server font, tidak disarankan untuk diubah.';

  @override
  String get time => 'Waktu';

  @override
  String get times => 'Waktu';

  @override
  String get trySudo => 'Cobalah menggunakan sudo';

  @override
  String get sudoPromptNotFound =>
      'Tidak ada permintaan kata sandi sudo yang aktif.';

  @override
  String get unknown => 'Tidak dikenal';

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
  String get viewErr => 'Lihat kesalahan';

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
  String get wiki => 'Wiki';

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
  String get menuGitHubRepository => 'GitHub Repository';

  @override
  String get podmanDockerEmulationDetected =>
      'Emulasi Podman Docker terdeteksi. Silakan beralih ke Podman di pengaturan.';

  @override
  String get portForwardBeta =>
      'This feature is still in beta testing. Functionality is not guaranteed.';

  @override
  String get portForward_startPrompt =>
      'Add a port forward rule to get started';

  @override
  String get portForward_localHost => 'Local Host';

  @override
  String get portForward_localPort => 'Local Port';

  @override
  String get portForward_remoteHost => 'Remote Host';

  @override
  String get portForward_remotePort => 'Remote Port';

  @override
  String get portForward_type_local => 'Local';

  @override
  String get portForward_type_remote => 'Remote';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return 'Delete $name?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sort => 'Sort';

  @override
  String get sortByName => 'By name';

  @override
  String get sortByJoinTime => 'By join time';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get serverHistory => 'Server history';

  @override
  String get clearHistory => 'Clear history';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'tmux auto-attach';

  @override
  String get tmuxAuto => 'Auto tmux';

  @override
  String get tmuxAutoTip =>
      'Automatically start or attach tmux when connecting over SSH';

  @override
  String get tmuxSessionSelector => 'Session selector';

  @override
  String get tmuxSessionSelectorTip =>
      'Show the session picker when connecting';

  @override
  String get tmuxDefaultSessionName => 'Default session name';

  @override
  String get tmuxSessionName => 'Session name';

  @override
  String get tmuxExistingSessions => 'Existing sessions';

  @override
  String get tmuxNewSession => 'New session';

  @override
  String get tmuxWindows => 'Windows';

  @override
  String get tmuxNewWindow => 'New window';

  @override
  String get tmuxNoWindowsFound => 'No windows found';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count windows',
      one: '1 window',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count panes',
      one: '1 pane',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Attached';

  @override
  String get tmuxActive => 'Active';

  @override
  String tmuxActiveAt(String time) {
    return 'active: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'attached: $time';
  }

  @override
  String get tmuxSkip => 'Skip';

  @override
  String get tmuxNotAvailable => 'tmux is not available';

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
}
