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
  String get crashLastRunFailed =>
      'ServerBox son çalıştırmada beklenmedik şekilde kapandı.';

  @override
  String get crashReportTitle => 'Çökme raporu';

  @override
  String get crashReportHint =>
      'Bu, önceki çalıştırmanın günlüğüdür. Bilinen sunucu adları ve adresleri yer tutucularla değiştirilmiştir, ancak başka ayrıntılar kalmış olabilir. Göndermeden önce dikkatlice okuyun.';

  @override
  String get crashReportSubmit => 'Kopyala ve bildir';

  @override
  String get preReleaseUpdates => 'Ön sürüm güncellemelerini al';

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
  String get remoteDesktop => 'Uzak masaüstü';

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
  String get askAiResend => 'Resend';

  @override
  String get askAiResendTip =>
      'Bu mesajdan sonraki her şey silinir: yanıtlar, komutlar ve sonuçları.';

  @override
  String get askAiDeleteTip =>
      'Bu mesaj ve sonrasındaki her şey silinir: yanıtlar, komutlar ve sonuçları.';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'Model adına göre bağlam boyutları models.dev üzerinden alınır. Bir tablo uygulamayla birlikte gelir; daha yenisini indirmek için dokunun.';

  @override
  String get askAiContextFallback => 'tabloda yok';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      'Önceki konuşmalar özetlenmeden önce model bağlamının ne kadar dolacağı. Erken özetleme ayrıntıları daha çabuk kaybettirir; geç özetlemede ise model isteği reddedebilir.';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'Bu modelin bağlamında kaç token tutulabileceği. Otomatik seçeneği model adına göre arar; sağlayıcınız modelin desteklediğinden daha kısa bir pencere sunuyorsa bir sayı girin.';

  @override
  String get askAiConversationCompacted =>
      'Konuşmanın sürebilmesi için önceki mesajlar özetlendi.';

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
  String get askAiAllowInsecure => 'Şifresiz HTTP’ye izin ver';

  @override
  String get askAiAllowInsecureTip =>
      'localhost dışındaki adreslerde bulunan kendi barındırdığınız modellere http:// bağlantılarına izin verir. API anahtarı ve tüm terminal bağlamı şifrelenmeden gönderilir; localhost etkilenmez.';

  @override
  String get askAiInsecureEndpoint =>
      'Bu uç nokta http:// kullanıyor. Kullanmak için AI ayarlarında “Şifresiz HTTP’ye izin ver” seçeneğini açın.';

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
  String get globe => 'Küre';

  @override
  String get locationTip =>
      'Bu sunucunun küre üzerinde çizileceği yer. Önce enlem, sonra boylam, derece cinsinden — örneğin 39.9042, 116.4074.';

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
  String get plainHttpTitle =>
      'Bu agent şifrelenmemiş HTTP üzerinden sunuluyor';

  @override
  String get plainHttpTip =>
      'Parola ve bu uygulamanın istediği her şey şifrelenmeden iletilir. Henüz hiçbir şey gönderilmedi.';

  @override
  String get allowForThisServer => 'Bu sunucu için izin ver';

  @override
  String get viewError => 'Hatayı gör';

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
  String get trayReadings => 'Değerler';

  @override
  String get trayChart => 'Grafik';

  @override
  String get trayChartNone => 'Yok';

  @override
  String get trayCompact => 'Sıkıştırılmış satırlar';

  @override
  String get trayCompactTip =>
      'Grafik olmadan sunucu başına bir satır. Linux, panel menüsü özel bir düzen yerine etiket taşıyan D-Bus üzerinden gönderildiği için her zaman tek satırlı bir düzen kullanır; ancak seçilen grafiği görüntü olarak içerebilir.';

  @override
  String get trayKeepRunning => 'Tepside çalışmaya devam et';

  @override
  String get trayKeepRunningTip =>
      'Pencere kapatıldığında uygulama menü çubuğunda veya bildirim alanında kalır ve sunucularınızı izlemeye devam eder. Kapat düğmesinin uygulamayı sonlandırması için bunu devre dışı bırakın.';

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
  String get containerReclaimable => 'Reclaimable';

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
  String get liveActivity => 'Canlı Etkinlik';

  @override
  String get liveActivityTip =>
      'Terminal oturumlarını Kilitli Ekran\'da ve Dynamic Island\'da gösterir. Cihazın kilidi açılmadan sunucu adı ve bağlantı durumu görülebilir.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS buna izin vermiyor. Anahtarlar Ayarlar › ServerBox › Canlı Etkinlikler ve Ayarlar › Face ID ve Parola › Canlı Etkinlikler bölümlerinde.';

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
  String get serverFuncBtns => 'Sunucu işlev düğmeleri';

  @override
  String get serverOrder => 'Sunucu sırası';

  @override
  String get serverTabEmpty => 'Henüz sunucu yok';

  @override
  String get serverTabRequired => 'Sunucu sekmesi kaldırılamaz';

  @override
  String get shareCodeHint =>
      'Bu rakamları alıcıya ayrıca iletin. QR koduna dahil değildir.';

  @override
  String get shareCodePrompt => '6 haneli kod';

  @override
  String get shareCodeTitle => 'Tek kullanımlık kod';

  @override
  String get shareExpired => 'Bu paylaşımın süresi doldu. Yenisini isteyin.';

  @override
  String get shareImportFile => 'Paylaşılan dosyadan';

  @override
  String get shareImportTitle => 'Paylaşılan sunucuyu içe aktar';

  @override
  String get shareIncludesKey => 'Paylaşım özel anahtarı içeriyor.';

  @override
  String get shareOmittedBmc =>
      'BMC kimlik bilgileri. Adres dahildir ancak kimlik bilgileri değildir.';

  @override
  String get shareOmittedJump =>
      'Atlama sunucusu; çünkü bu cihazda ayrı bir sunucu olarak kayıtlıdır.';

  @override
  String get shareOmittedKeyPath =>
      'Anahtar dosyası; çünkü yolu yalnızca bu cihazda geçerlidir.';

  @override
  String get shareOmittedMissingKey =>
      'Özel anahtar; çünkü bu cihazın anahtar deposunda bulunmuyor.';

  @override
  String get shareOmittedTip =>
      'Dahil değildir; alıcının şunları yapılandırması gerekir:';

  @override
  String get sharePassphraseTip =>
      'Bu parola dosyayı şifreler. Alıcının sunucuyu içe aktarmak için parolaya ihtiyacı vardır ve parola kurtarılamaz.';

  @override
  String shareQrTip(int minutes) {
    return 'Bu QR kodundaki bağlantı bilgileri şifrelenmiştir. Paylaşımın süresi $minutes dakika sonra dolar.';
  }

  @override
  String get shareScanQr => 'QR kodu tara';

  @override
  String shareServerExists(String name) {
    return 'Bu cihazdaki “$name” zaten bu adresi kullanıyor. Yine de içe aktarılsın mı?';
  }

  @override
  String get shareTooBigForQr =>
      'QR kodu için çok büyük. Bunun yerine dosya olarak paylaşın.';

  @override
  String get shareTooNew =>
      'Bu paylaşım daha yeni bir ServerBox sürümüyle oluşturuldu. Açmak için uygulamayı güncelleyin.';

  @override
  String get shareUnreadable => 'Bu, geçerli bir ServerBox paylaşımı değil.';

  @override
  String get shareVia => 'Şununla paylaş';

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
  String get portForwardBetaTitle => 'Port Yönlendirme (Beta)';

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
  String get processSearchHint => 'Ad, kullanıcı veya PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kernel iş parçacığını göster',
      one: '1 kernel iş parçacığını göster',
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
  String get systemdUserScopeMissing => 'Kullanıcı unit\'leri listelenmiyor';

  @override
  String get systemdUserScopeMissingTip =>
      'Bu hesabın sunucuda kullanıcı oturum veri yolu yok, bu yüzden yalnızca sistem unit\'leri gösteriliyor.';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count diğer unit',
      one: '1 diğer unit',
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
    return '$duration önce durduruldu';
  }

  @override
  String serviceExitStatus(String code) {
    return 'çıkış durumu $code';
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
      other: 'Son $count satır',
      one: 'Son satır',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable =>
      'Bu hesap journal kayıtlarını okuyamıyor';

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
  String get fan => 'Fan';

  @override
  String get clockSpeed => 'Saat hızı';

  @override
  String get vendor => 'Üretici';

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

  @override
  String get globeEnabledTip =>
      'Sunucuları adreslerinin bulunduğu yerde bir küre üzerinde gösterir. Kapalıyken düğme kaybolur ve hiçbir sorgu yapılmaz.';

  @override
  String get geoShardsConsentAttribution =>
      'IP coğrafi konumu [DB-IP](https://db-ip.com) tarafından, CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Özel adres';

  @override
  String get geoMissNoData => 'Konum verisi yok';

  @override
  String get globeGuide =>
      'Sunucularınızı adreslerinin bulunduğu yerde bir küre üzerinde görmek için buraya dokunun.';

  @override
  String get publicIp => 'Genel IP';

  @override
  String get geoData => 'Şehir düzeyinde veri';

  @override
  String get geoDataTip =>
      'İndirme tamamlandıktan sonra tüm konum sorguları bu cihazda saklanan verileri kullanır. Sunucu adresleri ve sorgu etkinliği indirme hizmetine gönderilmez.';

  @override
  String get geoDataMissing => 'İndirilmedi';

  @override
  String get geoDataUnreachable => 'Veri alınamadı.';

  @override
  String get geoDataRemoveFailed => 'Veriler silinemedi.';

  @override
  String geoDataCurrent(Object month) {
    return '$month zaten yüklü.';
  }

  @override
  String geoDataConsent(Object download, Object disk) {
    return '**İndirme: $download · Cihazdaki depolama alanı: $disk.** Veri kümesinin tamamı bu cihazda saklanır ve sonraki tüm konum sorguları yerel olarak gerçekleştirilir. Sunucu adresleri ve sorgu etkinliği indirme hizmetine gönderilmez.\n\nHer ay güncellenir. Yeni sürüm yüklü verilerin yerini alır ve ek bir kopya tutmaz. İstediğiniz zaman silebilirsiniz.';
  }

  @override
  String get benchmark => 'Performans testi';

  @override
  String get benchmarkIntro =>
      'Disk, ağ ve CPU\'yu test etmek için bu sunucuda Yet Another Bench Script\'i çalıştırır. Tam bir test 10–20 dakika sürer ve bu sayfadan ayrılsanız veya uygulamayı kapatsanız da devam eder.';

  @override
  String get benchmarkNoRuns => 'Henüz performans testi yok.';

  @override
  String get benchmarkRunning => 'Performans testi çalışıyor';

  @override
  String get benchmarkStartFailed => 'Performans testi başlatılamadı';

  @override
  String get benchmarkCancelConfirm =>
      'Bu test durdurulsun mu? Şimdiye kadar yapılan tüm ölçümler kaybolacak.';

  @override
  String get benchmarkDeleteConfirm => 'Bu test sonucu silinsin mi?';

  @override
  String get benchmarkNothingSelected =>
      'Tüm test aşamaları kapalı. Yalnızca sistem bilgileri toplanacak ve işlem birkaç saniye sürecek.';

  @override
  String get benchmarkDiskTip =>
      'Dört blok boyutuyla fio; yaklaşık 3 dakika. Çalışma dizinine 2 GB\'lık bir test dosyası yazar ve bu kadar boş alan gerektirir.';

  @override
  String get benchmarkNetworkTip =>
      'Genel sunuculara karşı iperf3; yaklaşık 4 dakika.';

  @override
  String get benchmarkReducedNetwork => 'Daha az konum';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Yedi yerine üç konum. Tahmini trafik $full yerine $reduced olur.';
  }

  @override
  String get benchmarkCpuTip =>
      'Tescilli bir program olan Geekbench\'i indirir ve **sonucu geekbench.com\'da herkese açık bir sayfada yayımlar**; CPU modeli, çekirdek sayısı ve bellek bilgileri de yayımlanır.';

  @override
  String get benchmarkSensitiveOptions =>
      'Aşağıdaki seçenekler bu sunucuda üçüncü taraf yazılımları indirip çalıştırır veya sunucu bilgilerini üçüncü taraflara gönderir. Varsayılan olarak kapalıdır.';

  @override
  String get benchmarkIpInfoTip =>
      'Bu sunucunun genel IP adresini şifrelenmemiş HTTP üzerinden ip-api.com\'a gönderir.';

  @override
  String get benchmarkIpInfo => 'IP sahibini sorgula';

  @override
  String get benchmarkPreferBin => 'fio ve iperf3\'ü indir';

  @override
  String get benchmarkPreferBinTip =>
      'Ana makinenin paketlerini kullanmak yerine GitHub\'dan indirir. Yalnızca ana makinede ikisi de yüklü değilse açın.';

  @override
  String get benchmarkWorkDir => 'Çalışma dizini';

  @override
  String get benchmarkWorkDirTip =>
      'Disk testinin hangi dosya sistemini ölçeceğini belirler. Boş bırakılırsa oturum açılan hesabın ana dizini kullanılır.';

  @override
  String benchmarkEstimatedTime(String minutes) {
    return 'Yaklaşık $minutes dk.';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Yaklaşık $size trafik';
  }

  @override
  String get benchmarkPhaseSystem => 'Sistem bilgileri okunuyor';

  @override
  String get benchmarkPhaseDisk => 'Disk test ediliyor';

  @override
  String get benchmarkPhaseNetwork => 'Ağ test ediliyor';

  @override
  String get benchmarkPhaseCpu => 'CPU test ediliyor';

  @override
  String get benchmarkPhaseDone => 'Tamamlanıyor';

  @override
  String get benchmarkResultUnreadable =>
      'Bu sonuç JSON olarak okunamadı. Ham metin aşağıdadır.';

  @override
  String get benchmarkViewOnGeekbench => 'Geekbench\'te görüntüle';

  @override
  String get benchmarkGeekbenchPublic =>
      'Bu sonuç yukarıdaki bağlantıda herkese açık olarak yayımlanmıştır.';

  @override
  String get benchmarkSingleCore => 'Tek çekirdek';

  @override
  String get benchmarkMultiCore => 'Çok çekirdek';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Yükleme';

  @override
  String get benchmarkRecv => 'İndirme';

  @override
  String get benchmarkLatency => 'Gecikme';

  @override
  String get benchmarkVirt => 'Sanallaştırma';

  @override
  String get benchmarkRawLog => 'Çalıştırma günlüğü';

  @override
  String benchmarkUpstream(String version) {
    return 'Yet Another Bench Script ($version) tarafından desteklenir';
  }

  @override
  String get benchmarkPhaseStarting => 'Başlatılıyor';

  @override
  String get benchmarkNoOutputYet =>
      'Henüz çıktı yok. YABS ilk satırı yazdırmadan önce google.com ve icanhazip.com adreslerine erişilip erişilemediğini kontrol eder. Bu sitelerden birini engelleyen ağlarda işlem birkaç dakika sürebilir.';

  @override
  String get tagsEmptyTip =>
      'Henüz etiket yok. Bir sunucuyu düzenlerken etiket ekleyin; burada görünür.';

  @override
  String get benchmarkNoServers =>
      'Önce bir sunucu ekleyin, ardından benchmark çalıştırmak için geri dönün.';

  @override
  String get schemaTooNewTitle => 'Bu veriler uygulamadan daha yeni';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Bu veriler ServerBox’ın daha yeni bir sürümü tarafından yazılmış (depolama v$stored); bu sürüm en fazla v$supported okuyabilir. Hiçbir şey değiştirilmedi.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Daha yeni sürümü yeniden yükleyin; her şey eskisi gibi açılır.';

  @override
  String get schemaTooNewExportPlain => 'Parolasız dışa aktar';

  @override
  String get schemaTooNewPlainWarn =>
      'Dosya tüm SSH özel anahtarlarını, sunucu parolalarını ve API anahtarlarını düz metin olarak içerecek. Dosyayı alan kişi bunların tamamına erişebilir.';

  @override
  String get schemaTooNewWipe => 'Tüm verileri sil';

  @override
  String get schemaTooNewWipeConfirm =>
      'Bu cihazdaki tüm sunucular, anahtarlar, snippet’ler ve ayarlar silinecek; bu işlem geri alınamaz. Burada dışa aktarılan bir yedek, geriye kalan tek kopya olur.';

  @override
  String get schemaTooNewWipeDone =>
      'Veriler silindi. Baştan başlamak için uygulamayı yeniden açın.';

  @override
  String get schemaTooNewWipeFailed =>
      'Bazı veriler silinemedi ve bu sürüm geriye kalanları hâlâ açamıyor. Erişmek için daha yeni sürümü yeniden yükleyin.';

  @override
  String get systemUsers => 'Users';

  @override
  String get userManagerLinuxOnly =>
      'Sistem kullanıcı yönetimi şu anda yalnızca Linux sunucularını destekliyor.';

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
      'root kullanıcısında yapılan değişiklikler tüm oturumlarda hemen geçerli olur.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Ek gruplar';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Home dizini oluştur';

  @override
  String get userMoveHome => 'Yol değiştiğinde mevcut home dizinini taşı';

  @override
  String get userRemoveHome => 'Home dizinini kaldır';

  @override
  String get userPasswordCreateTip =>
      'Parolayla girişi kilitlenmiş bir hesap oluşturmak için parola alanını boş bırakın.';

  @override
  String get userPasswordEditTip =>
      'Mevcut parolayı korumak için alanı boş bırakın.';

  @override
  String funcUnavailableFmt(Object func) {
    return '$func, bu sunucunun bağlantısında kullanılamıyor.';
  }

  @override
  String get rangeLive => 'Canlı';

  @override
  String get diskIo => 'Disk G/Ç';

  @override
  String get peak => 'tepe';

  @override
  String get hardware => 'Donanım';

  @override
  String get cores => 'Çekirdek';

  @override
  String get historyNoStored =>
      'Geçmişi yalnızca monitor aracısı saklar. Bu bağlantı yalnızca uygulamanın bağlandıktan sonra gördüğünü tutar.';

  @override
  String get noHistoryYet => 'Henüz ölçüm yok';

  @override
  String get noData => 'veri yok';

  @override
  String get from => 'Başlangıç';

  @override
  String get to => 'Bitiş';

  @override
  String get beyondRetention => 'bu agent\'ın sakladığından daha geriye';

  @override
  String agentRetentionFmt(Object kept) {
    return 'Agent $kept saklıyor';
  }

  @override
  String oldestSampleFmt(Object time) {
    return 'en eski ölçüm $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'Aralığın bitişi başlangıcından sonra olmalı.';

  @override
  String get samples => 'ölçüm';

  @override
  String get unavailable => 'kullanılamıyor';

  @override
  String get metricUnavailableTip =>
      'Sayfanın geri kalanı etkilenmedi. Bu ölçümün geldiği komutu sunucuda kontrol edin.';

  @override
  String get waitingFirstSample => 'İlk ölçüm bekleniyor';

  @override
  String atTimeFmt(Object time) {
    return 'saat $time';
  }

  @override
  String get stored => 'saklanan';

  @override
  String lastSampleFmt(Object ago) {
    return 'son ölçüm $ago';
  }

  @override
  String staleSinceFmt(Object ago, Object time) {
    return 'Aşağıdakilerin tamamı $time değerleri, $ago.';
  }

  @override
  String noDataBeforeFmt(Object time) {
    return '$time öncesine ait veri yok';
  }

  @override
  String loadingRangeFmt(Object range) {
    return '$range yükleniyor…';
  }

  @override
  String noStoredHistoryFor(Object metric) {
    return '$metric için saklanan geçmiş yok';
  }

  @override
  String devicesFmt(Object count) {
    return '$count aygıt';
  }

  @override
  String devicesBusiestFmt(Object count, Object name) {
    return '$count aygıt · en yoğunu $name';
  }

  @override
  String devicesPlottedFmt(Object plotted, Object total) {
    return '$total aygıttan $plotted tanesi';
  }

  @override
  String sensorsHottestFmt(Object count, Object name) {
    return '$count sensör · en sıcak $name';
  }

  @override
  String get oneDeviceAtLeast => 'Grafikte en az bir aygıt kalır.';

  @override
  String shownOfFmt(Object shown, Object total, Object what) {
    return '$total $what içinden $shown';
  }

  @override
  String countOfFmt(Object count, Object what) {
    return '$count $what';
  }

  @override
  String get unitDevices => 'aygıt';

  @override
  String get unitSensors => 'sensör';

  @override
  String get unitBatteries => 'pil';

  @override
  String get unitCommands => 'komut';

  @override
  String get unitReadings => 'okuma';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => 'en sıcak';

  @override
  String get oldest => 'en eski';

  @override
  String get notApplicable => 'uygulanamaz';

  @override
  String get attributes => 'öznitelikler';

  @override
  String get powerOnHours => 'Çalışma saati';

  @override
  String get powerCycles => 'Açılma sayısı';

  @override
  String get lifeLeft => 'Kalan ömür';

  @override
  String get lifetimeWrite => 'Toplam yazma';

  @override
  String get lifetimeRead => 'Toplam okuma';

  @override
  String get averageErase => 'Ortalama silme';

  @override
  String get unsafeShutdowns => 'Güvensiz kapanma';

  @override
  String get diskAllPassed => 'tümü PASSED';

  @override
  String diskWarningFmt(num count) {
    return '$count uyarı';
  }

  @override
  String diskWrongOfFmt(Object total, Object wrong) {
    return '$total aygıttan $wrong';
  }

  @override
  String get diskSmartSortedTip => 'En kötüden sıralı';

  @override
  String readAgoFmt(Object ago) {
    return '$ago okundu';
  }

  @override
  String processesFmt(Object count) {
    return '$count süreç';
  }

  @override
  String diskFailingFmt(Object count) {
    return '$count arızalı';
  }

  @override
  String get diskSmartOpenTip => 'Özniteliklerini görmek için dokunun';

  @override
  String get cycle => 'Çevrim';

  @override
  String get window => 'pencere';

  @override
  String ofFmt(Object total) {
    return '/ $total';
  }

  @override
  String get serverDetailCards => 'Ayrıntı sayfası kartları';

  @override
  String get connection => 'Bağlantı';

  @override
  String get connectionTip =>
      'İkisi aynı anda açık olabilir. Sıra, denendikleri sıradır.';

  @override
  String get transportNoneOn => 'İkisi de kapalı — bu sunucuya bağlanılamaz.';

  @override
  String get thisDevice => 'Bu cihaz';

  @override
  String get localServerTip =>
      'Durum betiğini burada çalıştırarak bu cihazı doğrudan okur. SSH ve Monitor HTTP kullanılmaz; ayarları korunur.';

  @override
  String get localServerUnsupported =>
      'Bu platform bu cihazı sunucu olarak okuyamaz. Linux, Windows ve macOS DMG sürümü destekler.';

  @override
  String get remoteDesktopIntro =>
      'Bir sunucunun RDP veya VNC masaüstünü uygulama içinde açar. Bağlantı sunucunun SSH bağlantısı veya Monitor ajanı üzerinden geçer; bu yüzden masaüstü bağlantı noktasının ağdan erişilebilir olması gerekmez.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Her masaüstü için bir profili, sunucudaki Uzak masaüstü düğmesinden veya Uzak masaüstü sekmesinden kaydedin.';

  @override
  String get localServerIntro =>
      'ServerBox\'ı çalıştıran cihazı sunucu olarak ekler. Durum, işlemler, hizmetler, konteynerler, terminal ve dosyalar SSH veya Monitor ajanı olmadan çalışır.';

  @override
  String get localServerAdd => 'Bu cihazı ekle';

  @override
  String get localServerIntroFooter =>
      'Bu, daha sonra bir sunucunun düzenleme sayfasında Bağlantı altında da açılabilir.';

  @override
  String get transportSectionOff =>
      'Kapalı. Aşağıdaki alanlar, yeniden açtığınızda kullanılmak üzere saklanıyor.';

  @override
  String get monitorAgent => 'Monitor aracısı';

  @override
  String get plainHttpEditTip =>
      'Kimlik bilgileri ve ölçümler ağdan şifrelenmeden geçer. Bunu bir LAN veya Tailscale adresiyle sınırlayın ya da aracıyı TLS arkasına alın.';

  @override
  String get behaviour => 'Davranış';

  @override
  String get optional => 'İsteğe bağlı';

  @override
  String get sshAdvanced => 'SSH gelişmiş';

  @override
  String get sshAdvancedTip =>
      'Yedek hedef, ProxyCommand, atlama sunucusu, dosya aktarımı, uzak yol';

  @override
  String get sshLegacyAlgorithms => 'Eski algoritmalar';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Yalnızca SHA-1 `ssh-rsa` host anahtarı veya SHA-1 anahtar değişimi sunan eski SSH sunucuları (yönlendirici ya da anahtar gibi) içindir. Daha az güvenlidir; yalnızca ihtiyacı olan hostlar için etkinleştirin.';

  @override
  String get appearanceAndPlace => 'Görünüm ve konum';

  @override
  String get appearanceAndPlaceTip => 'Logo, koordinatlar';

  @override
  String get statusCollection => 'Durum toplama';

  @override
  String get statusCollectionTip =>
      'Hangi komutlar çalışır, özel komutlar, hangi aygıt okunur';

  @override
  String get tagAllTags => 'Tüm etiketler';

  @override
  String get tagMatching => 'Eşleşenler';

  @override
  String get tagNewHint => 'Yeni etiket';

  @override
  String tagCreateFmt(Object tag) {
    return '#$tag oluştur';
  }

  @override
  String get tagOnThisServer => 'bu sunucuda';

  @override
  String tagServersFmt(Object count) {
    return '$count sunucu';
  }

  @override
  String tagOnThisServerFmt(Object count) {
    return 'bu sunucuda $count';
  }

  @override
  String get tagMatchesTyped => 'yazdığınızla eşleşiyor';

  @override
  String get tagEditorTip =>
      'Yazmak listeyi süzer; düğme etiketi oluşturup tek adımda bu sunucuya ekler. Kalem, etiketi taşıyan her sunucuda adını değiştirir. Hiçbir sunucunun taşımadığı etiket kaydederken kaybolur.';

  @override
  String get tagRenamesOnSave => 'Yeniden adlandırmalar kaydederken uygulanır';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'Zamanlanmış görev yönetimi şu anda yalnızca Linux sunucularını destekliyor.';

  @override
  String get scheduledTaskUnavailable => 'Bu sunucuda crontab kullanılamıyor.';

  @override
  String get scheduledTaskPreserveTip =>
      'Bu crontab içindeki yorumlar, ortam değişkenleri ve tanınmayan satırlar korunur.';

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
  String scheduledTaskSummaryFmt(num enabled, num total) {
    return '$total görev · $enabled etkin';
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
      'Kapalı olduğunda satır yorum satırı olarak yazılır.';

  @override
  String scheduledTaskEmptyFmt(Object user) {
    return '$user için zamanlanmış görev yok. Buraya eklenenler bu hesabın crontab dosyasına yazılır.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'Ayın günü';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'Haftanın günü';

  @override
  String get cronErrScheduleEmpty => 'Bir zamanlama gerekli.';

  @override
  String get cronErrCommandEmpty => 'Bir komut gerekli.';

  @override
  String get cronErrLineBreak => 'Bir crontab satırı satır sonu içeremez.';

  @override
  String get cronErrMacro =>
      'Makro, @reboot gibi tek bir sözcükten oluşmalıdır.';

  @override
  String get cronErrFieldCount =>
      'Cron zamanlaması beş alandan veya @reboot gibi bir makrodan oluşmalıdır.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(Object minutes) {
    return 'Her $minutes dakikada bir';
  }

  @override
  String cronHourlyAtFmt(Object minute) {
    return 'Her saat :$minute geçe';
  }

  @override
  String cronEveryHoursFmt(Object hours) {
    return 'Her $hours saatte bir';
  }

  @override
  String cronEveryHoursAtFmt(Object hours, Object minute) {
    return 'Her $hours saatte bir, :$minute geçe';
  }

  @override
  String cronDailyAtFmt(Object time) {
    return 'Her gün $time saatinde';
  }

  @override
  String cronWeekdaysAtFmt(Object time) {
    return 'Hafta içi $time saatinde';
  }

  @override
  String cronWeekdayAtFmt(Object day, Object time) {
    return 'Her $day, $time saatinde';
  }

  @override
  String cronMonthlyAtFmt(Object day, Object time) {
    return 'Her ayın $day. günü $time saatinde';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart =>
      'Agent yeniden başlatıldıktan sonra geçerli olur';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Genişletilmiş döngü aralığı';

  @override
  String get idlePause => 'İzleyen yokken duraklat';

  @override
  String get idlePauseTip =>
      'Genişletilmiş döngü smartctl, sensors ve amd-smi komutlarını çalıştırır. Hiçbir istemci veri istemezken döngüyü duraklatmak, diskin okunmayacak veriler için uyandırılmasını önler.';

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
      'Metrik: cpu / memory / swap / disk / network / temperature. Eşleştirici: tek bir çekirdek için cpu0, bellek için used / free / avail, ağ için rx / tx; disk ve sıcaklık bunu yok sayar. Eşik: >=80%, >=70c veya >10m/s gibi bir karşılaştırma işleci ve değer.';

  @override
  String get pushChannels => 'Bildirim kanalları';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Agent üzerinde ayarlı, gösterilmiyor';

  @override
  String get pushSecretKeep => 'Korumak için boş bırakın';

  @override
  String get pushTestTip =>
      'Kaydedilmiş olsun ya da olmasın, kanalın buradaki mevcut ayarlarıyla bir bildirim gönderir.';

  @override
  String get pushTestSent => 'Kanal bildirimi kabul etti';

  @override
  String get pushTestFailed => 'Kanal bildirimi reddetti';

  @override
  String get pushTestMessage => 'ServerBox Monitor test bildirimi';

  @override
  String get pushUnknownType =>
      'Bu Agent, söz konusu kanal türü için bir göndericiye sahip olmadığından ayarları gösterilmiyor. Kanalı buradan kaldırabilir veya Agent\'ın config.toml dosyasında düzenleyebilirsiniz.';

  @override
  String get pushJsonInvalid => 'geçerli bir JSON değil';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Kapalı olduğunda Agent hiçbir şeyi silmez ve veritabanı sınırsız büyür.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Temizleme sıklığı';

  @override
  String get retentionMaxDbSize => 'Veritabanı boyutu sınırı';

  @override
  String get corsOrigins => 'CORS için izin verilen origin\'ler';

  @override
  String get corsOriginsTip =>
      'Tarayıcı panelinin bu Agent\'a erişebileceği origin\'ler. Boş bırakılırsa yalnızca aynı origin\'e izin verilir.';

  @override
  String get monitorNoRemoteAccess =>
      'Bu agent yalnızca izleme için yapılandırılmıştır. Buradan terminal açamaz, komut çalıştıramaz veya dosyalara göz atamazsınız. Bu özellikleri etkinleştirmek için agent\'ın config.toml dosyasındaki [remote_access] bölümünü düzenleyin.';

  @override
  String get alerts => 'Uyarılar';

  @override
  String get online => 'çevrimiçi';

  @override
  String get densityCards => 'Kartlar';

  @override
  String get densityRows => 'Satırlar';

  @override
  String get densityGrid => 'Izgara';

  @override
  String get connect => 'Bağlan';

  @override
  String get disconnect => 'Bağlantıyı kes';

  @override
  String get searchServerTip =>
      'Adları ve adresleri arar — düzenleyicinin önce sorduğu iki bilgiyi.';

  @override
  String get addServerTip =>
      'Birini doldurun, QR kodu tarayın veya birinin paylaştığı dosyayı içe aktarın.';

  @override
  String get move => 'Taşı';

  @override
  String get moveToTop => 'En başa taşı';

  @override
  String get moveToBottom => 'En sona taşı';

  @override
  String get groupByTag => 'Etikete göre grupla';

  @override
  String get groupByTagTip =>
      'Etiketler sunucunun kendi düzenleme sayfasında ayarlanır.';

  @override
  String get connecting => 'Bağlanıyor…';

  @override
  String get authShort => 'Kimlik';

  @override
  String get remoteDesktopFitToWindow => 'Pencereye sığdır';

  @override
  String get remoteDesktopActualSize => 'Gerçek boyut';

  @override
  String get remoteDesktopZoom => 'Yakınlaştırma';

  @override
  String get remoteDesktopViewOnly => 'Yalnızca görüntüle';

  @override
  String get remoteDesktopDisableViewOnly => 'Yalnızca görüntülemeyi kapat';

  @override
  String get remoteDesktopSendClipboardText => 'Pano metnini gönder';

  @override
  String get remoteDesktopShowKeyboard => 'Klavyeyi göster';

  @override
  String get remoteDesktopMoreControls => 'Diğer denetimler';

  @override
  String get remoteDesktopUseDirectPointer => 'Doğrudan işaretçiyi kullan';

  @override
  String get remoteDesktopUseTouchpadPointer =>
      'Dokunmatik yüzey işaretçisini kullan';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Ctrl+Alt+Delete gönder';

  @override
  String get remoteDesktopReconnect => 'Yeniden bağlan';

  @override
  String get remoteDesktopFullScreen => 'Tam ekran';

  @override
  String get remoteDesktopCloseSession => 'Oturumu kapat';

  @override
  String get remoteDesktopConnected => 'Bağlandı';

  @override
  String get remoteDesktopConnecting => 'Bağlanıyor';

  @override
  String get remoteDesktopReconnecting => 'Yeniden bağlanıyor';

  @override
  String get remoteDesktopDisconnected => 'Bağlantı kesildi';

  @override
  String get remoteDesktopGuideTouch => 'Dokunmatik yüzey';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Tek parmak işaretçiyi dokunmatik yüzey gibi hareket ettirir, dokunmak tıklar. Sağ tık için iki parmakla dokunun, kaydırmak için iki parmakla sürükleyin, yakınlaştırmak için sıkıştırın. Sürüklemek için iki kez dokunup parmağınızı kaldırmayın.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Ekran klavyesini açar. Yazdıklarınız uzak masaüstüne gönderilir.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'İşaretçi ve tuşların gönderilmesini durdurur; yanlışlıkla tıklamadan bakabilirsiniz.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Ctrl+Alt+Delete, yeniden bağlanma ve tam ekran burada.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'Parmağın dokunduğu yeri tıklayan doğrudan işaretçi de burada.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'VNC panosu yalnızca Latin-1 metnini destekler.';

  @override
  String get remoteDesktopAddProfile => 'Profil ekle';

  @override
  String get remoteDesktopNoProfiles => 'Uzak masaüstü profili yok';

  @override
  String get remoteDesktopAdd => 'Uzak masaüstü ekle';

  @override
  String get remoteDesktopEdit => 'Uzak masaüstünü düzenle';

  @override
  String get remoteDesktopTargetTip =>
      'Hedef, SSH sunucusu veya Monitor ajanı tarafından çözümlenir. localhost o makineyi belirtir.';

  @override
  String get remoteDesktopDomain => 'Etki alanı (isteğe bağlı)';

  @override
  String get remoteDesktopPassword => 'Parola (isteğe bağlı)';

  @override
  String get remoteDesktopSavePassword => 'Parolayı kaydet';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Şifrelenmiş veritabanında saklanır. Yedekler kaydedilmiş parolaları içerir ve yalnızca bir yedek parolası ayarlandığında şifrelenir.';

  @override
  String get remoteDesktopShareSession => 'Oturumu paylaş';

  @override
  String get remoteDesktopProtocol => 'Protokol';

  @override
  String get remoteDesktopUniqueName =>
      'Profil adları bu sunucuda benzersiz olmalıdır.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'Klasik VNC parolaları 8 ASCII baytla sınırlıdır.';

  @override
  String get remoteDesktopNameRequired => 'Bir profil adı girin.';

  @override
  String get remoteDesktopHostRequired => 'Bir hedef sunucu girin.';

  @override
  String get remoteDesktopPortRequired => 'Geçerli bir bağlantı noktası girin.';

  @override
  String get remoteDesktopUsernameRequired => 'RDP kullanıcı adını girin.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Klasik VNC parolaları yalnızca ASCII karakter içerebilir.';

  @override
  String get remoteDesktopCertificateRequired => 'Sertifika onayı gerekli';

  @override
  String get remoteDesktopWaiting => 'Masaüstü bekleniyor…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Uzak masaüstü sertifikası değişti';

  @override
  String get remoteDesktopTrustCertificate => 'Sertifikaya güvenilsin mi?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'Sertifikanın parmak izi artık kaydedilen değerle eşleşmiyor. Güveni değiştirmeden önce yeni parmak izini doğrulayın.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'Sistem bu sertifikayı doğrulayamadı. Devam etmeden önce SHA-256 parmak izini doğrulayın.';

  @override
  String get remoteDesktopReplaceTrust => 'Güveni değiştir';

  @override
  String get remoteDesktopTrustReconnect => 'Güven ve yeniden bağlan';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return '“$name” uzak masaüstü profili silinsin mi?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Yeniden bağlanılıyor ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Daha önce güvenilen\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Konu: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Veren: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Geçerlilik: $start – $end';
  }
}
