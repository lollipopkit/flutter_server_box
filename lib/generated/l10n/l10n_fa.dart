// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Persian (`fa`).
class AppLocalizationsFa extends AppLocalizations {
  AppLocalizationsFa([String locale = 'fa']) : super(locale);

  @override
  String get crashCollect => 'داده‌های عیب‌یابی';

  @override
  String get crashCollectIntro =>
      'ServerBox هنگام اجرا اطلاعاتی را ثبت می‌کند تا بتوانیم مشکلات را بررسی و رفع کنیم.';

  @override
  String get crashCollectNone => 'هیچ‌کدام';

  @override
  String get crashCollectNoneTip =>
      'گزارش فقط در این دستگاه ذخیره می‌شود. پس از بروز خرابی، می‌توانید آن را دستی ارسال کنید.';

  @override
  String get crashCollectBasic => 'اطلاعات پایه';

  @override
  String get crashCollectBasicTip =>
      'فقط اطلاعات خرابی برنامه ثبت می‌شود و گزارش‌ها یا داده‌های عملکردی در آن نیست. **این اطلاعات به بهبود برنامه و رفع اشکال‌ها کمک می‌کند.**';

  @override
  String get crashCollectFooter =>
      'صرف‌نظر از سطح انتخاب‌شده، هنگام ثبت اطلاعات، نام‌ها، نشانی‌ها و نام‌های کاربری سرورهای شناخته‌شده با مقادیر جایگزین می‌شوند. بعداً می‌توانید سطح جمع‌آوری اطلاعات را در تنظیمات تغییر دهید.';

  @override
  String get privacy => 'حریم خصوصی';

  @override
  String get privacyPolicy => 'سیاست حریم خصوصی';

  @override
  String get crashLastRunFailed =>
      'برنامه ServerBox در اجرای قبلی خود به‌طور غیرمنتظره متوقف شد.';

  @override
  String get crashReportTitle => 'گزارش خرابی';

  @override
  String get crashReportHint =>
      'این لاگ مربوط به اجرای قبلی است. نام‌ها و نشانی‌های سرور شناخته‌شده با مقادیر جایگزین عوض شده‌اند، اما ممکن است جزئیات دیگری باقی مانده باشد. لطفاً پیش از ارسال، آن را با دقت بررسی کنید.';

  @override
  String get crashReportSubmit => 'کپی و گزارش';

  @override
  String get preReleaseUpdates => 'دریافت به‌روزرسانی‌های پیش‌انتشار';

  @override
  String get addSystemPrivateKeyTip =>
      'در حال حاضر کلید خصوصی وجود ندارد؛ آیا می‌خواهید کلید پیش‌فرض سیستم (~/.ssh/id_rsa) را اضافه کنید؟';

  @override
  String get added2List => 'به فهرست وظایف افزوده شد';

  @override
  String get askAi => 'پرسش از هوش مصنوعی';

  @override
  String get askAiInsertTerminal => 'درج در ترمینال';

  @override
  String get remoteDesktop => 'دسکتاپ از راه دور';

  @override
  String get askAiRiskReadOnly => 'فقط‌خواندنی';

  @override
  String get askAiRiskCaution => 'ایجاد تغییرات در سیستم';

  @override
  String get askAiRiskUnvetted => 'میزبان بررسی‌نشده';

  @override
  String get askAiRiskDestructive => 'خطر بالا';

  @override
  String get askAiAutoRunSafeCommands => 'اجرای خودکار دستورهای فقط‌خواندنی';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'فقط زمانی اجرا می‌شود که هم مدل و هم بررسی محلی آن را فقط‌خواندنی تشخیص دهند';

  @override
  String get askAiHistory => 'تاریخچه گفتگو';

  @override
  String get askAiNewConversation => 'گفتگوی جدید';

  @override
  String get askAiUntitledConversation => 'بدون عنوان';

  @override
  String get askAiRenameConversation => 'تغییر نام گفتگو';

  @override
  String get askAiDeleteConversationTitle => 'این گفتگو حذف شود؟';

  @override
  String get askAiDeleteConversationTip =>
      'از این دستگاه حذف می‌شود. این عمل غیرقابل‌بازگشت است.';

  @override
  String get agentNoHistory =>
      'هیچ گفتگوی سراسری ذخیره‌شده‌ای برای Agent وجود ندارد';

  @override
  String get agentClearHistoryTitle => 'پاک کردن تاریخچه سراسری Agent؟';

  @override
  String get agentClearHistoryTip =>
      'تمام گفتگوهای سراسری Agent از این دستگاه حذف خواهند شد.';

  @override
  String get agentCommandMayStillRun =>
      'دستور متوقف‌شده ممکن است همچنان در سرور در حال اجرا باشد.';

  @override
  String get agentToolShell => 'پوسته (Shell)';

  @override
  String get agentToolReadFile => 'خواندن فایل';

  @override
  String get agentToolWriteFile => 'نوشتن فایل';

  @override
  String get floatOverTabs => 'شناور روی تب‌های دیگر';

  @override
  String get agentToolSshConnect => 'اتصال SSH';

  @override
  String get agentToolSshDisconnect => 'قطع اتصال SSH';

  @override
  String get agentSshConnectTitle => 'اتصال به میزبان جدید';

  @override
  String get agentAuthMethod => 'احراز هویت';

  @override
  String get agentSshConnectTip =>
      'Agent درخواست ایجاد اتصال SSH دارد. گذرواژه را اینجا وارد کنید.';

  @override
  String get agentAdHocSessions => 'اتصال‌های موقت';

  @override
  String get agentSaveServerTitle => 'ذخیره به‌عنوان سرور';

  @override
  String get agentSaveServerTip =>
      'اطلاعات این میزبان و گذرواژه‌ای که وارد می‌کنید در این دستگاه ذخیره می‌شود.';

  @override
  String get agentMonitorOptional => 'ایجنت Monitor (اختیاری)';

  @override
  String get authFailTip => 'احراز هویت ناموفق بود. مشخصات را بررسی کنید';

  @override
  String get autoBackupConflict =>
      'هم‌زمان فقط یک پشتیبان‌گیری خودکار می‌تواند فعال باشد.';

  @override
  String get autoConnect => 'اتصال خودکار';

  @override
  String get autoRun => 'اجرای خودکار';

  @override
  String get autoUpdateHomeWidget => 'به‌روزرسانی خودکار ویجت صفحه اصلی';

  @override
  String get availableTabs => 'تب‌های موجود';

  @override
  String get backupEncrypted => 'نسخه پشتیبان رمزگذاری شده است';

  @override
  String get backupNotEncrypted => 'نسخه پشتیبان رمزگذاری نشده است';

  @override
  String get backupPassword => 'گذرواژه پشتیبان‌گیری';

  @override
  String get backupPasswordRemoved => 'گذرواژه پشتیبان‌گیری حذف شد';

  @override
  String get backupPasswordSet => 'گذرواژه پشتیبان‌گیری تنظیم شد';

  @override
  String get backupPasswordTip =>
      'برای رمزگذاری فایل‌های پشتیبان، گذرواژه‌ای تعیین کنید. برای غیرفعال کردن رمزگذاری، آن را خالی بگذارید.';

  @override
  String get backupPasswordWrong => 'گذرواژه پشتیبان‌گیری نادرست است';

  @override
  String get connectAll => 'اتصال به همه';

  @override
  String get disconnectAll => 'قطع اتصال همه';

  @override
  String get distIcon => 'نشان‌های توزیع';

  @override
  String get distIconIntroLegal =>
      'هر نشان صرفاً بیانگر اطلاعاتی است که این دستگاه از سیستم دوردست خوانده است، که ممکن است نادرست یا قدیمی باشد، و نشان‌دهنده توزیع اشتقاقی، بازتولید یا نسخه خاصی نیست. در صورت عدم شناسایی، یک آیکون ساده نمایش داده می‌شود.\n\nهر نشان، علامت تجاری مالک مربوطه خود است و صرفاً برای اشاره به سیستم شناسایی‌شده استفاده می‌شود.';

  @override
  String get distIconTip =>
      'نمایش یک نشان کوچک در کنار هر سرور برای سیستمی که به نظر می‌رسد در حال اجرای آن است.';

  @override
  String get distNameMap => 'جایگزینی نام‌ها';

  @override
  String get distNameMapTip =>
      'فقط وقتی نام فایل نماد توزیع در محل میزبانی با نامی که برنامه استفاده می‌کند متفاوت است، این مورد را تنظیم کنید. کلید، نام مورد استفاده برنامه و مقدار، نام واقعی فایل است. اگر نمادی کم نیست، آن را خالی بگذارید.';

  @override
  String get logoUrl => 'نشانی URL لوگو';

  @override
  String get logoUrlTip =>
      'تصویر بزرگ بالای صفحه اختصاصی هر سرور، که با رنگ‌های اختصاصی آن نمایش داده می‌شود.';

  @override
  String get globe => 'کره زمین';

  @override
  String get locationTip =>
      'محل نمایش این سرور روی کره زمین. ابتدا عرض جغرافیایی سپس طول جغرافیایی، برحسب درجه — برای مثال 39.9042, 116.4074.';

  @override
  String get markUrl => 'نشانی URL نشان';

  @override
  String get markUrlTip =>
      'نشان کوچک کنار نام سرور در فهرست‌ها. خالی بودن یعنی نشانی نمایش داده نمی‌شود.\n\nبا تصویر لوگو یکی نیست';

  @override
  String get navTabMenuTip =>
      'برای اتصال یا قطع اتصال هم‌زمان همه سرورهای یک برگه، آن را لمس کنید و نگه دارید یا با دکمه راست ماوس روی آن کلیک کنید.';

  @override
  String nTags(int count) {
    return '$count برچسب';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'پشتیبان‌گیری از راه دور نیازمند گذرواژه پشتیبان‌گیری غیرخالی است';

  @override
  String get monitorHttpsRequired =>
      'یک ایجنت Monitor از راه دور به HTTPS نیاز دارد، مگر اینکه HTTP برای آن مجاز شده باشد.';

  @override
  String get monitorAllowInsecureHttp => 'مجاز کردن HTTP';

  @override
  String get plainHttpTitle =>
      'این Monitor از HTTP بدون رمزنگاری استفاده می‌کند';

  @override
  String get plainHttpTip =>
      'گذرواژه و همه داده‌هایی که برنامه درخواست می‌کند بدون رمزنگاری منتقل می‌شوند. تا زمانی که اتصال را مجاز نکنید، هیچ داده‌ای ارسال نمی‌شود.';

  @override
  String get allowForThisServer => 'مجاز کردن برای این سرور';

  @override
  String get viewError => 'مشاهده خطا';

  @override
  String get monitorAllowInsecureHttpTip =>
      'فقط در یک شبکه خصوصی قابل‌اعتماد که خودِ لایه انتقال را رمزگذاری می‌کند، مانند Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'وضعیت این سرور را از طریق رابط HTTP **Monitor** بخوانید، نه با اجرای دستورها از طریق SSH.\n\nابتدا باید Monitor را روی سرور نصب کنید؛ نمودارها، برنامه Apple Watch و ویجت‌های صفحه اصلی به آن نیاز دارند.\n\n[روش راه‌اندازی Monitor]($url)';
  }

  @override
  String get backupThemesNotRestored =>
      'بازیابی شد، به‌جز این پوسته‌ها. آن‌ها را مجدداً از فروشگاه پوسته یا فایل مبدأ نصب کنید.';

  @override
  String get backupTip =>
      'داده‌های خروجی گرفته‌شده می‌توانند با گذرواژه رمزگذاری شوند.\nلطفاً از آن به‌خوبی محافظت کنید.';

  @override
  String get icloudBackupStatusTitle => 'وضعیت پشتیبان‌گیری';

  @override
  String get icloudBackupStatusLoading =>
      'در حال بارگیری وضعیت پشتیبان‌گیری iCloud...';

  @override
  String get icloudBackupStatusError =>
      'امکان خواندن متاداده پشتیبان‌گیری iCloud وجود ندارد';

  @override
  String get icloudBackupStatusEmpty =>
      'هنوز هیچ فایل پشتیبان‌گیری iCloud یافت نشد';

  @override
  String get icloudBackupStateUploading => 'در حال بارگذاری';

  @override
  String get icloudBackupStateConflict => 'تداخل شناسایی شد';

  @override
  String get icloudBackupStateUploaded => 'بارگذاری شد';

