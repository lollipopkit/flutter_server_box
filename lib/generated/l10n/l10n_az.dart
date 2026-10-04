// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Azerbaijani (`az`).
class AppLocalizationsAz extends AppLocalizations {
  AppLocalizationsAz([String locale = 'az']) : super(locale);

  @override
  String get crashCollect => 'Diaqnostika məlumatları';

  @override
  String get crashCollectIntro =>
      'ServerBox problemləri aradan qaldırmaq üçün işləyərkən baş verənləri qeydə alır. Göndəriləcək məlumatın həcmini seç.';

  @override
  String get crashCollectNone => 'Heç nə';

  @override
  String get crashCollectNoneTip =>
      'Hesabatlar bu cihazda qalır; qəza baş verdikdən sonra hesabatı əl ilə göndərə bilərsən.';

  @override
  String get crashCollectBasic => 'Əsas məlumatlar';

  @override
  String get crashCollectBasicTip =>
      'Yalnız qəza məlumatları daxil edilir; jurnallar və məhsuldarlıq məlumatları daxil edilmir. **Bu, tətbiqi təkmilləşdirməyimizə və xətaları düzəltməyimizə kömək edir.**';

  @override
  String get crashCollectFull => 'Tam məlumatlar';

  @override
  String get crashCollectFullTip =>
      'Qəza jurnalı ilə yanaşı məhsuldarlıq məlumatları və hansı funksiyaların istifadə olunduğu da daxil edilir: **bunlar nəyin yavaş işlədiyini və hansı funksiyaları saxlamağa dəyər olduğunu göstərir.**';

  @override
  String get crashCollectFooter =>
      'Bütün səviyyələrdə məlum server adları, ünvanlar və istifadəçi adları qeydə alınarkən yer tutucularla əvəz olunur. Məlumat toplama səviyyəsini daha sonra parametrlərdə dəyişə bilərsən.';

  @override
  String get privacy => 'Məxfilik';

  @override
  String get privacyPolicy => 'Məxfilik siyasəti';

  @override
  String get crashLastRunFailed =>
      'ServerBox son dəfə işləyərkən gözlənilmədən bağlandı.';

  @override
  String get crashReportTitle => 'Qəza hesabatı';

  @override
  String get crashReportHint =>
      'Bu, əvvəlki işə salınmanın jurnalıdır. Məlum server adları və ünvanları yer tutucularla əvəz olunub, lakin başqa təfərrüatlar qala bilər. Göndərməzdən əvvəl diqqətlə oxu.';

  @override
  String get crashReportSubmit => 'Kopyala və bildir';

  @override
  String get preReleaseUpdates => 'Önizləmə versiyası yeniləmələrini qəbul et';

  @override
  String get addSystemPrivateKeyTip =>
      'Hazırda məxfi açar yoxdur. Sistemdəki açarı (~/.ssh/id_rsa) əlavə etmək istəyirsən?';

  @override
  String get added2List => 'Tapşırıq siyahısına əlavə edildi';

  @override
  String get askAi => 'AI-dan soruş';

  @override
  String get askAiInsertTerminal => 'Terminala daxil et';

  @override
  String get remoteDesktop => 'Uzaq masaüstü';

  @override
  String get askAiRiskReadOnly => 'Yalnız oxuma';

  @override
  String get askAiRiskCaution => 'Sistemi dəyişir';

  @override
  String get askAiRiskUnvetted => 'Yoxlanılmamış host';

  @override
  String get askAiRiskDestructive => 'Yüksək risk';

  @override
  String get askAiAutoRunSafeCommands =>
      'Yalnız oxuma əmrlərini avtomatik icra et';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Yalnız həm model, həm də yerli yoxlama əmri yalnız oxuma kimi qiymətləndirdikdə icra olunur';

  @override
  String get askAiHistory => 'Söhbət tarixçəsi';

  @override
  String get askAiNewConversation => 'Yeni söhbət';

  @override
  String get askAiUntitledConversation => 'Adsız';

  @override
  String get askAiRenameConversation => 'Söhbətin adını dəyiş';

  @override
  String get askAiDeleteConversationTitle => 'Bu söhbət silinsin?';

  @override
  String get askAiDeleteConversationTip =>
      'Söhbəti bu cihazdan silir. Geri qaytarmaq mümkün deyil.';

  @override
  String get agentNoHistory => 'Yadda saxlanmış ümumi agent söhbəti yoxdur';

  @override
  String get agentClearHistoryTitle => 'Ümumi agent tarixçəsi təmizlənsin?';

  @override
  String get agentClearHistoryTip =>
      'Bütün ümumi agent söhbətləri bu cihazdan silinəcək.';

  @override
  String get agentToolShell => 'Əmr örtüyü';

  @override
  String get agentToolReadFile => 'Faylı oxu';

  @override
  String get agentToolWriteFile => 'Fayla yaz';

  @override
  String get floatOverTabs => 'Digər vərəqlərin üzərində göstər';

  @override
  String get agentToolSshConnect => 'SSH ilə əlaqə qur';

  @override
  String get agentToolSshDisconnect => 'SSH əlaqəsini kəs';

  @override
  String get agentSshConnectTitle => 'Yeni hostla əlaqə qur';

  @override
  String get agentAuthMethod => 'Autentifikasiya';

  @override
  String get agentSshConnectTip =>
      'Agent SSH əlaqəsi yaratmaq istəyir. Parolu burada daxil et';

  @override
  String get agentAdHocSessions => 'Müvəqqəti əlaqələr';

  @override
  String get agentSaveServerTitle => 'Server kimi yadda saxla';

  @override
  String get agentSaveServerTip =>
      'Bu host və daxil etdiyin parol bu cihazda yadda saxlanılır';

  @override
  String get agentMonitorOptional => 'Monitorinq agenti (istəyə bağlı)';

  @override
  String get authFailTip => 'Autentifikasiya uğursuz oldu. Məlumatları yoxla';

  @override
  String get autoBackupConflict =>
      'Eyni vaxtda yalnız bir avtomatik ehtiyat nüsxə funksiyası aktivləşdirilə bilər.';

  @override
  String get autoConnect => 'Avtomatik əlaqə qur';

  @override
  String get autoRun => 'Avtomatik icra et';

  @override
  String get autoUpdateHomeWidget =>
      'Ana ekran vidcetinin avtomatik yenilənməsi';

  @override
  String get availableTabs => 'Mövcud vərəqlər';

  @override
  String get backupEncrypted => 'Ehtiyat nüsxə şifrələnib';

  @override
  String get backupNotEncrypted => 'Ehtiyat nüsxə şifrələnməyib';

  @override
  String get backupPassword => 'Ehtiyat nüsxə parolu';

  @override
  String get backupPasswordRemoved => 'Ehtiyat nüsxə parolu silindi';

  @override
  String get backupPasswordSet => 'Ehtiyat nüsxə parolu təyin edildi';

  @override
  String get backupPasswordTip =>
      'Ehtiyat nüsxə fayllarını şifrələmək üçün parol təyin et. Şifrələməni söndürmək üçün boş saxla.';

  @override
  String get backupPasswordWrong => 'Ehtiyat nüsxə parolu yanlışdır';

  @override
  String get connectAll => 'Hamısı ilə əlaqə qur';

  @override
  String get disconnectAll => 'Bütün əlaqələri kəs';

  @override
  String get distIcon => 'Distributiv nişanları';

  @override
  String get distIconIntroLegal =>
      'Nişan yalnız bu cihazın uzaq sistemdən oxuduğu məlumatı göstərir. Bu məlumat yanlış və ya köhnəlmiş ola bilər, törəmə sistemi, yenidən yığılmış buraxılışı və ya konkret versiyanı müəyyən etmir. Sistem müəyyən edilə bilmədikdə sadə işarə göstərilir.\n\nHər nişan müvafiq sahibinin əmtəə nişanıdır və yalnız təmsil etdiyi sistemə istinad etmək üçün istifadə olunur.';

  @override
  String get distIconTip =>
      'Hər serverin yanında işlətdiyi güman edilən sistemin kiçik nişanını göstər.';

  @override
  String get distNameMap => 'Ad əvəzləmələri';

  @override
  String get distNameMapTip =>
      'Yalnız nişanları yerləşdirdiyin yerdə faylının adı fərqli olan distributiv üçündür. Açar bu tətbiqin istifadə etdiyi addır; dəyər isə alınacaq addır. Nişan çatışmırsa doldur, əks halda boş saxla.';

  @override
  String get logoUrl => 'Loqonun URL ünvanı';

  @override
  String get logoUrlTip =>
      'Serverin öz səhifəsinin yuxarısında öz rəngləri ilə göstərilən böyük şəkil.';

  @override
  String get globe => 'Qlobus';

  @override
  String get locationTip =>
      'Bu serverin qlobusda göstərildiyi yer. Əvvəlcə enlik, sonra uzunluq, dərəcə ilə. Məsələn, 39.9042, 116.4074.';

  @override
  String get markUrl => 'Nişanın URL ünvanı';

  @override
  String get markUrlTip =>
      'Siyahılarda server adının yanındakı kiçik nişan. Boş olduqda nişan göstərilmir.\n\nLoqo ilə eyni şəkil deyil';

  @override
  String get navTabMenuTip =>
      'Vərəqdəki hər şeylə birdəfəyə əlaqə qurmaq və ya əlaqəni kəsmək üçün vərəqi basıb saxla və ya sağ kliklə.';

  @override
  String nTags(int count) {
    return '$count etiket';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Uzaq ehtiyat nüsxələr üçün boş olmayan ehtiyat nüsxə parolu tələb olunur';

  @override
  String get monitorHttpsRequired =>
      'HTTP istifadəsinə icazə verilməyibsə, uzaq monitorinq agenti üçün HTTPS tələb olunur.';

  @override
  String get monitorAllowInsecureHttp => 'HTTP istifadəsinə icazə ver';

  @override
  String get plainHttpTitle => 'Bu agent şifrələnməmiş HTTP üzərindən verilir';

  @override
  String get plainHttpTip =>
      'Parol və bu tətbiqin istədiyi hər şey şifrələnmədən ötürüləcək. Hələ heç nə göndərilməyib.';

  @override
  String get allowForThisServer => 'Bu server üçün icazə ver';

  @override
  String get viewError => 'Xətaya bax';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Yalnız Tailscale kimi ötürülməni özü şifrələyən etibarlı özəl şəbəkədə';

  @override
  String monitorHttpTip(String url) {
    return 'SSH üzərindən əmrlər icra etmək əvəzinə bu serverin statusunu **monitor** agentinin HTTP API interfeysindən oxu.\n\nƏvvəlcə agent serverdə quraşdırılmalıdır. Dəyişmə qrafikləri, saat tətbiqi və ana ekran vidcetləri bu agent sayəsində işləyir.\n\n[Monitorinq agentinin quraşdırılması]($url)';
  }

  @override
  String get backupTip =>
      'İxrac edilən məlumatlar parolla şifrələnə bilər. \nOnları təhlükəsiz yerdə saxla.';

  @override
  String get icloudBackupStatusTitle => 'Ehtiyat nüsxənin statusu';

  @override
  String get icloudBackupStatusLoading =>
      'iCloud ehtiyat nüsxəsinin statusu yüklənir...';

  @override
  String get icloudBackupStatusError =>
      'iCloud ehtiyat nüsxəsinin metaməlumatlarını oxumaq mümkün olmadı';

  @override
  String get icloudBackupStatusEmpty =>
      'Hələ iCloud ehtiyat nüsxə faylı tapılmayıb';

  @override
  String get icloudBackupStateUploading => 'Göndərilir';

  @override
  String get icloudBackupStateConflict => 'Ziddiyyət aşkarlandı';

  @override
  String get icloudBackupStateUploaded => 'Göndərildi';

  @override
  String get icloudBackupStateWaiting => 'iCloud gözlənilir';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return 'Son ehtiyat nüsxə: $lastModified\nVəziyyət: $remoteState';
  }

  @override
  String get bgRun => 'Arxa planda işlət';

  @override
  String get bgRunTip =>
      'Bu keçid yalnız proqramın arxa planda işləməyə cəhd edəcəyini bildirir. Arxa planda işləyə bilməsi müvafiq icazənin aktiv olub-olmamasından asılıdır. AOSP əsaslı Android ROM sistemlərində bu tətbiq üçün \"Batareya optimallaşdırması\" funksiyasını söndür. MIUI / HyperOS üçün enerjiyə qənaət siyasətini \"Məhdudiyyətsiz\" olaraq dəyiş.';

  @override
  String get trayReadings => 'Göstəricilər';

  @override
  String get trayChart => 'Qrafik';

  @override
  String get trayChartNone => 'Yoxdur';

  @override
  String get trayCompact => 'Yığcam sətirlər';

  @override
  String get trayCompactTip =>
      'Hər server üçün bir sətir, qrafiksiz. Linux həmişə birsətirli düzülüşdən istifadə edir, çünki onun panel menyusu xüsusi düzülüş deyil, mətn etiketi ötürən D-Bus vasitəsilə göndərilir; seçilmiş qrafik yenə də şəkil kimi daxil edilə bilər.';

  @override
  String get trayKeepRunning => 'Sistem panelində işləməyə davam et';

  @override
  String get trayKeepRunningTip =>
      'Pəncərəni bağladıqda tətbiq menyu sətrində və ya bildiriş sahəsində qalaraq serverlərini izləməyə davam edir. Bağlama düyməsinin tətbiqi sonlandırması üçün bunu söndür.';

  @override
  String get bgRunNeedsNotification =>
      'Arxa planda işləmək üçün daimi bildiriş lazımdır, lakin tətbiqin bildiriş icazəsi yoxdur. Bildirişlərə icazə vermək üçün toxun.';

  @override
  String get clearAllStatsContent =>
      'Bütün server əlaqə statistikasını təmizləmək istədiyinə əminsən? Bu əməliyyatı geri qaytarmaq mümkün deyil.';

  @override
  String get clearAllStatsTitle => 'Bütün statistikanı təmizlə';

  @override
  String clearServerStatsContent(String serverName) {
    return '\"$serverName\" serverinin əlaqə statistikasını təmizləmək istədiyinə əminsən? Bu əməliyyatı geri qaytarmaq mümkün deyil.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return '$serverName statistikasını təmizlə';
  }

  @override
  String get clearThisServerStats => 'Bu serverin statistikasını təmizlə';

  @override
  String get closeAfterSave => 'Yadda saxla və bağla';

  @override
  String get collapseUITip =>
      'İnterfeysdəki uzun siyahıların standart olaraq yığılması';

  @override
  String get connectionDetails => 'Əlaqə təfərrüatları';

  @override
  String get connectionStats => 'Əlaqə statistikası';

  @override
  String get connectionStatsDesc =>
      'Server əlaqələrinin uğur göstəricisinə və tarixçəsinə bax';

  @override
  String get containerTrySudoTip =>
      'Məsələn: tətbiqdə istifadəçi aaa kimi təyin edilib, lakin Docker root istifadəçisi altında quraşdırılıb. Bu halda bu seçimi aktivləşdirməlisən.';

  @override
  String get containerSudoPasswordRequired =>
      'Docker istifadəsi üçün sudo parolu tələb olunur. Parolunu daxil et.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Sudo parolu yanlışdır və ya istifadəsinə icazə verilmir. Yenidən cəhd et.';

  @override
  String get copyPath => 'Yolu kopyala';

  @override
  String get customCmd => 'Fərdi əmrlər';

  @override
  String get deleteServers => 'Serverləri toplu şəkildə sil';

  @override
  String get deleteDirRecursive => 'Qovluğu və içindəkilərin hamısını sil';

  @override
  String get dirEmpty => 'Qovluğun boş olduğuna əmin ol.';

  @override
  String get discoverSshServers => 'SSH serverlərini aşkar et';

  @override
  String get discoveryFailed => 'Aşkarlama uğursuz oldu';

  @override
  String get discoverySettings => 'Aşkarlama parametrləri';

  @override
  String get distro => 'Distributiv';

  @override
  String get diskHealth => 'Diskin sağlamlığı';

  @override
  String dl2Local(String fileName) {
    return '$fileName bu cihaza endirilsin?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'İşləyən konteyner yoxdur.\nBunun səbəbi aşağıdakılar ola bilər:\n- Docker quraşdıran istifadəçi tətbiqdə təyin edilmiş istifadəçi adı ilə eyni deyil.\n- DOCKER_HOST mühit dəyişəni düzgün oxunmayıb. Onu terminalda `echo \$DOCKER_HOST` əmrini icra edərək əldə edə bilərsən.';

  @override
  String get dockerProjectOther => 'Digər';

  @override
  String get dockerPruneTip =>
      'Diskdə yer boşaltmaq üçün istifadə olunmayan məlumatları sil';

  @override
  String get dockerStatistics => 'Docker statistikası';

  @override
  String get editVirtKeys => 'Virtual düymələr';

  @override
  String get editorHighlightTip =>
      'Hazırda kodun rənglənməsi ideal sürətlə işləmir. Məhsuldarlığı artırmaq üçün onu söndürmək olar.';

  @override
  String get enableMdns => 'mDNS aktivləşdir';

  @override
  String get enableMdnsDesc =>
      'SSH xidmətlərini aşkar etmək üçün mDNS/Bonjour istifadə et';

  @override
  String get envVars => 'Mühit dəyişəni';

  @override
  String get extraArgs => 'Əlavə arqumentlər';

  @override
  String get fallbackSshDest => 'Ehtiyat SSH təyinatı';

  @override
  String get fdroidReleaseTip =>
      'Bu tətbiqi F-Droid vasitəsilə endirmisənsə, bu seçimi söndürmək tövsiyə olunur.';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return '\'$file\' faylı çox böyükdür: $size, maksimum $sizeMax';
  }

  @override
  String get fileDirGone => 'Bu qovluq artıq burada yoxdur';

  @override
  String get fileDirGoneTip => 'Silinib və ya adı dəyişdirilib';

  @override
  String get fullScreen => 'Tam ekran';

  @override
  String get fullScreenJitter => 'Tam ekranda kiçik yerdəyişmələr';

  @override
  String get fullScreenJitterHelp =>
      'Ekranda qalıcı iz yaranmasının qarşısını almaq üçün';

  @override
  String get fullScreenTip =>
      'Cihaz üfüqi vəziyyətə çevrildikdə tam ekran rejimi aktivləşdirilsin? Bu seçim yalnız server vərəqinə aiddir.';

  @override
  String get githubGistIdOptional => 'Gist ID (istəyə bağlı)';

  @override
  String get githubGistToken => 'GitHub Gist tokeni';

  @override
  String get githubGistTokenEmpty => 'Token boşdur';

  @override
  String get goto => 'Keç';

  @override
  String get homeTabs => 'Ana səhifə vərəqləri';

  @override
  String get homeTabsCustomizeDesc =>
      'Ana səhifədə görünən vərəqləri və onların sırasını fərdiləşdir';

  @override
  String get ignoreCert => 'Sertifikatı nəzərə alma';

  @override
  String get image => 'Obraz';

  @override
  String get macDmgBody =>
      'App Store bu tətbiqin təcrid olunmuş mühitdə işləməsini tələb edir və belə mühit terminal aça bilmir. DMG buraxılışı bunu edə bilir.\n\nApp Store buraxılışının yenilənməsi dayandırıla bilər.';

  @override
  String get macDmgImportDenied =>
      'macOS əvvəlki buraxılışın məlumatlarını oxumağa icazə vermədi';

  @override
  String get macDmgImported => 'Əvvəlki buraxılışın məlumatları idxal edildi';

  @override
  String get macDmgImportFailed =>
      'Əvvəlki buraxılışın məlumatlarını oxumaq mümkün olmadı';

  @override
  String get macDmgTip =>
      'Yerli terminal və snippetlərin yerli icrası (DMG buraxılışı)';

  @override
  String get macDmgTitle => 'DMG buraxılışı';

