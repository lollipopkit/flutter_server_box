// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Azerbaijani (`az`).
class AppLocalizationsAz extends AppLocalizations {
  AppLocalizationsAz([String locale = 'az']) : super(locale);

  @override
  String get appearanceSettings => 'Görünüş';

  @override
  String get appearancePreset => 'Tema dəsti';

  @override
  String get appearanceThemeSchemaRange => 'Dəstəklənən mövzu schema-sı';

  @override
  String get appearanceThemeInstall => 'Mövzu quraşdır';

  @override
  String get appearanceThemeStore => 'Mövzu mağazası';

  @override
  String get appearanceInvalidTheme =>
      'Mövzu paketi və ya kataloq etibarsızdır';

  @override
  String get themeStoreRefreshFailed => 'Tema kataloqu oxuna bilmədi.';

  @override
  String themeStoreDeleteTheme(String name) {
    return '“$name” silinsin? Faylları bu cihazdan silinir. İstifadə olunan temadırsa, tətbiq standart temaya qayıdır.';
  }

  @override
  String themeStoreUpdatedFmt(String ago) {
    return '$ago yeniləndi';
  }

  @override
  String get themeStoreUpdatedJustNow => 'indi yeniləndi';

  @override
  String get themeStoreSortInUse => 'İstifadədə olan əvvəl';

  @override
  String themeStoreMakeOwnFmt(String doc) {
    return 'Öz temanızı yaratmaq istəyirsiniz? [Necə yaradılır]($doc) baxın — töhfəniz üçün təşəkkürlər!';
  }

  @override
  String appearanceThemeNeedsNewerApp(String version) {
    return 'Daha yeni tətbiq tələb olunur: $version';
  }

  @override
  String get appearanceFontFamilies => 'İnterfeys şrift ailələri';

  @override
  String get appearanceFontFamiliesTip =>
      'Hər sətirə bir ad yazın; şriftlər ardıcıllıqla yoxlanır.';

  @override
  String get appearanceFontImport => 'İnterfeys şrift faylını idxal et';

  @override
  String get appearanceGradient => 'Qradient';

  @override
  String get appearanceNoBackground => 'Fon yoxdur';

  @override
  String get appearanceIcons => 'Tətbiqdaxili ikonlar';

  @override
  String get appearanceCorners => 'Künclər';

  @override
  String get appearanceCardCorners => 'Kart küncləri';

  @override
  String get appearanceTileCorners => 'Element küncləri';

  @override
  String get appearanceButtonCorners => 'Düymə küncləri';

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
  String askAiConfigMissing(String fields) {
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
  String get remoteDesktop => 'Uzaq masaüstü';

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
      'Bu mesajdan sonrakı hər şey — cavablar, əmrlər və onların nəticələri silinəcək.';

  @override
  String get askAiDeleteTip =>
      'Bu mesaj və ondan sonrakı hər şey — cavablar, əmrlər və onların nəticələri silinəcək.';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'models.dev saytından model adına görə kontekst ölçüləri. Biri tətbiqlə birlikdə verilir; yenisini əldə etmək üçün toxunun.';

  @override
  String get askAiContextFallback => 'cədvəldə yoxdur';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      'Əvvəlki dialoq hissələri xülasə edilməzdən öncə model kontekstinin nə qədər dolacağını müəyyən edir. Daha erkən xülasə detalları tez itirir, daha gec xülasə isə modelin sorğunu rədd etməsi riskini artırır.';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'Bu modelin neçə token saxladığını göstərir. Avtomatik rejim bunu ada görə tapır; provider daha qısa kontekst pəncərəsi təqdim edirsə, rəqəmi özünüz təyin edin.';

  @override
  String get askAiConversationCompacted =>
      'Söhbətin davam etməsi üçün əvvəlki mesajlar xülasə edildi.';

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
  String agentToolCallsFmt(int count) {
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
  String nTags(int count) {
    return '$count etiket';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Uzaq ehtiyat nüsxələr üçün boş olmayan ehtiyat nüsxə parolu tələb olunur';

  @override
  String get monitorSyncServerTip =>
      'Ehtiyat nüsxə bu serverin monitor agentində saxlanılır və ehtiyat nüsxə parolu ilə şifrələnir. Onun paneli faylı saxlaya və oxuya bilmədən geri qaytara bilər.';

  @override
  String get monitorSyncNeedsServer =>
      'Ehtiyat nüsxənin monitor agentinə göndəriləcəyi serveri seçin.';

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
  String madeWithLove(String myGithub) {
    return '$myGithub tərəfindən ❤️ ilə hazırlanıb';
  }

  @override
  String get maxConcurrency => 'Maksimum paralel əməliyyat sayı';

  @override
  String get maxRetryCount => 'Serverlə yenidən əlaqə cəhdlərinin sayı';

  @override
  String mismatchSystem(String system) {
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
  String get sshConnectionModeTip =>
      'Daxili: tətbiqin terminalından istifadə et. Sistem SSH: sistemin ssh əmrini xarici terminalda başlat.';

  @override
  String get sshConnectionModeUseBuiltin => 'Daxili terminaldan istifadə et';

  @override
  String get sshConnectionModeUseSystem => 'Sistem SSH istifadə et';

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
  String portForward_deleteConfirmFmt(String name) {
    return '$name silinsin?';
  }

  @override
  String get sponsor => 'Sponsor ol';

  @override
  String get sortByJoinTime => 'Əlavə edilmə vaxtına görə';

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
  String transportOrderFmt(String first, String second) {
    return 'Sıranı dəyişmək üçün sürüşdürün. Əvvəlcə $first yığılır; cavab verməsə, sessiyanı $second təkbaşına aparır.';
  }

  @override
  String transportOnlyFmt(String name) {
    return 'Yalnız $name açıqdır, ona görə də geri dönüləcək bir şey yoxdur.';
  }

  @override
  String get transportNoneOn =>
      'Hər ikisi bağlıdır — bu serverə qoşulmaq mümkün deyil.';

  @override
  String get transportOffKept =>
      'bağlı — parametrlər saxlanılır, heç vaxt yığılmır';

  @override
  String get transportDialledFirst => 'əvvəlcə yığılır';

  @override
  String get transportFallback => 'ehtiyat';

  @override
  String get transportOnlyMethod => 'yeganə üsul';

  @override
  String get transportOff => 'bağlı';

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
  String get optionalTip =>
      'Burada heç nə qoşulmaq üçün lazım deyil. Birini açın, onun sahələri formanı əvəz edir.';

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
  String appearanceThemeModeLocked(String mode) {
    return 'Bu mövzu yalnız $mode rejimini dəstəkləyir. Rejimi dəyişmək üçün başqa mövzu seçin.';
  }
}
