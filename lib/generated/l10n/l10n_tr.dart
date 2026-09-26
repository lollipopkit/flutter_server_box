// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appearanceSettings => 'Görünüm';

  @override
  String get appearancePreset => 'Tema ön ayarı';

  @override
  String get appearanceThemeSchemaRange => 'Desteklenen tema schema sürümü';

  @override
  String get appearanceThemeInstall => 'Tema yükle';

  @override
  String get appearanceThemeStore => 'Tema mağazası';

  @override
  String get appearanceInvalidTheme => 'Geçersiz tema paketi veya katalog';

  @override
  String get themeStoreRefreshFailed => 'Tema kataloğu okunamadı.';

  @override
  String themeStoreDeleteTheme(String name) {
    return '“$name” silinsin mi? Dosyaları bu cihazdan kaldırılır. Kullanımdaki tema ise uygulama varsayılan temaya döner.';
  }

  @override
  String themeStoreUpdatedFmt(String ago) {
    return '$ago güncellendi';
  }

  @override
  String get themeStoreUpdatedJustNow => 'az önce güncellendi';

  @override
  String get themeStoreSortInUse => 'Kullanımda olan önce';

  @override
  String themeStoreMakeOwnFmt(String doc) {
    return 'Kendi temanızı mı yapmak istiyorsunuz? [Nasıl yapılacağına]($doc) bakın — katkınız için teşekkürler!';
  }

  @override
  String appearanceThemeNeedsNewerApp(String version) {
    return 'Daha yeni bir uygulama sürümü gerekiyor: $version';
  }

  @override
  String get appearanceFontFamilies => 'Arayüz yazı tipi aileleri';

  @override
  String get appearanceFontFamiliesTip =>
      'Her satıra bir ad yazın; yazı tipleri sırayla denenir.';

  @override
  String get appearanceFontImport => 'Arayüz yazı tipi dosyasını içe aktar';

  @override
  String get appearanceGradient => 'Gradyan';

  @override
  String get appearanceNoBackground => 'Arka plan yok';

  @override
  String get appearanceIcons => 'Uygulama içi simgeler';

  @override
  String get appearanceCorners => 'Köşeler';

  @override
  String get appearanceCardCorners => 'Kart köşeleri';

  @override
  String get appearanceTileCorners => 'Kutucuk köşeleri';

  @override
  String get appearanceButtonCorners => 'Düğme köşeleri';

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
  String askAiConfigMissing(String fields) {
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
  String agentToolCallsFmt(int count) {
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
  String nTags(int count) {
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
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
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
  String clearServerStatsContent(String serverName) {
    return '\"$serverName\" sunucusu için bağlantı istatistiklerini temizlemek istediğinizden emin misiniz? Bu işlem geri alınamaz.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
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
  String dl2Local(String fileName) {
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
  String fileTooLarge(String file, String size, String sizeMax) {
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
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return '$serverName için atlama sunucuları bulunamadı: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
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
  String madeWithLove(String myGithub) {
    return '$myGithub tarafından ❤️ ile yapıldı';
  }

  @override
  String get maxConcurrency => 'Maksimum Eşzamanlılık';

  @override
  String get maxRetryCount => 'Sunucu yeniden bağlantı sayısı';

  @override
  String mismatchSystem(String system) {
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
  String get preferDiskAmount => 'Disk kapasitesini öncelikli olarak göster';

  @override
  String get privateKey => 'Özel Anahtar';

  @override
  String privateKeyNotFoundFmt(String keyId) {
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
  String get pvePasswordRequired =>
      'PVE parolası gerekli. Lütfen sunucu ayarlarında belirle.';

  @override
  String get pveOtpRequired =>
      'Bu PVE sunucusunda iki adımlı doğrulama açık. Lütfen OTP kodunu gir.';

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
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '$distro $installed kurulu, $latest var. Güncelleme tüm konteyneri değiştirir: $pm verisi kaybolur';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'Silmeden önce $name üzerindeki terminalleri kapat';
  }

  @override
  String get rootfsSubtitle => 'Bu cihazdaki bir Linux kullanıcı alanı';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
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
  String selected(int count) {
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
  String spentTime(String time) {
    return 'Harcanan süre: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
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
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount kopya atlanacak';
  }

  @override
  String get sshConfigFound => 'Sisteminizde SSH yapılandırması bulduk';

  @override
  String sshConfigFoundServers(int totalCount) {
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
  String sshConfigImported(int count) {
    return 'SSH yapılandırmasından $count sunucu içe aktarıldı';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
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
  String sshHostKeyNewDesc(String serverName) {
    return '$serverName üzerinden yeni bir SSH ana bilgisayar anahtarı alındı. Güvenmeden önce parmak izini kontrol edin.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
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
  String sshConfigServersToImport(int importCount) {
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
  String switchTo(String val) {
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
  String portForward_deleteConfirmFmt(String name) {
    return '$name silinsin mi?';
  }

  @override
  String get sponsor => 'Sponsor';

  @override
  String get sortByJoinTime => 'Eklenme zamanına göre';

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
  String serviceExitStatus(int code) {
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
  String geoDataCurrent(String month) {
    return '$month zaten yüklü.';
  }

  @override
  String geoDataConsent(String download, String disk) {
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
  String benchmarkEstimatedTime(int minutes) {
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
  String funcUnavailableFmt(String func) {
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
  String agentRetentionFmt(String kept) {
    return 'Agent $kept saklıyor';
  }

  @override
  String oldestSampleFmt(String time) {
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
  String atTimeFmt(String time) {
    return 'saat $time';
  }

  @override
  String get stored => 'saklanan';

  @override
  String lastSampleFmt(String ago) {
    return 'son ölçüm $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Aşağıdakilerin tamamı $time değerleri, $ago.';
  }

  @override
  String noDataBeforeFmt(String time) {
    return '$time öncesine ait veri yok';
  }

  @override
  String loadingRangeFmt(String range) {
    return '$range yükleniyor…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return '$metric için saklanan geçmiş yok';
  }

  @override
  String devicesFmt(int count) {
    return '$count aygıt';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count aygıt · en yoğunu $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$total aygıttan $plotted tanesi';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count sensör · en sıcak $name';
  }

  @override
  String get oneDeviceAtLeast => 'Grafikte en az bir aygıt kalır.';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$total $what içinden $shown';
  }

  @override
  String countOfFmt(int count, String what) {
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
  String diskWarningFmt(int count) {
    return '$count uyarı';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$total aygıttan $wrong';
  }

  @override
  String get diskSmartSortedTip => 'En kötüden sıralı';

  @override
  String readAgoFmt(String ago) {
    return '$ago okundu';
  }

  @override
  String processesFmt(int count) {
    return '$count süreç';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count arızalı';
  }

  @override
  String get diskSmartOpenTip => 'Özniteliklerini görmek için dokunun';

  @override
  String get cycle => 'Çevrim';

  @override
  String get window => 'pencere';

  @override
  String ofFmt(String total) {
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
  String transportOrderFmt(String first, String second) {
    return 'Sırayı değiştirmek için sürükleyin. Önce $first denenir; yanıt vermezse oturumu tek başına $second taşır.';
  }

  @override
  String transportOnlyFmt(String name) {
    return 'Yalnızca $name açık, dolayısıyla geri dönülecek bir şey yok.';
  }

  @override
  String get transportNoneOn => 'İkisi de kapalı — bu sunucuya bağlanılamaz.';

  @override
  String get transportOffKept => 'kapalı — ayarlar saklanıyor, hiç denenmiyor';

  @override
  String get transportDialledFirst => 'önce denenir';

  @override
  String get transportFallback => 'yedek';

  @override
  String get transportOnlyMethod => 'tek yöntem';

  @override
  String get transportOff => 'kapalı';

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
  String get optionalTip =>
      'Buradaki hiçbir şey bağlanmak için gerekli değil. Birini açın, alanları formun yerini alsın.';

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
  String tagCreateFmt(String tag) {
    return '#$tag oluştur';
  }

  @override
  String get tagOnThisServer => 'bu sunucuda';

  @override
  String tagServersFmt(int count) {
    return '$count sunucu';
  }

  @override
  String tagOnThisServerFmt(int count) {
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
  String scheduledTaskNextInFmt(String time) {
    return 'in $time';
  }

  @override
  String get scheduledTaskEnabled => 'Enabled';

  @override
  String get scheduledTaskCommentedOut => 'Commented out';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
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
  String scheduledTaskEmptyFmt(String user) {
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
  String cronEveryMinsFmt(int minutes) {
    return 'Her $minutes dakikada bir';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'Her saat :$minute geçe';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'Her $hours saatte bir';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'Her $hours saatte bir, :$minute geçe';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Her gün $time saatinde';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'Hafta içi $time saatinde';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Her $day, $time saatinde';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
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

  @override
  String appearanceThemeModeLocked(String mode) {
    return 'Bu tema yalnızca $mode modunu destekler. Modu değiştirmek için başka bir tema seçin.';
  }

  @override
  String get pveAuthToken => 'API belirteci';

  @override
  String get pveVersionLow =>
      'Bu özellik şu anda test aşamasında ve yalnızca PVE 8+ üzerinde test edildi. Lütfen dikkatli kullanın.';

  @override
  String get pveTokenId => 'Belirteç kimliği';

  @override
  String get pveTokenSecret => 'Belirteç gizli anahtarı';

  @override
  String get pveTokenTip =>
      'PVE\'de Veri Merkezi → İzinler → API Tokens altında oluşturun. Gösterilecek yollarda VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit ve Sys.Audit gerekir; ayrıcalık ayrımı açıksa bunları belirtecin kendisine verin.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return '$account belirteci bu ana makinede hiçbir şey göremiyor. Yetki ayrımı açık bir belirteç, kullanıcısının izinlerini almaz; PVE ana makinesinde izin verin:\n$command\nya da belirteçte \"Privilege Separation\" seçeneğini kaldırın.';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account bu ana makinede hiçbir şey göremiyor. PVE ana makinesinde izin verin:\n$command';
  }

  @override
  String get pveTokenIdInvalid =>
      'Belirteç kimliği user@realm!tokenid biçiminde olmalıdır';

  @override
  String get pvePasswordAuthTip =>
      'PAM realm\'inde SSH kullanıcısı olarak SSH parolasıyla, SSH anahtar kullanıyorsa aşağıdaki PVE parolasıyla oturum açar. Gerektiğinde iki aşamalı doğrulama kodu istenir.';

  @override
  String get pveCertUnpinned =>
      'Henüz onaylanmış bir sertifika yok. Güvenilir bir CA imzalamadıysa, sonraki bağlantı sertifikayı onay için gösterir.';

  @override
  String get pveCertForget => 'Sertifikayı unut';

  @override
  String get pveCertForgetTip =>
      'Sonraki bağlantı PVE sertifikasını yeniden onay için gösterecek.';

  @override
  String get virtualization => 'Sanallaştırma';

  @override
  String get virtIntro =>
      'Proxmox VE ve libvirt/KVM ana makinelerindeki sanal makineleri ve kapsayıcıları yönetin: durum, güç işlemleri ve konsollar.';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE sunucu sayfasından bu sekmeye taşındı. Bir sunucunun PVE kartı onu burada açar.';

  @override
  String get virtIntroLibvirt =>
      'libvirt\'in virsh aracı kurulu bir sunucu, QEMU/KVM sanal makineleriyle birlikte ana makine olarak görünür.';

  @override
  String get virtIntroTransports =>
      'İkisi de SSH üzerinden, bir Monitor ajanı aracılığıyla veya bu cihazda çalışır.';

  @override
  String get virtIntroTokens =>
      'PVE, parola yerine bir API belirteciyle oturum açabilir. Sunucunun düzenleme sayfasında, PVE altında ayarlayın.';

  @override
  String get virtIntroInBar => 'Sekme çubuğuna eklendi.';

  @override
  String get virtIntroInMore =>
      'Daha fazla altında. Ayarlardaki Ana Sayfa Sekmeleri ile sekme çubuğuna taşıyabilirsiniz.';

  @override
  String get virtGuests => 'Sanal makineler';

  @override
  String get virtHosts => 'Ana makineler';

  @override
  String get virtCheckServer => 'Bu sunucuyu denetle';

  @override
  String get virtCheckAll => 'Tüm sunucuları denetle';

  @override
  String get virtProbeNotChecked => 'Henüz denetlenmedi';

  @override
  String get virtProbeAbsent => 'Ana makine değil';

  @override
  String virtProbeContainer(String kind) {
    return '$kind kapsayıcısı';
  }

  @override
  String get virtProbeContainerTip =>
      'Bu sunucu bir kapsayıcıda çalışıyor, yani ana makine değil konuk. Onu çalıştıran ana makineden yönetilir.';

  @override
  String get virtProbePve => 'PVE, ayarlanmadı';

  @override
  String virtPveSetupTip(String version) {
    return 'Bu sunucuda $version çalışıyor. Sanal makinelerini ve kapsayıcılarını burada yönetmek için sunucu ayarlarında API erişimini girin (API belirteci önerilir).';
  }

  @override
  String get virtNoHosts => 'Sanallaştırma ana makinesi yok';

  @override
  String get virtNoHostsTip =>
      'Proxmox VE çalıştıran ve API erişimi girilmiş bir sunucu ana makinedir; virsh\'in yanıt verdiği sunucu da öyledir. Diğer sunucular ana makine değiştiriciden denetlenebilir.';

  @override
  String get virtNoGuests => 'Sanal makine veya konteyner yok';

  @override
  String get virtPaused => 'Duraklatıldı';

  @override
  String get virtStarting => 'Başlatılıyor…';

  @override
  String get virtStopping => 'Durduruluyor…';

  @override
  String get virtRebooting => 'Yeniden başlatılıyor…';

  @override
  String get virtMigrating => 'Taşınıyor…';

  @override
  String get virtBackingUp => 'Yedekleniyor…';

  @override
  String get virtResume => 'Sürdür';

  @override
  String get virtOverview => 'Genel bakış';

  @override
  String get virtConsole => 'Konsol';

  @override
  String get virtConsoleNone => 'Bu konuk için yapılandırılmış konsol yok';

  @override
  String get virtConsoleGraphical => 'Grafik';

  @override
  String get virtVncPasswordNeeded => 'Bu ekran bir parola istiyor';

  @override
  String get virtConsoleSerialTip =>
      'Konuğun seri konsolunu ana makinede virsh ile açar. Bağlantıyı kes veya Ctrl+] ana makinenin kabuğuna döndürür.';

  @override
  String virtConsoleVia(String transport) {
    return '$transport üzerinden';
  }

  @override
  String get virtConsoleEnterTip => 'Çıktı yok mu? Enter\'a basın';

  @override
  String virtConsoleAutoEnter(int seconds) {
    return 'İstemi göstermek için $seconds saniye içinde Enter\'a basılacak';
  }

  @override
  String get virtConsoleEnterNow => 'Şimdi';

  @override
  String get virtOffTip =>
      'CPU, bellek, disk ve ağı burada canlı görmek için başlatın.';

  @override
  String get virtAllocated => 'Ayrılan';

  @override
  String virtRunningCount(int running, int total) {
    return '$running çalışıyor · toplam $total';
  }

  @override
  String get virtTemplate => 'Şablon';

  @override
  String get virtAutostart => 'Ana makineyle başlar';

  @override
  String get virtErrUnreachable => 'Bu ana makineye ulaşılamadı';

  @override
  String get virtErrNotConfigured => 'Bu sunucunun PVE ayarları eksik';

  @override
  String get virtErrNotConfiguredTip =>
      'Sunucu ayarlarında adresi ve parolayı ya da API belirtecini denetleyin.';

  @override
  String get virtErrAuthFailed => 'Ana makine oturum açmayı reddetti';

  @override
  String get virtErrCertUnconfirmed => 'Ana makinenin sertifikasını onaylayın';

  @override
  String get virtErrCertChanged => 'Ana makinenin sertifikası değişti';

  @override
  String get virtErrRelayNotGranted =>
      'Monitor aracısı bağlantıları aktarmıyor';

  @override
  String get virtErrExecNotGranted => 'Monitor aracısı komut çalıştırmıyor';

  @override
  String get virtErrNotInstalled => 'Bu sunucuda virsh kurulu değil';

  @override
  String get virtErrServerRemoved => 'Bu sunucu artık mevcut değil';

  @override
  String get virtErrSudoRequired =>
      'libvirt\'e erişmek için sudo parola istiyor';

  @override
  String get virtErrSudoRejected => 'sudo parolayı reddetti';

  @override
  String get virtErrInvalidResponse =>
      'Ana makine beklenmeyen biçimde yanıt verdi';

  @override
  String get virtErrActionFailed => 'Ana makine işlemi reddetti';

  @override
  String get remoteSessionIdleTimeout => 'Ayrılınca kapat';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'Uzak masaüstünden veya bir konuğun konsolundan ayrıldıktan sonra bağlantının ne kadar süre açık kalacağı. Kapanmadan önce bir bildirim, bağlantıyı korumanız için 10 saniye verir.';

  @override
  String get remoteSessionKeepAlive => 'Açık tut';

  @override
  String get remoteSessionClosedAway => 'Boşta kaldığı için kapatıldı';

  @override
  String remoteSessionClosingIn(int seconds) {
    return '$seconds sn içinde kapanıyor';
  }

  @override
  String get reopen => 'Yeniden aç';

  @override
  String get virtSnapshots => 'Anlık görüntüler';

  @override
  String get virtSnapshotCreate => 'Anlık görüntü al';

  @override
  String get virtSnapshotNone => 'Henüz anlık görüntü yok';

  @override
  String get virtSnapshotWithMemory => 'Diskler ve bellek';

  @override
  String get virtSnapshotDiskOnly => 'Yalnızca diskler';

  @override
  String get virtSnapshotParent => 'Üst';

  @override
  String get virtSnapshotRevert => 'Geri dön';

  @override
  String get virtSnapshotMemory => 'Belleği dahil et';

  @override
  String get virtSnapshotMemoryTip =>
      'Geri dönüldüğünde konuk bu andan devam eder.';

  @override
  String get virtSnapshotMemoryAlways =>
      'Burada çalışan bir konuğun anlık görüntüsü her zaman belleğini içerir.';

  @override
  String get virtSnapshotMemoryOff =>
      'Konuk çalışmıyor, bu yüzden yalnızca diskleri kaydedilir.';

  @override
  String get virtSnapshotNameInvalid =>
      'Önce bir harf, sonra harf, rakam, - veya _; 2 ile 40 karakter.';

  @override
  String get virtSnapshotNameTaken => 'Bu adda bir anlık görüntü zaten var.';

  @override
  String get virtSnapshotRevertTip =>
      'Geri dönmek, anlık görüntüden sonraki tüm değişiklikleri siler.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return '$guest, $snapshot anına geri döndürülsün mü? O zamandan beri yapılan tüm değişiklikler kaybolur.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'Bu anlık görüntüde bellek yok: $guest durdurulacak.';
  }

  @override
  String get virtSnapshotStartAfter => 'Ardından başlat';

  @override
  String get virtVolumes => 'Birimler';

  @override
  String get virtNoPools => 'Depolama havuzu yok';

  @override
  String get virtNoNetworks => 'Ağ yok';

  @override
  String get virtPoolInactive =>
      'Havuz etkin değil, bu yüzden birimleri listelenemiyor.';

  @override
  String get virtShared => 'Düğümler arasında paylaşılan';

  @override
  String get virtBackingFile => 'Temel dosya';

  @override
  String get virtNetIsolated => 'Yalıtılmış';

  @override
  String get virtNetBridged => 'Köprülü';

  @override
  String get virtNetRouted => 'Yönlendirilmiş';

  @override
  String get virtBridge => 'Köprü';

  @override
  String get virtPorts => 'Bağlantı noktaları';

  @override
  String get virtAttachedGuests => 'Bağlı konuklar';

  @override
  String get virtNoAttachedGuests => 'Bağlı konuk yok';

  @override
  String get virtCreateVm => 'Yeni sanal makine';

  @override
  String get virtCreateLxc => 'Yeni kapsayıcı';

  @override
  String get virtCreateGuest => 'Yeni sanal makine veya kapsayıcı';

  @override
  String get virtKindVm => 'Sanal makine';

  @override
  String get virtKindLxc => 'Kapsayıcı';

  @override
  String get virtHostname => 'Ana makine adı';

  @override
  String get virtInstallMedia => 'Kurulum ortamı';

  @override
  String get virtNoIsos => 'Bu ana makinede ISO kalıbı yok';

  @override
  String get virtNoTemplates =>
      'Bu ana makinede kapsayıcı şablonu yok. PVE\'de bir depolamanın CT Şablonları\'ndan indirilebilir.';

  @override
  String get virtNoDiskStorage =>
      'Bu ana makinede yeni disk alan bir depolama yok';

  @override
  String get virtStartAfterCreate => 'Oluşturunca başlat';

  @override
  String get virtUnprivileged => 'Ayrıcalıksız kapsayıcı';

  @override
  String get virtUnprivilegedTip =>
      'root\'u ana makinede sıradan bir kullanıcıdır.';

  @override
  String get virtSshKeys => 'SSH açık anahtarları';

  @override
  String get virtCredentialsTip => 'root parolası, SSH anahtarları veya ikisi.';

  @override
  String virtCreated(String name) {
    return '$name oluşturuldu';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '$name oluşturuldu ama başlamadı';
  }

  @override
  String get virtErrExists => 'Bu adda bir konuk veya disk zaten var';

  @override
  String get virtCreateNameInvalidLibvirt =>
      'Harf, rakam, ., _ ve -, harf veya rakamla başlar; en fazla 63 karakter.';

  @override
  String get virtCreateNameInvalidPve =>
      'Harf, rakam ve -, noktalarla ayrılmış parçalar; en fazla 63 karakter.';

  @override
  String get virtCreateNameTaken => 'Bu adda bir konuk var.';

  @override
  String get virtCreateVmidInvalid => '100 ile 999999999 arası.';

  @override
  String get virtCreateVmidTaken => 'Bu VMID kullanımda.';

  @override
  String get virtCreateCoresInvalid =>
      'Bu ana makinenin izin verdiğinden fazla çekirdek.';

  @override
  String get virtCreateMemoryInvalid => 'Bellek yetersiz.';

  @override
  String get virtCreateStorageMissing => 'Diskinin nereye gideceğini seçin.';

  @override
  String get virtCreateDiskInvalid => '1 GiB ile 64 TiB arası.';

  @override
  String get virtCreateTemplateMissing => 'Bir şablon seçin.';

  @override
  String get virtCreateCredentialsMissing =>
      'Bir root parolası veya SSH anahtarı belirleyin.';

  @override
  String virtCreatePasswordShort(int min) {
    return 'En az $min karakter.';
  }

  @override
  String get virtCreateSshKeysInvalid =>
      'Her satıra bir OpenSSH açık anahtarı.';

  @override
  String get virtDeleteDisks => 'Disklerini de sil';

  @override
  String get virtDeleteDisksPve =>
      'Diskleri onunla birlikte silinir; kurulum ortamı korunur.';

  @override
  String virtDeleted(String name) {
    return '$name silindi';
  }

  @override
  String get pveTokenTipCreate =>
      'Konuk oluşturmak ve silmek için ayrıca VM.Allocate, VM.Config.*, Datastore.AllocateSpace ve SDN.Use gerekir.';

  @override
  String get pveTokenTipHardware =>
      'Donanım düzenlemek için VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.CDROM, VM.Config.Network ve VM.Config.Options gerekir; yeni diskler ve arabirimler için ayrıca Datastore.AllocateSpace ve SDN.Use gerekir. Ekran kartı ile USB ve PCI aygıtları ayrıca VM.Config.HWType gerektirir; kaynak eşlemesiyle verilen bir aygıt o eşleme üzerinde Mapping.Use, eşlemeleri listelemek için Mapping.Audit gerektirir.';

  @override
  String get pveTokenTipBackup =>
      'Klonlama VM.Clone, yedekleme ve geri yükleme VM.Backup gerektirir; kopyanın veya yedeğin gittiği yerde Datastore.AllocateSpace de gerekir.';

  @override
  String get virtErrConflict => 'Başka yerde değişti';

  @override
  String get virtErrConflictTip =>
      'Bu konuğun yapılandırması burada okunduktan sonra başka biri tarafından değiştirildi, bu yüzden hiçbir şey değiştirilmedi. Yeniden okundu: hâlâ gerekiyorsa değişikliği tekrar yapın.';

  @override
  String get virtHardware => 'Donanım';

  @override
  String get virtHwAddDisk => 'Disk ekle';

  @override
  String get virtHwAddMount => 'Bağlama noktası ekle';

  @override
  String get virtHwAddNic => 'Ağ arabirimi ekle';

  @override
  String get virtHwAppliesOnRestart =>
      'Kaydedildi. Bir sonraki başlatmada geçerli olur.';

  @override
  String get virtHwAutostart => 'Ana makineyle başlat';

  @override
  String get virtHwAutostartPve => 'onboot · VMID sırasıyla başlatılır';

  @override
  String get virtHwBalloonLibvirt => 'Geçerli bellek';

  @override
  String get virtHwBalloonNote =>
      'Bellek azaldığında ana makinenin konuğun boştaki belleğini geri almasına izin verir';

  @override
  String get virtHwBoot => 'Önyükleme';

  @override
  String get virtHwBootOrder => 'Önyükleme sırası';

  @override
  String get virtHwBootTip =>
      'Oklar aygıtı taşır; dokunmak ondan önyüklemeyi açar veya kapatır.';

  @override
  String get virtHwCdrom => 'CD-ROM';

  @override
  String get virtHwConfigFile => 'Yapılandırma dosyası';

  @override
  String get virtHwCores => 'Çekirdekler';

  @override
  String get virtHwCpuTypeDefault => 'Varsayılan';

  @override
  String get virtHwDeleteVolume => 'Birimini de sil';

  @override
  String get virtHwDetach => 'Ayır';

  @override
  String get virtHwDiskHotplug => 'Sıcak takılabilir: çalışırken eklenebilir';

  @override
  String get virtHwDisksLxc => 'Kök disk ve bağlama noktaları';

  @override
  String get virtHwEject => 'Çıkar';

  @override
  String get virtHwEmpty => 'Ortam yok';

  @override
  String get virtHwFirewall => 'Güvenlik duvarı';

  @override
  String virtHwFree(String size) {
    return '$size boş';
  }

  @override
  String get virtHwGrow => 'Büyüt';

  @override
  String get virtHwGrowNote => 'Diskler yalnızca büyütülebilir.';

  @override
  String get virtHwGrowNoteRunning =>
      'Diskler yalnızca büyür. Çalışırken büyütüldüyse bölüm konukta genişletilmelidir.';

  @override
  String get virtHwGuestUsed => 'Konuğun kullandığı';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'Ana makine $threads iş parçacığı · $allocated ayrılmış';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'Ana makine $total · $allocated ayrılmış';
  }

  @override
  String get virtHwHotplugNow => 'Sıcak takılır: hemen geçerli olur.';

  @override
  String get virtHwIssueBootEmpty => 'En az bir aygıt işaretleyin';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'Toplam 1 ile $max vCPU arası';
  }

  @override
  String get virtHwIssueCpuOnline => 'Etkin vCPU\'lar: 1 ile toplam arası';

  @override
  String get virtHwIssueDiskShrink =>
      'Şimdikinden büyük olmalı: diskler yalnızca büyür';

  @override
  String get virtHwIssueDiskSize => '1 ile 65536 GiB arası';

  @override
  String virtHwIssueMemory(int min, int max) {
    return '$min ile $max MiB arası';
  }

  @override
  String get virtHwIssueMemoryMin => 'Bellekten fazla olamaz';

  @override
  String get virtHwIssueMountPoint => '/data gibi mutlak bir yol';

  @override
  String get virtHwIssueStorageSpace => 'Depolamanın boş alanından fazla';

  @override
  String get virtHwIssueSwap => 'Negatif olamaz';

  @override
  String get virtHwLater => 'Yeniden başlatınca geçerli';

  @override
  String get virtHwLess => 'Azalt';

  @override
  String get virtHwLinkDown => 'Bağlı değil';

  @override
  String get virtHwLinkNote =>
      'Kapalıyken konuk kablonun çekildiğini görür; yeniden başlatma gerekmez';

  @override
  String get virtHwLinkUp => 'Bağlı';

  @override
  String get virtHwMac => 'MAC adresi';

  @override
  String get virtHwModel => 'Model';

  @override
  String get virtHwMore => 'Artır';

  @override
  String get virtHwMountFromPool =>
      'Bağlama noktaları doğrudan bir depolamadan ayrılır';

  @override
  String get virtHwMountPoint => 'Bağlama noktası';

  @override
  String get virtHwMoveDown => 'Aşağı taşı';

  @override
  String get virtHwMoveUp => 'Yukarı taşı';

  @override
  String get virtHwNewDisk => 'Yeni disk';

  @override
  String get virtHwNewMount => 'Yeni bağlama noktası';

  @override
  String get virtHwNewNic => 'Yeni ağ arabirimi';

  @override
  String get virtHwNicHotplug => 'virtio arabirimleri sıcak takılabilir';

  @override
  String get virtHwNics => 'Ağ arabirimleri';

  @override
  String get virtHwNoMedia => 'Ortam yok';

  @override
  String get virtHwNoNetworks => 'Burada ağ veya köprü yok';

  @override
  String get virtHwNoStorage => 'Burada disk alabilen depolama yok';

  @override
  String get virtHwOnline => 'Etkin vCPU\'lar';

  @override
  String get virtHwPendingBanner =>
      'Bazı donanım değişiklikleri yeniden başlatınca geçerli olur';

  @override
  String get virtHwPickNet => 'Bir ağ seçin';

  @override
  String get virtHwPickPool => 'Bir depolama ve boyut seçin';

  @override
  String get virtHwProcessor => 'İşlemci';

  @override
  String get virtHwRemove => 'Kaldır';

  @override
  String get virtHwRemoveCdrom => 'CD-ROM\'u kaldır';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return '$disk, $guest konuğundan kaldırılsın mı?';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return '$nic, $guest konuğundan kaldırılsın mı?';
  }

  @override
  String get virtHwResources => 'Kaynaklar';

  @override
  String get virtHwRestartNow => 'Şimdi yeniden başlat';

  @override
  String get virtHwRevert => 'Geri al';

  @override
  String get virtHwRevertAll => 'Tümünü geri al';

  @override
  String get virtSetRenameStopped =>
      'Yeniden adlandırmak için konuğu kapatın: libvirt yalnızca çalışmayan bir konuğu yeniden adlandırır.';

  @override
  String virtSetIssueDescription(int max) {
    return 'En çok $max karakter, denetim karakteri olmadan.';
  }

  @override
  String get virtSetManualStart => 'Elle başlatılır';

  @override
  String get virtSetProtection => 'Koruma';

  @override
  String get virtSetProtectionNote =>
      'Konuğun silinmesini ve disklerinin değiştirilmesini engeller';

  @override
  String get virtSetIrreversible => 'Geri alınamaz';

  @override
  String get virtSetDeleteStopFirst => 'Silmeden önce kapatın.';

  @override
  String get virtSetDeleteProtected =>
      'Koruma açık: önce Genel altında kapatın.';

  @override
  String get virtSetDeleteAgain => 'Onaylamak için yeniden basın';

  @override
  String virtSetDeleteConfirm(String name) {
    return '$name öğesini sil';
  }

  @override
  String get virtSetDeleteVm => 'Sanal makineyi sil';

  @override
  String get virtSetDeleteLxc => 'Kapsayıcıyı sil';

  @override
  String get virtHwSockets => 'Soketler';

  @override
  String get virtHwSource => 'Kaynak';

  @override
  String get virtHwSwap => 'Takas';

  @override
  String get virtHwTopology => 'Soket × çekirdek';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets soket × $cores çekirdek × $threads iş parçacığı';
  }

  @override
  String virtHwTotal(String size) {
    return 'toplam $size';
  }

  @override
  String get virtHwVolumeKept =>
      'Kaldırıldı, ancak çalışan konuk diski hâlâ kullanıyor, bu yüzden birimi korundu. Bir sonraki başlatmada ayrılacak.';

  @override
  String get virtHwBus => 'Veri yolu';

  @override
  String get virtHwCache => 'Önbellek';

  @override
  String get virtHwBusStopped =>
      'Veri yolu yalnızca konuk durdurulmuşken değişir.';

  @override
  String get virtHwMacGenerate => 'Oluştur';

  @override
  String get virtHwIssueMac =>
      'Tek noktaya yayın MAC adresi olmalı, örn. 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => 'Önce konuğu durdurun';

  @override
  String get virtHwIssueStorageMissing => 'Önce bir depolama seçin';

  @override
  String get virtHwIssueDevice => 'Önce bir aygıt seçin';

  @override
  String get virtHwDevices => 'CD-ROM ve geçiş';

  @override
  String get virtHwDevicesEmpty => 'USB ve PCI geçişi, CD-ROM, TPM';

  @override
  String get virtHwAddDevice => 'Aygıt ekle';

  @override
  String get virtHwNewDevice => 'Yeni aygıt';

  @override
  String get virtHwUsbHotplug => 'USB geçişi çalışırken takılabilir.';

  @override
  String get virtHwPci => 'PCI geçişi';

  @override
  String get virtHwIommuOffTitle => 'Ana makinede IOMMU yok';

  @override
  String get virtHwIommuOffBody =>
      'Önce ana makinenin BIOS\'unda VT-d ya da AMD-Vi\'yi, çekirdeğinde IOMMU\'yu açın. O zamana kadar PCI aygıtı verilen konuk başlamaz.';

  @override
  String get virtHwPciTitle => 'Ana makinede IOMMU gerekir';

  @override
  String get virtHwPciBody =>
      'Geçirildikten sonra ana makine aygıtı kullanamaz, konuk da çalışırken taşınamaz.';

  @override
  String virtHwIommuGroup(int group) {
    return 'IOMMU grubu $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return 'IOMMU grubunu paylaşan $count aygıt birlikte geçirilir';
  }

  @override
  String get virtHwNoHostDevices => 'Bu ana makinede geçirilecek aygıt yok';

  @override
  String get virtHwMappingsOnly =>
      'Burada yalnızca kaynak eşlemeleri kullanılabilir: PVE ham aygıt geçişine yalnızca parolasıyla giriş yapan root@pam için izin verir. Eşlemeleri Veri Merkezi → Kaynak Eşlemeleri altında oluşturun.';

  @override
  String get virtHwTpmNote => 'Windows 11 TPM 2.0 gerektirir.';

  @override
  String get virtHwDisplay => 'Görüntü';

  @override
  String get virtHwProtocol => 'Protokol';

  @override
  String get virtHwListen => 'Dinleme';

  @override
  String get virtHwGpu => 'Ekran kartı';

  @override
  String get virtHwListenAllTitle => 'Konsol ağa açık';

  @override
  String get virtHwListenAllBody =>
      'Tüm adreslerde dinlemek, ana makineye erişen herkesin konsola bağlanmasına izin verir. 127.0.0.1\'de tutun ve SSH tüneliyle bağlanın.';

  @override
  String get virtHwFirmware => 'Ürün yazılımı';

  @override
  String get virtHwUefiSub =>
      'OVMF · Secure Boot destekli, Windows 11 için gerekli';

  @override
  String get virtHwBiosSub => 'SeaBIOS · eski sistemler ve MBR diskler';

  @override
  String get virtHwSecureBootNote =>
      'Yalnızca imzalı çekirdek ve önyükleyicileri başlatır';

  @override
  String get virtHwFirmwareWarnTitle =>
      'Kurulu bir sistemin ürün yazılımını değiştirmeyin';

  @override
  String get virtHwFirmwareWarnBody =>
      'UEFI ile BIOS arasında geçiş, kurulu sistemi önyüklenemez hâle getirir.';

  @override
  String get virtHwFirmwareStopped =>
      'Ürün yazılımı yalnızca konuk durdurulmuşken değişir.';

  @override
  String get virtHwSecureBootVars =>
      'Secure Boot\'u açıp kapatmak EFI değişkenlerini yeniden oluşturur; içlerinde kayıtlı önyükleme girdileri kaybolur.';

  @override
  String get virtHwEfiStorage => 'EFI değişkenlerinin yeri';

  @override
  String get virtHwTpmStorage => 'TPM durumunun yeri';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return '$guest, $firmware olarak değiştirilsin mi?';
  }

  @override
  String get virtCloneName => 'Yeni ad';

  @override
  String get virtCloneFull => 'Tam klon';

  @override
  String get virtCloneCopyDisks => 'Disk içeriğini kopyala';

  @override
  String get virtCloneLinkedNote =>
      'Kapalı: şablonun disklerine bağlı bir bağlantılı klon';

  @override
  String get virtCloneFullOnly =>
      'Yalnızca bir şablon bağlantılı klon olarak klonlanabilir';

  @override
  String get virtCloneEmptyNote => 'Kapalı: aynı boyutta yeni boş diskler';

  @override
  String get virtCloneStopFirst => 'Klonlamadan önce kapatın.';

  @override
  String get virtCloneFullShort => 'Tam';

  @override
  String get virtCloneLinkedShort => 'Bağlantılı';

  @override
  String get virtCloneEmptyShort => 'Boş diskler';

  @override
  String get virtCloning => 'Klonlanıyor…';

  @override
  String virtCloned(String name) {
    return '$name olarak klonlandı';
  }

  @override
  String get virtBackupPlan => 'Plan';

  @override
  String get virtBackupPlanWhere => 'Veri merkezi → Yedekleme';

  @override
  String get virtBackupNoPlanShort => 'Plan yok';

  @override
  String get virtBackupNoPlan =>
      'Bu konuğu içeren zamanlanmış yedekleme işi yok. İşler veri merkezinde ayarlanır.';

  @override
  String get virtBackupKeep => 'Sakla';

  @override
  String get virtBackupJobDisabled => 'Bu iş devre dışı.';

  @override
  String virtBackupCount(int count) {
    return '$count yedek';
  }

  @override
  String get virtBackupNoStorage => 'Bu düğümde yedekleri tutan depolama yok.';

  @override
  String get virtBackupLiveTip => 'Çalışıyor: snapshot modu, kesinti yok';

  @override
  String get virtBackupStoppedTip => 'Kapalı: olduğu gibi yedeklenir';

  @override
  String get virtBackupNow => 'Şimdi yedekle';

  @override
  String get virtBackupNotes => 'Notlar';

  @override
  String get virtBackupProtected =>
      'Korumalı: koruma PVE\'de kaldırılana kadar silinemez.';

  @override
  String virtBackupVerified(String state) {
    return 'Doğrulama: $state';
  }

  @override
  String get virtBackupRestoreOverwrites =>
      'Geri yükleme mevcut diskleri üzerine yazar';

  @override
  String get virtBackupStopFirst => 'Geri yüklemeden önce kapatın.';

  @override
  String get virtBackupRestoreAgain =>
      'Konuğun diskleri ve yapılandırması yedektekilerle değiştirilir.';

  @override
  String get virtBackupDeleteConfirm => 'Yedeği sil';

  @override
  String get virtBackupRestoreNew => 'Yeni olarak geri yükle';

  @override
  String get virtBackupRestoreConfirm => 'Üzerine geri yükle';

  @override
  String get virtBackupDone => 'Yedekleme tamamlandı';

  @override
  String get virtBackupDeleted => 'Yedek silindi';

  @override
  String virtBackupRestored(String time) {
    return '$time tarihinden geri yüklendi';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return '$account hesabının $path üzerinde $privilege yetkisi yok. PVE ana makinesinde verin:\n$command';
  }

  @override
  String get virtCanDelete => 'Silinebilir';

  @override
  String get virtInUse => 'Kullanımda';

  @override
  String get virtOps => 'İşlemler';

  @override
  String get virtPool => 'Depolama havuzu';

  @override
  String get virtPoolNew => 'Yeni depolama havuzu';

  @override
  String get virtStorageAdd => 'Depolama ekle';

  @override
  String virtPoolUsedPct(String pct) {
    return '%$pct kullanıldı';
  }

  @override
  String get virtPoolInUse =>
      'Bir VM buradaki bir birimi kullanıyor; havuz durdurulamaz veya kaldırılamaz.';

  @override
  String get virtPoolDelete => 'Havuzu sil';

  @override
  String get virtStorageRemove => 'Depolamayı kaldır';

  @override
  String virtPoolDeleteAsk(String name) {
    return '$name havuzu kaldırılsın mı? Tanımı silinir; birimleri yerinde kalır.';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return '$name depolaması PVE yapılandırmasından kaldırılsın mı? İçindekiler kalır.';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return '$count birimi diskte kalır.';
  }

  @override
  String get virtPoolDeleteStorage => 'Dizinini de sil (yalnızca boşsa)';

  @override
  String virtPoolStopAsk(String name) {
    return '$name havuzu durdurulsun mu? Yeniden başlayana kadar birimler listelenemez ve oluşturulamaz.';
  }

  @override
  String virtStorageDisableAsk(String name) {
    return '$name depolaması devre dışı bırakılsın mı? Diskleri üzerinde olan VM\'ler yeniden etkinleşene kadar başlamaz.';
  }

  @override
  String get virtPoolLogicalNote =>
      'Var olan bir birim grubu olduğu gibi kullanılır; hiçbir şey biçimlendirilmez.';

  @override
  String get virtPoolMountPoint => 'Bağlama noktası';

  @override
  String get virtPoolSourceNfs => 'Kaynak (host:/yol)';

  @override
  String get virtPoolSourceVg => 'Birim grubu';

  @override
  String get virtPoolSourceThin => 'Birim grubu / thin pool';

  @override
  String get virtPoolSourceZfs => 'ZFS havuzu';

  @override
  String get virtPoolTypeVg => 'LVM birim grubu';

  @override
  String get virtResNameEmpty => 'Bir ad girin';

  @override
  String get virtResNameInvalid =>
      'Bu ana makinenin kabul ettiği bir ad değil (harf, rakam, . _ -)';

  @override
  String get virtResSourceInvalid => 'Geçerli bir yol veya kaynak değil';

  @override
  String get virtResTargetInvalid => 'Mutlak bir yol';

  @override
  String get virtResCidrInvalid => 'Önekli bir adres, ör. 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid =>
      'Ağda sıralı iki adres, ana makinenin adresi hariç';

  @override
  String get virtResSubnetTaken => 'Buradaki başka bir ağ bu alt ağda';

  @override
  String get virtResBridgeInvalid => 'Arabirim adı değil';

  @override
  String get virtResFormat => 'Bu havuz bu biçimi desteklemiyor';

  @override
  String get virtVolNew => 'Yeni birim';

  @override
  String virtVolCount(int count) {
    return '$count birim';
  }

  @override
  String get virtVolNone => 'Bu havuzda henüz birim yok.';

  @override
  String get virtVolEmptyAttach =>
      'Yeni bir birim daha sonra herhangi bir VM\'e takılabilir';

  @override
  String get virtVolEmptyUpload => 'Doğrudan bir ISO da yüklenebilir';

  @override
  String get virtVolPveName =>
      'PVE birimi VM\'ine göre adlandırır: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => 'Kullanan';

  @override
  String get virtVolAllocated => 'Ayrılmış';

  @override
  String get virtVolGrowFromGuest =>
      'Bir VM kullanıyor: o VM\'in Donanım görünümünden büyütün';

  @override
  String get virtVolInUse => 'Bu birimi bir VM kullanıyor';

  @override
  String get virtVolAttach => 'VM\'e tak';

  @override
  String get virtVolAttachNote =>
      'İlk diskinin bulunduğu veri yoluna yeni disk olarak takılır';

  @override
  String virtVolAttached(String name) {
    return '$name makinesine takıldı';
  }

  @override
  String get virtVolInsert => 'CD-ROM\'a tak';

  @override
  String virtVolInserted(String name) {
    return '$name CD-ROM sürücüsüne takıldı';
  }

  @override
  String virtVolNoCdrom(String name) {
    return '$name makinesinde CD-ROM sürücüsü yok';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return '$name birimi $pool havuzundan silinsin mi? İçeriği kalıcı olarak gider.';
  }

  @override
  String get virtUploadIso => 'ISO yükle';

  @override
  String virtUploadTo(String pool) {
    return '$pool konumuna yükle';
  }

  @override
  String virtUploadDone(String name) {
    return '$name yüklendi';
  }

  @override
  String get virtNetConfig => 'Yapılandırma';

  @override
  String get virtNetInternal => 'Dahili';

  @override
  String get virtNetBridgePorts => 'Köprü bağlantı noktaları';

  @override
  String get virtNetHostBridge => 'Ana makine köprüsü';

  @override
  String get virtNetPortsHint => 'eno2; dahili köprü için boş';

  @override
  String get virtNetDhcpRange => 'DHCP aralığı';

  @override
  String get virtNetDhcpTip => 'dnsmasq VM\'lere adres verir';

  @override
  String get virtNetVlanTip => 'VM ağ kartları VLAN etiketi taşıyabilir';

  @override
  String get virtNetNatTip =>
      'Ana makine üzerinden: VM\'ler dışarı çıkar, dışarıdan girilemez';

  @override
  String get virtNetRoutedTip =>
      'NAT olmadan ana makine yönlendirir: LAN\'da dönüş rotası gerekir';

  @override
  String get virtNetIsolatedTip =>
      'Yalnızca VM\'ler ve ana makine birbirine ulaşır';

  @override
  String get virtNetBridgedTip =>
      'VM\'ler ana makinenin bir köprüsüne, fiziksel ağına katılır';

  @override
  String get virtNetNew => 'Yeni ağ';

  @override
  String get virtNetNewBridge => 'Yeni Linux köprüsü';

  @override
  String get virtNetVirtual => 'Sanal ağ';

  @override
  String get virtNetDelete => 'Ağı sil';

  @override
  String virtNetDeleteAsk(String name) {
    return '$name ağı silinsin mi? Durdurulur ve tanımı kaldırılır.';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return '$name köprüsü $node üzerinden kaldırılsın mı? Şimdi bekleyen yapılandırmadan, uygulanınca da ana makineden çıkar.';
  }

  @override
  String virtNetInUse(int count) {
    return 'Üzerindeki VM: $count. Silinemez.';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return '$name durdurulsun mu? Üzerindeki $count VM yeniden başlayana kadar ağı kaybeder.';
  }

  @override
  String get virtNetInactivePve =>
      'Etkin değil: yeni bir köprü uygulanana kadar bekleyen yapılandırmada durur.';

  @override
  String get virtNetPveApplyNote =>
      'Bekleyen değişiklik olarak kaydedilir; yapılandırma uygulanınca geçerli olur (ifreload -a).';

  @override
  String get virtNetPendingSaved =>
      'Bekleyen olarak kaydedildi: geçerli olması için yapılandırmayı uygulayın';

  @override
  String virtNetPendingTitle(String node) {
    return '$node üzerinde bekleyen ağ değişiklikleri';
  }

  @override
  String get virtNetPendingTip =>
      'PVE ağ değişikliklerini uygulanana kadar interfaces.new içinde tutar.';

  @override
  String get virtNetPendingShow => 'Değişiklikleri göster';

  @override
  String get virtNetApply => 'Yapılandırmayı uygula';

  @override
  String virtNetApplyAsk(String node) {
    return '$node üzerinde bekleyen ağ yapılandırması uygulansın mı? PVE ana makinenin ağını yeniden yükler (ifreload -a): bir hata ana makineye erişimi kesebilir.';
  }

  @override
  String virtNetRevertAsk(String node) {
    return '$node üzerinde bekleyen ağ yapılandırması atılsın mı?';
  }

  @override
  String get pveTokenTipStorage =>
      'Depolama yönetimi /storage üzerinde Datastore.Allocate (ekleme, devre dışı bırakma, kaldırma), Datastore.AllocateSpace (birimler) ve Datastore.AllocateTemplate (yüklemeler) gerektirir; Linux köprüleri ve ağ yapılandırmasını uygulamak düğümde Sys.Modify gerektirir.';

  @override
  String get virtCreateUnnamed => 'Adsız';

  @override
  String get virtCreateNotChosen => 'Seçilmedi';

  @override
  String get virtCreateKindVmSub => 'qm · tam bir KVM sanal makinesi';

  @override
  String get virtCreateKindLxcSub =>
      'pct · ana makinenin çekirdeğini paylaşır, daha hafif';

  @override
  String get virtCloudImage => 'Bulut imajı';

  @override
  String get virtCloudImageTip =>
      'Üzerinde sistem olan bir disk: kopyalanır, Depolama altındaki boyuta büyütülür ve ilk açılışta cloud-init ile yapılandırılır. İmajın kendisi olduğu gibi kalır.';

  @override
  String get virtNoCloudImagesLibvirt =>
      'Burada bulut imajı yok: hiçbir VM\'nin kullanmadığı bir qcow2 veya raw imajını bir havuza koyun (Depolama\'dan yükleyin).';

  @override
  String get virtNoCloudImagesPve =>
      'Burada bulut imajı yok: bir qcow2, raw veya vmdk imajını Import içerik türüne sahip bir depolamaya yükleyin (PVE 8.2+).';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 UEFI ve TPM 2.0 gerektirir';

  @override
  String get virtCreateWindowsBody =>
      'Yukarıda UEFI\'yi seçin ve TPM\'yi açın.';

  @override
  String get virtCreateWindowsNoTpm =>
      'Bu ana makinede yazılım TPM\'si (swtpm) yok: VM\'ye vermek için kurun.';

  @override
  String virtCreateImageSize(String size) {
    return 'İmaj $size: disk en az bu kadar büyük olmalı.';
  }

  @override
  String get virtCreateImageMissing => 'Bir bulut imajı seçin.';

  @override
  String get virtCreateIncomplete =>
      'Önce turuncu işaretli kısımları tamamlayın.';

  @override
  String virtCreateOn(String host) {
    return '$host üzerinde oluşturulur';
  }

  @override
  String get virtCiTip =>
      'sudo yetkili bir hesap; parola, SSH anahtarı veya ikisiyle giriş yapılır.';

  @override
  String get virtCiUserInvalid =>
      'Küçük harf, rakam, _ ve -; harf veya _ ile başlamalı';

  @override
  String get virtCiCredentialsMissing =>
      'Bir parola veya SSH anahtarı belirleyin.';

  @override
  String get virtCiHostnamePve => 'Ana bilgisayar adı VM\'nin adıdır.';

  @override
  String get virtCiStatic => 'Statik';

  @override
  String get virtCiAddressInvalid =>
      'Önekiyle bir IPv4 adresi, örneğin 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'Bir IPv4 adresi, örneğin 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => 'Boş: DHCP\'den';

  @override
  String get virtCiDnsInvalid => 'Boşluk veya virgülle ayrılmış IP adresleri';

  @override
  String get virtCiSearch => 'Arama alanı';

  @override
  String get virtCiSeedNote =>
      'Diskin yanındaki küçük bir ISO\'ya yazılır, CD-ROM olarak takılır ve VM ile birlikte silinir. Parolanın yalnızca özeti saklanır.';

  @override
  String get virtCiNoToolTitle =>
      'Ana makinede cloud-init verisini oluşturacak araç yok';

  @override
  String virtCiNoToolBody(String tools) {
    return 'Ana makineye $tools araçlarından birini kurun. cloud-init olmadan imaj, giriş yapılacak hesap olmadan başlar.';
  }

  @override
  String get virtHwCloudInitNote =>
      'cloud-init\'in ilk açılışta okuduğu veri. Kurulum ortamı değil: buraya bir şey takılmaz.';

  @override
  String get virtHwCdromLater =>
      'Çalışırken sürücü bir sonraki açılışta eklenir (SATA ve IDE çalışırken takmayı desteklemez).';

  @override
  String virtCreateDiskKept(String size) {
    return 'Disk, imajın kendi boyutu olan $size olarak kaldı; istenenden büyük: bir disk hiçbir zaman üzerindeki sistemden küçük kesilmez.';
  }

  @override
  String get virtCiEditTip =>
      'cloud-init\'in bu VM\'de kurduğu şeyler: sudo yetkili bir hesap, ona nasıl girileceği, ana makine adı ve adres.';

  @override
  String get virtCiForeignTitle =>
      'Bu seed, bu uygulamanın yazdığından fazlasını içeriyor';

  @override
  String get virtCiForeignBody =>
      'Başka yerde yapılan ayarlar (paketler, komutlar, diğer hesaplar) burada gösterilmez. Kaydetmek seedi burada gösterilenle değiştirir.';

  @override
  String get virtCiPasswordKept => 'Ayarlı. Korumak için boş bırakın';

  @override
  String get virtCiRemovePassword => 'Parolayı kaldır';

  @override
  String get virtCiRemovePasswordNote => 'Yalnızca SSH anahtarıyla giriş';

  @override
  String get virtCiKeysAdded =>
      'Anahtarlar hesaba eklenir. Burada çıkarılan bir anahtar, orada silinene kadar sistemde kalır; yeni bir kullanıcı adı eskisinin yanında yeni bir hesap açar.';

  @override
  String get virtCiEffectTitle => 'Bir sonraki açılışta geçerli olur';

  @override
  String get virtCiEffectLibvirt =>
      'Kaydetmek, yeni bir örnek kimliğiyle yeni bir seed yazar.';

  @override
  String get virtCiEffectPve =>
      'PVE cloud-init sürücüsünü hemen yeniden yazar; örnek kimliği bu ayarlardan türetilir, bu yüzden buradaki her değişiklik yenisini oluşturur.';

  @override
  String get virtCiNewInstance =>
      'Bir sonraki açılışta cloud-init sistemi yeni bir örnek olarak ele alır: ana makine adını yeniden ayarlar, hesap yoksa oluşturur, parolasını ayarlar, anahtarları ekler ve ağ yapılandırmasını yeniden yazar. Yeni SSH ana makine anahtarları da üretir; bu yüzden SSH istemcileri ana makine anahtarının değiştiği uyarısını verir. O açılıştan önce hiçbir şey değişmez.';

  @override
  String get virtCiSaved => 'Kaydedildi. Bir sonraki açılışta geçerli olur.';
}
