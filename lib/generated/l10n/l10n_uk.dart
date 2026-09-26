// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appearanceSettings => 'Вигляд';

  @override
  String get appearancePreset => 'Готова тема';

  @override
  String get appearanceThemeSchemaRange => 'Підтримувана схема теми';

  @override
  String get appearanceThemeInstall => 'Установити тему';

  @override
  String get appearanceThemeStore => 'Магазин тем';

  @override
  String get appearanceInvalidTheme => 'Недійсний пакет теми або каталог';

  @override
  String get themeStoreRefreshFailed => 'Не вдалося прочитати каталог тем.';

  @override
  String themeStoreDeleteTheme(String name) {
    return 'Видалити «$name»? Його файли буде видалено з цього пристрою. Якщо це тема, що використовується, застосунок повернеться до типової теми.';
  }

  @override
  String themeStoreUpdatedFmt(String ago) {
    return 'оновлено $ago';
  }

  @override
  String get themeStoreUpdatedJustNow => 'щойно оновлено';

  @override
  String get themeStoreSortInUse => 'Спочатку використовувана';

  @override
  String themeStoreMakeOwnFmt(String doc) {
    return 'Хочете створити власну тему? Дивіться [як її створити]($doc) — дякуємо за ваш внесок!';
  }

  @override
  String appearanceThemeNeedsNewerApp(String version) {
    return 'Потрібна новіша версія застосунку: $version';
  }

  @override
  String get appearanceFontFamilies => 'Сімейства шрифтів інтерфейсу';

  @override
  String get appearanceFontFamiliesTip =>
      'Одна назва в рядку; шрифти застосовуються за порядком.';

  @override
  String get appearanceFontImport => 'Імпортувати файл шрифту інтерфейсу';

  @override
  String get appearanceGradient => 'Градієнт';

  @override
  String get appearanceNoBackground => 'Без тла';

  @override
  String get appearanceIcons => 'Піктограми в застосунку';

  @override
  String get appearanceCorners => 'Кути';

  @override
  String get appearanceCardCorners => 'Кути карток';

  @override
  String get appearanceTileCorners => 'Кути плиток';

  @override
  String get appearanceButtonCorners => 'Кути кнопок';

  @override
  String get crashCollect => 'Діагностичні дані';

  @override
  String get crashCollectIntro =>
      'ServerBox записує те, що відбувається під час роботи, щоб можна було виправляти проблеми. Виберіть, скільки даних надсилати.';

  @override
  String get crashCollectNone => 'Нічого';

  @override
  String get crashCollectNoneTip =>
      'Звіти залишаються на цьому пристрої; після збою ви можете надіслати один вручну.';

  @override
  String get crashCollectBasic => 'Основні дані';

  @override
  String get crashCollectBasicTip =>
      'Містить лише відомості про збій; журнали й дані про продуктивність не включаються. **Це допомагає нам покращувати застосунок і виправляти помилки.**';

  @override
  String get crashCollectFull => 'Повні дані';

  @override
  String get crashCollectFullTip =>
      'Окрім журналу збою, містить дані про продуктивність і відомості про те, які функції використовуються: вони допомагають знайти, що працює повільно та які функції справді потрібні.';

  @override
  String get crashCollectFooter =>
      'На всіх рівнях відомі імена серверів, адреси та імена користувачів замінюються заповнювачами вже під час запису. Пізніше рівень збору можна змінити в налаштуваннях.';

  @override
  String get privacy => 'Конфіденційність';

  @override
  String get privacyPolicy => 'Політика конфіденційності';

  @override
  String get crashLastRunFailed =>
      'ServerBox несподівано завершив роботу під час останнього запуску.';

  @override
  String get crashReportTitle => 'Звіт про збій';

  @override
  String get crashReportHint =>
      'Це журнал попереднього запуску. Відомі імена та адреси серверів замінено заповнювачами, але інші дані можуть залишитися. Уважно прочитайте звіт перед надсиланням.';

  @override
  String get crashReportSubmit => 'Копіювати та повідомити';

  @override
  String get preReleaseUpdates => 'Отримувати оновлення попередніх версій';

  @override
  String get addSystemPrivateKeyTip =>
      'Наразі приватних ключів нема, хочете додати той, що йде з системою (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Додано до списку завдань';

  @override
  String get askAi => 'Запитати ШІ';

  @override
  String get askAiAwaitingResponse => 'Очікування відповіді ШІ...';

  @override
  String get askAiEndpointTip =>
      'Домен або повний URL. Шлях доповнюється за обраним протоколом.';

  @override
  String get askAiProtocolTip =>
      'Авто пробує Responses, потім Chat Completions.';

  @override
  String get askAiCommandInserted => 'Команду вставлено в термінал';

  @override
  String askAiConfigMissing(String fields) {
    return 'Налаштуйте $fields у налаштуваннях.';
  }

  @override
  String get askAiDisclaimer => 'ШІ може помилятися. Користуйтеся обережно.';

  @override
  String get askAiInsertTerminal => 'Вставити в термінал';

  @override
  String get askAiNoResponse => 'Відповідь відсутня';

  @override
  String get remoteDesktop => 'Віддалений робочий стіл';

  @override
  String get askAiAgentWelcome => 'Що зробимо на цьому сервері?';

  @override
  String get askAiAgentPromptHint =>
      'Попросіть агента щось перевірити або виправити…';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Проаналізуй виділений вивід термінала й поясни, що сталося';

  @override
  String get askAiTerminalContext => 'Контекст термінала';

  @override
  String get askAiReviewNeeded => 'Перевірити';

  @override
  String get askAiReviewAction => 'Перевірити запропоновану команду';

  @override
  String get askAiReviewBeforeContinuing =>
      'Спершу перевірте або відхиліть поточну пропозицію';

  @override
  String get askAiApproveRun => 'Схвалити й виконати';

  @override
  String get askAiDecline => 'Відхилити';

  @override
  String get askAiActionDeclined => 'Запропоновану команду відхилено.';

  @override
  String get askAiInterrupted => 'Відповідь агента перервано.';

  @override
  String get askAiResend => 'Resend';

  @override
  String get askAiResendTip =>
      'Усе після цього повідомлення буде видалено — відповіді, команди та їхні результати.';

  @override
  String get askAiDeleteTip =>
      'Це повідомлення й усе після нього буде видалено — відповіді, команди та їхні результати.';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'Розміри контексту для різних моделей узято з models.dev. Одна таблиця вже вбудована в застосунок; натисніть, щоб завантажити новішу.';

  @override
  String get askAiContextFallback => 'немає в таблиці';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      'Наскільки має заповнитися контекст моделі, перш ніж попередні повідомлення буде підсумовано. За раннього стискання деталі втрачаються швидше, а за пізнього модель може відхилити запит.';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'Скільки токенів уміщує контекст цієї моделі. В автоматичному режимі розмір визначається за назвою; укажіть число, якщо провайдер надає менше вікно, ніж підтримує модель.';

  @override
  String get askAiConversationCompacted =>
      'Попередні повідомлення було підсумовано, щоб продовжити розмову.';

  @override
  String get askAiRiskReadOnly => 'Лише читання';

  @override
  String get askAiRiskCaution => 'Змінює систему';

  @override
  String get askAiRiskUnvetted => 'Неперевірений хост';

  @override
  String get askAiRiskDestructive => 'Високий ризик';

  @override
  String get askAiHighRiskConfirmTitle => 'Виконати команду з високим ризиком?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Команда може внести зміни, які важко скасувати. Перевірте уважно.';

  @override
  String get askAiNoCommandOutput => 'Команда завершилася без виводу.';

  @override
  String get askAiOutputTruncated =>
      'Довгий вивід обрізано перед поверненням агентові.';

  @override
  String get askAiAutoApproved => 'Схвалено автоматично';

  @override
  String get askAiAutoRunSafeCommands =>
      'Автоматично виконувати команди лише для читання';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Виконується, лише коли і модель, і локальна перевірка вважають команду лише для читання';

  @override
  String get askAiSendOnEnter => 'Enter надсилає';

  @override
  String get askAiSendOnEnterTip =>
      'Enter надсилає, Shift+Enter — новий рядок. Вимк.: Enter — новий рядок, Cmd/Ctrl+Enter надсилає.';

  @override
  String get askAiApiKeyOptional =>
      'Залиште порожнім для локального або без автентифікації';

  @override
  String get askAiAllowInsecure => 'Дозволити незашифрований HTTP';

  @override
  String get askAiAllowInsecureTip =>
      'Дозволяє підключення через http:// до самостійно розміщених моделей за адресами, відмінними від localhost. Ключ API та будь-який контекст термінала буде надіслано без шифрування; localhost це не стосується.';

  @override
  String get askAiInsecureEndpoint =>
      'Ця кінцева точка використовує http://. Увімкніть «Дозволити незашифрований HTTP» у налаштуваннях AI, щоб використовувати її.';

  @override
  String get askAiHistory => 'Історія розмов';

  @override
  String get askAiNewConversation => 'Нова розмова';

  @override
  String get askAiNoHistory => 'Збережених розмов ще немає';

  @override
  String get askAiNoHistoryMessages => 'Повідомлень ще немає';

  @override
  String get askAiUntitledConversation => 'Без назви';

  @override
  String get askAiRenameConversation => 'Перейменувати розмову';

  @override
  String get askAiDeleteConversationTitle => 'Видалити цю розмову?';

  @override
  String get askAiDeleteConversationTip =>
      'Видаляє її з цього пристрою. Скасувати не можна.';

  @override
  String get askAiClearHistoryTitle =>
      'Очистити історію агента для цього сервера?';

  @override
  String get askAiClearHistoryTip =>
      'Усі збережені розмови агента для цього сервера буде видалено.';

  @override
  String get askAiRestoredReview => 'Команда з історії. Перевірте її ще раз';

  @override
  String get agentWelcome => 'Що зробимо на ваших серверах?';

  @override
  String get agentWelcomeTip =>
      'Хай агент з’ясує проблему або виконає завдання';

  @override
  String get agentPromptHint =>
      'Попросіть агента перевірити сервери або виконати на них дію…';

  @override
  String get agentNoHistory => 'Немає збережених глобальних розмов агента';

  @override
  String get agentClearHistoryTitle => 'Очистити глобальну історію агента?';

  @override
  String get agentClearHistoryTip =>
      'Усі глобальні розмови агента буде видалено з цього пристрою.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Читання файлу';

  @override
  String get agentToolWriteFile => 'Запис файлу';

  @override
  String get agentToolFailed => 'Не вдалося виконати інструмент.';

  @override
  String agentToolCallsFmt(int count) {
    return 'Викликів інструментів: $count';
  }

  @override
  String get floatOverTabs => 'Поверх інших вкладок';

  @override
  String get agentToolSshConnect => 'Підключення по SSH';

  @override
  String get agentToolSshDisconnect => 'Відключити SSH';

  @override
  String get agentSshConnectTitle => 'Підключення до нового хоста';

  @override
  String get agentAuthMethod => 'Автентифікація';

  @override
  String get agentSshConnectTip =>
      'Агенту потрібне SSH-з’єднання. Введіть пароль тут';

  @override
  String get agentAdHocSessions => 'Тимчасові підключення';

  @override
  String get agentSaveServerTitle => 'Зберегти як сервер';

  @override
  String get agentSaveServerTip =>
      'Цей хост і введений пароль зберігаються на цьому пристрої';

  @override
  String get agentMonitorOptional => 'Агент monitor (необов\'язково)';

  @override
  String get authFailTip => 'Не вдалося автентифікуватися. Перевірте дані';

  @override
  String get autoBackupConflict =>
      'Тільки одне автоматичне резервне копіювання може бути активне одночасно.';

  @override
  String get autoConnect => 'Авто підключення';

  @override
  String get autoRun => 'Авто запуск';

  @override
  String get autoUpdateHomeWidget =>
      'Автоматичне оновлення віджетів на головному екрані';

  @override
  String get availableTabs => 'Доступні вкладки';

  @override
  String get backupEncrypted => 'Резервна копія зашифрована';

  @override
  String get backupNotEncrypted => 'Резервна копія не зашифрована';

  @override
  String get backupPassword => 'Пароль резервного копіювання';

  @override
  String get backupPasswordRemoved => 'Пароль резервного копіювання видалено';

  @override
  String get backupPasswordSet => 'Пароль резервного копіювання встановлено';

  @override
  String get backupPasswordTip =>
      'Встановіть пароль для шифрування файлів резервного копіювання. Залиште порожнім для відключення шифрування.';

  @override
  String get backupPasswordWrong => 'Неправильний пароль резервного копіювання';

  @override
  String get connectAll => 'Підключити всі';

  @override
  String get disconnectAll => 'Відключити всі';

  @override
  String get distIcon => 'Позначки дистрибутивів';

  @override
  String get distIconIntroLegal =>
      'Знак свідчить лише про те, що цей пристрій прочитав із віддаленої системи; ці відомості можуть бути хибними або застарілими і не позначають ані похідну збірку, ані перезбирання, ані якусь конкретну версію. Якщо визначити не вдалося, малюється звичайна піктограма.\n\nКожен знак є торговельною маркою свого власника і використовується тут лише для позначення системи, яку він ідентифікує.';

  @override
  String get distIconTip =>
      'Показувати біля кожного сервера невелику позначку системи, яка на ньому ймовірно працює';

  @override
  String get distNameMap => 'Зіставлення імен';

  @override
  String get distNameMapTip =>
      'Лише для дистрибутива, у якого файл там, де ви розміщуєте позначки, називається інакше. Ключ — ім\'я, яке вживає цей застосунок, значення — ім\'я, яке слід завантажити. Залиште порожнім, доки жодної позначки не бракує.';

  @override
  String get logoUrl => 'Адреса логотипа';

  @override
  String get logoUrlTip =>
      'Велике зображення вгорі сторінки сервера, у власних кольорах.';

  @override
  String get globe => 'Глобус';

  @override
  String get locationTip =>
      'Де цей сервер показано на глобусі. Спочатку широта, потім довгота, у градусах — наприклад 39.9042, 116.4074.';

  @override
  String get markUrl => 'Адреса позначки';

  @override
  String get markUrlTip =>
      'Маленька позначка поряд з іменем сервера у списках. Порожньо — не показувати.\n\nЦе не те саме зображення, що логотип';

  @override
  String get navTabMenuTip =>
      'Натисніть і утримуйте вкладку — або клацніть правою кнопкою — щоб підключити чи відключити все одразу.';

  @override
  String nTags(int count) {
    return 'Тегів: $count';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Для віддалених резервних копій потрібен непорожній пароль резервного копіювання';

  @override
  String get monitorHttpsRequired =>
      'Віддаленому агенту monitor потрібен HTTPS, якщо для нього не дозволено HTTP.';

  @override
  String get monitorAllowInsecureHttp => 'Дозволити HTTP';

  @override
  String get plainHttpTitle => 'Цей агент віддається незашифрованим HTTP';

  @override
  String get plainHttpTip =>
      'Пароль і все, що запитує застосунок, підуть відкритим текстом. Поки нічого не надіслано.';

  @override
  String get allowForThisServer => 'Дозволити для цього сервера';

  @override
  String get viewError => 'Переглянути помилку';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Лише в довіреній приватній мережі, що сама шифрує транспорт, наприклад Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Читати стан цього сервера через HTTP API агента **monitor**, а не виконуючи команди по SSH.\n\nАгента спершу треба встановити на сервер; графіки, застосунок для годинника та віджети залежать від нього.\n\n[Як встановити monitor]($url)';
  }

  @override
  String get backupTip =>
      'Експортовані дані можуть бути зашифровані паролем. \nБудь ласка, зберігайте їх у безпеці.';

  @override
  String get icloudBackupStatusTitle => 'Стан резервної копії';

  @override
  String get icloudBackupStatusLoading =>
      'Завантаження стану резервної копії iCloud…';

  @override
  String get icloudBackupStatusError =>
      'Не вдалося прочитати метадані резервної копії iCloud';

  @override
  String get icloudBackupStatusEmpty =>
      'Файл резервної копії в iCloud поки не знайдено';

  @override
  String get icloudBackupStateUploading => 'Вивантаження';

  @override
  String get icloudBackupStateConflict => 'Виявлено конфлікт';

  @override
  String get icloudBackupStateUploaded => 'Вивантажено';

  @override
  String get icloudBackupStateWaiting => 'Очікування iCloud';

  @override
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
    return 'Остання копія: $lastModified\nСтан: $remoteState';
  }

  @override
  String get bgRun => 'Запуск у фоновому режимі';

  @override
  String get bgRunTip =>
      'Цей перемикач лише вказує на те, що програма намагатиметься працювати у фоновому режимі. Чи може вона працювати у фоновому режимі, залежить від прав доступу. Для AOSP-орієнтованих Android ROM, будь ласка, вимкніть \"Оптимізацію акумулятора\" в цьому додатку. Для MIUI / HyperOS, будь ласка, змініть політику економії енергії на \"Нескінченна\".';

  @override
  String get trayReadings => 'Показники';

  @override
  String get trayChart => 'Графік';

  @override
  String get trayChartNone => 'Немає';

  @override
  String get trayCompact => 'Компактні рядки';

  @override
  String get trayCompactTip =>
      'По одному рядку на сервер, без графіка. Linux завжди використовує однорядковий макет, оскільки меню панелі передається через D-Bus, який передає мітку замість довільного макета; водночас вибраний графік може бути доданий як зображення.';

  @override
  String get trayKeepRunning => 'Продовжувати роботу в треї';

  @override
  String get trayKeepRunningTip =>
      'Після закриття вікна програма залишається в рядку меню або області сповіщень і продовжує стежити за серверами. Вимкніть цей параметр, щоб кнопка закриття завершувала роботу програми.';

  @override
  String get bgRunNeedsNotification =>
      'Робота у фоні потребує постійного сповіщення, а застосунок не має дозволу на сповіщення. Натисніть, щоб дозволити.';

  @override
  String get clearAllStatsContent =>
      'Ви впевнені, що хочете очистити всю статистику з\'єднань сервера? Цю дію не можна скасувати.';

  @override
  String get clearAllStatsTitle => 'Очистити всю статистику';

  @override
  String clearServerStatsContent(String serverName) {
    return 'Ви впевнені, що хочете очистити статистику з\'єднань для сервера \"$serverName\"? Цю дію не можна скасувати.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
    return 'Очистити статистику $serverName';
  }

  @override
  String get clearThisServerStats => 'Очистити статистику цього сервера';

  @override
  String get closeAfterSave => 'Зберегти та закрити';

  @override
  String get collapseUITip =>
      'Сховати довгі списки, що є у UI за замовчуванням';

  @override
  String get connectionDetails => 'Деталі з\'єднання';

  @override
  String get connectionStats => 'Статистика з\'єднань';

  @override
  String get connectionStatsDesc =>
      'Переглянути коефіцієнт успішності підключення до сервера та історію';

  @override
  String get containerTrySudoTip =>
      'Наприклад: У застосунку користувач це aaa, але Docker встановлений під користувачем root. У цьому випадку вам потрібно активувати цю опцію.';

  @override
  String get containerSudoPasswordRequired =>
      'Для доступу до Docker потрібен пароль sudo. Будь ласка, введіть ваш пароль.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Пароль sudo неправильний або не дозволений. Будь ласка, спробуйте ще раз.';

  @override
  String get copyPath => 'Скопіювати шлях';

  @override
  String get cpuViewAsProgressTip =>
      'Відобразити використання кожного процесора у вигляді стовпчикової діаграми (старий стиль)';

  @override
  String get customCmd => 'Користувацькі команди';

  @override
  String get deleteServers => 'Масове видалення серверів';

  @override
  String get deleteDirRecursive => 'Видалити папку та весь її вміст';

  @override
  String get desktopTerminalTip =>
      'Команда для відкриття емулятора термінала під час запуску SSH-сеансів.';

  @override
  String get dirEmpty => 'Переконайтеся, що директорія пуста.';

  @override
  String get discoverSshServers => 'Виявити SSH сервери';

  @override
  String get discoveryFailed => 'Виявлення не вдалось';

  @override
  String get discoverySettings => 'Налаштування виявлення';

  @override
  String get distro => 'Дистрибутив';

  @override
  String get diskHealth => 'Стан диска';

  @override
  String get displayCpuIndex => 'Відобразити індекс ЦП';

  @override
  String dl2Local(String fileName) {
    return 'Завантажити $fileName на локальний комп\'ютер?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Немає запущених контейнерів.\nЦе може бути через:\n- Користувача Docker, відмінного від користувача, налаштованого в додатку\n- змінну оточення DOCKER_HOST, яка не була правильно зчитана. Ви можете виконати `echo \$DOCKER_HOST` у терміналі, щоб побачити її значення.';

  @override
  String get dockerProjectOther => 'Інші';

  @override
  String get dockerPruneTip =>
      'Видаліть невикористані дані, щоб звільнити місце на диску';

  @override
  String get dockerStatistics => 'Статистика Docker';

  @override
  String get doubleColumnMode => 'Режим подвійної колонки';

  @override
  String get doubleColumnTip =>
      'Ця опція лише активує функцію, чи можна її насправді включити, залежить від ширини пристрою';

  @override
  String get editVirtKeys => 'Віртуальні клавіші';

  @override
  String get editorHighlightTip =>
      'Поточна підсвітка коду не ідеальна і може бути вимкнена для покращення.';

  @override
  String get enableMdns => 'Увімкнути mDNS';

  @override
  String get enableMdnsDesc =>
      'Використовувати mDNS/Bonjour для виявлення SSH сервісів';

  @override
  String get envVars => 'Змінні середовища';

  @override
  String get extraArgs => 'Додаткові аргументи';

  @override
  String get fallbackSshDest => 'Резервна SSH адреса';

  @override
  String get fdroidReleaseTip =>
      'Якщо ви завантажили цей застосунок з F-Droid, рекомендується відключити цю опцію.';

  @override
  String fileTooLarge(String file, String size, String sizeMax) {
    return 'Файл \'$file\' занадто великий ($size), макс $sizeMax';
  }

  @override
  String get fileDirGone => 'Цієї теки більше немає';

  @override
  String get fileDirGoneTip => 'Його видалено або перейменовано';

  @override
  String get fullScreen => 'Повний екран';

  @override
  String get fullScreenJitter => 'Тремтіння в повноекранному режимі';

  @override
  String get fullScreenJitterHelp => 'Щоб уникнути вигоряння екрану';

  @override
  String get fullScreenTip =>
      'Чи слід увімкнути повноекранний режим під час повороту пристрою в горизонтальне положення? Ця опція стосується лише вкладки сервера.';

  @override
  String get githubGistIdOptional => 'ID Gist (необов\'язково)';

  @override
  String get githubGistToken => 'Токен GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'Токен порожній';

  @override
  String get goto => 'Перейти до';

  @override
  String get homeTabs => 'Домашні вкладки';

  @override
  String get homeTabsCustomizeDesc =>
      'Налаштуйте, які вкладки відображаються на головній сторінці та їх порядок';

  @override
  String get ignoreCert => 'Ігнорувати сертифікат';

  @override
  String get image => 'Зображення';

  @override
  String get macDmgBody =>
      'App Store вимагає запускати застосунок у пісочниці, а з пісочниці не відкрити термінал. Версія DMG може.\n\nВерсія з App Store може перестати оновлюватися.';

  @override
  String get macDmgImportDenied =>
      'macOS не дозволив прочитати дані попередньої версії';

  @override
  String get macDmgImported => 'Дані попередньої версії імпортовано';

  @override
  String get macDmgImportFailed =>
      'Не вдалося прочитати дані попередньої версії';

  @override
  String get macDmgTip =>
      'Локальний термінал і запуск сніпетів локально (версія DMG)';

  @override
  String get macDmgTitle => 'Збірка DMG';

  @override
  String get showHiddenFiles => 'Показувати приховані файли';

  @override
  String get sshKeyAlgorithm => 'Алгоритм';

  @override
  String get sshKeyComment => 'Коментар';

  @override
  String get sshKeyGenerate => 'Створити пару ключів';

  @override
  String get sshKeyGenerating => 'Створення…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'Закритий ключ [$name] не розблоковано.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Необов\'язково. Ключ із парольною фразою зберігається зашифрованим, і її запитують під час першого використання ключа.';

  @override
  String get sshKeyPassphraseWrong => 'Неправильна парольна фраза.';

  @override
  String get sshKeyPublicKey => 'Відкритий ключ';

  @override
  String get sshKeyPublicKeyTip =>
      'Додайте цей рядок до ~/.ssh/authorized_keys на сервері.';

  @override
  String get sshKeyRecommended => 'Рекомендовано';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Введіть парольну фразу закритого ключа [$name].';
  }

  @override
  String get ungrouped => 'Без групи';

  @override
  String get containerReclaimable => 'Reclaimable';

  @override
  String get unused => 'Не використовується';

  @override
  String get dangling => 'Висячий';

  @override
  String get pruneUnusedImages => 'Очистити невикористані образи';

  @override
  String get pruneDanglingImages => 'Очистити висячі образи';

  @override
  String get pruneImages => 'Очистити образи';

  @override
  String get unusedTaggedImages => 'Невикористовувані з тегами';

  @override
  String get pruneDanglingImagesTip => 'Видаляє лише висячі образи.';

  @override
  String get pruneUnusedImagesTip =>
      'Також видаляє образи з тегами, які не використовуються контейнерами.';

  @override
  String get includeUnusedVolumesTip =>
      'Також видаляє томи, які не використовуються контейнерами.';

  @override
  String get pruneCommandPreview => 'Попередній перегляд команди';

  @override
  String get pruneForceSshTip =>
      '-f пропускає інтерактивне підтвердження і завжди ввімкнено для виконання через SSH.';

  @override
  String get pruneVolumes => 'Очистити томи';

  @override
  String get pruneUnusedData => 'Очистити невикористані дані';

  @override
  String get pull => 'Pull';

  @override
  String get invalidHostFormat =>
      'Недійсний формат хоста. Дозволено лише символи IPv4, IPv6 та домену.';

  @override
  String get jumpServer => 'Стрибковий Сервер';

  @override
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return 'Проміжні сервери для $serverName не знайдено: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
    return '«$name» вже існує';
  }

  @override
  String get noJumpServerAvailable => 'Немає доступного проміжного сервера.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Проміжний сервер і ProxyCommand не можна використовувати разом.';

  @override
  String get noConnectionMethod => 'Налаштуйте SSH, агент monitor або обидва';

  @override
  String get preferredTransport => 'Спробувати спершу';

  @override
  String get preferredTransportTip =>
      'Звідки читається стан і яке з’єднання команда відкриє першим. Інше лишається доступним.';

  @override
  String get keepForeground => 'Тримати застосунок на передньому плані!';

  @override
  String get keepStatusWhenErr => 'Зберегати останній стан сервера';

  @override
  String get keepStatusWhenErrTip =>
      'Тільки в разі виникнення помилки під час виконання скрипту';

  @override
  String get keyAuth => 'Аутентифікація ключем';

  @override
  String get lastFailure => 'Остання помилка';

  @override
  String get lastSuccess => 'Останній успіх';

  @override
  String get letterCache => 'Звичайне введення з клавіатури';

  @override
  String get letterCacheTip =>
      'Коли параметр увімкнено, введення проходить через звичайний IME, що на деяких системах дає змогу уникнути запитів захищеної клавіатури в терміналі.';

  @override
  String get linuxShellTip =>
      'З якої оболонки запускається термінал. Порожньо — повернути /bin/sh.';

  @override
  String get linuxNetTip => 'DNS-сервери. Порожньо — повернути типові значення';

  @override
  String madeWithLove(String myGithub) {
    return 'Зроблено з ❤️ від $myGithub';
  }

  @override
  String get maxConcurrency => 'Максимальна паралельність';

  @override
  String get maxRetryCount =>
      'Кількість повторних спроб підключення до сервера';

  @override
  String mismatchSystem(String system) {
    return 'Невідповідна система: $system';
  }

  @override
  String get mirror => 'Дзеркало';

  @override
  String get needRestart => 'Необхідно перезапустити застосунок';

  @override
  String get netViewType => 'Тип перегляду мережі';

  @override
  String get newContainer => 'Новий контейнер';

  @override
  String get noConnectionStatsData => 'Немає даних статистики з\'єднань';

  @override
  String get noLineChart => 'Не використовувати лінійні діаграми';

  @override
  String get noPrivateKeyTip =>
      'Приватного ключа немає, можливо, він був видалений або сталася помилка конфігурації.';

  @override
  String get noPromptAgain => 'Більше не запитувати';

  @override
  String get openLastPath => 'Відкрити останній шлях';

  @override
  String get openLastPathTip =>
      'Для різних серверів будуть збережені різні логи. Записується шлях при виході';

  @override
  String get parseContainerStatsTip =>
      'Парсинг статусу зайнятості Docker є відносно повільним.';

  @override
  String get preferDiskAmount => 'Пріоритетно показувати ємність диска';

  @override
  String get privateKey => 'Приватний ключ';

  @override
  String privateKeyNotFoundFmt(String keyId) {
    return 'Приватний ключ [$keyId] не знайдено.';
  }

  @override
  String get bmcPowerOnAction => 'Увімкнути';

  @override
  String get bmcShutdown => 'Вимкнути';

  @override
  String get bmcForceOff => 'Примусово вимкнути';

  @override
  String get restart => 'Перезапустити';

  @override
  String get bmcPowerCycle => 'Повне перезавантаження живлення';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Надіслати на $server? Сервісу буде надіслано «$resetType»';
  }

  @override
  String get bmcPowerDone => 'Стан живлення змінився';

  @override
  String get bmcPowerAccepted =>
      'Прийнято, але стан живлення не змінився. М’яка операція залежить від ОС';

  @override
  String get bmcPowerUnsupported => 'Ця служба нічого не дозволяє для цієї дії';

  @override
  String get bmcUnauthorized => 'BMC відхилив обліковий запис';

  @override
  String get bmcAccountMissing => 'Для цього BMC не задано обліковий запис';

  @override
  String get bmcPowerOn => 'Увімкнено';

  @override
  String get bmcPowerOff => 'Вимкнено';

  @override
  String get bmcCertRejected =>
      'Сертифікат відхилено — перевірте його в налаштуваннях сервера';

  @override
  String get bmcNotAService => 'За цією адресою немає служби Redfish';

  @override
  String get bmcNoSystem => 'Служба не повідомляє про жодну систему';

  @override
  String get bmcSensorsTruncated => 'Показано лише перші датчики';

  @override
  String get bmcMultipleSystems => 'Показано лише першу систему';

  @override
  String get bmcTip =>
      'BMC — окремий комп\'ютер на материнській платі, доступний тоді, коли операційна система хоста недоступна. Налаштований тут, він повідомляє стан живлення та показання апаратних датчиків, поки сервер вимкнено або він завис. Потрібен Redfish, він є в більшості серверного обладнання приблизно з 2016 року.';

  @override
  String get bmcCert => 'Сертифікат';

  @override
  String get bmcCertPinned => 'Перевірено та закріплено';

  @override
  String get bmcCertUnreviewed =>
      'Ще не перевірено — торкніться, щоб побачити сертифікат';

  @override
  String get bmcCertReview =>
      'Самопідписаний сертифікат. Звірте його перед прийняттям. Далі довіряють лише йому.';

  @override
  String get bmcCertChanged => 'Сертифікат не збігається. Перевірте.';

  @override
  String get bmcCertExpired => 'Прострочений.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Прийнято раніше: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'Адреса BMC має бути URL, наприклад https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Ця збірка працює в пісочниці: команда отримує порожній home, не ваш, тому все, що читає ~/.ssh, падає. Версія DMG — ні.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Не вдалося прочитати файл закритого ключа $path: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Ця збірка не може читати файли поза своїм контейнером, тож ключ за шляхом $path недоступний. Імпортуйте ключ у налаштуваннях або скористайтеся збіркою DMG.';
  }

  @override
  String get pushToken => 'Надіслати токен';

  @override
  String get liveActivity => 'Активність у реальному часі';

  @override
  String get liveActivityTip =>
      'Показує сеанси термінала на екрані блокування та в Dynamic Island. Ім’я сервера й стан підключення видно без розблокування пристрою.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS не дозволяє. Перемикачі розташовані в розділах Налаштування › ServerBox › Активності в реальному часі та Налаштування › Face ID і код-пароль › Активності в реальному часі.';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand підтримується лише на настільних платформах.';

  @override
  String get pveIgnoreCertTip =>
      'Не рекомендується включати, будьте обережні з ризиками безпеки! Якщо ви використовуєте стандартний сертифікат від PVE, вам потрібно увімкнути цю опцію.';

  @override
  String get pvePasswordRequired =>
      'Потрібен пароль PVE. Задайте його в параметрах сервера.';

  @override
  String get pveOtpRequired =>
      'На цьому сервері PVE увімкнено двофакторну автентифікацію. Введіть код OTP.';

  @override
  String get pveOtpCodeRequired => 'Потрібен код OTP.';

  @override
  String get pveOtpVerificationFailed =>
      'Перевірка OTP не вдалася. Спробуйте ще раз із новим кодом.';

  @override
  String get pveOtpTitle => 'Перевірка OTP';

  @override
  String get pveOtpLabel => 'Код OTP';

  @override
  String get pveInvalidResponseBody =>
      'Вхід у PVE повернув некоректне тіло відповіді.';

  @override
  String get pveInvalidResponseData =>
      'Відповідь на вхід у PVE не містила коректних даних.';

  @override
  String get pveMissingAuthTicket =>
      'Вхід у PVE успішний, але квиток автентифікації не повернуто.';

  @override
  String get pveLoadingConnect => 'Підключення…';

  @override
  String get pvePassword => 'Пароль PVE';

  @override
  String get pvePasswordHint => 'Потрібен під час автентифікації SSH за ключем';

  @override
  String get read => 'Читати';

  @override
  String get recentConnections => 'Останні з\'єднання';

  @override
  String get rememberPwdInMem => 'Запам\'ятати пароль у пам\'яті';

  @override
  String get rememberPwdInMemTip =>
      'Використовується для контейнерів, призупинення тощо.';

  @override
  String get remotePath => 'Віддалений шлях';

  @override
  String rootfsUpdateTip(
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return 'Встановлено $distro $installed, доступний $latest. Оновлення замінить весь контейнер: дані $pm буде втрачено';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'Закрийте термінали на $name, перш ніж видаляти';
  }

  @override
  String get rootfsSubtitle =>
      'Користувацьке середовище Linux на цьому пристрої';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
    return 'Завантажує $distro $version (близько $size МБ) і розпаковує на пристрої.';
  }

  @override
  String get sameIdServerExist => 'Сервер з таким ID вже існує';

  @override
  String get second => 'сек.';

  @override
  String get serverFilesUnavailableTip =>
      'Потрібен SSH до цього сервера або встановлений server_box_monitor з увімкненим файловим API.';

  @override
  String get back => 'Назад';

  @override
  String get history => 'Історія';

  @override
  String get homeDir => 'Домівка';

  @override
  String selected(int count) {
    return 'Вибрано: $count';
  }

  @override
  String get sendTo => 'Надіслати до…';

  @override
  String get serverFuncBtns => 'Кнопки функцій сервера';

  @override
  String get serverOrder => 'Порядок сервера';

  @override
  String get serverTabEmpty => 'Серверів ще немає';

  @override
  String get serverTabRequired => 'Вкладку сервера не можна видалити';

  @override
  String get shareCodeHint =>
      'Передайте ці цифри одержувачу окремо. Їх немає в QR-коді.';

  @override
  String get shareCodePrompt => '6-значний код';

  @override
  String get shareCodeTitle => 'Одноразовий код';

  @override
  String get shareExpired =>
      'Термін дії цих даних минув. Попросіть надіслати нові.';

  @override
  String get shareImportFile => 'З отриманого файлу';

  @override
  String get shareImportTitle => 'Імпорт спільного сервера';

  @override
  String get shareIncludesKey => 'До спільних даних включено приватний ключ.';

  @override
  String get shareOmittedBmc =>
      'Облікові дані BMC. Адресу включено, а облікові дані — ні.';

  @override
  String get shareOmittedJump =>
      'Проміжний сервер, оскільки на цьому пристрої він зберігається як окремий сервер.';

  @override
  String get shareOmittedKeyPath =>
      'Файл ключа, оскільки шлях до нього дійсний лише на цьому пристрої.';

  @override
  String get shareOmittedMissingKey =>
      'Приватний ключ, оскільки його немає у сховищі ключів цього пристрою.';

  @override
  String get shareOmittedTip => 'Не включено; одержувачу потрібно налаштувати:';

  @override
  String get sharePassphraseTip =>
      'Ця парольна фраза шифрує файл. Вона потрібна одержувачу для імпорту сервера, і відновити її неможливо.';

  @override
  String shareQrTip(int minutes) {
    return 'Дані підключення в цьому QR-коді зашифровано. Термін дії спливе через $minutes хв.';
  }

  @override
  String get shareScanQr => 'Сканувати QR-код';

  @override
  String shareServerExists(String name) {
    return 'Сервер «$name» на цьому пристрої вже використовує цю адресу. Усе одно імпортувати?';
  }

  @override
  String get shareTooBigForQr =>
      'Дані завеликі для QR-коду. Надішліть їх як файл.';

  @override
  String get shareTooNew =>
      'Ці дані створено в новішій версії ServerBox. Оновіть застосунок, щоб відкрити їх.';

  @override
  String get shareUnreadable =>
      'Це неприпустимі дані спільного доступу ServerBox.';

  @override
  String get shareVia => 'Спосіб надсилання';

  @override
  String get sftpDlPrepare => 'Підготовка до підключення...';

  @override
  String get sftpEditorTip =>
      'Порожньо — вбудований редактор. Наприклад `vim` (краще брати з `EDITOR`).';

  @override
  String get sftpRmrDirSummary =>
      'Використовуйте `rm -r`, щоб видалити папку в SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP підключено';

  @override
  String get sftpShowFoldersFirst => 'Спочатку відображати директорії';

  @override
  String get sftpUnavailableUseScp =>
      'Якщо цей хост не має підсистеми SFTP, як багато вбудованих пристроїв, змініть передавання файлів на SCP в налаштуваннях сервера.';

  @override
  String get sshFileTransportTip =>
      'SFTP підходить для будь-якого сучасного пристрою. SCP — для старого чи вбудованого хоста, у SSH-сервера якого немає підсистеми SFTP: йому потрібна команда `scp` і оболонка, у якій є й звичайні файлові утиліти (`find`, `stat`, `mv`, `chmod`).';

  @override
  String get specifyDev => 'Вказати пристрій';

  @override
  String get specifyDevTip =>
      'Мережевий трафік типово рахується по всіх пристроях; вкажіть один тут';

  @override
  String get tempIsCelsiusTip =>
      'Якщо увімкнено, значення температури вважається градусами Цельсія, а не мілліцельсія. Вмикайте, лише якщо температура показується неправильно (наприклад, 0,1 °C замість 58 °C).';

  @override
  String spentTime(String time) {
    return 'Витрачений час: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return 'Всі сервери вже існують (знайдено $duplicateCount дублікатів)';
  }

  @override
  String get sshConnectionModeTip =>
      'Вбудований: використовувати термінал застосунку. Системний SSH: запускати системну команду ssh у зовнішньому терміналі.';

  @override
  String get sshConnectionModeUseBuiltin =>
      'Використовувати вбудований термінал';

  @override
  String get sshConnectionModeUseSystem => 'Використовувати системний SSH';

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount дублікатів буде пропущено';
  }

  @override
  String get sshConfigFound => 'Ми знайшли SSH-конфігурацію у вашій системі';

  @override
  String sshConfigFoundServers(int totalCount) {
    return 'Знайдено $totalCount серверів';
  }

  @override
  String get sshConfigImport => 'Імпорт SSH Конфігурації';

  @override
  String get sshConfigImportPermission =>
      'Чи хочете ви надати дозвіл на читання ~/.ssh/config та автоматичний імпорт налаштувань сервера?';

  @override
  String get sshConfigImportTip =>
      'Пропозиція прочитати ~/.ssh/config при створенні першого сервера';

  @override
  String sshConfigImported(int count) {
    return 'Імпортовано $count серверів з SSH-конфігурації';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return 'SSH-ключ хоста для $serverName змінено. Продовжуйте лише якщо довіряєте цьому серверу.';
  }

  @override
  String get sshHostKeyType => 'Тип ключа хоста SSH';

  @override
  String get sshKnownHostKeys => 'Відомі хости';

  @override
  String get sshKnownHostKeysTip => 'Ключі хостів, які прийняв цей застосунок';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return 'Отримано новий SSH-ключ хоста від $serverName. Перевірте відбиток перед тим, як довіряти.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
    return 'Збережений відбиток: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Код підтвердження';

  @override
  String get sshConfigManualSelect =>
      'Чи хочете ви вручну вибрати файл конфігурації SSH?';

  @override
  String get sshConfigNoServers => 'Сервери не знайдені в SSH-конфігурації';

  @override
  String get sshConfigPermissionDenied =>
      'Неможливо отримати доступ до файлу конфігурації SSH через дозволи macOS.';

  @override
  String sshConfigServersToImport(int importCount) {
    return '$importCount серверів буде імпортовано';
  }

  @override
  String get sshTermHelp =>
      'Коли термінал прокрутний, горизонтальне проведення вибирає текст. Натискання кнопки клавіатури вмикає/вимикає клавіатуру. Іконка файлу відкриває поточний шлях SFTP. Кнопка буфера обміну копіює вміст, коли текст вибрано, і вставляє вміст з буфера обміну в термінал, коли текст не вибрано і є вміст у буфері обміну. Іконка коду вставляє фрагменти коду в термінал і виконує їх.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Автоматичне переключення віртуальних клавіш';

  @override
  String get supportFmtArgs => 'Підтримуються такі параметри форматування:';

  @override
  String get suspendTip =>
      'Функція призупинення потребує адміністративних прав та підтримки systemd.';

  @override
  String switchTo(String val) {
    return 'Переключитися на $val';
  }

  @override
  String get syncAppSettings => 'Синхронізувати налаштування застосунку';

  @override
  String get syncAppSettingsTip =>
      'Включити тему, компонування, редактор, термінал та інші налаштування пристрою в автоматичну синхронізацію.';

  @override
  String get termFontSizeTip =>
      'Це налаштування вплине на розмір терміналу (ширину та висоту). Ви можете масштабувати на сторінці терміналу, щоб налаштувати розмір шрифту поточної сесії.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (оригінальний розмір), працює лише на частині шрифта сторінки сервера, не рекомендується змінювати.';

  @override
  String get times => 'Рази';

  @override
  String get trySudo => 'Спробуйте використовувати sudo';

  @override
  String get sudoPromptNotFound => 'Наразі немає запиту пароля sudo.';

  @override
  String get updateServerStatusInterval => 'Інтервал оновлення статусу сервера';

  @override
  String get useNoPwd => 'Пароль не буде використовуватися';

  @override
  String get usePodmanByDefault => 'Використовувати Podman за замовчуванням';

  @override
  String get used => 'Використано';

  @override
  String get view => 'Переглянути';

  @override
  String get viewDetails => 'Переглянути деталі';

  @override
  String get virtKeyHelpClipboard =>
      'Копіювати в буфер обміну, якщо вибраний термінал не порожній, в іншому випадку вставити вміст буфера обміну в термінал.';

  @override
  String get virtKeyHelpIME => 'Увімкнути/вимкнути клавіатуру';

  @override
  String get virtKeyHelpSFTP => 'Відкрити поточний каталог у SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Вибрати сніпет і виконати його в цьому терміналі.';

  @override
  String get virtKeyHelpTmux => 'Перемикання між сесіями та вікнами tmux.';

  @override
  String get virtKeyIntroActions => 'Швидкі дії';

  @override
  String get virtKeyIntroActionsTip =>
      'Ці клавіші нічого не вводять, а відкривають потрібне. Утримуйте клавішу, щоб прочитати, що вона робить.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'У налаштуваннях термінала їх можна переставити або приховати ті, якими ви не користуєтесь.';

  @override
  String get virtKeyIntroModifiers => 'Модифікатори';

  @override
  String get virtKeyIntroModifiersTip =>
      'Натисніть одну, щоб увімкнути, потім літеру на клавіатурі. Вона діє рівно на одну клавішу.';

  @override
  String get virtKeyIntroNav => 'Переміщення курсора';

  @override
  String get virtKeyIntroNavTip =>
      'Ці клавіші рухають курсор. Утримуйте стрілку, щоб повторювати її.';

  @override
  String get virtKeyIntroSelect =>
      'Поки в терміналі є що прокручувати, перетягування вбік виділяє текст.';

  @override
  String get virtKeyRows => 'Рядків показувати одразу';

  @override
  String get virtKeyRowsTip =>
      'Решта — на окремій сторінці, яку гортають убік.';

  @override
  String get waitConnection =>
      'Будь ласка, зачекайте, доки з\'єднання буде встановлено.';

  @override
  String get wakeLock => 'Залишити активним';

  @override
  String get watchNotPaired => 'Немає спарованого Apple Watch';

  @override
  String get webdavSettingEmpty => 'Налаштування WebDav порожнє';

  @override
  String get whenOpenApp => 'При відкритті програми';

  @override
  String get wolTip =>
      'Після налаштування WOL (Wake-on-LAN), при кожному підключенні до сервера відправляється запит WOL.';

  @override
  String get write => 'Записати';

  @override
  String get writeScriptFailTip =>
      'Запис у скрипт не вдався, можливо, через брак дозволів або каталог не існує.';

  @override
  String get writeScriptTip =>
      'Після підключення до сервера скрипт буде записано у `~/.config/server_box` \n | `/tmp/server_box` для моніторингу стану системи. Ви можете переглянути вміст скрипта.';

  @override
  String get menuGitHubRepository => 'Репозиторій GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'Виявлено емуляцію Podman Docker. Будь ласка, переключіться на Podman у налаштуваннях.';

  @override
  String get betaTip =>
      'Функція ще в бета-тестуванні. Її роботу не гарантовано.';

  @override
  String get portForward_startPrompt =>
      'Додайте правило перенаправлення порту, щоб почати';

  @override
  String get portForward_localHost => 'Локальний хост';

  @override
  String get portForward_localPort => 'Локальний порт';

  @override
  String get portForward_remoteHost => 'Віддалений хост';

  @override
  String get portForward_remotePort => 'Віддалений порт';

  @override
  String portForward_deleteConfirmFmt(String name) {
    return 'Видалити $name?';
  }

  @override
  String get sponsor => 'Спонсор';

  @override
  String get sortByJoinTime => 'За часом додавання';

  @override
  String get tmuxAutoAttach => 'Автопідключення до tmux';

  @override
  String get tmuxAuto => 'Автоматичний tmux';

  @override
  String get tmuxAutoTip =>
      'Автоматично запускати tmux або підключатися до нього під час з\'єднання по SSH';

  @override
  String get tmuxSessionSelector => 'Вибір сесії';

  @override
  String get tmuxSessionSelectorTip =>
      'Показувати вибір сесії під час підключення';

  @override
  String get tmuxDefaultSessionName => 'Типова назва сесії';

  @override
  String get tmuxSessionName => 'Назва сесії';

  @override
  String get tmuxExistingSessions => 'Наявні сесії';

  @override
  String get tmuxNewSession => 'Нова сесія';

  @override
  String get tmuxWindows => 'Вікна';

  @override
  String get tmuxNewWindow => 'Нове вікно';

  @override
  String get tmuxNoWindowsFound => 'Вікон не знайдено';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count вікна',
      many: '$count вікон',
      few: '$count вікна',
      one: '1 вікно',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count панелі',
      many: '$count панелей',
      few: '$count панелі',
      one: '1 панель',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Підключена';

  @override
  String get tmuxActive => 'Активна';

  @override
  String tmuxActiveAt(String time) {
    return 'активна: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'підключена: $time';
  }

  @override
  String get tmuxSkip => 'Пропустити';

  @override
  String get tmuxNotAvailable => 'tmux недоступний';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Неочікувана кількість сегментів у відповіді контейнера: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Інша операція з контейнером уже виконується';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count процесу',
      many: '$count процесів',
      few: '$count процеси',
      one: '$count процес',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'Формат списку процесів не підтримується.';

  @override
  String get processParseInvalidRows =>
      'Не вдалося прочитати деякі записи процесів.';

  @override
  String get processParseInvalidWindowsJson =>
      'Не вдалося прочитати відповідь зі списком процесів Windows.';

  @override
  String get processParseInvalidWindowsRows =>
      'Не вдалося прочитати деякі записи процесів Windows.';

  @override
  String get processKillTargetChanged =>
      'Процес змінився або завершився. Оновіть список і повторіть спробу.';

  @override
  String get processSearchHint => 'Назва, користувач або PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Показати потоки ядра: $count',
      one: 'Показати 1 потік ядра',
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
  String get watchServers => 'Сервери на годиннику';

  @override
  String get watchServersTip =>
      'Годинник сам звертається до monitor, тому доступні лише сервери з ним.';

  @override
  String get watchNoMonitorServer =>
      'Жоден сервер не має налаштованого агента monitor';

  @override
  String get legacyStatusGoneTitle => 'URL-адреси стану більше не працюють';

  @override
  String get legacyStatusGoneBody =>
      'Застосунок для годинника та віджети читали адресу `/status`, введену вручну. Цю кінцеву точку вилучено: вона могла повертати лише поточні значення текстом, тому графіки були неможливі.\n\nТепер вони читають автентифікований API агента monitor, малюють графіки та самі синхронізуються із застосунком. Налаштуйте сервер у застосунку один раз — і кожен годинник та віджет його підхопить.';

  @override
  String get services => 'Служби';

  @override
  String get status => 'Стан';

  @override
  String get enable => 'Увімкнути';

  @override
  String get disable => 'Вимкнути';

  @override
  String get starting => 'Запускається';

  @override
  String get stopping => 'Зупиняється';

  @override
  String get serviceManagerUnsupported => 'Непідтримуваний менеджер служб';

  @override
  String get serviceManagerUnsupportedTip =>
      'Цей сервер використовує менеджер служб, який ServerBox ще не підтримує. Підтримуються systemd, procd та OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Керується через $manager';
  }

  @override
  String get serviceListFailed => 'Не вдалося отримати список служб';

  @override
  String get serviceDetailsUnavailable =>
      'Деякі відомості про служби недоступні';

  @override
  String get serviceDetailsUnavailableTip =>
      'Список доступний, але менеджер не повернув усі відомості про стан або автозапуск.';

  @override
  String get systemdUserScopeMissing => 'Юніти користувача не показані';

  @override
  String get systemdUserScopeMissingTip =>
      'Цей обліковий запис не має шини сеансу користувача на сервері, тому показано лише системні юніти.';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Інші units: $count',
      one: 'Ще 1 unit',
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
    return 'Зупинено $duration тому';
  }

  @override
  String serviceExitStatus(int code) {
    return 'код завершення $code';
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
      other: 'Останні рядки: $count',
      one: 'Останній рядок',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable =>
      'Цей обліковий запис не може читати journal';

  @override
  String get serverUnreachable =>
      'Не вдалося виконати команду на цьому сервері';

  @override
  String get containerNoRuntime => 'Тут немає середовища виконання контейнерів';

  @override
  String get containerNoRuntimeTip =>
      'Ні `docker`, ні `podman` не відповіли на цій машині. Якщо один із них встановлено для іншого облікового запису, увімкніть «Спробуйте використовувати sudo» в налаштуваннях.';

  @override
  String get containerUnreadable =>
      'Середовище виконання контейнерів відповіло в неочікуваному форматі';

  @override
  String get power => 'Живлення';

  @override
  String get fan => 'Вентилятор';

  @override
  String get clockSpeed => 'Частота';

  @override
  String get vendor => 'Виробник';

  @override
  String get continueInTerminal => 'Продовжити в терміналі';

  @override
  String get askAiRiskUnknown => 'Не визначено';

  @override
  String get agentLocalExec => 'Виконувати команди на цьому пристрої';

  @override
  String get agentLocalExecTip =>
      'Дозволяє агенту працювати на машині, де запущено ServerBox. Навіть команди лише для читання перевіряються';

  @override
  String get agentLocalExecRootfsTip =>
      'Дозволяє агенту працювати локально, у межах контейнера Linux, встановленого ServerBox';

  @override
  String macDmgImportedPartly(String path) {
    return 'Дані раніше встановленої збірки імпортовано. Завантажені файли залишилися в $path.';
  }

  @override
  String get bmcAccount => 'Обліковий запис';

  @override
  String get bmcAccountUnset =>
      'Не вибрано — торкніться, щоб вибрати або створити';

  @override
  String bmcAccountShared(int count) {
    return 'Використовується на $count серверах';
  }

  @override
  String get bmcAccounts => 'Облікові записи BMC';

  @override
  String get bmcAccountSharedTip => 'Зміна тут вплине на всі з них.';

  @override
  String bmcAccountInUse(int count) {
    return 'Його використовують $count серверів. Адреса залишиться, обліковий запис — ні.';
  }

  @override
  String get bmcStaleWrite => 'BMC змінився під час запису. Спробуйте ще раз.';

  @override
  String get send => 'Надіслати';

  @override
  String get privacyBlur => 'Приватність у фоні';

  @override
  String get privacyBlurTip => 'Приховувати вміст програми в перемикачі';

  @override
  String get floatReturnToTab => 'Повернути у вкладку';

  @override
  String get termInFloatWindow => 'Цей термінал у плаваючому вікні';

  @override
  String get globeEnabledTip =>
      'Показувати сервери на глобусі там, де розташовані їхні адреси. Вимкнено прибирає кнопку та припиняє будь-які запити.';

  @override
  String get geoShardsConsentAttribution =>
      'IP-геолокація від [DB-IP](https://db-ip.com), CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Приватна адреса';

  @override
  String get geoMissNoData => 'Немає даних про місце';

  @override
  String get globeGuide =>
      'Натисніть тут, щоб побачити сервери на глобусі — там, де розташовані їхні адреси.';

  @override
  String get publicIp => 'Публічна IP';

  @override
  String get geoData => 'Дані міського рівня';

  @override
  String get geoDataTip =>
      'Після завантаження всі геолокаційні запити використовують дані, збережені на цьому пристрої. Адреси серверів і відомості про запити не передаються сервісу завантаження.';

  @override
  String get geoDataMissing => 'Не завантажено';

  @override
  String get geoDataUnreachable => 'Не вдалося отримати дані.';

  @override
  String get geoDataRemoveFailed => 'Не вдалося видалити дані.';

  @override
  String geoDataCurrent(String month) {
    return '$month вже встановлено.';
  }

  @override
  String geoDataConsent(String download, String disk) {
    return '**Розмір завантаження: $download · Місце на пристрої: $disk.** Повний набір даних зберігається на цьому пристрої, а всі подальші геолокаційні запити виконуються локально. Адреси серверів і відомості про запити не передаються сервісу завантаження.\n\nОновлюється щомісяця. Нова версія замінює встановлені дані, не зберігаючи додаткову копію. Дані можна видалити будь-коли.';
  }

  @override
  String get benchmark => 'Тест продуктивності';

  @override
  String get benchmarkIntro =>
      'Запускає на цьому сервері Yet Another Bench Script для перевірки диска, мережі та процесора. Повний тест триває 10–20 хвилин і продовжує виконуватися, якщо залишити цю сторінку або закрити застосунок.';

  @override
  String get benchmarkNoRuns => 'Результатів тестування ще немає.';

  @override
  String get benchmarkRunning => 'Виконується тест продуктивності';

  @override
  String get benchmarkStartFailed => 'Не вдалося запустити тест продуктивності';

  @override
  String get benchmarkCancelConfirm =>
      'Зупинити цей тест? Усі отримані результати буде втрачено.';

  @override
  String get benchmarkDeleteConfirm => 'Видалити результат цього тесту?';

  @override
  String get benchmarkNothingSelected =>
      'Усі етапи вимкнено. Буде зібрано лише інформацію про систему; це триватиме кілька секунд.';

  @override
  String get benchmarkDiskTip =>
      'fio із чотирма розмірами блоків; близько 3 хвилин. Записує тестовий файл розміром 2 ГБ у робочий каталог і потребує стільки ж вільного місця.';

  @override
  String get benchmarkNetworkTip =>
      'iperf3 із загальнодоступними серверами; близько 4 хвилин.';

  @override
  String get benchmarkReducedNetwork => 'Менше розташувань';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Три розташування замість семи. Приблизний обсяг трафіку зменшиться з $full до $reduced.';
  }

  @override
  String get benchmarkCpuTip =>
      'Завантажує Geekbench, пропрієтарну програму, і **публікує результат на загальнодоступній сторінці geekbench.com**, включно з моделлю процесора, кількістю ядер і обсягом пам’яті.';

  @override
  String get benchmarkSensitiveOptions =>
      'Наведені нижче параметри завантажують і запускають стороннє програмне забезпечення на цьому сервері або надсилають відомості про сервер третім сторонам. За замовчуванням вони вимкнені.';

  @override
  String get benchmarkIpInfoTip =>
      'Передає публічну адресу цього сервера сервісу ip-api.com через незашифрований HTTP.';

  @override
  String get benchmarkIpInfo => 'Дізнатися власника IP-адреси';

  @override
  String get benchmarkPreferBin => 'Завантажити fio та iperf3';

  @override
  String get benchmarkPreferBinTip =>
      'Завантажує їх із GitHub замість використання пакетів хоста. Вмикайте лише тоді, коли на хості не встановлено жодної із цих програм.';

  @override
  String get benchmarkWorkDir => 'Робочий каталог';

  @override
  String get benchmarkWorkDirTip =>
      'Визначає файлову систему для тестування диска. Якщо залишити поле порожнім, буде використано домашній каталог облікового запису.';

  @override
  String benchmarkEstimatedTime(int minutes) {
    return 'Близько $minutes хв.';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Близько $size трафіку';
  }

  @override
  String get benchmarkPhaseSystem => 'Зчитування інформації про систему';

  @override
  String get benchmarkPhaseDisk => 'Тестування диска';

  @override
  String get benchmarkPhaseNetwork => 'Тестування мережі';

  @override
  String get benchmarkPhaseCpu => 'Тестування процесора';

  @override
  String get benchmarkPhaseDone => 'Завершення';

  @override
  String get benchmarkResultUnreadable =>
      'Не вдалося прочитати цей результат як JSON. Нижче наведено початковий текст.';

  @override
  String get benchmarkViewOnGeekbench => 'Відкрити в Geekbench';

  @override
  String get benchmarkGeekbenchPublic =>
      'Цей результат загальнодоступний за наведеним вище посиланням.';

  @override
  String get benchmarkSingleCore => 'Одне ядро';

  @override
  String get benchmarkMultiCore => 'Кілька ядер';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Надсилання';

  @override
  String get benchmarkRecv => 'Отримання';

  @override
  String get benchmarkLatency => 'Затримка';

  @override
  String get benchmarkVirt => 'Віртуалізація';

  @override
  String get benchmarkRawLog => 'Журнал виконання';

  @override
  String benchmarkUpstream(String version) {
    return 'На основі Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'Запуск';

  @override
  String get benchmarkNoOutputYet =>
      'Виводу ще немає. Перед виведенням першого рядка YABS перевіряє доступність google.com та icanhazip.com. У мережах, де заблоковано хоча б один із цих сайтів, перевірка може тривати кілька хвилин.';

  @override
  String get tagsEmptyTip =>
      'Тегів ще немає. Додайте тег під час редагування сервера, і він з’явиться тут.';

  @override
  String get benchmarkNoServers =>
      'Спочатку додайте сервер, а потім поверніться, щоб запустити бенчмарк.';

  @override
  String get schemaTooNewTitle => 'Ці дані новіші за програму';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Їх записала новіша версія ServerBox (версія сховища v$stored); ця версія читає дані до v$supported. Дані не змінювалися.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Перевстановіть новішу версію, і всі дані знову відкриються як раніше.';

  @override
  String get schemaTooNewExportPlain => 'Експортувати без пароля';

  @override
  String get schemaTooNewPlainWarn =>
      'Файл міститиме у відкритому вигляді всі закриті ключі SSH, паролі серверів і ключі API. Той, хто отримає файл, отримає доступ до всього цього.';

  @override
  String get schemaTooNewWipe => 'Видалити всі дані';

  @override
  String get schemaTooNewWipeConfirm =>
      'Усі сервери, ключі, фрагменти коду та налаштування на цьому пристрої буде видалено без можливості скасування. Експортована тут резервна копія стане єдиною копією, що залишиться.';

  @override
  String get schemaTooNewWipeDone =>
      'Дані видалено. Відкрийте програму знову, щоб почати з чистого аркуша.';

  @override
  String get schemaTooNewWipeFailed =>
      'Не вдалося видалити частину даних, і ця версія досі не може відкрити те, що залишилося. Перевстановіть новішу версію, щоб отримати до них доступ.';

  @override
  String get systemUsers => 'Users';

  @override
  String get userManagerLinuxOnly =>
      'Керування системними користувачами зараз підтримується лише на серверах Linux.';

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
      'Зміни користувача root одразу застосовуються до всіх сеансів.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Додаткові групи';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Створити домашній каталог';

  @override
  String get userMoveHome =>
      'Перемістити наявний домашній каталог у разі зміни шляху';

  @override
  String get userRemoveHome => 'Видалити домашній каталог';

  @override
  String get userPasswordCreateTip =>
      'Залиште пароль порожнім, щоб створити обліковий запис із заблокованим входом за паролем.';

  @override
  String get userPasswordEditTip =>
      'Залиште поле порожнім, щоб зберегти поточний пароль.';

  @override
  String funcUnavailableFmt(String func) {
    return '$func недоступно через це підключення до сервера.';
  }

  @override
  String get rangeLive => 'У реальному часі';

  @override
  String get diskIo => 'Диск (введення-виведення)';

  @override
  String get peak => 'пік';

  @override
  String get hardware => 'Обладнання';

  @override
  String get cores => 'Ядра';

  @override
  String get historyNoStored =>
      'Історію зберігає лише агент monitor. Це підключення зберігає тільки те, що застосунок побачив після підключення.';

  @override
  String get noHistoryYet => 'Вимірювань ще немає';

  @override
  String get noData => 'немає даних';

  @override
  String get from => 'Від';

  @override
  String get to => 'До';

  @override
  String get beyondRetention => 'далі, ніж зберігає цей агент';

  @override
  String agentRetentionFmt(String kept) {
    return 'Агент зберігає $kept';
  }

  @override
  String oldestSampleFmt(String time) {
    return 'найстаріший замір $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'Кінець діапазону має бути пізніше за початок.';

  @override
  String get samples => 'замірів';

  @override
  String get unavailable => 'недоступно';

  @override
  String get metricUnavailableTip =>
      'Решта сторінки не зачеплена. Перевірте на хості команду, з якої береться це значення.';

  @override
  String get waitingFirstSample => 'Очікування першого заміру';

  @override
  String atTimeFmt(String time) {
    return 'о $time';
  }

  @override
  String get stored => 'збережено';

  @override
  String lastSampleFmt(String ago) {
    return 'останній замір $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Усе нижче — станом на $time ($ago).';
  }

  @override
  String noDataBeforeFmt(String time) {
    return 'немає даних до $time';
  }

  @override
  String loadingRangeFmt(String range) {
    return 'Завантаження $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return 'Немає збереженої історії для «$metric»';
  }

  @override
  String devicesFmt(int count) {
    return 'пристроїв: $count';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return 'пристроїв: $count · найзавантаженіший — $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$plotted із $total пристроїв';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return 'датчиків: $count · найгарячіший — $name';
  }

  @override
  String get oneDeviceAtLeast =>
      'Щонайменше один пристрій лишається на графіку.';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$shown із $total ($what)';
  }

  @override
  String countOfFmt(int count, String what) {
    return '$what: $count';
  }

  @override
  String get unitDevices => 'пристрої';

  @override
  String get unitSensors => 'датчики';

  @override
  String get unitBatteries => 'батареї';

  @override
  String get unitCommands => 'команди';

  @override
  String get unitReadings => 'показники';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => 'найгарячіший';

  @override
  String get oldest => 'найстаріший';

  @override
  String get notApplicable => 'не застосовно';

  @override
  String get attributes => 'атрибути';

  @override
  String get powerOnHours => 'Годин роботи';

  @override
  String get powerCycles => 'Циклів увімкнення';

  @override
  String get lifeLeft => 'Залишок ресурсу';

  @override
  String get lifetimeWrite => 'Усього записано';

  @override
  String get lifetimeRead => 'Усього прочитано';

  @override
  String get averageErase => 'Середня кількість стирань';

  @override
  String get unsafeShutdowns => 'Аварійних вимкнень';

  @override
  String get diskAllPassed => 'усі PASSED';

  @override
  String diskWarningFmt(int count) {
    return 'попереджень: $count';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$wrong із $total пристроїв';
  }

  @override
  String get diskSmartSortedTip => 'Найгірші вгорі';

  @override
  String readAgoFmt(String ago) {
    return 'прочитано $ago';
  }

  @override
  String processesFmt(int count) {
    return 'процесів: $count';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count з помилками';
  }

  @override
  String get diskSmartOpenTip => 'Натисніть, щоб побачити атрибути';

  @override
  String get cycle => 'Цикли';

  @override
  String get window => 'вікно';

  @override
  String ofFmt(String total) {
    return 'з $total';
  }

  @override
  String get serverDetailCards => 'Картки сторінки деталей';

  @override
  String get connection => 'З\'єднання';

  @override
  String get connectionTip =>
      'Обидва можуть бути увімкнені одночасно. Порядок — це порядок, у якому до них звертаються.';

  @override
  String transportOrderFmt(String first, String second) {
    return 'Перетягніть, щоб змінити порядок. Спершу $first; якщо він не відповідає, сеанс бере на себе $second.';
  }

  @override
  String transportOnlyFmt(String name) {
    return 'Увімкнено лише $name, тож перемикатися нема на що.';
  }

  @override
  String get transportNoneOn =>
      'Обидва вимкнені — до цього сервера неможливо під\'єднатися.';

  @override
  String get transportOffKept =>
      'вимкнено — налаштування збережено, звернень немає';

  @override
  String get transportDialledFirst => 'звертаємось першим';

  @override
  String get transportFallback => 'запасний';

  @override
  String get transportOnlyMethod => 'єдиний спосіб';

  @override
  String get transportOff => 'вимкнено';

  @override
  String get thisDevice => 'Цей пристрій';

  @override
  String get localServerTip =>
      'Зчитує цей пристрій напряму, запускаючи тут скрипт стану. SSH і Monitor HTTP не використовуються, їхні налаштування зберігаються.';

  @override
  String get localServerUnsupported =>
      'На цій платформі не можна читати цей пристрій як сервер. Підтримуються Linux, Windows і DMG-збірка для macOS.';

  @override
  String get remoteDesktopIntro =>
      'Відкриває робочий стіл RDP або VNC сервера просто в застосунку. З\'єднання йде через SSH-з\'єднання сервера або його агент Monitor, тому порт робочого столу не потрібно відкривати в мережу.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Зберігайте профіль для кожного робочого столу через кнопку «Віддалений робочий стіл» на сервері або на вкладці «Віддалений робочий стіл».';

  @override
  String get localServerIntro =>
      'Додає пристрій, на якому працює ServerBox, як сервер. Стан, процеси, служби, контейнери, термінал і файли працюють без SSH і агента Monitor.';

  @override
  String get localServerAdd => 'Додати цей пристрій';

  @override
  String get localServerIntroFooter =>
      'Це можна ввімкнути й пізніше на сторінці редагування сервера, у розділі «З\'єднання».';

  @override
  String get transportSectionOff =>
      'Вимкнено. Поля нижче збережено на той випадок, коли ви ввімкнете його знову.';

  @override
  String get monitorAgent => 'Агент monitor';

  @override
  String get plainHttpEditTip =>
      'Облікові дані й показники йдуть мережею без шифрування. Обмежтеся локальною мережею чи адресою Tailscale або поставте агента за TLS.';

  @override
  String get behaviour => 'Поведінка';

  @override
  String get optional => 'Необов\'язкове';

  @override
  String get optionalTip =>
      'Нічого з цього не потрібно для під\'єднання. Відкрийте один — і його поля займуть місце форми.';

  @override
  String get sshAdvanced => 'SSH, додатково';

  @override
  String get sshAdvancedTip =>
      'Запасна адреса, ProxyCommand, проміжний сервер, передавання файлів, шлях на сервері';

  @override
  String get sshLegacyAlgorithms => 'Застарілі алгоритми';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Для старих SSH-серверів, наприклад маршрутизаторів або комутаторів, які пропонують лише SHA-1-ключ хоста `ssh-rsa` або SHA-1-обмін ключами. Менш безпечно; вмикайте лише для хостів, яким це потрібно.';

  @override
  String get appearanceAndPlace => 'Вигляд і місце';

  @override
  String get appearanceAndPlaceTip => 'Логотип, координати';

  @override
  String get statusCollection => 'Збір статусу';

  @override
  String get statusCollectionTip =>
      'Які команди виконуються, власні команди, який пристрій читати';

  @override
  String get tagAllTags => 'Усі теги';

  @override
  String get tagMatching => 'Збіги';

  @override
  String get tagNewHint => 'Новий тег';

  @override
  String tagCreateFmt(String tag) {
    return 'Створити #$tag';
  }

  @override
  String get tagOnThisServer => 'на цьому сервері';

  @override
  String tagServersFmt(int count) {
    return 'серверів: $count';
  }

  @override
  String tagOnThisServerFmt(int count) {
    return '$count на цьому сервері';
  }

  @override
  String get tagMatchesTyped => 'збігається з введеним';

  @override
  String get tagEditorTip =>
      'Введення фільтрує список; кнопка створює тег і одразу ставить його на цей сервер. Олівець перейменовує його на всіх серверах, де він є. Тег, якого немає на жодному сервері, зникає під час збереження.';

  @override
  String get tagRenamesOnSave =>
      'Перейменування застосовуються під час збереження';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'Керування запланованими завданнями зараз підтримується лише на серверах Linux.';

  @override
  String get scheduledTaskUnavailable =>
      'crontab недоступний на цьому сервері.';

  @override
  String get scheduledTaskPreserveTip =>
      'Коментарі, змінні середовища та нерозпізнані рядки в цьому crontab буде збережено.';

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
    return 'Усього: $total · увімкнено: $enabled';
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
      'Якщо вимкнено, рядок записується як коментар.';

  @override
  String scheduledTaskEmptyFmt(String user) {
    return 'У користувача $user немає запланованих завдань. Додані тут завдання записуються до crontab цього облікового запису.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'День місяця';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'День тижня';

  @override
  String get cronErrScheduleEmpty => 'Укажіть розклад.';

  @override
  String get cronErrCommandEmpty => 'Укажіть команду.';

  @override
  String get cronErrLineBreak =>
      'Рядок crontab не може містити перенесення рядків.';

  @override
  String get cronErrMacro =>
      'Макрос має складатися з одного слова, наприклад @reboot.';

  @override
  String get cronErrFieldCount =>
      'Розклад cron має містити п’ять полів або макрос, наприклад @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(int minutes) {
    return 'Кожні $minutes хв.';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'Щогодини о :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'Кожні $hours год.';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'Кожні $hours год. о :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Щодня о $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'У будні о $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Щоразу в $day о $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
    return '$day-го числа кожного місяця о $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart => 'Набуде чинності після перезапуску Agent';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Інтервал розширеного циклу';

  @override
  String get idlePause => 'Призупиняти, якщо ніхто не стежить';

  @override
  String get idlePauseTip =>
      'У розширеному циклі запускаються smartctl, sensors і amd-smi. Якщо призупиняти його, коли жоден клієнт не запитує дані, диск не прокидатиметься без потреби.';

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
      'Метрика: cpu / memory / swap / disk / network / temperature. Фільтр: cpu0 для одного ядра, used / free / avail для пам’яті, rx / tx для мережі; для диска й температури він ігнорується. Поріг: оператор порівняння та значення, наприклад >=80%, >=70c або >10m/s.';

  @override
  String get pushChannels => 'Канали сповіщень';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Задано в Agent, значення приховано';

  @override
  String get pushSecretKeep => 'Залиште порожнім, щоб зберегти';

  @override
  String get pushTestTip =>
      'Надсилає одне сповіщення через канал із поточними налаштуваннями, незалежно від того, збережено їх чи ні.';

  @override
  String get pushTestSent => 'Канал прийняв сповіщення';

  @override
  String get pushTestFailed => 'Канал відхилив сповіщення';

  @override
  String get pushTestMessage => 'Тестове сповіщення від ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'У цьому Agent немає відправника для такого типу каналу, тому його налаштування не показано. Канал можна видалити тут або змінити в config.toml Agent.';

  @override
  String get pushJsonInvalid => 'не є припустимим JSON';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Якщо вимкнено, Agent нічого не видаляє, а його база даних зростає без обмежень.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Запускати очищення кожні';

  @override
  String get retentionMaxDbSize => 'Обмеження розміру бази даних';

  @override
  String get corsOrigins => 'Дозволені джерела CORS';

  @override
  String get corsOriginsTip =>
      'Джерела, з яких вебпанель може звертатися до цього Agent. Порожнє значення дозволяє лише запити з того самого джерела.';

  @override
  String get monitorNoRemoteAccess =>
      'Цей агент налаштовано лише для моніторингу. Тут не можна відкрити термінал, виконувати команди чи переглядати файли. Щоб увімкнути ці функції, відредагуйте розділ [remote_access] у config.toml агента.';

  @override
  String get alerts => 'Сповіщення';

  @override
  String get online => 'онлайн';

  @override
  String get densityCards => 'Картки';

  @override
  String get densityRows => 'Рядки';

  @override
  String get densityGrid => 'Сітка';

  @override
  String get connect => 'Підключити';

  @override
  String get disconnect => 'Відключити';

  @override
  String get searchServerTip =>
      'Шукає назви й адреси — два поля, які редактор запитує першими.';

  @override
  String get addServerTip =>
      'Заповніть одне поле, відскануйте QR-код або імпортуйте файл, яким хтось поділився.';

  @override
  String get move => 'Перемістити';

  @override
  String get moveToTop => 'На початок';

  @override
  String get moveToBottom => 'У кінець';

  @override
  String get groupByTag => 'Групувати за тегом';

  @override
  String get groupByTagTip => 'Теги задаються в редакторі сервера.';

  @override
  String get connecting => 'Підключення…';

  @override
  String get authShort => 'Автор.';

  @override
  String get remoteDesktopFitToWindow => 'За розміром вікна';

  @override
  String get remoteDesktopActualSize => 'Фактичний розмір';

  @override
  String get remoteDesktopZoom => 'Масштаб';

  @override
  String get remoteDesktopViewOnly => 'Лише перегляд';

  @override
  String get remoteDesktopDisableViewOnly => 'Вимкнути режим перегляду';

  @override
  String get remoteDesktopSendClipboardText =>
      'Надіслати текст із буфера обміну';

  @override
  String get remoteDesktopShowKeyboard => 'Показати клавіатуру';

  @override
  String get remoteDesktopMoreControls => 'Інші елементи керування';

  @override
  String get remoteDesktopUseDirectPointer =>
      'Використовувати прямий вказівник';

  @override
  String get remoteDesktopUseTouchpadPointer =>
      'Використовувати вказівник тачпада';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Надіслати Ctrl+Alt+Delete';

  @override
  String get remoteDesktopReconnect => 'Перепідключитися';

  @override
  String get remoteDesktopFullScreen => 'На весь екран';

  @override
  String get remoteDesktopCloseSession => 'Закрити сеанс';

  @override
  String get remoteDesktopConnected => 'Підключено';

  @override
  String get remoteDesktopConnecting => 'Підключення';

  @override
  String get remoteDesktopReconnecting => 'Повторне підключення';

  @override
  String get remoteDesktopDisconnected => 'Відключено';

  @override
  String get remoteDesktopGuideTouch => 'Тачпад';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Один палець рухає вказівник як тачпад, дотик — клік. Дотик двома пальцями — правий клік, перетягування двома — прокручування, щипок — масштаб. Торкніться двічі й не відпускайте палець, щоб перетягувати.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Відкриває екранну клавіатуру. Введений текст надсилається на віддалений робочий стіл.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Припиняє надсилання вказівника й клавіш, щоб дивитися без випадкових кліків.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Тут є Ctrl+Alt+Delete, повторне підключення та повноекранний режим.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'А також прямий вказівник: палець клікає там, де торкається.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'Буфер обміну VNC підтримує лише текст у кодуванні Latin-1.';

  @override
  String get remoteDesktopAddProfile => 'Додати профіль';

  @override
  String get remoteDesktopNoProfiles =>
      'Немає профілів віддаленого робочого стола';

  @override
  String get remoteDesktopAdd => 'Додати віддалений робочий стіл';

  @override
  String get remoteDesktopEdit => 'Редагувати віддалений робочий стіл';

  @override
  String get remoteDesktopTargetTip =>
      'Адресу визначає SSH-сервер або агент Monitor. localhost указує на цю машину.';

  @override
  String get remoteDesktopDomain => 'Домен (необов\'язково)';

  @override
  String get remoteDesktopPassword => 'Пароль (необов\'язково)';

  @override
  String get remoteDesktopSavePassword => 'Зберегти пароль';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Зберігається в зашифрованій базі даних. Резервні копії містять збережені паролі й шифруються лише за наявності пароля резервної копії.';

  @override
  String get remoteDesktopShareSession => 'Поділитися сеансом';

  @override
  String get remoteDesktopProtocol => 'Протокол';

  @override
  String get remoteDesktopUniqueName =>
      'Імена профілів мають бути унікальними для цього сервера.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'Класичні паролі VNC обмежені 8 байтами ASCII.';

  @override
  String get remoteDesktopNameRequired => 'Введіть ім\'я профілю.';

  @override
  String get remoteDesktopHostRequired => 'Введіть цільовий хост.';

  @override
  String get remoteDesktopPortRequired => 'Введіть дійсний порт.';

  @override
  String get remoteDesktopUsernameRequired => 'Введіть ім\'я користувача RDP.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Класичні паролі VNC можуть містити лише символи ASCII.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Потрібне підтвердження сертифіката';

  @override
  String get remoteDesktopWaiting => 'Очікування робочого стола…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Сертифікат віддаленого робочого стола змінився';

  @override
  String get remoteDesktopTrustCertificate => 'Довіряти сертифікату?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'Відбиток сертифіката більше не збігається зі збереженим значенням. Перевірте новий відбиток, перш ніж замінювати довіру.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'Система не змогла перевірити цей сертифікат. Перевірте його відбиток SHA-256, перш ніж продовжити.';

  @override
  String get remoteDesktopReplaceTrust => 'Замінити довіру';

  @override
  String get remoteDesktopTrustReconnect => 'Довіряти й підключитися знову';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'Видалити профіль віддаленого робочого стола «$name»?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Повторне підключення ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Раніше довірений відбиток\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Суб\'єкт: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Видавець: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Дійсний: $start – $end';
  }

  @override
  String appearanceThemeModeLocked(String mode) {
    return 'Ця тема підтримує лише режим «$mode». Щоб змінити режим, виберіть іншу тему.';
  }

  @override
  String get pveAuthToken => 'API-токен';

  @override
  String get pveVersionLow =>
      'Ця функція наразі перебуває на стадії тестування та випробувалася лише на PVE 8+. Будь ласка, використовуйте її з обережністю.';

  @override
  String get pveTokenId => 'ID токена';

  @override
  String get pveTokenSecret => 'Секрет токена';

  @override
  String get pveTokenTip =>
      'Створіть його в PVE: Датацентр → Дозволи → API Tokens. Потрібні права VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit і Sys.Audit на шляхах, які треба показати; якщо ввімкнено розділення привілеїв, надайте їх самому токену.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'Токену $account нічого не видно на цьому хості. Токен із розділенням привілеїв не успадковує права користувача; надайте їх на хості PVE:\n$command\nабо зніміть для токена позначку «Privilege Separation».';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account нічого не видно на цьому хості. Надайте права на хості PVE:\n$command';
  }

  @override
  String get pveTokenIdInvalid =>
      'ID токена має мати вигляд user@realm!tokenid';

  @override
  String get pvePasswordAuthTip =>
      'Вхід виконується від імені користувача SSH у realm PAM з паролем SSH, а якщо SSH використовує ключ — з паролем PVE нижче. За потреби запитується код двофакторної автентифікації.';

  @override
  String get pveCertUnpinned =>
      'Ще нічого не підтверджено. Якщо сертифікат не підписаний довіреним CA, під час наступного підключення його буде показано для підтвердження.';

  @override
  String get pveCertForget => 'Забути сертифікат';

  @override
  String get pveCertForgetTip =>
      'Під час наступного підключення сертифікат PVE знову буде показано для підтвердження.';

  @override
  String get virtualization => 'Віртуалізація';

  @override
  String get virtIntro =>
      'Керування віртуальними машинами й контейнерами на хостах Proxmox VE і libvirt/KVM: стан, керування живленням і консолі.';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE перенесено зі сторінки сервера на цю вкладку. Картка PVE сервера відкриває її тут.';

  @override
  String get virtIntroLibvirt =>
      'Сервер із встановленим virsh з libvirt показується як хост разом із його віртуальними машинами QEMU/KVM.';

  @override
  String get virtIntroTransports =>
      'Обидва працюють через SSH, через агент Monitor або на цьому пристрої.';

  @override
  String get virtIntroTokens =>
      'PVE може входити за допомогою API-токена замість пароля. Налаштовується на сторінці редагування сервера, у розділі PVE.';

  @override
  String get virtIntroInBar => 'Її додано на панель вкладок.';

  @override
  String get virtIntroInMore =>
      'Вона в розділі «Більше». У домашніх вкладках у налаштуваннях її можна перенести на панель вкладок.';

  @override
  String get virtGuests => 'Віртуальні машини';

  @override
  String get virtHosts => 'Хости';

  @override
  String get virtCheckServer => 'Перевірити цей сервер';

  @override
  String get virtCheckAll => 'Перевірити всі сервери';

  @override
  String get virtProbeNotChecked => 'Ще не перевірено';

  @override
  String get virtProbeAbsent => 'Не хост';

  @override
  String virtProbeContainer(String kind) {
    return 'Контейнер $kind';
  }

  @override
  String get virtProbeContainerTip =>
      'Цей сервер працює в контейнері, тобто це гість, а не хост. Керувати ним потрібно з хоста, на якому він запущений.';

  @override
  String get virtProbePve => 'PVE, не налаштовано';

  @override
  String virtPveSetupTip(String version) {
    return 'На цьому сервері працює $version. Вкажіть доступ до API в налаштуваннях сервера (рекомендовано API-токен), щоб керувати тут його віртуальними машинами й контейнерами.';
  }

  @override
  String get virtNoHosts => 'Немає хостів віртуалізації';

  @override
  String get virtNoHostsTip =>
      'Сервер із Proxmox VE та вказаним доступом до API є хостом, як і сервер, на якому відповідає virsh. Інші сервери можна перевірити в перемикачі хостів.';

  @override
  String get virtNoGuests => 'Немає віртуальних машин або контейнерів';

  @override
  String get virtPaused => 'Призупинено';

  @override
  String get virtStarting => 'Запуск…';

  @override
  String get virtStopping => 'Зупинка…';

  @override
  String get virtRebooting => 'Перезавантаження…';

  @override
  String get virtMigrating => 'Міграція…';

  @override
  String get virtBackingUp => 'Резервне копіювання…';

  @override
  String get virtResume => 'Відновити';

  @override
  String get virtOverview => 'Огляд';

  @override
  String get virtConsole => 'Консоль';

  @override
  String get virtConsoleNone =>
      'Для цієї гостьової системи консоль не налаштовано';

  @override
  String get virtConsoleGraphical => 'Графічна';

  @override
  String get virtVncPasswordNeeded => 'Цей дисплей вимагає пароль';

  @override
  String get virtConsoleSerialTip =>
      'Відкриває послідовну консоль гостя через virsh на хості. «Від\'єднати» або Ctrl+] повертає до оболонки хоста.';

  @override
  String virtConsoleVia(String transport) {
    return 'через $transport';
  }

  @override
  String get virtConsoleEnterTip => 'Немає виводу? Натисніть Enter';

  @override
  String virtConsoleAutoEnter(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds секунд',
      few: '$seconds секунди',
      one: '$seconds секунду',
    );
    return 'Enter буде натиснуто через $_temp0, щоб показати запрошення';
  }

  @override
  String get virtConsoleEnterNow => 'Зараз';

  @override
  String get virtOffTip =>
      'Запустіть, щоб бачити тут ЦП, пам\'ять, диск і мережу в реальному часі.';

  @override
  String get virtAllocated => 'Виділено';

  @override
  String virtRunningCount(int running, int total) {
    return '$running працюють · усього $total';
  }

  @override
  String get virtTemplate => 'Шаблон';

  @override
  String get virtAutostart => 'Запускається разом із хостом';

  @override
  String get virtErrUnreachable => 'Не вдалося зв\'язатися з цим хостом';

  @override
  String get virtErrNotConfigured => 'Налаштування PVE цього сервера неповні';

  @override
  String get virtErrNotConfiguredTip =>
      'Перевірте адресу, а також пароль або API-токен у налаштуваннях сервера.';

  @override
  String get virtErrAuthFailed => 'Хост відхилив вхід';

  @override
  String get virtErrCertUnconfirmed => 'Підтвердьте сертифікат хоста';

  @override
  String get virtErrCertChanged => 'Сертифікат хоста змінився';

  @override
  String get virtErrRelayNotGranted => 'Агент Monitor не пересилає з\'єднання';

  @override
  String get virtErrExecNotGranted => 'Агент Monitor не виконує команди';

  @override
  String get virtErrNotInstalled => 'virsh не встановлено на цьому сервері';

  @override
  String get virtErrServerRemoved => 'Цей сервер більше не існує';

  @override
  String get virtErrSudoRequired =>
      'Для доступу до libvirt sudo потребує пароль';

  @override
  String get virtErrSudoRejected => 'sudo відхилив пароль';

  @override
  String get virtErrInvalidResponse => 'Хост відповів у неочікуваному вигляді';

  @override
  String get virtErrActionFailed => 'Хост відхилив дію';

  @override
  String get remoteSessionIdleTimeout => 'Закривати після виходу';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'Скільки віддалений робочий стіл або консоль гостя залишаються підключеними після того, як ви їх залишили. Перед закриттям сповіщення дає 10 секунд, щоб зберегти підключення.';

  @override
  String get remoteSessionKeepAlive => 'Не закривати';

  @override
  String get remoteSessionClosedAway => 'Закрито через бездіяльність';

  @override
  String remoteSessionClosingIn(int seconds) {
    return 'Закриється через $seconds с';
  }

  @override
  String get reopen => 'Відкрити знову';

  @override
  String get virtSnapshots => 'Знімки';

  @override
  String get virtSnapshotCreate => 'Зробити знімок';

  @override
  String get virtSnapshotNone => 'Знімків поки немає';

  @override
  String get virtSnapshotWithMemory => 'Диски і пам\'ять';

  @override
  String get virtSnapshotDiskOnly => 'Лише диски';

  @override
  String get virtSnapshotParent => 'Батьківський';

  @override
  String get virtSnapshotRevert => 'Відкотити';

  @override
  String get virtSnapshotMemory => 'Включити пам\'ять';

  @override
  String get virtSnapshotMemoryTip =>
      'Після відкату гість продовжить роботу з цього моменту.';

  @override
  String get virtSnapshotMemoryAlways =>
      'Тут знімок запущеного гостя завжди містить пам\'ять.';

  @override
  String get virtSnapshotMemoryOff =>
      'Гість не запущений, тому зберігаються лише диски.';

  @override
  String get virtSnapshotNameInvalid =>
      'Спочатку літера, далі літери, цифри, - або _; від 2 до 40 символів.';

  @override
  String get virtSnapshotNameTaken => 'Знімок із такою назвою вже існує.';

  @override
  String get virtSnapshotRevertTip =>
      'Відкат скасує всі зміни, зроблені після знімка.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return 'Відкотити $guest до $snapshot? Усі зміни після нього буде втрачено.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'У цьому знімку немає пам\'яті: $guest буде зупинено.';
  }

  @override
  String get virtSnapshotStartAfter => 'Запустити після';

  @override
  String get virtVolumes => 'Томи';

  @override
  String get virtNoPools => 'Немає пулів сховища';

  @override
  String get virtNoNetworks => 'Немає мереж';

  @override
  String get virtPoolInactive =>
      'Пул не активний, тому його томи не можна перелічити.';

  @override
  String get virtShared => 'Спільний для вузлів';

  @override
  String get virtBackingFile => 'Базовий файл';

  @override
  String get virtNetIsolated => 'Ізольована';

  @override
  String get virtNetBridged => 'Міст';

  @override
  String get virtNetRouted => 'Маршрутизована';

  @override
  String get virtBridge => 'Міст';

  @override
  String get virtPorts => 'Порти';

  @override
  String get virtAttachedGuests => 'Гості в ній';

  @override
  String get virtNoAttachedGuests => 'Гостей немає';

  @override
  String get virtCreateVm => 'Нова віртуальна машина';

  @override
  String get virtCreateLxc => 'Новий контейнер';

  @override
  String get virtCreateGuest => 'Нова віртуальна машина або контейнер';

  @override
  String get virtKindVm => 'Віртуальна машина';

  @override
  String get virtKindLxc => 'Контейнер';

  @override
  String get virtHostname => 'Ім\'я хоста';

  @override
  String get virtInstallMedia => 'Інсталяційний носій';

  @override
  String get virtNoIsos => 'На цьому хості немає ISO-образів';

  @override
  String get virtNoTemplates =>
      'На цьому хості немає шаблонів контейнерів. Завантажити шаблон можна в розділі «Шаблони CT» сховища в PVE.';

  @override
  String get virtNoDiskStorage =>
      'На цьому хості немає сховища для нового диска';

  @override
  String get virtStartAfterCreate => 'Запустити після створення';

  @override
  String get virtUnprivileged => 'Непривілейований контейнер';

  @override
  String get virtUnprivilegedTip =>
      'Його root — звичайний користувач на хості.';

  @override
  String get virtSshKeys => 'Відкриті ключі SSH';

  @override
  String get virtCredentialsTip => 'Пароль root, ключі SSH або обидва.';

  @override
  String virtCreated(String name) {
    return '$name створено';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '$name створено, але він не запустився';
  }

  @override
  String get virtErrExists => 'Гість або диск із такою назвою вже існує';

  @override
  String get virtCreateNameInvalidLibvirt =>
      'Літери, цифри, ., _ і -, починаючи з літери або цифри; до 63 символів.';

  @override
  String get virtCreateNameInvalidPve =>
      'Літери, цифри і -, частини розділені крапками; до 63 символів.';

  @override
  String get virtCreateNameTaken => 'Гість із такою назвою вже є.';

  @override
  String get virtCreateVmidInvalid => 'Від 100 до 999999999.';

  @override
  String get virtCreateVmidTaken => 'Цей VMID зайнятий.';

  @override
  String get virtCreateCoresInvalid => 'Більше ядер, ніж дозволяє цей хост.';

  @override
  String get virtCreateMemoryInvalid => 'Замало пам\'яті.';

  @override
  String get virtCreateStorageMissing => 'Виберіть, де буде диск.';

  @override
  String get virtCreateDiskInvalid => 'Від 1 ГіБ до 64 ТіБ.';

  @override
  String get virtCreateTemplateMissing => 'Виберіть шаблон.';

  @override
  String get virtCreateCredentialsMissing =>
      'Задайте пароль root або ключ SSH.';

  @override
  String virtCreatePasswordShort(int min) {
    return 'Щонайменше $min символів.';
  }

  @override
  String get virtCreateSshKeysInvalid =>
      'Один відкритий ключ OpenSSH на рядок.';

  @override
  String get virtDeleteDisks => 'Видалити і його диски';

  @override
  String get virtDeleteDisksPve =>
      'Його диски видаляються разом із ним; інсталяційний носій залишиться.';

  @override
  String virtDeleted(String name) {
    return '$name видалено';
  }

  @override
  String get pveTokenTipCreate =>
      'Для створення й видалення гостей також потрібні VM.Allocate, VM.Config.*, Datastore.AllocateSpace і SDN.Use.';

  @override
  String get pveTokenTipHardware =>
      'Для зміни обладнання потрібні VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.CDROM, VM.Config.Network і VM.Config.Options; для нових дисків та інтерфейсів також Datastore.AllocateSpace і SDN.Use. Для відеокарти та пристроїв USB і PCI потрібна також VM.Config.HWType; для пристрою через зіставлення ресурсів потрібна Mapping.Use на ньому, а для списку зіставлень — Mapping.Audit.';

  @override
  String get pveTokenTipBackup =>
      'Для клонування потрібен VM.Clone, для резервного копіювання й відновлення — VM.Backup, а також Datastore.AllocateSpace на сховищі копії.';

  @override
  String get virtErrConflict => 'Змінено деінде';

  @override
  String get virtErrConflictTip =>
      'Хтось змінив конфігурацію цього гостя після того, як її було прочитано тут, тому нічого не змінено. Її прочитано знову: повторіть зміну, якщо вона ще потрібна.';

  @override
  String get virtHardware => 'Обладнання';

  @override
  String get virtHwAddDisk => 'Додати диск';

  @override
  String get virtHwAddMount => 'Додати точку монтування';

  @override
  String get virtHwAddNic => 'Додати мережевий інтерфейс';

  @override
  String get virtHwAppliesOnRestart =>
      'Збережено. Набуде чинності під час наступного запуску.';

  @override
  String get virtHwAutostart => 'Запускати разом із хостом';

  @override
  String get virtHwAutostartPve => 'onboot · запуск у порядку VMID';

  @override
  String get virtHwBalloonLibvirt => 'Поточна пам\'ять';

  @override
  String get virtHwBalloonNote =>
      'Дозволяє хосту забирати вільну пам\'ять гостя за нестачі пам\'яті';

  @override
  String get virtHwBoot => 'Завантаження';

  @override
  String get virtHwBootOrder => 'Порядок завантаження';

  @override
  String get virtHwBootTip =>
      'Стрілки змінюють порядок; натискання вмикає чи вимикає завантаження з пристрою.';

  @override
  String get virtHwCdrom => 'CD-ROM';

  @override
  String get virtHwConfigFile => 'Файл конфігурації';

  @override
  String get virtHwCores => 'Ядра';

  @override
  String get virtHwCpuTypeDefault => 'Типово';

  @override
  String get virtHwDeleteVolume => 'Також видалити його том';

  @override
  String get virtHwDetach => 'Від\'єднати';

  @override
  String get virtHwDiskHotplug =>
      'Гаряче підключення: можна додати під час роботи';

  @override
  String get virtHwDisksLxc => 'Кореневий диск і точки монтування';

  @override
  String get virtHwEject => 'Вийняти';

  @override
  String get virtHwEmpty => 'Без носія';

  @override
  String get virtHwFirewall => 'Брандмауер';

  @override
  String virtHwFree(String size) {
    return 'вільно $size';
  }

  @override
  String get virtHwGrow => 'Збільшити';

  @override
  String get virtHwGrowNote => 'Диск можна лише збільшити.';

  @override
  String get virtHwGrowNoteRunning =>
      'Диск можна лише збільшити. Після збільшення на ходу розділ треба розширити всередині гостя.';

  @override
  String get virtHwGuestUsed => 'Використовує гість';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'Хост $threads потоків · виділено $allocated';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'Хост $total · виділено $allocated';
  }

  @override
  String get virtHwHotplugNow => 'Гаряче підключення: одразу набуває чинності.';

  @override
  String get virtHwIssueBootEmpty => 'Позначте принаймні один пристрій';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'Загалом від 1 до $max vCPU';
  }

  @override
  String get virtHwIssueCpuOnline =>
      'Активні vCPU: від 1 до загальної кількості';

  @override
  String get virtHwIssueDiskShrink =>
      'Більше за поточний: диски лише збільшуються';

  @override
  String get virtHwIssueDiskSize => 'Від 1 до 65536 ГіБ';

  @override
  String virtHwIssueMemory(int min, int max) {
    return 'Від $min до $max МіБ';
  }

  @override
  String get virtHwIssueMemoryMin => 'Не більше за пам\'ять';

  @override
  String get virtHwIssueMountPoint => 'Абсолютний шлях, наприклад /data';

  @override
  String get virtHwIssueStorageSpace => 'Більше, ніж вільно у сховищі';

  @override
  String get virtHwIssueSwap => 'Не від\'ємне';

  @override
  String get virtHwLater => 'Набуде чинності після перезапуску';

  @override
  String get virtHwLess => 'Менше';

  @override
  String get virtHwLinkDown => 'Від\'єднано';

  @override
  String get virtHwLinkNote =>
      'Вимкнено — гість бачить від\'єднаний кабель; перезапуск не потрібен';

  @override
  String get virtHwLinkUp => 'Під\'єднано';

  @override
  String get virtHwMac => 'MAC-адреса';

  @override
  String get virtHwModel => 'Модель';

  @override
  String get virtHwMore => 'Більше';

  @override
  String get virtHwMountFromPool =>
      'Точки монтування виділяються прямо зі сховища';

  @override
  String get virtHwMountPoint => 'Точка монтування';

  @override
  String get virtHwMoveDown => 'Вниз';

  @override
  String get virtHwMoveUp => 'Вгору';

  @override
  String get virtHwNewDisk => 'Новий диск';

  @override
  String get virtHwNewMount => 'Нова точка монтування';

  @override
  String get virtHwNewNic => 'Новий мережевий інтерфейс';

  @override
  String get virtHwNicHotplug => 'Інтерфейси virtio підключаються на ходу';

  @override
  String get virtHwNics => 'Мережеві інтерфейси';

  @override
  String get virtHwNoMedia => 'Немає носія';

  @override
  String get virtHwNoNetworks => 'Тут немає мереж або мостів';

  @override
  String get virtHwNoStorage => 'Тут немає сховища для дисків';

  @override
  String get virtHwOnline => 'Активні vCPU';

  @override
  String get virtHwPendingBanner =>
      'Частина змін обладнання набуде чинності після перезапуску';

  @override
  String get virtHwPickNet => 'Виберіть мережу';

  @override
  String get virtHwPickPool => 'Виберіть сховище й розмір';

  @override
  String get virtHwProcessor => 'Процесор';

  @override
  String get virtHwRemove => 'Вилучити';

  @override
  String get virtHwRemoveCdrom => 'Вилучити CD-ROM';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return 'Вилучити $disk з $guest?';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return 'Вилучити $nic з $guest?';
  }

  @override
  String get virtHwResources => 'Ресурси';

  @override
  String get virtHwRestartNow => 'Перезапустити';

  @override
  String get virtHwRevert => 'Скасувати';

  @override
  String get virtHwRevertAll => 'Скасувати все';

  @override
  String get virtSetRenameStopped =>
      'Вимкніть гостя, щоб перейменувати: libvirt перейменовує лише гостя, що не працює.';

  @override
  String virtSetIssueDescription(int max) {
    return 'Не більше $max символів, без керувальних символів.';
  }

  @override
  String get virtSetManualStart => 'Запуск вручну';

  @override
  String get virtSetProtection => 'Захист';

  @override
  String get virtSetProtectionNote =>
      'Забороняє видаляти гостя й змінювати його диски';

  @override
  String get virtSetIrreversible => 'Не можна скасувати';

  @override
  String get virtSetDeleteStopFirst => 'Вимкніть його перед видаленням.';

  @override
  String get virtSetDeleteProtected =>
      'Увімкнено захист: спершу вимкніть його в розділі «Загальні».';

  @override
  String get virtSetDeleteAgain => 'Натисніть ще раз для підтвердження';

  @override
  String virtSetDeleteConfirm(String name) {
    return 'Видалити $name';
  }

  @override
  String get virtSetDeleteVm => 'Видалити віртуальну машину';

  @override
  String get virtSetDeleteLxc => 'Видалити контейнер';

  @override
  String get virtHwSockets => 'Сокети';

  @override
  String get virtHwSource => 'Джерело';

  @override
  String get virtHwSwap => 'Підкачка';

  @override
  String get virtHwTopology => 'Сокети × ядра';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets сокет. × $cores ядер × $threads пот.';
  }

  @override
  String virtHwTotal(String size) {
    return 'усього $size';
  }

  @override
  String get virtHwVolumeKept =>
      'Вилучено, але запущений гість ще використовує диск, тому том збережено. Диск буде від\'єднано під час наступного запуску.';

  @override
  String get virtHwBus => 'Шина';

  @override
  String get virtHwCache => 'Кеш';

  @override
  String get virtHwBusStopped => 'Шину можна змінити лише в зупиненого гостя.';

  @override
  String get virtHwMacGenerate => 'Згенерувати';

  @override
  String get virtHwIssueMac =>
      'Потрібна одноадресна MAC-адреса, наприклад 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => 'Спочатку зупиніть гостя';

  @override
  String get virtHwIssueStorageMissing => 'Спочатку виберіть сховище';

  @override
  String get virtHwIssueDevice => 'Спочатку виберіть пристрій';

  @override
  String get virtHwDevices => 'CD-ROM і прокидання';

  @override
  String get virtHwDevicesEmpty => 'Прокидання USB і PCI, CD-ROM, TPM';

  @override
  String get virtHwAddDevice => 'Додати пристрій';

  @override
  String get virtHwNewDevice => 'Новий пристрій';

  @override
  String get virtHwUsbHotplug => 'Прокидання USB підтримує гаряче підключення.';

  @override
  String get virtHwPci => 'Прокидання PCI';

  @override
  String get virtHwIommuOffTitle => 'У хоста немає IOMMU';

  @override
  String get virtHwIommuOffBody =>
      'Спочатку ввімкніть VT-d або AMD-Vi у BIOS хоста та IOMMU в його ядрі. До того гість із PCI-пристроєм не запуститься.';

  @override
  String get virtHwPciTitle => 'Потрібен IOMMU на хості';

  @override
  String get virtHwPciBody =>
      'Після прокидання хост не зможе використовувати пристрій, а гість — мігрувати на ходу.';

  @override
  String virtHwIommuGroup(int group) {
    return 'Група IOMMU $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '$count пристроїв в одній групі IOMMU прокидаються разом';
  }

  @override
  String get virtHwNoHostDevices =>
      'На цьому хості немає пристроїв для прокидання';

  @override
  String get virtHwMappingsOnly =>
      'Тут доступні лише зіставлення ресурсів: PVE дозволяє прокидати пристрій напряму лише root@pam, що увійшов за паролем. Створіть зіставлення в Датацентр → Зіставлення ресурсів.';

  @override
  String get virtHwTpmNote => 'Windows 11 потребує TPM 2.0.';

  @override
  String get virtHwDisplay => 'Дисплей';

  @override
  String get virtHwProtocol => 'Протокол';

  @override
  String get virtHwListen => 'Прослуховування';

  @override
  String get virtHwGpu => 'Відеокарта';

  @override
  String get virtHwListenAllTitle => 'Консоль відкрита в мережу';

  @override
  String get virtHwListenAllBody =>
      'Під час прослуховування всіх адрес консоль може відкрити будь-хто, хто досягає хоста. Залиште 127.0.0.1 і підключайтеся через SSH-тунель.';

  @override
  String get virtHwFirmware => 'Прошивка';

  @override
  String get virtHwUefiSub =>
      'OVMF · підтримує Secure Boot, потрібна для Windows 11';

  @override
  String get virtHwBiosSub => 'SeaBIOS · старі системи та диски MBR';

  @override
  String get virtHwSecureBootNote =>
      'Завантажує лише підписані ядра й завантажувачі';

  @override
  String get virtHwFirmwareWarnTitle =>
      'Не змінюйте прошивку встановленої системи';

  @override
  String get virtHwFirmwareWarnBody =>
      'Перемикання між UEFI і BIOS робить встановлену систему незавантажуваною.';

  @override
  String get virtHwFirmwareStopped =>
      'Прошивку можна змінити лише в зупиненого гостя.';

  @override
  String get virtHwSecureBootVars =>
      'Увімкнення або вимкнення Secure Boot створює змінні EFI заново; збережені в них записи завантаження буде втрачено.';

  @override
  String get virtHwEfiStorage => 'Де зберігати змінні EFI';

  @override
  String get virtHwTpmStorage => 'Де зберігати стан TPM';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return 'Перемкнути $guest на $firmware?';
  }

  @override
  String get virtCloneName => 'Нове імʼя';

  @override
  String get virtCloneFull => 'Повний клон';

  @override
  String get virtCloneCopyDisks => 'Копіювати вміст дисків';

  @override
  String get virtCloneLinkedNote =>
      'Вимк.: повʼязаний клон, що залежить від дисків шаблону';

  @override
  String get virtCloneFullOnly =>
      'Повʼязаний клон можна зробити лише з шаблону';

  @override
  String get virtCloneEmptyNote => 'Вимк.: нові порожні диски того ж розміру';

  @override
  String get virtCloneStopFirst => 'Перед клонуванням вимкніть її.';

  @override
  String get virtCloneFullShort => 'Повний';

  @override
  String get virtCloneLinkedShort => 'Повʼязаний';

  @override
  String get virtCloneEmptyShort => 'Порожні диски';

  @override
  String get virtCloning => 'Клонування…';

  @override
  String virtCloned(String name) {
    return 'Клоновано як $name';
  }

  @override
  String get virtBackupPlan => 'План';

  @override
  String get virtBackupPlanWhere => 'Датацентр → Резервне копіювання';

  @override
  String get virtBackupNoPlanShort => 'Немає плану';

  @override
  String get virtBackupNoPlan =>
      'Жодне планове завдання резервного копіювання не охоплює цей гостьовий хост. Завдання налаштовуються в датацентрі.';

  @override
  String get virtBackupKeep => 'Зберігати';

  @override
  String get virtBackupJobDisabled => 'Це завдання вимкнено.';

  @override
  String virtBackupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count копій',
      few: '$count копії',
      one: '$count копія',
    );
    return '$_temp0';
  }

  @override
  String get virtBackupNoStorage =>
      'На цьому вузлі немає сховища для резервних копій.';

  @override
  String get virtBackupLiveTip => 'Працює: режим snapshot, без зупинки';

  @override
  String get virtBackupStoppedTip => 'Вимкнений: копіюється як є';

  @override
  String get virtBackupNow => 'Створити копію';

  @override
  String get virtBackupNotes => 'Нотатки';

  @override
  String get virtBackupProtected =>
      'Захищена: її не можна видалити, доки захист не знято в PVE.';

  @override
  String virtBackupVerified(String state) {
    return 'Перевірка: $state';
  }

  @override
  String get virtBackupRestoreOverwrites =>
      'Відновлення перезапише поточні диски';

  @override
  String get virtBackupStopFirst => 'Перед відновленням вимкніть її.';

  @override
  String get virtBackupRestoreAgain =>
      'Диски й конфігурацію гостя буде замінено даними з копії.';

  @override
  String get virtBackupDeleteConfirm => 'Видалити копію';

  @override
  String get virtBackupRestoreNew => 'Відновити як новий';

  @override
  String get virtBackupRestoreConfirm => 'Відновити поверх';

  @override
  String get virtBackupDone => 'Копію створено';

  @override
  String get virtBackupDeleted => 'Копію видалено';

  @override
  String virtBackupRestored(String time) {
    return 'Відновлено з $time';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return '$account не має $privilege на $path. Надайте на хості PVE:\n$command';
  }

  @override
  String get virtCanDelete => 'Можна видалити';

  @override
  String get virtInUse => 'Використовується';

  @override
  String get virtOps => 'Дії';

  @override
  String get virtPool => 'Пул зберігання';

  @override
  String get virtPoolNew => 'Новий пул зберігання';

  @override
  String get virtStorageAdd => 'Додати сховище';

  @override
  String virtPoolUsedPct(String pct) {
    return 'Зайнято $pct%';
  }

  @override
  String get virtPoolInUse =>
      'Віртуальна машина використовує том тут, тому пул не можна зупинити чи видалити.';

  @override
  String get virtPoolDelete => 'Видалити пул';

  @override
  String get virtStorageRemove => 'Прибрати сховище';

  @override
  String virtPoolDeleteAsk(String name) {
    return 'Видалити пул $name? Видаляється його визначення; томи лишаються на місці.';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return 'Прибрати сховище $name з конфігурації PVE? Дані на ньому лишаться.';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return 'Його томи ($count) лишаються на диску.';
  }

  @override
  String get virtPoolDeleteStorage => 'Видалити й каталог (лише якщо порожній)';

  @override
  String virtPoolStopAsk(String name) {
    return 'Зупинити пул $name? До запуску не можна буде переглядати й створювати томи.';
  }

  @override
  String virtStorageDisableAsk(String name) {
    return 'Вимкнути сховище $name? ВМ із дисками на ньому не запустяться, доки його знову не ввімкнуть.';
  }

  @override
  String get virtPoolLogicalNote =>
      'Використовується наявна група томів як є; нічого не форматується.';

  @override
  String get virtPoolMountPoint => 'Точка монтування';

  @override
  String get virtPoolSourceNfs => 'Джерело (host:/шлях)';

  @override
  String get virtPoolSourceVg => 'Група томів';

  @override
  String get virtPoolSourceThin => 'Група томів / thin pool';

  @override
  String get virtPoolSourceZfs => 'Пул ZFS';

  @override
  String get virtPoolTypeVg => 'Група томів LVM';

  @override
  String get virtResNameEmpty => 'Введіть назву';

  @override
  String get virtResNameInvalid =>
      'Такої назви хост не прийме (літери, цифри, . _ -)';

  @override
  String get virtResSourceInvalid => 'Недійсний шлях або джерело';

  @override
  String get virtResTargetInvalid => 'Потрібен абсолютний шлях';

  @override
  String get virtResCidrInvalid =>
      'Адреса з префіксом, наприклад 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid =>
      'Дві адреси в мережі за порядком, без адреси хоста';

  @override
  String get virtResSubnetTaken => 'Цю підмережу вже займає інша мережа';

  @override
  String get virtResBridgeInvalid => 'Недійсна назва інтерфейсу';

  @override
  String get virtResFormat => 'Пул не підтримує цей формат';

  @override
  String get virtVolNew => 'Новий том';

  @override
  String virtVolCount(int count) {
    return 'Томів: $count';
  }

  @override
  String get virtVolNone => 'У цьому пулі ще немає томів.';

  @override
  String get virtVolEmptyAttach =>
      'Новий том можна згодом під\'єднати до будь-якої ВМ';

  @override
  String get virtVolEmptyUpload => 'Можна також одразу завантажити ISO';

  @override
  String get virtVolPveName => 'PVE називає том за його ВМ: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => 'Використовує';

  @override
  String get virtVolAllocated => 'Виділено';

  @override
  String get virtVolGrowFromGuest =>
      'Використовується ВМ: збільште його в розділі «Обладнання» цієї ВМ';

  @override
  String get virtVolInUse => 'Цей том використовує ВМ';

  @override
  String get virtVolAttach => 'Під\'єднати до ВМ';

  @override
  String get virtVolAttachNote =>
      'Під\'єднується як новий диск до шини першого диска';

  @override
  String virtVolAttached(String name) {
    return 'Під\'єднано до $name';
  }

  @override
  String get virtVolInsert => 'Вставити в CD-ROM';

  @override
  String virtVolInserted(String name) {
    return 'Вставлено в CD-ROM $name';
  }

  @override
  String virtVolNoCdrom(String name) {
    return 'У $name немає приводу CD-ROM';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return 'Видалити том $name з $pool? Його вміст буде втрачено назавжди.';
  }

  @override
  String get virtUploadIso => 'Завантажити ISO';

  @override
  String virtUploadTo(String pool) {
    return 'Завантажити в $pool';
  }

  @override
  String virtUploadDone(String name) {
    return '$name завантажено';
  }

  @override
  String get virtNetConfig => 'Конфігурація';

  @override
  String get virtNetInternal => 'Внутрішня';

  @override
  String get virtNetBridgePorts => 'Порти мосту';

  @override
  String get virtNetHostBridge => 'Міст хоста';

  @override
  String get virtNetPortsHint => 'eno2; порожньо — внутрішній міст';

  @override
  String get virtNetDhcpRange => 'Діапазон DHCP';

  @override
  String get virtNetDhcpTip => 'dnsmasq роздає ВМ адреси';

  @override
  String get virtNetVlanTip => 'Мережеві карти ВМ можуть мати VLAN-тег';

  @override
  String get virtNetNatTip =>
      'Через хост: ВМ виходять назовні, ззовні до них не потрапити';

  @override
  String get virtNetRoutedTip =>
      'Маршрутизується хостом без NAT: у LAN потрібен зворотний маршрут';

  @override
  String get virtNetIsolatedTip => 'Зв\'язок лише між ВМ і хостом';

  @override
  String get virtNetBridgedTip =>
      'ВМ під\'єднуються до мосту хоста, у його фізичну мережу';

  @override
  String get virtNetNew => 'Нова мережа';

  @override
  String get virtNetNewBridge => 'Новий міст Linux';

  @override
  String get virtNetVirtual => 'Віртуальна мережа';

  @override
  String get virtNetDelete => 'Видалити мережу';

  @override
  String virtNetDeleteAsk(String name) {
    return 'Видалити мережу $name? Її буде зупинено, а визначення видалено.';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return 'Прибрати міст $name з $node? Зараз він вийде з очікуваної конфігурації, а з хоста — після її застосування.';
  }

  @override
  String virtNetInUse(int count) {
    return 'ВМ у цій мережі: $count. Видалити не можна.';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return 'Зупинити $name? $count ВМ у ній втратять мережу до повторного запуску.';
  }

  @override
  String get virtNetInactivePve =>
      'Не активний: новий міст чекає в очікуваній конфігурації до її застосування.';

  @override
  String get virtNetPveApplyNote =>
      'Зберігається як очікувана зміна й набуває чинності після застосування конфігурації (ifreload -a).';

  @override
  String get virtNetPendingSaved =>
      'Збережено як очікуване: застосуйте конфігурацію, щоб зміна набула чинності';

  @override
  String virtNetPendingTitle(String node) {
    return 'Очікувані зміни мережі на $node';
  }

  @override
  String get virtNetPendingTip =>
      'PVE зберігає зміни мережі в interfaces.new до їх застосування.';

  @override
  String get virtNetPendingShow => 'Показати зміни';

  @override
  String get virtNetApply => 'Застосувати конфігурацію';

  @override
  String virtNetApplyAsk(String node) {
    return 'Застосувати очікувану конфігурацію мережі на $node? PVE перезавантажить мережу хоста (ifreload -a): помилка може відрізати хост.';
  }

  @override
  String virtNetRevertAsk(String node) {
    return 'Скасувати очікувану конфігурацію мережі на $node?';
  }

  @override
  String get pveTokenTipStorage =>
      'Керування сховищем потребує Datastore.Allocate на /storage (додавання, вимкнення, видалення), Datastore.AllocateSpace (томи) і Datastore.AllocateTemplate (завантаження); мости Linux і застосування мережевої конфігурації потребують Sys.Modify на вузлі.';

  @override
  String get virtCreateUnnamed => 'Без назви';

  @override
  String get virtCreateNotChosen => 'Не вибрано';

  @override
  String get virtCreateKindVmSub => 'qm · повноцінна віртуальна машина KVM';

  @override
  String get virtCreateKindLxcSub => 'pct · спільне ядро з хостом, легше';

  @override
  String get virtCloudImage => 'Хмарний образ';

  @override
  String get virtCloudImageTip =>
      'Диск із готовою системою: копіюється, збільшується до розміру з розділу «Сховище» й налаштовується cloud-init під час першого завантаження. Сам образ не змінюється.';

  @override
  String get virtNoCloudImagesLibvirt =>
      'Хмарних образів немає: покладіть образ qcow2 або raw у пул (завантажте в «Сховище»), який не використовує жодна ВМ.';

  @override
  String get virtNoCloudImagesPve =>
      'Хмарних образів немає: завантажте образ qcow2, raw або vmdk до сховища з типом вмісту Import (PVE 8.2+).';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 потребує UEFI і TPM 2.0';

  @override
  String get virtCreateWindowsBody => 'Виберіть вище UEFI й увімкніть TPM.';

  @override
  String get virtCreateWindowsNoTpm =>
      'На цьому хості немає програмного TPM (swtpm): встановіть його, щоб дати ВМ TPM.';

  @override
  String virtCreateImageSize(String size) {
    return 'Образ має $size: диск має бути не менший.';
  }

  @override
  String get virtCreateImageMissing => 'Виберіть хмарний образ.';

  @override
  String get virtCreateIncomplete =>
      'Спершу заповніть частини, позначені помаранчевим.';

  @override
  String virtCreateOn(String host) {
    return 'Створюється на $host';
  }

  @override
  String get virtCiTip =>
      'Обліковий запис із sudo; вхід за паролем, SSH-ключем або обома.';

  @override
  String get virtCiUserInvalid =>
      'Малі літери, цифри, _ і -, починаючи з літери або _';

  @override
  String get virtCiCredentialsMissing => 'Задайте пароль або SSH-ключ.';

  @override
  String get virtCiHostnamePve => 'Ім\'я хоста — це ім\'я ВМ.';

  @override
  String get virtCiStatic => 'Статична';

  @override
  String get virtCiAddressInvalid =>
      'IPv4-адреса з префіксом, наприклад 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'IPv4-адреса, наприклад 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => 'Порожньо: з DHCP';

  @override
  String get virtCiDnsInvalid => 'IP-адреси через пробіл або кому';

  @override
  String get virtCiSearch => 'Домен пошуку';

  @override
  String get virtCiSeedNote =>
      'Записується в невеликий ISO поруч із диском, підключається як CD-ROM і видаляється разом із ВМ. Зберігається лише хеш пароля.';

  @override
  String get virtCiNoToolTitle =>
      'На хості немає засобу для створення даних cloud-init';

  @override
  String virtCiNoToolBody(String tools) {
    return 'Встановіть на хост одне з: $tools. Без cloud-init образ запуститься без облікового запису для входу.';
  }

  @override
  String get virtHwCloudInitNote =>
      'Те, що cloud-init читає під час першого завантаження. Не інсталяційний носій: вставляти сюди нічого.';

  @override
  String get virtHwCdromLater =>
      'Поки ВМ працює, привід додасться під час наступного запуску (SATA та IDE не підтримують гаряче підключення).';

  @override
  String virtCreateDiskKept(String size) {
    return 'Диск залишено розміром $size, як у самого образу, — більше за запитаний: диск ніколи не урізається менше за систему на ньому.';
  }

  @override
  String get virtCiEditTip =>
      'Що cloud-init налаштовує в цій ВМ: обліковий запис із sudo, спосіб входу до нього, ім’я хоста й адресу.';

  @override
  String get virtCiForeignTitle =>
      'У цьому seed більше, ніж записує цей застосунок';

  @override
  String get virtCiForeignBody =>
      'Налаштування, зроблені деінде (пакети, команди, інші облікові записи), тут не показано. Збереження замінює seed тим, що показано тут.';

  @override
  String get virtCiPasswordKept => 'Задано. Залиште порожнім, щоб зберегти';

  @override
  String get virtCiRemovePassword => 'Видалити пароль';

  @override
  String get virtCiRemovePasswordNote => 'Вхід лише за SSH-ключем';

  @override
  String get virtCiKeysAdded =>
      'Ключі додаються до облікового запису. Ключ, прибраний тут, лишається в системі, доки його не видалять там, а нове ім’я користувача створює новий обліковий запис поруч зі старим.';

  @override
  String get virtCiEffectTitle =>
      'Набуде чинності під час наступного завантаження';

  @override
  String get virtCiEffectLibvirt =>
      'Збереження записує новий seed із новим ID екземпляра.';

  @override
  String get virtCiEffectPve =>
      'PVE одразу перезаписує свій диск cloud-init; ID екземпляра обчислюється з цих налаштувань, тож будь-яка зміна тут дає новий.';

  @override
  String get virtCiNewInstance =>
      'Під час наступного завантаження cloud-init вважає систему новим екземпляром: заново задає ім’я хоста, створює обліковий запис, якщо його немає, задає пароль, додає ключі й заново записує налаштування мережі. Він також створює нові SSH-ключі хоста, тож SSH-клієнти попередять, що ключ хоста змінився. До цього завантаження нічого не змінюється.';

  @override
  String get virtCiSaved =>
      'Збережено. Набуде чинності під час наступного завантаження.';
}
