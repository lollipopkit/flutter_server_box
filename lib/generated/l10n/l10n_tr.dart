// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get aboutThanks => 'Aşağıdaki katılımcılara teşekkürler.';

  @override
  String get acceptBeta => 'Beta sürüm güncellemelerini kabul et';

  @override
  String get addSystemPrivateKeyTip =>
      'Şu anda özel anahtarlar mevcut değil, sistemle birlikte gelen anahtarı (~/.ssh/id_rsa) eklemek ister misiniz?';

  @override
  String get added2List => 'Görev listesine eklendi';

  @override
  String get addr => 'Adres';

  @override
  String get alreadyLastDir => 'Zaten son dizindesiniz.';

  @override
  String get askAi => 'Yapay zekaya sor';

  @override
  String get askAiApiKey => 'API anahtarı';

  @override
  String get askAiAwaitingResponse => 'Yapay zekâ yanıtı bekleniyor...';

  @override
  String get askAiBaseUrl => 'Temel URL';

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
  String get askAiModel => 'Model';

  @override
  String get askAiNoResponse => 'Yanıt yok';

  @override
  String get askAiRecommendedCommand => 'YZ önerilen komut';

  @override
  String get askAiSelectedContent => 'Seçilen içerik';

  @override
  String get askAiUsageHint => 'SSH Terminalinde kullanılır';

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
  String get backupVersionNotMatch => 'Yedekleme sürümü eşleşmiyor.';

  @override
  String get battery => 'Pil';

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
  String get closeAfterSave => 'Kaydet ve kapat';

  @override
  String get cmd => 'Komut';

  @override
  String get collapseUITip =>
      'Arayüzde uzun listelerin varsayılan olarak daraltılıp daraltılmayacağı';

  @override
  String get conn => 'Bağlantı';

  @override
  String get connectionDetails => 'Bağlantı Detayları';

  @override
  String get connectionStats => 'Bağlantı İstatistikleri';

  @override
  String get connectionStatsDesc =>
      'Sunucu bağlantı başarı oranını ve geçmişi görüntüle';

  @override
  String get container => 'Konteyner';

  @override
  String get containerTrySudoTip =>
      'Örneğin: Uygulamada kullanıcı aaa olarak ayarlanmış, ancak Docker root kullanıcısı altında kurulmuş. Bu durumda bu seçeneği etkinleştirmeniz gerekir.';

  @override
  String get convert => 'Dönüştür';

  @override
  String get copyPath => 'Yolu kopyala';

  @override
  String get cpuViewAsProgressTip =>
      'Her CPU\'nun kullanımını ilerleme çubuğu tarzında göster (eski tarz)';

  @override
  String get cursorType => 'İmleç türü';

  @override
  String get customCmd => 'Özel komutlar';

  @override
  String get customCmdDocUrl =>
      'https://github.com/lollipopkit/flutter_server_box/wiki#özel-komutlar';

  @override
  String get customCmdHint => '\"Komut Adı\": \"Komut\"';

  @override
  String get decode => 'Çöz';

  @override
  String get decompress => 'Sıkıştırmayı aç';

  @override
  String get deleteServers => 'Sunucuları toplu sil';

  @override
  String get desktopTerminalTip =>
      'SSH oturumları başlatılırken terminal öykünücüsünü açmak için kullanılan komut.';

  @override
  String get dirEmpty => 'Klasörün boş olduğundan emin olun.';

  @override
  String get disconnected => 'Bağlantı kesildi';

  @override
  String get discoverSshServers => 'SSH Sunucularını Keşfet';

  @override
  String get discoveryFailed => 'Keşif başarısız';

  @override
  String get discoverySettings => 'Keşif Ayarları';

  @override
  String get discoverySummary => 'Keşif Özeti';

  @override
  String get disk => 'Disk';

  @override
  String get diskHealth => 'Disk sağlığı';

  @override
  String get diskIgnorePath => 'Disk için yok sayılan yol';

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
  String get dockerNotInstalled => 'Docker kurulmamış';

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
  String get emulator => 'Emülatör';

  @override
  String get enableMdns => 'mDNS\'yi Etkinleştir';

  @override
  String get enableMdnsDesc =>
      'SSH hizmetlerini keşfetmek için mDNS/Bonjour kullan';

  @override
  String get encode => 'Kodla';

  @override
  String get envVars => 'Ortam değişkeni';

  @override
  String get experimentalFeature => 'Deneysel özellik';

  @override
  String get extraArgs => 'Ek argümanlar';

  @override
  String get fallbackSshDest => 'Yedek SSH hedefi';

  @override
  String get fdroidReleaseTip =>
      'Bu uygulamayı F-Droid\'den indirdiyseniz, bu seçeneği kapatmanız önerilir.';

  @override
  String get fgService => 'Ön Plan Servisi';

  @override
  String get fgServiceTip =>
      'Etkinleştirildikten sonra bazı cihaz modellerinde çökme olabilir. Devre dışı bırakmak, bazı modellerde SSH bağlantılarının arka planda sürdürülememesine neden olabilir. Lütfen sistem ayarlarında ServerBox bildirim izinlerini, arka planda çalışmayı ve otomatik uyanmayı etkinleştirin.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '\'$file\' dosyası çok büyük $size, maksimum $sizeMax';
  }

  @override
  String get finishedAt => 'Tamamlandı:';

  @override
  String get followSystem => 'Sistemi takip et';

  @override
  String get fontSize => 'Yazı tipi boyutu';

  @override
  String get force => 'Zorla';

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
  String get goBackQ => 'Geri dön?';

  @override
  String get goto => 'Git';

  @override
  String get hideTitleBar => 'Başlık çubuğunu gizle';

  @override
  String get highlight => 'Kod vurgulama';

  @override
  String get homeTabs => 'Ana Sayfa Sekmeleri';

  @override
  String get homeTabsCustomizeDesc =>
      'Ana sayfada görünecek sekmeleri ve sıralarını özelleştirin';

  @override
  String get homeWidgetUrlConfig => 'Ana ekran bileşeni URL\'sini yapılandır';

  @override
  String get host => 'Ana bilgisayar';

  @override
  String httpFailedWithCode(Object code) {
    return 'İstek başarısız oldu, durum kodu: $code';
  }

  @override
  String get ignoreCert => 'Sertifikayı yok say';

  @override
  String get image => 'Görüntü';

  @override
  String get imagesList => 'Görüntü listesi';

  @override
  String get inner => 'İç';

  @override
  String get install => 'Kur';

  @override
  String get installDockerWithUrl =>
      'Lütfen önce https://docs.docker.com/engine/install adresinden Docker\'ı kurun.';

  @override
  String get invalid => 'Geçersiz';

  @override
  String get jumpServer => 'Atlama sunucusu';

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
  String get letterCache => 'Harf önbelleği';

  @override
  String get letterCacheTip =>
      'Devre dışı bırakılması önerilir, ancak devre dışı bırakıldığında CJK karakterlerini girmek mümkün olmayacaktır.';

  @override
  String get location => 'Konum';

  @override
  String get loss => 'Kayıp';

  @override
  String madeWithLove(Object myGithub) {
    return '$myGithub tarafından ❤️ ile yapıldı';
  }

  @override
  String get max => 'maks';

  @override
  String get maxConcurrency => 'Maksimum Eşzamanlılık';

  @override
  String get maxRetryCount => 'Sunucu yeniden bağlantı sayısı';

  @override
  String get maxRetryCountEqual0 => 'Tekrar tekrar deneyecek.';

  @override
  String get min => 'min';

  @override
  String get mission => 'Görev';

  @override
  String get more => 'Daha fazla';

  @override
  String get moveOutServerFuncBtnsHelp =>
      'Açık: Sunucu Sekmesi sayfasındaki her kartın altında görüntülenebilir. Kapalı: Sunucu Ayrıntıları sayfasının üstünde görüntülenebilir.';

  @override
  String get ms => 'ms';

  @override
  String get needHomeDir =>
      'Synology kullanıcısıysanız, [buraya bakın](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Diğer sistem kullanıcılarının bir ana dizin oluşturma yöntemini araması gerekir.';

  @override
  String get needRestart => 'Uygulamanın yeniden başlatılması gerekiyor';

  @override
  String get net => 'Ağ';

  @override
  String get netViewType => 'Ağ görüntüleme türü';

  @override
  String get newContainer => 'Yeni konteyner';

  @override
  String get noConnectionStatsData => 'Bağlantı istatistik verisi yok';

  @override
  String get noLineChart => 'Çizgi grafikleri kullanma';

  @override
  String get noLineChartForCpu => 'CPU için çizgi grafikleri kullanma';

  @override
  String get noPrivateKeyTip =>
      'Özel anahtar mevcut değil, silinmiş olabilir veya yapılandırma hatası vardır.';

  @override
  String get noPromptAgain => 'Tekrar sorma';

  @override
  String get node => 'Düğüm';

  @override
  String get notAvailable => 'Kullanılamaz';

  @override
  String get onServerDetailPage => 'Sunucu ayrıntı sayfasında';

  @override
  String get onlyOneLine => 'Yalnızca tek satır olarak göster (kaydırılabilir)';

  @override
  String get onlyWhenCoreBiggerThan8 =>
      'Çekirdek sayısı 8\'den büyük olduğunda çalışır';

  @override
  String get openLastPath => 'Son yolu aç';

  @override
  String get openLastPathTip =>
      'Farklı sunucular farklı günlükler tutar ve günlük, çıkış yoludur';

  @override
  String get parseContainerStatsTip =>
      'Docker\'ın doluluk durumunu ayrıştırmak oldukça yavaş.';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$size\'ın $percent%\'i';
  }

  @override
  String get permission => 'İzinler';

  @override
  String get pingAvg => 'Ort:';

  @override
  String get pingInputIP => 'Lütfen bir hedef IP / alan adı girin.';

  @override
  String get pingNoServer =>
      'Ping yapılacak sunucu yok.\nLütfen sunucu sekmesinde bir sunucu ekleyin.';

  @override
  String get pkg => 'Paket';

  @override
  String get plugInType => 'Eklenti Türü';

  @override
  String get port => 'Port';

  @override
  String get preferDiskAmount => 'Disk kapasitesini öncelikli olarak göster';

  @override
  String get privateKey => 'Özel Anahtar';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Özel anahtar [$keyId] bulunamadı.';
  }

  @override
  String get process => 'İşlem';

  @override
  String get prune => 'Budamak';

  @override
  String get pushToken => 'Push belirteci';

  @override
  String get pveIgnoreCertTip =>
      'Etkinleştirilmesi önerilmez, güvenlik risklerine dikkat edin! PVE\'den varsayılan sertifikayı kullanıyorsanız, bu seçeneği etkinleştirmeniz gerekir.';

  @override
  String get pveLoginFailed =>
      'Giriş başarısız. Linux PAM girişi için sunucu yapılandırmasındaki kullanıcı adı/şifre ile kimlik doğrulama yapılamadı.';

  @override
  String get pveVersionLow =>
      'Bu özellik şu anda test aşamasında ve yalnızca PVE 8+ üzerinde test edildi. Lütfen dikkatli kullanın.';

  @override
  String get read => 'Oku';

  @override
  String get reboot => 'Yeniden başlat';

  @override
  String get recentConnections => 'Son Bağlantılar';

  @override
  String get rememberPwdInMem => 'Şifreyi bellekte hatırla';

  @override
  String get rememberPwdInMemTip =>
      'Konteynerler, askıya alma vb. için kullanılır.';

  @override
  String get rememberWindowSize => 'Pencere boyutunu hatırla';

  @override
  String get remotePath => 'Uzak yol';

  @override
  String get restart => 'Yeniden başlat';

  @override
  String get result => 'Sonuç';

  @override
  String get rotateAngel => 'Dönüş açısı';

  @override
  String get route => 'Yönlendirme';

  @override
  String get run => 'Çalıştır';

  @override
  String get running => 'Çalışıyor';

  @override
  String get sameIdServerExist => 'Aynı kimliğe sahip bir sunucu zaten mevcut';

  @override
  String get save => 'Kaydet';

  @override
  String get saved => 'Kaydedildi';

  @override
  String get second => 's';

  @override
  String get sensors => 'Sensör';

  @override
  String get sequence => 'Sıra';

  @override
  String get server => 'Sunucu';

  @override
  String get serverDetailOrder => 'Ayrıntı sayfası bileşen sırası';

  @override
  String get serverFuncBtns => 'Sunucu işlev düğmeleri';

  @override
  String get serverOrder => 'Sunucu sırası';

  @override
  String get serverTabRequired => 'Sunucu sekmesi kaldırılamaz';

  @override
  String get servers => 'sunucu';

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
  String get sftpShowFoldersFirst => 'Önce klasörleri göster';

  @override
  String get showDistLogo => 'Dağıtım logosunu göster';

  @override
  String get shutdown => 'Kapat';

  @override
  String get size => 'Boyut';

  @override
  String get snippet => 'Kod parçacığı';

  @override
  String get softWrap => 'Yumuşak kaydırma';

  @override
  String get specifyDev => 'Cihazı belirt';

  @override
  String get specifyDevTip =>
      'Örneğin, ağ trafiği istatistikleri varsayılan olarak tüm cihazlar içindir. Burada belirli bir cihaz belirtebilirsiniz.';

  @override
  String get speed => 'Hız';

  @override
  String spentTime(Object time) {
    return 'Harcanan süre: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Tüm sunucular zaten mevcut ($duplicateCount kopya bulundu)';
  }

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
  String get sshConfigImportHelp =>
      'Yalnızca temel bilgiler içe aktarılabilir, örneğin: IP/Port.';

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
  String sshTip(Object url) {
    return 'Bu işlev şu anda deneysel aşamada.\n\nLütfen hataları $url adresinde bildirin veya geliştirmemize katılın.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Sanal tuşların otomatik geçişi';

  @override
  String get start => 'Başlat';

  @override
  String get stat => 'İstatistik';

  @override
  String get stats => 'İstatistikler';

  @override
  String get stop => 'Durdur';

  @override
  String get stopped => 'Durduruldu';

  @override
  String get storage => 'Depolama';

  @override
  String get supportFmtArgs =>
      'Aşağıdaki biçimlendirme parametreleri desteklenir:';

  @override
  String get suspend => 'Askıya al';

  @override
  String get suspendTip =>
      'Askıya alma işlevi, root izni ve systemd desteği gerektirir.';

  @override
  String switchTo(Object val) {
    return '$val\'a geç';
  }

  @override
  String get syncTip =>
      'Bazı değişikliklerin etkili olması için yeniden başlatma gerekebilir.';

  @override
  String get system => 'Sistem';

  @override
  String get tag => 'Etiketler';

  @override
  String get tapToStartDiscovery =>
      'Ağınızdaki SSH sunucularını keşfetmek için arama düğmesine dokunun';

  @override
  String get temperature => 'Sıcaklık';

  @override
  String get termFontSizeTip =>
      'Bu ayar terminal boyutunu (genişlik ve yükseklik) etkiler. Terminal sayfasında yakınlaştırarak mevcut oturumun yazı tipi boyutunu ayarlayabilirsiniz.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Test';

  @override
  String get textScaler => 'Metin ölçekleyici';

  @override
  String get textScalerTip =>
      '1.0 => %100 (orijinal boyut), yalnızca sunucu sayfasındaki yazı tipinin bir kısmı üzerinde çalışır, değiştirilmesi önerilmez.';

  @override
  String get theme => 'Tema';

  @override
  String get time => 'Zaman';

  @override
  String get times => 'Kez';

  @override
  String get total => 'Toplam';

  @override
  String get totalAttempts => 'Toplam';

  @override
  String get traffic => 'Trafik';

  @override
  String get trySudo => 'Sudo ile dene';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Bilinmeyen';

  @override
  String get unkownConvertMode => 'Bilinmeyen dönüşüm modu';

  @override
  String get update => 'Güncelle';

  @override
  String get updateIntervalEqual0 =>
      '0 olarak ayarladınız, otomatik güncelleme yapılmayacak.\nCPU durumu hesaplanamaz.';

  @override
  String get updateServerStatusInterval => 'Sunucu durumu güncelleme aralığı';

  @override
  String get upsideDown => 'Başaşağı';

  @override
  String get uptime => 'Çalışma süresi';

  @override
  String get useCdn => 'CDN kullan';

  @override
  String get useCdnTip =>
      'Çinli olmayan kullanıcıların CDN kullanması önerilir. Kullanmak ister misiniz?';

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
  String get viewErr => 'Hatayı gör';

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
  String get menuSettings => 'Setting';

  @override
  String get menuQuit => 'Quit';

  @override
  String get menuNavigate => 'Navigate';

  @override
  String get menuInfo => 'Info';

  @override
  String get menuGitHubRepository => 'GitHub Repository';

  @override
  String get menuWiki => 'Wiki';

  @override
  String get menuHelp => 'Help';

  @override
  String get logs => 'Günlükler';
}
