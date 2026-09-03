// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get crashCollect => 'Tanılama verileri';

  @override
  String get crashCollectIntro =>
      'ServerBox, sorunların düzeltilebilmesi için çalışırken olanları kaydeder. Ne kadar bilgi gönderileceğini seçin.';

  @override
  String get crashCollectNone => 'Hiçbir şey';

  @override
  String get crashCollectNoneTip =>
      'Raporlar bu cihazda tutulur; çökmenin ardından bir raporu elle gönderebilirsiniz.';

  @override
  String get crashCollectBasic => 'Temel bilgiler';

  @override
  String get crashCollectBasicTip =>
      'Yalnızca çökme bilgileri dahil edilir; günlükler ve performans verileri dahil edilmez. **Bu, uygulamayı geliştirmemize ve hataları düzeltmemize yardımcı olur.**';

  @override
  String get crashCollectFull => 'Tüm bilgiler';

  @override
  String get crashCollectFullTip =>
      'Çökme günlüğüne ek olarak performans verileri ve hangi özelliklerin kullanıldığı da dahil edilir: **Neyin yavaş olduğunu ve hangi özelliklerin gerçekten kullanıldığını bulmaya yarar.**';

  @override
  String get crashCollectFooter =>
      'Her düzeyde bilinen sunucu adları, adresler ve kullanıcı adları kaydedilirken yer tutucularla değiştirilir. Toplama düzeyini daha sonra Ayarlar\'dan değiştirebilirsiniz.';

  @override
  String get privacy => 'Gizlilik';

  @override
  String get privacyPolicy => 'Gizlilik politikası';

  @override
  String get crashUpload => 'Çökme raporlarını yükle';

  @override
  String get crashUploadTip =>
      'Çökme raporlarını geliştiriciye gönderir. Bilinen sunucu adları ve adresleri yer tutucularla değiştirilir. Varsayılan olarak kapalıdır; istediğiniz zaman kapatabilirsiniz.';

  @override
  String get crashNoticeBody =>
      'ServerBox son çalıştırmada beklenmedik şekilde kapandı. Çökme raporunu görüntülemek ister misiniz?';

  @override
  String get crashReportTitle => 'Çökme raporu';

  @override
  String get crashReportHint =>
      'Bu, önceki çalıştırmanın günlüğüdür. Bilinen sunucu adları ve adresleri yer tutucularla değiştirilmiştir, ancak başka ayrıntılar kalmış olabilir. Göndermeden önce dikkatlice okuyun.';

  @override
  String get crashReportSubmit => 'Kopyala ve bildir';

  @override
  String get acceptBeta => 'Beta sürüm güncellemelerini kabul et';

  @override
  String get addSystemPrivateKeyTip =>
      'Şu anda özel anahtarlar mevcut değil, sistemle birlikte gelen anahtarı (~/.ssh/id_rsa) eklemek ister misiniz?';

  @override
  String get added2List => 'Görev listesine eklendi';

  @override
  String get askAi => 'Yapay zekaya sor';

  @override
  String get askAiAwaitingResponse => 'Yapay zekâ yanıtı bekleniyor...';

  @override
  String get askAiEndpointTip =>
      'Alan adı veya tam URL. Yol, seçtiğin protokole göre tamamlanır.';

  @override
  String get askAiProtocolTip =>
      'Otomatik önce Responses, sonra Chat Completions dener.';

  @override
  String get askAiCommandInserted => 'Komut terminale eklendi';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Lütfen Ayarlar\'da $fields öğesini yapılandırın.';
  }

  @override
  String get askAiDisclaimer =>
      'Yapay zeka hata yapabilir. Lütfen dikkatli kullanın.';

  @override
  String get askAiInsertTerminal => 'Terminale ekle';

  @override
  String get askAiNoResponse => 'Yanıt yok';

  @override
  String get askAiAgentWelcome => 'Bu sunucuda ne yapalım?';

  @override
  String get askAiAgentPromptHint =>
      'Agent\'tan bir şeyi incelemesini veya düzeltmesini iste...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Seçili terminal çıktısını incele ve ne olduğunu açıkla';

  @override
  String get askAiTerminalContext => 'Terminal bağlamı';

  @override
  String get askAiReviewNeeded => 'İncele';

  @override
  String get askAiReviewAction => 'Önerilen komutu incele';

  @override
  String get askAiReviewBeforeContinuing =>
      'Önce mevcut öneriyi incele ya da reddet';

  @override
  String get askAiApproveRun => 'Onayla ve çalıştır';

  @override
  String get askAiDecline => 'Reddet';

  @override
  String get askAiActionDeclined => 'Önerilen komut reddedildi.';

  @override
  String get askAiInterrupted => 'Agent yanıtı kesildi.';

  @override
  String get askAiRiskReadOnly => 'Salt okunur';

  @override
  String get askAiRiskCaution => 'Sistemi değiştirir';

  @override
  String get askAiRiskUnvetted => 'Doğrulanmamış sunucu';

  @override
  String get askAiRiskDestructive => 'Yüksek risk';

  @override
  String get askAiHighRiskConfirmTitle =>
      'Yüksek riskli komut çalıştırılsın mı?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Bu komut geri alması zor değişiklikler yapabilir. Dikkatle kontrol et.';

  @override
  String get askAiNoCommandOutput => 'Komut çıktı üretmeden tamamlandı.';

  @override
  String get askAiOutputTruncated =>
      'Uzun çıktı, Agent\'a geri gönderilmeden önce kısaltıldı.';

  @override
  String get askAiAutoApproved => 'Otomatik onaylandı';

  @override
  String get askAiAutoRunSafeCommands =>
      'Salt okunur komutları otomatik çalıştır';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Yalnızca hem model hem yerel kontrol salt okunur derse çalışır';

  @override
  String get askAiSendOnEnter => 'Enter gönderir';

  @override
  String get askAiSendOnEnterTip =>
      'Enter gönderir, Shift+Enter yeni satır. Kapalı: Enter yeni satır, Cmd/Ctrl+Enter gönderir.';

  @override
  String get askAiApiKeyOptional =>
      'Yerel ya da kimlik doğrulaması gerekmiyorsa boş bırak';

  @override
  String get askAiHistory => 'Konuşma geçmişi';

  @override
  String get askAiNewConversation => 'Yeni konuşma';

  @override
  String get askAiNoHistory => 'Henüz kayıtlı konuşma yok';

  @override
  String get askAiNoHistoryMessages => 'Henüz mesaj yok';

  @override
  String get askAiUntitledConversation => 'Adsız';

  @override
  String get askAiRenameConversation => 'Konuşmayı yeniden adlandır';

  @override
  String get askAiDeleteConversationTitle => 'Bu konuşma silinsin mi?';

  @override
  String get askAiDeleteConversationTip => 'Bu cihazdan siler. Geri alınamaz.';

  @override
  String get askAiClearHistoryTitle =>
      'Bu sunucunun Agent geçmişi temizlensin mi?';

  @override
  String get askAiClearHistoryTip =>
      'Bu sunucu için kayıtlı tüm Agent konuşmaları silinecek.';

  @override
  String get askAiRestoredReview => 'Bu komut geçmişten geldi. Yeniden incele';

  @override
  String get agentWelcome => 'Sunucularında ne yapalım?';

  @override
  String get agentWelcomeTip =>
      'Agent bir sorunu inceleyebilir ya da bir işi yapabilir';

  @override
  String get agentPromptHint =>
      'Agent\'tan sunucularını incelemesini veya yönetmesini iste...';

  @override
  String get agentNoHistory => 'Kayıtlı genel Agent konuşması yok';

  @override
  String get agentClearHistoryTitle => 'Genel Agent geçmişi temizlensin mi?';

  @override
  String get agentClearHistoryTip =>
      'Tüm genel Agent konuşmaları bu cihazdan kaldırılır.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Dosya oku';

  @override
  String get agentToolWriteFile => 'Dosya yaz';

  @override
  String get agentToolFailed => 'Araç çalıştırılamadı.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count araç çağrısı';
  }

  @override
  String get floatOverTabs => 'Diğer sekmelerin üzerinde yüzsün';

  @override
  String get agentToolSshConnect => 'SSH bağlan';

  @override
  String get agentToolSshDisconnect => 'SSH bağlantısını kes';

  @override
  String get agentSshConnectTitle => 'Yeni bir sunucuya bağlan';

  @override
  String get agentAuthMethod => 'Kimlik doğrulama';

  @override
  String get agentSshConnectTip =>
      'Agent bir SSH bağlantısı istiyor. Parolayı buraya gir';

  @override
  String get agentAdHocSessions => 'Geçici bağlantılar';

  @override
  String get agentSaveServerTitle => 'Sunucu olarak kaydet';

  @override
  String get agentSaveServerTip =>
      'Bu host ve girdiğin parola bu cihazda saklanır';

  @override
  String get agentMonitorOptional => 'monitor aracısı (isteğe bağlı)';

  @override
  String get authFailTip => 'Kimlik doğrulama başarısız. Bilgileri kontrol et';

  @override
  String get autoBackupConflict =>
      'Aynı anda yalnızca bir otomatik yedekleme açık olabilir.';

  @override
  String get autoConnect => 'Otomatik bağlan';

  @override
  String get autoRun => 'Otomatik çalıştır';

  @override
  String get autoUpdateHomeWidget => 'Ana ekran bileşenini otomatik güncelle';

  @override
  String get availableTabs => 'Mevcut Sekmeler';

  @override
  String get backupEncrypted => 'Yedekleme şifrelenmiş';

  @override
  String get backupNotEncrypted => 'Yedekleme şifreli değil';

  @override
  String get backupPassword => 'Yedekleme parolası';

  @override
  String get backupPasswordRemoved => 'Yedekleme parolası kaldırıldı';

  @override
  String get backupPasswordSet => 'Yedekleme parolası ayarlandı';

  @override
  String get backupPasswordTip =>
      'Yedekleme dosyalarını şifrelemek için bir parola belirleyin. Şifrelemeyi devre dışı bırakmak için boş bırakın.';

  @override
  String get backupPasswordWrong => 'Yanlış yedekleme parolası';

  @override
  String get connectAll => 'Tümünü bağla';

  @override
  String get disconnectAll => 'Tümünün bağlantısını kes';

  @override
  String get distIcon => 'Dağıtım işaretleri';

  @override
  String get distIconIntroLegal =>
      'Bir işaret yalnızca bu cihazın uzak sistemden okuduğunu belirtir; bu bilgi yanlış veya güncel olmayabilir ve bir türevi, yeniden derlemeyi ya da belirli bir sürümü göstermez. Belirlenemediğinde sade bir simge çizilir.\n\nHer işaret ilgili sahibinin ticari markasıdır ve burada yalnızca işaret ettiği sistemi belirtmek için kullanılır.';

  @override
  String get distIconTip =>
      'Her sunucunun yanında, üzerinde çalıştığı görünen sistemin küçük bir işaretini göster';

  @override
  String get distNameMap => 'Ad eşleştirme';

  @override
  String get distNameMapTip =>
      'Yalnızca işaretleri barındırdığınız yerde dosyası başka adla duran bir dağıtım için. Anahtar, bu uygulamanın kullandığı ad; değer ise indirilecek ad. Eksik bir işaret olmadıkça boş bırakın.';

  @override
  String get logoUrl => 'Logo adresi';

  @override
  String get logoUrlTip =>
      'Bir sunucunun kendi sayfasının üstündeki büyük görsel, kendi renkleriyle.';

  @override
  String get markUrl => 'İşaret adresi';

  @override
  String get markUrlTip =>
      'Listelerde sunucu adının yanındaki küçük işaret. Boşsa hiçbiri çizilmez.\n\nLogoyla aynı görsel değil';

  @override
  String get navTabMenuTip =>
      'İçindeki her şeyi tek seferde bağlamak veya bağlantısını kesmek için bir sekmeye uzun basın ya da sağ tıklayın.';

  @override
  String nTags(Object count) {
    return '$count etiket';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Uzak yedeklemeler için boş olmayan bir yedekleme parolası gerekir';

  @override
  String get monitorHttpsRequired =>
      'Uzak monitor ajanı HTTPS ister, HTTP’ye izin verilmediyse.';

  @override
  String get monitorAllowInsecureHttp => 'HTTP’ye izin ver';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Yalnızca taşımayı kendisi şifreleyen güvenilir özel ağlarda, örneğin Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Bu sunucunun durumunu SSH ile komut çalıştırmak yerine bir **monitor** aracısının HTTP API\'sinden okur.\n\nAracının önce sunucuya kurulması gerekir; eğilimler, saat uygulaması ve ana ekran bileşenleri buna bağlıdır.\n\n[monitor aracısı nasıl kurulur]($url)';
  }

  @override
  String get backupTip =>
      'Dışa aktarılan veriler parola ile şifrelenebilir. \nLütfen güvenli bir şekilde saklayın.';

  @override
  String get icloudBackupStatusTitle => 'Yedekleme durumu';

  @override
  String get icloudBackupStatusLoading =>
      'iCloud yedekleme durumu yükleniyor...';

  @override
  String get icloudBackupStatusError =>
      'iCloud yedekleme meta verileri okunamıyor';

  @override
  String get icloudBackupStatusEmpty =>
      'Henüz bir iCloud yedekleme dosyası bulunamadı';

  @override
  String get icloudBackupStateUploading => 'Yükleniyor';

  @override
  String get icloudBackupStateConflict => 'Çakışma algılandı';

  @override
  String get icloudBackupStateUploaded => 'Yüklendi';

  @override
  String get icloudBackupStateWaiting => 'iCloud bekleniyor';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Son yedekleme: $lastModified\nDurum: $remoteState';
  }

  @override
  String get bgRun => 'Arka planda çalıştır';

  @override
  String get bgRunTip =>
      'Bu anahtar yalnızca programın arka planda çalışmayı deneyeceği anlamına gelir. Arka planda çalışıp çalışamayacağı, iznin etkinleştirilip etkinleştirilmediğine bağlıdır. AOSP tabanlı Android ROM\'lar için lütfen bu uygulamada \"Pil Optimizasyonu\"nu devre dışı bırakın. MIUI / HyperOS için lütfen güç tasarrufu politikasını \"Sınırsız\" olarak değiştirin.';

  @override
  String get trayKeepRunning => 'Keep running in the tray';

  @override
  String get trayKeepRunningTip =>
      'Closing the window leaves the app in the menu bar or notification area, still watching your servers. Turn this off to have the close button end the app.';

  @override
  String get bgRunNeedsNotification =>
      'Arka planda çalışmak kalıcı bir bildirim gerektirir ve bu uygulamanın bildirim izni yok. İzin vermek için dokunun.';

  @override
  String get clearAllStatsContent =>
      'Tüm sunucu bağlantı istatistiklerini temizlemek istediğinizden emin misiniz? Bu işlem geri alınamaz.';

  @override
  String get clearAllStatsTitle => 'Tüm İstatistikleri Temizle';

  @override
  String clearServerStatsContent(Object serverName) {
    return '\"$serverName\" sunucusu için bağlantı istatistiklerini temizlemek istediğinizden emin misiniz? Bu işlem geri alınamaz.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return '$serverName İstatistiklerini Temizle';
  }

  @override
  String get clearThisServerStats => 'Bu Sunucu İstatistiklerini Temizle';

  @override
  String get compactDatabase => 'Veritabanını Sıkıştır';

  @override
  String compactDatabaseContent(Object size) {
    return 'Veritabanı boyutu: $size\n\nBu, dosya boyutunu küçültmek için veritabanını yeniden düzenleyecektir. Veriler silinmeyecek.';
  }

  @override
  String get closeAfterSave => 'Kaydet ve kapat';

  @override
  String get collapseUITip =>
      'Arayüzde uzun listelerin varsayılan olarak daraltılıp daraltılmayacağı';

  @override
  String get connectionDetails => 'Bağlantı Detayları';

  @override
  String get connectionStats => 'Bağlantı İstatistikleri';

  @override
  String get connectionStatsDesc =>
      'Sunucu bağlantı başarı oranını ve geçmişi görüntüle';

  @override
  String get containerTrySudoTip =>
      'Örneğin: Uygulamada kullanıcı aaa olarak ayarlanmış, ancak Docker root kullanıcısı altında kurulmuş. Bu durumda bu seçeneği etkinleştirmeniz gerekir.';

  @override
  String get containerSudoPasswordRequired =>
      'Docker\'e erişmek için sudo şifresi gereklidir. Lütfen şifrenizi girin.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Sudo şifresi yanlış veya izin verilmiyor. Lütfen tekrar deneyin.';

  @override
  String get copyPath => 'Yolu kopyala';

  @override
  String get cpuViewAsProgressTip =>
      'Her CPU\'nun kullanımını ilerleme çubuğu tarzında göster (eski tarz)';

  @override
  String get customCmd => 'Özel komutlar';

  @override
  String get deleteServers => 'Sunucuları toplu sil';

  @override
  String get deleteDirRecursive => 'Klasörü ve içindeki her şeyi sil';

  @override
  String get desktopTerminalTip =>
      'SSH oturumları başlatılırken terminal öykünücüsünü açmak için kullanılan komut.';

  @override
  String get dirEmpty => 'Klasörün boş olduğundan emin olun.';

  @override
  String get discoverSshServers => 'SSH Sunucularını Keşfet';

  @override
  String get discoveryFailed => 'Keşif başarısız';

  @override
  String get discoverySettings => 'Keşif Ayarları';

  @override
  String get distro => 'Dağıtım';

  @override
  String get diskHealth => 'Disk sağlığı';

  @override
  String get displayCpuIndex => 'CPU indeksini göster';

  @override
  String dl2Local(Object fileName) {
    return '$fileName dosyasını yerel cihaza indir?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Çalışan konteyner yok.\nBunun nedeni şunlar olabilir:\n- Docker kurulum kullanıcısı, uygulamada yapılandırılan kullanıcı adıyla aynı değil.\n- DOCKER_HOST ortam değişkeni doğru okunmadı. Terminalde `echo \$DOCKER_HOST` komutunu çalıştırarak kontrol edebilirsiniz.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count görüntü';
  }

  @override
  String get dockerProjectOther => 'Diğer';

  @override
  String get dockerPruneTip =>
      'Disk alanını boşaltmak için kullanılmayan verileri kaldırın';

  @override
  String get dockerStatistics => 'Docker İstatistikleri';

  @override
  String get doubleColumnMode => 'Çift sütun modu';

  @override
  String get doubleColumnTip =>
      'Bu seçenek yalnızca özelliği etkinleştirir, gerçekten etkinleşip etkinleşmeyeceği cihazın genişliğine bağlıdır';

  @override
  String get editVirtKeys => 'Sanal tuşlar';

  @override
  String get editorHighlightTip =>
      'Mevcut kod vurgulama performansı ideal değil ve isteğe bağlı olarak kapatılabilir.';

  @override
  String get enableMdns => 'mDNS\'yi Etkinleştir';

  @override
  String get enableMdnsDesc =>
      'SSH hizmetlerini keşfetmek için mDNS/Bonjour kullan';

  @override
  String get envVars => 'Ortam değişkeni';

  @override
  String get extraArgs => 'Ek argümanlar';

  @override
  String get fallbackSshDest => 'Yedek SSH hedefi';

  @override
  String get fdroidReleaseTip =>
      'Bu uygulamayı F-Droid\'den indirdiyseniz, bu seçeneği kapatmanız önerilir.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '\'$file\' dosyası çok büyük $size, maksimum $sizeMax';
  }

  @override
  String get fileDirGone => 'Bu klasör artık burada değil';

  @override
  String get fileDirGoneTip => 'Silinmiş ya da adı değişmiş';

  @override
  String get fullScreen => 'Tam ekran';

  @override
  String get fullScreenJitter => 'Tam ekran titreşim';

  @override
  String get fullScreenJitterHelp => 'Ekran yanmasını önlemek için';

  @override
  String get fullScreenTip =>
      'Cihaz yatay moda döndürüldüğünde tam ekran modu etkinleştirilsin mi? Bu seçenek yalnızca sunucu sekmesi için geçerlidir.';

  @override
  String get githubGistIdOptional => 'Gist kimliği (isteğe bağlı)';

  @override
  String get githubGistToken => 'GitHub Gist belirteci';

  @override
  String get githubGistTokenEmpty => 'Belirteç boş';

  @override
  String get goto => 'Git';

  @override
  String get homeTabs => 'Ana Sayfa Sekmeleri';

  @override
  String get homeTabsCustomizeDesc =>
      'Ana sayfada görünecek sekmeleri ve sıralarını özelleştirin';

  @override
  String get ignoreCert => 'Sertifikayı yok say';

  @override
  String get image => 'Görüntü';

  @override
  String get macDmgBody =>
      'App Store bu uygulamanın kum havuzunda çalışmasını ister ve kum havuzu terminal açamaz. DMG sürümü açabilir.\n\nApp Store sürümü ileride güncellenmeyebilir.';

  @override
  String get macDmgImportDenied => 'macOS önceki sürümün verisini okutmadı';

  @override
  String get macDmgImported => 'Önceki sürümün verisi içe aktarıldı';

  @override
  String get macDmgImportFailed => 'Önceki sürümün verisi okunamadı';

  @override
  String get macDmgTip =>
      'Yerel terminal ve snippet’leri yerelde çalıştırma (DMG sürümü)';

  @override
  String get macDmgTitle => 'DMG sürümü';

  @override
  String get showHiddenFiles => 'Gizli dosyaları göster';

  @override
  String get sshKeyAlgorithm => 'Algoritma';

  @override
  String get sshKeyComment => 'Açıklama';

  @override
  String get sshKeyGenerate => 'Anahtar çifti oluştur';

  @override
  String get sshKeyGenerating => 'Oluşturuluyor…';

  @override
  String sshKeyLockedFmt(String name) {
    return '[$name] özel anahtarının kilidi açılmadı.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'İsteğe bağlı. Parola belirlenen anahtar şifreli saklanır ve bir bağlantı anahtarı ilk kez kullandığında parola sorulur.';

  @override
  String get sshKeyPassphraseWrong => 'Parola yanlış.';

  @override
  String get sshKeyPublicKey => 'Genel anahtar';

  @override
  String get sshKeyPublicKeyTip =>
      'Bu satırı sunucudaki ~/.ssh/authorized_keys dosyasına ekleyin.';

  @override
  String get sshKeyRecommended => 'Önerilen';

  @override
  String sshKeyUnlockTip(String name) {
    return '[$name] özel anahtarının parolasını girin.';
  }

  @override
  String get ungrouped => 'Gruplandırılmamış';

  @override
  String get unused => 'Kullanılmıyor';

  @override
  String get dangling => 'Askıda';

  @override
  String get pruneUnusedImages => 'Kullanılmayan görüntüleri temizle';

  @override
  String get pruneDanglingImages => 'Askıdaki görüntüleri temizle';

  @override
  String get pruneImages => 'Görüntüleri temizle';

  @override
  String get unusedTaggedImages => 'Kullanılmayan etiketliler';

  @override
  String get pruneDanglingImagesTip => 'Yalnızca boşta kalan imajları siler.';

  @override
  String get pruneUnusedImagesTip =>
      'Hiçbir konteyner tarafından kullanılmayan etiketli görüntüleri de kaldırır.';

  @override
  String get includeUnusedVolumesTip =>
      'Hiçbir konteyner tarafından kullanılmayan birimleri de kaldırır.';

  @override
  String get pruneCommandPreview => 'Komut önizlemesi';

  @override
  String get pruneForceSshTip =>
      '-f etkileşimli onayı atlar ve SSH yürütmesinde her zaman etkindir.';

  @override
  String get pruneVolumes => 'Birimleri temizle';

  @override
  String get pruneUnusedData => 'Kullanılmayan verileri temizle';

  @override
  String get pull => 'Çek';

  @override
  String get invalidHostFormat =>
      'Geçersiz ana makine biçimi. Yalnızca IPv4, IPv6 ve alan adı karakterlerine izin verilir.';

  @override
  String get jumpServer => 'Atlama sunucusu';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return '$serverName için atlama sunucuları bulunamadı: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '\"$name\" zaten mevcut';
  }

  @override
  String get noJumpServerAvailable => 'Kullanılabilir atlama sunucusu yok.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Atlama sunucusu ile ProxyCommand birlikte kullanılamaz.';

  @override
  String get noConnectionMethod =>
      'SSH, monitor aracısı veya ikisini birden yapılandırın';

  @override
  String get preferredTransport => 'Önce denenecek';

  @override
  String get preferredTransportTip =>
      'Durumun nereden okunacağı ve bir komutun önce hangi bağlantıyı açacağı. Diğeri kullanılabilir kalır.';

  @override
  String get keepForeground => 'Uygulamayı ön planda tut!';

  @override
  String get keepStatusWhenErr => 'Son sunucu durumunu koru';

  @override
  String get keepStatusWhenErrTip =>
      'Yalnızca betik yürütülmesi sırasında bir hata olduğunda';

  @override
  String get keyAuth => 'Anahtar Kimlik Doğrulama';

  @override
  String get lastFailure => 'Son Başarısızlık';

  @override
  String get lastSuccess => 'Son Başarı';

  @override
  String get letterCache => 'Normal klavye girişi';

  @override
  String get letterCacheTip =>
      'Etkinleştirildiğinde giriş normal IME üzerinden yapılır; bu da bazı sistemlerde terminalde güvenli klavye istemlerini önleyebilir.';

  @override
  String get linuxShellTip =>
      'Terminalin hangi kabukla açılacağı. Boş bırakınca /bin/sh’a döner.';

  @override
  String get linuxNetTip => 'DNS sunucuları. Boş bırakınca varsayılana döner';

  @override
  String madeWithLove(Object myGithub) {
    return '$myGithub tarafından ❤️ ile yapıldı';
  }

  @override
  String get maxConcurrency => 'Maksimum Eşzamanlılık';

  @override
  String get maxRetryCount => 'Sunucu yeniden bağlantı sayısı';

  @override
  String mismatchSystem(Object system) {
    return 'Eşleşmeyen sistem: $system';
  }

  @override
  String get mirror => 'Yansı';

  @override
  String get needRestart => 'Uygulamanın yeniden başlatılması gerekiyor';

  @override
  String get netViewType => 'Ağ görüntüleme türü';

  @override
  String get newContainer => 'Yeni konteyner';

  @override
  String get noConnectionStatsData => 'Bağlantı istatistik verisi yok';

  @override
  String get noLineChart => 'Çizgi grafikleri kullanma';

  @override
  String get noPrivateKeyTip =>
      'Özel anahtar mevcut değil, silinmiş olabilir veya yapılandırma hatası vardır.';

  @override
  String get noPromptAgain => 'Tekrar sorma';

  @override
  String get openLastPath => 'Son yolu aç';

  @override
  String get openLastPathTip =>
      'Farklı sunucular farklı günlükler tutar ve günlük, çıkış yoludur';

  @override
  String get parseContainerStatsTip =>
      'Docker\'ın doluluk durumunu ayrıştırmak oldukça yavaş.';

  @override
  String get plugInType => 'Eklenti Türü';

  @override
  String get preferDiskAmount => 'Disk kapasitesini öncelikli olarak göster';

  @override
  String get privateKey => 'Özel Anahtar';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Özel anahtar [$keyId] bulunamadı.';
  }

  @override
  String get bmcPowerOnAction => 'Aç';

  @override
  String get bmcShutdown => 'Kapat';

  @override
  String get bmcForceOff => 'Zorla kapat';

  @override
  String get restart => 'Yeniden başlat';

  @override
  String get bmcPowerCycle => 'Güç döngüsü';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return '$server için gönderilsin mi? Servise \"$resetType\" istenecek';
  }

  @override
  String get bmcPowerDone => 'Güç durumu değişti';

  @override
  String get bmcPowerAccepted =>
      'Kabul edildi ama güç durumu değişmedi. Nazik işlem işletim sistemine bağlı';

  @override
  String get bmcPowerUnsupported =>
      'Bu hizmet o eylem için hiçbir şeye izin vermiyor';

  @override
  String get bmcUnauthorized => 'BMC hesabı reddetti';

  @override
  String get bmcAccountMissing => 'Bu BMC için hesap ayarlanmamış';

  @override
  String get bmcPowerOn => 'Açık';

  @override
  String get bmcPowerOff => 'Kapalı';

  @override
  String get bmcCertRejected =>
      'Sertifika reddedildi — sunucu ayarlarından inceleyin';

  @override
  String get bmcNotAService => 'Bu adreste Redfish hizmeti yok';

  @override
  String get bmcNoSystem => 'Hizmet herhangi bir sistem bildirmiyor';

  @override
  String get bmcSensorsTruncated => 'Yalnızca ilk sensörler gösteriliyor';

  @override
  String get bmcMultipleSystems => 'Yalnızca ilk sistem gösteriliyor';

  @override
  String get bmcTip =>
      'BMC, anakart üzerindeki ayrı bir bilgisayardır ve ana makinenin işletim sistemine ulaşılamadığında da erişilebilir. Burada yapılandırıldığında, sunucu kapalıyken ya da takılıyken güç durumunu ve donanım sensörlerini bildirir. Redfish gerektirir; yaklaşık 2016\'dan sonraki kurumsal donanımların çoğunda bulunur.';

  @override
  String get bmcCert => 'Sertifika';

  @override
  String get bmcCertPinned => 'İncelendi ve sabitlendi';

  @override
  String get bmcCertUnreviewed =>
      'Henüz incelenmedi — sertifikayı görmek için dokun';

  @override
  String get bmcCertReview =>
      'Kendinden imzalı bir sertifika. Kabul etmeden önce karşılaştır. Sonrasında yalnızca bu güvenilir.';

  @override
  String get bmcCertChanged => 'Sertifika eşleşmiyor. Kontrol et.';

  @override
  String get bmcCertExpired => 'Süresi dolmuş.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Daha önce kabul edilen: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'BMC adresi bir URL olmalı, örneğin https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Bu sürüm kum havuzunda çalışır: komut boş bir home alır, seninkini değil, bu yüzden ~/.ssh okuyan her şey başarısız olur. DMG sürümünde bu kısıtlama yok.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Özel anahtar dosyası $path okunamıyor: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Bu sürüm kendi kapsayıcısı dışındaki dosyaları okuyamıyor, bu yüzden $path konumundaki anahtara erişilemiyor. Anahtarı Ayarlar\'dan içe aktarın ya da DMG sürümünü kullanın.';
  }

  @override
  String get pushToken => 'Push belirteci';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand yalnızca masaüstü platformlarda desteklenir.';

  @override
  String get pveIgnoreCertTip =>
      'Etkinleştirilmesi önerilmez, güvenlik risklerine dikkat edin! PVE\'den varsayılan sertifikayı kullanıyorsanız, bu seçeneği etkinleştirmeniz gerekir.';

  @override
  String get pveServerClientMissing =>
      'Bu sunucunun SSH istemcisi kullanılamıyor.';

  @override
  String get pveAddressMissing =>
      'PVE adresi eksik. Lütfen sunucu ayarlarından yapılandır.';

  @override
  String get pvePasswordRequired =>
      'PVE parolası gerekli. Lütfen sunucu ayarlarında belirle.';

  @override
  String get pveOtpRequired =>
      'Bu PVE sunucusunda iki adımlı doğrulama açık. Lütfen OTP kodunu gir.';

  @override
  String get pveOtpChallengeExpired =>
      'OTP isteğinin süresi doldu. Lütfen yenileyip tekrar dene.';

  @override
  String get pveOtpCodeRequired => 'OTP kodu gerekli.';

  @override
  String get pveOtpVerificationFailed =>
      'OTP doğrulaması başarısız. Lütfen yeni bir kodla tekrar dene.';

  @override
  String get pveOtpTitle => 'OTP doğrulaması';

  @override
  String get pveOtpLabel => 'OTP kodu';

  @override
  String get pveInvalidResponseBody =>
      'PVE oturum açma isteği geçersiz bir yanıt gövdesi döndürdü.';

  @override
  String get pveInvalidResponseData =>
      'PVE oturum açma yanıtı geçerli bir veri içermiyordu.';

  @override
  String get pveMissingAuthTicket =>
      'PVE oturumu açıldı ancak kimlik doğrulama bileti döndürülmedi.';

  @override
  String get pveVersionLow =>
      'Bu özellik şu anda test aşamasında ve yalnızca PVE 8+ üzerinde test edildi. Lütfen dikkatli kullanın.';

  @override
  String get pveLoadingForwarding => 'SSH tüneli kuruluyor...';

  @override
  String get pveLoadingLogin => 'PVE ile kimlik doğrulanıyor...';

  @override
  String get pveLoadingData => 'Küme verileri alınıyor...';

  @override
  String get pveLoadingConnect => 'Bağlanıyor...';

  @override
  String get pvePassword => 'PVE parolası';

  @override
  String get pvePasswordHint =>
      'Anahtar tabanlı SSH kimlik doğrulaması kullanılırken gerekir';

  @override
  String get read => 'Oku';

  @override
  String get recentConnections => 'Son Bağlantılar';

  @override
  String get rememberPwdInMem => 'Şifreyi bellekte hatırla';

  @override
  String get rememberPwdInMemTip =>
      'Konteynerler, askıya alma vb. için kullanılır.';

  @override
  String get remotePath => 'Uzak yol';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed kurulu, $latest var. Güncelleme tüm konteyneri değiştirir: $pm verisi kaybolur';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Silmeden önce $name üzerindeki terminalleri kapat';
  }

  @override
  String get rootfsSubtitle => 'Bu cihazdaki bir Linux kullanıcı alanı';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return '$distro $version (yaklaşık $size MB) indirir ve bu cihaza açar.';
  }

  @override
  String get sameIdServerExist => 'Aynı kimliğe sahip bir sunucu zaten mevcut';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'Bu sunucuya SSH ya da dosya API’si açık server_box_monitor gerekir.';

  @override
  String get back => 'Geri';

  @override
  String get history => 'Geçmiş';

  @override
  String get homeDir => 'Ana klasör';

  @override
  String selected(Object count) {
    return '$count seçildi';
  }

  @override
  String get sendTo => 'Şuraya gönder…';

  @override
  String get serverDetailOrder => 'Ayrıntı sayfası bileşen sırası';

  @override
  String get serverFuncBtns => 'Sunucu işlev düğmeleri';

  @override
  String get serverOrder => 'Sunucu sırası';

  @override
  String get serverTabEmpty => 'Henüz sunucu yok';

  @override
  String get serverTabRequired => 'Sunucu sekmesi kaldırılamaz';

  @override
  String get shareServerRiskTip =>
      'Bu QR kod bağlantı ayarlarını düz metin olarak taşır. Tarayan ya da fotoğraflayan herkes bağlanabilir.';

  @override
  String get sftpDlPrepare => 'Bağlantı hazırlanıyor...';

  @override
  String get sftpEditorTip =>
      'Boşsa yerleşik düzenleyici kullanılır. Örneğin `vim` (`EDITOR`’dan okumak önerilir).';

  @override
  String get sftpRmrDirSummary =>
      'SFTP\'de bir klasörü silmek için `rm -r` kullan.';

  @override
  String get sftpSSHConnected => 'SFTP Bağlandı';

  @override
  String get sftpShowFoldersFirst => 'Önce klasörleri göster';

  @override
  String get sftpUnavailableUseScp =>
      'Birçok gömülü cihazda olduğu gibi bu makinede SFTP alt sistemi yoksa, sunucu ayarlarından dosya aktarımını SCP yapın.';

  @override
  String get sshFileTransportTip =>
      'Güncel her cihaz için SFTP uygundur. SSH sunucusunda SFTP alt sistemi bulunmayan eski ya da gömülü bir makine için SCP seçin: `scp` komutunun yanı sıra `find`, `stat`, `mv`, `chmod` gibi olağan dosya araçlarına sahip bir kabuk ortamı gerekir.';

  @override
  String get specifyDev => 'Cihazı belirt';

  @override
  String get specifyDevTip =>
      'Ağ trafiği varsayılan olarak tüm aygıtları sayar; burada birini belirt';

  @override
  String get tempIsCelsiusTip =>
      'Açıkken sıcaklık değeri milisantigrat yerine santigrat olarak işlenir. Yalnızca sıcaklık yanlış görünüyorsa aç (örneğin 58 °C yerine 0,1 °C).';

  @override
  String spentTime(Object time) {
    return 'Harcanan süre: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Tüm sunucular zaten mevcut ($duplicateCount kopya bulundu)';
  }

  @override
  String get sshConnectionModeTip =>
      'Yerleşik: uygulamanın terminalini kullanır. Sistem SSH: sistemin ssh komutunu harici bir terminalde başlatır.';

  @override
  String get sshConnectionModeUseBuiltin => 'Yerleşik terminali kullan';

  @override
  String get sshConnectionModeUseSystem => 'Sistem SSH\'ini kullan';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount kopya atlanacak';
  }

  @override
  String get sshConfigFound => 'Sisteminizde SSH yapılandırması bulduk';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return '$totalCount sunucu bulundu';
  }

  @override
  String get sshConfigImport => 'SSH Yapılandırma İçe Aktarma';

  @override
  String get sshConfigImportPermission =>
      '~/.ssh/config dosyasını okumak ve sunucu ayarlarını otomatik olarak içe aktarmak için izin vermek ister misiniz?';

  @override
  String get sshConfigImportTip =>
      'İlk sunucu oluşturulurken ~/.ssh/config okuma istemi';

  @override
  String sshConfigImported(Object count) {
    return 'SSH yapılandırmasından $count sunucu içe aktarıldı';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return '$serverName için SSH ana bilgisayar anahtarı değişti. Yalnızca bu sunucuya güveniyorsanız devam edin.';
  }

  @override
  String get sshHostKeyType => 'SSH ana bilgisayar anahtarı türü';

  @override
  String get sshKnownHostKeys => 'Bilinen ana makineler';

  @override
  String get sshKnownHostKeysTip =>
      'Bu uygulamanın kabul ettiği host anahtarları';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return '$serverName üzerinden yeni bir SSH ana bilgisayar anahtarı alındı. Güvenmeden önce parmak izini kontrol edin.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Kaydedilen parmak izi: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Doğrulama kodu';

  @override
  String get sshConfigManualSelect =>
      'SSH yapılandırma dosyasını manuel olarak seçmek ister misiniz?';

  @override
  String get sshConfigNoServers => 'SSH yapılandırmasında sunucu bulunamadı';

  @override
  String get sshConfigPermissionDenied =>
      'macOS izinleri nedeniyle SSH yapılandırma dosyasına erişilemiyor.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount sunucu içe aktarılacak';
  }

  @override
  String get sshTermHelp =>
      'Terminal kaydırılabilir olduğunda, yatay olarak sürüklemek metni seçebilir. Klavye düğmesine tıklamak klavyeyi açar/kapar. Dosya simgesi mevcut yolu SFTP\'de açar. Pano düğmesi, metin seçiliyken içeriği kopyalar ve metin seçili değilken panoda içerik varsa terminale yapıştırır. Kod simgesi, kod parçacıklarını terminale yapıştırır ve yürütür.';

  @override
  String get sshVirtualKeyAutoOff => 'Sanal tuşların otomatik geçişi';

  @override
  String get supportFmtArgs =>
      'Aşağıdaki biçimlendirme parametreleri desteklenir:';

  @override
  String get suspendTip =>
      'Askıya alma işlevi, root izni ve systemd desteği gerektirir.';

  @override
  String switchTo(Object val) {
    return '$val\'a geç';
  }

  @override
  String get syncAppSettings => 'Uygulama ayarlarını eşitle';

  @override
  String get syncAppSettingsTip =>
      'Tema, düzen, düzenleyici, terminal ve diğer cihaz tercihlerini otomatik eşitlemeye dâhil et.';

  @override
  String get termFontSizeTip =>
      'Bu ayar terminal boyutunu (genişlik ve yükseklik) etkiler. Terminal sayfasında yakınlaştırarak mevcut oturumun yazı tipi boyutunu ayarlayabilirsiniz.';

  @override
  String get textScalerTip =>
      '1.0 => %100 (orijinal boyut), yalnızca sunucu sayfasındaki yazı tipinin bir kısmı üzerinde çalışır, değiştirilmesi önerilmez.';

  @override
  String get times => 'Kez';

  @override
  String get trySudo => 'Sudo ile dene';

  @override
  String get sudoPromptNotFound => 'Aktif bir sudo parola istemi yok.';

  @override
  String get updateServerStatusInterval => 'Sunucu durumu güncelleme aralığı';

  @override
  String get useNoPwd => 'Şifre kullanılmayacak';

  @override
  String get usePodmanByDefault => 'Varsayılan olarak Podman kullan';

  @override
  String get used => 'Kullanılan';

  @override
  String get view => 'Görünüm';

  @override
  String get viewDetails => 'Detayları Görüntüle';

  @override
  String get virtKeyHelpClipboard =>
      'Seçili terminal boş değilse panoya kopyala, aksi takdirde panodaki içeriği terminale yapıştır.';

  @override
  String get virtKeyHelpIME => 'Klavyeyi aç/kapat';

  @override
  String get virtKeyHelpSFTP => 'Mevcut dizini SFTP\'de aç.';

  @override
  String get virtKeyHelpSnippet =>
      'Bir parçacık seçip bu terminalde çalıştırır.';

  @override
  String get virtKeyHelpTmux =>
      'tmux oturumları ve pencereleri arasında geçiş yapar.';

  @override
  String get virtKeyIntroActions => 'Kısayollar';

  @override
  String get virtKeyIntroActionsTip =>
      'Bu tuşlar yazmaz, bir şey açar. Ne yaptığını okumak için birine basılı tutun.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'Terminal ayarlarından sıralarını değiştirebilir, hiç kullanmadıklarınızı gizleyebilirsiniz.';

  @override
  String get virtKeyIntroModifiers => 'Değiştirici tuşlar';

  @override
  String get virtKeyIntroModifiersTip =>
      'Birine dokunup etkinleştirin, sonra klavyeden bir harfe dokunun. Yalnızca o tek tuş için geçerlidir.';

  @override
  String get virtKeyIntroNav => 'İmleç hareketi';

  @override
  String get virtKeyIntroNavTip =>
      'Bu tuşlar imleci hareket ettirir. Yön tuşunu basılı tutarsanız yinelenir.';

  @override
  String get virtKeyIntroSelect =>
      'Terminalde kaydırılacak bir şey olduğu sürece, yana sürükleyerek metin seçebilirsiniz.';

  @override
  String get virtKeyRows => 'Aynı anda gösterilen satır';

  @override
  String get virtKeyRowsTip =>
      'Kalanlar yana kaydırılan ayrı bir sayfada yer alır.';

  @override
  String get waitConnection => 'Lütfen bağlantının kurulmasını bekleyin.';

  @override
  String get wakeLock => 'Uyanık tut';

  @override
  String get watchNotPaired => 'Eşleştirilmiş Apple Watch yok';

  @override
  String get webdavSettingEmpty => 'WebDav ayarı boş';

  @override
  String get whenOpenApp => 'Uygulama açıldığında';

  @override
  String get wolTip =>
      'WOL (Wake-on-LAN) yapılandırıldıktan sonra, sunucuya her bağlanıldığında bir WOL isteği gönderilir.';

  @override
  String get write => 'Yaz';

  @override
  String get writeScriptFailTip =>
      'Betik yazma başarısız oldu, muhtemelen izin eksikliği veya dizin mevcut değil.';

  @override
  String get writeScriptTip =>
      'Sunucuya bağlandıktan sonra, sistem durumunu izlemek için `~/.config/server_box` \n | `/tmp/server_box` dizinine bir betik yazılacak. Betik içeriğini inceleyebilirsiniz.';

  @override
  String get menuGitHubRepository => 'GitHub deposu';

  @override
  String get podmanDockerEmulationDetected =>
      'Podman Docker emülasyonu tespit edildi. Lütfen ayarlarda Podman\'a geçin.';

  @override
  String get betaTip =>
      'Bu özellik hâlâ beta aşamasında. İşleyişi garanti edilmez.';

  @override
  String get portForward_startPrompt =>
      'Başlamak için bir port yönlendirme kuralı ekle';

  @override
  String get portForward_localHost => 'Yerel ana makine';

  @override
  String get portForward_localPort => 'Yerel port';

  @override
  String get portForward_remoteHost => 'Uzak ana makine';

  @override
  String get portForward_remotePort => 'Uzak port';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return '$name silinsin mi?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Eklenme zamanına göre';

  @override
  String get serverHistory => 'Sunucu geçmişi';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'tmux\'a otomatik bağlan';

  @override
  String get tmuxAuto => 'Otomatik tmux';

  @override
  String get tmuxAutoTip =>
      'SSH ile bağlanırken tmux\'u otomatik başlat veya ona bağlan';

  @override
  String get tmuxSessionSelector => 'Oturum seçici';

  @override
  String get tmuxSessionSelectorTip => 'Bağlanırken oturum seçiciyi göster';

  @override
  String get tmuxDefaultSessionName => 'Varsayılan oturum adı';

  @override
  String get tmuxSessionName => 'Oturum adı';

  @override
  String get tmuxExistingSessions => 'Mevcut oturumlar';

  @override
  String get tmuxNewSession => 'Yeni oturum';

  @override
  String get tmuxWindows => 'Pencereler';

  @override
  String get tmuxNewWindow => 'Yeni pencere';

  @override
  String get tmuxNoWindowsFound => 'Pencere bulunamadı';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pencere',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bölme',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Bağlı';

  @override
  String get tmuxActive => 'Etkin';

  @override
  String tmuxActiveAt(String time) {
    return 'etkin: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'bağlandı: $time';
  }

  @override
  String get tmuxSkip => 'Atla';

  @override
  String get tmuxNotAvailable => 'tmux kullanılamıyor';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Konteyner yanıtındaki beklenmeyen bölüm sayısı: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Başka bir konteyner işlemi zaten devam ediyor';

  @override
  String processCount(int count) {
    return '$count işlem';
  }

  @override
  String get processParseUnsupportedOutput =>
      'İşlem listesi biçimi desteklenmiyor.';

  @override
  String get processParseInvalidRows => 'Bazı işlem girdileri okunamadı.';

  @override
  String get processParseInvalidWindowsJson =>
      'Windows işlem yanıtı okunamadı.';

  @override
  String get processParseInvalidWindowsRows =>
      'Bazı Windows işlem girdileri okunamadı.';

  @override
  String get processKillTargetChanged =>
      'İşlem değişti veya sonlandı. Listeyi yenileyip tekrar deneyin.';

  @override
  String get watchServers => 'Saatteki sunucular';

  @override
  String get watchServersTip =>
      'Saat veriyi monitor’dan kendisi alır, bu yüzden yalnızca monitor’u olan sunucular seçilebilir.';

  @override
  String get watchNoMonitorServer =>
      'monitor aracısı yapılandırılmış sunucu yok';

  @override
  String get legacyStatusGoneTitle => 'Durum URL\'leri artık çalışmıyor';

  @override
  String get legacyStatusGoneBody =>
      'Saat uygulaması ve ana ekran bileşenleri elle yazılan bir `/status` adresini okuyordu. Bu uç nokta kaldırıldı: yalnızca anlık değerleri metin olarak döndürebiliyordu, grafik gösterememelerinin nedeni buydu.\n\nArtık monitor aracısının kimlik doğrulamalı API\'sini okuyorlar; eğilimleri çiziyor ve uygulamayla kendiliğinden eşleşiyorlar. Sunucuyu uygulamada bir kez yapılandırın, her saat ve bileşen onu alsın.';

  @override
  String get services => 'Hizmetler';

  @override
  String get status => 'Durum';

  @override
  String get enable => 'Etkinleştir';

  @override
  String get disable => 'Devre dışı bırak';

  @override
  String get starting => 'Başlatılıyor';

  @override
  String get stopping => 'Durduruluyor';

  @override
  String get serviceManagerUnsupported => 'Desteklenmeyen hizmet yöneticisi';

  @override
  String get serviceManagerUnsupportedTip =>
      'Bu sunucu ServerBox\'ın henüz desteklemediği bir hizmet yöneticisi kullanıyor. systemd, procd ve OpenRC desteklenir.';

  @override
  String serviceManagerFmt(String manager) {
    return '$manager tarafından yönetiliyor';
  }

  @override
  String get serviceListFailed => 'Hizmetler listelenemedi';

  @override
  String get serviceDetailsUnavailable =>
      'Bazı hizmet ayrıntıları kullanılamıyor';

  @override
  String get serviceDetailsUnavailableTip =>
      'Liste kullanılabilir, ancak yönetici tüm durum veya otomatik başlatma bilgilerini döndürmedi.';

  @override
  String get serviceEnabled => 'Başlangıçta etkin';

  @override
  String get systemdUserScopeMissing => 'Kullanıcı unit\'leri listelenmiyor';

  @override
  String get systemdUserScopeMissingTip =>
      'Bu hesabın sunucuda kullanıcı oturum veri yolu yok, bu yüzden yalnızca sistem unit\'leri gösteriliyor.';

  @override
  String get serverUnreachable => 'Bu sunucuda komut çalıştırılamadı';

  @override
  String get containerNoRuntime => 'Burada konteyner çalışma ortamı yok';

  @override
  String get containerNoRuntimeTip =>
      'Bu makinede ne `docker` ne de `podman` yanıt verdi. Biri başka bir hesap için kuruluysa Ayarlar\'dan \"Sudo ile dene\" seçeneğini açın.';

  @override
  String get containerUnreadable =>
      'Konteyner çalışma ortamı beklenmeyen bir biçimde yanıt verdi';

  @override
  String get power => 'Güç';

  @override
  String get continueInTerminal => 'Terminalde devam et';

  @override
  String get askAiRiskUnknown => 'Sınıflandırılmadı';

  @override
  String get agentLocalExec => 'Bu cihazda komut çalıştır';

  @override
  String get agentLocalExecTip =>
      'Agent’ın ServerBox’ın çalıştığı makinede çalışmasına izin verir. Salt okunur komutlar da incelenir';

  @override
  String get agentLocalExecRootfsTip =>
      'Agent’ın yerelde, ServerBox’ın kurduğu Linux konteynerinin içinde çalışmasına izin verir';

  @override
  String macDmgImportedPartly(String path) {
    return 'Daha önce yüklü sürümün verileri içe aktarıldı. İndirilen dosyalar $path konumunda kaldı.';
  }

  @override
  String get bmcAccount => 'Hesap';

  @override
  String get bmcAccountUnset => 'Seçilmedi — seçmek veya oluşturmak için dokun';

  @override
  String bmcAccountShared(int count) {
    return '$count sunucuda kullanılıyor';
  }

  @override
  String get bmcAccounts => 'BMC hesapları';

  @override
  String get bmcAccountSharedTip =>
      'Burada düzenlemek hepsinin kullandığını değiştirir.';

  @override
  String bmcAccountInUse(int count) {
    return '$count sunucu kullanıyor. Adresleri kalır, hesabı kaybederler.';
  }

  @override
  String get bmcStaleWrite => 'Yazma sırasında BMC değişti. Tekrar dene.';

  @override
  String get send => 'Gönder';

  @override
  String get privacyBlur => 'Arka planda gizlilik';

  @override
  String get privacyBlurTip => 'Uygulama değiştiricide içeriği gizle';

  @override
  String get floatReturnToTab => 'Sekmeye geri koy';

  @override
  String get termInFloatWindow => 'Bu terminal yüzen pencerede';
}
