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
  String askAiConfigMissing(Object fields) {
    return 'Налаштуйте $fields у налаштуваннях.';
  }

  @override
  String get askAiDisclaimer => 'ШІ може помилятися. Користуйтеся обережно.';

  @override
  String get askAiInsertTerminal => 'Вставити в термінал';

  @override
  String get askAiNoResponse => 'Відповідь відсутня';

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
  String agentToolCallsFmt(Object count) {
    return 'Викликів інструментів: $count';
  }

  @override
  String get agentFloat => 'Поверх інших вкладок';

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
  String distIconIntroLegal(Object fontLogos) {
    return 'Ці позначки взято з $fontLogos. Позначка відображає лише те, що цей пристрій прочитав із віддаленої системи, і ці відомості можуть бути хибними або застарілими; вона не позначає похідну збірку, перезбірку чи конкретну версію. Якщо систему не вдалося визначити або її позначки немає, замість неї малюється нейтральний контур.\n\nКожна позначка є торговельною маркою відповідного власника і використовується тут лише для позначення системи, яку вона ідентифікує.';
  }

  @override
  String get distIconTip =>
      'Показувати біля кожного сервера невелику позначку системи, яка на ньому ймовірно працює';

  @override
  String get navTabMenuTip =>
      'Натисніть і утримуйте вкладку — або клацніть правою кнопкою — щоб підключити чи відключити все одразу.';

  @override
  String get remoteBackupPasswordRequired =>
      'Для віддалених резервних копій потрібен непорожній пароль резервного копіювання';

  @override
  String get monitorHttpsRequired =>
      'Віддаленому агенту monitor потрібен HTTPS, якщо для нього не дозволено HTTP.';

  @override
  String get monitorAllowInsecureHttp => 'Дозволити HTTP';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Лише в довіреній приватній мережі, що сама шифрує транспорт, наприклад Tailscale';

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
  String distroSwitchTip(Object from, Object to) {
    return 'Замінити $from на $to. Усе, що встановлено всередині $from, буде видалено, а замість нього буде завантажено й розпаковано $to.';
  }

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
  String fileTooLarge(Object file, Object size, Object sizeMax) {
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
  String get homeWidgetUrlConfig =>
      'Налаштувати URL віджета на головному екрані';

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
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Проміжні сервери для $serverName не знайдено: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '«$name» вже існує';
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
  String get linuxShellTip =>
      'З якої оболонки запускається термінал. Порожньо — повернути /bin/sh.';

  @override
  String get linuxNetTip => 'DNS-сервери. Порожньо — повернути типові значення';

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
  String get rememberPwdInMem => 'Запам\'ятати пароль у пам\'яті';

  @override
  String get rememberPwdInMemTip =>
      'Використовується для контейнерів, призупинення тощо.';

  @override
  String get remotePath => 'Віддалений шлях';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return 'Встановлено $distro $installed, доступний $latest. Оновлення замінить весь контейнер: дані $pm буде втрачено';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Закрийте термінали на $name, перш ніж видаляти';
  }

  @override
  String get rootfsSubtitle =>
      'Користувацьке середовище Linux на цьому пристрої';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
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
  String selected(Object count) {
    return 'Вибрано: $count';
  }

  @override
  String get sendTo => 'Надіслати до…';

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
      'Цей QR-код містить налаштування підключення відкритим текстом. Будь-хто, хто його відсканує чи сфотографує, зможе підключитися.';

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
  String get specifyDev => 'Вказати пристрій';

  @override
  String get specifyDevTip =>
      'Мережевий трафік типово рахується по всіх пристроях; вкажіть один тут';

  @override
  String get tempIsCelsiusTip =>
      'Якщо увімкнено, значення температури вважається градусами Цельсія, а не мілліцельсія. Вмикайте, лише якщо температура показується неправильно (наприклад, 0,1 °C замість 58 °C).';

  @override
  String spentTime(Object time) {
    return 'Витрачений час: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
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
  String get sshHostKeyType => 'Тип ключа хоста SSH';

  @override
  String get sshKnownHostKeys => 'Відомі хости';

  @override
  String get sshKnownHostKeysTip => 'Ключі хостів, які прийняв цей застосунок';

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
  String portForward_deleteConfirmFmt(Object name) {
    return 'Видалити $name?';
  }

  @override
  String get sponsor => 'Спонсор';

  @override
  String get sortByJoinTime => 'За часом додавання';

  @override
  String get serverHistory => 'Історія сервера';

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
      'Годинник сам звертається до monitor, тому доступні лише сервери з ним.';

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
}