  @override
  String get icloudBackupStateWaiting => 'در انتظار iCloud';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return 'آخرین پشتیبان‌گیری: $lastModified\nوضعیت: $remoteState';
  }

  @override
  String get bgRun => 'اجرا در پس‌زمینه';

  @override
  String get bgRunTip =>
      'این گزینه صرفاً به این معناست که برنامه برای اجرا در پس‌زمینه تلاش خواهد کرد. امکان اجرای برنامه در پس‌زمینه به فعال بودن مجوز مربوطه بستگی دارد. در ROMهای Android مبتنی بر AOSP، لطفاً «بهینه‌سازی باتری» را برای این برنامه غیرفعال کنید. برای MIUI / HyperOS، لطفاً خط‌مشی ذخیره انرژی را روی «نامحدود» قرار دهید.';

  @override
  String get trayReadings => 'شاخص‌ها';

  @override
  String get trayChart => 'نمودار';

  @override
  String get trayChartNone => 'هیچ‌کدام';

  @override
  String get trayCompact => 'ردیف‌های فشرده';

  @override
  String get trayCompactTip =>
      'یک خط برای هر سرور، بدون نمودار. سیستم‌عامل Linux همیشه از طرح‌بندی تک‌خطی استفاده می‌کند زیرا منوی پنل آن از طریق D-Bus ارسال می‌شود که به جای طرح‌بندی سفارشی، فقط یک برچسب حمل می‌کند؛ البته ممکن است همچنان نمودار انتخاب‌شده را به‌صورت تصویر نمایش دهد.';

  @override
  String get trayKeepRunning => 'ادامه اجرا در سینی سیستم (Tray)';

  @override
  String get trayKeepRunningTip =>
      'بستن پنجره، برنامه را در نوار منو یا ناحیه اعلان نگه می‌دارد تا همچنان وضعیت سرورهای شما را بررسی کند. با غیرفعال کردن این گزینه، دکمه بستن باعث خروج کامل از برنامه می‌شود.';

  @override
  String get bgRunNeedsNotification =>
      'اجرا در پس‌زمینه نیازمند یک اعلان مداوم است و این برنامه مجوز اعلان ندارد. برای مجاز کردن اعلان‌ها ضربه بزنید.';

  @override
  String get clearAllStatsContent =>
      'آیا مطمئن هستید که می‌خواهید تمام آمارهای اتصال سرور را پاک کنید؟ این عمل غیرقابل‌بازگشت است.';

  @override
  String get clearAllStatsTitle => 'پاک کردن همه آمارها';

  @override
  String get clearAllSettings => 'پاک کردن همه تنظیمات';

  @override
  String clearServerStatsContent(String serverName) {
    return 'آیا مطمئن هستید که می‌خواهید آمارهای اتصال را برای سرور «$serverName» پاک کنید؟ این عمل غیرقابل‌بازگشت است.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return 'پاک کردن آمارهای $serverName';
  }

  @override
  String get clearThisServerStats => 'پاک کردن آمارهای این سرور';

  @override
  String get closeAfterSave => 'ذخیره و بستن';

  @override
  String get collapseUITip => 'جمع شدن پیش‌فرض فهرست‌های طولانی در رابط کاربری';

  @override
  String get connectionDetails => 'جزئیات اتصال';

  @override
  String get connectionStats => 'آمارهای اتصال';

  @override
  String get connectionStatsDesc =>
      'مشاهده درصد موفقیت و تاریخچه اتصال‌های سرور';

  @override
  String get containerTrySudoTip =>
      'برای مثال، اگر نام کاربری را در برنامه aaa تنظیم کرده‌اید اما Docker با کاربر root نصب شده است، این گزینه را فعال کنید.';

  @override
  String get containerSudoPasswordRequired =>
      'برای دسترسی به Docker گذرواژه sudo لازم است. آن را وارد کنید.';

  @override
  String get containerSudoPasswordIncorrect =>
      'گذرواژه sudo نادرست است یا این حساب اجازه استفاده از sudo را ندارد. دوباره تلاش کنید.';

  @override
  String get copyPath => 'کپی مسیر';

  @override
  String get customCmd => 'دستورهای سفارشی';

  @override
  String get deleteServers => 'حذف گروهی سرورها';

  @override
  String get deleteDirRecursive => 'حذف پوشه و تمام محتویات آن';

  @override
  String get dirEmpty => 'مطمئن شوید که پوشه خالی است.';

  @override
  String get discoverSshServers => 'یافتن سرورهای SSH';

  @override
  String get discoveryFailed => 'شناسایی ناموفق بود';

  @override
  String get discoverySettings => 'تنظیمات شناسایی';

  @override
  String get distro => 'توزیع';

  @override
  String get diskHealth => 'سلامت دیسک';

  @override
  String dl2Local(String fileName) {
    return 'دانلود $fileName در حافظه محلی دستگاه؟';
  }

  @override
  String get dockerEmptyRunningItems =>
      'هیچ کانتینر در حال اجرایی وجود ندارد.\nاین مشکل ممکن است به دلایل زیر باشد:\n- کاربری که Docker با آن نصب شده است با نام کاربری تنظیم‌شده در برنامه یکسان نیست.\n- متغیر محیطی DOCKER_HOST به‌درستی خوانده نشده است. می‌توانید با اجرای دستور `echo \$DOCKER_HOST` در ترمینال آن را بیابید.';

  @override
  String get dockerProjectOther => 'سایر';

  @override
  String get dockerPruneTip =>
      'حذف داده‌های استفاده‌نشده برای آزادسازی فضای دیسک';

  @override
  String get dockerStatistics => 'آمارهای Docker';

  @override
  String get editVirtKeys => 'کلیدهای مجازی';

  @override
  String get editorHighlightTip =>
      'عملکرد فعلی برجسته‌سازی کد بهینه نیست و برای بهبود سرعت می‌توانید آن را به‌صورت اختیاری غیرفعال کنید.';

  @override
  String get enableMdns => 'فعال‌سازی mDNS';

  @override
  String get enableMdnsDesc =>
      'استفاده از mDNS/Bonjour برای شناسایی سرویس‌های SSH';

  @override
  String get envVars => 'متغیرهای محیطی';

  @override
  String get extraArgs => 'آرگومان‌های اضافی';

  @override
  String get fallbackSshDest => 'مقصد جایگزین SSH';

  @override
  String get fdroidReleaseTip =>
      'اگر این برنامه را از F-Droid دانلود کرده‌اید، توصیه می‌شود این گزینه را غیرفعال کنید.';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return 'اندازه فایل «$file» برابر $size است و از حد مجاز $sizeMax بیشتر است.';
  }

  @override
  String fileChangedOverwrite(String file) {
    return '\'$file\' پس از باز شدن روی سرور تغییر کرده است. بازنویسی شود؟';
  }

  @override
  String get fileDirGone => 'این پوشه دیگر در اینجا وجود ندارد';

  @override
  String get fileDirGoneTip => 'این پوشه حذف شده یا تغییر نام یافته است';

  @override
  String get fullScreen => 'تمام‌صفحه';

  @override
  String get fullScreenJitter => 'لرزش تمام‌صفحه';

  @override
  String get fullScreenJitterHelp =>
      'برای جلوگیری از ماندگاری تصویر روی صفحه (Burn-in)';

  @override
  String get fullScreenTip =>
      'آیا با چرخش دستگاه به حالت افقی، حالت تمام‌صفحه فعال شود؟ این گزینه فقط در تب سرورها اعمال می‌شود.';

  @override
  String get githubGistIdOptional => 'شناسه Gist (اختیاری)';

  @override
  String get githubGistToken => 'توکن GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'توکن خالی است';

  @override
  String get githubGistIdInvalid =>
      'این مقدار نه شناسه Gist است و نه پیوند Gist. بخش پایانی نشانی Gist را وارد کنید (https://gist.github.com/<user>/<ID>)، یا آن را خالی بگذارید تا در اولین پشتیبان‌گیری یک Gist خصوصی جدید ایجاد شود.';

  @override
  String get githubGistNotFound =>
      'در GitHub هیچ Gist با این شناسه که توسط این توکن قابل خواندن باشد یافت نشد: ممکن است شناسه نادرست باشد، Gist حذف شده باشد، یا به حساب کاربری دیگری تعلق داشته باشد. شناسه را خالی بگذارید تا در اولین پشتیبان‌گیری یک Gist خصوصی جدید ایجاد شود.';

  @override
  String get githubGistTokenRejected =>
      'سامانه GitHub این توکن را رد کرد: ممکن است نادرست، منقضی یا باطل شده باشد، یا فاقد مجوز gist باشد (توکن کلاسیک: محدوده «gist»؛ توکن دقیق (Fine-grained): دسترسی خواندن و نوشتن «Gists»).';

  @override
  String get goto => 'رفتن به';

  @override
  String get homeTabs => 'تب‌های صفحه اصلی';

  @override
  String get homeTabsCustomizeDesc =>
      'سفارشی‌سازی تب‌های نمایش داده‌شده در صفحه اصلی و ترتیب آن‌ها';

  @override
  String get ignoreCert => 'نادیده گرفتن گواهی';

  @override
  String get image => 'ایمیج';

  @override
  String get macDmgBody =>
      'فروشگاه App Store الزام می‌کند که این برنامه محدود به Sandbox باشد، و محیط Sandbox امکان باز کردن ترمینال را ندارد. اما نسخه DMG این امکان را دارد.\n\nممکن است به‌روزرسانی نسخه App Store متوقف شود.';

  @override
  String get macDmgImportDenied =>
      'سیستم‌عامل macOS اجازه خواندن داده‌های نسخه قبلی را نداد';

  @override
  String get macDmgImported => 'داده‌های نسخه قبلی وارد شد';

  @override
  String get macDmgImportFailed => 'امکان خواندن داده‌های نسخه قبلی وجود نداشت';

  @override
  String get macDmgTip =>
      'نسخه DMG از ترمینال محلی و اجرای قطعه‌کدها روی همین دستگاه پشتیبانی می‌کند.';

  @override
  String get macDmgTitle => 'نسخه DMG';

  @override
  String get showHiddenFiles => 'نمایش فایل‌های مخفی';

  @override
  String get sshKeyAlgorithm => 'الگوریتم';

  @override
  String get sshKeyComment => 'توضیحات';

  @override
  String get sshKeyGenerate => 'تولید جفت‌کلید';

  @override
  String get sshKeyGenerating => 'در حال تولید…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'کلید خصوصی [$name] قفل‌گشایی نشد.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'اختیاری. کلید دارای عبارت عبور به‌صورت رمزگذاری‌شده ذخیره می‌شود، و در اولین اتصالی که از این کلید استفاده می‌کند از شما درخواست خواهد شد.';

  @override
  String get sshKeyPassphraseWrong => 'عبارت عبور نادرست است.';

  @override
  String get sshKeyPublicKey => 'کلید عمومی';

  @override
  String get sshKeyPublicKeyTip =>
      'این خط را به انتهای فایل ~/.ssh/authorized_keys در سرور اضافه کنید.';

  @override
  String get sshKeyRecommended => 'توصیه‌شده';

  @override
  String get rememberKeyPassphrase => 'به‌خاطر سپردن عبارت‌های عبور کلید';

  @override
  String get rememberKeyPassphraseTip =>
      'عبارت‌های عبور کلیدهای خصوصی رمزگذاری‌شده را در Keychain سیستم این دستگاه ذخیره کنید تا پس از راه‌اندازی مجدد درخواست نشوند. کلیدها در فایل‌های پشتیبان رمزگذاری‌شده باقی می‌مانند. غیرفعال کردن این گزینه عبارت‌های عبور ذخیره‌شده را حذف می‌کند.';

  @override
  String sshKeyUnlockTip(String name) {
    return 'عبارت عبور کلید خصوصی [$name] را وارد کنید.';
  }

  @override
  String get ungrouped => 'دسته‌بندی‌نشده';

  @override
  String get containerReclaimable => 'قابل آزادسازی';

  @override
  String get unused => 'استفاده‌نشده';

  @override
  String get dangling => 'معلق';

  @override
  String get pruneUnusedImages => 'پاک‌سازی ایمیج‌های استفاده‌نشده';

  @override
  String get pruneDanglingImages => 'پاک‌سازی ایمیج‌های معلق';

  @override
  String get pruneImages => 'پاک‌سازی ایمیج‌ها';

  @override
  String get unusedTaggedImages => 'دارای برچسب و استفاده‌نشده';

  @override
  String get pruneDanglingImagesTip => 'فقط ایمیج‌های معلق را حذف می‌کند.';

  @override
  String get pruneUnusedImagesTip =>
      'حذف ایمیج‌های دارای برچسب که توسط هیچ کانتینری استفاده نمی‌شوند نیز انجام شود.';

  @override
  String get includeUnusedVolumesTip =>
      'حذف Volumeهایی که توسط هیچ کانتینری استفاده نمی‌شوند نیز انجام شود.';

  @override
  String get pruneCommandPreview => 'پیش‌نمایش دستور';

  @override
  String get pruneForceSshTip =>
      'گزینه -f از اعلان تعاملی صرف‌نظر می‌کند و برای اجرای SSH همیشه فعال است.';

  @override
  String get pruneVolumes => 'پاک‌سازی Volumeها';

  @override
  String get pruneUnusedData => 'پاک‌سازی داده‌های استفاده‌نشده';

  @override
  String get pull => 'دریافت (Pull)';

  @override
  String get invalidHostFormat =>
      'قالب میزبان نامعتبر است. فقط کاراکترهای IPv4، IPv6 و دامنه مجاز هستند.';

  @override
  String get jumpServer => 'سرور واسط (Jump)';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return 'سرورهای واسط (Jump) برای $serverName یافت نشدند: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return 'نام «$name» از قبل وجود دارد';
  }

  @override
  String get noJumpServerAvailable => 'هیچ سرور واسطی (Jump) در دسترس نیست.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'امکان استفاده هم‌زمان از سرور واسط (Jump) و ProxyCommand وجود ندارد.';

  @override
  String get noConnectionMethod => 'SSH، Monitor یا هر دو را پیکربندی کنید.';

  @override
  String get keepForeground => 'برنامه را در پیش‌زمینه نگه دارید!';

  @override
  String get keepStatusWhenErr => 'حفظ آخرین وضعیت سرور';

  @override
  String get keepStatusWhenErrTip =>
      'فقط در صورت بروز خطا در حین اجرای اسکریپت';

  @override
  String get keyAuth => 'احراز هویت با کلید';

  @override
  String get lastFailure => 'آخرین شکست';

  @override
  String get lastSuccess => 'آخرین موفقیت';

  @override
  String get letterCache => 'ورودی عادی صفحه‌کلید';

  @override
  String get letterCacheTip =>
      'در صورت فعال بودن، ورودی از طریق IME معمولی پردازش می‌شود که می‌تواند در برخی سیستم‌ها از نمایش اعلان‌های صفحه‌کلید امن در ترمینال جلوگیری کند.';

  @override
  String get linuxShellTip =>
      'ترمینال با کدام پوسته (Shell) شروع به کار کند. خالی گذاشتن آن /bin/sh را بازیابی می‌کند.';

  @override
  String get linuxNetTip =>
      'سرورهای DNS. برای استفاده از تنظیمات پیش‌فرض، خالی بگذارید.';

  @override
  String madeWithLove(String myGithub) {
    return 'ساخته‌شده با ❤️ توسط $myGithub';
  }

  @override
  String get maxConcurrency => 'حداکثر هم‌زمانی';

  @override
  String get maxRetryCount => 'حداکثر تعداد تلاش برای اتصال دوباره به سرور';

  @override
  String get mirror => 'سرور آینه (Mirror)';

  @override
  String get needRestart => 'برنامه باید مجدداً راه‌اندازی شود';

  @override
  String get newContainer => 'کانتینر جدید';

  @override
  String get noConnectionStatsData => 'داده‌ای برای آمار اتصال وجود ندارد';

  @override
  String get noPrivateKeyTip =>
      'کلید خصوصی وجود ندارد؛ ممکن است حذف شده باشد یا خطایی در پیکربندی رخ داده باشد.';

  @override
  String get noPromptAgain => 'دیگر پرسیده نشود';

  @override
  String get openLastPath => 'باز کردن آخرین مسیر';

  @override
  String get openLastPathTip =>
      'سرورهای مختلف لاگ‌های متفاوتی خواهند داشت، و لاگ مسیری به‌سوی خروج است';

  @override
  String get parseContainerStatsTip =>
      'تجزیه وضعیت مصرف منابع Docker نسبتاً کند است.';

  @override
  String get privateKey => 'کلید خصوصی';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return 'کلید خصوصی [$keyId] یافت نشد.';
  }

  @override
  String get bmcPowerOnAction => 'روشن کردن';

  @override
  String get bmcShutdown => 'خاموش کردن';

  @override
  String get bmcForceOff => 'خاموش کردن اجباری';

  @override
  String get restart => 'راه‌اندازی مجدد';

  @override
  String get bmcPowerCycle => 'قطع و وصل برق (Power Cycle)';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'آیا این دستور به $server ارسال شود؟ از سرویس برای «$resetType» درخواست خواهد شد';
  }

  @override
  String get bmcPowerDone => 'وضعیت برق تغییر کرد';

  @override
  String get bmcPowerAccepted =>
      'درخواست پذیرفته شد، اما وضعیت برق هنوز تغییر نکرده است. اجرای بدون نقص به سیستم‌عامل بستگی دارد';

  @override
  String get bmcPowerUnsupported =>
      'این سرویس از این نوع عملیات پشتیبانی نمی‌کند.';

  @override
  String get bmcUnauthorized => 'سیستم BMC حساب کاربری را رد کرد';

  @override
  String get bmcAccountMissing => 'هیچ حساب کاربری برای این BMC تنظیم نشده است';

  @override
  String get bmcPowerOn => 'روشن شد';

  @override
  String get bmcPowerOff => 'خاموش شد';

  @override
  String get bmcCertRejected =>
      'گواهی رد شد — آن را در تنظیمات سرور بررسی کنید';

  @override
  String get bmcNotAService => 'هیچ سرویس Redfish در این نشانی وجود ندارد';

  @override
  String get bmcNoSystem => 'این سرویس هیچ سیستمی گزارش نکرده است.';

  @override
  String get bmcSensorsTruncated => 'تنها حسگرهای نخست نمایش داده می‌شوند';

  @override
  String get bmcMultipleSystems => 'تنها سیستم نخست نمایش داده می‌شود';

  @override
  String get bmcTip =>
      'کنترل‌کننده BMC یک رایانه جداگانه روی مادربرد است که هنگام در دسترس نبودن سیستم‌عامل میزبان نیز قابل دسترسی است. در صورت پیکربندی در اینجا، می‌تواند وضعیت برق و حسگرهای سخت‌افزاری را در زمان خاموش بودن یا هنگ کردن سرور گزارش دهد. این قابلیت به Redfish نیاز دارد که بیشتر سخت‌افزارهای سازمانی از حدود سال ۲۰۱۶ به بعد از آن برخوردارند.';

  @override
  String get bmcCert => 'گواهی';

  @override
  String get bmcCertPinned => 'بررسی و پین شده';

  @override
  String get bmcCertUnreviewed =>
      'هنوز بررسی نشده است — برای مشاهده گواهی ضربه بزنید';

  @override
  String get bmcCertReview =>
      'یک گواهی خودامضا است. پیش از پذیرش آن را مقایسه کنید. پس از آن تنها دقیقاً همین گواهی مورد اعتماد خواهد بود.';

  @override
  String get bmcCertChanged => 'گواهی مطابقت ندارد. آن را بررسی کنید.';

  @override
  String get bmcCertExpired => 'منقضی شده است.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'قبلاً پذیرفته شده: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'نشانی BMC باید یک URL باشد، مانند https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'این نسخه در sandbox اجرا می‌شود: دستورها به‌جای پوشه خانگی شما از یک پوشه خانگی خالی استفاده می‌کنند. بنابراین دستورهایی که به ~/.ssh نیاز دارند با خطا روبه‌رو می‌شوند. نسخه DMG این محدودیت را ندارد.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'خواندن فایل کلید خصوصی $path ممکن نیست: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'این نسخه نمی‌تواند فایل‌های خارج از کانتینر خود را بخواند، بنابراین کلید در $path غیرقابل دسترس است. کلید را در «تنظیمات» وارد کنید یا از نسخه DMG استفاده نمایید.';
  }

  @override
  String get pushToken => 'توکن Push';

  @override
  String get liveActivity => 'فعالیت زنده (Live Activity)';

  @override
  String get liveActivityTip =>
      'نمایش نشست‌های ترمینال در Lock Screen و Dynamic Island. بدون باز کردن قفل، نام سرور و وضعیت اتصال در آنجا قابل مشاهده خواهد بود.';

  @override
  String get liveActivitySystemDisabled =>
      'سیستم‌عامل iOS این اجازه را نمی‌دهد. کلیدهای فعال‌سازی در مسیر Settings › ServerBox › Live Activities و Settings › Face ID & Passcode › Live Activities قرار دارند.';

  @override
  String get proxyCommandNeedsLinux =>
      'دستور ProxyCommand در محیط Linux این دستگاه اجرا می‌شود. ابتدا یک سیستم Linux نصب کنید.';

  @override
  String get proxyCommandMobileTip =>
      'در گوشی تلفن، این دستور در سیستم Linux انتخاب‌شده اجرا می‌شود. ابتدا ابزارهای مورد استفاده آن (nc، socat، …) را در آنجا نصب کنید.';

  @override
  String get pveIgnoreCertTip =>
      'اگر PVE از گواهی خودامضای پیش‌فرض استفاده می‌کند، باید این گزینه را فعال کنید؛ اما این کار خطر امنیتی دارد.';

  @override
  String get pvePasswordRequired =>
      'گذرواژه PVE الزامی است. لطفاً آن را در تنظیمات سرور تعیین کنید.';

  @override
  String get pveOtpRequired =>
      'احراز هویت دو مرحله‌ای در این سرور PVE فعال است. لطفاً کد OTP را وارد کنید.';

  @override
  String get pveOtpCodeRequired => 'کد OTP الزامی است.';

  @override
  String get pveOtpVerificationFailed =>
      'تأیید کد OTP ناموفق بود. لطفاً با یک کد جدید دوباره تلاش کنید.';

  @override
  String get pveOtpTitle => 'تأیید OTP';

  @override
  String get pveOtpLabel => 'کد OTP';

  @override
  String get pveInvalidResponseBody =>
      'ورود به PVE یک بدنه پاسخ نامعتبر بازگرداند.';

  @override
  String get pveInvalidResponseData =>
      'پاسخ ورود به PVE فاقد فیلد data معتبر است.';

  @override
  String get pveMissingAuthTicket =>
      'ورود به PVE موفقیت‌آمیز بود اما هیچ بلیت احراز هویتی بازگردانده نشد.';

  @override
  String get pveLoadingConnect => 'در حال اتصال...';

  @override
  String get pvePassword => 'گذرواژه PVE';

  @override
  String get pvePasswordHint =>
      'هنگام استفاده از احراز هویت SSH با کلید نیز لازم است.';

  @override
  String get read => 'خواندن';

  @override
  String get recentConnections => 'اتصال‌های اخیر';

  @override
  String get rememberPwdInMem => 'به‌خاطرسپاری گذرواژه در حافظه';

  @override
  String get rememberPwdInMemTip =>
      'این گذرواژه برای مدیریت کانتینرها، تعلیق سیستم و موارد مشابه استفاده می‌شود.';

  @override
  String get remotePath => 'مسیر دوردست';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return 'نسخه $installed از $distro نصب است و نسخه $latest در دسترس است. با به‌روزرسانی، کل کانتینر دوباره بارگیری و جایگزین می‌شود و داده‌های $pm از بین می‌روند.';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'پیش از حذف $name، ترمینال‌های آن را ببندید';
  }

  @override
  String get rootfsSubtitle => 'یک محیط کاربری Linux روی این دستگاه';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return 'بسته $distro $version (حدود $size MB) را بارگیری کرده و روی این دستگاه از حالت فشرده خارج می‌کند.';
  }

  @override
  String get sameIdServerExist => 'سروری با همین شناسه از قبل وجود دارد.';

  @override
  String get second => 's';

  @override
  String get serverFilesUnavailableTip =>
      'باید از طریق SSH به این سرور وصل شوید یا Monitor را نصب و API فایل آن را فعال کنید.';

  @override
  String get back => 'بازگشت';

  @override
  String get history => 'تاریخچه';

  @override
  String get homeDir => 'خانه';

  @override
  String selected(int count) {
    return '$count مورد انتخاب شد';
  }

  @override
  String get sendTo => 'ارسال به…';

  @override
  String get serverFuncBtns => 'دکمه‌های عملکرد سرور';

  @override
  String get serverOrder => 'ترتیب سرورها';

  @override
  String get serverOverview => 'نمای کلی سرور';

  @override
  String get serverOverviewTip =>
      'نمایش خلاصه در بالای فهرست سرورها، و ردیف سرورها در بالای سرور بازشده';

  @override
  String get serverTabEmpty => 'هنوز سروری وجود ندارد';

  @override
  String get serverTabConnBadge => 'تعداد اتصال‌ها در برگه سرور';

  @override
  String get serverTabConnBadgeTip => 'تعداد سرورهای متصل، برای مثال 2/4.';

  @override
  String get serverTabRequired => 'برگه سرور قابل حذف نیست';

  @override
  String get shareCodeHint =>
      'این ارقام را جداگانه به گیرنده اطلاع دهید. آن‌ها در کد QR گنجانده نشده‌اند.';

  @override
  String get shareCodePrompt => 'کد ۶ رقمی';

  @override
  String get shareCodeTitle => 'کد یک‌بارمصرف';

  @override
  String get shareExpired =>
      'این اشتراک‌گذاری منقضی شده است. پیوند جدیدی درخواست کنید.';

  @override
  String get shareImportFile => 'از یک فایل به‌اشتراک‌گذاشته‌شده';

  @override
  String get shareImportTitle => 'وارد کردن سرور به‌اشتراک‌گذاشته‌شده';

  @override
  String get shareIncludesKey => 'این اشتراک‌گذاری شامل کلید خصوصی است.';

  @override
  String get shareOmittedBmc =>
      'اطلاعات ورود BMC. نشانی گنجانده شده است، اما اطلاعات ورود خیر.';

  @override
  String get shareOmittedJump =>
      'سرور واسط (Jump)، زیرا به‌عنوان یک سرور جداگانه روی این دستگاه ذخیره شده است.';

  @override
  String get shareOmittedKeyPath =>
      'فایل کلید، زیرا مسیر آن فقط روی این دستگاه معتبر است.';

  @override
  String get shareOmittedMissingKey =>
      'کلید خصوصی، زیرا در مخزن کلید این دستگاه موجود نیست.';

  @override
  String get shareOmittedTip => 'گنجانده نشده است؛ گیرنده باید پیکربندی کند:';

  @override
  String get sharePassphraseTip =>
      'این عبارت عبور فایل را رمزگذاری می‌کند. گیرنده برای وارد کردن سرور به آن نیاز دارد، و قابل بازیابی نیست.';

  @override
  String shareQrTip(int minutes) {
    return 'جزئیات اتصال در این کد QR رمزگذاری شده است. مهلت اشتراک‌گذاری تا $minutes دقیقه دیگر منقضی می‌شود.';
  }

  @override
  String get shareScanQr => 'اسکن کد QR';

  @override
  String shareServerExists(String name) {
    return 'سرور «$name» روی این دستگاه در حال حاضر از این نشانی استفاده می‌کند. در هر صورت وارد شود؟';
  }

  @override
  String get shareTooBigForQr =>
      'برای کد QR خیلی بزرگ است. در عوض آن را به‌عنوان فایل به اشتراک بگذارید.';

  @override
  String get shareTooNew =>
      'این اشتراک‌گذاری با نسخه جدیدتری از ServerBox ایجاد شده است. برای باز کردن آن، برنامه را به‌روزرسانی کنید.';

  @override
  String get shareUnreadable =>
      'این یک فایل اشتراک‌گذاری معتبر ServerBox نیست.';

  @override
  String get shareVia => 'اشتراک‌گذاری از طریق';

  @override
  String get sftpDlPrepare => 'در حال آماده‌سازی برای اتصال...';

  @override
  String get sftpEditorTip =>
      'اگر خالی باشد، ویرایشگر داخلی برنامه استفاده می‌شود. همچنین می‌توانید ویرایشگری مانند `vim` مشخص کنید (پیشنهاد می‌شود آن را از متغیر محیطی `EDITOR` دریافت کنید).';

  @override
  String get sftpRmrDirSummary =>
      'برای حذف یک پوشه در SFTP از دستور `rm -r` استفاده کنید.';

  @override
  String get sftpSSHConnected => 'اتصال SFTP برقرار شد';

  @override
  String get sftpShowFoldersFirst => 'نمایش پوشه‌ها در ابتدا';

  @override
  String get sftpUnavailableUseScp =>
      'اگر این میزبان فاقد زیرسیستم SFTP است (مانند بسیاری از دستگاه‌های تعبیه‌شده)، در تنظیمات سرور انتقال فایل آن را روی SCP قرار دهید.';

  @override
  String get sshFileTransportTip =>
      'پروتکل SFTP برای بیشتر سیستم‌های امروزی مناسب است. برای یک میزبان قدیمی یا تعبیه‌شده که سرور SSH آن فاقد زیرسیستم SFTP است SCP را انتخاب کنید: این حالت نیازمند دستور `scp` و پوسته‌ای است که ابزارهای متداول فایلی (`find`، `stat`، `mv`، `chmod`) را داشته باشد.';

  @override
  String get specifyDev => 'مشخص کردن دستگاه';

  @override
  String get specifyDevTip =>
      'ترافیک شبکه به‌طور پیش‌فرض تمام دستگاه‌ها را شمارش می‌کند؛ در اینجا می‌توانید یک دستگاه خاص را مشخص کنید';

  @override
  String get tempIsCelsiusTip =>
      'با فعال‌کردن این گزینه، دما برحسب درجه سلسیوس خوانده می‌شود، نه هزارم درجه سلسیوس. فقط اگر دما نادرست نمایش داده می‌شود آن را فعال کنید (برای مثال، 0.1°C به‌جای 58°C).';

  @override
  String get diskCountsNetwork => 'شمارش سیستم‌های فایل شبکه‌ای در مجموع';

  @override
  String get diskCountsNetworkTip =>
      'اتصال‌های NFS، SMB و موارد مشابه همیشه در فهرست نمایش داده می‌شوند. ظرفیت آن‌ها متعلق به دستگاه دیگری است و به‌طور پیش‌فرض در مجموع فضای دیسک حساب نمی‌شود. این تنظیم فقط هنگام دریافت وضعیت از طریق SSH اعمال می‌شود؛ هنگام دریافت از طریق Monitor، تنظیم خود Monitor تعیین‌کننده است.';

  @override
  String get diskCountsNetworkAgentTip =>
      'اتصال‌های NFS، SMB و موارد مشابه همیشه در فهرست نمایش داده می‌شوند. ظرفیت آن‌ها متعلق به دستگاه دیگری است و به‌طور پیش‌فرض در مجموع فضای دیسک حساب نمی‌شود. Monitor از همین مجموع برای ثبت تاریخچه و بررسی هشدارهای دیسک استفاده می‌کند.';

  @override
  String spentTime(String time) {
    return 'زمان سپری‌شده: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return 'همه سرورها از قبل وجود دارند ($duplicateCount مورد تکراری پیدا شد)';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return 'از $duplicateCount مورد تکراری صرف‌نظر خواهد شد';
  }

  @override
  String get sshConfigFound => 'پیکربندی SSH در این سیستم پیدا شد.';

  @override
  String sshConfigFoundServers(int totalCount) {
    return '$totalCount سرور یافت شد';
  }

  @override
  String get sshConfigImport => 'وارد کردن پیکربندی SSH';

  @override
  String get sshConfigImportPermission =>
      'اجازه می‌دهید فایل ~/.ssh/config خوانده و تنظیمات سرورهای داخل آن خودکار وارد شوند؟';

  @override
  String get sshConfigImportTip =>
      'درخواست خواندن ~/.ssh/config در زمان ایجاد نخستین سرور';

  @override
  String sshConfigImported(int count) {
    return '$count سرور از پیکربندی SSH وارد شد.';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return 'کلید میزبان SSH برای $serverName تغییر کرده است. فقط اگر به این سرور اعتماد دارید، اتصال را ادامه دهید.';
  }

  @override
  String get sshHostKeyType => 'نوع کلید میزبان SSH';

  @override
  String get sshKnownHostKeys => 'میزبان‌های شناخته‌شده';

  @override
  String get sshKnownHostKeysTip =>
      'کلیدهای میزبان که توسط این برنامه پذیرفته شده است';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return 'کلید میزبان SSH جدیدی از $serverName دریافت شد. پیش از اعتماد، اثر انگشت آن را بررسی کنید.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return 'اثر انگشت ذخیره‌شده: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'کد تأیید';

  @override
  String get sshConfigManualSelect =>
      'آیا مایلید فایل پیکربندی SSH را به‌صورت دستی انتخاب کنید؟';

  @override
  String get sshConfigNoServers => 'هیچ سروری در پیکربندی SSH یافت نشد';

  @override
  String get sshConfigPermissionDenied =>
      'به دلیل مجوزهای macOS دسترسی به فایل پیکربندی SSH امکان‌پذیر نیست.';

  @override
  String sshConfigServersToImport(int importCount) {
    return '$importCount سرور وارد خواهد شد';
  }

  @override
  String get sshTermHelp =>
      'هنگامی که ترمینال قابلیت پیمایش دارد، کشیدن افقی می‌تواند متن را انتخاب کند. کلیک روی دکمه صفحه‌کلید، صفحه‌کلید را روشن/خاموش می‌کند. نماد فایل، SFTP مسیر فعلی را باز می‌کند. دکمه کلیپ‌بورد در صورت انتخاب بودن متن، محتوا را کپی می‌کند و زمانی که متنی انتخاب نشده باشد و محتوایی در کلیپ‌بورد وجود داشته باشد، آن را در ترمینال جای‌گذاری می‌کند. نماد کد، قطعه‌کدها را در ترمینال جای‌گذاری کرده و آن‌ها را اجرا می‌کند.';

  @override
  String get sshVirtualKeyAutoOff => 'تغییر وضعیت خودکار کلیدهای مجازی';

  @override
  String get supportFmtArgs => 'پارامترهای قالب‌بندی زیر پشتیبانی می‌شوند:';

  @override
  String get suspendTip =>
      'قابلیت suspend به دسترسی root و پشتیبانی systemd نیاز دارد.';

  @override
  String switchTo(String val) {
    return 'جابه‌جایی به $val';
  }

  @override
  String get syncAppSettings => 'همگام‌سازی تنظیمات برنامه';

  @override
  String get syncAppSettingsTip =>
      'گنجاندن پوسته، طرح‌بندی، ویرایشگر، ترمینال و سایر ترجیحات دستگاه در همگام‌سازی خودکار.';

  @override
  String get termFontSizeTip =>
      'این تنظیم بر اندازه ترمینال (عرض و ارتفاع) تأثیر می‌گذارد. می‌توانید در صفحه ترمینال بزرگ‌نمایی کنید تا اندازه فونت نشست فعلی تنظیم شود.';

  @override
  String get textScalerTip =>
      'مقدار 1.0 => 100% (اندازه اصلی) است، فقط روی فونت بخش‌هایی از صفحه سرور اعمال می‌شود، تغییر آن توصیه نمی‌شود.';

  @override
  String get times => 'دفعات';

  @override
  String get trySudo => 'تلاش برای استفاده از sudo';

  @override
  String get sudoPromptNotFound => 'هیچ درخواست گذرواژه sudo فعالی وجود ندارد.';

  @override
  String get updateServerStatusInterval => 'فاصله زمانی به‌روزرسانی وضعیت سرور';

  @override
  String get useNoPwd => 'بدون گذرواژه';

  @override
  String get usePodmanByDefault => 'استفاده پیش‌فرض از Podman';

  @override
  String get used => 'مصرف‌شده';

  @override
  String get viewDetails => 'مشاهده جزئیات';

  @override
  String get virtKeyHelpIME => 'روشن/خاموش کردن صفحه‌کلید';

  @override
  String get virtKeyHelpSFTP => 'باز کردن پوشه فعلی در SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'یک قطعه‌کد را انتخاب کرده و در این ترمینال اجرا کنید.';

  @override
  String get virtKeyHelpTmux => 'جابه‌جایی بین نشست‌ها و پنجره‌های tmux.';

  @override
  String get virtKeyIntroActions => 'میانبرها';

  @override
  String get virtKeyIntroActionsTip =>
      'این کلیدها به‌جای تایپ کردن، موردی را باز می‌کنند. برای خواندن عملکرد هرکدام، انگشتتان را روی آن نگه دارید.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'در تنظیمات ترمینال، ترتیب این کلیدها را تغییر دهید، موارد بیشتری را روشن کنید (مرورگر فایل، sudo، کلیدهای F1–F12…) یا کلیدهایی را که استفاده نمی‌کنید پنهان نمایید.';

  @override
  String get virtKeyIntroModifiers => 'کلیدهای تغییردهنده';

  @override
  String get virtKeyIntroModifiersTip =>
      'روی یکی ضربه بزنید تا آماده شود، سپس یک حرف را روی صفحه‌کلید فشار دهید. این حالت فقط برای همان یک کلید فعال می‌ماند.';

  @override
  String get virtKeyIntroNav => 'پیمایش';

  @override
  String get virtKeyIntroNavTip =>
      'این کلیدها مکان‌نما را جابه‌جا می‌کنند. برای تکرار، کلید جهت‌نما را نگه دارید.';

  @override
  String get virtKeyIntroSelect =>
      'هر زمان که ترمینال محتوایی برای پیمایش داشته باشد، با کشیدن انگشت به‌صورت افقی روی آن می‌توانید متن را انتخاب کنید.';

  @override
  String get virtKeyRows => 'تعداد ردیف‌های هم‌زمان';

  @override
  String get virtKeyRowsTip =>
      'بقیه موارد در صفحه‌ای جداگانه قرار می‌گیرند که با کشیدن به طرفین قابل دسترسی است.';

  @override
  String get keyArrowDown => 'کلید جهت‌نمای پایین';

  @override
  String get keyArrowLeft => 'کلید جهت‌نمای چپ';

  @override
  String get keyArrowRight => 'کلید جهت‌نمای راست';

  @override
  String get keyArrowUp => 'کلید جهت‌نمای بالا';

  @override
  String get keyControl => 'کلید Control';

  @override
  String get keyEscape => 'کلید Escape';

  @override
  String get keyPageDown => 'کلید Page down';

  @override
  String get keyPageUp => 'کلید Page up';

  @override
  String get termTextView => 'مشاهده به‌صورت متن';

  @override
  String termTextLetGo(int count) {
    return 'سطرهای قبلی که دیگر نگهداری نمی‌شوند: $count';
  }

  @override
  String get waitConnection => 'لطفاً تا برقراری اتصال منتظر بمانید.';

  @override
  String get wakeLock => 'روشن نگه داشتن صفحه';

  @override
  String get watchNotPaired => 'هیچ Apple Watch جفت‌شده‌ای وجود ندارد';

  @override
  String get webdavSettingEmpty => 'تنظیمات WebDav خالی است';

  @override
  String get whenOpenApp => 'هنگام باز کردن برنامه';

  @override
  String get wolTip =>
      'پس از پیکربندی WOL (Wake-on-LAN)، با هر بار اتصال به سرور یک درخواست WOL ارسال می‌شود.';

  @override
  String get write => 'نوشتن';

  @override
  String get writeScriptFailTip =>
      'نوشتن در اسکریپت ناموفق بود، احتمالاً به دلیل نداشتن مجوز یا عدم وجود دایرکتوری.';

  @override
  String get writeScriptTip =>
      'پس از اتصال به سرور، اسکریپتی در `~/.config/server_box` \n | `/tmp/server_box` برای پایش وضعیت سیستم نوشته خواهد شد. می‌توانید محتوای اسکریپت را بررسی کنید.';

  @override
  String get menuGitHubRepository => 'مخزن GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'شبیه‌سازی Podman Docker شناسایی شد. لطفاً در تنظیمات به Podman تغییر دهید.';

  @override
  String get betaTip =>
      'این قابلیت هنوز در مرحله آزمایش بتا است. کارکرد آن تضمین نمی‌شود.';

  @override
  String get portForward_startPrompt =>
      'برای شروع، یک قانون انتقال پورت اضافه کنید';

  @override
  String get portForward_localHost => 'میزبان محلی';

  @override
  String get portForward_localPort => 'پورت محلی';

  @override
  String get portForward_remoteHost => 'میزبان دوردست';

  @override
  String get portForward_remotePort => 'پورت دوردست';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return 'آیا $name حذف شود؟';
  }

  @override
  String get sponsor => 'حمایت مالی';

  @override
  String get sortByJoinTime => 'بر اساس زمان پیوستن';

  @override
  String get tmuxAutoAttach => 'اتصال خودکار به tmux';

  @override
  String get tmuxAuto => 'اجرای خودکار tmux';

  @override
  String get tmuxAutoTip =>
      'شروع یا اتصال خودکار به tmux هنگام اتصال از طریق SSH';

  @override
  String get tmuxSessionSelector => 'انتخاب‌گر نشست';

  @override
  String get tmuxSessionSelectorTip => 'نمایش انتخاب‌گر نشست هنگام اتصال';

  @override
  String get tmuxDefaultSessionName => 'نام پیش‌فرض نشست';

  @override
  String get tmuxSessionName => 'نام نشست';

  @override
  String get tmuxNewSession => 'نشست جدید';

  @override
  String get tmuxNewWindow => 'پنجره جدید';

  @override
  String get tmuxNoWindowsFound => 'هیچ پنجره‌ای یافت نشد';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پنجره',
      one: '1 پنجره',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'متصل‌شده';

  @override
  String get tmuxSkip => 'صرف‌نظر';

  @override
  String get tmuxNotAvailable => 'ابزار tmux در دسترس نیست';

  @override
  String containerSegmentsMismatch(int count) {
    return 'تعداد بخش‌های پاسخ کانتینر غیرمنتظره است: $count';
  }

  @override
  String get containerOperationInProgress =>
      'عملیات دیگری روی کانتینر در حال انجام است';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فرایند',
      one: '1 فرایند',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'قالب فهرست فرایندها پشتیبانی نمی‌شود.';

  @override
  String get processParseInvalidRows =>
      'خواندن برخی از ورودی‌های فرایند امکان‌پذیر نبود.';

  @override
  String get processParseInvalidWindowsJson =>
      'پاسخ فرایند Windows قابل خواندن نبود.';

  @override
  String get processParseInvalidWindowsRows =>
      'برخی از ورودی‌های فرایند Windows قابل خواندن نبود.';

  @override
  String get processKillTargetChanged =>
      'فرایند تغییر کرده یا خارج شده است. نوسازی کرده و دوباره تلاش کنید.';

  @override
  String get processSearchHint => 'نام، کاربر یا PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'نمایش $count رشته هسته',
      one: 'نمایش 1 رشته هسته',
    );
    return '$_temp0';
  }

  @override
  String get processForceKill => 'توقف اجباری';

  @override
  String get processStarted => 'شروع‌شده';

  @override
  String get processThreads => 'رشته‌ها';

  @override
  String get watchServers => 'سرورهای روی ساعت';

  @override
  String get watchServersTip =>
      'ساعت اطلاعات را به‌طور مستقل از مانیتور دریافت می‌کند، بنابراین تنها سرورهایی که مانیتور دارند قابل انتخاب هستند.';

  @override
  String get watchNoMonitorServer =>
      'برای هیچ سروری Monitor پیکربندی نشده است.';

  @override
  String get legacyStatusGoneTitle => 'نشانی‌های URL وضعیت دیگر کار نمی‌کنند';

  @override
  String get legacyStatusGoneBody =>
      'برنامه ساعت و ویجت‌های صفحه اصلی قبلاً آدرس `/status` را که به‌صورت دستی وارد می‌شد می‌خواندند. آن نقطه پایانی حذف شده است: آن آدرس فقط می‌توانست مقادیر فعلی را به‌صورت متنی گزارش کند، به همین دلیل هرگز نمی‌توانستند نموداری را نشان دهند.\n\nآن‌ها اکنون API احراز هویت‌شده عامل مانیتور را می‌خوانند، بنابراین روندها را ترسیم می‌کنند و خودبه‌خود با برنامه هماهنگ می‌مانند. کافی است سرور را یک‌بار در برنامه پیکربندی کنید تا همه ساعت‌ها و ویجت‌ها آن را دریافت کنند.';

  @override
  String get services => 'سرویس‌ها';

  @override
  String get status => 'وضعیت';

  @override
  String get enable => 'فعال‌سازی';

  @override
  String get disable => 'غیرفعال‌سازی';

  @override
  String get starting => 'در حال شروع';

  @override
  String get stopping => 'در حال توقف';

  @override
  String get serviceManagerUnsupported => 'مدیر سرویس پشتیبانی‌نشده';

  @override
  String get serviceManagerUnsupportedTip =>
      'این سرور از یک مدیر سرویس استفاده می‌کند که ServerBox هنوز از آن پشتیبانی نمی‌کند. مدیرهای پشتیبانی‌شده: systemd، procd و OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'مدیریت‌شده توسط $manager';
  }

  @override
  String get serviceListFailed => 'فهرست کردن سرویس‌ها امکان‌پذیر نبود';

  @override
  String get serviceDetailsUnavailable => 'برخی از جزئیات سرویس در دسترس نیست';

  @override
  String get serviceDetailsUnavailableTip =>
      'فهرست سرویس‌ها قابل استفاده است، اما مدیر سرویس همه اطلاعات وضعیت یا راه‌اندازی را بازنگردانده است.';

  @override
  String get systemdUserScopeMissing => 'واحدهای کاربری فهرست نشده‌اند';

  @override
  String get systemdUserScopeMissingTip =>
      'این حساب کاربری فاقد گذرگاه نشست کاربری (Session bus) روی سرور است، بنابراین فقط واحدهای سیستمی نمایش داده می‌شوند.';

  @override
  String get serviceSearchHint => 'نام واحد (Unit)';

  @override
  String get serviceNeedsAttention => 'نیازمند توجه';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count واحد دیگر',
      one: '1 واحد دیگر',
    );
    return '$_temp0';
  }

  @override
  String get serviceUnit => 'واحد (Unit)';

  @override
  String get serviceUnitType => 'نوع';

  @override
  String get serviceScope => 'محدوده';

  @override
  String get serviceStartup => 'راه‌اندازی';

  @override
  String serviceUpFor(String duration) {
    return 'به‌مدت $duration فعال بوده است';
  }

  @override
  String serviceDownFor(String duration) {
    return 'به‌مدت $duration متوقف بوده است';
  }

  @override
  String serviceNextIn(String duration) {
    return 'اجرای بعدی تا $duration دیگر';
  }

  @override
  String serviceStoppedAgo(String duration) {
    return 'متوقف‌شده از $duration پیش';
  }

  @override
  String serviceExitStatus(int code) {
    return 'وضعیت خروج $code';
  }

  @override
  String get serviceFullJournal => 'گزارش کامل (Journal)';

  @override
  String get serviceUnitFile => 'فایل واحد (Unit)';

  @override
  String serviceJournalRecent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سطر آخر',
      one: 'آخرین سطر',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable =>
      'این حساب کاربری نمی‌تواند ژورنال (Journal) را بخواند';

  @override
  String get serverUnreachable => 'اجرای دستور روی این سرور امکان‌پذیر نبود';

  @override
  String get containerNoRuntime => 'هیچ محیط اجرای کانتینری در اینجا یافت نشد';

  @override
  String get containerNoRuntimeTip =>
      'هیچ‌کدام از دستورات `docker` یا `podman` در این دستگاه پاسخ ندادند. اگر یکی از آن‌ها برای حساب کاربری دیگری نصب شده است، «تلاش برای استفاده از sudo» را در «تنظیمات» روشن کنید.';

  @override
  String get containerUnreadable =>
      'محیط اجرای کانتینر پاسخی با ساختار غیرمنتظره بازگرداند';

  @override
  String get power => 'توان مصرفی';

  @override
  String get fan => 'فن';

  @override
  String get clockSpeed => 'سرعت کلاک';

  @override
  String get vendor => 'سازنده';

  @override
  String get continueInTerminal => 'ادامه در ترمینال';

  @override
  String get askAiRiskUnknown => 'طبقه‌بندی‌نشده';

  @override
  String get agentLocalExec => 'اجرای دستورها روی این دستگاه';

  @override
  String get agentLocalExecTip =>
      'به Agent امکان می‌دهد روی دستگاهی که ServerBox را اجرا می‌کند کار کند. حتی دستورهای فقط‌خواندنی نیز بررسی می‌شوند';

  @override
  String get agentLocalExecRootfsTip =>
      'به Agent امکان می‌دهد به‌صورت محلی و محدود به کانتینر لینوکسی که ServerBox نصب کرده است کار کند';

  @override
  String macDmgImportedPartly(String path) {
    return 'داده‌های نسخه نصب‌شده قبلی وارد شد. فایل‌های دانلودشده در همان محل در $path باقی ماندند.';
  }

  @override
  String get bmcAccount => 'حساب کاربری';

  @override
  String get bmcAccountUnset =>
      'موردی انتخاب نشده است - برای انتخاب یا ساخت یکی ضربه بزنید';

  @override
  String bmcAccountShared(int count) {
    return 'مورد استفاده در $count سرور';
  }

  @override
  String get bmcAccounts => 'حساب‌های کاربری BMC';

  @override
  String get bmcAccountSharedTip =>
      'ویرایش این مورد، تنظیمات مورد استفاده همه آن‌ها را تغییر می‌دهد.';

  @override
  String bmcAccountInUse(int count) {
    return '$count سرور از آن استفاده می‌کنند. آدرس آن‌ها حفظ می‌شود و حساب کاربری حذف خواهد شد.';
  }

  @override
  String get bmcStaleWrite =>
      'تنظیمات BMC در حین نوشتن تغییر کرد. دوباره تلاش کنید.';

  @override
  String get privacyBlur => 'حریم خصوصی در پس‌زمینه';

  @override
  String get privacyBlurTip =>
      'پنهان کردن محتوای برنامه در جابه‌جاگر برنامه‌ها';

  @override
  String get floatReturnToTab => 'بازگشت به برگه';

  @override
  String get termInFloatWindow => 'این ترمینال در پنجره شناور است';

  @override
  String get globeEnabledTip =>
      'نمایش سرورها روی کره زمین در موقعیت آدرس آن‌ها. غیرفعال کردن، دکمه را از برگه سرور حذف کرده و همه جستجوها را متوقف می‌کند.';

  @override
  String get geoShardsConsentAttribution =>
      'موقعیت‌یابی مکانی IP توسط [DB-IP](https://db-ip.com)، تحت CC BY 4.0.';

  @override
  String get geoMissPrivate => 'آدرس خصوصی';

  @override
  String get geoMissNoData => 'بدون داده‌های مکانی';

  @override
  String get globeGuide =>
      'برای مشاهده سرورهای خود روی کره زمین در موقعیت آدرس آن‌ها، اینجا ضربه بزنید.';

  @override
  String get publicIp => 'آدرس IP عمومی';

  @override
  String get geoData => 'داده‌های در سطح شهر';

  @override
  String get geoDataTip =>
      'پس از دانلود، تمام جستجوهای موقعیت مکانی از داده‌های ذخیره‌شده روی این دستگاه استفاده می‌کنند. آدرس‌های سرور و فعالیت‌های جستجو به سرویس دانلود ارسال نمی‌شوند.';

  @override
  String get geoDataMissing => 'دانلود نشده';

  @override
  String get geoDataUnreachable => 'دریافت داده‌ها امکان‌پذیر نبود.';

  @override
  String get geoDataRemoveFailed => 'حذف داده‌ها امکان‌پذیر نبود.';

  @override
  String geoDataCurrent(String month) {
    return 'نسخه $month از قبل نصب شده است.';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**دانلود: $download · فضای ذخیره‌سازی روی دستگاه: $disk.** مجموعه داده کامل روی این دستگاه ذخیره می‌شود و تمام جستجوهای موقعیت مکانی بعدی به‌صورت محلی انجام خواهد شد. آدرس‌های سرور و فعالیت‌های جستجو به سرویس دانلود ارسال نمی‌شوند.\n\nبه‌روزرسانی ماهانه. نسخه جدیدتر بدون نگه‌داشتن نسخه اضافی، جایگزین داده‌های نصب‌شده می‌شود. شما می‌توانید هر زمان آن را حذف کنید.';
  }

  @override
  String get benchmark => 'بنچ‌مارک';

  @override
  String get benchmarkIntro =>
      'اسکریپت Yet Another Bench Script را روی این سرور اجرا می‌کند: دیسک، شبکه و CPU. اجرای کامل ۱۰ تا ۲۰ دقیقه طول می‌کشد و حتی اگر از این صفحه خارج شوید یا برنامه را ببندید ادامه می‌یابد.';

  @override
  String get benchmarkNoRuns => 'هنوز بنچ‌مارکی وجود ندارد.';

  @override
  String get benchmarkRunning => 'بنچ‌مارک در حال اجرا است';

  @override
  String get benchmarkStartFailed => 'شروع بنچ‌مارک امکان‌پذیر نبود';

  @override
  String get benchmarkCancelConfirm =>
      'این بنچ‌مارک متوقف شود؟ آنچه تاکنون اندازه‌گیری شده است از دست می‌رود.';

  @override
  String get benchmarkDeleteConfirm => 'این نتیجه بنچ‌مارک حذف شود؟';

  @override
  String get benchmarkNothingSelected =>
      'تمام مراحل غیرفعال هستند. اجرا فقط اطلاعات سیستم را جمع‌آوری می‌کند و چند ثانیه طول می‌کشد.';

  @override
  String get benchmarkDiskTip =>
      'اجرای fio با چهار اندازه بلوک، حدود ۳ دقیقه. یک فایل آزمایشی ۲ گیگابایتی در پوشه کاری می‌نویسد و به همین مقدار فضای خالی نیاز دارد.';

  @override
  String get benchmarkNetworkTip =>
      'اجرای iperf3 در برابر سرورهای عمومی، حدود ۴ دقیقه.';

  @override
  String get benchmarkReducedNetwork => 'موقعیت‌های مکانی کمتر';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'سه موقعیت مکانی به‌جای هفت مورد. ترافیک تقریباً از $full به $reduced کاهش می‌یابد.';
  }

  @override
  String get benchmarkCpuTip =>
      'برنامه اختصاصی Geekbench را دانلود کرده و **نتیجه را در صفحه‌ای عمومی در geekbench.com منتشر می‌کند** — شامل مدل CPU، تعداد هسته‌ها و حافظه.';

  @override
  String get benchmarkSensitiveOptions =>
      'گزینه‌های زیر نرم‌افزارهای شخص ثالث را روی این سرور دانلود و اجرا کرده یا اطلاعات سرور را به اشخاص ثالث ارسال می‌کنند. این گزینه‌ها به‌طور پیش‌فرض غیرفعال هستند.';

  @override
  String get benchmarkIpInfoTip =>
      'آدرس عمومی این سرور را از طریق HTTP ساده به ip-api.com ارسال می‌کند.';

  @override
  String get benchmarkIpInfo => 'جستجوی مالک IP';

  @override
  String get benchmarkPreferBin => 'دانلود fio و iperf3';

  @override
  String get benchmarkPreferBinTip =>
      'آن‌ها را به‌جای بسته‌های میزبان از GitHub دانلود می‌کند. این گزینه را تنها در صورتی فعال کنید که هیچ‌کدام روی میزبان نصب نشده باشند.';

  @override
  String get benchmarkWorkDir => 'پوشه کاری';

  @override
  String get benchmarkWorkDirTip =>
      'سیستم فایلی را که آزمایش دیسک اندازه‌گیری می‌کند تعیین می‌نماید. خالی بودن به معنی پوشه خانگی حساب کاربری ورود است.';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return 'حدود $minutes دقیقه';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'حدود $size ترافیک';
  }

  @override
  String get benchmarkPhaseSystem => 'در حال خواندن اطلاعات سیستم';

  @override
  String get benchmarkPhaseDisk => 'در حال آزمایش دیسک';

  @override
  String get benchmarkPhaseNetwork => 'در حال آزمایش شبکه';

  @override
  String get benchmarkPhaseCpu => 'در حال آزمایش CPU';

  @override
  String get benchmarkPhaseDone => 'در حال اتمام';

  @override
  String get benchmarkResultUnreadable =>
      'این نتیجه قابل خواندن به‌عنوان JSON نبود. متن خام در زیر آمده است.';

  @override
  String get benchmarkViewOnGeekbench => 'مشاهده در Geekbench';

  @override
  String get benchmarkGeekbenchPublic =>
      'این نتیجه به‌صورت عمومی در پیوند بالا منتشر شده است.';

  @override
  String get benchmarkSingleCore => 'تک‌هسته‌ای';

  @override
  String get benchmarkMultiCore => 'چندهسته‌ای';

  @override
  String get benchmarkIops => 'شاخص IOPS';

  @override
  String get benchmarkSend => 'ارسال';

  @override
  String get benchmarkRecv => 'دریافت';

  @override
  String get benchmarkLatency => 'تأخیر';

  @override
  String get benchmarkVirt => 'مجازی‌سازی';

  @override
  String get benchmarkRawLog => 'گزارش اجرا';

  @override
  String benchmarkUpstream(String version) {
    return 'قدرت‌گرفته از Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'در حال شروع';

  @override
  String get benchmarkNoOutputYet =>
      'هنوز خروجی وجود ندارد. پیش از چاپ اولین خط، YABS بررسی می‌کند که google.com و icanhazip.com در دسترس هستند یا خیر. در شبکه‌هایی که دسترسی به هریک از این سایت‌ها مسدود است، این بررسی ممکن است چند دقیقه طول بکشد.';

  @override
  String get tagsEmptyTip =>
      'هنوز برچسبی وجود ندارد. هنگام ویرایش سرور یکی اضافه کنید تا اینجا نمایش داده شود.';

  @override
  String get benchmarkNoServers =>
      'ابتدا یک سرور اضافه کنید، سپس برای اجرای بنچ‌مارک به اینجا برگردید.';

  @override
  String get schemaTooNewTitle => 'این داده‌ها جدیدتر از برنامه است';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'این داده‌ها توسط نسخه جدیدتری از ServerBox نوشته شده است (ذخیره‌سازی نسخه $stored). این نسخه تا نسخه $supported را می‌خواند؛ تغییری اعمال نشده است.';
  }

  @override
  String get schemaTooNewReinstall =>
      'برای دسترسی دوباره به همه داده‌های خود، نسخه جدیدتر را دوباره نصب کنید.';

  @override
  String get schemaTooNewExportPlain => 'خروجی گرفتن بدون گذرواژه';

  @override
  String get schemaTooNewPlainWarn =>
      'این فایل شامل تمام کلیدهای خصوصی SSH، گذرواژه‌های سرور و کلیدهای API به صورت متن ساده خواهد بود. هر کسی به این فایل دسترسی یابد می‌تواند به همه آن‌ها دسترسی داشته باشد.';

  @override
  String get schemaTooNewWipe => 'حذف همه داده‌ها';

  @override
  String get schemaTooNewWipeConfirm =>
      'همه سرورها، کلیدها، قطعه‌کدها و تنظیمات روی این دستگاه حذف خواهند شد. این عملیات قابل بازگشت نیست. نسخه پشتیبان صادرشده در اینجا تنها نسخه باقی‌مانده خواهد بود.';

  @override
  String get schemaTooNewWipeDone =>
      'داده‌ها حذف شدند. برنامه را دوباره باز کنید تا از نو شروع شود.';

  @override
  String get schemaTooNewWipeFailed =>
      'برخی از داده‌ها حذف نشدند و این نسخه همچنان نمی‌تواند موارد باقی‌مانده را باز کند. برای دسترسی به آن‌ها، نسخه جدیدتر را دوباره نصب کنید.';

  @override
  String get systemUsers => 'کاربران';

  @override
  String get userManagerLinuxOnly =>
      'مدیریت کاربران سیستم در حال حاضر از سرورهای لینوکس پشتیبانی می‌کند.';

  @override
  String get userRegularAccount => 'عادی';

  @override
  String get userCurrentAccount => 'حساب کاربری فعلی';

  @override
  String get userSystemAccount => 'حساب کاربری سیستم';

  @override
  String get userUid => 'شناسه UID';

  @override
  String get userLoginStatus => 'وضعیت';

  @override
  String get userLoginEnabled => 'ورود فعال';

  @override
  String get userDetailAccount => 'حساب کاربری';

  @override
  String get userDetailSecurity => 'امنیت';

  @override
  String get userSshKeys => 'کلیدهای SSH';

  @override
  String get userExpires => 'تاریخ انقضا';

  @override
  String get userNever => 'هرگز';

  @override
  String get userPasswordSet => 'تنظیم‌شده';

  @override
  String get userPasswordLocked => 'قفل‌شده';

  @override
  String get userPasswordNone => 'ندارد';

  @override
  String get userSuperuser => 'کاربر ارشد';

  @override
  String get userOpenShell => 'باز کردن شل';

  @override
  String get userRootChangesWarning =>
      'تغییرات اعمال‌شده بر root بلافاصله در تمام نشست‌ها تأثیر می‌گذارد.';

  @override
  String get userComment => 'توضیحات';

  @override
  String get userPrimaryGroup => 'گروه اصلی';

  @override
  String get userSupplementaryGroups => 'گروه‌های تکمیلی';

  @override
  String get userLoginShell => 'شل ورود';

  @override
  String get userCreateHome => 'ایجاد پوشه خانگی';

  @override
  String get userMoveHome => 'انتقال پوشه خانگی موجود هنگام تغییر مسیر';

  @override
  String get userRemoveHome => 'حذف پوشه خانگی';

  @override
  String get userPasswordCreateTip =>
      'گذرواژه را خالی بگذارید تا حساب کاربری با گذرواژه قفل‌شده ایجاد شود.';

  @override
  String get userPasswordEditTip =>
      'برای حفظ گذرواژه فعلی، آن را خالی بگذارید.';

  @override
  String get systemGroups => 'گروه‌ها';

  @override
  String get userGid => 'شناسه GID';

  @override
  String get userGroupMembers => 'اعضا';

  @override
  String get userPrimaryMembers => 'اعضای اصلی';

  @override
  String get userSystemGroup => 'گروه سیستم';

  @override
  String get userMembersHint => 'نمونه: alice,bob';

  @override
  String get userRegularGroup => 'عادی';

  @override
  String funcUnavailableFmt(String func) {
    return 'قابلیت $func از طریق اتصال این سرور در دسترس نیست.';
  }

  @override
  String funcNeedsAgentGrant(String func, String setting) {
    return 'برای استفاده از $func، گزینه $setting را در Monitor فعال کنید.';
  }

  @override
  String funcNeedsAgentUpdate(String func) {
    return 'برای استفاده از $func به نسخه جدیدتری از Monitor نیاز دارید.';
  }

  @override
  String get portForwardRemoteNeedsAgent =>
      'هدایت پورت راه دور از طریق Monitor به نسخه جدیدتری از agent نیاز دارد. آن را روی سرور به‌روزرسانی کنید.';

  @override
  String get rangeLive => 'زنده';

  @override
  String get diskIo => 'ورودی/خروجی دیسک';

  @override
  String get peak => 'اوج';

  @override
  String get hardware => 'سخت‌افزار';

  @override
  String get cores => 'هسته‌ها';

  @override
  String get historyNoStored =>
      'فقط Monitor داده‌های تاریخچه را ذخیره می‌کند. هنگام اتصال از طریق SSH، برنامه فقط داده‌های جمع‌آوری‌شده پس از اتصال را نشان می‌دهد.';

  @override
  String get noHistoryYet => 'هنوز چیزی اندازه‌گیری نشده است';

  @override
  String get noData => 'بدون داده';

  @override
  String get from => 'از';

  @override
  String get to => 'تا';

  @override
  String get beyondRetention => 'بیرون از بازه داده‌های ذخیره‌شده Monitor';

  @override
  String agentRetentionFmt(String kept) {
    return 'Monitor داده‌ها را به‌مدت $kept نگه می‌دارد';
  }

  @override
  String get agentServerTools => 'ابزارهای سرور';

  @override
  String get agentServerToolsTip =>
      'روی سرورها دستور اجرا کنید، فایل‌ها را بخوانید یا بنویسید، از طریق SSH به میزبان‌های دیگر وصل شوید و از قابلیت‌های خود ServerBox استفاده کنید.';

  @override
  String get agentTerminalTools => 'ترمینال';

  @override
  String get agentTerminalToolsTip =>
      'در گفت‌وگوی ترمینال، محتوای روی صفحه را بخوانید و روی سرور مربوطه دستور اجرا کنید.';

  @override
  String get agentToolTerminalScreen => 'خواندن صفحه';

  @override
  String get agentProviders => 'ارائه‌دهندگان';

  @override
  String get agentProvidersTip =>
      'کلیدهای API، مدل‌ها و مدلی که گفتگوی جدید استفاده می‌کند';

  @override
  String get agentTools => 'ابزارها';

  @override
  String get agentToolsTip =>
      'آنچه Agent می‌تواند استفاده کند و سرورهای MCP آن';

  @override
  String get agentSnippetToolsTip =>
      'قطعه‌کدها را فهرست کنید، بیفزایید، ویرایش کنید یا حذف کنید.';

  @override
  String get agentVirtToolsTip =>
      'خواندن ماشین‌های مجازی و کانتینرهایی که برگه مجازی‌سازی بارگیری کرده است.';

  @override
  String get agentBenchmarkToolsTip =>
      'خواندن نتایج بنچ‌مارک، و اجرا یا توقف بنچ‌مارک با تأیید شما.';

  @override
  String get agentRemoteDesktopToolsTip =>
      'فهرست کردن پروفایل‌های دسکتاپ راه دور، و اتصال یا قطع اتصال با تأیید شما.';

  @override
  String get agentSkills => 'مهارت‌ها';

  @override
  String get agentSkillsTip =>
      'دستورالعمل‌ها برای وظایف خاص، نصب‌شده از GitHub یا پیوند';

  @override
  String get agentPermissions => 'مجوزها';

  @override
  String get agentEmptyHint => 'روی سرور عملیات انجام دهید.';

  @override
  String get agentTerminalEmptyHint =>
      'محتوای ترمینال فعلی را بخوانید و در آن دستور اجرا کنید.';

  @override
  String oldestSampleFmt(String time) {
    return 'قدیمی‌ترین نمونه $time';
  }

  @override
  String get rangeEndsBeforeItStarts => 'پایان بازه باید پس از شروع آن باشد.';

  @override
  String get samples => 'نمونه‌ها';

  @override
  String get unavailable => 'در دسترس نیست';

  @override
  String get metricUnavailableTip =>
      'بقیه این صفحه تحت تأثیر قرار نمی‌گیرد. دستوری را که این اطلاعات از آن به دست می‌آید روی میزبان بررسی کنید.';

  @override
  String get waitingFirstSample => 'در انتظار اولین نمونه';

  @override
  String atTimeFmt(String time) {
    return 'در $time';
  }

  @override
  String get stored => 'ذخیره‌شده';

  @override
  String lastSampleFmt(String ago) {
    return 'آخرین نمونه: $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'تمام موارد زیر مربوط به $time، $ago است.';
  }

  @override
  String noDataBeforeFmt(String time) {
    return 'بدون داده قبل از $time';
  }

  @override
  String loadingRangeFmt(String range) {
    return 'در حال بارگیری $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return 'تاریخچه ذخیره‌شده‌ای برای $metric وجود ندارد';
  }

  @override
  String devicesFmt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دستگاه',
      one: '1 دستگاه',
    );
    return '$_temp0';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return '$count دستگاه · بیشترین فعالیت: $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$plotted از $total دستگاه';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return '$count حسگر · داغ‌ترین: $name';
  }

  @override
  String get oneDeviceAtLeast => 'حداقل یک دستگاه روی نمودار باقی می‌ماند.';

  @override
  String showAllFmt(int count) {
    return 'نمایش همه $count مورد';
  }

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$shown از $total $what';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$count $what';
  }

  @override
  String get filesystems => 'سیستم‌های فایل';

  @override
  String get blockDevices => 'دستگاه‌های بلوکی';

  @override
  String get notMounted => 'سوار نشده';

  @override
  String get unitDevices => 'دستگاه';

  @override
  String get unitSensors => 'حسگر';

  @override
  String get unitBatteries => 'باتری';

  @override
  String get unitCommands => 'دستور';

  @override
  String get unitReadings => 'خوانش';

  @override
  String get unitGpus => 'واحد GPU';

  @override
  String get hottest => 'داغ‌ترین';

  @override
  String get oldest => 'قدیمی‌ترین';

  @override
  String get notApplicable => 'غیرقابل اعمال';

  @override
  String get attributes => 'ویژگی‌ها';

  @override
  String get powerOnHours => 'ساعات روشن بودن';

  @override
  String get powerCycles => 'چرخه‌های روشن شدن';

  @override
  String get lifeLeft => 'عمر باقی‌مانده';

  @override
  String get lifetimeWrite => 'میزان کل نوشتن';

  @override
  String get lifetimeRead => 'میزان کل خواندن';

  @override
  String get averageErase => 'میانگین پاک‌سازی';

  @override
  String get unsafeShutdowns => 'خاموش‌شدن‌های ناگهانی';

  @override
  String get diskAllPassed => 'همه سالم (PASSED)';

  @override
  String diskWarningFmt(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count هشدار',
      one: '1 هشدار',
    );
    return '$_temp0';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$wrong از $total دستگاه';
  }

  @override
  String get diskSmartSortedTip => 'مرتب‌شده از بدترین به بهترین';

  @override
  String readAgoFmt(String ago) {
    return 'خوانده‌شده در $ago';
  }

  @override
  String processesFmt(int count) {
    return '$count فرایند';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count مورد در حال خرابی';
  }

  @override
  String get diskSmartOpenTip => 'برای مشاهده ویژگی‌ها یکی را باز کنید';

  @override
  String get cycle => 'چرخه';

  @override
  String get window => 'پنجره';

  @override
  String ofFmt(String total) {
    return 'از $total';
  }

  @override
  String get serverDetailCards => 'کارت‌های صفحه جزئیات';

  @override
  String get connection => 'اتصال';

  @override
  String get connectionTip =>
      'هر دو می‌توانند هم‌زمان فعال باشند. ترتیب، همان ترتیب اتصال است.';

  @override
  String get transportNoneOn =>
      'هر دو خاموش هستند — اتصال به این سرور امکان‌پذیر نیست.';

  @override
  String get thisDevice => 'این دستگاه';

  @override
  String get localServerTip =>
      'این دستگاه را با اجرای اسکریپت وضعیت در همین‌جا به‌صورت مستقیم می‌خواند. SSH و Monitor HTTP استفاده نمی‌شوند و تنظیمات آن‌ها حفظ می‌شود.';

  @override
  String get localServerUnsupported =>
      'این پلتفرم نمی‌تواند این دستگاه را به‌عنوان سرور بخواند. لینوکس، ویندوز و نسخه DMG در macOS این قابلیت را دارند.';

  @override
  String get remoteDesktopIntro =>
      'دسکتاپ RDP یا VNC یک سرور را درون برنامه باز کنید. اتصال از طریق اتصال SSH سرور یا Monitor agent آن انجام می‌شود، بنابراین نیازی به در دسترس بودن پورت دسکتاپ از طریق شبکه نیست.';

  @override
  String get remoteDesktopIntroProfiles =>
      'یک پروفایل برای هر دسکتاپ از طریق دکمه دسکتاپ راه دور در سرور، یا از برگه دسکتاپ راه دور ذخیره کنید.';

  @override
  String get localServerIntro =>
      'دستگاهی را که ServerBox را اجرا می‌کند به‌عنوان سرور اضافه کنید. وضعیت، فرایندها، سرویس‌ها، کانتینرها، ترمینال و فایل‌ها همگی بدون SSH یا Monitor agent کار می‌کنند.';

  @override
  String get localServerAdd => 'افزودن این دستگاه';

  @override
  String get localServerIntroFooter =>
      'این مورد را بعداً نیز می‌توان در صفحه ویرایش سرور و زیر بخش «اتصال» فعال کرد.';

  @override
  String get transportSectionOff =>
      'خاموش. فیلدهای زیر برای زمانی که آن را دوباره روشن کنید حفظ می‌شوند.';

  @override
  String get monitorAgent => 'عامل Monitor';

  @override
  String get plainHttpEditTip =>
      'اطلاعات ورود و آمارها بدون رمزگذاری در شبکه منتقل می‌شوند. آن را به یک آدرس LAN یا Tailscale محدود کنید، یا عامل را پشت TLS قرار دهید.';

  @override
  String get behaviour => 'رفتار';

  @override
  String get optional => 'اختیاری';

  @override
  String get sshAdvanced => 'تنظیمات پیشرفته SSH';

  @override
  String get sshAdvancedTip =>
      'مقصد پشتیبان، ProxyCommand، سرور واسط (Jump)، انتقال فایل، مسیر راه دور';

  @override
  String get sshLegacyAlgorithms => 'الگوریتم‌های قدیمی';

  @override
  String get sshLegacyAlgorithmsTip =>
      'برای دیمن قدیمی SSH (روتر، سوئیچ) که فقط کلید میزبان SHA-1 `ssh-rsa` یا تبادل کلید SHA-1 را ارائه می‌دهد. امنیت کمتری دارد؛ آن را فقط برای میزبانی که نیاز دارد فعال کنید.';

  @override
  String get appearanceAndPlace => 'ظاهر و موقعیت مکانی';

  @override
  String get appearanceAndPlaceTip => 'لوگو، مختصات';

  @override
  String get statusCollection => 'جمع‌آوری وضعیت';

  @override
  String get statusCollectionTip =>
      'دستورهای در حال اجرا، دستورهای سفارشی، دستگاه موردنظر برای خواندن';

  @override
  String get tagAllTags => 'همه برچسب‌ها';

  @override
  String get tagMatching => 'منطبق';

  @override
  String get tagNewHint => 'برچسب جدید';

  @override
  String tagCreateFmt(String tag) {
    return 'ایجاد #$tag';
  }

  @override
  String get tagOnThisServer => 'روی این سرور';

  @override
  String tagServersFmt(int count) {
    return '$count سرور';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '$count مورد در این سرور';
  }

  @override
  String get tagMatchesTyped => 'منطبق با عبارت تایپ‌شده';

  @override
  String get tagEditorTip =>
      'تایپ کردن، فهرست را فیلتر می‌کند؛ این دکمه برچسب را ایجاد کرده و در یک مرحله به این سرور اضافه می‌کند. تغییر نام از طریق آیکون مداد، نام آن را در هر سروری که دارای آن است تغییر می‌دهد. برچسبی که روی هیچ سروری نباشد هنگام ذخیره ناپدید می‌شود.';

  @override
  String get tagRenamesOnSave => 'تغییر نام هنگام ذخیره اعمال می‌شود';

  @override
  String get scheduledTasks => 'وظایف زمان‌بندی‌شده';

  @override
  String get scheduledTaskLinuxOnly =>
      'مدیریت وظایف زمان‌بندی‌شده در حال حاضر از سرورهای لینوکس پشتیبانی می‌کند.';

  @override
  String get scheduledTaskUnavailable =>
      'ابزار crontab روی این سرور در دسترس نیست.';

  @override
  String get scheduledTaskPreserveTip =>
      'توضیحات، متغیرهای محیطی و خطوط ناشناخته در این crontab حفظ می‌شوند.';

  @override
  String get scheduledTaskSchedule => 'زمان‌بندی';

  @override
  String get scheduledTaskAdd => 'افزودن وظیفه';

  @override
  String get scheduledTaskNextRun => 'اجرای بعدی';

  @override
  String scheduledTaskNextInFmt(String time) {
    return 'در $time';
  }

  @override
  String get scheduledTaskEnabled => 'فعال';

  @override
  String get scheduledTaskCommentedOut => 'کامنت‌شده';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
    return '$total وظیفه · $enabled فعال';
  }

  @override
  String get scheduledTaskFilterHint => 'فیلتر وظایف';

  @override
  String get scheduledTaskPreserved => 'خطوط حفظ‌شده';

  @override
  String get scheduledTaskRaw => 'متن خام crontab';

  @override
  String get scheduledTaskEnableNow => 'فعال‌سازی اکنون';

  @override
  String get scheduledTaskEnableNowTip =>
      'در حالت غیرفعال، خط به صورت کامنت‌شده نوشته می‌شود.';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return 'هیچ وظیفه زمان‌بندی‌شده‌ای برای $user وجود ندارد. هر آنچه اینجا اضافه شود، در crontab این حساب نوشته خواهد شد.';
  }

  @override
  String get scheduledTaskFieldMinute => 'دقیقه';

  @override
  String get scheduledTaskFieldHour => 'ساعت';

  @override
  String get scheduledTaskFieldDayOfMonth => 'روز ماه';

  @override
  String get scheduledTaskFieldMonth => 'ماه';

  @override
  String get scheduledTaskFieldDayOfWeek => 'روز هفته';

  @override
  String get cronErrScheduleEmpty => 'تعیین زمان‌بندی الزامی است.';

  @override
  String get cronErrCommandEmpty => 'وارد کردن دستور الزامی است.';

  @override
  String get cronErrLineBreak => 'یک خط crontab نمی‌تواند شامل شکستگی خط باشد.';

  @override
  String get cronErrMacro => 'یک ماکرو باید یک کلمه باشد، مانند @reboot.';

  @override
  String get cronErrFieldCount =>
      'یک زمان‌بندی cron دارای پنج فیلد یا یک ماکرو مانند @reboot است.';

  @override
  String get cronAtBoot => 'هنگام راه‌اندازی';

  @override
  String get cronEveryMin => 'هر دقیقه';

  @override
  String cronEveryMinsFmt(int minutes) {
    return 'هر $minutes دقیقه';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'هر ساعت، در دقیقه $minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'هر $hours ساعت';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'هر $hours ساعت، در دقیقه $minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'هر روز در ساعت $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'در روزهای کاری در ساعت $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'هر $day در ساعت $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return 'روز $day هر ماه در ساعت $time';
  }

  @override
  String get monitorSettings => 'تنظیمات Monitor';

  @override
  String get monitorAgentDefault => 'پیش‌فرض Agent';

  @override
  String get monitorNeedsRestart => 'پس از راه‌اندازی مجدد Agent اعمال می‌شود';

  @override
  String get monitorCollection => 'جمع‌آوری داده';

  @override
  String get extendedInterval => 'بازه زمانی چرخه تکمیلی';

  @override
  String get idlePause => 'توقف موقت در صورت عدم پایش';

  @override
  String get idlePauseTip =>
      'چرخه تکمیلی دستورهای smartctl، sensors و amd-smi را اجرا می‌کند. توقف موقت آن در زمانی که هیچ کلاینتی داده‌ها را بررسی نمی‌کند، از روشن شدن دیسک برای اطلاعاتی که خوانده نمی‌شوند جلوگیری می‌کند.';

  @override
  String get idlePauseThreshold => 'بیکار پس از';

  @override
  String get monitorAlerts => 'هشدارها';

  @override
  String get monitoringRules => 'قوانین هشدار';

  @override
  String get ruleMonitorType => 'معیار';

  @override
  String get ruleThreshold => 'آستانه';

  @override
  String get ruleMatcher => 'تطبیق‌دهنده';

  @override
  String get ruleTip =>
      'معیار: cpu / memory / swap / disk / network / temperature. تطبیق‌دهنده: cpu0 برای یک هسته، used / free / avail برای حافظه، rx / tx برای شبکه؛ دیسک و دما آن را نادیده می‌گیرند. آستانه: یک عملگر مقایسه‌ای و یک مقدار، مانند >=80%، >=70c یا >10m/s.';

  @override
  String get pushChannels => 'کانال‌های اعلان';

  @override
  String get pushType => 'نوع';

  @override
  String get pushRate => 'محدودیت نرخ';

  @override
  String get pushHeaders => 'هدرها';

  @override
  String get pushSecretSet => 'در Monitor تنظیم شده است و نمایش داده نمی‌شود';

  @override
  String get pushSecretKeep => 'برای حفظ مقدار، خالی بگذارید';

  @override
  String get pushTestTip =>
      'یک اعلان از طریق این کانال با وضعیت فعلی، چه ذخیره شده باشد و چه نه، ارسال می‌کند.';

  @override
  String get pushTestSent => 'کانال آن را پذیرفت';

  @override
  String get pushTestFailed => 'کانال آن را رد کرد';

  @override
  String get pushTestMessage => 'اعلان آزمایشی از ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'Monitor برای این نوع کانال فرستنده‌ای ندارد، بنابراین تنظیمات آن نمایش داده نمی‌شود. می‌توانید آن را از اینجا حذف کنید یا در فایل config.toml مربوط به Monitor ویرایش کنید.';

  @override
  String get pushJsonInvalid => 'یک JSON معتبر نیست';

  @override
  String get dataRetention => 'نگهداری داده‌ها';

  @override
  String get dataRetentionTip =>
      'وقتی غیرفعال باشد، Monitor هیچ داده‌ای را حذف نمی‌کند و پایگاه داده بدون محدودیت رشد می‌کند.';

  @override
  String get retentionMetrics => 'نگهداری معیارها';

  @override
  String get retentionAlerts => 'نگهداری هشدارها';

  @override
  String get retentionCleanup => 'اجرای پاک‌سازی هر';

  @override
  String get retentionMaxDbSize => 'حداکثر حجم پایگاه داده';

  @override
  String get corsOrigins => 'مبداهای مجاز CORS';

  @override
  String get corsOriginsTip =>
      'مبداهایی که یک پنل مرورگر مجاز است از آن‌ها این Agent را فراخوانی کند. خالی بودن به معنای فقط همان مبدا است.';

  @override
  String get monitorNoRemoteAccess =>
      'این Agent فقط برای پایش تنظیم شده است. شما نمی‌توانید در اینجا ترمینال باز کنید، دستورات را اجرا نمایید یا فایل‌ها را مرور کنید. برای فعال کردن این قابلیت‌ها، بخش [remote_access] را در config.toml مربوط به Agent ویرایش کنید.';

  @override
  String get monitorAgentTooOld =>
      'این ایجنت Monitor قدیمی‌تر از آن است که این نسخه از ServerBox پشتیبانی کند. Agent را روی سرور به‌روزرسانی کنید.';

  @override
  String get monitorClientTooOld =>
      'این ایجنت Monitor دیگر از این نسخه از ServerBox پشتیبانی نمی‌کند. برنامه را به‌روزرسانی کنید.';

  @override
  String get alerts => 'هشدارها';

  @override
  String get online => 'آنلاین';

  @override
  String get densityCards => 'کارت‌ها';

  @override
  String get densityRows => 'ردیف‌ها';

  @override
  String get densityGrid => 'شبکه‌ای';

  @override
  String get connect => 'اتصال';

  @override
  String get disconnect => 'قطع اتصال';

  @override
  String get searchServerTip =>
      'نام‌ها و نشانی‌ها را جستجو می‌کند — دو موردی که ویرایشگر ابتدا می‌پرسد.';

  @override
  String get addServerTip =>
      'مشخصات را وارد کنید، کد QR را اسکن نمایید، یا فایلی را که دیگران به اشتراک گذاشته‌اند وارد کنید.';

  @override
  String get move => 'انتقال';

  @override
  String get moveToTop => 'انتقال به بالا';

  @override
  String get moveToBottom => 'انتقال به پایین';

  @override
  String get groupByTag => 'گروه‌بندی بر اساس برچسب';

  @override
  String get groupByTagTip =>
      'برچسب‌ها در ویرایشگر اختصاصی سرور تنظیم می‌شوند.';

  @override
  String get connecting => 'در حال اتصال…';

  @override
  String get authShort => 'احراز هویت';

  @override
  String get remoteDesktopFitToWindow => 'هم‌اندازه با پنجره';

  @override
  String get remoteDesktopActualSize => 'اندازه واقعی';

  @override
  String get remoteDesktopZoom => 'بزرگ‌نمایی';

  @override
  String get remoteDesktopViewOnly => 'فقط مشاهده';

  @override
  String get remoteDesktopDisableViewOnly => 'غیرفعال کردن فقط مشاهده';

  @override
  String get remoteDesktopSendClipboardText => 'ارسال متن کلیپ‌بورد';

  @override
  String get remoteDesktopShowKeyboard => 'نمایش صفحه‌کلید';

  @override
  String get remoteDesktopMoreControls => 'کنترل‌های بیشتر';

  @override
  String get remoteDesktopUseDirectPointer => 'استفاده از اشاره‌گر مستقیم';

  @override
  String get remoteDesktopUseTouchpadPointer => 'استفاده از اشاره‌گر تاچ‌پد';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'ارسال Ctrl+Alt+Delete';

  @override
  String get remoteDesktopReconnect => 'اتصال مجدد';

  @override
  String get remoteDesktopFullScreen => 'تمام‌صفحه';

  @override
  String get remoteDesktopExitFullScreen => 'خروج از تمام‌صفحه';

  @override
  String get remoteDesktopCloseSession => 'بستن جلسه';

  @override
  String get remoteDesktopConnected => 'متصل';

  @override
  String get remoteDesktopConnecting => 'در حال اتصال';

  @override
  String get remoteDesktopReconnecting => 'در حال اتصال مجدد';

  @override
  String get remoteDesktopDisconnected => 'قطع‌شده';

  @override
  String get remoteDesktopGuideTouch => 'تاچ‌پد';

  @override
  String get remoteDesktopGuideTouchTip =>
      'یک انگشت نشانگر را مانند تاچ‌پد حرکت می‌دهد و یک ضربه کلیک می‌کند. برای راست‌کلیک با دو انگشت ضربه بزنید، برای پیمایش با دو انگشت بکشید و برای بزرگ‌نمایی دو انگشت را جمع یا باز کنید. برای کشیدن، دو بار ضربه بزنید و انگشت را نگه دارید.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'صفحه‌کلید مجازی را باز می‌کند. آنچه تایپ می‌کنید به ریموت دسکتاپ ارسال می‌شود.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'ارسال نشانگر و کلیدها را متوقف می‌کند تا بتوانید بدون کلیک تصادفی، صفحه را مشاهده کنید.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'گزینه‌های Ctrl+Alt+Delete، اتصال مجدد و تمام‌صفحه در اینجا قرار دارند.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'همچنین اشاره‌گر مستقیم که در آن لمس انگشت روی هر قسمت باعث کلیک می‌شود.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'کلیپ‌بورد VNC فقط از متن با کدگذاری Latin-1 پشتیبانی می‌کند.';

  @override
  String get remoteDesktopAddProfile => 'افزودن پروفایل';

  @override
  String get remoteDesktopNoProfiles => 'هیچ پروفایل ریموت دسکتاپی وجود ندارد';

  @override
  String get remoteDesktopAdd => 'افزودن ریموت دسکتاپ';

  @override
  String get remoteDesktopEdit => 'ویرایش ریموت دسکتاپ';

  @override
  String get remoteDesktopTargetTip =>
      'مقصد از طریق سرور SSH یا ایجنت Monitor شناسایی می‌شود. کلمه Localhost به همان دستگاه اشاره دارد.';

  @override
  String get remoteDesktopDomain => 'دامنه (اختیاری)';

  @override
  String get remoteDesktopPassword => 'گذرواژه (اختیاری)';

  @override
  String get remoteDesktopSavePassword => 'ذخیره گذرواژه';

  @override
  String get remoteDesktopSavePasswordTip =>
      'در پایگاه داده رمزگذاری‌شده ذخیره می‌شود. پشتیبان‌گیری‌ها شامل گذرواژه‌های ذخیره‌شده هستند و فقط زمانی رمزگذاری می‌شوند که گذرواژه پشتیبان‌گیری تعیین شده باشد.';

  @override
  String get remoteDesktopShareSession => 'اشتراک‌گذاری جلسه';

  @override
  String get remoteDesktopProtocol => 'پروتکل';

  @override
  String get remoteDesktopUniqueName =>
      'نام‌های پروفایل باید برای این سرور یکتا باشند.';

  @override
  String get remoteDesktopNameRequired => 'یک نام برای پروفایل وارد کنید.';

  @override
  String get remoteDesktopHostRequired => 'یک میزبان مقصد وارد کنید.';

  @override
  String get remoteDesktopPortRequired => 'یک پورت معتبر وارد کنید.';

  @override
  String get remoteDesktopUsernameRequired => 'نام کاربری RDP را وارد کنید.';

  @override
  String get remoteDesktopNameInvalid =>
      'نام پروفایل می‌تواند حداکثر تا ۶۴ نویسه باشد و نباید شامل شکستگی خط باشد.';

  @override
  String get remoteDesktopHostInvalid =>
      'میزبان مقصد نمی‌تواند شامل فاصله یا شکستگی خط باشد.';

  @override
  String get remoteDesktopCredentialInvalid =>
      'نام کاربری و دامنه می‌توانند حداکثر تا ۲۵۶ نویسه باشند و نباید شامل شکستگی خط باشند.';

  @override
  String get remoteDesktopVncPasswordHint =>
      'در VNC کلاسیک فقط از ۸ نویسه اول استفاده می‌شود';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'گذرواژه‌های VNC کلاسیک فقط باید شامل نویسه‌های ASCII باشند.';

  @override
  String get remoteDesktopCertificateRequired => 'تأیید گواهی الزامی است';

  @override
  String get remoteDesktopWaiting => 'در انتظار دسکتاپ…';

  @override
  String get remoteDesktopCertificateChanged =>
      'گواهی ریموت دسکتاپ تغییر کرده است';

  @override
  String get remoteDesktopTrustCertificate => 'به گواهی اعتماد شود؟';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'اثر انگشت گواهی دیگر با مقدار ذخیره‌شده مطابقت ندارد. قبل از جایگزینی اعتماد، اثر انگشت جدید را بررسی کنید.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'سیستم نتوانست این گواهی را تأیید کند. قبل از ادامه، اثر انگشت SHA-256 آن را بررسی کنید.';

  @override
  String get remoteDesktopReplaceTrust => 'جایگزینی اعتماد';

  @override
  String get remoteDesktopTrustReconnect => 'اعتماد و اتصال مجدد';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'آیا پروفایل ریموت دسکتاپ «$name» حذف شود؟';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'در حال اتصال مجدد ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'قبلاً مورد اعتماد بوده است\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'موضوع: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'صادرکننده: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'معتبر: $start – $end';
  }

  @override
  String get pveAuthToken => 'توکن API';

  @override
  String get pveVersionLow =>
      'این قابلیت در حال حاضر در مرحله آزمایشی است و تنها روی PVE 8+ تست شده است. لطفاً با احتیاط از آن استفاده کنید.';

  @override
  String get pveTokenId => 'شناسه توکن';

  @override
  String get pveTokenSecret => 'کلید مخفی توکن';

  @override
  String get pveTokenTip =>
      'یک مورد در PVE در مسیر Datacenter ← Permissions ← API Tokens ایجاد کنید. این توکن برای نمایش مسیرها به VM.Audit، VM.PowerMgmt، VM.Console، VM.Snapshot، VM.Snapshot.Rollback، Datastore.Audit و Sys.Audit نیاز دارد؛ در صورت فعال بودن جداسازی اختیارات، آن‌ها را به خود توکن اختصاص دهید.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'توکن $account ممکن است نتواند چیزی در این میزبان ببیند. یک توکن با جداسازی اختیارات، مجوزهای کاربر خود را ندارد؛ در میزبان PVE به آن دسترسی بدهید:\n$command\nیا گزینه «Privilege Separation» را برای توکن غیرفعال کنید.';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return 'حساب $account ممکن است نتواند چیزی در این میزبان ببیند. در میزبان PVE به آن دسترسی بدهید:\n$command';
  }

  @override
  String get pveTokenIdInvalid =>
      'شناسه توکن باید به صورت user@realm!tokenid باشد';

  @override
  String get pvePasswordAuthTip =>
      'به عنوان کاربر SSH در قلمرو PAM، با گذرواژه SSH یا در صورتی که SSH از کلید استفاده می‌کند با گذرواژه PVE زیر وارد می‌شود. در صورت نیاز کد دومرحله‌ای درخواست خواهد شد.';

  @override
  String get pveCertUnpinned =>
      'هنوز موردی تأیید نشده است. مگر اینکه یک CA معتبر آن را امضا کرده باشد، در اتصال بعدی گواهی برای تأیید نمایش داده می‌شود.';

  @override
  String get pveCertForget => 'فراموش کردن گواهی';

  @override
  String get pveCertForgetTip =>
      'در اتصال بعدی، گواهی PVE دوباره برای تأیید نمایش داده خواهد شد.';

  @override
  String get virtualization => 'مجازی‌سازی';

  @override
  String get virtIntro =>
      'مدیریت ماشین‌های مجازی و کانتینرها در میزبان‌های Proxmox VE و libvirt/KVM: وضعیت، عملیات مربوط به برق و کنسول‌های آن‌ها.';

  @override
  String get virtIntroPveMoved =>
      'بخش Proxmox VE از صفحه سرور به این برگه منتقل شده است. کارت PVE هر سرور آن را در اینجا باز می‌کند.';

  @override
  String get virtIntroLibvirt =>
      'سروری که ابزار virsh متعلق به libvirt روی آن نصب باشد، به همراه ماشین‌های مجازی QEMU/KVM خود به عنوان میزبان نمایش داده می‌شود.';

  @override
  String get virtIntroTransports =>
      'هر دو از طریق SSH، با یک ایجنت Monitor، یا روی همین دستگاه کار می‌کنند.';

  @override
  String get virtIntroTokens =>
      'در PVE می‌توان به جای گذرواژه با یک توکن API وارد شد. آن را در صفحه ویرایش سرور، زیر بخش PVE تنظیم کنید.';

  @override
  String get virtIntroInBar => 'این بخش به نوار برگه‌ها افزوده شده است.';

  @override
  String get virtIntroInMore =>
      'این بخش در «بیشتر» قرار دارد. از طریق «برگه‌های خانه» در تنظیمات می‌توان آن را به نوار برگه‌ها منتقل کرد.';

  @override
  String get virtGuests => 'ماشین‌های مجازی';

  @override
  String get virtHosts => 'میزبان‌ها';

  @override
  String get virtCheckServer => 'بررسی این سرور';

  @override
  String get virtCheckAll => 'بررسی همه سرورها';

  @override
  String get virtProbeNotChecked => 'هنوز بررسی نشده است';

  @override
  String get virtProbeAbsent => 'میزبان نیست';

  @override
  String virtProbeContainer(String kind) {
    return 'کانتینر $kind';
  }

  @override
  String get virtProbeContainerTip =>
      'این سرور درون یک کانتینر اجرا می‌شود، بنابراین به جای میزبان یک مهمان است و از میزبانی که آن را اجرا می‌کند مدیریت می‌شود.';

  @override
  String get virtProbePve => 'سامانه PVE، راه‌اندازی‌نشده';

  @override
  String virtPveSetupTip(String version) {
    return 'نسخه $version روی این سرور در حال اجرا است. دسترسی API آن را در تنظیمات سرور وارد کنید (یک توکن API توصیه می‌شود) تا ماشین‌های مجازی و کانتینرهای آن را در اینجا مدیریت کنید.';
  }

  @override
  String get virtNoHosts => 'هیچ میزبان مجازی‌سازی وجود ندارد';

  @override
  String get virtNoHostsTip =>
      'سروری که Proxmox VE را اجرا می‌کند و دسترسی API آن تنظیم شده باشد یک میزبان است، و سروری که virsh در آن پاسخ دهد نیز همین‌طور است. سایر سرورها را می‌توان از بخش تغییر میزبان بررسی کرد.';

  @override
  String get virtNoGuests => 'هیچ ماشین مجازی یا کانتینری وجود ندارد';

  @override
  String get virtPaused => 'مکث';

  @override
  String get virtStarting => 'در حال راه‌اندازی…';

  @override
  String get virtStopping => 'در حال توقف…';

  @override
  String get virtRebooting => 'در حال راه‌اندازی مجدد…';

  @override
  String get virtMigrating => 'در حال مهاجرت…';

  @override
  String get virtBackingUp => 'در حال پشتیبان‌گیری…';

  @override
  String get virtResume => 'ادامه';

  @override
  String get virtOverview => 'نمای کلی';

  @override
  String get virtConsole => 'کنسول';

  @override
  String get virtConsoleNone => 'هیچ کنسولی برای این مهمان پیکربندی نشده است';

  @override
  String get virtConsoleGraphical => 'گرافیکی';

  @override
  String get virtVncPasswordNeeded => 'این تصویر نیاز به گذرواژه دارد';

  @override
  String get virtConsoleSerialTip =>
      'کنسول سریال مهمان را با virsh روی میزبان باز می‌کند. قطع اتصال، یا فشردن Ctrl+]، شما را به شل میزبان بازمی‌گرداند.';

  @override
  String virtConsoleVia(String transport) {
    return 'از طریق $transport';
  }

  @override
  String get virtConsoleEnterTip => 'خروجی وجود ندارد؟ Enter را فشار دهید';

  @override
  String virtConsoleAutoEnter(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds ثانیه',
      one: '1 ثانیه',
    );
    return 'ارسال Enter تا $_temp0 دیگر برای نمایش اعلان ورودی';
  }

  @override
  String get virtConsoleEnterNow => 'اکنون';

  @override
  String get virtOffTip =>
      'آن را روشن کنید تا مصرف زنده CPU، حافظه، دیسک و شبکه را در اینجا مشاهده نمایید.';

  @override
  String get virtAllocated => 'اختصاص‌یافته';

  @override
  String virtRunningCount(int running, int total) {
    return '$running در حال اجرا · $total در کل';
  }

  @override
  String get virtTemplate => 'قالب';

  @override
  String get virtAutostart => 'راه‌اندازی همگام با میزبان';

  @override
  String get virtErrUnreachable => 'امکان دسترسی به این میزبان وجود نداشت';

  @override
  String get virtErrNotConfigured => 'تنظیمات PVE این سرور ناقص است';

  @override
  String get virtErrNotConfiguredTip =>
      'آدرس و گذرواژه یا توکن API را در تنظیمات سرور بررسی کنید.';

  @override
  String get virtErrAuthFailed => 'میزبان ورود را رد کرد';

  @override
  String get virtErrCertUnconfirmed => 'گواهی میزبان را تأیید کنید';

  @override
  String get virtErrCertChanged => 'گواهی میزبان تغییر کرده است';

  @override
  String get virtErrRelayNotGranted => 'ایجنت Monitor اتصالات را رله نمی‌کند';

  @override
  String get virtErrExecNotGranted => 'ایجنت Monitor دستورات را اجرا نمی‌کند';

  @override
  String get virtErrNotInstalled => 'ابزار virsh روی این سرور نصب نشده است';

  @override
  String get virtErrServerRemoved => 'این سرور دیگر وجود ندارد';

  @override
  String get virtErrSudoRequired =>
      'دستور sudo برای دسترسی به libvirt به گذرواژه نیاز دارد';

  @override
  String get virtErrSudoRejected => 'دستور sudo گذرواژه را رد کرد';

  @override
  String get virtErrInvalidResponse => 'میزبان به شکل غیرمنتظره‌ای پاسخ داد';

  @override
  String get virtErrActionFailed => 'میزبان این عملیات را رد کرد';

  @override
  String get remoteSessionIdleTimeout => 'بستن در صورت عدم فعالیت';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'مدت زمانی را مشخص می‌کند که دسکتاپ راه دور یا کنسول ماشین مجازی پس از خروج شما همچنان متصل می‌ماند. پیش از قطع اتصال، هشداری نمایش داده می‌شود و ۱۰ ثانیه فرصت دارید اتصال را حفظ کنید.';

  @override
  String get remoteSessionKeepAlive => 'فعال نگه داشتن';

  @override
  String get remoteSessionClosedAway => 'در زمان عدم حضور شما بسته شد';

  @override
  String remoteSessionClosingIn(int seconds) {
    return 'بسته شدن تا $seconds ثانیه دیگر';
  }

  @override
  String get virtSnapshots => 'اسنپ‌شات‌ها';

  @override
  String get virtSnapshotCreate => 'گرفتن اسنپ‌شات';

  @override
  String get virtSnapshotNone => 'هنوز اسنپ‌شاتی وجود ندارد';

  @override
  String get virtSnapshotWithMemory => 'دیسک‌ها و حافظه';

  @override
  String get virtSnapshotDiskOnly => 'فقط دیسک‌ها';

  @override
  String get virtSnapshotParent => 'والد';

  @override
  String get virtSnapshotRevert => 'بازگردانی';

  @override
  String get virtSnapshotMemory => 'شامل حافظه';

  @override
  String get virtSnapshotMemoryTip =>
      'بازگردانی، اجرای مهمان را از همین لحظه از سر می‌گیرد.';

  @override
  String get virtSnapshotMemoryAlways =>
      'اسنپ‌شات یک مهمان در حال اجرا در اینجا همیشه شامل حافظه آن می‌شود.';

  @override
  String get virtSnapshotMemoryOff =>
      'مهمان در حال اجرا نیست، بنابراین فقط دیسک‌های آن ذخیره می‌شوند.';

  @override
  String get virtSnapshotNameInvalid =>
      'ابتدا یک حرف، سپس حروف، ارقام، - یا _؛ بین ۲ تا ۴۰ نویسه.';

  @override
  String get virtSnapshotNameTaken => 'اسنپ‌شاتی با این نام وجود دارد.';

  @override
  String get virtSnapshotRevertTip =>
      'بازگردانی، تمام تغییرات ایجادشده پس از اسنپ‌شات را لغو می‌کند.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return 'آیا $guest به $snapshot بازگردانده شود؟ تمام تغییرات پس از ثبت آن از دست می‌روند.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'این اسنپ‌شات فاقد حافظه است: $guest متوقف خواهد شد.';
  }

  @override
  String get virtSnapshotStartAfter => 'راه‌اندازی پس از آن';

  @override
  String get virtVolumes => 'حجم‌ها';

  @override
  String get virtNoPools => 'هیچ استخر ذخیره‌سازی وجود ندارد';

  @override
  String get virtNoNetworks => 'هیچ شبکه‌ای وجود ندارد';

  @override
  String get virtPoolInactive =>
      'این استخر فعال نیست، بنابراین نمی‌توان حجم‌های آن را فهرست کرد.';

  @override
  String get virtShared => 'مشترک بین نودها';

  @override
  String get virtBackingFile => 'فایل پایه';

  @override
  String get virtNetIsolated => 'ایزوله';

  @override
  String get virtNetBridged => 'بریج‌شده';

  @override
  String get virtNetRouted => 'مسیریابی‌شده';

  @override
  String get virtBridge => 'بریج';

  @override
  String get virtPorts => 'پورت‌ها';

  @override
  String get virtAttachedGuests => 'مهمان‌های متصل';

  @override
  String get virtNoAttachedGuests => 'هیچ مهمانی به آن متصل نیست';

  @override
  String get virtCreateVm => 'ماشین مجازی جدید';

  @override
  String get virtCreateLxc => 'کانتینر جدید';

  @override
  String get virtCreateGuest => 'ماشین مجازی یا کانتینر جدید';

  @override
  String get virtKindVm => 'ماشین مجازی';

  @override
  String get virtKindLxc => 'کانتینر';

  @override
  String get virtHostname => 'نام میزبان';

  @override
  String get virtInstallMedia => 'رسانه نصب';

  @override
  String get virtNoIsos => 'هیچ ایمیج ISO روی این میزبان وجود ندارد';

  @override
  String get virtNoTemplates =>
      'هیچ الگوی کانتینری روی این میزبان وجود ندارد. از بخش CT Templates در فضای ذخیره‌سازی PVE می‌توانید یکی دانلود کنید.';

  @override
  String get virtNoDiskStorage =>
      'هیچ فضایی روی این میزبان امکان پذیرش دیسک جدید را ندارد';

  @override
  String get virtStartAfterCreate => 'راه‌اندازی پس از ایجاد';

  @override
  String get virtUnprivileged => 'کانتینر غیرممتاز';

  @override
  String get virtUnprivilegedTip =>
      'کاربر root آن یک کاربر معمولی در میزبان است.';

  @override
  String get virtSshKeys => 'کلیدهای عمومی SSH';

  @override
  String get virtCredentialsTip => 'یک گذرواژه root، کلیدهای SSH، یا هر دو.';

  @override
  String virtCreated(String name) {
    return 'مهمان $name ایجاد شد';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return 'مهمان $name ایجاد شد اما راه‌اندازی نشد';
  }

  @override
  String get virtErrExists => 'مهمان یا دیسکی با این نام از قبل وجود دارد';

  @override
  String get virtCreateNameInvalidLibvirt =>
      'حروف، ارقام، .، _ و -، شروع با یک حرف یا رقم؛ تا 63 نویسه.';

  @override
  String get virtCreateNameInvalidPve =>
      'حروف، ارقام و -، در بخش‌های جداشده با نقطه؛ تا 63 نویسه.';

  @override
  String get virtCreateNameTaken => 'مهمانی با این نام وجود دارد.';

  @override
  String get virtCreateVmidTaken => 'این VMID قبلاً گرفته شده است.';

  @override
  String get virtCreateCoresInvalid =>
      'تعداد هسته‌ها بیش از حد مجاز این میزبان است.';

  @override
  String get virtCreateMemoryInvalid => 'حافظه آزاد کافی نیست.';

  @override
  String get virtCreateStorageMissing => 'محل ذخیره دیسک را انتخاب کنید.';

  @override
  String get virtCreateDiskInvalid => 'از 1 GiB تا 64 TiB.';

  @override
  String get virtCreateTemplateMissing => 'یک الگو انتخاب کنید.';

  @override
  String get virtCreateCredentialsMissing =>
      'گذرواژه root یا کلید عمومی SSH تنظیم کنید.';

  @override
  String virtCreatePasswordShort(int min) {
    return 'حداقل $min نویسه.';
  }

  @override
  String get virtCreateSshKeysInvalid => 'در هر خط یک کلید عمومی OpenSSH.';

  @override
  String get virtDeleteDisks => 'دیسک‌های آن نیز حذف شوند';

  @override
  String get virtDeleteDisksPve =>
      'دیسک‌های آن همراه با آن حذف می‌شوند؛ رسانه نصب نگه داشته می‌شود.';

  @override
  String virtDeleted(String name) {
    return 'مهمان $name حذف شد';
  }

  @override
  String get pveTokenTipCreate =>
      'ایجاد و حذف مهمان‌ها همچنین به VM.Allocate، ‏VM.Config.*، ‏Datastore.AllocateSpace و SDN.Use نیاز دارد.';

  @override
  String get pveTokenTipHardware =>
      'ویرایش سخت‌افزار به VM.Config.CPU، ‏VM.Config.Memory، ‏VM.Config.Disk، ‏VM.Config.CDROM، ‏VM.Config.Network و VM.Config.Options نیاز دارد؛ دیسک‌ها و رابط‌های جدید نیز به Datastore.AllocateSpace و SDN.Use نیاز دارند. کارت گرافیک و دستگاه‌های USB و PCI همچنین به VM.Config.HWType نیاز دارند؛ دستگاهی که از طریق نگاشت منابع اختصاص می‌یابد نیازمند Mapping.Use روی آن و Mapping.Audit برای فهرست کردن نگاشت‌ها است.';

  @override
  String get pveTokenTipBackup =>
      'کلون کردن به VM.Clone، پشتیبان‌گیری و بازیابی به VM.Backup، و تبدیل یک مهمان به الگو به VM.Allocate نیاز دارد؛ کارهای پشتیبان‌گیری همچنین به Sys.Audit برای خواندن آن‌ها و Sys.Modify در / برای ایجاد، ویرایش و حذف آن‌ها نیاز دارند، به همراه Datastore.AllocateSpace در محلی که رونوشت یا پشتیبان قرار می‌گیرد.';

  @override
  String get virtErrConflict => 'در جای دیگری تغییر کرده است';

  @override
  String get virtErrConflictTip =>
      'شخصی این پیکربندی را پس از خوانده شدن در اینجا تغییر داده است، بنابراین تغییری اعمال نشد. مجدداً خوانده شد: در صورت لزوم تغییر را دوباره اعمال کنید.';

  @override
  String get virtHardware => 'سخت‌افزار';

  @override
  String get virtHwAddDisk => 'افزودن دیسک';

  @override
  String get virtHwAddMount => 'افزودن نقطه اتصال';

  @override
  String get virtHwAddNic => 'افزودن رابط شبکه';

  @override
  String get virtHwAppliesOnRestart =>
      'ذخیره شد. در راه‌اندازی بعدی اعمال می‌شود.';

  @override
  String get virtHwAutostart => 'راه‌اندازی با میزبان';

  @override
  String get virtHwAutostartPve => 'گزینه onboot · راه‌اندازی به ترتیب VMID';

  @override
  String get virtHwBalloonLibvirt => 'حافظه فعلی';

  @override
  String get virtHwBalloonNote =>
      'به میزبان امکان می‌دهد در صورت کمبود حافظه، حافظه بیکار مهمان را پس بگیرد';

  @override
  String get virtHwBoot => 'بوت';

  @override
  String get virtHwBootOrder => 'ترتیب بوت';

  @override
  String get virtHwBootTip =>
      'فلش‌ها دستگاه را جابه‌جا می‌کنند؛ با ضربه روی آن، بوت شدن از آن فعال یا غیرفعال می‌شود.';

  @override
  String get virtHwCdrom => 'درایو CD-ROM';

  @override
  String get virtHwConfigFile => 'فایل پیکربندی';

  @override
  String get virtHwCores => 'هسته‌ها';

  @override
  String get virtHwCpuTypeDefault => 'پیش‌فرض';

  @override
  String get virtHwDeleteVolume => 'حجم آن نیز حذف شود';

  @override
  String get virtHwDetach => 'جدا کردن';

  @override
  String get virtHwDiskHotplug =>
      'قابلیت اتصال حین کار: می‌تواند در حین اجرا اضافه شود';

  @override
  String get virtHwDisksLxc => 'دیسک root و نقاط اتصال';

  @override
  String get virtHwEject => 'خارج کردن';

  @override
  String get virtHwEmpty => 'بدون رسانه';

  @override
  String get virtHwFirewall => 'فایروال';

  @override
  String virtHwFree(String size) {
    return 'فضای آزاد $size';
  }

  @override
  String get virtHwGrow => 'افزایش حجم';

  @override
  String get virtHwGrowNote =>
      'دیسک‌ها فقط می‌توانند از اندازه فعلی خود بزرگ‌تر شوند.';

  @override
  String get virtHwGrowNoteRunning =>
      'دیسک‌ها فقط می‌توانند از اندازه فعلی خود بزرگ‌تر شوند. در صورت افزایش حجم حین اجرا، پارتیشن باید در داخل مهمان گسترش یابد.';

  @override
  String get virtHwGuestUsed => 'استفاده‌شده توسط مهمان';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'میزبان: $threads رشته · $allocated تخصیص‌یافته';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'میزبان: $total · $allocated تخصیص‌یافته';
  }

  @override
  String get virtHwHotplugNow => 'اتصال حین کار: بلافاصله اعمال می‌شود.';

  @override
  String get virtHwIssueBootEmpty => 'حداقل یک دستگاه را علامت بزنید';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'در مجموع بین 1 تا $max vCPU';
  }

  @override
  String get virtHwIssueCpuOnline => 'تعداد vCPUهای آنلاین: از 1 تا کل';

  @override
  String get virtHwIssueDiskShrink =>
      'بزرگ‌تر از اندازه فعلی: دیسک‌ها فقط می‌توانند افزایش حجم داشته باشند';

  @override
  String get virtHwIssueDiskSize => 'از 1 تا 65536 GiB';

  @override
  String virtHwIssueMemory(int min, int max) {
    return 'از $min تا $max MiB';
  }

  @override
  String get virtHwIssueMemoryMin => 'نباید بیشتر از حافظه باشد';

  @override
  String get virtHwIssueMountPoint => 'یک مسیر مطلق، مانند /data';

  @override
  String get virtHwIssueStorageSpace => 'بیشتر از فضای خالی ذخیره‌ساز است';

  @override
  String get virtHwLater => 'در راه‌اندازی مجدد اعمال می‌شود';

  @override
  String get virtHwLess => 'کمتر';

  @override
  String get virtHwLinkDown => 'قطع‌شده';

  @override
  String get virtHwLinkNote =>
      'در حالت خاموش، مهمان قطع کابل را می‌بیند؛ بدون نیاز به راه‌اندازی مجدد';

  @override
  String get virtHwLinkUp => 'متصل';

  @override
  String get virtHwMac => 'آدرس MAC';

  @override
  String get virtHwModel => 'مدل';

  @override
  String get virtHwMore => 'بیشتر';

  @override
  String get virtHwMountFromPool =>
      'نقاط اتصال مستقیماً از فضای ذخیره‌سازی تخصیص می‌یابند';

  @override
  String get virtHwMountPoint => 'نقطه اتصال';

  @override
  String get virtHwMoveDown => 'انتقال به پایین';

  @override
  String get virtHwMoveUp => 'انتقال به بالا';

  @override
  String get virtHwNewDisk => 'دیسک جدید';

  @override
  String get virtHwNewMount => 'نقطه اتصال جدید';

  @override
  String get virtHwNewNic => 'رابط شبکه جدید';

  @override
  String get virtHwNicHotplug =>
      'کارت‌های شبکه virtio قابل اتصال حین کار هستند';

  @override
  String get virtHwNics => 'رابط‌های شبکه';

  @override
  String get virtHwNoMedia => 'بدون رسانه';

  @override
  String get virtHwNoNetworks => 'هیچ شبکه یا پلی در اینجا وجود ندارد';

  @override
  String get virtHwNoStorage => 'هیچ فضای ذخیره‌سازی در اینجا دیسک نمی‌پذیرد';

  @override
  String get virtHwOnline => 'تعداد vCPUهای آنلاین';

  @override
  String get virtHwPendingBanner =>
      'برخی تغییرات سخت‌افزاری پس از راه‌اندازی مجدد اعمال می‌شوند';

  @override
  String get virtHwPickNet => 'یک شبکه انتخاب کنید';

  @override
  String get virtHwPickPool => 'فضای ذخیره‌سازی و اندازه را انتخاب کنید';

  @override
  String get virtHwProcessor => 'پردازنده';

  @override
  String get virtHwRemove => 'حذف';

  @override
  String get virtHwRemoveCdrom => 'حذف CD-ROM';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return 'دیسک $disk از $guest حذف شود؟';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return 'رابط $nic از $guest حذف شود؟';
  }

  @override
  String get virtHwResources => 'منابع';

  @override
  String get virtHwRestartNow => 'راه‌اندازی مجدد اکنون';

  @override
  String get virtHwRevert => 'بازگردانی';

  @override
  String get virtHwRevertAll => 'بازگردانی همه';

  @override
  String get virtSetRenameStopped =>
      'برای تغییر نام مهمان، آن را خاموش کنید: libvirt فقط نام مهمانی را تغییر می‌دهد که در حال اجرا نباشد.';

  @override
  String virtSetIssueDescription(int max) {
    return 'حداکثر $max بایت (UTF-8)، و بدون نویسه‌های کنترلی.';
  }

  @override
  String get virtSetManualStart => 'راه‌اندازی دستی';

  @override
  String get virtSetProtection => 'محافظت';

  @override
  String get virtSetProtectionNote =>
      'مانع از حذف مهمان و تغییر دیسک‌های آن می‌شود';

  @override
  String get virtSetIrreversible => 'غیرقابل بازگشت';

  @override
  String get virtSetDeleteStopFirst => 'قبل از حذف، آن را خاموش کنید.';

  @override
  String get virtSetDeleteProtected =>
      'محافظت فعال است: ابتدا آن را در «عمومی» خاموش کنید.';

  @override
  String get virtSetDeleteAgain => 'برای تأیید دوباره فشار دهید';

  @override
  String virtSetDeleteConfirm(String name) {
    return 'حذف $name';
  }

  @override
  String get virtSetDeleteVm => 'حذف ماشین مجازی';

  @override
  String get virtSetDeleteLxc => 'حذف کانتینر';

  @override
  String get virtHwSockets => 'سوکت‌ها';

  @override
  String get virtHwSource => 'منبع';

  @override
  String get virtHwSwap => 'حافظه swap';

  @override
  String get virtHwTopology => 'سوکت‌ها × هسته‌ها';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets سوکت × $cores هسته × $threads رشته';
  }

  @override
  String virtHwTotal(String size) {
    return 'مجموع $size';
  }

  @override
  String get virtHwVolumeKept =>
      'پیکربندی دیسک حذف شد، اما ماشین مجازیِ در حال اجرا هنوز از آن استفاده می‌کند؛ بنابراین volume فعلاً نگه داشته می‌شود. این volume در راه‌اندازی بعدی جدا خواهد شد.';

  @override
  String get virtHwBus => 'گذرگاه';

  @override
  String get virtHwCache => 'حافظه کش';

  @override
  String get virtHwBusStopped =>
      'گذرگاه فقط در زمانی که مهمان متوقف است تغییر می‌کند.';

  @override
  String get virtHwMacGenerate => 'تولید';

  @override
  String get virtHwIssueMac =>
      'باید یک آدرس MAC یونیکست باشد، مانند 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => 'ابتدا مهمان را متوقف کنید';

  @override
  String get virtHwIssueStorageMissing =>
      'ابتدا یک فضای ذخیره‌سازی برای آن انتخاب کنید';

  @override
  String get virtHwIssueDevice => 'ابتدا یک دستگاه انتخاب کنید';

  @override
  String get virtHwDevices => 'درایو CD-ROM و گذردهی';

  @override
  String get virtHwDevicesEmpty => 'گذردهی USB و PCI، درایو CD-ROM، ‏TPM';

  @override
  String get virtHwAddDevice => 'افزودن دستگاه';

  @override
  String get virtHwNewDevice => 'دستگاه جدید';

  @override
  String get virtHwUsbHotplug => 'گذردهی USB قابلیت اتصال حین کار دارد.';

  @override
  String get virtHwPci => 'گذردهی PCI';

  @override
  String get virtHwIommuOffTitle => 'میزبان فاقد IOMMU است';

  @override
  String get virtHwIommuOffBody =>
      'ابتدا VT-d یا AMD-Vi را در BIOS میزبان و IOMMU را در کرنل آن فعال کنید. تا آن زمان، مهمانی که دستگاه PCI به آن اختصاص داده شده باشد راه‌اندازی نخواهد شد.';

  @override
  String get virtHwPciTitle => 'نیازمند IOMMU در میزبان';

  @override
  String get virtHwPciBody =>
      'پس از گذردهی، میزبان نمی‌تواند از دستگاه استفاده کند و مهمان در حین اجرا امکان مهاجرت ندارد.';

  @override
  String virtHwIommuGroup(int group) {
    return 'گروه IOMMU $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '$count دستگاه در این گروه IOMMU مشترک هستند و با هم گذردهی می‌شوند';
  }

  @override
  String get virtHwNoHostDevices =>
      'هیچ دستگاهی برای گذردهی در این میزبان وجود ندارد';

  @override
  String get virtHwMappingsOnly =>
      'در اینجا فقط نگاشت‌های منبع قابل استفاده هستند: PVE فقط به root@pam که با گذرواژه خود وارد شده باشد اجازه گذردهی دستگاه خام را می‌دهد. نگاشت‌ها را در مسیر Datacenter ← Resource Mappings ایجاد کنید.';

  @override
  String get virtHwTpmNote => 'سیستم‌عامل Windows 11 به TPM 2.0 نیاز دارد.';

  @override
  String get virtHwDisplay => 'نمایشگر';

  @override
  String get virtHwProtocol => 'پروتکل';

  @override
  String get virtHwListen => 'شنود';

  @override
  String get virtHwGpu => 'کارت گرافیک';

  @override
  String get virtHwListenAllTitle => 'کنسول در شبکه باز است';

  @override
  String get virtHwListenAllBody =>
      'شنود روی همه آدرس‌ها به هر کسی که به میزبان دسترسی دارد اجازه می‌دهد به کنسول متصل شود. آدرس 127.0.0.1 را نگه دارید و از طریق تونل SSH متصل شوید.';

  @override
  String get virtHwFirmware => 'سفت‌افزار';

  @override
  String get virtHwUefiSub =>
      'سیستم OVMF · دارای قابلیت Secure Boot، مورد نیاز Windows 11';

  @override
  String get virtHwBiosSub =>
      'سیستم SeaBIOS · سیستم‌های قدیمی‌تر و دیسک‌های MBR';

  @override
  String get virtHwSecureBootNote =>
      'فقط کرنل‌ها و بوت‌لودرهای امضاشده را بوت می‌کند';

  @override
  String get virtHwFirmwareWarnTitle =>
      'سفت‌افزار یک سیستم نصب‌شده را تغییر ندهید';

  @override
  String get virtHwFirmwareWarnBody =>
      'تغییر بین UEFI و BIOS باعث عدم توانایی سیستم نصب‌شده در بوت شدن می‌شود.';

  @override
  String get virtHwFirmwareStopped =>
      'سفت‌افزار فقط در زمانی که مهمان متوقف است تغییر می‌کند.';

  @override
  String get virtHwSecureBootVars =>
      'فعال یا غیرفعال کردن Secure Boot متغیرهای EFI را از نو می‌سازد؛ ورودی‌های بوت ذخیره‌شده در آن‌ها از بین می‌روند.';

  @override
  String get virtHwEfiStorage => 'محل ذخیره متغیرهای EFI';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return 'سفت‌افزار $guest به $firmware تغییر یابد؟';
  }

  @override
  String get virtCloneName => 'نام جدید';

  @override
  String get virtCloneFull => 'کلون کامل';

  @override
  String get virtCloneCopyDisks => 'کپی محتویات دیسک';

  @override
  String get virtCloneLinkedNote =>
      'خاموش: کلون پیوندی، که به دیسک‌های الگو وابسته است';

  @override
  String get virtCloneFullOnly =>
      'فقط یک الگو می‌تواند به صورت کلون پیوندی شبیه‌سازی شود';

  @override
  String get virtCloneEmptyNote => 'خاموش: دیسک‌های خالی جدید با همان اندازه';

  @override
  String get virtCloneStopFirst => 'قبل از کلون کردن، آن را خاموش کنید.';

  @override
  String get virtCloneFullShort => 'کامل';

  @override
  String get virtCloneLinkedShort => 'پیوندی';

  @override
  String get virtCloneEmptyShort => 'دیسک‌های خالی';

  @override
  String get virtCloning => 'در حال کلون کردن…';

  @override
  String virtCloned(String name) {
    return 'کلون‌شده با نام $name';
  }

  @override
  String get virtBackupPlan => 'برنامه زمان‌بندی';

  @override
  String get virtBackupPlanWhere => 'مسیر Datacenter ← Backup';

  @override
  String get virtBackupNoPlanShort => 'بدون برنامه';

  @override
  String get virtBackupNoPlan =>
      'هیچ کار پشتیبان‌گیری زمان‌بندی‌شده‌ای شامل این مهمان نمی‌شود.';

  @override
  String get virtBackupKeep => 'نگهداری';

  @override
  String get virtBackupJobDisabled => 'این کار غیرفعال است.';

  @override
  String virtBackupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count پشتیبان‌گیری',
      one: '1 پشتیبان‌گیری',
    );
    return '$_temp0';
  }

  @override
  String virtSnapshotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count اسنپ‌شات',
      one: '1 اسنپ‌شات',
    );
    return '$_temp0';
  }

  @override
  String get virtBackupNoStorage =>
      'هیچ فضای ذخیره‌سازی در این نود نسخه‌های پشتیبان را نگه نمی‌دارد.';

  @override
  String get virtBackupLiveTip =>
      'ماشین مجازی روشن می‌ماند: پشتیبان‌گیری در حالت snapshot، بدون قطعی';

  @override
  String get virtBackupStoppedTip =>
      'متوقف‌شده: پشتیبان‌گیری به همان صورت موجود';

  @override
  String get virtBackupNow => 'پشتیبان‌گیری اکنون';

  @override
  String get virtBackupNotes => 'یادداشت‌ها';

  @override
  String get virtBackupProtected =>
      'محافظت‌شده: تا زمانی که محافظت در PVE برداشته نشود، قابل حذف نیست.';

  @override
  String virtBackupVerified(String state) {
    return 'وضعیت اعتبارسنجی: $state';
  }

  @override
  String get virtBackupRestoreOverwrites =>
      'بازیابی، دیسک‌های فعلی را بازنویسی می‌کند';

  @override
  String get virtBackupStopFirst => 'قبل از بازیابی، آن را خاموش کنید.';

  @override
  String get virtBackupRestoreAgain =>
      'دیسک‌ها و پیکربندی مهمان با دیسک‌ها و پیکربندی نسخه پشتیبان جایگزین می‌شوند.';

  @override
  String get virtBackupDeleteConfirm => 'حذف نسخه پشتیبان';

  @override
  String get virtBackupRestoreNew => 'بازیابی به عنوان مهمان جدید';

  @override
  String get virtBackupRestoreConfirm => 'بازیابی روی آن';

  @override
  String get virtBackupDone => 'پشتیبان‌گیری به پایان رسید';

  @override
  String get virtBackupDeleted => 'نسخه پشتیبان حذف شد';

  @override
  String virtBackupRestored(String time) {
    return 'بازیابی‌شده از $time';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return 'حساب $account فاقد مجوز $privilege در $path است. در میزبان PVE آن را اعطا کنید:\n$command';
  }

  @override
  String get virtCanDelete => 'قابل حذف';

  @override
  String get virtInUse => 'در حال استفاده';

  @override
  String get virtOps => 'عملیات';

  @override
  String get virtPool => 'استخر ذخیره‌سازی';

  @override
  String get virtPoolNew => 'استخر ذخیره‌سازی جدید';

  @override
  String get virtStorageAdd => 'افزودن فضای ذخیره‌سازی';

  @override
  String virtPoolUsedPct(String pct) {
    return '$pct% مصرف‌شده';
  }

  @override
  String get virtPoolInUse =>
      'یک مهمان از یک حجم در اینجا استفاده می‌کند، بنابراین استخر را نمی‌توان متوقف یا حذف کرد.';

  @override
  String get virtPoolDelete => 'حذف استخر';

  @override
  String get virtStorageRemove => 'حذف فضای ذخیره‌سازی';

  @override
  String virtPoolDeleteAsk(String name) {
    return 'استخر $name حذف شود؟ تعریف آن پاک می‌شود؛ حجم‌های آن در جای خود باقی می‌مانند.';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return 'فضای ذخیره‌سازی $name از پیکربندی PVE حذف شود؟ محتویات آن باقی خواهد ماند.';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return '$count حجم آن روی دیسک نگه داشته می‌شود.';
  }

  @override
  String get virtPoolDeleteStorage =>
      'پوشه آن نیز حذف شود (فقط در صورت خالی بودن)';

  @override
  String virtPoolStopAsk(String name) {
    return 'استخر $name متوقف شود؟ تا زمان شروع مجدد، حجم‌های آن قابل فهرست‌بندی یا ایجاد نخواهند بود.';
  }

  @override
  String get virtStorageClusterWide =>
      'این تغییر برای هر نود کلاستر که دارای این فضای ذخیره‌سازی است اعمال می‌شود.';

  @override
  String get virtStorageDisable => 'غیرفعال کردن';

  @override
  String get virtStorageEnable => 'فعال کردن';

  @override
  String virtStorageDisableAsk(String name) {
    return 'فضای ذخیره‌سازی $name غیرفعال شود؟ مهمان‌هایی که روی آن دیسک دارند تا زمان فعال‌سازی مجدد نمی‌توانند راه‌اندازی شوند.';
  }

  @override
  String get virtPoolLogicalNote =>
      'از گروه حجم موجود به همان شکل استفاده می‌شود؛ چیزی فرمت نخواهد شد.';

  @override
  String get virtPoolMountPoint => 'نقطه اتصال';

  @override
  String get virtPoolSourceNfs => 'منبع (host:/path)';

  @override
  String get virtPoolSourceVg => 'گروه حجم';

  @override
  String get virtPoolSourceThin => 'گروه حجم / استخر thin';

  @override
  String get virtPoolSourceZfs => 'استخر ZFS';

  @override
  String get virtPoolTypeVg => 'گروه حجم LVM';

  @override
  String get virtResNameEmpty => 'یک نام وارد کنید';

  @override
  String get virtResNotFound => 'دیگر روی این میزبان وجود ندارد';

  @override
  String get virtResUnsupported => 'این میزبان از این قابلیت پشتیبانی نمی‌کند';

  @override
  String get virtResNameInvalid =>
      'نامی نیست که این میزبان بپذیرد (حروف، ارقام، . _ -)';

  @override
  String get virtResSourceInvalid => 'مسیر یا منبعی نیست که این میزبان بپذیرد';

  @override
  String get virtResTargetInvalid => 'یک مسیر مطلق';

  @override
  String get virtResCidrInvalid =>
      'یک آدرس همراه با پیشوند آن، مانند 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid =>
      'دو آدرس در شبکه، به ترتیب، بدون آدرس خود میزبان';

  @override
  String get virtResSubnetTaken =>
      'شبکه دیگری در اینجا روی این زیرشبکه قرار دارد';

  @override
  String get virtResBridgeInvalid => 'نام یک رابط نیست';

  @override
  String get virtResFormat => 'فرمت مورد پذیرش این مخزن نیست';

  @override
  String get virtVolNew => 'حجم جدید';

  @override
  String virtVolCount(int count) {
    return '$count حجم';
  }

  @override
  String get virtVolNone => 'این مخزن هنوز هیچ حجمی ندارد.';

  @override
  String get virtVolEmptyAttach =>
      'یک حجم جدید می‌تواند بعداً به هر VM متصل شود';

  @override
  String get virtVolEmptyUpload =>
      'امکان بارگذاری مستقیم فایل ISO نیز وجود دارد';

  @override
  String get virtVolPveName =>
      'در PVE نام حجم بر اساس VM مشخص می‌شود: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => 'استفاده‌شده توسط';

  @override
  String get virtVolAllocated => 'تخصیص‌یافته';

  @override
  String get virtVolGrowFromGuest =>
      'یک مهمان از آن استفاده می‌کند: اندازه آن را از نمای سخت‌افزار همان مهمان افزایش دهید';

  @override
  String get virtVolInUse => 'یک مهمان از این حجم استفاده می‌کند';

  @override
  String virtVolBackingOf(String names) {
    return 'فایل پشتیبان $names';
  }

  @override
  String get virtVolIsBase =>
      'حجم‌های دیگر بر اساس این حجم ساخته شده‌اند؛ حذف آن باعث خرابی آن‌ها می‌شود';

  @override
  String get virtVolAttach => 'اتصال به VM';

  @override
  String get virtVolAttachNote =>
      'به‌عنوان یک دیسک جدید متصل می‌شود، روی همان گذرگاهی که دیسک اول آن قرار دارد';

  @override
  String virtVolAttached(String name) {
    return 'به $name متصل شد';
  }

  @override
  String get virtVolInsert => 'قرار دادن در CD-ROM';

  @override
  String virtVolInserted(String name) {
    return 'در درایو CD-ROM مربوط به $name قرار گرفت';
  }

  @override
  String virtVolNoCdrom(String name) {
    return 'مهمان $name درایو CD-ROM ندارد';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return 'آیا حجم $name از $pool حذف شود؟ محتویات آن برای همیشه از دست خواهد رفت.';
  }

  @override
  String get virtUploadIso => 'بارگذاری ISO';

  @override
  String virtUploadTo(String pool) {
    return 'بارگذاری در $pool';
  }

  @override
  String virtUploadDone(String name) {
    return 'فایل $name بارگذاری شد';
  }

  @override
  String get virtNetConfig => 'پیکربندی';

  @override
  String get virtNetConfigFile => 'فایل پیکربندی';

  @override
  String get virtNetInternal => 'داخلی';

  @override
  String get virtNetBridgePorts => 'پورت‌های پل';

  @override
  String get virtNetHostBridge => 'پل میزبان';

  @override
  String get virtNetPortsHint => 'مانند eno2؛ برای پل داخلی خالی بگذارید';

  @override
  String get virtNetDhcpRange => 'محدوده DHCP';

  @override
  String get virtNetDhcpTip =>
      'سرویس dnsmasq آدرس‌ها را به مهمان‌ها اختصاص می‌دهد';

  @override
  String get virtNetVlanTip =>
      'کارت‌های شبکه مهمان‌ها می‌توانند دارای تگ VLAN باشند';

  @override
  String get virtNetNatTip =>
      'از طریق میزبان: مهمان‌ها به بیرون دسترسی دارند، هیچ اتصالی از بیرون به داخل برقرار نمی‌شود';

  @override
  String get virtNetRoutedTip =>
      'مسیریابی توسط میزبان بدون NAT: شبکه محلی (LAN) به یک مسیر برگشت نیاز دارد';

  @override
  String get virtNetIsolatedTip =>
      'فقط مهمان‌ها و میزبان به یکدیگر دسترسی دارند';

  @override
  String get virtNetBridgedTip =>
      'مهمان‌ها به یکی از پل‌های میزبان در شبکه فیزیکی آن متصل می‌شوند';

  @override
  String get virtNetNew => 'شبکه جدید';

  @override
  String get virtNetNewBridge => 'پل لینوکسی جدید';

  @override
  String get virtNetVirtual => 'شبکه مجازی';

  @override
  String get virtNetDelete => 'حذف شبکه';

  @override
  String virtNetDeleteAsk(String name) {
    return 'آیا شبکه $name حذف شود؟ شبکه متوقف شده و تعاریف آن حذف خواهد شد.';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return 'آیا پل $name از $node حذف شود؟ اکنون از پیکربندی در انتظار خارج می‌شود و پس از اعمال، از میزبان حذف خواهد شد.';
  }

  @override
  String virtNetInUse(int count) {
    return 'مهمان‌های روی آن: $count. امکان حذف آن وجود ندارد.';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return 'آیا $name متوقف شود؟ ارتباط شبکه $count مهمان روی آن تا راه‌اندازی مجدد قطع خواهد شد.';
  }

  @override
  String get virtNetInactivePve =>
      'غیرفعال: یک پل جدید تا زمان اعمال، در پیکربندی در انتظار باقی می‌ماند.';

  @override
  String get virtNetPveApplyNote =>
      'به‌عنوان تغییر در انتظار ذخیره شد: پس از اعمال پیکربندی (ifreload -a) اعمال خواهد شد.';

  @override
  String get virtNetPendingSaved =>
      'به‌عنوان در انتظار ذخیره شد: برای اثرگذاری، پیکربندی را اعمال کنید';

  @override
  String virtNetPendingTitle(String node) {
    return 'تغییرات شبکه در انتظار در $node';
  }

  @override
  String get virtNetPendingTip =>
      'سیستم PVE تغییرات شبکه را تا زمان اعمال در interfaces.new نگه می‌دارد.';

  @override
  String get virtNetPendingShow => 'نمایش تغییرات';

  @override
  String get virtNetApply => 'اعمال پیکربندی';

  @override
  String virtNetApplyAsk(String node) {
    return 'آیا پیکربندی شبکه در انتظار روی $node اعمال شود؟ PVE شبکه میزبان را مجدداً بارگذاری می‌کند (ifreload -a): هرگونه اشتباه ممکن است دسترسی به میزبان را قطع کند.';
  }

  @override
  String virtNetRevertAsk(String node) {
    return 'آیا پیکربندی شبکه در انتظار روی $node لغو شود؟';
  }

  @override
  String get pveTokenTipStorage =>
      'مدیریت فضای ذخیره‌سازی نیازمند مجوز Datastore.Allocate در مسیر /storage (برای افزودن، غیرفعال کردن، حذف)، مجوز Datastore.AllocateSpace (برای حجم‌ها) و مجوز Datastore.AllocateTemplate (برای بارگذاری‌ها) است؛ پل‌های لینوکس و اعمال پیکربندی شبکه به Sys.Modify روی گره نیاز دارند.';

  @override
  String get virtCreateUnnamed => 'بدون نام';

  @override
  String get virtCreateNotChosen => 'انتخاب‌نشده';

  @override
  String get virtCreateKindVmSub => 'دستور qm · یک ماشین مجازی کامل KVM';

  @override
  String get virtCreateKindLxcSub =>
      'دستور pct · اشتراک‌گذاری هسته میزبان، سبک‌تر';

  @override
  String get virtCloudImage => 'ایمیج ابری';

  @override
  String get virtCloudImageTip =>
      'این یک ایمیج دیسک با سیستم‌عامل نصب‌شده است. هنگام ساخت ماشین مجازی، ابتدا از ایمیج کپی گرفته و اندازه آن به مقدار مشخص‌شده در بخش «ذخیره‌سازی» افزایش می‌یابد؛ cloud-init در اولین راه‌اندازی آن را پیکربندی می‌کند. ایمیج اصلی تغییر نمی‌کند.';

  @override
  String get virtNoCloudImagesLibvirt =>
      'ایمیج cloud قابل استفاده‌ای وجود ندارد. یک ایمیج qcow2 یا raw را در مخزن ذخیره‌سازی قرار دهید (می‌توانید آن را از بخش «ذخیره‌سازی» بارگذاری کنید) و مطمئن شوید هیچ ماشین مجازی از آن استفاده نمی‌کند.';

  @override
  String get virtNoCloudImagesPve =>
      'ایمیج cloud قابل استفاده‌ای وجود ندارد. یک ایمیج qcow2، raw یا vmdk را در فضای ذخیره‌سازی با نوع محتوای «Import» بارگذاری کنید (به PVE 8.2 یا جدیدتر نیاز است).';

  @override
  String get virtCreateWindowsTitle =>
      'سیستم‌عامل Windows 11 به UEFI و TPM 2.0 نیاز دارد';

  @override
  String get virtCreateWindowsBody =>
      'گزینه UEFI را انتخاب کرده و TPM را در بالا فعال کنید.';

  @override
  String get virtCreateWindowsNoTpm =>
      'این میزبان TPM نرم‌افزاری (swtpm) ندارد: برای ارائه آن به مهمان، باید آن را نصب کنید.';

  @override
  String virtCreateImageSize(String size) {
    return 'اندازه ایمیج $size است: دیسک باید حداقل به همان اندازه باشد.';
  }

  @override
  String get virtCreateImageMissing => 'یک ایمیج ابری انتخاب کنید.';

  @override
  String get virtCreateIncomplete =>
      'ابتدا همه بخش‌های علامت‌گذاری‌شده با رنگ نارنجی را تکمیل کنید.';

  @override
  String virtCreateOn(String host) {
    return 'ایجادشده در $host';
  }

  @override
  String get virtCiTip =>
      'یک حساب با دسترسی sudo ایجاد کنید که بتوان با گذرواژه، کلید SSH یا هر دو به آن وارد شد.';

  @override
  String get virtCiUserInvalid =>
      'حروف کوچک، ارقام، _ و -، که با یک حرف یا _ شروع می‌شود';

  @override
  String get virtCiCredentialsMissing =>
      'یک گذرواژه یا یک کلید SSH تعیین کنید.';

  @override
  String get virtCiHostnamePve => 'نام میزبان (hostname) همان نام VM است.';

  @override
  String get virtCiStatic => 'ایستا';

  @override
  String get virtCiAddressInvalid =>
      'یک آدرس IPv4 همراه با پیشوند آن، مانند 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'یک آدرس IPv4، مانند 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => 'خالی: دریافت از DHCP';

  @override
  String get virtCiDnsInvalid => 'آدرس‌های IP، جداشده با فاصله یا کاما';

  @override
  String get virtCiSearch => 'دامنه جستجو';

  @override
  String get virtCiSeedNote =>
      'تنظیمات در یک فایل ISO کوچک کنار دیسک نوشته می‌شوند، به‌عنوان CD-ROM متصل می‌شوند و با ماشین مجازی حذف خواهند شد. فقط هش گذرواژه ذخیره می‌شود.';

  @override
  String get virtCiNoToolTitle =>
      'هیچ ابزاری در میزبان برای ایجاد داده‌های cloud-init وجود ندارد';

  @override
  String virtCiNoToolBody(String tools) {
    return 'یکی از ابزارهای $tools را روی میزبان نصب کنید. بدون cloud-init، ایمیج بدون حسابی برای ورود راه‌اندازی می‌شود.';
  }

  @override
  String get virtHwCloudInitNote =>
      'اطلاعاتی که cloud-init در اولین بوت می‌خواند. این رسانه نصب نیست: چیزی برای قرار دادن در اینجا وجود ندارد.';

  @override
  String get virtHwCdromLater =>
      'در حین اجرا، درایو در شروع بعدی اضافه می‌شود (SATA و IDE به‌صورت زنده اضافه نمی‌شوند).';

  @override
  String virtCreateDiskKept(String size) {
    return 'دیسک در اندازه $size (اندازه خود ایمیج) نگه داشته شد که بیشتر از مقدار درخواستی است: دیسک هرگز به کمتر از حجم سیستم روی آن کاهش نمی‌یابد.';
  }

  @override
  String get virtCiEditTip =>
      'تنظیمات cloud-init این ماشین مجازی را پیکربندی کنید: حسابی با دسترسی sudo، روش ورود، نام میزبان و نشانی.';

  @override
  String get virtCiForeignTitle =>
      'این seed شامل تنظیماتی بیشتر از موارد نوشته‌شده توسط این برنامه است';

  @override
  String get virtCiForeignBody =>
      'تنظیماتی که ابزارهای دیگر نوشته‌اند (مانند بسته‌ها، دستورها و حساب‌های دیگر) اینجا نمایش داده نمی‌شوند. با ذخیره، seed با تنظیمات همین صفحه جایگزین می‌شود.';

  @override
  String get virtCiPasswordKept => 'تنظیم شده است. برای حفظ آن، خالی بگذارید';

  @override
  String get virtCiRemovePassword => 'حذف گذرواژه';

  @override
  String get virtCiRemovePasswordNote => 'ورود فقط با کلید SSH';

  @override
  String get virtCiKeysAdded =>
      'کلیدها به حساب اضافه می‌شوند. حذف کلید از اینجا آن را از سیستم پاک نمی‌کند و باید جداگانه از سیستم حذف شود. تغییر نام کاربری، حساب جدیدی ایجاد می‌کند و حساب قبلی را نگه می‌دارد.';

  @override
  String get virtCiEffectTitle => 'در بوت بعدی اعمال می‌شود';

  @override
  String get virtCiEffectLibvirt =>
      'ذخیره‌سازی یک seed جدید با شناسه نمونه (instance ID) جدید می‌نویسد.';

  @override
  String get virtCiEffectPve =>
      'PVE درایو cloud-init را بلافاصله بازنویسی می‌کند. شناسه نمونه از این تنظیمات ساخته می‌شود؛ بنابراین هر تغییری شناسه نمونه جدیدی ایجاد می‌کند.';

  @override
  String get virtCiNewInstance =>
      'در بوت بعدی، cloud-init با سیستم مانند یک نمونه جدید برخورد می‌کند: نام میزبان را مجدداً تنظیم می‌کند، در صورت عدم وجود حساب آن را می‌سازد، گذرواژه آن را تعیین می‌کند، کلیدها را اضافه می‌کند و پیکربندی شبکه را دوباره می‌نویسد. همچنین کلیدهای میزبان SSH جدیدی ایجاد می‌کند، بنابراین کلاینت‌های SSH هشدار می‌دهند که کلید میزبان تغییر کرده است. پیش از آن بوت هیچ تغییری رخ نمی‌دهد.';

  @override
  String get virtCiSaved => 'ذخیره شد. در بوت بعدی اعمال خواهد شد.';

  @override
  String get virtSnapshotExternal => 'فقط دیسک در حین اجرا';

  @override
  String get virtSnapshotExternalTip =>
      'ماشین مجازی به کار خود ادامه می‌دهد. برای هر دیسک، یک لایه پوششی qcow2 در مخزن انتخاب‌شده ساخته می‌شود و ماشین مجازی همچنان از این زنجیره snapshot استفاده می‌کند.';

  @override
  String get virtSnapshotFormInternal => 'داخلی (درون ایمیج)';

  @override
  String get virtSnapshotOverlayPool => 'مخزن لایه پوششی (Overlay)';

  @override
  String get virtSnapshotOverlayBeside => 'در کنار هر دیسک';

  @override
  String get virtSnapshotExternalNoMemory =>
      'یک اسنپ‌شات خارجی هرگز حافظه را نگه نمی‌دارد: مهمان متوقف نمی‌شود.';

  @override
  String get virtSnapshotChain => 'زنجیره دیسک';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count لایه';
  }

  @override
  String get virtSnapshotChainFile => 'فایل';

  @override
  String get virtSnapshotChainActive => 'اکنون در حال استفاده';

  @override
  String get virtSnapshotChainBase => 'ایمیج پایه';

  @override
  String get virtSnapshotNoSupport =>
      'فضای ذخیره‌سازی مهمان از اسنپ‌شات پشتیبانی نمی‌کند، بنابراین نمی‌توان اسنپ‌شاتی گرفت.';

  @override
  String get virtSnapshotRevertChain =>
      'بازگردانی یک snapshot در زنجیره، لایه فعال را با ایمیج ادغام می‌کند و snapshotهای پس از آن را غیرقابل استفاده می‌سازد. فقط می‌توان به جدیدترین snapshot بازگشت.';

  @override
  String get virtSnapshotRevertHasChildren =>
      'تا زمانی که اسنپ‌شات بعدی روی این مورد قرار دارد رد می‌شود.';

  @override
  String get virtSnapshotDiff => 'تفاوت‌ها با وضعیت کنونی';

  @override
  String get virtSnapshotDiffNone =>
      'پیکربندی از زمان این اسنپ‌شات تغییری نکرده است.';

  @override
  String get virtSnapshotDiffShow => 'مقایسه با وضعیت کنونی';

  @override
  String get virtSnapshotDiffGroupCpu => 'پردازنده';

  @override
  String get virtSnapshotDiffGroupMemory => 'حافظه';

  @override
  String get virtSnapshotDiffGroupDisks => 'دیسک‌ها';

  @override
  String get virtSnapshotDiffGroupNic => 'رابط‌ها';

  @override
  String get virtSnapshotDiffGroupFirmware => 'میان‌افزار';

  @override
  String get virtSnapshotDiffGroupBoot => 'بوت';

  @override
  String get virtSnapshotDiffGroupOther => 'سایر';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => 'حذف شد';

  @override
  String get virtSnapshotDiffAdded => 'اضافه شد';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return 'تغییرات در صورت بازگردانی به $snapshot:';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return 'میزبان نتوانست تفاوت‌ها را اعلام کند: $error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return 'مهمان در حال حاضر روی $count لایه قرار دارد؛ این اسنپ‌شات یک لایه دیگر اضافه می‌کند.';
  }

  @override
  String get virtToTemplate => 'تبدیل به الگو';

  @override
  String get virtToTemplateNote =>
      'یک الگو قابل راه‌اندازی نیست و نمی‌تواند دوباره به یک مهمان تبدیل شود. دیسک‌های آن به ایمیج‌های پایه تبدیل می‌شوند که یک کلون پیوندی (linked clone) آن را به اشتراک می‌گذارد.';

  @override
  String virtToTemplateConfirm(String name) {
    return 'آیا $name به الگو تبدیل شود؟';
  }

  @override
  String get virtToTemplateIrreversible =>
      'این عملیات غیرقابل بازگشت است: یک الگو نمی‌تواند دوباره به مهمان تبدیل شود.';

  @override
  String get virtToTemplateStopped => 'ابتدا آن را خاموش کنید.';

  @override
  String get virtToTemplateSnapshots =>
      'یک مهمان دارای اسنپ‌شات نمی‌تواند به الگو تبدیل شود.';

  @override
  String virtTemplateCreated(String name) {
    return 'مهمان $name اکنون یک الگو است';
  }

  @override
  String get virtTemplateTip => 'یک الگو تنها پس از کلون شدن اجرا می‌شود.';

  @override
  String get virtCloneStorageSame => 'همانند منبع';

  @override
  String get virtCloneNodeSame => 'همانند منبع';

  @override
  String get virtCloneStorageContent =>
      'این فضای ذخیره‌سازی حاوی ایمیج‌های VM نیست.';

  @override
  String get virtCloneStorageShared =>
      'کپی کردن به یک گره دیگر نیازمند فضای ذخیره‌سازی مشترک است.';

  @override
  String get virtCloneNodeUnknown => 'این میزبان چنین گرهی ندارد.';

  @override
  String get virtCloneLinkedTarget =>
      'یک کلون پیوندی دیسک‌های الگو را به اشتراک می‌گذارد، بنابراین نمی‌تواند فضای ذخیره‌سازی یا گره مشخصی تعیین کند.';

  @override
  String get virtBackupJobs => 'کارهای پشتیبان‌گیری';

  @override
  String get virtBackupJobsNone =>
      'هیچ کار پشتیبان‌گیری زمان‌بندی‌شده‌ای وجود ندارد. برای پشتیبان‌گیری از مهمان‌ها طبق زمان‌بندی، یکی اضافه کنید.';

  @override
  String get virtBackupJobNew => 'کار جدید';

  @override
  String get virtBackupJobRun => 'اجرا در همین لحظه';

  @override
  String get virtBackupJobRunAsk => 'آیا این کار پشتیبان‌گیری اکنون شروع شود؟';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return 'آیا کار پشتیبان‌گیری $id حذف شود؟ پشتیبان‌های ایجادشده توسط آن باقی می‌مانند.';
  }

  @override
  String get virtBackupJobSaved => 'کار ذخیره شد';

  @override
  String get virtBackupJobDeleted => 'کار حذف شد';

  @override
  String get virtBackupJobStarted => 'کار پشتیبان‌گیری شروع شد';

  @override
  String get virtBackupSchedule => 'زمان‌بندی';

  @override
  String get virtBackupScheduleHelp =>
      'زیرمجموعه‌ای از رویدادهای تقویم systemd: مانند 02:30، mon..fri 02:30، sat 03:00، daily، hourly، */15.';

  @override
  String get virtBackupScheduleInvalid => 'زمان‌بندی مورد پذیرش میزبان نیست.';

  @override
  String virtBackupScheduleNext(String times) {
    return 'اجراهای بعدی: $times';
  }

  @override
  String get virtBackupSelection => 'مهمان‌ها';

  @override
  String get virtBackupSelectionAll => 'همه مهمان‌ها';

  @override
  String get virtBackupSelectionList => 'مهمان‌های انتخاب‌شده';

  @override
  String get virtBackupSelectionNone => 'حداقل یک مهمان را انتخاب کنید.';

  @override
  String get virtBackupMail => 'اعلان';

  @override
  String get virtBackupNotesTemplate => 'یادداشت‌های پشتیبان';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return 'یادداشت‌ها به هر نسخه پشتیبان تهیه‌شده توسط این کار اضافه می‌شوند. این متغیرها با مقادیر خود جایگزین می‌شوند: $vars.';
  }

  @override
  String get virtBackupPrune => 'مدت نگهداری';

  @override
  String get virtBackupPruneTip =>
      'گزینه‌های نگهداری PVE، مانند keep-last=7,keep-daily=4. در صورت خالی بودن: از تنظیمات خود فضای ذخیره‌سازی یا گره استفاده می‌شود.';

  @override
  String get virtBackupJobNode => 'گره';

  @override
  String get virtBackupJobNodeAny => 'همه گره‌ها';

  @override
  String get virtBackupEnabled => 'فعال';

  @override
  String get virtBackupOptions => 'گزینه‌ها';

  @override
  String get virtBackupProtect => 'محافظت';

  @override
  String get virtBackupProtectTip =>
      'یک نسخه پشتیبان محافظت‌شده از پاک‌سازی دوره‌ای مصون می‌ماند و تا زمان حذف محافظت نمی‌توان آن را حذف کرد.';

  @override
  String get virtBackupEditNotes => 'یادداشت‌ها';

  @override
  String get virtBackupSaveNotes => 'ذخیره';

  @override
  String get virtBackupEdited => 'نسخه پشتیبان به‌روزرسانی شد';

  @override
  String get virtBackupRestoreStorage => 'بازیابی در فضای ذخیره‌سازی';

  @override
  String get virtBackupRestoreStorageSame => 'همانند نسخه پشتیبان';

  @override
  String get virtCloneStorageMissing =>
      'هیچ فضای ذخیره‌سازی در این گره حاوی ایمیج‌های VM نیست.';

  @override
  String get virtBackupCompress => 'فشرده‌سازی';

  @override
  String get virtBackupUnprotect => 'لغو محافظت';

  @override
  String get virtBackupModeStops =>
      'حالت‌های تعلیق (suspend) و توقف (stop) اجرای مهمان را در حین کپی شدن متوقف می‌کنند.';

  @override
  String get virtBackupScheduleValidate => 'بررسی با میزبان';

  @override
  String virtBackupSelected(int count) {
    return '$count مورد انتخاب شد';
  }

  @override
  String get virtBackupExcludeTip =>
      'همه مهمان‌های روی گره انتخاب می‌شوند. برای خارج کردن هر کدام، آن را خاموش کنید.';

  @override
  String virtNetEditAsk(int count) {
    return 'شبکه در حال اجرا تا زمان راه‌اندازی مجدد بدون تغییر می‌ماند. راه‌اندازی مجدد، اتصال $count ماشین مجازیِ متصل به آن را قطع می‌کند.';
  }

  @override
  String get virtNetEditAskNoGuest =>
      'شبکه در حال اجرا تا زمان راه‌اندازی مجدد بدون تغییر می‌ماند.';

  @override
  String get virtNetEditRestart => 'راه‌اندازی مجدد برای اعمال فوری';

  @override
  String get virtNetEditRestartNote =>
      'ارتباط شبکه مهمان‌های روی آن در حین راه‌اندازی مجدد قطع می‌شود.';

  @override
  String get virtNetEditPending =>
      'تعریف شبکه دارای تغییری است که هنوز روی شبکه در حال اجرا اعمال نشده است.';

  @override
  String get virtNetRestart => 'راه‌اندازی مجدد';

  @override
  String virtNetRestartAsk(String name, int count) {
    return 'آیا $name مجدداً راه‌اندازی شود؟ ارتباط شبکه $count مهمان روی آن تا زمان بازگشت قطع خواهد شد.';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return 'آیا $name مجدداً راه‌اندازی شود؟ هیچ موردی روی آن قرار ندارد.';
  }

  @override
  String get virtNetHosts => 'آدرس‌های ایستا';

  @override
  String get virtNetHostAdd => 'افزودن آدرس';

  @override
  String get virtNetHostMac => 'آدرس MAC';

  @override
  String get virtNetHostIp => 'آدرس';

  @override
  String get virtNetHostName => 'نام (اختیاری)';

  @override
  String get virtNetHostEmpty =>
      'هنوز برای هیچ MAC نشانی IP ثابتی تنظیم نشده است؛ همه ماشین‌های مجازی IP خود را از بازه DHCP می‌گیرند.';

  @override
  String get virtNetHostOthers =>
      'سایر مهمان‌ها آدرسی از محدوده DHCP دریافت می‌کنند.';

  @override
  String get virtNetHostInvalid =>
      'یک MAC، آدرس یا نامی که میزبان آن را رد می‌کند، یا یک MAC تکراری.';

  @override
  String get virtNetManagementIface =>
      'این رابط حامل آدرس خود میزبان است. ویرایش یا اعمال آن باعث قطع ارتباط میزبان خواهد شد.';

  @override
  String get virtNetManagementTip =>
      'این رابط، ترافیک مدیریتی میزبان را منتقل می‌کند یا زیرمجموعه رابطی است که این ترافیک را منتقل می‌کند؛ برنامه آن را تغییر نمی‌دهد.';

  @override
  String get virtNetPhysicalTip =>
      'یک رابط فیزیکی متعلق به خود میزبان است: برنامه فقط پل‌ها را ویرایش می‌کند.';

  @override
  String get virtNetVlanAware => 'پشتیبانی از VLAN';

  @override
  String get virtCiExpire => 'گذرواژه منقضی می‌شود';

  @override
  String get virtCiExpireNote =>
      'در اولین ورود با این گذرواژه باید یک گذرواژه جدید تنظیم شود. فقط برای libvirt: سیستم PVE عبارت «expire: false» را می‌نویسد و گزینه‌ای برای آن ندارد.';

  @override
  String get virtCiSearchHint => 'مثال: lab.example dev.lab.example';

  @override
  String get virtCiSearchTip =>
      'چندین مورد، جداشده با فاصله؛ فایل resolv.conf چند مورد اول را نگه می‌دارد.';

  @override
  String virtCiNicsTip(int count) {
    return '$count کارت شبکه (NIC) در پیکربندی شبکه seed؛ این فرم اولین مورد را ویرایش می‌کند.';
  }

  @override
  String get virtUsbByVendor => 'بر اساس سازنده و محصول';

  @override
  String get virtUsbByAddress => 'بر اساس آدرس';

  @override
  String get virtUsbAddressTip =>
      'دستگاه از این آدرس پیروی می‌کند: هر چیزی که به آن متصل شود در اختیار مهمان قرار می‌گیرد. در libvirt نام دستگاه USB میزبان با شماره گذرگاه (bus) و شماره دستگاه مشخص می‌شود.';

  @override
  String virtUsbPortNote(int bus, String port) {
    return 'گذرگاه $bus · پورت $port';
  }

  @override
  String get virtSbUnsupported =>
      'توصیف‌کننده‌های میان‌افزار میزبان، میان‌افزار Secure Boot دارای کلیدهای ثبت‌شده ندارند، بنابراین دامنه‌ای با این ویژگی نمی‌تواند راه‌اندازی شود.';

  @override
  String get virtCreateSecureBoot => 'بوت امن (Secure Boot)';

  @override
  String get virtCreateSecureBootNote =>
      'فقط کرنل‌ها و بوت‌لودرهای امضاشده بوت می‌شوند.';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return 'گذرگاه $bus · دستگاه $device';
  }

  @override
  String get virtHwRevertPendingTitle => 'صرف‌نظر کردن از تغییرات در انتظار';

  @override
  String virtHwRevertPendingBody(String name) {
    return 'تنظیمات $name به وضعیت در حال اجرا بازگردانده می‌شود: تعریف بر اساس مورد در حال اجرا بازنویسی می‌شود و شروع بعدی دقیقاً آنچه را این مورد دارد دریافت خواهد کرد. فایل NVRAM و میان‌افزار آن بدون تغییر باقی می‌مانند.';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return 'آیا تمام تغییرات در انتظار برای شروع بعدی $name لغو شوند؟';
  }

  @override
  String get virtBackupPlanNew => 'طرح جدید';

  @override
  String get virtBackupPlanNewTip =>
      'یک زمان‌بندی که فقط از این مهمان پشتیبان می‌گیرد.';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'همچنین از $count مهمان دیگر پشتیبان می‌گیرد',
      one: 'همچنین از ۱ مهمان دیگر پشتیبان می‌گیرد',
      zero: 'بدون مهمان دیگر',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => 'کاهش حرکت';

  @override
  String get copyLink => 'کپی لینک';

  @override
  String funcNeedsAgentPermission(String func) {
    return 'حساب شما در این Monitor مجوز $func را ندارد. با مدیر تماس بگیرید.';
  }

  @override
  String funcNeedsAgentHttps(String func) {
    return 'برای $func باید از طریق HTTPS به این Monitor وصل شوید یا HTTP هم در Monitor و هم در برنامه مجاز باشد.';
  }

  @override
  String funcNeedsAgentSetup(String func) {
    return '$func در این Monitor پیکربندی نشده است؛ مدیر آن باید این قابلیت را پیکربندی کند.';
  }

  @override
  String get monitorFilesReadOnly =>
      'فقط‌خواندنی: این حساب می‌تواند فایل‌های Monitor را مرور کند، اما نمی‌تواند آن‌ها را تغییر دهد.';

  @override
  String get monitorAccess => 'دسترسی';

  @override
  String get monitorAccounts => 'حساب‌ها';

  @override
  String get monitorRoles => 'نقش‌ها';

  @override
  String get monitorRole => 'نقش';

  @override
  String get monitorChangePassword => 'تغییر گذرواژه';

  @override
  String get monitorNewPassword => 'گذرواژه جدید';

  @override
  String get monitorCurrentPassword => 'گذرواژه فعلی شما';

  @override
  String get monitorReauthTip =>
      'تغییر سطح دسترسی نیازمند وارد کردن مجدد گذرواژه شما است.';

  @override
  String get monitorPasswordTooShort => 'حداقل ۸ کاراکتر';

  @override
  String get monitorPasswordMismatch => 'گذرواژه‌ها مطابقت ندارند';

  @override
  String get monitorErrReauth => 'گذرواژه شما اشتباه بود.';

  @override
  String get monitorErrLastAdmin => 'وجود دست‌کم یک حساب مدیر الزامی است.';

  @override
  String get monitorErrConflict =>
      'از قبل وجود دارد یا هنوز در حال استفاده است.';

  @override
  String get monitorErrForbidden =>
      'فقط یک مدیر می‌تواند این کار را انجام دهد.';

  @override
  String get monitorRoleNameRule => 'حروف کوچک، ارقام، - و _، تا ۳۲ کاراکتر';

  @override
  String get monitorGrantShell => 'شِل و دستورها';

  @override
  String get monitorGrantShellTip =>
      'ترمینال، فرایندها، سرویس‌ها، کانتینرها، قطعه‌کدها، خاموش/روشن — با حساب کاربری عامل';

  @override
  String get monitorGrantSshTerminal => 'ترمینال پنل از طریق SSH';

  @override
  String get monitorGrantVirt => 'مجازی‌سازی';

  @override
  String get monitorGrantVirtTip =>
      'دسترسی به Proxmox VE،‏ libvirt و BMCهایی که عامل در پنل وب به آن‌ها متصل می‌شود';

  @override
  String get monitorGrantFiles => 'فایل‌ها';

  @override
  String get monitorGrantConnect => 'اتصالات خروجی';

  @override
  String get monitorGrantConnectTip =>
      'هدایت پورت‌های محلی و پویا، دسکتاپ از راه دور';

  @override
  String get monitorGrantConnectAllow =>
      'مقصدهای مجاز (IP یا CIDR، اختیاری :port یا :from-to؛ در هر خط یک مورد، خالی یعنی همه‌جا)';

  @override
  String get monitorGrantListen => 'شنود روی سرور';

  @override
  String get monitorGrantListenTip => 'هدایت پورت‌های راه دور';

  @override
  String get monitorGrantListenPublic => 'نشانی‌های غیر لوپ‌بک';

  @override
  String get monitorGrantPorts => 'محدوده پورت (خالی یعنی هر پورتی)';

  @override
  String get monitorGrantOff => 'خاموش';

  @override
  String get monitorBuiltin => 'توکار';

  @override
  String get monitorAdminRoleTip => 'مدیریت حساب‌ها، نقش‌ها و تنظیمات عامل';

  @override
  String get monitorYou => 'شما';

  @override
  String get monitorNoAccessToSettings =>
      'تنها مدیر می‌تواند تنظیمات این عامل را تغییر دهد.';

  @override
  String get monitorPasswordNotSaved =>
      'گذرواژه در عامل تغییر کرد، اما برنامه نتوانست آن را ذخیره کند. گذرواژه Monitor این سرور را در تنظیمات آن به‌روزرسانی کنید.';

  @override
  String get firewall => 'فایروال';

  @override
  String get firewallLinuxOnly =>
      'مدیریت فایروال از سرورهای لینوکس با ufw یا firewalld پشتیبانی می‌کند.';

  @override
  String get firewallNeedsRoot =>
      'خواندن قوانین فایروال به دسترسی root نیاز دارد. برای ادامه، گذرواژه sudo را وارد کنید.';

  @override
  String get firewallIncoming => 'ورودی';

  @override
  String get firewallOutgoing => 'خروجی';

  @override
  String get firewallRouted => 'مسیریابی‌شده';

  @override
  String get firewallDefaultPolicy => 'سیاست پیش‌فرض';

  @override
  String get firewallLogging => 'ثبت گزارش';

  @override
  String get firewallRules => 'قوانین';

  @override
  String get firewallRule => 'قانون';

  @override
  String get firewallAddRule => 'افزودن قانون';

  @override
  String get firewallAnywhere => 'همه‌جا';

  @override
  String firewallFromFmt(String source) {
    return 'از $source';
  }

  @override
  String get firewallFrom => 'مبدأ';

  @override
  String get firewallTo => 'مقصد';

  @override
  String get firewallProtocol => 'پروتکل';

  @override
  String get firewallInterface => 'رابط';

  @override
  String get firewallComment => 'توضیح';

  @override
  String get firewallAppProfile => 'پروفایل برنامه';

  @override
  String get firewallPrepend => 'قرار دادن قبل از همه قوانین دیگر';

  @override
  String get firewallIpv6Off =>
      'قابلیت IPv6 خاموش است (IPV6=no): قوانین v6 بارگذاری نمی‌شوند.';

  @override
  String get firewallReload => 'بارگذاری مجدد';

  @override
  String get firewallNothingMatched =>
      'یک پورت، پروفایل برنامه، نشانی یا رابط شبکه را وارد کنید.';

  @override
  String get firewallInvalidPort =>
      'پورت نامعتبر است. از 22، 80,443 یا 6000:6010 استفاده کنید.';

  @override
  String get firewallTooManyPorts =>
      'حداکثر ۱۵ پورت؛ هر بازه دو پورت محسوب می‌شود.';

  @override
  String get firewallPortsNeedProtocol =>
      'فهرست یا بازه پورت‌ها به پروتکل tcp یا udp نیاز دارد.';

  @override
  String get firewallInvalidAddress =>
      'نشانی نامعتبر است. از یک آدرس IP یا شبکه‌ای مانند 192.168.1.0/24 استفاده کنید.';

  @override
  String get firewallMixedIpVersions =>
      '«مبدأ» و «مقصد» باید هر دو IPv4 یا هر دو IPv6 باشند.';

  @override
  String get firewallInvalidInterface => 'نام رابط نامعتبر است.';

  @override
  String get firewallInvalidComment =>
      'توضیح نمی‌تواند شامل \' یا خط جدید باشد.';

  @override
  String get firewallInvalidProtocol => 'پروتکل پشتیبانی نمی‌شود.';

  @override
  String get firewallInterfaceIn => 'رابط ورودی';

  @override
  String get firewallInterfaceOut => 'رابط خروجی';

  @override
  String get firewallSourcePort => 'پورت مبدأ';

  @override
  String get firewallMoreOptions => 'گزینه‌های بیشتر';

  @override
  String get firewallNoneInstalled =>
      'هیچ‌کدام از ufw یا firewalld روی این سرور نصب نیست. یکی از آن‌ها را با مدیر بسته سیستم نصب کنید؛ مانند `apt install ufw` یا `dnf install firewalld`.';

  @override
  String get firewallKeepAccess =>
      'ابتدا پورت‌های این برنامه باز نگه داشته شود';

  @override
  String firewallWillRefuseFmt(String access) {
    return '$access: اتصالات جدید از این برنامه رد خواهند شد. اتصال فعلی تا زمان قطع شدن فعال می‌ماند.';
  }

  @override
  String firewallMayRefuseFmt(String access) {
    return '$access: ممکن است اتصال‌های جدید به این برنامه رد شوند. این موضوع به IP مبدأ یا رابط شبکه‌ای که اتصال از آن وارد می‌شود بستگی دارد و برنامه نمی‌تواند از پیش آن را تشخیص دهد.';
  }

  @override
  String firewallRateLimitedFmt(String access) {
    return '$access: نرخ اتصالات محدود خواهد شد. اگر از یک نشانی ۶ اتصال یا بیشتر در ۳۰ ثانیه باز شود رد خواهد شد، و ممکن است این برنامه با همین فراوانی مجدداً متصل شود.';
  }

  @override
  String get firewallConflict =>
      'هر دو فایروال ufw و firewalld فعال هستند. هرکدام قوانین کرنل را بازنویسی می‌کند و هرکدام که در آخر بارگذاری شده باشد عبور ترافیک را تعیین می‌کند.';

  @override
  String get firewallDefaultZone => 'ناحیه پیش‌فرض';

  @override
  String get firewallZone => 'ناحیه';

  @override
  String get firewallTarget => 'هدف';

  @override
  String get firewallMasquerade => 'قابلیت Masquerade';

  @override
  String get firewallServices => 'سرویس‌ها';

  @override
  String get firewallPorts => 'پورت‌ها';

  @override
  String get firewallSources => 'مبدأها';

  @override
  String get firewallInterfaces => 'رابط‌ها';

  @override
  String get firewallRichRules => 'قوانین پیشرفته (Rich rules)';

  @override
  String get firewallForwardPorts => 'پورت‌های هدایت‌شده';

  @override
  String get firewallRuntimeOnly => 'فقط در زمان اجرا';

  @override
  String get firewallPermanentOnly => 'فقط دائمی';

  @override
  String get firewallThisConnection => 'همین اتصال';

  @override
  String get firewallDefaultTag => 'پیش‌فرض';

  @override
  String get firewallDrift =>
      'تنظیمات در حال اجرا با پیکربندی ذخیره‌شده تفاوت دارد. بارگذاری مجدد یا راه‌اندازی دوباره، آن را با پیکربندی ذخیره‌شده جایگزین می‌کند.';

  @override
  String firewallDriftLockoutFmt(String access) {
    return 'پس از بارگذاری مجدد یا راه‌اندازی دوباره، $access رد خواهد شد: پیکربندی ذخیره‌شده اجازه ورود به آن را نمی‌دهد.';
  }

  @override
  String get firewallSaveRuntime => 'ذخیره به‌صورت دائمی';

  @override
  String get firewallReloadLoses =>
      'تغییراتی که به‌صورت دائمی ذخیره نشده باشند از دست خواهند رفت.';

  @override
  String get firewallPanic =>
      'حالت اضطراری (Panic) فعال است: همه بسته‌ها دور ریخته می‌شوند.';

  @override
  String get firewallPanicOff => 'خاموش کردن حالت اضطراری (Panic)';

  @override
  String get firewallStoppedNote =>
      'سرویس firewalld متوقف است. تغییرات ذخیره می‌شوند و پس از شروع به کار اعمال خواهند شد.';

  @override
  String get firewallInvalidSource =>
      'مبدأ نامعتبر است. از یک نشانی، شبکه‌ای مانند 192.168.1.0/24، عبارت ipset:NAME یا یک آدرس MAC استفاده کنید.';

  @override
  String get firewallInvalidRichRule =>
      'یک قانون پیشرفته (rich rule) با «rule» شروع می‌شود و در یک خط قرار می‌گیرد.';

  @override
  String get firewallInvalidForwardPort =>
      'از ساختار port=80:proto=tcp:toport=8080 به‌همراه toport،‏ toaddr یا هر دو استفاده کنید.';

  @override
  String get monitorSyncNeedsServer =>
      'سروری را انتخاب کنید که عامل مانیتور آن نسخه پشتیبان را ذخیره می‌کند.';

  @override
  String get monitorBackupUnsupported =>
      'این عامل مانیتور نمی‌تواند نسخه‌های پشتیبان را ذخیره کند. عامل را به‌روزرسانی کنید.';

  @override
  String get monitorBackupAdminOnly =>
      'تنها یک حساب مدیر در عامل مانیتور می‌تواند نسخه‌های پشتیبان را روی آن ذخیره کند.';

  @override
  String monitorBackupTooLarge(String max) {
    return 'حجم نسخه پشتیبان بیشتر از حدی است که عامل مانیتور می‌پذیرد ($max).';
  }

  @override
  String get monitorBackupTooMany =>
      'عامل مانیتور در حال حاضر حداکثر تعداد مجاز نسخه پشتیبان را نگهداری می‌کند. ابتدا یکی را حذف کنید.';

  @override
  String get virtCreateVmidInvalid => 'شناسه VMID بین ۱۰۰ تا ۹۹۹۹۹۹۹۹۹.';

  @override
  String get virtCreateNodeOffline => 'آن گره آنلاین نیست.';

  @override
  String get virtCreateMediaMissing =>
      'آن رسانه نصب روی این میزبان وجود ندارد.';

  @override
  String get virtCreateNetworkMissing =>
      'یک مهمان جدید نمی‌تواند از آن شبکه استفاده کند.';

  @override
  String get virtCreateNotOffered =>
      'این میزبان چنین گزینه‌ای را برای یک VM جدید ارائه نمی‌دهد.';

  @override
  String get virtCreateSecureBootNeedsUefi =>
      'قابلیت Secure Boot به UEFI نیاز دارد.';

  @override
  String get virtGuestNotStopped => 'ابتدا آن را خاموش کنید.';

  @override
  String get virtGuestIsTemplate => 'این مورد از قبل یک الگو است.';

  @override
  String get virtCreateImageBigger =>
      'ایمیج بزرگ‌تر از دیسک است: اندازه دیسک را حداقل به همان اندازه انتخاب کنید.';

  @override
  String get virtBackupIssueStorage =>
      'آن فضای ذخیره‌سازی روی این گره نسخه‌های پشتیبان را نگه نمی‌دارد.';

  @override
  String get virtBackupIssueOption =>
      'حالتی یا فشرده‌سازی‌ای نیست که PVE بپذیرد.';

  @override
  String get virtBackupIssueNodeOffline => 'گره این کار آنلاین نیست.';

  @override
  String get programWaiting => 'در انتظار اقدام شما';

  @override
  String get programWaitingPermission => 'در انتظار تأیید شما';

  @override
  String get programWaitingQuestion => 'در انتظار پاسخ شما';

  @override
  String get programWaitingAuth => 'در انتظار ورود شما';

  @override
  String get programStatus => 'وضعیت برنامه';

  @override
  String get programIdle => 'بیکار';

  @override
  String get programThisShell => 'همین شِل';

  @override
  String get programProgress => 'پیشرفت';

  @override
  String get programCommandRunning => 'دستوری در حال اجرا است';

  @override
  String get programCommandSucceeded => 'آخرین دستور با موفقیت انجام شد';

  @override
  String programCommandFailed(int code) {
    return 'آخرین دستور با کد $code پایان یافت';
  }

  @override
  String get programStatusAlerts => 'اعلان هنگام نیاز برنامه به شما';

  @override
  String get programStatusAlertsTip =>
      'برای ترمینالی که خارج از دید است: برنامه‌ای که منتظر شماست، پایان یافته یا ناموفق بوده است (طبق گزارش خودش، OSC 7501, OSC 9;4)، یا پایان دستوری که ۳۰ ثانیه یا بیشتر اجرا شده است (OSC 133).';

  @override
  String get termLineHeight => 'ارتفاع خط';

  @override
  String get termLineHeightTip =>
      'فضایی که یک سطر ترمینال اشغال می‌کند، به‌صورت مضربی از اندازه فونت، از ۱.۰ تا ۲.۰. مانند اندازه فونت، تعداد سطرهایی را که جا می‌شوند تغییر می‌دهد.';

  @override
  String get termFontTip =>
      'بدون فایل فونت، ترمینال از فونت monospace سیستم و سپس برای موارد ناموجود از فونت‌های دارای نویسه‌های CJK و ایموجی استفاده می‌کند.';

  @override
  String get netSpeed => 'سرعت شبکه';

  @override
  String get inRange => 'در محدوده';

  @override
  String threadsFmt(int count) {
    return '$count رشته';
  }

  @override
  String get workspace => 'فضای کاری';

  @override
  String get workspaceTroubleshoot => 'عیب‌یابی';

  @override
  String workspaceNotConnected(String server) {
    return '$server متصل نیست';
  }

  @override
  String get workspaceConnectHint =>
      'این سرور به‌گونه‌ای تنظیم شده است که هنگام راه‌اندازی متصل نشود.';

  @override
  String workspaceAllTabs(int count) {
    return 'همه زبانه‌ها ($count)';
  }

  @override
  String get workspaceAsleep => 'متصل نیست';

  @override
  String workspaceClosed(String what) {
    return '$what بسته شد';
  }

  @override
  String get workspaceClosePane => 'بستن قاب';

  @override
  String get workspaceClosePaneHint =>
      'همه زبانه‌های داخل آن را می‌بندد؛ قابل بازگردانی است';

  @override
  String get workspaceDropLeft => 'چپ';

  @override
  String get workspaceDropRight => 'راست';

  @override
  String get workspaceDropTop => 'بالا';

  @override
  String get workspaceDropBottom => 'پایین';

  @override
  String get workspaceDropMerge => 'پیوستن به این قاب';

  @override
  String get workspaceEmpty => 'فضای کاری خالی';

  @override
  String get workspaceEmptyTemplate =>
      'یک فضای کاری خالی طرح‌بندی‌ای برای ذخیره کردن ندارد';

  @override
  String workspaceFromTemplate(String template, String server) {
    return 'فضای کاری جدید از «$template» در $server';
  }

  @override
  String get workspaceHidden => 'پنهان';

  @override
  String get workspaceMaximize => 'بزرگ‌نمایی';

  @override
  String workspaceMaximized(int pane, int hidden) {
    return 'قاب $pane بزرگ شده، $hidden پنهان است';
  }

  @override
  String workspaceMaximizeHint(String keys) {
    return '$keys، یا دو بار کلیک روی نوار زبانه';
  }

  @override
  String get workspaceNewEmpty => 'فضای کاری خالی جدید';

  @override
  String get workspaceNewPane => 'قاب جدید';

  @override
  String get workspaceNewTab => 'زبانه جدید';

  @override
  String get workspaceNewTabFocused => 'زبانه جدید · در قاب فوکوس‌شده';

  @override
  String get workspaceNoMatch => 'موردی یافت نشد';

  @override
  String get workspaceNothingToReopen => 'چیزی برای بازگشایی مجدد وجود ندارد';

  @override
  String workspacePane(int index) {
    return 'قاب $index';
  }

  @override
  String get workspacePaneActions => 'عملیات قاب';

  @override
  String workspacePaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قاب',
      one: '1 قاب',
    );
    return '$_temp0';
  }

  @override
  String get workspacePanes => 'قاب‌ها';

  @override
  String workspacePanesHead(String workspace) {
    return '$workspace · دو قاب نشان داده شده‌اند؛ با ضربه روی هر قاب فوکوس می‌شود';
  }

  @override
  String workspacePaneTabs(int index) {
    return 'زبانه‌های قاب $index';
  }

  @override
  String workspacePickView(String server) {
    return 'زبانه جدید در $server · یک نما انتخاب کنید';
  }

  @override
  String get workspaceQuickOpen => 'باز کردن سریع';

  @override
  String get workspaceQuickOpenHead =>
      'باز کردن سریع · با Enter اولین مورد باز می‌شود';

  @override
  String get workspaceQuickOpenHint =>
      'سرورها، نماها، زبانه‌ها یا فضاهای کاری، مثلاً db docker';

  @override
  String get workspaceRestore => 'بازگردانی';

  @override
  String get workspaceSaveTemplate => 'ذخیره طرح‌بندی به‌عنوان الگو';

  @override
  String get workspaceSeamTip =>
      'برای تغییر اندازه بکشید، برای هم‌اندازه شدن دو بار کلیک کنید';

  @override
  String get workspaceSplitDown => 'تقسیم به پایین';

  @override
  String get workspaceSplitRight => 'تقسیم به راست';

  @override
  String get workspaceSwitchTo => 'جابه‌جایی به';

  @override
  String get workspaceSwitchWorkspace => 'تغییر فضای کاری';

  @override
  String workspaceSyncBar(int count) {
    return 'همگام‌سازی ورودی: متن تایپ‌شده به $count ترمینال این فضای کاری ارسال می‌شود';
  }

  @override
  String get workspaceSyncOff => 'توقف همگام‌سازی ورودی';

  @override
  String get workspaceSyncOn => 'همگام‌سازی ورودی به همه ترمینال‌ها';

  @override
  String get workspaceSyncOnToast =>
      'همگام‌سازی ورودی روشن است: تایپ در هر ترمینال به همه ترمینال‌های این فضای کاری فرستاده می‌شود';

  @override
  String get workspaceSyncOffToast => 'همگام‌سازی ورودی خاموش است';

  @override
  String workspaceTemplateOf(String workspace) {
    return 'طرح‌بندی $workspace';
  }

  @override
  String workspaceTemplateSaved(String name) {
    return 'الگوی «$name» ذخیره شد';
  }

  @override
  String get workspaceTemplatesHead =>
      'الگوهای طرح‌بندی · فضای کاری جدید روی سرور قاب فوکوس‌شده';

  @override
  String get workspaceMoveTo => 'انتقال به فضای کاری، بدون قطع اتصال';

  @override
  String workspaceMoved(String server, String workspace) {
    return 'ترمینال $server به «$workspace» منتقل شد، همچنان متصل است';
  }

  @override
  String get workspaceNew => 'فضای کاری جدید';

  @override
  String get workspaceIntoFocused => 'به داخل قاب فوکوس‌شده';

  @override
  String get keybindings => 'میانبرهای صفحه‌کلید';

  @override
  String get kbSearchHint => 'جستجوی دستورها، کلیدها یا دامنه‌ها';

  @override
  String get kbOnlyModified => 'فقط تغییریافته‌ها';

  @override
  String get kbResetAll => 'بازنشانی همه به حالت پیش‌فرض';

  @override
  String get kbResetAllAsk =>
      'تمام میانبرهای این پلتفرم به حالت پیش‌فرض بازنشانی شوند؟';

  @override
  String get kbResetDone => 'میانبرهای پیش‌فرض بازگردانده شدند';

  @override
  String get kbResetOne => 'بازنشانی به حالت پیش‌فرض';

  @override
  String get kbUnassigned => 'اختصاص نیافته';

  @override
  String get kbFixed => 'ثابت';

  @override
  String get kbModified => 'تغییریافته';

  @override
  String get kbDefault => 'پیش‌فرض';

  @override
  String get kbFixedHint => 'این کلیدها قابل تغییر نیستند';

  @override
  String get kbNote =>
      'میانبرهای فضای کاری تنها درون یک فضای کاری عمل می‌کنند. میانبرهای سراسری، مانند باز کردن «تنظیمات»، در تمام صفحه‌ها کار می‌کنند. در سایر صفحه‌های ترمینال، میانبرهای مربوط به فضای کاری، «تنظیمات» یا زبانه‌های سرور به شِل ارسال می‌شوند زیرا این قابلیت‌ها در آنجا در دسترس نیستند. کپی، چسباندن و انتخاب همه جزو کنترل‌های ترمینال هستند و نه میانبرهای قابل تنظیم.';

  @override
  String kbCurrent(String keys, String scope) {
    return 'فعلی: $keys · دامنه: $scope';
  }

  @override
  String get kbPress => 'یک ترکیب کلید را فشار دهید';

  @override
  String get kbRecordHint =>
      'برای تأیید Enter و برای لغو Esc را بزنید. در صورت خارج شدن فوکوس، روی کادر بالا ضربه بزنید و دوباره فشار دهید.';

  @override
  String kbConflict(String name, String scope) {
    return 'تداخل با «$name» ($scope)';
  }

  @override
  String get kbConflictNote =>
      'تأیید کردن، این ترکیب کلید را از دستور متداخل حذف می‌کند.';

  @override
  String get kbRemove => 'حذف میانبر';

  @override
  String kbChanged(String name, String keys) {
    return '«$name» اکنون $keys است';
  }

  @override
  String get kbScopeGlobal => 'سراسری';

  @override
  String get kbScopeSettings => 'صفحه تنظیمات';

  @override
  String get kbScopeServerTab => 'زبانه سرور';

  @override
  String get kbWsSplitRight => 'فضای کاری: تقسیم به راست';

  @override
  String get kbWsSplitDown => 'فضای کاری: تقسیم به پایین';

  @override
  String get kbWsFocusLeft => 'فضای کاری: فوکوس روی قاب سمت چپ';

  @override
  String get kbWsFocusRight => 'فضای کاری: فوکوس روی قاب سمت راست';

  @override
  String get kbWsFocusUp => 'فضای کاری: فوکوس روی قاب بالایی';

  @override
  String get kbWsFocusDown => 'فضای کاری: فوکوس روی قاب پایینی';

  @override
  String get kbWsNewTab => 'فضای کاری: زبانه جدید';

  @override
  String get kbWsCloseTab => 'فضای کاری: بستن زبانه';

  @override
  String get kbWsNextTab => 'فضای کاری: زبانه بعدی';

  @override
  String get kbWsPrevTab => 'فضای کاری: زبانه قبلی';

  @override
  String get kbWsTabs => 'فضای کاری: زبانه‌های قاب فوکوس‌شده';

  @override
  String get kbWsReopenTab => 'فضای کاری: بازگشایی مجدد زبانه بسته شده';

  @override
  String get kbWsMaximize => 'فضای کاری: بزرگ‌نمایی یا بازگردانی قاب';

  @override
  String get kbWsSync => 'فضای کاری: همگام‌سازی ورودی به همه ترمینال‌ها';

  @override
  String get kbWsQuickOpen => 'فضای کاری: باز کردن سریع';

  @override
  String get kbWsSwitcher => 'فضای کاری: تغییر فضای کاری';

  @override
  String get kbHomeTab => 'خانه: رفتن به زبانه ۱ تا ۹';

  @override
  String get kbAppSettings => 'باز کردن تنظیمات';

  @override
  String get kbSettingsSearch => 'تنظیمات: جستجو';

  @override
  String get kbServerPrev => 'سرورها: سرور قبلی';

  @override
  String get kbServerNext => 'سرورها: سرور بعدی';

  @override
  String get kbServerList => 'سرورها: فهرست سرورها';

  @override
  String get kbServerClose => 'سرورها: بستن جزئیات';

  @override
  String get termMetricsBar => 'اطلاعات وضعیت سرور زیر ترمینال';

  @override
  String get termMetricsBarTip =>
      'مصرف CPU، حافظه، شبکه و دیسک، همان‌طور که در کارت سرور نمایش داده می‌شود. در گوشی بالای کلیدهای مجازی قرار می‌گیرد.';

  @override
  String get launchFailedTitle => 'برنامه ServerBox نتوانست راه‌اندازی شود';

  @override
  String get launchFailedBody =>
      'خطای زیر را کپی کرده و به همراه فایل‌های لاگ، در یک issue در GitHub گزارش دهید.';

  @override
  String launchFailedLogs(String path) {
    return 'لاگ‌ها: $path';
  }

  @override
  String get reconnect => 'اتصال مجدد';

  @override
  String get reconnectEndsShell =>
      'هیچ نشست tmuxای برای اتصال مجدد وجود ندارد؛ بنابراین اتصال مجدد باعث پایان یافتن این شِل و هر آنچه هنوز در آن در حال اجراست می‌شود و خروجی آن را از صفحه پاک می‌کند.';

  @override
  String get storeUnreadableTitle => 'داده‌های قبلی باز نشدند';

  @override
  String get storeUnreadableKeyLost =>
      'کلید رمزگذاری داده‌های ServerBox دیگر در keystore سیستم موجود نیست. این اتفاق زمانی رخ می‌دهد که سیستم keystore را بازنشانی کند، سرویس keyring در دسترس نباشد، یا داده‌های برنامه از دستگاه دیگری (مثلاً با ابزار انتقال داده‌های گوشی) کپی شده باشد. بدون آن کلید نمی‌توان داده‌ها را رمزگشایی کرد، بنابراین ServerBox بدون هیچ داده‌ای راه‌اندازی شد.';

  @override
  String get storeUnreadableKeyRejected =>
      'کلید موجود در keystore سیستم، داده‌های ServerBox را باز نمی‌کند: داده‌ها با کلید دیگری رمزگذاری شده‌اند، یا فایل آسیب دیده است. ServerBox بدون هیچ داده‌ای راه‌اندازی شد.';

  @override
  String storeUnreadableKept(String path) {
    return 'فایل قدیمی در این مسیر نگهداری می‌شود:\n$path\nبرای بازگرداندن سرورهای خود، یک نسخه پشتیبان را بازیابی کنید.';
  }

  @override
  String get storeKeyLostAsk =>
      'کلید رمزگذاری داده‌های ServerBox در keystore سیستم وجود ندارد. اگر keystore یا keyring موقتاً در دسترس نیست (برای مثال هنوز قفل آن باز نشده است)، دوباره امتحان کنید. در غیر این صورت ServerBox می‌تواند بدون داده راه‌اندازی شود؛ فایل قدیمی حفظ خواهد شد.';

  @override
  String get storeKeyLostStartEmpty => 'شروع بدون داده';

  @override
  String get storeVaultFailedAsk =>
      'سامانه keystore نتوانست کلید رمزگذاری داده‌های ServerBox را رمزگشایی کند. اگر خطای keystore تنها همین یک‌بار رخ داده است، دوباره امتحان کنید (در صورت نیاز پس از راه‌اندازی مجدد دستگاه). اگر هربار ناموفق است، داده‌ها قابل رمزگشایی نیستند و ServerBox می‌تواند بدون داده راه‌اندازی شود؛ فایل قدیمی نگهداری می‌شود. شروع بدون داده همچنین گذرواژه پشتیبان‌گیری، اطلاعات ورود WebDAV و GitHub و گذرواژه‌های ذخیره‌شده sudo را پاک می‌کند.';

  @override
  String get storeVaultFailedRootHint =>
      'در دستگاه‌های روت‌شده، ماژولی که مانع کار keystore می‌شود (مانند TrickyStore) دلیل این موضوع است. این برنامه را از فهرست اهداف آن ماژول حذف کرده و سپس بدون داده شروع کنید.';

  @override
  String get storeUnreadableVaultFailed =>
      'سامانه keystore نتوانست کلید رمزگذاری داده‌های ServerBox را رمزگشایی کند، بنابراین ServerBox موارد موجود در keystore را بازنشانی کرد و بدون داده شروع به کار نمود. گذرواژه پشتیبان‌گیری، اطلاعات احراز هویت WebDAV و GitHub و گذرواژه‌های ذخیره‌شده sudo باید دوباره وارد شوند.';

  @override
  String get hostCertAuthorities => 'مراجع گواهی میزبان';

  @override
  String get hostCertAuthoritiesTip =>
      'میزبانی که گواهی آن توسط یکی از این مراجع امضا شده باشد، بدون پرسش قابل اعتماد دانسته می‌شود (مانند دستور @cert-authority در OpenSSH)؛ درباره سایر میزبان‌ها مانند گذشته در اولین اتصال سؤال خواهد شد. میزبان‌ها الگوهایی جداشده با کاما شامل * و ? هستند و با ! استثنا می‌شوند؛ پورت‌های غیر از 22 با ساختار [host]:port تطبیق داده می‌شوند.';

  @override
  String get hostCertAuthorityInvalid =>
      'کلید عمومی پشتیبانی‌شده SSH نیست (ssh-ed25519،‏ ssh-rsa یا ecdsa-sha2-*)';

  @override
  String get hostCertAuthorityNoHosts =>
      'میزبان‌هایی را که این مرجع تأیید می‌کند وارد کنید، مثلاً *';

  @override
  String get hostCertAuthorityExists => 'از قبل در فهرست موجود است';

  @override
  String get addToHomeScreen => 'افزودن به صفحه اصلی';

  @override
  String transfersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count انتقال',
      one: '1 انتقال',
    );
    return '$_temp0';
  }
}
