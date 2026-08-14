// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

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
      'Bir servis temel URL\'si ya da tam bir Chat Completions veya Responses uç noktası gir. ServerBox yolu seçilen protokole göre tamamlar.';

  @override
  String get askAiProtocolTip =>
      'Otomatik, resmî OpenAI uç noktası için Responses\'ı, uyumlu sağlayıcılar için Chat Completions\'ı kullanır.';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => 'Komut terminale eklendi';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Lütfen Ayarlar\'da $fields öğesini yapılandırın.';
  }

  @override
  String get askAiConfirmExecute => 'Çalıştırmadan önce onayla';

  @override
  String get askAiConversation => 'YZ sohbeti';

  @override
  String get askAiDisclaimer =>
      'Yapay zeka hata yapabilir. Lütfen dikkatli kullanın.';

  @override
  String get askAiFollowUpHint => 'Yeni bir soru sor...';

  @override
  String get askAiInsertTerminal => 'Terminale ekle';

  @override
  String get askAiNoResponse => 'Yanıt yok';

  @override
  String get askAiRecommendedCommand => 'YZ önerilen komut';

  @override
  String get askAiSelectedContent => 'Seçilen içerik';

  @override
  String get askAiUsageHint => 'SSH Terminalinde kullanılır';

  @override
  String get askAiAgentTitle => 'SSH Agent';

  @override
  String get askAiAgentWelcome => 'Bu sunucuda ne yapalım?';

  @override
  String get askAiAgentWelcomeTip =>
      'Bir teşhis ya da görev iste. Agent her seferinde tek bir komut önerir ve değişiklik yapmadan önce onayını bekler.';

  @override
  String get askAiAgentPromptHint =>
      'Agent\'tan bir şeyi incelemesini veya düzeltmesini iste...';

  @override
  String get askAiAgentSend => 'Agent\'a gönder';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Seçilen terminal içeriğini incele, ne olduğunu açıkla ve işlem gerekiyorsa en güvenli sonraki adımı öner.';

  @override
  String get askAiTerminalContext => 'Terminal bağlamı';

  @override
  String get askAiReviewNeeded => 'İncele';

  @override
  String get askAiReviewAction => 'Önerilen komutu incele';

  @override
  String get askAiReviewBeforeContinuing =>
      'Önce önerilen komutu incele ya da reddet';

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
      'Bu komut veri silebilir, servisleri durdurabilir ya da geri alınması zor olabilir. Çalıştırmadan önce dikkatle incele.';

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
      'Yalnızca hem model hem de yerel güvenlik denetimleri komutu salt okunur olarak sınıflandırdığında otomatik çalıştırılır. Sistemi değiştiren komutlar yine incelenmelidir.';

  @override
  String get askAiSendOnEnter => 'Enter gönderir';

  @override
  String get askAiSendOnEnterTip =>
      'Enter mesajı gönderir, Shift+Enter yeni satır açar. Kapalıyken yer değiştirir: Enter yeni satır açar, Cmd/Ctrl+Enter gönderir.';

  @override
  String get askAiApiKeyOptional =>
      'Yerel veya kimlik doğrulaması olmayan uç noktalar için isteğe bağlı';

  @override
  String get askAiHistory => 'Konuşma geçmişi';

  @override
  String get askAiNewConversation => 'Yeni konuşma';

  @override
  String get askAiNoHistory => 'Bu sunucu için kayıtlı konuşma yok';

  @override
  String get askAiNoHistoryMessages => 'Henüz mesaj yok';

  @override
  String get askAiUntitledConversation => 'Yeni konuşma';

  @override
  String get askAiRenameConversation => 'Konuşmayı yeniden adlandır';

  @override
  String get askAiDeleteConversationTitle => 'Bu konuşma silinsin mi?';

  @override
  String get askAiDeleteConversationTip =>
      'Konuşma bu cihazdan kaldırılır ve geri alınamaz.';

  @override
  String get askAiClearHistoryTitle =>
      'Bu sunucunun Agent geçmişi temizlensin mi?';

  @override
  String get askAiClearHistoryTip =>
      'Bu sunucu için kaydedilmiş tüm Agent konuşmaları bu cihazdan kaldırılır.';

  @override
  String get askAiRestoredReview =>
      'Geçmişten geri yüklendi. Çalıştırmadan önce yeniden incele; kendiliğinden asla çalışmaz.';

  @override
  String get agentTitle => 'Agent';

  @override
  String get agentWelcome => 'Sunucularında ne yapalım?';

  @override
  String get agentWelcomeTip =>
      'Bir teşhis ya da işletim görevi iste. Agent, ServerBox\'ın anlık durumunu kullanır ve her seferinde incelenecek tek bir eylem önerir.';

  @override
  String get agentPromptHint =>
      'Agent\'tan sunucularını incelemesini veya yönetmesini iste...';

  @override
  String get agentNoServers => 'Yapılandırılmış sunucu yok';

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
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Araç çalıştırılamadı.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count araç çağrısı';
  }

  @override
  String get agentFloat => 'Diğer sekmelerin üzerinde yüzsün';

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
      'Agent bir SSH bağlantısı açmak istiyor. Parolayı buraya yaz, konuşmaya yazma; orada saklanır ve modele gönderilir.';

  @override
  String get agentAdHocSessions => 'Geçici bağlantılar';

  @override
  String get agentSaveServerTitle => 'Sunucu olarak kaydet';

  @override
  String get agentSaveServerTip =>
      'Bu sunucu ve girdiğin parola bu cihazda saklanacak.';

  @override
  String get agentMonitorOptional => 'monitor aracısı (isteğe bağlı)';

  @override
  String get atLeastOneTab => 'En az bir sekme seçilmelidir';

  @override
  String get authFailTip =>
      'Kimlik doğrulama başarısız oldu, lütfen kimlik bilgilerinin doğru olup olmadığını kontrol edin';

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
  String get discoverySummary => 'Keşif Özeti';

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
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount çalışıyor, $stoppedCount konteyner durdurulmuş.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count konteyner çalışıyor.';
  }

  @override
  String get doubleColumnMode => 'Çift sütun modu';

  @override
  String get doubleColumnTip =>
      'Bu seçenek yalnızca özelliği etkinleştirir, gerçekten etkinleşip etkinleşmeyeceği cihazın genişliğine bağlıdır';

  @override
  String get editVirtKeys => 'Sanal tuşları düzenle';

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
  String get finishedAt => 'Tamamlandı:';

  @override
  String get fullScreen => 'Tam ekran modu';

  @override
  String get fullScreenJitter => 'Tam ekran titreşim';

  @override
  String get fullScreenJitterHelp => 'Ekran yanmasını önlemek için';

  @override
  String get fullScreenTip =>
      'Cihaz yatay moda döndürüldüğünde tam ekran modu etkinleştirilsin mi? Bu seçenek yalnızca sunucu sekmesi için geçerlidir.';

  @override
  String get githubGist => 'GitHub Gist';

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
  String get homeWidgetUrlConfig => 'Ana ekran bileşeni URL\'sini yapılandır';

  @override
  String get ignoreCert => 'Sertifikayı yok say';

  @override
  String get image => 'Görüntü';

  @override
  String get imagesList => 'Görüntü listesi';

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
  String get pruneDanglingImagesTip =>
      'Yalnızca askıdaki görüntüleri (etiketsiz katmanları) kaldırır.';

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
  String get volume => 'Birim';

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
  String get noJumpServerAvailable => 'Kullanılabilir atlama sunucusu yok.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Atlama sunucusu ile ProxyCommand birlikte kullanılamaz.';

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
  String get onlyOneLine => 'Yalnızca tek satır olarak göster (kaydırılabilir)';

  @override
  String get openLastPath => 'Son yolu aç';

  @override
  String get openLastPathTip =>
      'Farklı sunucular farklı günlükler tutar ve günlük, çıkış yoludur';

  @override
  String get parseContainerStatsTip =>
      'Docker\'ın doluluk durumunu ayrıştırmak oldukça yavaş.';

  @override
  String get fullAccessRefused => 'Bu aracı kimlik bilgisiz terminal sunmuyor.';

  @override
  String get fullAccessInsecure =>
      'Bu aracı terminali yalnızca TLS veya loopback üzerinden sunuyor, bu bağlantı ise düz HTTP.';

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
  String get sameIdServerExist => 'Aynı kimliğe sahip bir sunucu zaten mevcut';

  @override
  String get second => 's';

  @override
  String get serverDetailOrder => 'Ayrıntı sayfası bileşen sırası';

  @override
  String get serverFuncBtns => 'Sunucu işlev düğmeleri';

  @override
  String get serverOrder => 'Sunucu sırası';

  @override
  String get serverTabRequired => 'Sunucu sekmesi kaldırılamaz';

  @override
  String get shareServerRiskTip =>
      'Bu QR kod, parolalar dahil olmak üzere sunucunun bağlantı ayarlarını düz metin olarak içerir. Kodu tarayan veya fotoğraflayan herkes bu sunucuya bağlanabilir.';

  @override
  String get sftpDlPrepare => 'Bağlantı hazırlanıyor...';

  @override
  String get sftpEditorTip =>
      'Boşsa, uygulamanın yerleşik dosya düzenleyicisi kullanılır. Bir değer varsa, uzak sunucunun düzenleyicisi kullanılır, örn. `vim` (otomatik olarak `EDITOR`\'a göre algılanması önerilir).';

  @override
  String get sftpRmrDirSummary =>
      'SFTP\'de bir klasörü silmek için `rm -r` kullan.';

  @override
  String get sftpSSHConnected => 'SFTP Bağlandı';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Önce klasörleri göster';

  @override
  String get specifyDev => 'Cihazı belirt';

  @override
  String get specifyDevTip =>
      'Örneğin, ağ trafiği istatistikleri varsayılan olarak tüm cihazlar içindir. Burada belirli bir cihaz belirtebilirsiniz.';

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
  String get ssh => 'SSH';

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
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Parmak izi (MD5 Base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Parmak izi (MD5 hex): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'SSH ana bilgisayar anahtarı türü';

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
  String get system => 'Sistem';

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
  String get portForwardBeta =>
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
  String get systemd => 'Systemd';

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
      'Saat bu sunucuları doğrudan monitor aracısından okur, bu yüzden yalnızca monitor yapılandırılmış sunucular seçilebilir.';

  @override
  String get watchNoMonitorServer =>
      'monitor aracısı yapılandırılmış sunucu yok';

  @override
  String get watchLegacyUrls => 'Eski durum URL\'leri';

  @override
  String get accessoryWidgetServer => 'Kilit ekranı bileşeni sunucusu';

  @override
  String get systemdMissing => 'Bu sunucuda systemd yok';

  @override
  String get systemdMissingTip =>
      '`systemctl` burada kurulu değil, bu yüzden listelenecek unit yok.';

  @override
  String initSystemFmt(String init) {
    return 'Bu makine $init kullanıyor gibi görünüyor.';
  }

  @override
  String get systemdListFailed => 'Unit\'ler listelenemedi';

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
}
