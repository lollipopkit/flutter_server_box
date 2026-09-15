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
  String get askAiAwaitingResponse => 'AI cavabı gözlənilir...';

  @override
  String get askAiEndpointTip =>
      'Domen və ya tam URL daxil et. Yol seçdiyin protokola əsasən tamamlanır.';

  @override
  String get askAiProtocolTip =>
      'Avtomatik rejim əvvəlcə Responses, sonra Chat Completions sınayır.';

  @override
  String get askAiCommandInserted => 'Əmr terminala daxil edildi';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Parametrlərdə $fields məlumatlarını təyin et.';
  }

  @override
  String get askAiDisclaimer =>
      'AI səhv edə bilər. Tətbiq etməzdən əvvəl diqqətlə yoxla.';

  @override
  String get askAiInsertTerminal => 'Terminala daxil et';

  @override
  String get askAiNoResponse => 'Cavab yoxdur';

  @override
  String get remoteDesktop => 'Remote desktop';

  @override
  String get askAiAgentWelcome => 'Bu serverdə nə edək?';

  @override
  String get askAiAgentPromptHint =>
      'Agentdən nəyisə yoxlamağı və ya düzəltməyi istə...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Seçilmiş terminal çıxışını təhlil et və nə baş verdiyini izah et';

  @override
  String get askAiTerminalContext => 'Terminal konteksti';

  @override
  String get askAiReviewNeeded => 'Yoxla';

  @override
  String get askAiReviewAction => 'Təklif olunan əmri yoxla';

  @override
  String get askAiReviewBeforeContinuing =>
      'Əvvəlcə cari təklifi yoxla və ya rədd et';

  @override
  String get askAiApproveRun => 'Təsdiqlə və icra et';

  @override
  String get askAiDecline => 'Rədd et';

  @override
  String get askAiActionDeclined => 'Təklif olunan əmr rədd edildi.';

  @override
  String get askAiInterrupted => 'Agentin cavabı kəsildi.';

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
  String get askAiRiskReadOnly => 'Yalnız oxuma';

  @override
  String get askAiRiskCaution => 'Sistemi dəyişir';

  @override
  String get askAiRiskUnvetted => 'Yoxlanılmamış host';

  @override
  String get askAiRiskDestructive => 'Yüksək risk';

  @override
  String get askAiHighRiskConfirmTitle => 'Yüksək riskli əmr icra edilsin?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Bu əmr geri qaytarılması çətin olan dəyişikliklər edə bilər. Diqqətlə yoxla.';

  @override
  String get askAiNoCommandOutput => 'Əmr çıxış olmadan tamamlandı.';

  @override
  String get askAiOutputTruncated =>
      'Uzun çıxış agentə geri göndərilməzdən əvvəl qısaldıldı.';

  @override
  String get askAiAutoApproved => 'Avtomatik təsdiqləndi';

  @override
  String get askAiAutoRunSafeCommands =>
      'Yalnız oxuma əmrlərini avtomatik icra et';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Yalnız həm model, həm də yerli yoxlama əmri yalnız oxuma kimi qiymətləndirdikdə icra olunur';

  @override
  String get askAiSendOnEnter => 'Enter göndərir';

  @override
  String get askAiSendOnEnterTip =>
      'Enter göndərir, Shift+Enter yeni sətir açır. Söndürüldükdə: Enter yeni sətir açır, Cmd/Ctrl+Enter göndərir.';

  @override
  String get askAiApiKeyOptional =>
      'Yerli istifadə və ya autentifikasiya tələb olunmadıqda boş saxla';

  @override
  String get askAiAllowInsecure => 'Şifrələnməmiş HTTP-yə icazə ver';

  @override
  String get askAiAllowInsecureTip =>
      'localhost xaricindəki ünvanlarda yerləşən öz modelinə http:// ilə qoşulmağa imkan verir. API açarı və terminal konteksti şifrələnmədən göndərilir; localhost bundan təsirlənmir.';

  @override
  String get askAiInsecureEndpoint =>
      'Bu ünvan http:// istifadə edir. İstifadə etmək üçün AI parametrlərində «Şifrələnməmiş HTTP-yə icazə ver» seçimini aktivləşdir.';

  @override
  String get askAiHistory => 'Söhbət tarixçəsi';

  @override
  String get askAiNewConversation => 'Yeni söhbət';

  @override
  String get askAiNoHistory => 'Hələ yadda saxlanmış söhbət yoxdur';

  @override
  String get askAiNoHistoryMessages => 'Hələ mesaj yoxdur';

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
  String get askAiClearHistoryTitle =>
      'Bu serverin agent tarixçəsi təmizlənsin?';

  @override
  String get askAiClearHistoryTip =>
      'Bu server üçün yadda saxlanmış bütün agent söhbətləri silinəcək.';

  @override
  String get askAiRestoredReview =>
      'Bu əmr tarixçədən götürülüb. Yenidən yoxla';

  @override
  String get agentWelcome => 'Serverlərində nə edək?';

  @override
  String get agentWelcomeTip =>
      'Agentə problemi araşdırmağı və ya tapşırığı yerinə yetirməyi həvalə et';

  @override
  String get agentPromptHint =>
      'Agentdən serverlərini yoxlamağı və ya idarə etməyi istə...';

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
  String get agentToolFailed => 'Alətin icrası uğursuz oldu.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count alət çağırışı';
  }

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
  String nTags(Object count) {
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
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Son ehtiyat nüsxə: $lastModified\nVəziyyət: $remoteState';
  }

  @override
  String get bgRun => 'Arxa planda işlət';

  @override
  String get bgRunTip =>
      'Bu keçid yalnız proqramın arxa planda işləməyə cəhd edəcəyini bildirir. Arxa planda işləyə bilməsi müvafiq icazənin aktiv olub-olmamasından asılıdır. AOSP əsaslı Android ROM sistemlərində bu tətbiq üçün \"Batareya optimallaşdırması\" funksiyasını söndür. MIUI / HyperOS üçün enerjiyə qənaət siyasətini \"Məhdudiyyətsiz\" olaraq dəyiş.';

  @override
  String get trayTitle => 'Vəziyyət işarəsi';

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
  String clearServerStatsContent(Object serverName) {
    return '\"$serverName\" serverinin əlaqə statistikasını təmizləmək istədiyinə əminsən? Bu əməliyyatı geri qaytarmaq mümkün deyil.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
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
  String get cpuViewAsProgressTip =>
      'Hər CPU istifadəsini irəliləyiş zolağı şəklində göstər (köhnə üslub)';

  @override
  String get customCmd => 'Fərdi əmrlər';

  @override
  String get deleteServers => 'Serverləri toplu şəkildə sil';

  @override
  String get deleteDirRecursive => 'Qovluğu və içindəkilərin hamısını sil';

  @override
  String get desktopTerminalTip =>
      'SSH sessiyaları başladılarkən terminal emulyatorunu açmaq üçün istifadə olunan əmr.';

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
  String get displayCpuIndex => 'CPU indeksini göstər';

  @override
  String dl2Local(Object fileName) {
    return '$fileName bu cihaza endirilsin?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'İşləyən konteyner yoxdur.\nBunun səbəbi aşağıdakılar ola bilər:\n- Docker quraşdıran istifadəçi tətbiqdə təyin edilmiş istifadəçi adı ilə eyni deyil.\n- DOCKER_HOST mühit dəyişəni düzgün oxunmayıb. Onu terminalda `echo \$DOCKER_HOST` əmrini icra edərək əldə edə bilərsən.';

  @override
  String dockerImagesFmt(Object count) {
    return '$count obraz';
  }

  @override
  String get dockerProjectOther => 'Digər';

  @override
  String get dockerPruneTip =>
      'Diskdə yer boşaltmaq üçün istifadə olunmayan məlumatları sil';

  @override
  String get dockerStatistics => 'Docker statistikası';

  @override
  String get doubleColumnMode => 'İki sütunlu rejim';

  @override
  String get doubleColumnTip =>
      'Bu seçim yalnız funksiyanı aktivləşdirir. Onun həqiqətən işləməsi cihazın enindən asılıdır.';

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
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
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return '$serverName üçün vasitəçi serverlər tapılmadı: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
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
  String get preferredTransport => 'Əvvəlcə sına';

  @override
  String get preferredTransportTip =>
      'Vəziyyətin haradan oxunduğunu və əmrin əvvəlcə hansı əlaqəni açdığını müəyyən edir. Digər əlaqə də əlçatan qalır.';

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
  String madeWithLove(Object myGithub) {
    return '$myGithub tərəfindən ❤️ ilə hazırlanıb';
  }

  @override
  String get maxConcurrency => 'Maksimum paralel əməliyyat sayı';

  @override
  String get maxRetryCount => 'Serverlə yenidən əlaqə cəhdlərinin sayı';

  @override
  String mismatchSystem(Object system) {
    return 'Uyğun olmayan sistem: $system';
  }

  @override
  String get mirror => 'Güzgü serveri';

  @override
  String get needRestart => 'Tətbiq yenidən başladılmalıdır';

  @override
  String get netViewType => 'Şəbəkə görünüşünün növü';

  @override
  String get newContainer => 'Yeni konteyner';

  @override
  String get noConnectionStatsData => 'Əlaqə statistikası məlumatları yoxdur';

  @override
  String get noLineChart => 'Xətti qrafiklərdən istifadə etmə';

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
  String get plugInType => 'Daxiletmə növü';

  @override
  String get preferDiskAmount => 'Disk tutumunun göstərilməsinə üstünlük ver';

  @override
  String get privateKey => 'Məxfi açar';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
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
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand yalnız masaüstü platformalarda dəstəklənir.';

  @override
  String get pveIgnoreCertTip =>
      'Aktivləşdirmək tövsiyə olunmur, təhlükəsizlik risklərini nəzərə al! PVE standart sertifikatından istifadə edirsənsə, bu seçimi aktivləşdirməlisən.';

  @override
  String get pveServerClientMissing =>
      'Bu server üçün SSH müştərisi əlçatan deyil.';

  @override
  String get pveAddressMissing =>
      'PVE ünvanı yoxdur. Onu server parametrlərində təyin et.';

  @override
  String get pvePasswordRequired =>
      'PVE parolu tələb olunur. Onu server parametrlərində təyin et.';

  @override
  String get pveOtpRequired =>
      'Bu PVE serverində iki amilli autentifikasiya aktivdir. OTP kodunu daxil et.';

  @override
  String get pveOtpChallengeExpired =>
      'OTP sorğusunun müddəti bitib. Yenilə və yenidən cəhd et.';

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
  String get pveVersionLow =>
      'Bu funksiya hazırda sınaq mərhələsindədir və yalnız PVE 8+ üzərində sınaqdan keçirilib. Ehtiyatla istifadə et.';

  @override
  String get pveLoadingForwarding => 'SSH tuneli yaradılır...';

  @override
  String get pveLoadingLogin => 'PVE ilə autentifikasiya aparılır...';

  @override
  String get pveLoadingData => 'Klaster məlumatları alınır...';

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
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed quraşdırılıb; $latest mövcuddur. Yeniləmə bütün konteyneri əvəz edir: $pm məlumatları itirilir';
  }

  @override
  String linuxSystemInUse(Object name) {
    return '$name sistemini silməzdən əvvəl ondakı terminalları bağla';
  }

  @override
  String get rootfsSubtitle => 'Bu cihazda Linux istifadəçi mühiti';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
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
  String selected(Object count) {
    return '$count seçilib';
  }

  @override
  String get sendTo => 'Göndər…';

  @override
  String get serverDetailOrder => 'Təfərrüatlar səhifəsində vidcetlərin sırası';

  @override
  String get serverFuncBtns => 'Server funksiya düymələri';

  @override
  String get serverOrder => 'Serverlərin sırası';

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
  String spentTime(Object time) {
    return 'Sərf olunan vaxt: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Bütün serverlər artıq mövcuddur ($duplicateCount təkrar tapıldı)';
  }

  @override
  String get sshConnectionModeTip =>
      'Daxili: tətbiqin terminalından istifadə et. Sistem SSH: sistemin ssh əmrini xarici terminalda başlat.';

  @override
  String get sshConnectionModeUseBuiltin => 'Daxili terminaldan istifadə et';

  @override
  String get sshConnectionModeUseSystem => 'Sistem SSH istifadə et';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount təkrar ötürüləcək';
  }

  @override
  String get sshConfigFound => 'Sistemində SSH konfiqurasiyası tapıldı.';

  @override
  String sshConfigFoundServers(Object totalCount) {
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
  String sshConfigImported(Object count) {
    return 'SSH konfiqurasiyasından $count server idxal edildi';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return '$serverName üçün SSH host açarı dəyişib. Yalnız bu serverə etibar edirsənsə davam et.';
  }

  @override
  String get sshHostKeyType => 'SSH host açarının növü';

  @override
  String get sshKnownHostKeys => 'Tanınan hostlar';

  @override
  String get sshKnownHostKeysTip => 'Bu tətbiqin qəbul etdiyi host açarları';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return '$serverName serverindən yeni SSH host açarı alındı. Etibar etməzdən əvvəl barmaq izini yoxla.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
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
  String sshConfigServersToImport(Object importCount) {
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
  String switchTo(Object val) {
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
  String get view => 'Bax';

  @override
  String get viewDetails => 'Təfərrüatlara bax';

  @override
  String get virtKeyHelpClipboard =>
      'Terminalda seçilmiş mətn varsa mübadilə buferinə kopyala, əks halda buferin məzmununu terminala yapışdır.';

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
      'Terminal parametrlərində bu düymələrin sırasını dəyiş və ya istifadə etmədiklərini gizlət.';

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
  String portForward_deleteConfirmFmt(Object name) {
    return '$name silinsin?';
  }

  @override
  String get sponsor => 'Sponsor ol';

  @override
  String get sortByJoinTime => 'Əlavə edilmə vaxtına görə';

  @override
  String get serverHistory => 'Server tarixçəsi';

  @override
  String get portForwardBetaTitle => 'Port yönləndirmə (beta)';

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
  String get tmuxExistingSessions => 'Mövcud sessiyalar';

  @override
  String get tmuxNewSession => 'Yeni sessiya';

  @override
  String get tmuxWindows => 'Pəncərələr';

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
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bölmə',
      one: '1 bölmə',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Qoşulub';

  @override
  String get tmuxActive => 'Aktivdir';

  @override
  String tmuxActiveAt(String time) {
    return 'aktivdir: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'qoşulub: $time';
  }

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
  String get serviceEnabled => 'Başlanğıcda aktivdir';

  @override
  String get systemdUserScopeMissing =>
      'İstifadəçi vahidləri siyahıda göstərilmir';

  @override
  String get systemdUserScopeMissingTip =>
      'Bu hesabın serverdə istifadəçi sessiyası şini yoxdur, buna görə yalnız sistem vahidləri göstərilir.';

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
  String get send => 'Göndər';

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
  String geoDataCurrent(Object month) {
    return '$month artıq quraşdırılıb.';
  }

  @override
  String geoDataConsent(Object download, Object disk) {
    return '**Endirmə: $download · Cihazda tutulan yer: $disk.** Tam məlumat toplusu bu cihazda saxlanılır və sonrakı bütün coğrafi mövqe sorğuları yerli olaraq icra olunur. Server ünvanları və sorğu fəaliyyəti endirmə servisinə göndərilmir.\n\nHər ay yenilənir. Yeni versiya əlavə nüsxə saxlamadan quraşdırılmış məlumatları əvəz edir. Məlumatları istənilən vaxt silə bilərsən.';
  }

  @override
  String get benchmark => 'Benchmark';

  @override
  String get benchmarkIntro =>
      'Bu serverdə disk, şəbəkə və CPU üçün Yet Another Bench Script işə salınır. Tam icra 10 ilə 20 dəqiqə arasında vaxt aparır və bu səhifədən çıxsan və ya tətbiqi bağlasan da davam edir.';

  @override
  String benchmarkLinuxOnly(String system) {
    return 'Benchmark üçün Linux tələb olunur. Bu server $system bildirir.';
  }

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
  String benchmarkEstimatedTime(String minutes) {
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
  String get benchmarkDiedUnreported =>
      'İcra nəticə bildirilmədən dayandı. Az yaddaşlı serverlərdə buna adətən yaddaş çatışmazlığı zamanı prosesləri dayandıran mexanizm səbəb olur.';

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
  String get benchmarkBlockSize => 'Blok ölçüsü';

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
  String get benchmarkCompare => 'Müqayisə et';

  @override
  String get benchmarkCompareEmpty =>
      'Müqayisə üçün ən azı iki tamamlanmış benchmark lazımdır.';

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
  String get scheduledTaskScheduleHint => 'For example: 0 2 * * * or @reboot';
}
