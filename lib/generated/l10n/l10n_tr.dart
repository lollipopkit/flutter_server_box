import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get aboutThanks => 'Katılım gösteren aşağıdaki kişilere teşekkür ederiz.';

  @override
  String get acceptBeta => 'Beta sürüm güncellemelerini kabul et';

  @override
  String get addSystemPrivateKeyTip => 'Şu anda özel anahtar yok, sistemle geleni (~/.ssh/id_rsa) eklemek ister misiniz?';

  @override
  String get added2List => 'Görev listesine eklendi';

  @override
  String get addr => 'Adres';

  @override
  String get alreadyLastDir => 'Zaten son klasörde.';

  @override
  String get authFailTip => 'Kimlik doğrulama başarısız, kimlik bilgilerinin doğru olup olmadığını kontrol edin';

  @override
  String get autoBackupConflict => 'Aynı anda yalnızca bir otomatik yedekleme etkinleştirilebilir.';

  @override
  String get autoConnect => 'Otomatik bağlan';

  @override
  String get autoRun => 'Otomatik çalıştır';

  @override
  String get autoUpdateHomeWidget => 'Ana widget\'ı otomatik güncelle';

  @override
  String get backupTip => 'Dışa aktarılan veriler zayıf bir şekilde şifrelenmiştir. \nLütfen güvenli bir yerde saklayın.';

  @override
  String get backupVersionNotMatch => 'Yedekleme sürümü uyumlu değil.';

  @override
  String get battery => 'Pil';

  @override
  String get bgRun => 'Arka planda çalıştır';

  @override
  String get bgRunTip => 'Bu anahtar yalnızca programın arka planda çalışmayı deneyeceğini ifade eder. Arka planda çalışıp çalışamayacağı, iznin etkinleştirilip etkinleştirilmediğine bağlıdır. AOSP tabanlı Android ROM\'larda, bu uygulamada \"Pil Optimizasyonunu\" devre dışı bırakın. MIUI / HyperOS için, güç tasarrufu politikasını \"Sınırsız\" olarak değiştirin.';

  @override
  String get closeAfterSave => 'Kaydet ve kapat';

  @override
  String get cmd => 'Komut';

  @override
  String get collapseUITip => 'UI\'daki uzun listeleri varsayılan olarak gizleyip gizlememeyi belirler';

  @override
  String get conn => 'Bağlantı';

  @override
  String get container => 'Konteyner';

  @override
  String get containerTrySudoTip => 'Örneğin: Uygulamada kullanıcı aaa olarak ayarlanmış, ancak Docker root kullanıcısı altında kurulmuş. Bu durumda, bu seçeneği etkinleştirmeniz gerekir.';

  @override
  String get convert => 'Dönüştür';

  @override
  String get copyPath => 'Yolu kopyala';

  @override
  String get cpuViewAsProgressTip => 'Her CPU\'nun kullanımını bir ilerleme çubuğu tarzında görüntüle (eski tarz)';

  @override
  String get cursorType => 'İmleç türü';

  @override
  String get customCmd => 'Özel komutlar';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Komut Adı\": \"Komut\"';

  @override
  String get decode => 'Çöz';

  @override
  String get decompress => 'Sıkıştırmayı aç';

  @override
  String get deleteServers => 'Toplu sunucu silme';

  @override
  String get dirEmpty => 'Klasörün boş olduğundan emin olun.';

  @override
  String get disconnected => 'Bağlantı kesildi';

  @override
  String get disk => 'Disk';

  @override
  String get diskIgnorePath => 'Disk için göz ardı edilen yol';

  @override
  String get displayCpuIndex => 'CPU dizinini görüntüle';

  @override
  String dl2Local(Object fileName) {
    return '$fileName dosyasını yerel olarak indirmek istiyor musunuz?';
  }

  @override
  String get dockerEmptyRunningItems => 'Çalışan konteyner yok.\nBu şu sebeplerden kaynaklanabilir:\n- Docker kurulumu kullanıcı adı, uygulamada yapılandırılan kullanıcı adıyla aynı değil.\n- DOCKER_HOST ortam değişkeni doğru okunmadı. Terminalde `echo \$DOCKER_HOST` komutunu çalıştırarak elde edebilirsiniz.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count görüntü';
  }

  @override
  String get dockerNotInstalled => 'Docker kurulu değil';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount çalışıyor, $stoppedCount konteyner durduruldu.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count konteyner çalışıyor.';
  }

  @override
  String get doubleColumnMode => 'Çift sütun modu';

  @override
  String get doubleColumnTip => 'Bu seçenek yalnızca özelliği etkinleştirir, gerçekten etkinleştirilebilir olup olmadığını cihazın genişliği belirler';

  @override
  String get editVirtKeys => 'Sanal tuşları düzenle';

  @override
  String get editor => 'Editör';

  @override
  String get editorHighlightTip => 'Mevcut kod vurgulama performansı ideal değil ve isteğe bağlı olarak kapatılabilir.';

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
  String get fdroidReleaseTip => 'Bu uygulamayı F-Droid\'den indirdiyseniz, bu seçeneği kapatmanız önerilir.';

  @override
  String get fgService => 'Ön plan hizmeti';

  @override
  String get fgServiceTip => 'Etkinleştirdikten sonra, bazı cihaz modellerinde çökme olabilir. Devre dışı bırakmak, bazı modellerin SSH bağlantılarını arka planda sürdürememesine neden olabilir. Lütfen sistem ayarlarında ServerBox bildirim izinlerine, arka planda çalışmaya ve kendiliğinden uyanmaya izin verin.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return '\'$file\' dosyası çok büyük $size, maksimum $sizeMax';
  }

  @override
  String get followSystem => 'Sistemi takip et';

  @override
  String get font => 'Yazı tipi';

  @override
  String get fontSize => 'Yazı tipi boyutu';

  @override
  String get force => 'Zorla';

  @override
  String get fullScreen => 'Tam ekran modu';

  @override
  String get fullScreenJitter => 'Tam ekran titremesi';

  @override
  String get fullScreenJitterHelp => 'Ekran yanıklarını önlemek için';

  @override
  String get fullScreenTip => 'Cihaz yatay moda döndürüldüğünde tam ekran modu etkinleştirilsin mi? Bu seçenek yalnızca sunucu sekmesi için geçerlidir.';

  @override
  String get goBackQ => 'Geri dön?';

  @override
  String get goto => 'Git';

  @override
  String get hideTitleBar => 'Başlık çubuğunu gizle';

  @override
  String get highlight => 'Kod vurgulama';

  @override
  String get homeWidgetUrlConfig => 'Ana sayfa widget URL\'sini yapılandır';

  @override
  String get host => 'Sunucu';

  @override
  String httpFailedWithCode(Object code) {
    return 'İstek başarısız oldu, durum kodu: $code';
  }

  @override
  String get ignoreCert => 'Sertifikayı yoksay';

  @override
  String get image => 'Resim';

  @override
  String get imagesList => 'Resim listesi';

  @override
  String get init => 'Başlat';

  @override
  String get inner => 'İç';

  @override
  String get install => 'Kur';

  @override
  String get installDockerWithUrl => 'Lütfen önce Docker\'ı https://docs.docker.com/engine/install adresinden kurun.';

  @override
  String get invalid => 'Geçersiz';

  @override
  String get jumpServer => 'Atlama sunucusu';

  @override
  String get keepForeground => 'Uygulama ön planda kalsın!';

  @override
  String get keepStatusWhenErr => 'Son sunucu durumunu koru';

  @override
  String get keepStatusWhenErrTip => 'Yalnızca betik yürütme sırasında bir hata oluştuğunda';

  @override
  String get keyAuth => 'Anahtar Doğrulama';

  @override
  String get letterCache => 'Harf önbelleği';

  @override
  String get letterCacheTip => 'Devre dışı bırakılması önerilir, ancak devre dışı bırakıldıktan sonra CJK karakterleri girilemez.';

  @override
  String get license => 'Lisans';

  @override
  String get location => 'Konum';

  @override
  String get loss => 'kayıp';

  @override
  String madeWithLove(Object myGithub) {
    return '$myGithub tarafından ❤️ ile yapıldı';
  }

  @override
  String get manual => 'Kılavuz';

  @override
  String get max => 'maks';

  @override
  String get maxRetryCount => 'Sunucu yeniden bağlanma sayısı';

  @override
  String get maxRetryCountEqual0 => 'Sürekli olarak tekrar denenecek.';

  @override
  String get min => 'min';

  @override
  String get mission => 'Görev';

  @override
  String get more => 'Daha fazla';

  @override
  String get moveOutServerFuncBtnsHelp => 'Açık: Sunucu sekmesi sayfasındaki her kartın altında görüntülenebilir. Kapalı: Sunucu Detayları sayfasının üst kısmında görüntülenebilir.';

  @override
  String get ms => 'ms';

  @override
  String get needHomeDir => 'Synology kullanıcısıysanız, [buraya bakın](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Diğer sistem kullanıcılarının bir ana dizin oluşturmayı öğrenmeleri gerekir.';

  @override
  String get needRestart => 'Uygulamanın yeniden başlatılması gerekiyor';

  @override
  String get net => 'Ağ';

  @override
  String get netViewType => 'Ağ görünümü türü';

  @override
  String get newContainer => 'Yeni konteyner';

  @override
  String get noLineChart => 'Çizgi grafik kullanma';

  @override
  String get noLineChartForCpu => 'CPU için çizgi grafik kullanma';

  @override
  String get noPrivateKeyTip => 'Özel anahtar mevcut değil, silinmiş olabilir veya bir yapılandırma hatası vardır.';

  @override
  String get noPromptAgain => 'Tekrar hatırlatma';

  @override
  String get node => 'Düğüm';

  @override
  String get notAvailable => 'Kullanılamaz';

  @override
  String get onServerDetailPage => 'Sunucu detay sayfasında';

  @override
  String get onlyOneLine => 'Yalnızca bir satır olarak göster (kaydırılabilir)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Yalnızca çekirdek sayısı 8\'den fazla olduğunda çalışır';

  @override
  String get openLastPath => 'Son yolu aç';

  @override
  String get openLastPathTip => 'Farklı sunucuların farklı günlükleri olacaktır ve çıkış yolu log dosyasıdır';

  @override
  String get parseContainerStatsTip => 'Docker\'ın işgal durumunu analiz etmek nispeten yavaştır.';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$size\'nin %$percent\'i';
  }

  @override
  String get permission => 'İzinler';

  @override
  String get pingAvg => 'Ortalama:';

  @override
  String get pingInputIP => 'Lütfen bir hedef IP / etki alanı girin.';

  @override
  String get pingNoServer => 'Ping yapılacak sunucu yok.\nLütfen sunucu sekmesine bir sunucu ekleyin.';

  @override
  String get pkg => 'Paket';

  @override
  String get plugInType => 'Takma Türü';

  @override
  String get port => 'Port';

  @override
  String get preview => 'Önizleme';

  @override
  String get privateKey => 'Özel Anahtar';

  @override
  String get process => 'Süreç';

  @override
  String get pushToken => 'Push token';

  @override
  String get pveIgnoreCertTip => 'Etkinleştirilmesi önerilmez, güvenlik risklerine dikkat edin! PVE\'nin varsayılan sertifikasını kullanıyorsanız, bu seçeneği etkinleştirmeniz gerekir.';

  @override
  String get pveLoginFailed => 'Giriş başarısız. Linux PAM girişi için sunucu yapılandırmasındaki kullanıcı adı/şifre ile kimlik doğrulaması yapılamadı.';

  @override
  String get pveVersionLow => 'Bu özellik şu anda test aşamasında ve sadece PVE 8+ üzerinde test edilmiştir. Lütfen dikkatli kullanın.';

  @override
  String get pwd => 'Şifre';

  @override
  String get read => 'Oku';

  @override
  String get reboot => 'Yeniden başlat';

  @override
  String get rememberPwdInMem => 'Şifreyi bellekte sakla';

  @override
  String get rememberPwdInMemTip => 'Konteynerler, askıya alma vb. için kullanılır.';

  @override
  String get rememberWindowSize => 'Pencere boyutunu hatırla';

  @override
  String get remotePath => 'Uzak yol';

  @override
  String get restart => 'Yeniden başlat';

  @override
  String get result => 'Sonuç';

  @override
  String get rotateAngel => 'Dönme açısı';

  @override
  String get route => 'Yönlendirme';

  @override
  String get run => 'Çalıştır';

  @override
  String get running => 'Çalışıyor';

  @override
  String get sameIdServerExist => 'Aynı kimliğe sahip bir sunucu zaten var';

  @override
  String get save => 'Kaydet';

  @override
  String get saved => 'Kaydedildi';

  @override
  String get second => 's';

  @override
  String get sensors => 'Sensör';

  @override
  String get sequence => 'Dizi';

  @override
  String get server => 'Sunucu';

  @override
  String get serverDetailOrder => 'Ayrıntı sayfası widget sırası';

  @override
  String get serverFuncBtns => 'Sunucu işlev düğmeleri';

  @override
  String get serverOrder => 'Sunucu sırası';

  @override
  String get sftpDlPrepare => 'Bağlantı hazırlığı yapılıyor...';

  @override
  String get sftpEditorTip => 'Boşsa, uygulamanın yerleşik dosya düzenleyicisini kullanın. Bir değer varsa, uzak sunucunun düzenleyicisini kullanın, örneğin, `vim` (otomatik olarak `EDITOR`\'a göre algılamanız önerilir).';

  @override
  String get sftpRmrDirSummary => 'SFTP\'de bir klasörü silmek için `rm -r` kullanın.';

  @override
  String get sftpSSHConnected => 'SFTP Bağlantısı';

  @override
  String get sftpShowFoldersFirst => 'Önce klasörleri göster';

  @override
  String get showDistLogo => 'Dağıtım logosunu göster';

  @override
  String get shutdown => 'Kapat';

  @override
  String get size => 'Boyut';

  @override
  String get snippet => 'Parça';

  @override
  String get softWrap => 'Yumuşak kaydırma';

  @override
  String get specifyDev => 'Cihazı belirle';

  @override
  String get specifyDevTip => 'Örneğin, ağ trafiği istatistikleri varsayılan olarak tüm cihazlar içindir. Burada belirli bir cihazı belirtebilirsiniz.';

  @override
  String get speed => 'Hız';

  @override
  String spentTime(Object time) {
    return 'Harcanan zaman: $time';
  }

  @override
  String get sshTermHelp => 'Terminal kaydırılabilir olduğunda, yatay sürükleme metni seçebilir. Klavye düğmesine tıklamak klavyeyi açar/kapatır. Dosya simgesi mevcut yolu SFTP\'de açar. Pano düğmesi metin seçildiğinde içeriği kopyalar ve metin seçilmediğinde ve panoda içerik olduğunda panodaki içeriği terminale yapıştırır. Kod simgesi kod parçacıklarını terminale yapıştırır ve çalıştırır.';

  @override
  String sshTip(Object url) {
    return 'Bu işlev şu anda deneme aşamasındadır.\n\nLütfen hataları $url adresine bildirin veya geliştirmemize katılın.';
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
  String get supportFmtArgs => 'Aşağıdaki biçimlendirme parametreleri desteklenir:';

  @override
  String get suspend => 'Askıya al';

  @override
  String get suspendTip => 'Askıya alma işlevi kök izinleri ve systemd desteği gerektirir.';

  @override
  String switchTo(Object val) {
    return '$val öğesine geç';
  }

  @override
  String get sync => 'Senkronize et';

  @override
  String get syncTip => 'Bazı değişikliklerin etkili olması için yeniden başlatma gerekebilir.';

  @override
  String get system => 'Sistem';

  @override
  String get tag => 'Etiketler';

  @override
  String get temperature => 'Sıcaklık';

  @override
  String get termFontSizeTip => 'Bu ayar terminal boyutunu (genişlik ve yükseklik) etkileyecektir. Terminal sayfasında yakınlaştırarak mevcut oturumun yazı tipi boyutunu ayarlayabilirsiniz.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Test';

  @override
  String get textScaler => 'Metin ölçekleyici';

  @override
  String get textScalerTip => '1.0 => %100 (orijinal boyut), yalnızca sunucu sayfası kısmındaki yazı tipine çalışır, değiştirilmesi önerilmez.';

  @override
  String get theme => 'Tema';

  @override
  String get time => 'Zaman';

  @override
  String get times => 'Zamanlar';

  @override
  String get total => 'Toplam';

  @override
  String get traffic => 'Trafik';

  @override
  String get trySudo => 'Sudo kullanmayı deneyin';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Bilinmeyen';

  @override
  String get unkownConvertMode => 'Bilinmeyen dönüştürme modu';

  @override
  String get update => 'Güncelle';

  @override
  String get updateIntervalEqual0 => '0 olarak ayarladınız, otomatik olarak güncellenmeyecek.\nCPU durumunu hesaplayamıyor.';

  @override
  String get updateServerStatusInterval => 'Sunucu durumu güncelleme aralığı';

  @override
  String get upload => 'Yükle';

  @override
  String get upsideDown => 'Ters';

  @override
  String get uptime => 'Çalışma süresi';

  @override
  String get useCdn => 'CDN kullanılıyor';

  @override
  String get useCdnTip => 'Çin dışındaki kullanıcıların CDN kullanması önerilir. Kullanmak ister misiniz?';

  @override
  String get useNoPwd => 'Şifre kullanılmayacak';

  @override
  String get usePodmanByDefault => 'Varsayılan olarak Podman kullan';

  @override
  String get used => 'Kullanıldı';

  @override
  String get view => 'Görünüm';

  @override
  String get viewErr => 'Hataya bakın';

  @override
  String get virtKeyHelpClipboard => 'Seçilen terminal boş değilse panoya kopyalayın, aksi takdirde panodaki içeriği terminale yapıştırın.';

  @override
  String get virtKeyHelpIME => 'Klavye aç/kapat';

  @override
  String get virtKeyHelpSFTP => 'Geçerli dizini SFTP\'de açın.';

  @override
  String get waitConnection => 'Lütfen bağlantının kurulmasını bekleyin.';

  @override
  String get wakeLock => 'Uyanık tut';

  @override
  String get watchNotPaired => 'Eşlenmiş Apple Watch yok';

  @override
  String get webdavSettingEmpty => 'WebDav ayarı boş';

  @override
  String get whenOpenApp => 'Uygulamayı açarken';

  @override
  String get wolTip => 'WOL (Wake-on-LAN) yapılandırıldıktan sonra, her sunucuya bağlandığınızda bir WOL isteği gönderilir.';

  @override
  String get write => 'Yaz';

  @override
  String get writeScriptFailTip => 'Komut dosyasına yazma başarısız oldu, muhtemelen izin eksikliğinden veya dizin mevcut olmadığından kaynaklanıyor olabilir.';

  @override
  String get writeScriptTip => 'Sunucuya bağlandıktan sonra, sistem durumunu izlemek için ~/.config/server_box\'a bir komut dosyası yazılacaktır. Komut dosyası içeriğini inceleyebilirsiniz.';
}