  @override
  String get showHiddenFiles => 'Gizli faylları göstər';

  @override
  String get sshKeyAlgorithm => 'Alqoritm';

  @override
  String get sshKeyComment => 'Şərh';

  @override
  String get sshKeyGenerate => 'Açar cütü yarat';

  @override
  String get sshKeyGenerating => 'Yaradılır…';

  @override
  String sshKeyLockedFmt(String name) {
    return '[$name] məxfi açarının kilidi açılmadı.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'İstəyə bağlıdır. Parol ifadəsi olan açar şifrələnmiş şəkildə saxlanılır və əlaqə bu açardan ilk dəfə istifadə etdikdə parol ifadəsi soruşulur.';

  @override
  String get sshKeyPassphraseWrong => 'Parol ifadəsi yanlışdır.';

  @override
  String get sshKeyPublicKey => 'Açıq açar';

  @override
  String get sshKeyPublicKeyTip =>
      'Bu sətri serverdə ~/.ssh/authorized_keys faylının sonuna əlavə et.';

  @override
  String get sshKeyRecommended => 'Tövsiyə olunur';

  @override
  String sshKeyUnlockTip(String name) {
    return '[$name] məxfi açarının parol ifadəsini daxil et.';
  }

  @override
  String get ungrouped => 'Qruplaşdırılmayıb';

  @override
  String get containerReclaimable => 'Reclaimable';

  @override
  String get unused => 'İstifadə olunmur';

  @override
  String get dangling => 'İstinadsız';

  @override
  String get pruneUnusedImages => 'İstifadə olunmayan obrazları sil';

  @override
  String get pruneDanglingImages => 'İstinadsız obrazları sil';

  @override
  String get pruneImages => 'Obrazları təmizlə';

  @override
  String get unusedTaggedImages => 'İstifadə olunmayan etiketli obrazlar';

  @override
  String get pruneDanglingImagesTip => 'Yalnız istinadsız obrazları silir.';

  @override
  String get pruneUnusedImagesTip =>
      'Heç bir konteynerin istifadə etmədiyi etiketli obrazları da sil.';

  @override
  String get includeUnusedVolumesTip =>
      'Heç bir konteynerin istifadə etmədiyi saxlama həcmlərini də sil.';

  @override
  String get pruneCommandPreview => 'Əmrin önbaxışı';

  @override
  String get pruneForceSshTip =>
      '-f interaktiv sorğunu ötürür və SSH üzərindən icra zamanı həmişə aktivdir.';

  @override
  String get pruneVolumes => 'Saxlama həcmlərini təmizlə';

  @override
  String get pruneUnusedData => 'İstifadə olunmayan məlumatları sil';

  @override
  String get pull => 'Çək';

  @override
  String get invalidHostFormat =>
      'Host formatı yanlışdır. Yalnız IPv4, IPv6 və domen simvollarına icazə verilir.';

  @override
  String get jumpServer => 'Vasitəçi server';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return '$serverName üçün vasitəçi serverlər tapılmadı: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '\"$name\" artıq mövcuddur';
  }

  @override
  String get noJumpServerAvailable => 'Mövcud vasitəçi server yoxdur.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Vasitəçi server və ProxyCommand birlikdə istifadə edilə bilməz.';

  @override
  String get noConnectionMethod =>
      'SSH, monitorinq agenti və ya hər ikisini konfiqurasiya et';

  @override
  String get keepForeground => 'Tətbiqi ön planda saxla!';

  @override
  String get keepStatusWhenErr => 'Serverin son vəziyyətini saxla';

  @override
  String get keepStatusWhenErrTip =>
      'Yalnız skript icrası zamanı xəta baş verdikdə';

  @override
  String get keyAuth => 'Açarla autentifikasiya';

  @override
  String get lastFailure => 'Son uğursuzluq';

  @override
  String get lastSuccess => 'Son uğurlu cəhd';

  @override
  String get letterCache => 'Adi klaviatura daxiletməsi';

  @override
  String get letterCacheTip =>
      'Aktivləşdirildikdə daxiletmə adi IME vasitəsilə aparılır. Bu, bəzi sistemlərdə terminalda təhlükəsiz klaviatura sorğularının qarşısını ala bilər.';

  @override
  String get linuxShellTip =>
      'Terminalın başladacağı əmr örtüyü. Boş olduqda /bin/sh bərpa olunur.';

  @override
  String get linuxNetTip =>
      'DNS serverləri. Boş olduqda standart dəyərlər bərpa olunur';

  @override
  String madeWithLove(String myGithub) {
    return '$myGithub tərəfindən ❤️ ilə hazırlanıb';
  }

  @override
  String get maxConcurrency => 'Maksimum paralel əməliyyat sayı';

  @override
  String get maxRetryCount => 'Serverlə yenidən əlaqə cəhdlərinin sayı';

  @override
  String get mirror => 'Güzgü serveri';

  @override
  String get needRestart => 'Tətbiq yenidən başladılmalıdır';

  @override
  String get newContainer => 'Yeni konteyner';

  @override
  String get noConnectionStatsData => 'Əlaqə statistikası məlumatları yoxdur';

  @override
  String get noPrivateKeyTip =>
      'Məxfi açar mövcud deyil. Silinmiş ola bilər və ya konfiqurasiya xətası var.';

  @override
  String get noPromptAgain => 'Bir daha soruşma';

  @override
  String get openLastPath => 'Son yolu aç';

  @override
  String get openLastPathTip =>
      'Hər server üçün çıxış zamanı açıq olan yol ayrıca yadda saxlanılır';

  @override
  String get parseContainerStatsTip =>
      'Docker resurs istifadəsi vəziyyətinin təhlili nisbətən yavaşdır.';

