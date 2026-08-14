// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get acceptBeta => 'Прийняти оновлення бета-версії';

  @override
  String get addSystemPrivateKeyTip =>
      'Наразі приватних ключів нема, хочете додати той, що йде з системою (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Додано до списку завдань';

  @override
  String get addr => 'Адреса';

  @override
  String get askAi => 'Запитати ШІ';

  @override
  String get ai => 'ШІ';

  @override
  String get askAiApiKey => 'Ключ API';

  @override
  String get askAiAwaitingResponse => 'Очікування відповіді ШІ...';

  @override
  String get askAiBaseUrl => 'Базова URL';

  @override
  String get askAiEndpointTip =>
      'Вкажіть базову URL-адресу сервісу або повний ендпоінт Chat Completions чи Responses. ServerBox доповнить шлях відповідно до вибраного протоколу.';

  @override
  String get askAiProtocol => 'Протокол API';

  @override
  String get askAiProtocolTip =>
      '«Авто» використовує Responses для офіційного ендпоінта OpenAI і Chat Completions для сумісних постачальників.';

  @override
  String get askAiProtocolAuto => 'Авто';

  @override
  String get askAiProtocolChatCompletions => 'Chat Completions';

  @override
  String get askAiProtocolResponses => 'Responses';

  @override
  String get askAiCommandInserted => 'Команду вставлено в термінал';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Налаштуйте $fields у налаштуваннях.';
  }

  @override
  String get askAiConfirmExecute => 'Підтвердити перед виконанням';

  @override
  String get askAiConversation => 'Розмова з ШІ';

  @override
  String get askAiDisclaimer => 'ШІ може помилятися. Користуйтеся обережно.';

  @override
  String get askAiFollowUpHint => 'Поставте додаткове запитання...';

  @override
  String get askAiInsertTerminal => 'Вставити в термінал';

  @override
  String get askAiNoResponse => 'Відповідь відсутня';

  @override
  String get askAiRecommendedCommand => 'Команда, запропонована ШІ';

  @override
  String get askAiSelectedContent => 'Вибраний вміст';

  @override
  String get askAiUsageHint => 'Використовується в SSH-терміналі';

  @override
  String get askAiAgentTitle => 'SSH-агент';

  @override
  String get askAiAgentWelcome => 'Що зробимо на цьому сервері?';

  @override
  String get askAiAgentWelcomeTip =>
      'Попросіть діагностику або задачу. Агент пропонує по одній команді й чекає на вашу перевірку, перш ніж щось змінювати.';

  @override
  String get askAiAgentPromptHint =>
      'Попросіть агента щось перевірити або виправити…';

  @override
  String get askAiAgentSend => 'Надіслати агентові';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Проаналізуйте виділений вивід термінала, поясніть, що сталося, і запропонуйте найбезпечніший наступний крок, якщо потрібна дія.';

  @override
  String get askAiTerminalContext => 'Контекст термінала';

  @override
  String get askAiReady => 'Готово';

  @override
  String get askAiThinking => 'Думає';

  @override
  String get askAiRunningCommand => 'Виконується';

  @override
  String get askAiReviewNeeded => 'Перевірити';

  @override
  String get askAiReviewAction => 'Перевірити запропоновану команду';

  @override
  String get askAiReviewBeforeContinuing =>
      'Спершу перевірте або відхиліть запропоновану команду';

  @override
  String get askAiApproveRun => 'Схвалити й виконати';

  @override
  String get askAiDecline => 'Відхилити';

  @override
  String get askAiActionDeclined => 'Запропоновану команду відхилено.';

  @override
  String get askAiInterrupted => 'Відповідь агента перервано.';

  @override
  String get askAiRiskReadOnly => 'Лише читання';

  @override
  String get askAiRiskCaution => 'Змінює систему';

  @override
  String get askAiRiskDestructive => 'Високий ризик';

  @override
  String get askAiHighRiskConfirmTitle => 'Виконати команду з високим ризиком?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Ця команда може видалити дані, зупинити служби або бути важкою для скасування. Уважно перевірте її перед запуском.';

  @override
  String get askAiCommandCancelled => 'Скасовано';

  @override
  String get askAiCommandTimedOut => 'Час вичерпано';

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
      'Автоматичний запуск лише тоді, коли і модель, і локальні перевірки безпеки визначають команду як таку, що лише читає. Команди, які змінюють систему, все одно потребують перевірки.';

  @override
  String get askAiSendOnEnter => 'Enter надсилає';

  @override
  String get askAiSendOnEnterTip =>
      'Enter надсилає повідомлення, Shift+Enter переносить рядок. Якщо вимкнено, навпаки: Enter переносить рядок, а надсилає Cmd/Ctrl+Enter.';

  @override
  String get askAiApiKeyOptional =>
      'Необов\'язково для локальних ендпоінтів і ендпоінтів без автентифікації';

  @override
  String get askAiHistory => 'Історія розмов';

  @override
  String get askAiNewConversation => 'Нова розмова';

  @override
  String get askAiNoHistory => 'Для цього сервера немає збережених розмов';

  @override
  String get askAiNoHistoryMessages => 'Повідомлень ще немає';

  @override
  String get askAiUntitledConversation => 'Нова розмова';

  @override
  String get askAiRenameConversation => 'Перейменувати розмову';

  @override
  String get askAiDeleteConversationTitle => 'Видалити цю розмову?';

  @override
  String get askAiDeleteConversationTip =>
      'Розмову буде видалено з цього пристрою без можливості відновлення.';

  @override
  String get askAiClearHistory => 'Очистити історію';

  @override
  String get askAiClearHistoryTitle =>
      'Очистити історію агента для цього сервера?';

  @override
  String get askAiClearHistoryTip =>
      'Усі розмови агента, збережені для цього сервера, буде видалено з цього пристрою.';

  @override
  String get askAiRestoredReview =>
      'Відновлено з історії. Перевірте ще раз перед запуском; сама вона ніколи не виконається.';

  @override
  String get agentTitle => 'Агент';

  @override
  String get agentWelcome => 'Що зробимо на ваших серверах?';

  @override
  String get agentWelcomeTip =>
      'Попросіть діагностику або експлуатаційну задачу. Агент використовує поточний стан ServerBox і пропонує по одній дії на перевірку.';

  @override
  String get agentPromptHint =>
      'Попросіть агента перевірити сервери або виконати на них дію…';

  @override
  String get agentNoServers => 'Немає налаштованих серверів';

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
  String get agentToolServerBox => 'ServerBox';

  @override
  String get agentToolFailed => 'Не вдалося виконати інструмент.';

  @override
  String get agentFloat => 'Float over other tabs';

  @override
  String get agentToolSshConnect => 'SSH connect';

  @override
  String get agentToolSshDisconnect => 'Disconnect SSH';

  @override
  String get agentSshConnectTitle => 'Connect to a new host';

  @override
  String get agentSshConnectTip =>
      'The Agent wants to open an SSH connection. Type the password here — never into the conversation, where it would be stored and sent to the model.';

  @override
  String get agentAdHocSessions => 'Temporary connections';

  @override
  String get atLeastOneTab => 'Потрібно вибрати принаймні одну вкладку';

  @override
  String get authFailTip =>
      'Авторизація не вдалася, будь ласка, перевірте правильність облікових даних';

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
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Остання копія: $lastModified\nСтан: $remoteState';
  }

  @override
  String get bgRun => 'Запуск у фоновому режимі';

  @override
  String get bgRunTip =>
      'Цей перемикач лише вказує на те, що програма намагатиметься працювати у фоновому режимі. Чи може вона працювати у фоновому режимі, залежить від прав доступу. Для AOSP-орієнтованих Android ROM, будь ласка, вимкніть \"Оптимізацію акумулятора\" в цьому додатку. Для MIUI / HyperOS, будь ласка, змініть політику економії енергії на \"Нескінченна\".';

  @override
  String get clearAllStatsContent =>
      'Ви впевнені, що хочете очистити всю статистику з\'єднань сервера? Цю дію не можна скасувати.';

  @override
  String get clearAllStatsTitle => 'Очистити всю статистику';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Ви впевнені, що хочете очистити статистику з\'єднань для сервера \"$serverName\"? Цю дію не можна скасувати.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Очистити статистику $serverName';
  }

  @override
  String get clearThisServerStats => 'Очистити статистику цього сервера';

  @override
  String get compactDatabase => 'Стиснути базу даних';

  @override
  String compactDatabaseContent(Object size) {
    return 'Розмір бази даних: $size\n\nЦе перебудує базу даних, щоб зменшити розмір файлу. Дані не будуть видалені.';
  }

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
  String get configured => 'Налаштовано';

  @override
  String get customCmd => 'Користувацькі команди';

  @override
  String get deleteServers => 'Масове видалення серверів';

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
  String get discoverySummary => 'Підсумок виявлення';

  @override
  String get diskHealth => 'Стан диска';

  @override
  String get displayCpuIndex => 'Відобразити індекс ЦП';

  @override
  String dl2Local(Object fileName) {
    return 'Завантажити $fileName на локальний комп\'ютер?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Немає запущених контейнерів.\nЦе може бути через:\n- Користувача Docker, відмінного від користувача, налаштованого в додатку\n- змінну оточення DOCKER_HOST, яка не була правильно зчитана. Ви можете виконати `echo \$DOCKER_HOST` у терміналі, щоб побачити її значення.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Всього $count образів';
  }

  @override
  String get dockerProjectOther => 'Інші';

  @override
  String get dockerPruneTip =>
      'Видаліть невикористані дані, щоб звільнити місце на диску';

  @override
  String get dockerStatistics => 'Статистика Docker';

  @override
  String dockerStatusRunningAndStoppedFmt(
    Object runningCount,
    Object stoppedCount,
  ) {
    return '$runningCount запущено, $stoppedCount контейнерів зупинено.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count контейнер(и) запущено.';
  }

  @override
  String get doubleColumnMode => 'Режим подвійної колонки';

  @override
  String get doubleColumnTip =>
      'Ця опція лише активує функцію, чи можна її насправді включити, залежить від ширини пристрою';

  @override
  String get editVirtKeys => 'Редагувати віртуальні клавіші';

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Файл \'$file\' занадто великий ($size), макс $sizeMax';
  }

  @override
  String get finishedAt => 'Завершено о';

  @override
  String get followSystem => 'Слідувати системі';

  @override
  String get fontSize => 'Розмір шрифту';

  @override
  String get fullScreen => 'Повноекранний режим';

  @override
  String get fullScreenJitter => 'Тремтіння в повноекранному режимі';

  @override
  String get fullScreenJitterHelp => 'Щоб уникнути вигоряння екрану';

  @override
  String get fullScreenTip =>
      'Чи слід увімкнути повноекранний режим під час повороту пристрою в горизонтальне положення? Ця опція стосується лише вкладки сервера.';

  @override
  String get githubGist => 'GitHub Gist';

  @override
  String get githubGistIdOptional => 'ID Gist (необов\'язково)';

  @override
  String get githubGistToken => 'Токен GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'Токен порожній';

  @override
  String get goBackQ => 'Повернутися назад?';

  @override
  String get goto => 'Перейти до';

  @override
  String get hideTitleBar => 'Сховати заголовок';

  @override
  String get highlight => 'Підсвітка коду';

  @override
  String get homeTabs => 'Домашні вкладки';

  @override
  String get homeTabsCustomizeDesc =>
      'Налаштуйте, які вкладки відображаються на головній сторінці та їх порядок';

  @override
  String get homeWidgetUrlConfig =>
      'Налаштувати URL віджета на головному екрані';

  @override
  String get ignoreCert => 'Ігнорувати сертифікат';

  @override
  String get image => 'Зображення';

  @override
  String get imagesList => 'Список зображень';

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
  String get pruneDanglingImagesTip =>
      'Видаляє лише висячі образи (шари без тегів).';

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
  String get volume => 'Том';

  @override
  String get pull => 'Pull';

  @override
  String get invalid => 'Недійсний';

  @override
  String get invalidUrl => 'Некоректна URL-адреса';

  @override
  String get invalidHostFormat =>
      'Недійсний формат хоста. Дозволено лише символи IPv4, IPv6 та домену.';

  @override
  String get jumpServer => 'Стрибковий Сервер';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Проміжні сервери для $serverName не знайдено: $jumpIds';
  }

  @override
  String get noJumpServerAvailable => 'Немає доступного проміжного сервера.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Проміжний сервер і ProxyCommand не можна використовувати разом.';

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
  String madeWithLove(Object myGithub) {
    return 'Зроблено з ❤️ від $myGithub';
  }

  @override
  String get maxConcurrency => 'Максимальна паралельність';

  @override
  String get maxRetryCount =>
      'Кількість повторних спроб підключення до сервера';

  @override
  String mismatchSystem(Object system) {
    return 'Невідповідна система: $system';
  }

  @override
  String get more => 'Більше';

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
  String get onlyOneLine => 'Відображати лише в один рядок (прокрутка)';

  @override
  String get openLastPath => 'Відкрити останній шлях';

  @override
  String get openLastPathTip =>
      'Для різних серверів будуть збережені різні логи. Записується шлях при виході';

  @override
  String get parseContainerStatsTip =>
      'Парсинг статусу зайнятості Docker є відносно повільним.';

  @override
  String get fullAccessRefused =>
      'Цей агент не пропонує термінал без облікових даних.';

  @override
  String get fullAccessInsecure =>
      'Цей агент віддає термінал лише через TLS або loopback, а це з\'єднання — відкритий HTTP.';

  @override
  String get permission => 'Дозволи';

  @override
  String get plugInType => 'Тип вставки';

  @override
  String get preferDiskAmount => 'Пріоритетно показувати ємність диска';

  @override
  String get privateKey => 'Приватний ключ';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Приватний ключ [$keyId] не знайдено.';
  }

  @override
  String get pushToken => 'Надіслати токен';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand підтримується лише на настільних платформах.';

  @override
  String get pveIgnoreCertTip =>
      'Не рекомендується включати, будьте обережні з ризиками безпеки! Якщо ви використовуєте стандартний сертифікат від PVE, вам потрібно увімкнути цю опцію.';

  @override
  String get pveServerClientMissing =>
      'SSH-клієнт для цього сервера недоступний.';

  @override
  String get pveAddressMissing =>
      'Не вказано адресу PVE. Налаштуйте її в параметрах сервера.';

  @override
  String get pvePasswordRequired =>
      'Потрібен пароль PVE. Задайте його в параметрах сервера.';

  @override
  String get pveOtpRequired =>
      'На цьому сервері PVE увімкнено двофакторну автентифікацію. Введіть код OTP.';

  @override
  String get pveOtpChallengeExpired =>
      'Термін дії запиту OTP минув. Оновіть і спробуйте ще раз.';

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
  String get pveVersionLow =>
      'Ця функція наразі перебуває на стадії тестування та випробувалася лише на PVE 8+. Будь ласка, використовуйте її з обережністю.';

  @override
  String get pveLoadingForwarding => 'Встановлення SSH-тунелю…';

  @override
  String get pveLoadingLogin => 'Автентифікація в PVE…';

  @override
  String get pveLoadingData => 'Отримання даних кластера…';

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
  String get reconnecting => 'Перепідключення...';

  @override
  String get rememberPwdInMem => 'Запам\'ятати пароль у пам\'яті';

  @override
  String get rememberPwdInMemTip =>
      'Використовується для контейнерів, призупинення тощо.';

  @override
  String get remotePath => 'Віддалений шлях';

  @override
  String get sameIdServerExist => 'Сервер з таким ID вже існує';

  @override
  String get save => 'Зберегти';

  @override
  String get second => 'сек.';

  @override
  String get serverDetailOrder => 'Порядок віджетів на сторінці деталі';

  @override
  String get serverFuncBtns => 'Кнопки функцій сервера';

  @override
  String get serverOrder => 'Порядок сервера';

  @override
  String get serverTabRequired => 'Вкладку сервера не можна видалити';

  @override
  String get shareServerRiskTip =>
      'Цей QR-код містить параметри підключення до сервера у відкритому вигляді, зокрема паролі. Будь-хто, хто його відсканує або сфотографує, зможе підключитися до цього сервера.';

  @override
  String get sftpDlPrepare => 'Підготовка до підключення...';

  @override
  String get sftpEditorTip =>
      'Якщо порожньо, використовуйте вбудований редактор файлів програми. Якщо є значення, використовуйте редактор віддаленого сервера, наприклад, `vim` (рекомендується автоматично визначити відповідно до `EDITOR`).';

  @override
  String get sftpRmrDirSummary =>
      'Використовуйте `rm -r`, щоб видалити папку в SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP підключено';

  @override
  String get sftp => 'SFTP';

  @override
  String get sftpShowFoldersFirst => 'Спочатку відображати директорії';

  @override
  String get size => 'Розмір';

  @override
  String get softWrap => 'М\'ягкий перенос';

  @override
  String get specifyDev => 'Вказати пристрій';

  @override
  String get specifyDevTip =>
      'Наприклад, статистика мережевого трафіку за замовчуванням є для всіх пристроїв. Ви можете вказати певний пристрій тут.';

  @override
  String get tempIsCelsiusTip =>
      'Якщо увімкнено, значення температури вважається градусами Цельсія, а не мілліцельсія. Вмикайте, лише якщо температура показується неправильно (наприклад, 0,1 °C замість 58 °C).';

  @override
  String get speed => 'Швидкість';

  @override
  String spentTime(Object time) {
    return 'Витрачений час: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Всі сервери вже існують (знайдено $duplicateCount дублікатів)';
  }

  @override
  String get ssh => 'SSH';

  @override
  String get sshConnectionModeTip =>
      'Вбудований: використовувати термінал застосунку. Системний SSH: запускати системну команду ssh у зовнішньому терміналі.';

  @override
  String get sshConnectionModeUseBuiltin =>
      'Використовувати вбудований термінал';

  @override
  String get sshConnectionModeUseSystem => 'Використовувати системний SSH';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount дублікатів буде пропущено';
  }

  @override
  String get sshConfigFound => 'Ми знайшли SSH-конфігурацію у вашій системі';

  @override
  String sshConfigFoundServers(Object totalCount) {
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
  String sshConfigImported(Object count) {
    return 'Імпортовано $count серверів з SSH-конфігурації';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'SSH-ключ хоста для $serverName змінено. Продовжуйте лише якщо довіряєте цьому серверу.';
  }

  @override
  String sshHostKeyFingerprintMd5Base64(Object fingerprint) {
    return 'Відбиток (MD5 Base64): $fingerprint';
  }

  @override
  String sshHostKeyFingerprintMd5Hex(Object fingerprint) {
    return 'Відбиток (MD5 hex): $fingerprint';
  }

  @override
  String get sshHostKeyType => 'Тип ключа хоста SSH';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'Отримано новий SSH-ключ хоста від $serverName. Перевірте відбиток перед тим, як довіряти.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
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
  String sshConfigServersToImport(Object importCount) {
    return '$importCount серверів буде імпортовано';
  }

  @override
  String get sshTermHelp =>
      'Коли термінал прокрутний, горизонтальне проведення вибирає текст. Натискання кнопки клавіатури вмикає/вимикає клавіатуру. Іконка файлу відкриває поточний шлях SFTP. Кнопка буфера обміну копіює вміст, коли текст вибрано, і вставляє вміст з буфера обміну в термінал, коли текст не вибрано і є вміст у буфері обміну. Іконка коду вставляє фрагменти коду в термінал і виконує їх.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Автоматичне переключення віртуальних клавіш';

  @override
  String get stat => 'Статистика';

  @override
  String get supportFmtArgs => 'Підтримуються такі параметри форматування:';

  @override
  String get suspendTip =>
      'Функція призупинення потребує адміністративних прав та підтримки systemd.';

  @override
  String switchTo(Object val) {
    return 'Переключитися на $val';
  }

  @override
  String get syncAppSettings => 'Синхронізувати налаштування застосунку';

  @override
  String get syncAppSettingsTip =>
      'Включити тему, компонування, редактор, термінал та інші налаштування пристрою в автоматичну синхронізацію.';

  @override
  String get system => 'Система';

  @override
  String get termFontSizeTip =>
      'Це налаштування вплине на розмір терміналу (ширину та висоту). Ви можете масштабувати на сторінці терміналу, щоб налаштувати розмір шрифту поточної сесії.';

  @override
  String get textScaler => 'Масштабування тексту';

  @override
  String get textScalerTip =>
      '1.0 => 100% (оригінальний розмір), працює лише на частині шрифта сторінки сервера, не рекомендується змінювати.';

  @override
  String get time => 'Час';

  @override
  String get times => 'Рази';

  @override
  String get trySudo => 'Спробуйте використовувати sudo';

  @override
  String get sudoPromptNotFound => 'Наразі немає запиту пароля sudo.';

  @override
  String get unknown => 'Невідомо';

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
  String get viewErr => 'Переглянути помилку';

  @override
  String get virtKeyHelpClipboard =>
      'Копіювати в буфер обміну, якщо вибраний термінал не порожній, в іншому випадку вставити вміст буфера обміну в термінал.';

  @override
  String get virtKeyHelpIME => 'Увімкнути/вимкнути клавіатуру';

  @override
  String get virtKeyHelpSFTP => 'Відкрити поточний каталог у SFTP.';

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
  String get wiki => 'Вікі';

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
  String get portForwardBeta =>
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
  String get portForward_type_local => 'Локальний';

  @override
  String get portForward_type_remote => 'Віддалений';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return 'Видалити $name?';
  }

  @override
  String get sponsor => 'Спонсор';

  @override
  String get sort => 'Сортування';

  @override
  String get sortByName => 'За назвою';

  @override
  String get sortByJoinTime => 'За часом додавання';

  @override
  String get ascending => 'За зростанням';

  @override
  String get descending => 'За спаданням';

  @override
  String get serverHistory => 'Історія сервера';

  @override
  String get clearHistory => 'Очистити історію';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

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
  String get systemd => 'Systemd';

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
  String get watchServers => 'Сервери на годиннику';

  @override
  String get watchServersTip =>
      'Годинник сам звертається до агента monitor цих серверів, тому вибрати можна лише сервери з налаштованим monitor.';

  @override
  String get watchNoMonitorServer =>
      'Жоден сервер не має налаштованого агента monitor';

  @override
  String get watchLegacyUrls => 'Застарілі URL статусу';

  @override
  String get accessoryWidgetServer => 'Сервер для віджета екрана блокування';

  @override
  String get systemdMissing => 'На цьому сервері немає systemd';

  @override
  String get systemdMissingTip =>
      '`systemctl` тут не встановлено, тому юнітів для показу немає.';

  @override
  String initSystemFmt(String init) {
    return 'Схоже, ця машина використовує $init.';
  }

  @override
  String get systemdListFailed => 'Не вдалося отримати список юнітів';

  @override
  String get systemdUserScopeMissing => 'Юніти користувача не показані';

  @override
  String get systemdUserScopeMissingTip =>
      'Цей обліковий запис не має шини сеансу користувача на сервері, тому показано лише системні юніти.';

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
  String get continueInTerminal => 'Продовжити в терміналі';

  @override
  String get browsing => 'Перегляд';
}