  @override
  String get privateKey => 'Məxfi açar';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return '[$keyId] məxfi açarı tapılmadı.';
  }

  @override
  String get bmcPowerOnAction => 'İşə sal';

  @override
  String get bmcShutdown => 'Söndür';

  @override
  String get bmcForceOff => 'Məcburi söndür';

  @override
  String get restart => 'Yenidən başlat';

  @override
  String get bmcPowerCycle => 'Söndür və yenidən işə sal';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Bu sorğu $server serverinə göndərilsin? Xidmətdən \"$resetType\" istəniləcək';
  }

  @override
  String get bmcPowerDone => 'Enerji vəziyyəti dəyişdi';

  @override
  String get bmcPowerAccepted =>
      'Qəbul edildi, lakin enerji vəziyyəti dəyişməyib. Normal tamamlanma əməliyyat sistemindən asılıdır';

  @override
  String get bmcPowerUnsupported =>
      'Bu xidmət həmin əməliyyat üçün heç bir seçimə icazə vermir';

  @override
  String get bmcUnauthorized => 'BMC hesabı qəbul etmədi';

  @override
  String get bmcAccountMissing => 'Bu BMC üçün hesab təyin edilməyib';

  @override
  String get bmcPowerOn => 'İşləyir';

  @override
  String get bmcPowerOff => 'Söndürülüb';

  @override
  String get bmcCertRejected =>
      'Sertifikat rədd edildi. Server parametrlərində onu yoxla';

  @override
  String get bmcNotAService => 'Bu ünvanda Redfish xidməti yoxdur';

  @override
  String get bmcNoSystem => 'Xidmət heç bir sistem bildirmir';

  @override
  String get bmcSensorsTruncated => 'Yalnız ilk sensorlar göstərilir';

  @override
  String get bmcMultipleSystems => 'Yalnız ilk sistem göstərilir';

  @override
  String get bmcTip =>
      'BMC ana platada yerləşən ayrıca kompüterdir və hostun əməliyyat sistemi əlçatmaz olduqda belə ona müraciət etmək mümkündür. Burada konfiqurasiya edildikdə server sönülü və ya donmuş vəziyyətdə olarkən enerji vəziyyəti və avadanlıq sensorları barədə məlumat verə bilər. Təxminən 2016-cı ildən bəri əksər müəssisə avadanlıqlarında olan Redfish tələb olunur.';

  @override
  String get bmcCert => 'Sertifikat';

  @override
  String get bmcCertPinned => 'Yoxlanılıb və sabitlənib';

  @override
  String get bmcCertUnreviewed =>
      'Hələ yoxlanılmayıb. Sertifikata baxmaq üçün toxun';

  @override
  String get bmcCertReview =>
      'Özü tərəfindən imzalanmış sertifikatdır. Qəbul etməzdən əvvəl müqayisə et. Bundan sonra yalnız məhz bu sertifikata etibar ediləcək.';

  @override
  String get bmcCertChanged => 'Sertifikat uyğun gəlmir. Onu yoxla.';

  @override
  String get bmcCertExpired => 'Müddəti bitib.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Əvvəllər qəbul edilib: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'BMC ünvanı URL olmalıdır, məsələn, https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Bu buraxılış təcrid olunmuş mühitdə işləyir: əmr sənin ev qovluğunu deyil, boş ev qovluğunu alır, buna görə ~/.ssh yolunu oxuyan əməliyyatlar uğursuz olur. DMG buraxılışında bu məhdudiyyət yoxdur.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return '$path məxfi açar faylını oxumaq mümkün deyil: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Bu buraxılış öz konteynerindən kənardakı faylları oxuya bilmir, buna görə $path yolundakı açar əlçatmazdır. Açarı parametrlərdə idxal et və ya DMG buraxılışından istifadə et.';
  }

  @override
  String get pushToken => 'Push tokeni';

  @override
  String get liveActivity => 'Canlı fəaliyyət';

  @override
  String get liveActivityTip =>
      'Terminal seanslarını kilid ekranında və Dynamic Island-da göstərir. Serverin adı və bağlantı vəziyyəti kilidi açmadan görünür.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS buna icazə vermir. Açarlar «Settings › ServerBox › Live Activities» və «Settings › Face ID & Passcode › Live Activities» bölmələrindədir.';

  @override
  String get proxyCommandNeedsLinux =>
      'ProxyCommand bu cihazın Linux mühitində işləyir. Əvvəlcə bir Linux sistemi quraşdırın.';

  @override
  String get proxyCommandMobileTip =>
      'Telefonda əmr seçilmiş Linux sistemində işləyir. Əvvəlcə istifadə etdiyi alətləri (nc, socat, …) oraya quraşdırın.';

  @override
  String get pveIgnoreCertTip =>
      'Aktivləşdirmək tövsiyə olunmur, təhlükəsizlik risklərini nəzərə al! PVE standart sertifikatından istifadə edirsənsə, bu seçimi aktivləşdirməlisən.';

  @override
  String get pvePasswordRequired =>
      'PVE parolu tələb olunur. Onu server parametrlərində təyin et.';

  @override
  String get pveOtpRequired =>
      'Bu PVE serverində iki amilli autentifikasiya aktivdir. OTP kodunu daxil et.';

  @override
  String get pveOtpCodeRequired => 'OTP kodu tələb olunur.';

  @override
  String get pveOtpVerificationFailed =>
      'OTP yoxlaması uğursuz oldu. Yeni kodla yenidən cəhd et.';

  @override
  String get pveOtpTitle => 'OTP yoxlaması';

  @override
  String get pveOtpLabel => 'OTP kodu';

  @override
  String get pveInvalidResponseBody =>
      'PVE girişi etibarsız cavab gövdəsi qaytardı.';

  @override
  String get pveInvalidResponseData =>
      'PVE giriş cavabında etibarlı məlumat məzmunu yoxdur.';

  @override
  String get pveMissingAuthTicket =>
      'PVE girişi uğurlu oldu, lakin autentifikasiya bileti qaytarılmadı.';

  @override
  String get pveLoadingConnect => 'Əlaqə qurulur...';

  @override
  String get pvePassword => 'PVE parolu';

  @override
  String get pvePasswordHint =>
      'Açar əsaslı SSH autentifikasiyası istifadə edilərkən tələb olunur';

  @override
  String get read => 'Oxu';

  @override
  String get recentConnections => 'Son əlaqələr';

  @override
  String get rememberPwdInMem => 'Parolu yaddaşda saxla';

  @override
  String get rememberPwdInMemTip =>
      'Konteynerlər, yuxu rejimi və s. üçün istifadə olunur.';

  @override
  String get remotePath => 'Uzaq yol';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return '$distro $installed quraşdırılıb; $latest mövcuddur. Yeniləmə bütün konteyneri əvəz edir: $pm məlumatları itirilir';
  }

  @override
  String linuxSystemInUse(String name) {
    return '$name sistemini silməzdən əvvəl ondakı terminalları bağla';
  }

  @override
  String get rootfsSubtitle => 'Bu cihazda Linux istifadəçi mühiti';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return '$distro $version endirilir (təxminən $size MB) və bu cihazda arxivdən çıxarılır.';
  }

  @override
  String get sameIdServerExist => 'Eyni ID ilə server artıq mövcuddur';

  @override
  String get second => 'san';

  @override
  String get serverFilesUnavailableTip =>
      'Bu serverlə SSH əlaqəsi və ya fayl API interfeysi aktiv olan server_box_monitor quraşdırılması tələb olunur.';

  @override
  String get back => 'Geri qayıt';

  @override
  String get history => 'Tarixçə';

  @override
  String get homeDir => 'Ev qovluğu';

  @override
  String selected(int count) {
    return '$count seçilib';
  }

  @override
  String get sendTo => 'Göndər…';

  @override
  String get serverFuncBtns => 'Server funksiya düymələri';

  @override
  String get serverOrder => 'Serverlərin sırası';

  @override
  String get serverOverview => 'Server icmalı';

  @override
  String get serverOverviewTip =>
      'Server siyahısının yuxarısında icmalı və açıq serverin üstündə server panelini göstərir';

  @override
  String get serverTabEmpty => 'Hələ server yoxdur';

  @override
  String get serverTabRequired => 'Server vərəqi silinə bilməz';

  @override
  String get shareCodeHint =>
      'Bu rəqəmləri alıcıya ayrıca bildir. Onlar QR koduna daxil edilmir.';

  @override
  String get shareCodePrompt => '6 rəqəmli kod';

  @override
  String get shareCodeTitle => 'Birdəfəlik kod';

  @override
  String get shareExpired => 'Bu paylaşımın müddəti bitib. Yenisini istə.';

  @override
  String get shareImportFile => 'Paylaşılan fayldan';

  @override
  String get shareImportTitle => 'Paylaşılan serveri idxal et';

  @override
  String get shareIncludesKey => 'Paylaşıma məxfi açar daxildir.';

  @override
  String get shareOmittedBmc =>
      'BMC giriş məlumatları. Ünvan daxil edilib, lakin giriş məlumatları daxil edilməyib.';

  @override
  String get shareOmittedJump =>
      'Vasitəçi server, çünki bu cihazda ayrıca server kimi saxlanılır.';

  @override
  String get shareOmittedKeyPath =>
      'Açar faylı, çünki onun yolu yalnız bu cihazda etibarlıdır.';

  @override
  String get shareOmittedMissingKey =>
      'Məxfi açar, çünki bu cihazın açar anbarında yoxdur.';

  @override
  String get shareOmittedTip =>
      'Daxil edilməyib; alıcı bunları konfiqurasiya etməlidir:';

  @override
  String get sharePassphraseTip =>
      'Bu parol ifadəsi faylı şifrələyir. Serveri idxal etmək üçün alıcıya bu ifadə lazımdır və onu bərpa etmək mümkün deyil.';

  @override
  String shareQrTip(int minutes) {
    return 'Bu QR kodundakı əlaqə təfərrüatları şifrələnib. Paylaşımın müddəti $minutes dəqiqədən sonra bitir.';
  }

  @override
  String get shareScanQr => 'QR kodunu skan et';

  @override
  String shareServerExists(String name) {
    return 'Bu cihazdakı “$name” artıq bu ünvandan istifadə edir. Yenə də idxal edilsin?';
  }

  @override
  String get shareTooBigForQr => 'QR kodu üçün çox böyükdür. Fayl kimi paylaş.';

  @override
  String get shareTooNew =>
      'Bu paylaşım ServerBox tətbiqinin daha yeni versiyası ilə yaradılıb. Açmaq üçün tətbiqi yenilə.';

  @override
  String get shareUnreadable => 'Bu, etibarlı ServerBox paylaşımı deyil.';

  @override
  String get shareVia => 'Paylaşma vasitəsi';

  @override
  String get sftpDlPrepare => 'Əlaqə qurmağa hazırlanır...';

  @override
  String get sftpEditorTip =>
      'Boş olduqda daxili redaktordan istifadə olunur. Məsələn, `vim` (`EDITOR` dəyərini oxumaq tövsiyə olunur).';

  @override
  String get sftpRmrDirSummary =>
      'SFTP daxilində qovluğu silmək üçün `rm -r` istifadə et.';

  @override
  String get sftpSSHConnected => 'SFTP əlaqəsi quruldu';

  @override
  String get sftpShowFoldersFirst => 'Əvvəlcə qovluqları göstər';

  @override
  String get sftpUnavailableUseScp =>
      'Əksər quraşdırılmış sistemlərdə olduğu kimi, bu hostda da SFTP alt sistemi yoxdursa, server parametrlərində fayl ötürülməsini SCP olaraq təyin et.';

  @override
  String get sshFileTransportTip =>
      'SFTP müasir sistemlər üçün uyğundur. SSH serverində SFTP alt sistemi olmayan köhnə host və ya quraşdırılmış sistem üçün SCP seç: bunun üçün `scp` əmri və adi fayl alətləri (`find`, `stat`, `mv`, `chmod`) olan əmr örtüyü lazımdır.';

  @override
  String get specifyDev => 'Cihazı təyin et';

  @override
  String get specifyDevTip =>
      'Şəbəkə trafiki standart olaraq bütün cihazlar üzrə hesablanır; yalnız bir cihaz üçün burada onun adını yaz';

  @override
  String get tempIsCelsiusTip =>
      'Aktivləşdirildikdə temperatur dəyəri milliselsi əvəzinə Selsi kimi qəbul ediləcək. Yalnız temperatur səhv göstərildikdə aktivləşdir (məsələn, 58°C əvəzinə 0.1°C göstərildikdə).';

  @override
  String spentTime(String time) {
    return 'Sərf olunan vaxt: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return 'Bütün serverlər artıq mövcuddur ($duplicateCount təkrar tapıldı)';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount təkrar ötürüləcək';
  }

  @override
  String get sshConfigFound => 'Sistemində SSH konfiqurasiyası tapıldı.';

  @override
  String sshConfigFoundServers(int totalCount) {
    return '$totalCount server tapıldı';
  }

  @override
  String get sshConfigImport => 'SSH konfiqurasiyasını idxal et';

  @override
  String get sshConfigImportPermission =>
      '~/.ssh/config faylını oxumağa və server parametrlərini avtomatik idxal etməyə icazə vermək istəyirsən?';

  @override
  String get sshConfigImportTip =>
      'İlk server yaradılarkən ~/.ssh/config faylını oxumaq üçün sorğu göstər';

  @override
  String sshConfigImported(int count) {
    return 'SSH konfiqurasiyasından $count server idxal edildi';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return '$serverName üçün SSH host açarı dəyişib. Yalnız bu serverə etibar edirsənsə davam et.';
  }

  @override
  String get sshHostKeyType => 'SSH host açarının növü';

  @override
  String get sshKnownHostKeys => 'Tanınan hostlar';

  @override
  String get sshKnownHostKeysTip => 'Bu tətbiqin qəbul etdiyi host açarları';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return '$serverName serverindən yeni SSH host açarı alındı. Etibar etməzdən əvvəl barmaq izini yoxla.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return 'Saxlanmış barmaq izi: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Təsdiqləmə kodu';

  @override
  String get sshConfigManualSelect =>
      'SSH konfiqurasiya faylını əl ilə seçmək istəyirsən?';

  @override
  String get sshConfigNoServers => 'SSH konfiqurasiyasında server tapılmadı';

  @override
  String get sshConfigPermissionDenied =>
      'macOS icazələrinə görə SSH konfiqurasiya faylına daxil olmaq mümkün deyil.';

  @override
  String sshConfigServersToImport(int importCount) {
    return '$importCount server idxal ediləcək';
  }

  @override
  String get sshTermHelp =>
      'Terminalda sürüşdürmə mümkün olduqda üfüqi sürükləyərək mətn seçə bilərsən. Klaviatura düyməsi klaviaturanı açıb bağlayır. Fayl işarəsi cari yolu SFTP daxilində açır. Mübadilə buferi düyməsi mətn seçildikdə məzmunu kopyalayır; mətn seçilmədikdə və buferdə məzmun olduqda isə onu terminala yapışdırır. Kod işarəsi kod snippetlərini terminala yapışdırır və icra edir.';

  @override
  String get sshVirtualKeyAutoOff => 'Virtual düymələrin avtomatik dəyişməsi';

  @override
  String get supportFmtArgs => 'Aşağıdakı formatlama parametrləri dəstəklənir:';

  @override
  String get suspendTip =>
      'Yuxu rejimi funksiyası root icazəsi və systemd dəstəyi tələb edir.';

  @override
  String switchTo(String val) {
    return '$val rejiminə keç';
  }

  @override
  String get syncAppSettings => 'Tətbiq parametrlərini sinxronlaşdır';

  @override
  String get syncAppSettingsTip =>
      'Tema, düzülüş, redaktor, terminal və digər cihaz seçimlərini avtomatik sinxronlaşdırmaya daxil et.';

  @override
  String get termFontSizeTip =>
      'Bu parametr terminalın ölçüsünə (eninə və hündürlüyünə) təsir edəcək. Cari sessiyanın şrift ölçüsünü tənzimləmək üçün terminal səhifəsində miqyası böyüdə bilərsən.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (ilkin ölçü), yalnız server səhifəsindəki bəzi şriftlərə təsir edir, dəyişdirmək tövsiyə olunmur.';

  @override
  String get times => 'Dəfə';

  @override
  String get trySudo => 'sudo istifadə etməyə cəhd et';

  @override
  String get sudoPromptNotFound => 'Aktiv sudo parol sorğusu yoxdur.';

  @override
  String get updateServerStatusInterval =>
      'Server statusunun yenilənmə intervalı';

  @override
  String get useNoPwd => 'Parol istifadə edilməyəcək';

  @override
  String get usePodmanByDefault => 'Standart olaraq Podman istifadə et';

  @override
  String get used => 'İstifadə olunur';

  @override
  String get viewDetails => 'Təfərrüatlara bax';

  @override
  String get virtKeyHelpIME => 'Klaviaturanı aç/bağla';

  @override
  String get virtKeyHelpSFTP => 'Cari qovluğu SFTP daxilində aç.';

  @override
  String get virtKeyHelpSnippet => 'Snippet seç və bu terminalda icra et.';

  @override
  String get virtKeyHelpTmux =>
      'tmux sessiyaları və pəncərələri arasında keçid et.';

  @override
  String get virtKeyIntroActions => 'Qısayollar';

  @override
  String get virtKeyIntroActionsTip =>
      'Bunlar yazı daxil etmək əvəzinə nəyisə açır. Nə etdiyini oxumaq üçün birini basıb saxla.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'Terminal parametrlərində bu düymələrin sırasını dəyiş, daha çoxunu aç (fayllar, sudo, F1–F12…) və ya istifadə etmədiklərini gizlət.';

  @override
  String get virtKeyIntroModifiers => 'Dəyişdirici düymələr';

  @override
  String get virtKeyIntroModifiersTip =>
      'Aktivləşdirmək üçün birinə toxun, sonra klaviaturada hərfə toxun. Yalnız həmin bir düymə üçün aktiv qalır.';

  @override
  String get virtKeyIntroNav => 'Naviqasiya';

  @override
  String get virtKeyIntroNavTip =>
      'Bunlar kursoru hərəkət etdirir. Hərəkəti təkrarlamaq üçün ox düyməsini basıb saxla.';

  @override
  String get virtKeyIntroSelect =>
      'Terminalda sürüşdürüləcək məzmun olduqda mətn seçmək üçün onun üzərində üfüqi sürüklə.';

  @override
  String get virtKeyRows => 'Eyni vaxtda göstərilən sətirlər';

  @override
  String get virtKeyRowsTip =>
      'Qalanları üfüqi sürüşdürmə ilə açılan ayrıca səhifədə yerləşir.';

  @override
  String get waitConnection => 'Əlaqə qurulana qədər gözlə.';

  @override
  String get wakeLock => 'Oyaq saxla';

  @override
  String get watchNotPaired => 'Cütləşdirilmiş Apple Watch yoxdur';

  @override
  String get webdavSettingEmpty => 'WebDav parametri boşdur';

  @override
  String get whenOpenApp => 'Tətbiq açılarkən';

  @override
  String get wolTip =>
      'WOL (Wake-on-LAN) konfiqurasiya edildikdən sonra serverlə hər dəfə əlaqə qurulduqda WOL sorğusu göndərilir.';

  @override
  String get write => 'Yaz';

  @override
  String get writeScriptFailTip =>
      'Skriptə yazmaq mümkün olmadı. Səbəb icazələrin çatışmaması və ya qovluğun mövcud olmaması ola bilər.';

  @override
  String get writeScriptTip =>
      'Serverlə əlaqə qurulduqdan sonra sistemin vəziyyətini izləmək üçün `~/.config/server_box` \n | `/tmp/server_box` yoluna skript yazılacaq. Skriptin məzmununa baxa bilərsən.';

  @override
  String get menuGitHubRepository => 'GitHub repozitoriyası';

  @override
  String get podmanDockerEmulationDetected =>
      'Podman Docker emulyasiyası aşkarlandı. Parametrlərdə Podman seç.';

  @override
  String get betaTip =>
      'Bu funksiya hələ beta sınağındadır. İşləyəcəyinə zəmanət verilmir.';

  @override
  String get portForward_startPrompt =>
      'Başlamaq üçün port yönləndirmə qaydası əlavə et';

  @override
  String get portForward_localHost => 'Yerli host';

  @override
  String get portForward_localPort => 'Yerli port';

  @override
  String get portForward_remoteHost => 'Uzaq host';

  @override
  String get portForward_remotePort => 'Uzaq port';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return '$name silinsin?';
  }

  @override
  String get sponsor => 'Sponsor ol';

  @override
  String get sortByJoinTime => 'Əlavə edilmə vaxtına görə';

  @override
  String get tmuxAutoAttach => 'tmux sessiyasına avtomatik qoşulma';

  @override
  String get tmuxAuto => 'Avtomatik tmux';

  @override
  String get tmuxAutoTip =>
      'SSH ilə əlaqə qurarkən tmux sessiyasını avtomatik başlat və ya ona qoşul';

  @override
  String get tmuxSessionSelector => 'Sessiya seçimi';

  @override
  String get tmuxSessionSelectorTip => 'Əlaqə qurarkən sessiya seçimini göstər';

  @override
  String get tmuxDefaultSessionName => 'Standart sessiya adı';

  @override
  String get tmuxSessionName => 'Sessiya adı';

  @override
  String get tmuxNewSession => 'Yeni sessiya';

  @override
  String get tmuxNewWindow => 'Yeni pəncərə';

  @override
  String get tmuxNoWindowsFound => 'Pəncərə tapılmadı';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pəncərə',
      one: '1 pəncərə',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Qoşulub';

  @override
  String get tmuxSkip => 'Keç';

  @override
  String get tmuxNotAvailable => 'tmux əlçatan deyil';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Konteyner cavabında gözlənilməyən bölmə sayı: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Başqa konteyner əməliyyatı artıq davam edir';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count proses',
      one: '1 proses',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'Proses siyahısının formatı dəstəklənmir.';

  @override
  String get processParseInvalidRows =>
      'Bəzi proses qeydlərini oxumaq mümkün olmadı.';

  @override
  String get processParseInvalidWindowsJson =>
      'Windows prosesləri haqqında cavabı oxumaq mümkün olmadı.';

  @override
  String get processParseInvalidWindowsRows =>
      'Bəzi Windows proses qeydlərini oxumaq mümkün olmadı.';

  @override
  String get processKillTargetChanged =>
      'Proses dəyişib və ya başa çatıb. Yenilə və yenidən cəhd et.';

  @override
  String get processSearchHint => 'Ad, istifadəçi və ya PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kernel thread göstər',
      one: '1 kernel thread göstər',
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
  String get watchServers => 'Saatdakı serverlər';

  @override
  String get watchServersTip =>
      'Saat məlumatları monitor agentindən özü alır, buna görə yalnız bu agenti olan serverləri seçmək mümkündür.';

  @override
  String get watchNoMonitorServer =>
      'Heç bir serverdə monitor agenti konfiqurasiya edilməyib';

  @override
  String get legacyStatusGoneTitle => 'Vəziyyət URL ünvanları artıq işləmir';

  @override
  String get legacyStatusGoneBody =>
      'Saat tətbiqi və ana ekran vidcetləri əvvəllər əl ilə daxil edilmiş `/status` ünvanını oxuyurdu. Bu son nöqtə artıq mövcud deyil: yalnız cari dəyərləri mətn kimi qaytara bildiyinə görə qrafik göstərmək mümkün olmurdu.\n\nİndi onlar monitor agentinin autentifikasiya tələb edən API interfeysindən məlumat alır, dəyişmə qrafikləri çəkir və tətbiqlə avtomatik sinxronlaşır. Serveri tətbiqdə bir dəfə konfiqurasiya et, bütün saatlar və vidcetlər onu avtomatik tanıyacaq.';

  @override
  String get services => 'Servislər';

  @override
  String get status => 'Vəziyyət';

  @override
  String get enable => 'Aktivləşdir';

  @override
  String get disable => 'Söndür';

  @override
  String get starting => 'Başladılır';

  @override
  String get stopping => 'Dayandırılır';

  @override
  String get serviceManagerUnsupported => 'Dəstəklənməyən servis idarəedicisi';

  @override
  String get serviceManagerUnsupportedTip =>
      'Bu server ServerBox tərəfindən hələ dəstəklənməyən servis idarəedicisindən istifadə edir. Dəstəklənən idarəedicilər: systemd, procd və OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return '$manager tərəfindən idarə olunur';
  }

  @override
  String get serviceListFailed => 'Servis siyahısını almaq mümkün olmadı';

  @override
  String get serviceDetailsUnavailable =>
      'Servislərlə bağlı bəzi təfərrüatlar əlçatan deyil';

  @override
  String get serviceDetailsUnavailableTip =>
      'Servis siyahısından istifadə etmək mümkündür, lakin idarəedici bütün status və ya başlanğıc məlumatlarını qaytarmadı.';

  @override
  String get systemdUserScopeMissing =>
      'İstifadəçi vahidləri siyahıda göstərilmir';

  @override
  String get systemdUserScopeMissingTip =>
      'Bu hesabın serverdə istifadəçi sessiyası şini yoxdur, buna görə yalnız sistem vahidləri göstərilir.';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count digər unit',
      one: '1 digər unit',
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
    return '$duration əvvəl dayandırılıb';
  }

  @override
  String serviceExitStatus(int code) {
    return 'çıxış statusu $code';
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
      other: 'Son $count sətir',
      one: 'Son sətir',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable => 'Bu hesab journal-ı oxuya bilmir';

  @override
  String get serverUnreachable => 'Bu serverdə əmr icra etmək mümkün olmadı';

  @override
  String get containerNoRuntime => 'Burada konteyner icra mühiti yoxdur';

  @override
  String get containerNoRuntimeTip =>
      'Bu kompüterdə nə `docker`, nə də `podman` cavab verdi. Onlardan biri başqa hesab üçün quraşdırılıbsa, parametrlərdə \"sudo istifadə etməyə cəhd et\" seçimini aktivləşdir.';

  @override
  String get containerUnreadable =>
      'Konteyner icra mühiti gözlənilməyən formatda cavab verdi';

  @override
  String get power => 'Güc';

  @override
  String get fan => 'Ventilyator';

  @override
  String get clockSpeed => 'Tezlik';

  @override
  String get vendor => 'İstehsalçı';

  @override
  String get continueInTerminal => 'Terminalda davam et';

  @override
  String get askAiRiskUnknown => 'Təsnif edilməyib';

  @override
  String get agentLocalExec => 'Bu cihazda əmrlər icra et';

  @override
  String get agentLocalExecTip =>
      'Agentin ServerBox işləyən kompüterdə işləməsinə icazə verir. Yalnız oxuma əmrləri də yoxlanılır';

  @override
  String get agentLocalExecRootfsTip =>
      'Agentin yerli olaraq, ServerBox tərəfindən quraşdırılmış Linux konteyneri daxilində işləməsinə icazə verir';

  @override
  String macDmgImportedPartly(String path) {
    return 'Əvvəllər quraşdırılmış versiyanın məlumatları idxal edildi. Endirilmiş fayllar əvvəlki yerində, $path qovluğunda saxlanıldı.';
  }

  @override
  String get bmcAccount => 'Hesab';

  @override
  String get bmcAccountUnset =>
      'Heç biri seçilməyib. Seçmək və ya yaratmaq üçün toxun';

  @override
  String bmcAccountShared(int count) {
    return '$count server tərəfindən istifadə olunur';
  }

  @override
  String get bmcAccounts => 'BMC hesabları';

  @override
  String get bmcAccountSharedTip =>
      'Buradakı dəyişikliklər bütün bu serverlərin istifadə etdiyi hesab məlumatlarını dəyişir.';

  @override
  String bmcAccountInUse(int count) {
    return '$count server bu hesabdan istifadə edir. Onların ünvanları qalacaq, hesab isə silinəcək.';
  }

  @override
  String get bmcStaleWrite =>
      'Məlumat yazılarkən BMC dəyişdi. Yenidən cəhd et.';

  @override
  String get privacyBlur => 'Arxa planda məxfilik';

  @override
  String get privacyBlurTip =>
      'Tətbiqlər arasında keçid ekranında tətbiqin məzmununu gizlət';

  @override
  String get floatReturnToTab => 'Vərəqə qaytar';

  @override
  String get termInFloatWindow => 'Bu terminal üzən pəncərədədir';

  @override
  String get globeEnabledTip =>
      'Serverləri ünvanlarının yerləşdiyi nöqtələrdə qlobus üzərində göstərir. Söndürüldükdə düymə server vərəqindən silinir və bütün sorğular dayandırılır.';

  @override
  String get geoShardsConsentAttribution =>
      'IP üzrə coğrafi mövqe məlumatları [DB-IP](https://db-ip.com) tərəfindən təqdim olunur, CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Özəl ünvan';

  @override
  String get geoMissNoData => 'Mövqe məlumatı yoxdur';

  @override
  String get globeGuide =>
      'Serverlərini ünvanlarının yerləşdiyi nöqtələrdə qlobus üzərində görmək üçün buraya toxun.';

  @override
  String get publicIp => 'İctimai IP';

  @override
  String get geoData => 'Şəhər səviyyəsində məlumatlar';

  @override
  String get geoDataTip =>
      'Endirildikdən sonra bütün coğrafi mövqe sorğuları bu cihazda saxlanılan məlumatlardan istifadə edir. Server ünvanları və sorğu fəaliyyəti endirmə servisinə göndərilmir.';

  @override
  String get geoDataMissing => 'Endirilməyib';

  @override
  String get geoDataUnreachable => 'Məlumatları almaq mümkün olmadı.';

  @override
  String get geoDataRemoveFailed => 'Məlumatları silmək mümkün olmadı.';

  @override
  String geoDataCurrent(String month) {
    return '$month artıq quraşdırılıb.';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**Endirmə: $download · Cihazda tutulan yer: $disk.** Tam məlumat toplusu bu cihazda saxlanılır və sonrakı bütün coğrafi mövqe sorğuları yerli olaraq icra olunur. Server ünvanları və sorğu fəaliyyəti endirmə servisinə göndərilmir.\n\nHər ay yenilənir. Yeni versiya əlavə nüsxə saxlamadan quraşdırılmış məlumatları əvəz edir. Məlumatları istənilən vaxt silə bilərsən.';
  }

  @override
  String get benchmark => 'Benchmark';

  @override
  String get benchmarkIntro =>
      'Bu serverdə disk, şəbəkə və CPU üçün Yet Another Bench Script işə salınır. Tam icra 10 ilə 20 dəqiqə arasında vaxt aparır və bu səhifədən çıxsan və ya tətbiqi bağlasan da davam edir.';

  @override
  String get benchmarkNoRuns => 'Hələ benchmark yoxdur.';

  @override
  String get benchmarkRunning => 'Benchmark icra olunur';

  @override
  String get benchmarkStartFailed => 'Benchmark başlatmaq mümkün olmadı';

  @override
  String get benchmarkCancelConfirm =>
      'Bu benchmark dayandırılsın? İndiyə qədər ölçülmüş nəticələr itiriləcək.';

  @override
  String get benchmarkDeleteConfirm => 'Bu benchmark nəticəsi silinsin?';

  @override
  String get benchmarkNothingSelected =>
      'Bütün mərhələlər söndürülüb. Yalnız sistem məlumatları toplanacaq və bu, bir neçə saniyə çəkəcək.';

  @override
  String get benchmarkDiskTip =>
      'Dörd blok ölçüsündə fio sınağı, təxminən 3 dəqiqə. İş qovluğuna 2 GB ölçülü sınaq faylı yazır və bu qədər boş yer tələb edir.';

  @override
  String get benchmarkNetworkTip =>
      'İctimai serverlərlə iperf3 sınağı, təxminən 4 dəqiqə.';

  @override
  String get benchmarkReducedNetwork => 'Daha az məkan';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Yeddi əvəzinə üç məkan. Təxmini trafik həcmi $full əvəzinə $reduced olacaq.';
  }

  @override
  String get benchmarkCpuTip =>
      'Qapalı mənbəli Geekbench proqramını endirir və **nəticəni geekbench.com saytında hamıya açıq səhifədə dərc edir**, CPU modeli, nüvə sayı və yaddaş məlumatları da daxil olmaqla.';

  @override
  String get benchmarkSensitiveOptions =>
      'Aşağıdakı seçimlər bu serverə üçüncü tərəf proqramlarını endirib işə salır və ya server məlumatlarını üçüncü tərəflərə göndərir. Standart olaraq söndürülüb.';

  @override
  String get benchmarkIpInfoTip =>
      'Bu serverin ictimai ünvanını şifrələnməmiş HTTP ilə ip-api.com saytına göndərir.';

  @override
  String get benchmarkIpInfo => 'IP ünvanının sahibini öyrən';

  @override
  String get benchmarkPreferBin => 'fio və iperf3 endir';

  @override
  String get benchmarkPreferBinTip =>
      'Hostdakı paketlərdən istifadə etmək əvəzinə onları GitHub saytından endirir. Yalnız hostda heç biri quraşdırılmayıbsa, aktivləşdir.';

  @override
  String get benchmarkWorkDir => 'İş qovluğu';

  @override
  String get benchmarkWorkDirTip =>
      'Disk sınağının hansı fayl sistemini ölçəcəyini müəyyən edir. Boş saxlanıldıqda daxil olduğun hesabın ev qovluğu istifadə olunur.';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return 'Təxminən $minutes dəq';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Təxminən $size trafik';
  }

  @override
  String get benchmarkPhaseSystem => 'Sistem məlumatları oxunur';

  @override
  String get benchmarkPhaseDisk => 'Disk sınaqdan keçirilir';

  @override
  String get benchmarkPhaseNetwork => 'Şəbəkə sınaqdan keçirilir';

  @override
  String get benchmarkPhaseCpu => 'CPU sınaqdan keçirilir';

  @override
  String get benchmarkPhaseDone => 'Tamamlanır';

  @override
  String get benchmarkResultUnreadable =>
      'Bu nəticəni JSON kimi oxumaq mümkün olmadı. Xam mətn aşağıdadır.';

  @override
  String get benchmarkViewOnGeekbench => 'Geekbench saytında bax';

  @override
  String get benchmarkGeekbenchPublic =>
      'Bu nəticə yuxarıdakı keçiddə hamıya açıq şəkildə dərc edilib.';

  @override
  String get benchmarkSingleCore => 'Tək nüvə';

  @override
  String get benchmarkMultiCore => 'Çox nüvə';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Yükləmə';

  @override
  String get benchmarkRecv => 'Endirmə';

  @override
  String get benchmarkLatency => 'Gecikmə';

  @override
  String get benchmarkVirt => 'Virtuallaşdırma';

  @override
  String get benchmarkRawLog => 'İcra jurnalı';

  @override
  String benchmarkUpstream(String version) {
    return 'Yet Another Bench Script ($version) əsasında işləyir';
  }

  @override
  String get benchmarkPhaseStarting => 'Başladılır';

  @override
  String get benchmarkNoOutputYet =>
      'Hələ çıxış yoxdur. İlk sətri göstərməzdən əvvəl YABS google.com və icanhazip.com saytlarının əlçatanlığını yoxlayır. Bu saytlardan hər hansı birini bloklayan şəbəkələrdə bu, bir neçə dəqiqə çəkə bilər.';

  @override
  String get tagsEmptyTip =>
      'Hələ etiket yoxdur. Serveri redaktə edərkən etiket əlavə et, burada görünəcək.';

  @override
  String get benchmarkNoServers =>
      'Əvvəlcə server əlavə et, sonra benchmark üçün buraya qayıt.';

  @override
  String get schemaTooNewTitle => 'Bu məlumatlar tətbiqdən daha yenidir';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Məlumatlar ServerBox-ın daha yeni versiyası tərəfindən yazılıb (yaddaş v$stored). Bu versiya ən çox v$supported oxuya bilir və məlumatlar dəyişdirilməyib.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Bütün məlumatları yenidən açmaq üçün daha yeni versiyanı quraşdır.';

  @override
  String get schemaTooNewExportPlain => 'Şifrəsiz ixrac et';

  @override
  String get schemaTooNewPlainWarn =>
      'Faylda bütün SSH məxfi açarları, server parolları və API açarları açıq mətn kimi saxlanacaq. Faylı əldə edən şəxs bunların hamısına giriş əldə edə bilər.';

  @override
  String get schemaTooNewWipe => 'Bütün məlumatları sil';

  @override
  String get schemaTooNewWipeConfirm =>
      'Bu cihazdakı bütün serverlər, açarlar, snippet-lər və parametrlər silinəcək. Bu əməliyyatı geri qaytarmaq olmaz. Burada ixrac edilmiş ehtiyat nüsxə qalan yeganə surət olacaq.';

  @override
  String get schemaTooNewWipeDone =>
      'Məlumatlar silindi. Tətbiqi yenidən aç və sıfırdan başla.';

  @override
  String get schemaTooNewWipeFailed =>
      'Məlumatların bir hissəsini silmək mümkün olmadı və bu versiya qalan məlumatları hələ də aça bilmir. Onlara giriş üçün daha yeni versiyanı yenidən quraşdır.';

  @override
  String get systemUsers => 'Users';

  @override
  String get userManagerLinuxOnly =>
      'Sistem istifadəçilərinin idarəsi hazırda yalnız Linux serverlərini dəstəkləyir.';

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
      'root hesabına dəyişikliklər bütün sessiyalarda dərhal qüvvəyə minir.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Əlavə qruplar';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Home qovluğu yarat';

  @override
  String get userMoveHome => 'Yol dəyişdikdə mövcud home qovluğunu köçür';

  @override
  String get userRemoveHome => 'Home qovluğunu sil';

  @override
  String get userPasswordCreateTip =>
      'Parolla girişi bağlı hesab yaratmaq üçün parolu boş saxlayın.';

  @override
  String get userPasswordEditTip =>
      'Mövcud parolu saxlamaq üçün parolu boş saxlayın.';

  @override
  String funcUnavailableFmt(String func) {
    return '$func bu serverin bağlantı üsulunda mövcud deyil.';
  }

  @override
  String funcNeedsAgentGrant(String func, String setting) {
    return '$func üçün Monitor agent-də $setting aktiv edilməlidir.';
  }

  @override
  String funcNeedsAgentUpdate(String func) {
    return '$func üçün daha yeni Monitor agent lazımdır.';
  }

  @override
  String get portForwardRemoteNeedsAgent =>
      'Monitor agent vasitəsilə uzaq yönləndirmələr daha yeni agent tələb edir: serverdə onu yeniləyin.';

  @override
  String get rangeLive => 'Canlı';

  @override
  String get diskIo => 'Disk G/Ç';

  @override
  String get peak => 'pik';

  @override
  String get hardware => 'Avadanlıq';

  @override
  String get cores => 'Nüvələr';

  @override
  String get historyNoStored =>
      'Tarixçəni yalnız monitor agenti saxlayır. Bu bağlantı yalnız tətbiqin qoşulduqdan sonra gördüyünü saxlayır.';

  @override
  String get noHistoryYet => 'Hələ ölçülməyib';

  @override
  String get noData => 'məlumat yoxdur';

  @override
  String get from => 'Başlanğıc';

  @override
  String get to => 'Son';

  @override
  String get beyondRetention => 'bu agentin saxladığından uzaq';

  @override
  String agentRetentionFmt(String kept) {
    return 'Agent $kept saxlayır';
  }

  @override
  String get agentServerTools => 'Server alətləri';

  @override
  String get agentServerToolsTip =>
      'Serverlərinizdə əmrlər icra etmək, faylları oxumaq və ya yazmaq, SSH ilə digər hostlara qoşulmaq və ServerBox-un öz əməliyyatlarından istifadə etmək.';

  @override
  String get agentTerminalTools => 'Terminal';

  @override
  String get agentTerminalToolsTip =>
      'Terminalın öz söhbətlərində: terminalın göstərdiyini oxumaq və onun serverində əmrlər icra etmək.';

  @override
  String get agentToolTerminalScreen => 'Ekranı oxu';

  @override
  String get agentProviders => 'Provayderlər';

  @override
  String get agentProvidersTip =>
      'API açarları, modellər və yeni söhbətin modeli';

  @override
  String get agentTools => 'Alətlər';

  @override
  String get agentToolsTip =>
      'Agent-in istifadə edə bildikləri və onun MCP serverləri';

  @override
  String get agentSnippetToolsTip =>
      'Snippet-ləri siyahıla, əlavə et, dəyiş və sil. Dəyişikliklər soruşulur.';

  @override
  String get agentVirtToolsTip =>
      'Virtualizasiya bölməsinin yüklədiyi VM və konteynerləri oxu.';

  @override
  String get agentBenchmarkToolsTip =>
      'Benchmark nəticələrini oxu; icazənizlə benchmark başlat və ya dayandır.';

  @override
  String get agentRemoteDesktopToolsTip =>
      'Uzaq masaüstü profillərini siyahıla; icazənizlə qoşul və ya ayrıl.';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentSkillsTip =>
      'Müəyyən tapşırıqlar üçün təlimatlar, GitHub-dan və ya keçiddən quraşdırılır';

  @override
  String get agentPermissions => 'İcazələr';

  @override
  String get agentEmptyHint =>
      'Serverləriniz haqqında soruşun və ya Agent-dən onlarda nəsə etməsini xahiş edin.';

  @override
  String get agentTerminalEmptyHint =>
      'Bu server haqqında soruşun. Agent bu terminalı oxuya və burada əmrlər icra edə bilər.';

  @override
  String oldestSampleFmt(String time) {
    return 'ən köhnə ölçmə $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'Aralığın sonu başlanğıcından sonra olmalıdır.';

  @override
  String get samples => 'ölçmə';

  @override
  String get unavailable => 'mövcud deyil';

  @override
  String get metricUnavailableTip =>
      'Səhifənin qalanı təsirlənməyib. Bu göstəricinin gəldiyi əmri hostda yoxlayın.';

  @override
  String get waitingFirstSample => 'İlk ölçmə gözlənilir';

  @override
  String atTimeFmt(String time) {
    return 'saat $time';
  }

  @override
  String get stored => 'saxlanılan';

  @override
  String lastSampleFmt(String ago) {
    return 'son ölçmə $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Aşağıdakıların hamısı $time tarixindəndir, $ago.';
  }

  @override
  String noDataBeforeFmt(String time) {
    return '$time tarixindən əvvəl məlumat yoxdur';
  }

  @override
  String loadingRangeFmt(String range) {
    return '$range yüklənir…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return '$metric üçün saxlanılan tarixçə yoxdur';
  }

  @override
  String devicesFmt(int count) {
    return '$count cihaz';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count cihaz · ən məşğulu $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$total cihazdan $plotted ədədi';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count sensor · ən istisi $name';
  }

  @override
  String get oneDeviceAtLeast => 'Qrafikdə ən azı bir cihaz qalır.';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$total $what arasından $shown';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count $what';
  }

  @override
  String get unitDevices => 'cihaz';

  @override
  String get unitSensors => 'sensor';

  @override
  String get unitBatteries => 'batareya';

  @override
  String get unitCommands => 'əmr';

  @override
  String get unitReadings => 'göstərici';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => 'ən isti';

  @override
  String get oldest => 'ən köhnə';

  @override
  String get notApplicable => 'tətbiq olunmur';

  @override
  String get attributes => 'atributlar';

  @override
  String get powerOnHours => 'İşləmə saatları';

  @override
  String get powerCycles => 'Açılma sayı';

  @override
  String get lifeLeft => 'Qalan resurs';

  @override
  String get lifetimeWrite => 'Ümumi yazma';

  @override
  String get lifetimeRead => 'Ümumi oxuma';

  @override
  String get averageErase => 'Orta silinmə';

  @override
  String get unsafeShutdowns => 'Təhlükəli sönmələr';

  @override
  String get diskAllPassed => 'hamısı PASSED';

  @override
  String diskWarningFmt(int count) {
    return '$count xəbərdarlıq';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$total cihazdan $wrong';
  }

  @override
  String get diskSmartSortedTip => 'Ən pisdən sıralanıb';

  @override
  String readAgoFmt(String ago) {
    return '$ago oxundu';
  }

  @override
  String processesFmt(int count) {
    return '$count proses';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count nasaz';
  }

  @override
  String get diskSmartOpenTip => 'Atributları üçün toxunun';

  @override
  String get cycle => 'Dövr';

  @override
  String get window => 'pəncərə';

  @override
  String ofFmt(String total) {
    return '$total içindən';
  }

  @override
  String get serverDetailCards => 'Ətraflı səhifəsinin kartları';

  @override
  String get connection => 'Bağlantı';

  @override
  String get connectionTip =>
      'Hər ikisi eyni anda açıq ola bilər. Sıra, onların yığılma sırasıdır.';

  @override
  String get transportNoneOn =>
      'Hər ikisi bağlıdır — bu serverə qoşulmaq mümkün deyil.';

  @override
  String get thisDevice => 'Bu cihaz';

  @override
  String get localServerTip =>
      'Status skriptini burada işlədərək bu cihazı birbaşa oxuyur. SSH və Monitor HTTP istifadə olunmur, onların ayarları saxlanılır.';

  @override
  String get localServerUnsupported =>
      'Bu platforma bu cihazı server kimi oxuya bilmir. Linux, Windows və macOS DMG versiyası dəstəkləyir.';

  @override
  String get remoteDesktopIntro =>
      'Serverin RDP və ya VNC masaüstünü tətbiqin içində açır. Bağlantı serverin SSH bağlantısı və ya Monitor agenti üzərindən keçir, ona görə masaüstü portunun şəbəkədən əlçatan olması lazım deyil.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Hər masaüstü üçün profili serverdəki Uzaq masaüstü düyməsindən və ya Uzaq masaüstü tabından saxlayın.';

  @override
  String get localServerIntro =>
      'ServerBox işləyən cihazı server kimi əlavə edir. Status, proseslər, xidmətlər, konteynerlər, terminal və fayllar SSH və ya Monitor agenti olmadan işləyir.';

  @override
  String get localServerAdd => 'Bu cihazı əlavə et';

  @override
  String get localServerIntroFooter =>
      'Bunu sonra serverin redaktə səhifəsində Bağlantı bölməsində də aktiv etmək olar.';

  @override
  String get transportSectionOff =>
      'Bağlıdır. Aşağıdakı sahələr yenidən açanda lazım olsun deyə saxlanılır.';

  @override
  String get monitorAgent => 'Monitor agenti';

  @override
  String get plainHttpEditTip =>
      'Giriş məlumatları və göstəricilər şəbəkədən şifrələnmədən keçir. Bunu LAN və ya Tailscale ünvanı ilə məhdudlaşdırın, ya da agenti TLS arxasına qoyun.';

  @override
  String get behaviour => 'Davranış';

  @override
  String get optional => 'İstəyə bağlı';

  @override
  String get sshAdvanced => 'SSH əlavə';

  @override
  String get sshAdvancedTip =>
      'Ehtiyat ünvan, ProxyCommand, keçid serveri, fayl nəqli, uzaq yol';

  @override
  String get sshLegacyAlgorithms => 'Köhnə alqoritmlər';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Yalnız SHA-1 `ssh-rsa` host açarı və ya SHA-1 açar mübadiləsi təklif edən köhnə SSH serverləri (örnəyin, router və ya switch) üçündür. Təhlükəsizliyi daha aşağıdır; yalnız cihaz bunu tələb etdikdə aktivləşdirin.';

  @override
  String get appearanceAndPlace => 'Görünüş və yer';

  @override
  String get appearanceAndPlaceTip => 'Loqo, koordinatlar';

  @override
  String get statusCollection => 'Status toplanması';

  @override
  String get statusCollectionTip =>
      'Hansı əmrlər işləyir, fərdi əmrlər, hansı cihaz oxunur';

  @override
  String get tagAllTags => 'Bütün teqlər';

  @override
  String get tagMatching => 'Uyğun gələnlər';

  @override
  String get tagNewHint => 'Yeni teq';

  @override
  String tagCreateFmt(String tag) {
    return '#$tag yarat';
  }

  @override
  String get tagOnThisServer => 'bu serverdə';

  @override
  String tagServersFmt(int count) {
    return '$count server';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return 'bu serverdə $count';
  }

  @override
  String get tagMatchesTyped => 'yazdığınıza uyğun gəlir';

  @override
  String get tagEditorTip =>
      'Yazmaq siyahını süzgəcdən keçirir; düymə teqi yaradır və bir addımda bu serverə əlavə edir. Karandaş onu daşıyan hər serverdə adını dəyişir. Heç bir serverin daşımadığı teq yadda saxlanarkən yox olur.';

  @override
  String get tagRenamesOnSave =>
      'Adların dəyişdirilməsi yadda saxlayarkən tətbiq olunur';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'Planlaşdırılmış tapşırıqların idarəsi hazırda yalnız Linux serverlərini dəstəkləyir.';

  @override
  String get scheduledTaskUnavailable => 'Bu serverdə crontab mövcud deyil.';

  @override
  String get scheduledTaskPreserveTip =>
      'Bu crontab-dakı şərhlər, environment variable-lar və tanınmayan sətirlər qorunur.';

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
    return '$total tapşırıq · $enabled aktiv';
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
      'Söndürüləndə sətir şərh kimi yazılır.';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return '$user üçün planlaşdırılmış tapşırıq yoxdur. Buraya əlavə edilənlər həmin hesabın crontab-ına yazılır.';
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
  String get scheduledTaskFieldDayOfWeek => 'Həftənin günü';

  @override
  String get cronErrScheduleEmpty => 'Cədvəl tələb olunur.';

  @override
  String get cronErrCommandEmpty => 'Əmr tələb olunur.';

  @override
  String get cronErrLineBreak => 'crontab sətrində sətir keçidi ola bilməz.';

  @override
  String get cronErrMacro => 'Makro @reboot kimi bir sözdən ibarət olur.';

  @override
  String get cronErrFieldCount =>
      'cron cədvəli beş sahədən və ya @reboot kimi makrodan ibarət olur.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(int minutes) {
    return 'Hər $minutes dəqiqədən bir';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'Hər saatın :$minute-ci dəqiqəsində';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'Hər $hours saatdan bir';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'Hər $hours saatdan bir, :$minute-ci dəqiqədə';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Hər gün saat $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'İş günləri saat $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Hər $day saat $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return 'Hər ayın $day-ci günü saat $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart =>
      'Agent yenidən başladıldıqdan sonra qüvvəyə minir';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Genişləndirilmiş dövr intervalı';

  @override
  String get idlePause => 'İzləyən olmadıqda dayandır';

  @override
  String get idlePauseTip =>
      'Genişləndirilmiş dövr smartctl, sensors və amd-smi işlədir. Heç bir client sorğu göndərməyəndə onu dayandırmaq, heç kimin oxumadığı məlumat üçün diskin oyadılmasının qarşısını alır.';

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
      'Metrika: cpu / memory / swap / disk / network / temperature. Uyğunlaşdırıcı: bir nüvə üçün cpu0, yaddaş üçün used / free / avail, şəbəkə üçün rx / tx; disk və temperatur bunu nəzərə almır. Hədd: >=80%, >=70c və ya >10m/s kimi müqayisə operatoru və dəyər.';

  @override
  String get pushChannels => 'Bildiriş kanalları';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Agent-də təyin edilib, göstərilmir';

  @override
  String get pushSecretKeep => 'Saxlamaq üçün boş buraxın';

  @override
  String get pushTestTip =>
      'Saxlanıb-saxlanmamasından asılı olmayaraq, bu channel vasitəsilə cari parametrlərlə bir bildiriş göndərir.';

  @override
  String get pushTestSent => 'Channel bildirişi qəbul etdi';

  @override
  String get pushTestFailed => 'Channel bildirişi rədd etdi';

  @override
  String get pushTestMessage => 'ServerBox Monitor-dan sınaq bildirişi';

  @override
  String get pushUnknownType =>
      'Bu agent-də bu channel növü üçün göndərici yoxdur, buna görə parametrlər göstərilmir. Buradan silə və ya agent-in config.toml faylında redaktə edə bilərsiniz.';

  @override
  String get pushJsonInvalid => 'düzgün JSON deyil';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Söndürüldükdə agent heç nəyi silmir və database məhdudiyyətsiz böyüyür.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Təmizləməni bu aralıqla işə sal';

  @override
  String get retentionMaxDbSize => 'Database ölçüsü limiti';

  @override
  String get corsOrigins => 'İcazə verilən CORS origin-ləri';

  @override
  String get corsOriginsTip =>
      'Browser panel-in bu agent-ə müraciət edə biləcəyi origin-lər. Boş olduqda yalnız same-origin icazəlidir.';

  @override
  String get monitorNoRemoteAccess =>
      'Bu agent yalnız monitorinq üçündür. Buradan terminal aça, əmrlər işlədə və fayllara baxa bilməzsiniz. Bu funksiyaları aktivləşdirmək üçün agentin config.toml faylında [remote_access] bölməsini redaktə edin.';

  @override
  String get alerts => 'Xəbərdarlıqlar';

  @override
  String get online => 'onlayn';

  @override
  String get densityCards => 'Kartlar';

  @override
  String get densityRows => 'Sətirlər';

  @override
  String get densityGrid => 'Tor';

  @override
  String get connect => 'Qoşul';

  @override
  String get disconnect => 'Bağlantını kəs';

  @override
  String get searchServerTip =>
      'Adları və ünvanları axtarır — redaktorun əvvəlcə soruşduğu iki məlumatı.';

  @override
  String get addServerTip =>
      'Birini doldurun, QR kodu skan edin və ya kiminsə paylaşdığı faylı idxal edin.';

  @override
  String get move => 'Köçür';

  @override
  String get moveToTop => 'Ən yuxarıya köçür';

  @override
  String get moveToBottom => 'Ən aşağıya köçür';

  @override
  String get groupByTag => 'Teqə görə qruplaşdır';

  @override
  String get groupByTagTip =>
      'Teqlər serverin öz redaktə səhifəsində təyin edilir.';

  @override
  String get connecting => 'Qoşulur…';

  @override
  String get authShort => 'Auth';

  @override
  String get remoteDesktopFitToWindow => 'Pəncərəyə uyğunlaşdır';

  @override
  String get remoteDesktopActualSize => 'Həqiqi ölçü';

  @override
  String get remoteDesktopZoom => 'Miqyas';

  @override
  String get remoteDesktopViewOnly => 'Yalnız baxış';

  @override
  String get remoteDesktopDisableViewOnly => 'Yalnız baxışı söndür';

  @override
  String get remoteDesktopSendClipboardText =>
      'Mübadilə buferinin mətnini göndər';

  @override
  String get remoteDesktopShowKeyboard => 'Klaviaturanı göstər';

  @override
  String get remoteDesktopMoreControls => 'Digər idarəetmələr';

  @override
  String get remoteDesktopUseDirectPointer =>
      'Birbaşa göstəricidən istifadə et';

  @override
  String get remoteDesktopUseTouchpadPointer =>
      'Toxunma paneli göstəricisindən istifadə et';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Ctrl+Alt+Delete göndər';

  @override
  String get remoteDesktopReconnect => 'Yenidən qoşul';

  @override
  String get remoteDesktopFullScreen => 'Tam ekran';

  @override
  String get remoteDesktopExitFullScreen => 'Tam ekrandan çıx';

  @override
  String get remoteDesktopCloseSession => 'Sessiyanı bağla';

  @override
  String get remoteDesktopConnected => 'Qoşuldu';

  @override
  String get remoteDesktopConnecting => 'Qoşulur';

  @override
  String get remoteDesktopReconnecting => 'Yenidən qoşulur';

  @override
  String get remoteDesktopDisconnected => 'Bağlantı kəsildi';

  @override
  String get remoteDesktopGuideTouch => 'Toxunma paneli';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Bir barmaq göstəricini toxunma paneli kimi hərəkət etdirir, toxunmaq klikləyir. Sağ klik üçün iki barmaqla toxunun, sürüşdürmək üçün iki barmaqla çəkin, böyütmək üçün sıxın. Sürükləmək üçün iki dəfə toxunun və barmağı qaldırmayın.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Ekran klaviaturasını açır. Yazdıqlarınız uzaq masaüstünə göndərilir.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Göstərici və düymələrin göndərilməsini dayandırır ki, təsadüfən klikləmədən baxa biləsiniz.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Ctrl+Alt+Delete, yenidən qoşulma və tam ekran buradadır.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'Barmağın toxunduğu yeri klikləyən birbaşa göstərici də buradadır.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'VNC mübadilə buferi yalnız Latin-1 mətnini dəstəkləyir.';

  @override
  String get remoteDesktopAddProfile => 'Profil əlavə et';

  @override
  String get remoteDesktopNoProfiles => 'Uzaq masaüstü profili yoxdur';

  @override
  String get remoteDesktopAdd => 'Uzaq masaüstü əlavə et';

  @override
  String get remoteDesktopEdit => 'Uzaq masaüstünü redaktə et';

  @override
  String get remoteDesktopTargetTip =>
      'Hədəf SSH serveri və ya Monitor agenti tərəfindən tapılır. localhost həmin maşına işarə edir.';

  @override
  String get remoteDesktopDomain => 'Domen (istəyə bağlı)';

  @override
  String get remoteDesktopPassword => 'Parol (istəyə bağlı)';

  @override
  String get remoteDesktopSavePassword => 'Parolu yadda saxla';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Şifrələnmiş verilənlər bazasında saxlanılır. Ehtiyat nüsxələr saxlanılmış parolları ehtiva edir və yalnız ehtiyat parolu təyin edildikdə şifrələnir.';

  @override
  String get remoteDesktopShareSession => 'Sessiyanı paylaş';

  @override
  String get remoteDesktopProtocol => 'Protokol';

  @override
  String get remoteDesktopUniqueName =>
      'Bu server üçün profil adları unikal olmalıdır.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'Klassik VNC parolları 8 ASCII baytla məhdudlaşır.';

  @override
  String get remoteDesktopNameRequired => 'Profil adı daxil et.';

  @override
  String get remoteDesktopHostRequired => 'Hədəf host daxil et.';

  @override
  String get remoteDesktopPortRequired => 'Etibarlı port daxil et.';

  @override
  String get remoteDesktopUsernameRequired => 'RDP istifadəçi adını daxil et.';

  @override
  String get remoteDesktopNameInvalid =>
      'Profil adı ən çox 64 simvol ola bilər və sətir sonu ola bilməz.';

  @override
  String get remoteDesktopHostInvalid =>
      'Hədəf host boşluq və ya sətir sonu ehtiva edə bilməz.';

  @override
  String get remoteDesktopCredentialInvalid =>
      'İstifadəçi adı və domen ən çox 256 simvol ola bilər və sətir sonu ola bilməz.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Klassik VNC parolları yalnız ASCII simvollarından ibarət olmalıdır.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Sertifikatın təsdiqi tələb olunur';

  @override
  String get remoteDesktopWaiting => 'Masaüstü gözlənilir…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Uzaq masaüstü sertifikatı dəyişdi';

  @override
  String get remoteDesktopTrustCertificate => 'Sertifikata etibar edilsin?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'Sertifikatın barmaq izi saxlanılan dəyərlə uyğun gəlmir. Etibarı dəyişməzdən əvvəl yeni barmaq izini yoxla.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'Sistem bu sertifikatı yoxlaya bilmədi. Davam etməzdən əvvəl onun SHA-256 barmaq izini yoxla.';

  @override
  String get remoteDesktopReplaceTrust => 'Etibarı dəyiş';

  @override
  String get remoteDesktopTrustReconnect => 'Etibar et və yenidən qoşul';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return '“$name” uzaq masaüstü profili silinsin?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Yenidən qoşulur ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Əvvəllər etibar edilən\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Subyekt: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Veren: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Etibarlıdır: $start – $end';
  }

  @override
  String get pveAuthToken => 'API tokeni';

  @override
  String get pveVersionLow =>
      'Bu funksiya hazırda sınaq mərhələsindədir və yalnız PVE 8+ üzərində sınaqdan keçirilib. Ehtiyatla istifadə et.';

  @override
  String get pveTokenId => 'Token ID';

  @override
  String get pveTokenSecret => 'Token sirri';

  @override
  String get pveTokenTip =>
      'PVE-də Datacenter → Permissions → API Tokens bölməsində yaradın. Göstəriləcək yollarda VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit və Sys.Audit lazımdır; imtiyaz ayrılması açıqdırsa, bunları tokenin özünə verin.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return '$account tokeni bu hostda heç nə görə bilmir. İmtiyaz ayrılığı olan token istifadəçisinin icazələrini almır; PVE hostunda icazə verin:\n$command\nvə ya tokendə \"Privilege Separation\" seçimini götürün.';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account bu hostda heç nə görə bilmir. PVE hostunda icazə verin:\n$command';
  }

  @override
  String get pveTokenIdInvalid =>
      'Token ID user@realm!tokenid formatında olmalıdır';

  @override
  String get pvePasswordAuthTip =>
      'PAM realm-də SSH istifadəçisi kimi SSH parolu ilə, SSH açar istifadə edirsə aşağıdakı PVE parolu ilə daxil olur. Lazım olduqda iki faktorlu kod soruşulur.';

  @override
  String get pveCertUnpinned =>
      'Hələ təsdiqlənməyib. Etibarlı CA imzalamayıbsa, növbəti bağlantı sertifikatı təsdiq üçün göstərəcək.';

  @override
  String get pveCertForget => 'Sertifikatı unut';

  @override
  String get pveCertForgetTip =>
      'Növbəti bağlantı PVE sertifikatını yenidən təsdiq üçün göstərəcək.';

  @override
  String get virtualization => 'Virtuallaşdırma';

  @override
  String get virtIntro =>
      'Proxmox VE və libvirt/KVM hostlarında virtual maşınları və konteynerləri idarə edin: vəziyyət, enerji əməliyyatları və konsollar.';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE server səhifəsindən bu vərəqə köçürüldü. Serverin PVE kartı onu burada açır.';

  @override
  String get virtIntroLibvirt =>
      'libvirt-in virsh aləti quraşdırılmış server QEMU/KVM virtual maşınları ilə birlikdə host kimi görünür.';

  @override
  String get virtIntroTransports =>
      'Hər ikisi SSH ilə, Monitor agenti vasitəsilə və ya bu cihazda işləyir.';

  @override
  String get virtIntroTokens =>
      'PVE parol əvəzinə API tokeni ilə daxil ola bilər. Bunu serverin redaktə səhifəsində, PVE bölməsində təyin edin.';

  @override
  String get virtIntroInBar => 'Vərəq panelinə əlavə edildi.';

  @override
  String get virtIntroInMore =>
      'Daha çox bölməsindədir. Ayarlardakı Ana səhifə vərəqləri onu vərəq panelinə köçürə bilər.';

  @override
  String get virtGuests => 'Virtual maşınlar';

  @override
  String get virtHosts => 'Hostlar';

  @override
  String get virtCheckServer => 'Bu serveri yoxla';

  @override
  String get virtCheckAll => 'Bütün serverləri yoxla';

  @override
  String get virtProbeNotChecked => 'Hələ yoxlanılmayıb';

  @override
  String get virtProbeAbsent => 'Host deyil';

  @override
  String virtProbeContainer(String kind) {
    return '$kind konteyneri';
  }

  @override
  String get virtProbeContainerTip =>
      'Bu server konteynerdə işləyir, yəni host deyil, qonaqdır. Onu işlədən hostdan idarə olunur.';

  @override
  String get virtProbePve => 'PVE, qurulmayıb';

  @override
  String virtPveSetupTip(String version) {
    return 'Bu serverdə $version işləyir. Virtual maşınlarını və konteynerlərini burada idarə etmək üçün server ayarlarında API girişini doldurun (API tokeni tövsiyə olunur).';
  }

  @override
  String get virtNoHosts => 'Virtualizasiya hostu yoxdur';

  @override
  String get virtNoHostsTip =>
      'Proxmox VE işlədən və API girişi doldurulmuş server hostdur, virsh cavab verən server də. Digər serverləri host dəyişdiricisindən yoxlamaq olar.';

  @override
  String get virtNoGuests => 'Virtual maşın və ya konteyner yoxdur';

  @override
  String get virtPaused => 'Dayandırılıb';

  @override
  String get virtStarting => 'Başladılır…';

  @override
  String get virtStopping => 'Dayandırılır…';

  @override
  String get virtRebooting => 'Yenidən başladılır…';

  @override
  String get virtMigrating => 'Köçürülür…';

  @override
  String get virtBackingUp => 'Ehtiyat nüsxə çıxarılır…';

  @override
  String get virtResume => 'Davam et';

  @override
  String get virtOverview => 'İcmal';

  @override
  String get virtConsole => 'Konsol';

  @override
  String get virtConsoleNone => 'Bu qonaq üçün konsol qurulmayıb';

  @override
  String get virtConsoleGraphical => 'Qrafik';

  @override
  String get virtVncPasswordNeeded => 'Bu ekran parol tələb edir';

  @override
  String get virtConsoleSerialTip =>
      'Qonağın seriya konsolunu hostda virsh ilə açır. Bağlantını kəs və ya Ctrl+] hostun shell-inə qaytarır.';

  @override
  String virtConsoleVia(String transport) {
    return '$transport vasitəsilə';
  }

  @override
  String get virtConsoleEnterTip => 'Çıxış yoxdur? Enter basın';

  @override
  String virtConsoleAutoEnter(int seconds) {
    return 'Sorğunu göstərmək üçün $seconds saniyədən sonra Enter basılacaq';
  }

  @override
  String get virtConsoleEnterNow => 'İndi';

  @override
  String get virtOffTip =>
      'CPU, yaddaş, disk və şəbəkəni burada canlı görmək üçün başladın.';

  @override
  String get virtAllocated => 'Ayrılıb';

  @override
  String virtRunningCount(int running, int total) {
    return '$running işləyir · cəmi $total';
  }

  @override
  String get virtTemplate => 'Şablon';

  @override
  String get virtAutostart => 'Hostla birlikdə başlayır';

  @override
  String get virtErrUnreachable => 'Bu hosta çatmaq mümkün olmadı';

  @override
  String get virtErrNotConfigured => 'Bu serverin PVE ayarları natamamdır';

  @override
  String get virtErrNotConfiguredTip =>
      'Server ayarlarında ünvanı, həmçinin parolu və ya API tokenini yoxlayın.';

  @override
  String get virtErrAuthFailed => 'Host girişi rədd etdi';

  @override
  String get virtErrCertUnconfirmed => 'Hostun sertifikatını təsdiqləyin';

  @override
  String get virtErrCertChanged => 'Hostun sertifikatı dəyişib';

  @override
  String get virtErrRelayNotGranted => 'Monitor agenti bağlantıları ötürmür';

  @override
  String get virtErrExecNotGranted => 'Monitor agenti əmrləri icra etmir';

  @override
  String get virtErrNotInstalled => 'Bu serverdə virsh quraşdırılmayıb';

  @override
  String get virtErrServerRemoved => 'Bu server artıq mövcud deyil';

  @override
  String get virtErrSudoRequired =>
      'libvirt-ə çatmaq üçün sudo parol tələb edir';

  @override
  String get virtErrSudoRejected => 'sudo parolu rədd etdi';

  @override
  String get virtErrInvalidResponse => 'Host gözlənilməz formada cavab verdi';

  @override
  String get virtErrActionFailed => 'Host əməliyyatı rədd etdi';

  @override
  String get remoteSessionIdleTimeout => 'Tərk edildikdə bağla';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'Uzaq masaüstünü və ya qonağın konsolunu tərk etdikdən sonra bağlantının nə qədər açıq qalacağı. Bağlanmazdan əvvəl bildiriş onu saxlamaq üçün 10 saniyə verir.';

  @override
  String get remoteSessionKeepAlive => 'Açıq saxla';

  @override
  String get remoteSessionClosedAway => 'Fəaliyyətsizlik səbəbindən bağlandı';

  @override
  String remoteSessionClosingIn(int seconds) {
    return '$seconds san sonra bağlanır';
  }

  @override
  String get virtSnapshots => 'Snapshotlar';

  @override
  String get virtSnapshotCreate => 'Snapshot yarat';

  @override
  String get virtSnapshotNone => 'Hələ snapshot yoxdur';

  @override
  String get virtSnapshotWithMemory => 'Disklər və yaddaş';

  @override
  String get virtSnapshotDiskOnly => 'Yalnız disklər';

  @override
  String get virtSnapshotParent => 'Valideyn';

  @override
  String get virtSnapshotRevert => 'Geri qaytar';

  @override
  String get virtSnapshotMemory => 'Yaddaşı daxil et';

  @override
  String get virtSnapshotMemoryTip =>
      'Geri qaytardıqda qonaq bu andan davam edir.';

  @override
  String get virtSnapshotMemoryAlways =>
      'Burada işləyən qonağın snapshotu həmişə yaddaşı daxil edir.';

  @override
  String get virtSnapshotMemoryOff =>
      'Qonaq işləmir, ona görə yalnız diskləri saxlanılır.';

  @override
  String get virtSnapshotNameInvalid =>
      'Əvvəl hərf, sonra hərf, rəqəm, - və ya _; 2-dən 40-a qədər simvol.';

  @override
  String get virtSnapshotNameTaken => 'Bu adda snapshot artıq var.';

  @override
  String get virtSnapshotRevertTip =>
      'Geri qaytarmaq snapshotdan sonrakı bütün dəyişiklikləri silir.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return '$guest $snapshot vəziyyətinə qaytarılsın? O vaxtdan bəri bütün dəyişikliklər itəcək.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'Bu snapshotda yaddaş yoxdur: $guest dayandırılacaq.';
  }

  @override
  String get virtSnapshotStartAfter => 'Sonra başlat';

  @override
  String get virtVolumes => 'Həcmlər';

  @override
  String get virtNoPools => 'Yaddaş hovuzu yoxdur';

  @override
  String get virtNoNetworks => 'Şəbəkə yoxdur';

  @override
  String get virtPoolInactive =>
      'Hovuz aktiv deyil, ona görə həcmləri siyahılana bilmir.';

  @override
  String get virtShared => 'Qovşaqlar arasında paylaşılır';

  @override
  String get virtBackingFile => 'Əsas fayl';

  @override
  String get virtNetIsolated => 'Təcrid olunmuş';

  @override
  String get virtNetBridged => 'Körpü';

  @override
  String get virtNetRouted => 'Marşrutlaşdırılmış';

  @override
  String get virtBridge => 'Körpü';

  @override
  String get virtPorts => 'Portlar';

  @override
  String get virtAttachedGuests => 'Qoşulmuş qonaqlar';

  @override
  String get virtNoAttachedGuests => 'Qoşulmuş qonaq yoxdur';

  @override
  String get virtCreateVm => 'Yeni virtual maşın';

  @override
  String get virtCreateLxc => 'Yeni konteyner';

  @override
  String get virtCreateGuest => 'Yeni virtual maşın və ya konteyner';

  @override
  String get virtKindVm => 'Virtual maşın';

  @override
  String get virtKindLxc => 'Konteyner';

  @override
  String get virtHostname => 'Host adı';

  @override
  String get virtInstallMedia => 'Quraşdırma mediası';

  @override
  String get virtNoIsos => 'Bu hostda ISO şəkli yoxdur';

  @override
  String get virtNoTemplates =>
      'Bu hostda konteyner şablonu yoxdur. PVE-də yaddaşın CT Şablonları bölməsindən yükləmək olar.';

  @override
  String get virtNoDiskStorage =>
      'Bu hostda yeni disk qəbul edən yaddaş yoxdur';

  @override
  String get virtStartAfterCreate => 'Yaradandan sonra başlat';

  @override
  String get virtUnprivileged => 'İmtiyazsız konteyner';

  @override
  String get virtUnprivilegedTip => 'Onun root-u hostda adi istifadəçidir.';

  @override
  String get virtSshKeys => 'SSH açıq açarları';

  @override
  String get virtCredentialsTip => 'root parolu, SSH açarları və ya hər ikisi.';

  @override
  String virtCreated(String name) {
    return '$name yaradıldı';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '$name yaradıldı, amma başlamadı';
  }

  @override
  String get virtErrExists => 'Bu adda qonaq və ya disk artıq var';

  @override
  String get virtCreateNameInvalidLibvirt =>
      'Hərflər, rəqəmlər, ., _ və -, hərf və ya rəqəmlə başlayır; 63 simvola qədər.';

  @override
  String get virtCreateNameInvalidPve =>
      'Hərflər, rəqəmlər və -, nöqtələrlə ayrılmış hissələr; 63 simvola qədər.';

  @override
  String get virtCreateNameTaken => 'Bu adda qonaq var.';

  @override
  String get virtCreateVmidTaken => 'Bu VMID məşğuldur.';

  @override
  String get virtCreateCoresInvalid => 'Bu hostun icazə verdiyindən çox nüvə.';

  @override
  String get virtCreateMemoryInvalid => 'Yaddaş kifayət deyil.';

  @override
  String get virtCreateStorageMissing => 'Diskin harada olacağını seçin.';

  @override
  String get virtCreateDiskInvalid => '1 GiB-dən 64 TiB-a qədər.';

  @override
  String get virtCreateTemplateMissing => 'Şablon seçin.';

  @override
  String get virtCreateCredentialsMissing =>
      'root parolu və ya SSH açarı təyin edin.';

  @override
  String virtCreatePasswordShort(int min) {
    return 'Ən azı $min simvol.';
  }

  @override
  String get virtCreateSshKeysInvalid => 'Hər sətirdə bir OpenSSH açıq açarı.';

  @override
  String get virtDeleteDisks => 'Disklərini də sil';

  @override
  String get virtDeleteDisksPve =>
      'Diskləri onunla birlikdə silinir; quraşdırma mediası saxlanılır.';

  @override
  String virtDeleted(String name) {
    return '$name silindi';
  }

  @override
  String get pveTokenTipCreate =>
      'Qonaq yaratmaq və silmək üçün həmçinin VM.Allocate, VM.Config.*, Datastore.AllocateSpace və SDN.Use lazımdır.';

  @override
  String get pveTokenTipHardware =>
      'Avadanlığı redaktə etmək üçün VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.CDROM, VM.Config.Network və VM.Config.Options lazımdır; yeni disklər və interfeyslər üçün həmçinin Datastore.AllocateSpace və SDN.Use lazımdır. Video kart, USB və PCI cihazları üçün VM.Config.HWType da lazımdır; resurs xəritəsi ilə verilən cihaz üçün onun üzərində Mapping.Use, xəritələri siyahılamaq üçün Mapping.Audit lazımdır.';

  @override
  String get pveTokenTipBackup =>
      'Klonlama VM.Clone, yedəkləmə və bərpa VM.Backup, şablona çevirmə VM.Allocate tələb edir; yedəkləmə işləri həmçinin oxumaq üçün Sys.Audit, yaratmaq, düzəltmək və silmək üçün / üzərində Sys.Modify tələb edir; kopyanın və ya yedəyin getdiyi yerdə Datastore.AllocateSpace də lazımdır.';

  @override
  String get virtErrConflict => 'Başqa yerdə dəyişdirilib';

  @override
  String get virtErrConflictTip =>
      'Bu konfiqurasiya burada oxunandan sonra başqası tərəfindən dəyişdirildi, ona görə heç nə dəyişdirilmədi. Yenidən oxundu: hələ lazımdırsa dəyişikliyi təkrar edin.';

  @override
  String get virtHardware => 'Avadanlıq';

  @override
  String get virtHwAddDisk => 'Disk əlavə et';

  @override
  String get virtHwAddMount => 'Qoşulma nöqtəsi əlavə et';

  @override
  String get virtHwAddNic => 'Şəbəkə interfeysi əlavə et';

  @override
  String get virtHwAppliesOnRestart =>
      'Yadda saxlanıldı. Növbəti başlanğıcda qüvvəyə minir.';

  @override
  String get virtHwAutostart => 'Hostla birlikdə başlat';

  @override
  String get virtHwAutostartPve => 'onboot · VMID sırası ilə başladılır';

  @override
  String get virtHwBalloonLibvirt => 'Cari yaddaş';

  @override
  String get virtHwBalloonNote =>
      'Yaddaş azaldıqda hostun qonağın boş yaddaşını geri almasına icazə verir';

  @override
  String get virtHwBoot => 'Yükləmə';

  @override
  String get virtHwBootOrder => 'Yükləmə sırası';

  @override
  String get virtHwBootTip =>
      'Oxlar cihazı yerini dəyişir; toxunmaq ondan yükləməni açır və ya bağlayır.';

  @override
  String get virtHwCdrom => 'CD-ROM';

  @override
  String get virtHwConfigFile => 'Konfiqurasiya faylı';

  @override
  String get virtHwCores => 'Nüvələr';

  @override
  String get virtHwCpuTypeDefault => 'Standart';

  @override
  String get virtHwDeleteVolume => 'Həcmini də sil';

  @override
  String get virtHwDetach => 'Ayır';

  @override
  String get virtHwDiskHotplug => 'İsti qoşulma: işləyərkən əlavə edilə bilər';

  @override
  String get virtHwDisksLxc => 'Kök disk və qoşulma nöqtələri';

  @override
  String get virtHwEject => 'Çıxar';

  @override
  String get virtHwEmpty => 'Daşıyıcı yoxdur';

  @override
  String get virtHwFirewall => 'Təhlükəsizlik divarı';

  @override
  String virtHwFree(String size) {
    return '$size boş';
  }

  @override
  String get virtHwGrow => 'Böyüt';

  @override
  String get virtHwGrowNote => 'Disklər yalnız böyüdülə bilər.';

  @override
  String get virtHwGrowNoteRunning =>
      'Disklər yalnız böyüyür. İşləyərkən böyüdülübsə, bölmə qonaqda genişləndirilməlidir.';

  @override
  String get virtHwGuestUsed => 'Qonağın istifadə etdiyi';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'Host $threads axın · $allocated ayrılıb';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'Host $total · $allocated ayrılıb';
  }

  @override
  String get virtHwHotplugNow => 'İsti qoşulma: dərhal qüvvəyə minir.';

  @override
  String get virtHwIssueBootEmpty => 'Ən azı bir cihaz işarələyin';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'Cəmi 1 ilə $max vCPU arası';
  }

  @override
  String get virtHwIssueCpuOnline => 'Aktiv vCPU-lar: 1-dən cəmə qədər';

  @override
  String get virtHwIssueDiskShrink =>
      'İndikindən böyük olmalıdır: disklər yalnız böyüyür';

  @override
  String get virtHwIssueDiskSize => '1 ilə 65536 GiB arası';

  @override
  String virtHwIssueMemory(int min, int max) {
    return '$min ilə $max MiB arası';
  }

  @override
  String get virtHwIssueMemoryMin => 'Yaddaşdan çox olmamalıdır';

  @override
  String get virtHwIssueMountPoint => '/data kimi mütləq yol';

  @override
  String get virtHwIssueStorageSpace => 'Yaddaşdakı boş yerdən çoxdur';

  @override
  String get virtHwIssueSwap => 'Mənfi olmamalıdır';

  @override
  String get virtHwLater => 'Yenidən başladıqda qüvvəyə minir';

  @override
  String get virtHwLess => 'Azalt';

  @override
  String get virtHwLinkDown => 'Ayrılıb';

  @override
  String get virtHwLinkNote =>
      'Söndürüldükdə qonaq kabelin çıxarıldığını görür; yenidən başlatma lazım deyil';

  @override
  String get virtHwLinkUp => 'Qoşulub';

  @override
  String get virtHwMac => 'MAC ünvanı';

  @override
  String get virtHwModel => 'Model';

  @override
  String get virtHwMore => 'Artır';

  @override
  String get virtHwMountFromPool =>
      'Qoşulma nöqtələri birbaşa yaddaşdan ayrılır';

  @override
  String get virtHwMountPoint => 'Qoşulma nöqtəsi';

  @override
  String get virtHwMoveDown => 'Aşağı';

  @override
  String get virtHwMoveUp => 'Yuxarı';

  @override
  String get virtHwNewDisk => 'Yeni disk';

  @override
  String get virtHwNewMount => 'Yeni qoşulma nöqtəsi';

  @override
  String get virtHwNewNic => 'Yeni şəbəkə interfeysi';

  @override
  String get virtHwNicHotplug =>
      'virtio interfeysləri isti qoşulmanı dəstəkləyir';

  @override
  String get virtHwNics => 'Şəbəkə interfeysləri';

  @override
  String get virtHwNoMedia => 'Daşıyıcı yoxdur';

  @override
  String get virtHwNoNetworks => 'Burada şəbəkə və ya körpü yoxdur';

  @override
  String get virtHwNoStorage => 'Burada disk qəbul edən yaddaş yoxdur';

  @override
  String get virtHwOnline => 'Aktiv vCPU-lar';

  @override
  String get virtHwPendingBanner =>
      'Bəzi avadanlıq dəyişiklikləri yenidən başladıqda qüvvəyə minir';

  @override
  String get virtHwPickNet => 'Şəbəkə seçin';

  @override
  String get virtHwPickPool => 'Yaddaş və ölçü seçin';

  @override
  String get virtHwProcessor => 'Prosessor';

  @override
  String get virtHwRemove => 'Çıxar';

  @override
  String get virtHwRemoveCdrom => 'CD-ROM-u çıxar';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return '$disk $guest qonağından çıxarılsın?';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return '$nic $guest qonağından çıxarılsın?';
  }

  @override
  String get virtHwResources => 'Resurslar';

  @override
  String get virtHwRestartNow => 'İndi yenidən başlat';

  @override
  String get virtHwRevert => 'Geri qaytar';

  @override
  String get virtHwRevertAll => 'Hamısını geri qaytar';

  @override
  String get virtSetRenameStopped =>
      'Adını dəyişmək üçün qonağı söndürün: libvirt yalnız işləməyən qonağın adını dəyişir.';

  @override
  String virtSetIssueDescription(int max) {
    return 'Ən çox $max bayt (UTF-8), idarəetmə simvolları olmadan.';
  }

  @override
  String get virtSetManualStart => 'Əllə başladılır';

  @override
  String get virtSetProtection => 'Qoruma';

  @override
  String get virtSetProtectionNote =>
      'Qonağın silinməsini və disklərinin dəyişdirilməsini qadağan edir';

  @override
  String get virtSetIrreversible => 'Geri qaytarıla bilməz';

  @override
  String get virtSetDeleteStopFirst => 'Silməzdən əvvəl söndürün.';

  @override
  String get virtSetDeleteProtected =>
      'Qoruma aktivdir: əvvəlcə Ümumi bölməsində söndürün.';

  @override
  String get virtSetDeleteAgain => 'Təsdiqləmək üçün yenidən basın';

  @override
  String virtSetDeleteConfirm(String name) {
    return '$name sil';
  }

  @override
  String get virtSetDeleteVm => 'Virtual maşını sil';

  @override
  String get virtSetDeleteLxc => 'Konteyneri sil';

  @override
  String get virtHwSockets => 'Soketlər';

  @override
  String get virtHwSource => 'Mənbə';

  @override
  String get virtHwSwap => 'Swap';

  @override
  String get virtHwTopology => 'Soket × nüvə';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets soket × $cores nüvə × $threads axın';
  }

  @override
  String virtHwTotal(String size) {
    return 'cəmi $size';
  }

  @override
  String get virtHwVolumeKept =>
      'Çıxarıldı, lakin işləyən qonaq diski hələ istifadə edir, ona görə həcmi saxlanıldı. Növbəti başlanğıcda ayrılacaq.';

  @override
  String get virtHwBus => 'Şin';

  @override
  String get virtHwCache => 'Keş';

  @override
  String get virtHwBusStopped => 'Şin yalnız qonaq dayandırılanda dəyişir.';

  @override
  String get virtHwMacGenerate => 'Yarat';

  @override
  String get virtHwIssueMac =>
      'Unicast MAC ünvanı olmalıdır, məs. 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => 'Əvvəlcə qonağı dayandırın';

  @override
  String get virtHwIssueStorageMissing => 'Əvvəlcə yaddaş seçin';

  @override
  String get virtHwIssueDevice => 'Əvvəlcə cihaz seçin';

  @override
  String get virtHwDevices => 'CD-ROM və ötürmə';

  @override
  String get virtHwDevicesEmpty => 'USB və PCI ötürməsi, CD-ROM, TPM';

  @override
  String get virtHwAddDevice => 'Cihaz əlavə et';

  @override
  String get virtHwNewDevice => 'Yeni cihaz';

  @override
  String get virtHwUsbHotplug => 'USB ötürməsi isti qoşulmanı dəstəkləyir.';

  @override
  String get virtHwPci => 'PCI ötürməsi';

  @override
  String get virtHwIommuOffTitle => 'Hostda IOMMU yoxdur';

  @override
  String get virtHwIommuOffBody =>
      'Əvvəlcə hostun BIOS-unda VT-d və ya AMD-Vi-ni, nüvəsində IOMMU-nu açın. O vaxta qədər PCI cihazı verilmiş qonaq başlamayacaq.';

  @override
  String get virtHwPciTitle => 'Hostda IOMMU tələb olunur';

  @override
  String get virtHwPciBody =>
      'Ötürüldükdən sonra host cihazdan istifadə edə bilməz, qonaq da işləyərkən köçürülə bilməz.';

  @override
  String virtHwIommuGroup(int group) {
    return 'IOMMU qrupu $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return 'IOMMU qrupunu paylaşan $count cihaz birlikdə ötürülür';
  }

  @override
  String get virtHwNoHostDevices => 'Bu hostda ötürüləcək cihaz yoxdur';

  @override
  String get virtHwMappingsOnly =>
      'Burada yalnız resurs xəritələri istifadə oluna bilər: PVE xam cihaz ötürməyə yalnız parolu ilə daxil olmuş root@pam-a icazə verir. Xəritələri Data mərkəzi → Resurs xəritələri bölməsində yaradın.';

  @override
  String get virtHwTpmNote => 'Windows 11 TPM 2.0 tələb edir.';

  @override
  String get virtHwDisplay => 'Ekran';

  @override
  String get virtHwProtocol => 'Protokol';

  @override
  String get virtHwListen => 'Dinləmə';

  @override
  String get virtHwGpu => 'Video kart';

  @override
  String get virtHwListenAllTitle => 'Konsol şəbəkəyə açıqdır';

  @override
  String get virtHwListenAllBody =>
      'Bütün ünvanlarda dinləmək hosta çatan hər kəsə konsola qoşulmağa imkan verir. 127.0.0.1-də saxlayın və SSH tuneli ilə qoşulun.';

  @override
  String get virtHwFirmware => 'Proqram təminatı';

  @override
  String get virtHwUefiSub =>
      'OVMF · Secure Boot dəstəkli, Windows 11 üçün lazımdır';

  @override
  String get virtHwBiosSub => 'SeaBIOS · köhnə sistemlər və MBR diskləri';

  @override
  String get virtHwSecureBootNote =>
      'Yalnız imzalı nüvə və yükləyiciləri başladır';

  @override
  String get virtHwFirmwareWarnTitle =>
      'Quraşdırılmış sistemin proqram təminatını dəyişməyin';

  @override
  String get virtHwFirmwareWarnBody =>
      'UEFI ilə BIOS arasında keçid quraşdırılmış sistemi yüklənməz edir.';

  @override
  String get virtHwFirmwareStopped =>
      'Proqram təminatı yalnız qonaq dayandırılanda dəyişir.';

  @override
  String get virtHwSecureBootVars =>
      'Secure Boot-u açıb-söndürmək EFI dəyişənlərini yenidən yaradır; onlarda saxlanan yükləmə qeydləri itir.';

  @override
  String get virtHwEfiStorage => 'EFI dəyişənlərinin yeri';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return '$guest $firmware rejiminə keçirilsin?';
  }

  @override
  String get virtCloneName => 'Yeni ad';

  @override
  String get virtCloneFull => 'Tam klon';

  @override
  String get virtCloneCopyDisks => 'Disk məzmununu kopyala';

  @override
  String get virtCloneLinkedNote =>
      'Söndürülü: şablonun disklərindən asılı bağlı klon';

  @override
  String get virtCloneFullOnly =>
      'Yalnız şablon bağlı klon kimi klonlana bilər';

  @override
  String get virtCloneEmptyNote => 'Söndürülü: eyni ölçüdə yeni boş disklər';

  @override
  String get virtCloneStopFirst => 'Klonlamadan əvvəl söndürün.';

  @override
  String get virtCloneFullShort => 'Tam';

  @override
  String get virtCloneLinkedShort => 'Bağlı';

  @override
  String get virtCloneEmptyShort => 'Boş disklər';

  @override
  String get virtCloning => 'Klonlanır…';

  @override
  String virtCloned(String name) {
    return '$name kimi klonlandı';
  }

  @override
  String get virtBackupPlan => 'Plan';

  @override
  String get virtBackupPlanWhere => 'Məlumat mərkəzi → Ehtiyat nüsxə';

  @override
  String get virtBackupNoPlanShort => 'Plan yoxdur';

  @override
  String get virtBackupNoPlan =>
      'Bu qonağı əhatə edən planlı ehtiyat nüsxə işi yoxdur.';

  @override
  String get virtBackupKeep => 'Saxla';

  @override
  String get virtBackupJobDisabled => 'Bu iş deaktivdir.';

  @override
  String virtBackupCount(int count) {
    return '$count nüsxə';
  }

  @override
  String virtSnapshotCount(int count) {
    return '$count snapshot';
  }

  @override
  String get virtBackupNoStorage =>
      'Bu qovşaqda ehtiyat nüsxələri saxlayan anbar yoxdur.';

  @override
  String get virtBackupLiveTip => 'İşləyir: snapshot rejimi, dayanmadan';

  @override
  String get virtBackupStoppedTip => 'Söndürülüb: olduğu kimi nüsxələnir';

  @override
  String get virtBackupNow => 'İndi nüsxələ';

  @override
  String get virtBackupNotes => 'Qeydlər';

  @override
  String get virtBackupProtected =>
      'Qorunur: qoruma PVE-də götürülənə qədər silinə bilməz.';

  @override
  String virtBackupVerified(String state) {
    return 'Yoxlama: $state';
  }

  @override
  String get virtBackupRestoreOverwrites => 'Bərpa cari diskləri üzərinə yazır';

  @override
  String get virtBackupStopFirst => 'Bərpadan əvvəl söndürün.';

  @override
  String get virtBackupRestoreAgain =>
      'Qonağın diskləri və konfiqurasiyası nüsxədəkilərlə əvəz olunur.';

  @override
  String get virtBackupDeleteConfirm => 'Nüsxəni sil';

  @override
  String get virtBackupRestoreNew => 'Yeni kimi bərpa et';

  @override
  String get virtBackupRestoreConfirm => 'Üzərinə bərpa et';

  @override
  String get virtBackupDone => 'Nüsxə hazırdır';

  @override
  String get virtBackupDeleted => 'Nüsxə silindi';

  @override
  String virtBackupRestored(String time) {
    return '$time tarixindən bərpa edildi';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return '$account hesabının $path üzərində $privilege icazəsi yoxdur. PVE hostunda verin:\n$command';
  }

  @override
  String get virtCanDelete => 'Silinə bilər';

  @override
  String get virtInUse => 'İstifadədədir';

  @override
  String get virtOps => 'Əməliyyatlar';

  @override
  String get virtPool => 'Yaddaş hovuzu';

  @override
  String get virtPoolNew => 'Yeni yaddaş hovuzu';

  @override
  String get virtStorageAdd => 'Yaddaş əlavə et';

  @override
  String virtPoolUsedPct(String pct) {
    return '$pct% istifadə olunub';
  }

  @override
  String get virtPoolInUse =>
      'Bir VM buradakı həcmdən istifadə edir, hovuzu dayandırmaq və ya silmək olmaz.';

  @override
  String get virtPoolDelete => 'Hovuzu sil';

  @override
  String get virtStorageRemove => 'Yaddaşı çıxar';

  @override
  String virtPoolDeleteAsk(String name) {
    return '$name hovuzu silinsin? Tərifi silinir, həcmləri yerində qalır.';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return '$name yaddaşı PVE konfiqurasiyasından çıxarılsın? İçindəkilər qalır.';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return '$count həcmi diskdə qalır.';
  }

  @override
  String get virtPoolDeleteStorage => 'Qovluğunu da sil (yalnız boşdursa)';

  @override
  String virtPoolStopAsk(String name) {
    return '$name hovuzu dayandırılsın? Yenidən başlayana qədər həcmlər siyahılanmır və yaradılmır.';
  }

  @override
  String get virtStorageClusterWide =>
      'Bu, klasterdə bu yaddaşa malik hər bir node-a aiddir.';

  @override
  String get virtStorageDisable => 'Deaktiv et';

  @override
  String get virtStorageEnable => 'Aktiv et';

  @override
  String virtStorageDisableAsk(String name) {
    return '$name yaddaşı söndürülsün? Diskləri orada olan VM-lər yenidən aktivləşənə qədər başlamaz.';
  }

  @override
  String get virtPoolLogicalNote =>
      'Mövcud həcm qrupu olduğu kimi istifadə olunur; heç nə formatlanmır.';

  @override
  String get virtPoolMountPoint => 'Bağlama nöqtəsi';

  @override
  String get virtPoolSourceNfs => 'Mənbə (host:/yol)';

  @override
  String get virtPoolSourceVg => 'Həcm qrupu';

  @override
  String get virtPoolSourceThin => 'Həcm qrupu / thin pool';

  @override
  String get virtPoolSourceZfs => 'ZFS hovuzu';

  @override
  String get virtPoolTypeVg => 'LVM həcm qrupu';

  @override
  String get virtResNameEmpty => 'Ad daxil edin';

  @override
  String get virtResNotFound => 'Artıq bu hostda deyil';

  @override
  String get virtResUnsupported => 'Bu host bunu etmir';

  @override
  String get virtResNameInvalid =>
      'Bu hostun qəbul etdiyi ad deyil (hərf, rəqəm, . _ -)';

  @override
  String get virtResSourceInvalid => 'Etibarlı yol və ya mənbə deyil';

  @override
  String get virtResTargetInvalid => 'Mütləq yol';

  @override
  String get virtResCidrInvalid => 'Prefiksli ünvan, məs. 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid =>
      'Şəbəkədə ardıcıl iki ünvan, hostun ünvanı olmadan';

  @override
  String get virtResSubnetTaken => 'Buradakı başqa şəbəkə bu alt şəbəkədədir';

  @override
  String get virtResBridgeInvalid => 'İnterfeys adı deyil';

  @override
  String get virtResFormat => 'Bu hovuz bu formatı dəstəkləmir';

  @override
  String get virtVolNew => 'Yeni həcm';

  @override
  String virtVolCount(int count) {
    return '$count həcm';
  }

  @override
  String get virtVolNone => 'Bu hovuzda hələ həcm yoxdur.';

  @override
  String get virtVolEmptyAttach =>
      'Yeni həcmi sonra istənilən VM-ə qoşmaq olar';

  @override
  String get virtVolEmptyUpload => 'ISO birbaşa da yüklənə bilər';

  @override
  String get virtVolPveName =>
      'PVE həcmi VM-inə görə adlandırır: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => 'İstifadə edən';

  @override
  String get virtVolAllocated => 'Ayrılıb';

  @override
  String get virtVolGrowFromGuest =>
      'VM istifadə edir: həmin VM-in Avadanlıq görünüşündən böyüdün';

  @override
  String get virtVolInUse => 'Bu həcmdən VM istifadə edir';

  @override
  String virtVolBackingOf(String names) {
    return '$names üçün əsas fayl';
  }

  @override
  String get virtVolIsBase =>
      'Digər həcmlər bunun üzərində qurulub; silmək onları korlayar';

  @override
  String get virtVolAttach => 'VM-ə qoş';

  @override
  String get virtVolAttachNote =>
      'İlk diskinin olduğu şinə yeni disk kimi qoşulur';

  @override
  String virtVolAttached(String name) {
    return '$name maşınına qoşuldu';
  }

  @override
  String get virtVolInsert => 'CD-ROM-a tax';

  @override
  String virtVolInserted(String name) {
    return '$name CD-ROM sürücüsünə taxıldı';
  }

  @override
  String virtVolNoCdrom(String name) {
    return '$name maşınında CD-ROM sürücüsü yoxdur';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return '$name həcmi $pool hovuzundan silinsin? İçindəkilər həmişəlik itir.';
  }

  @override
  String get virtUploadIso => 'ISO yüklə';

  @override
  String virtUploadTo(String pool) {
    return '$pool hovuzuna yüklə';
  }

  @override
  String virtUploadDone(String name) {
    return '$name yükləndi';
  }

  @override
  String get virtNetConfig => 'Konfiqurasiya';

  @override
  String get virtNetConfigFile => 'Konfiqurasiya faylı';

  @override
  String get virtNetInternal => 'Daxili';

  @override
  String get virtNetBridgePorts => 'Körpü portları';

  @override
  String get virtNetHostBridge => 'Host körpüsü';

  @override
  String get virtNetPortsHint => 'eno2; daxili körpü üçün boş';

  @override
  String get virtNetDhcpRange => 'DHCP aralığı';

  @override
  String get virtNetDhcpTip => 'dnsmasq VM-lərə ünvan verir';

  @override
  String get virtNetVlanTip => 'VM şəbəkə kartları VLAN teqi daşıya bilər';

  @override
  String get virtNetNatTip =>
      'Host vasitəsilə: VM-lər çölə çıxır, çöldən daxil olmaq olmur';

  @override
  String get virtNetRoutedTip =>
      'NAT olmadan host yönləndirir: LAN-da geri marşrut lazımdır';

  @override
  String get virtNetIsolatedTip => 'Yalnız VM-lər və host bir-birinə çatır';

  @override
  String get virtNetBridgedTip =>
      'VM-lər hostun körpüsünə, fiziki şəbəkəsinə qoşulur';

  @override
  String get virtNetNew => 'Yeni şəbəkə';

  @override
  String get virtNetNewBridge => 'Yeni Linux körpüsü';

  @override
  String get virtNetVirtual => 'Virtual şəbəkə';

  @override
  String get virtNetDelete => 'Şəbəkəni sil';

  @override
  String virtNetDeleteAsk(String name) {
    return '$name şəbəkəsi silinsin? Dayandırılır və tərifi silinir.';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return '$name körpüsü $node üzərindən çıxarılsın? İndi gözləyən konfiqurasiyadan, tətbiq ediləndə isə hostdan çıxır.';
  }

  @override
  String virtNetInUse(int count) {
    return 'Üzərindəki VM: $count. Silinə bilməz.';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return '$name dayandırılsın? Üzərindəki $count VM yenidən başlayana qədər şəbəkəsiz qalır.';
  }

  @override
  String get virtNetInactivePve =>
      'Aktiv deyil: yeni körpü tətbiq olunana qədər gözləyən konfiqurasiyadadır.';

  @override
  String get virtNetPveApplyNote =>
      'Gözləyən dəyişiklik kimi saxlanılır; konfiqurasiya tətbiq olunanda qüvvəyə minir (ifreload -a).';

  @override
  String get virtNetPendingSaved =>
      'Gözləyən kimi saxlanıldı: qüvvəyə minməsi üçün konfiqurasiyanı tətbiq edin';

  @override
  String virtNetPendingTitle(String node) {
    return '$node üzərində gözləyən şəbəkə dəyişiklikləri';
  }

  @override
  String get virtNetPendingTip =>
      'PVE şəbəkə dəyişikliklərini tətbiq olunana qədər interfaces.new-da saxlayır.';

  @override
  String get virtNetPendingShow => 'Dəyişiklikləri göstər';

  @override
  String get virtNetApply => 'Konfiqurasiyanı tətbiq et';

  @override
  String virtNetApplyAsk(String node) {
    return '$node üzərində gözləyən şəbəkə konfiqurasiyası tətbiq edilsin? PVE hostun şəbəkəsini yenidən yükləyir (ifreload -a): səhv hostu əlçatmaz edə bilər.';
  }

  @override
  String virtNetRevertAsk(String node) {
    return '$node üzərində gözləyən şəbəkə konfiqurasiyası atılsın?';
  }

  @override
  String get pveTokenTipStorage =>
      'Yaddaşın idarəsi /storage üzərində Datastore.Allocate (əlavə, söndürmə, çıxarma), Datastore.AllocateSpace (həcmlər) və Datastore.AllocateTemplate (yükləmələr) tələb edir; Linux körpüləri və şəbəkə konfiqurasiyasının tətbiqi node-da Sys.Modify tələb edir.';

  @override
  String get virtCreateUnnamed => 'Adsız';

  @override
  String get virtCreateNotChosen => 'Seçilməyib';

  @override
  String get virtCreateKindVmSub => 'qm · tam KVM virtual maşın';

  @override
  String get virtCreateKindLxcSub =>
      'pct · hostun nüvəsini paylaşır, daha yüngül';

  @override
  String get virtCloudImage => 'Bulud təsviri';

  @override
  String get virtCloudImageTip =>
      'Üzərində sistem olan disk: kopyalanır, Yaddaş bölməsindəki ölçüyə böyüdülür və ilk açılışda cloud-init tərəfindən qurulur. Təsvirin özü olduğu kimi qalır.';

  @override
  String get virtNoCloudImagesLibvirt =>
      'Burada bulud təsviri yoxdur: heç bir VM-in istifadə etmədiyi qcow2 və ya raw təsvirini hovuza qoyun (Yaddaşda yükləyin).';

  @override
  String get virtNoCloudImagesPve =>
      'Burada bulud təsviri yoxdur: qcow2, raw və ya vmdk təsvirini Import məzmun növlü yaddaşa yükləyin (PVE 8.2+).';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 UEFI və TPM 2.0 tələb edir';

  @override
  String get virtCreateWindowsBody => 'Yuxarıda UEFI seçin və TPM-i yandırın.';

  @override
  String get virtCreateWindowsNoTpm =>
      'Bu hostda proqram TPM-i (swtpm) yoxdur: VM-ə vermək üçün quraşdırın.';

  @override
  String virtCreateImageSize(String size) {
    return 'Təsvir $size-dır: disk ən azı bu qədər olmalıdır.';
  }

  @override
  String get virtCreateImageMissing => 'Bulud təsviri seçin.';

  @override
  String get virtCreateIncomplete =>
      'Əvvəlcə narıncı ilə işarələnmiş hissələri tamamlayın.';

  @override
  String virtCreateOn(String host) {
    return '$host üzərində yaradılır';
  }

  @override
  String get virtCiTip =>
      'sudo icazəli hesab; parol, SSH açarı və ya hər ikisi ilə daxil olunur.';

  @override
  String get virtCiUserInvalid =>
      'Kiçik hərflər, rəqəmlər, _ və -; hərf və ya _ ilə başlamalı';

  @override
  String get virtCiCredentialsMissing => 'Parol və ya SSH açarı təyin edin.';

  @override
  String get virtCiHostnamePve => 'Host adı VM-in adıdır.';

  @override
  String get virtCiStatic => 'Statik';

  @override
  String get virtCiAddressInvalid =>
      'Prefiksli IPv4 ünvanı, məsələn 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'IPv4 ünvanı, məsələn 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => 'Boş: DHCP-dən';

  @override
  String get virtCiDnsInvalid => 'Boşluq və ya vergüllə ayrılmış IP ünvanları';

  @override
  String get virtCiSearch => 'Axtarış domeni';

  @override
  String get virtCiSeedNote =>
      'Diskin yanındakı kiçik ISO-ya yazılır, CD-ROM kimi qoşulur və VM ilə birlikdə silinir. Parolun yalnız heşi saxlanılır.';

  @override
  String get virtCiNoToolTitle =>
      'Hostda cloud-init məlumatını yaratmaq üçün alət yoxdur';

  @override
  String virtCiNoToolBody(String tools) {
    return 'Hosta $tools alətlərindən birini quraşdırın. cloud-init olmadan təsvir daxil olmaq üçün hesabsız başlayır.';
  }

  @override
  String get virtHwCloudInitNote =>
      'cloud-init-in ilk açılışda oxuduğu məlumat. Quraşdırma mediası deyil: bura heç nə taxılmır.';

  @override
  String get virtHwCdromLater =>
      'İşləyərkən sürücü növbəti açılışda əlavə olunur (SATA və IDE işləyərkən qoşulmanı dəstəkləmir).';

  @override
  String virtCreateDiskKept(String size) {
    return 'Disk təsvirin öz ölçüsü olan $size olaraq saxlanıldı, istəniləndən böyük: disk heç vaxt üzərindəki sistemdən kiçik kəsilmir.';
  }

  @override
  String get virtCiEditTip =>
      'cloud-init-in bu VM-də qurduqları: sudo hüquqlu hesab, ona necə daxil olmaq, host adı və ünvan.';

  @override
  String get virtCiForeignTitle =>
      'Bu seed bu tətbiqin yazdığından artıq şey saxlayır';

  @override
  String get virtCiForeignBody =>
      'Başqa yerdə edilmiş ayarlar (paketlər, əmrlər, digər hesablar) burada göstərilmir. Saxlamaq seedi burada göstərilənlə əvəz edir.';

  @override
  String get virtCiPasswordKept => 'Təyin edilib. Saxlamaq üçün boş buraxın';

  @override
  String get virtCiRemovePassword => 'Parolu sil';

  @override
  String get virtCiRemovePasswordNote => 'Yalnız SSH açarı ilə giriş';

  @override
  String get virtCiKeysAdded =>
      'Açarlar hesaba əlavə olunur. Burada çıxarılan açar orada silinənə qədər sistemdə qalır, yeni istifadəçi adı isə köhnənin yanında yeni hesab yaradır.';

  @override
  String get virtCiEffectTitle => 'Növbəti açılışda qüvvəyə minir';

  @override
  String get virtCiEffectLibvirt =>
      'Saxlamaq yeni nümunə ID-si ilə yeni seed yazır.';

  @override
  String get virtCiEffectPve =>
      'PVE cloud-init sürücüsünü dərhal yenidən yazır; nümunə ID-si bu ayarlardan hesablanır, ona görə buradakı hər dəyişiklik yenisini yaradır.';

  @override
  String get virtCiNewInstance =>
      'Növbəti açılışda cloud-init sistemi yeni nümunə kimi qəbul edir: host adını yenidən təyin edir, hesab yoxdursa yaradır, parolunu təyin edir, açarları əlavə edir və şəbəkə konfiqurasiyasını yenidən yazır. O, həmçinin yeni SSH host açarları yaradır, ona görə SSH müştəriləri host açarının dəyişdiyi barədə xəbərdarlıq edəcək. O açılışdan əvvəl heç nə dəyişmir.';

  @override
  String get virtCiSaved => 'Saxlanıldı. Növbəti açılışda qüvvəyə minir.';

  @override
  String get virtSnapshotExternal => 'İşləyərkən yalnız disk';

  @override
  String get virtSnapshotExternalTip =>
      'Qonaq işləməyə davam edir. Hər disk seçilmiş hovuzda qcow2 örtüyü alır; qonaq zəncirdə qalır.';

  @override
  String get virtSnapshotFormInternal => 'Daxili (şəkil içində)';

  @override
  String get virtSnapshotOverlayPool => 'Örtük hovuzu';

  @override
  String get virtSnapshotOverlayBeside => 'Hər diskin yanında';

  @override
  String get virtSnapshotExternalNoMemory =>
      'Xarici anlık görüntü yaddaşı saxlamaz: qonaq dayandırılmır.';

  @override
  String get virtSnapshotChain => 'Disk zənciri';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count qat';
  }

  @override
  String get virtSnapshotChainFile => 'Fayl';

  @override
  String get virtSnapshotChainActive => 'Hazırda istifadə olunur';

  @override
  String get virtSnapshotChainBase => 'Əsas şəkil';

  @override
  String get virtSnapshotNoSupport =>
      'Qonağın yaddaşı anlık görüntünü dəstəkləmir, buna görə yaradıla bilməz.';

  @override
  String get virtSnapshotRevertChain =>
      'Zəncirdə geri qaytarma işləyən örtüyü şəklə birləşdirir və sonrakı bütün anlık görüntüləri yararsız edir. Yalnız ən yeni anlık görüntüyə qayıtmaq olar.';

  @override
  String get virtSnapshotRevertHasChildren =>
      'Sonrakı anlık görüntü bunun üzərində olduqca rədd edilir.';

  @override
  String get virtSnapshotDiff => 'İndiki ilə fərqlər';

  @override
  String get virtSnapshotDiffNone =>
      'Bu anlık görüntüdən bəri konfiqurasiya dəyişməyib.';

  @override
  String get virtSnapshotDiffShow => 'İndiki ilə müqayisə et';

  @override
  String get virtSnapshotDiffGroupCpu => 'Prosessor';

  @override
  String get virtSnapshotDiffGroupMemory => 'Yaddaş';

  @override
  String get virtSnapshotDiffGroupDisks => 'Disklər';

  @override
  String get virtSnapshotDiffGroupNic => 'İnterfeyslər';

  @override
  String get virtSnapshotDiffGroupFirmware => 'Proqram təminatı';

  @override
  String get virtSnapshotDiffGroupBoot => 'Önyükləmə';

  @override
  String get virtSnapshotDiffGroupOther => 'Digər';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => 'silinib';

  @override
  String get virtSnapshotDiffAdded => 'əlavə edildi';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return '$snapshot vəziyyətinə qaytarsanız nə dəyişər:';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return 'Host nəyin fərqli olduğunu deyə bilmədi: $error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return 'Qonaq artıq $count qatdadır; bu anlık görüntü bir daha əlavə edir.';
  }

  @override
  String get virtToTemplate => 'Şablona çevir';

  @override
  String get virtToTemplateNote =>
      'Şablon işə salına bilməz və guest-ə geri çevrilə bilməz. Diskləri əsas şəkillərə çevrilir; bağlı klon onları paylaşır.';

  @override
  String virtToTemplateConfirm(String name) {
    return '$name şablona çevrilsin?';
  }

  @override
  String get virtToTemplateIrreversible =>
      'Bu geri alına bilməz: şablon təkrar guest-ə çevrilə bilməz.';

  @override
  String get virtToTemplateStopped => 'Əvvəlcə söndürün.';

  @override
  String get virtToTemplateSnapshots =>
      'Anlık görüntüsü olan qonaq şablon ola bilməz.';

  @override
  String virtTemplateCreated(String name) {
    return '$name artıq şablondur';
  }

  @override
  String get virtTemplateTip => 'Şablon yalnızca klonlandıqdan sonra işləyir.';

  @override
  String get virtCloneStorageSame => 'Mənbə ilə eyni';

  @override
  String get virtCloneNodeSame => 'Mənbə ilə eyni';

  @override
  String get virtCloneStorageContent => 'Bu anbar VM disklərini saxlamır.';

  @override
  String get virtCloneStorageShared =>
      'Başqa node-a köçürmək üçün paylaşılan anbar lazımdır.';

  @override
  String get virtCloneNodeUnknown => 'Bu hostda belə node yoxdur.';

  @override
  String get virtCloneLinkedTarget =>
      'Bağlı klon şablonun disklərini paylaşır; ona görə anbar və ya node göstərə bilməz.';

  @override
  String get virtBackupJobs => 'Yedəkləmə işləri';

  @override
  String get virtBackupJobsNone =>
      'Zamanlanmış yedəkləmə işi yoxdur. Əlavə edin, guest-lər cədvəl üzrə yedəklənsin.';

  @override
  String get virtBackupJobNew => 'Yeni iş';

  @override
  String get virtBackupJobRun => 'İndi işə sal';

  @override
  String get virtBackupJobRunAsk => 'Bu yedəkləmə işi indi başladılsın?';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return '$id yedəkləmə işi silinsin? Yaradılan yedəklər qalır.';
  }

  @override
  String get virtBackupJobSaved => 'İş saxlanıldı';

  @override
  String get virtBackupJobDeleted => 'İş silindi';

  @override
  String get virtBackupJobStarted => 'Yedəkləmə işi başladı';

  @override
  String get virtBackupSchedule => 'Cədvəl';

  @override
  String get virtBackupScheduleHelp =>
      'systemd təqvim hadisələrinin alt çoxluğu: 02:30, mon..fri 02:30, sat 03:00, daily, hourly, */15.';

  @override
  String get virtBackupScheduleInvalid => 'Host bu cədvəli qəbul etmir.';

  @override
  String virtBackupScheduleNext(String times) {
    return 'Növbəti işə salmalar: $times';
  }

  @override
  String get virtBackupSelection => 'Qonaqlar';

  @override
  String get virtBackupSelectionAll => 'Bütün qonaqlar';

  @override
  String get virtBackupSelectionList => 'Seçilmiş qonaqlar';

  @override
  String get virtBackupSelectionNone => 'Ən azı bir qonaq seçin.';

  @override
  String get virtBackupMail => 'Bildiriş';

  @override
  String get virtBackupNotesTemplate => 'Yedək qeydləri';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return 'Qeydlər işin yaratdığı hər yedəyə əlavə olunur. Dəyəri ilə əvəz olunanlar: $vars.';
  }

  @override
  String get virtBackupPrune => 'Saxlama';

  @override
  String get virtBackupPruneTip =>
      'PVE saxlama seçimləri, məs. keep-last=7,keep-daily=4. Boş: anbarın və ya node-un öz ayarı.';

  @override
  String get virtBackupJobNode => 'Node';

  @override
  String get virtBackupJobNodeAny => 'Hər node';

  @override
  String get virtBackupEnabled => 'Aktiv';

  @override
  String get virtBackupOptions => 'Seçimlər';

  @override
  String get virtBackupProtect => 'Qoru';

  @override
  String get virtBackupProtectTip =>
      'Qorunan yedək saxlama ilə silinmir və qoruma götürülənə qədər silinə bilməz.';

  @override
  String get virtBackupEditNotes => 'Qeydlər';

  @override
  String get virtBackupSaveNotes => 'Saxla';

  @override
  String get virtBackupEdited => 'Yedək yeniləndi';

  @override
  String get virtBackupRestoreStorage => 'Anbara bərpa et';

  @override
  String get virtBackupRestoreStorageSame => 'Yedəkdəki kimi';

  @override
  String get virtCloneStorageMissing =>
      'Bu node-da VM disklərini saxlayan anbar yoxdur.';

  @override
  String get virtBackupCompress => 'Sıxılma';

  @override
  String get virtBackupUnprotect => 'Qorumanı götür';

  @override
  String get virtBackupModeStops =>
      'suspend və stop kopyalama zamanı işləyən qonağı dayandırır.';

  @override
  String get virtBackupScheduleValidate => 'Hostda yoxla';

  @override
  String virtBackupSelected(int count) {
    return '$count seçildi';
  }

  @override
  String get virtBackupExcludeTip =>
      'Node-dakı bütün qonaqlar götürülür. Birini söndürsəniz kənarda qalır.';

  @override
  String virtNetEditAsk(int count) {
    return 'İşləyən şəbəkə yenidən başladılana qədər mövcud vəziyyətini saxlayır. Yenidən başlatma üzərindəki VM-lərin ($count) bağlantısını kəsir.';
  }

  @override
  String get virtNetEditAskNoGuest =>
      'İşləyən şəbəkə yenidən başladılana qədər mövcud vəziyyətini saxlayır.';

  @override
  String get virtNetEditRestart => 'İndi tətbiq etmək üçün yenidən başlat';

  @override
  String get virtNetEditRestartNote =>
      'Üzərindəki VM-lər yenidən başlatma zamanı şəbəkəni itirir.';

  @override
  String get virtNetEditPending =>
      'Tərifdə işləyən şəbəkənin hələ qəbul etmədiyi dəyişiklik var.';

  @override
  String get virtNetRestart => 'Yenidən başlat';

  @override
  String virtNetRestartAsk(String name, int count) {
    return '$name yenidən başladılsın? Üzərindəki VM-lər ($count) şəbəkə geri qayıdana qədər bağlantısız qalır.';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return '$name yenidən başladılsın? Üzərində heç nə yoxdur.';
  }

  @override
  String get virtNetHosts => 'Statik ünvanlar';

  @override
  String get virtNetHostAdd => 'Ünvan əlavə et';

  @override
  String get virtNetHostMac => 'MAC';

  @override
  String get virtNetHostIp => 'Ünvan';

  @override
  String get virtNetHostName => 'Ad (istəyə bağlı)';

  @override
  String get virtNetHostEmpty =>
      'Heç bir MAC-a öz ünvanı verilmir: hər VM DHCP aralığından ünvan alır.';

  @override
  String get virtNetHostOthers => 'Digər hər VM DHCP aralığından ünvan alır.';

  @override
  String get virtNetHostInvalid =>
      'Hostun rədd edəcəyi MAC, ünvan və ya ad, ya da eyni MAC iki dəfə.';

  @override
  String get virtNetManagementIface =>
      'Bu interfeys hostun öz ünvanını daşıyır. Onu redaktə etmək və ya tətbiq etmək hostla əlaqəni kəsər.';

  @override
  String get virtNetManagementTip =>
      'Hostun idarəetmə trafikini daşıyır və ya bunu edən interfeysin altındadır: tətbiq onu redaktə etmir.';

  @override
  String get virtNetPhysicalTip =>
      'Fiziki interfeys hostun özünündür: tətbiq yalnız körpüləri redaktə edir.';

  @override
  String get virtNetVlanAware => 'VLAN dəstəyi';

  @override
  String get virtCiExpire => 'Parolun müddəti bitir';

  @override
  String get virtCiExpireNote =>
      'Onunla ilk girişdə yeni parol təyin edilməlidir. Yalnız libvirt: PVE \"expire: false\" yazır və bunun üçün seçimi yoxdur.';

  @override
  String get virtCiSearchHint => 'lab.example dev.lab.example';

  @override
  String get virtCiSearchTip =>
      'Bir neçəsi, boşluqla ayrılmış; resolv.conf ilk bir neçəsini saxlayır.';

  @override
  String virtCiNicsTip(int count) {
    return 'Seed-in şəbəkə konfiqurasiyasında $count NIC var; forma birincini redaktə edir.';
  }

  @override
  String get virtUsbByVendor => 'İstehsalçı və məhsula görə';

  @override
  String get virtUsbByAddress => 'Ünvana görə';

  @override
  String get virtUsbAddressTip =>
      'Cihaz bu ünvanı izləyir: ora nə taxılıbsa, VM-ə verilir. libvirt USB hostdev-i şin və cihaz nömrəsi ilə adlandırır.';

  @override
  String virtUsbPortNote(int bus, String port) {
    return 'şin $bus · port $port';
  }

  @override
  String get virtSbUnsupported =>
      'Hostun proqram təminatı deskriptorlarında qeydiyyatlı açarları olan Secure Boot proqram təminatı yoxdur, ona görə də onunla domen başlaya bilməz.';

  @override
  String get virtCreateSecureBoot => 'Secure Boot';

  @override
  String get virtCreateSecureBootNote =>
      'Yalnız imzalanmış nüvələr və yükləyicilər işə salınır.';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return 'şin $bus · cihaz $device';
  }

  @override
  String get virtHwRevertPendingTitle => 'Gözləyən dəyişiklikləri at';

  @override
  String virtHwRevertPendingBody(String name) {
    return '$name işlədiyi vəziyyətə qaytarılır: tərif işləyəndən yenidən yazılır və növbəti başlanğıc indikinin tam eynisini alır. NVRAM faylı və proqram təminatı olduğu kimi qalır.';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return '$name üçün növbəti başlanğıcı gözləyən bütün dəyişikliklər atılsın?';
  }

  @override
  String get virtBackupPlanNew => 'Yeni plan';

  @override
  String get virtBackupPlanNewTip =>
      'Yalnız bu qonağın ehtiyat nüsxəsini çıxaran cədvəl.';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Daha $count qonağın da ehtiyat nüsxəsini çıxarır',
      zero: 'Başqa qonaq yoxdur',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => 'Hərəkəti azalt';

  @override
  String get copyLink => 'Keçidi kopyala';

  @override
  String funcNeedsAgentPermission(String func) {
    return 'Bu Monitor agent-dəki hesabınızın $func üçün icazəsi yoxdur. Agent-in adminindən istəyin.';
  }

  @override
  String funcNeedsAgentHttps(String func) {
    return '$func bu Monitor agent-ə HTTPS və ya həm agent-də, həm də bu tətbiqdə icazə verilmiş HTTP tələb edir.';
  }

  @override
  String funcNeedsAgentSetup(String func) {
    return '$func bu Monitor agent-də qurulmayıb; onun operatoru konfiqurasiya etməlidir.';
  }

  @override
  String get monitorFilesReadOnly =>
      'Yalnız oxuma: bu hesab agent-dəki faylları gözdən keçirə bilər, amma dəyişə bilməz.';

  @override
  String get monitorAccess => 'Giriş';

  @override
  String get monitorAccounts => 'Hesablar';

  @override
  String get monitorRoles => 'Rollar';

  @override
  String get monitorRole => 'Rol';

  @override
  String get monitorChangePassword => 'Şifrəni dəyiş';

  @override
  String get monitorNewPassword => 'Yeni şifrə';

  @override
  String get monitorCurrentPassword => 'Hazırkı şifrəniz';

  @override
  String get monitorReauthTip =>
      'Girişi dəyişmək üçün şifrəniz yenidən tələb olunur.';

  @override
  String get monitorPasswordTooShort => 'Ən azı 8 simvol';

  @override
  String get monitorPasswordMismatch => 'Şifrələr uyğun gəlmir';

  @override
  String get monitorErrReauth => 'Şifrəniz yanlış idi.';

  @override
  String get monitorErrLastAdmin =>
      'Agent-in ən azı bir admin hesabı olmalıdır.';

  @override
  String get monitorErrConflict => 'Artıq mövcuddur və ya hələ istifadədədir.';

  @override
  String get monitorErrForbidden => 'Bunu yalnız admin edə bilər.';

  @override
  String get monitorRoleNameRule =>
      'Kiçik hərflər, rəqəmlər, - və _, 32 simvola qədər';

  @override
  String get monitorGrantShell => 'Shell və əmrlər';

  @override
  String get monitorGrantShellTip =>
      'Terminal, proseslər, xidmətlər, konteynerlər, snippet-lər, enerji — agent hesabı ilə';

  @override
  String get monitorGrantSshTerminal => 'SSH üzərindən panel terminalı';

  @override
  String get monitorGrantVirt => 'Virtuallaşdırma';

  @override
  String get monitorGrantVirtTip =>
      'Agentin veb panelində qoşulduğu Proxmox VE, libvirt və BMC-lər';

  @override
  String get monitorGrantFiles => 'Fayllar';

  @override
  String get monitorGrantConnect => 'Çıxan bağlantılar';

  @override
  String get monitorGrantConnectTip =>
      'Lokal və dinamik port yönləndirmələri, uzaq masaüstü';

  @override
  String get monitorGrantConnectAllow =>
      'İcazə verilən hədəflər (IP və ya CIDR, istəyə görə :port və ya :başlanğıc-son; hər sətirdə bir, boş = hər yer)';

  @override
  String get monitorGrantListen => 'Serverdə dinlə';

  @override
  String get monitorGrantListenTip => 'Uzaq port yönləndirmələri';

  @override
  String get monitorGrantListenPublic => 'Loopback olmayan ünvanlar';

  @override
  String get monitorGrantPorts => 'Port aralığı (boş = istənilən)';

  @override
  String get monitorGrantOff => 'Söndürülüb';

  @override
  String get monitorBuiltin => 'Daxili';

  @override
  String get monitorAdminRoleTip =>
      'Hesabları, rolları və agent ayarlarını idarə edir';

  @override
  String get monitorYou => 'Siz';

  @override
  String get monitorNoAccessToSettings =>
      'Bu agent-in ayarlarını yalnız admin dəyişə bilər.';

  @override
  String get monitorPasswordNotSaved =>
      'Parol agent-də dəyişdirildi, lakin tətbiq onu saxlaya bilmədi. Bu serverin ayarlarında Monitor parolunu yeniləyin.';

  @override
  String get firewall => 'Firewall';

  @override
  String get firewallLinuxOnly =>
      'Firewall idarəetməsi ufw və ya firewalld quraşdırılmış Linux serverlərini dəstəkləyir.';

  @override
  String get firewallNeedsRoot =>
      'Firewall qaydalarını oxumaq üçün root lazımdır. Davam etmək üçün sudo parolunu daxil edin.';

  @override
  String get firewallIncoming => 'Daxil olan';

  @override
  String get firewallOutgoing => 'Çıxan';

  @override
  String get firewallRouted => 'Yönləndirilən';

  @override
  String get firewallDefaultPolicy => 'Standart siyasət';

  @override
  String get firewallLogging => 'Jurnal';

  @override
  String get firewallRules => 'Qaydalar';

  @override
  String get firewallRule => 'Qayda';

  @override
  String get firewallAddRule => 'Qayda əlavə et';

  @override
  String get firewallAnywhere => 'İstənilən yer';

  @override
  String firewallFromFmt(String source) {
    return 'mənbə: $source';
  }

  @override
  String get firewallFrom => 'Mənbə';

  @override
  String get firewallTo => 'Təyinat';

  @override
  String get firewallProtocol => 'Protokol';

  @override
  String get firewallInterface => 'İnterfeys';

  @override
  String get firewallComment => 'Şərh';

  @override
  String get firewallAppProfile => 'Tətbiq profili';

  @override
  String get firewallPrepend => 'Bütün digər qaydalardan əvvəl yerləşdir';

  @override
  String get firewallIpv6Off =>
      'IPv6 söndürülüb (IPV6=no): v6 qaydaları yüklənmir.';

  @override
  String get firewallReload => 'Yenidən yüklə';

  @override
  String get firewallNothingMatched =>
      'Port, tətbiq profili, ünvan və ya interfeys daxil edin.';

  @override
  String get firewallInvalidPort =>
      'Yanlış port. 22, 80,443 və ya 6000:6010 formatından istifadə edin.';

  @override
  String get firewallTooManyPorts => 'Ən çox 15 port; bir aralıq iki sayılır.';

  @override
  String get firewallPortsNeedProtocol =>
      'Port siyahısı və ya aralığı üçün tcp və ya udp lazımdır.';

  @override
  String get firewallInvalidAddress =>
      'Yanlış ünvan. IP ünvanı və ya 192.168.1.0/24 kimi şəbəkə istifadə edin.';

  @override
  String get firewallMixedIpVersions =>
      'Mənbə və Təyinat ya hər ikisi IPv4, ya da hər ikisi IPv6 olmalıdır.';

  @override
  String get firewallInvalidInterface => 'Yanlış interfeys adı.';

  @override
  String get firewallInvalidComment => 'Şərhdə \' və ya sətir sonu ola bilməz.';

  @override
  String get firewallInterfaceIn => 'Daxil olan interfeys';

  @override
  String get firewallInterfaceOut => 'Çıxan interfeys';

  @override
  String get firewallSourcePort => 'Mənbə portu';

  @override
  String get firewallMoreOptions => 'Əlavə seçimlər';

  @override
  String get firewallNoneInstalled =>
      'Bu serverdə nə ufw, nə də firewalld quraşdırılıb. Onlardan birini sistemin paket meneceri ilə quraşdırın, məsələn `apt install ufw` və ya `dnf install firewalld`.';

  @override
  String get firewallKeepAccess => 'Əvvəlcə bu tətbiqin portlarını açıq saxla';

  @override
  String firewallWillRefuseFmt(String access) {
    return '$access: bu tətbiqin yeni qoşulmaları rədd ediləcək. İstifadə olunan qoşulma kəsilənə qədər qalır.';
  }

  @override
  String firewallMayRefuseFmt(String access) {
    return '$access: bu tətbiqin yeni qoşulmaları rədd edilə bilər. Bu, qoşulmanın gəldiyi ünvandan və ya interfeysdən asılıdır və tətbiq bunu bilə bilmir.';
  }

  @override
  String firewallRateLimitedFmt(String access) {
    return '$access: qoşulmalar sürət məhdudiyyətinə düşəcək. 30 saniyə ərzində 6 və ya daha çox qoşulma açan ünvan rədd edilir və bu tətbiq bu qədər tez-tez yenidən qoşula bilər.';
  }

  @override
  String get firewallConflict =>
      'ufw və firewalld hər ikisi aktivdir. Hər ikisi nüvənin qaydalarını yazır və sonuncu yüklənən nəyin keçəcəyini həll edir.';

  @override
  String get firewallDefaultZone => 'Standart zone';

  @override
  String get firewallZone => 'Zone';

  @override
  String get firewallTarget => 'Target';

  @override
  String get firewallMasquerade => 'Masquerade';

  @override
  String get firewallServices => 'Xidmətlər';

  @override
  String get firewallPorts => 'Portlar';

  @override
  String get firewallSources => 'Mənbələr';

  @override
  String get firewallInterfaces => 'İnterfeyslər';

  @override
  String get firewallRichRules => 'Rich rules';

  @override
  String get firewallForwardPorts => 'Yönləndirilən portlar';

  @override
  String get firewallRuntimeOnly => 'yalnız runtime';

  @override
  String get firewallPermanentOnly => 'yalnız permanent';

  @override
  String get firewallThisConnection => 'bu qoşulma';

  @override
  String get firewallDefaultTag => 'standart';

  @override
  String get firewallDrift =>
      'Qüvvədə olan konfiqurasiya saxlanılandan fərqlənir. Reload və ya yenidən başlatma onu saxlanılan konfiqurasiya ilə əvəz edir.';

  @override
  String firewallDriftLockoutFmt(String access) {
    return 'Reload və ya yenidən başlatmadan sonra $access rədd ediləcək: saxlanılan konfiqurasiya ona icazə vermir.';
  }

  @override
  String get firewallSaveRuntime => 'Permanent kimi saxla';

  @override
  String get firewallReloadLoses =>
      'Permanent kimi saxlanmayan dəyişikliklər itəcək.';

  @override
  String get firewallPanic => 'Panic rejimi aktivdir: bütün paketlər atılır.';

  @override
  String get firewallPanicOff => 'Panic rejimini söndür';

  @override
  String get firewallStoppedNote =>
      'firewalld dayandırılıb. Dəyişikliklər saxlanılır və o başlayanda qüvvəyə minir.';

  @override
  String get firewallInvalidSource =>
      'Yanlış mənbə. Ünvan, 192.168.1.0/24 kimi şəbəkə, ipset:AD və ya MAC ünvanı istifadə edin.';

  @override
  String get firewallInvalidRichRule =>
      'Rich rule \"rule\" ilə başlayır və bir sətirdə olur.';

  @override
  String get firewallInvalidForwardPort =>
      'port=80:proto=tcp:toport=8080 formatından toport, toaddr və ya hər ikisi ilə istifadə edin.';

  @override
  String get monitorSyncNeedsServer =>
      'Ehtiyat nüsxəni saxlayan monitor agentinin serverini seçin.';

  @override
  String get monitorBackupUnsupported =>
      'Bu monitor agenti ehtiyat nüsxə saxlaya bilmir. Agenti yeniləyin.';

  @override
  String get monitorBackupAdminOnly =>
      'Monitor agentində yalnız administrator hesabı ehtiyat nüsxə saxlaya bilər.';

  @override
  String monitorBackupTooLarge(String max) {
    return 'Ehtiyat nüsxə monitor agentinin qəbul etdiyi ölçüdən ($max) böyükdür.';
  }

  @override
  String get monitorBackupTooMany =>
      'Monitor agenti icazə verdiyi qədər ehtiyat nüsxə saxlayır. Əvvəlcə birini silin.';

  @override
  String get virtCreateVmidInvalid => '100 ilə 999999999 arasında VMID.';

  @override
  String get virtCreateNodeOffline => 'Bu node onlayn deyil.';

  @override
  String get virtCreateMediaMissing =>
      'Bu quraşdırma mediası bu hostda yoxdur.';

  @override
  String get virtCreateNetworkMissing =>
      'Yeni qonaq bu şəbəkədən istifadə edə bilməz.';

  @override
  String get virtCreateNotOffered => 'Bu host yeni VM üçün bunu təklif etmir.';

  @override
  String get virtCreateSecureBootNeedsUefi => 'Secure Boot UEFI tələb edir.';

  @override
  String get virtGuestNotStopped => 'Əvvəlcə onu söndürün.';

  @override
  String get virtGuestIsTemplate => 'Artıq şablondur.';

  @override
  String get virtCreateImageBigger =>
      'Şəkil diskdən böyükdür: diski ən azı onun qədər edin.';
}
