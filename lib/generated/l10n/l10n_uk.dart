import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get aboutThanks => 'Дякуємо наступним особам, які взяли участь.';

  @override
  String get acceptBeta => 'Прийняти оновлення бета-версії';

  @override
  String get addSystemPrivateKeyTip => 'Наразі приватних ключів нема, хочете додати той, що йде з системою (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Додано до списку завдань';

  @override
  String get addr => 'Адреса';

  @override
  String get alreadyLastDir => 'Вже в останньому каталозі.';

  @override
  String get authFailTip => 'Авторизація не вдалася, будь ласка, перевірте правильність облікових даних';

  @override
  String get autoBackupConflict => 'Тільки одне автоматичне резервне копіювання може бути активне одночасно.';

  @override
  String get autoConnect => 'Авто підключення';

  @override
  String get autoRun => 'Авто запуск';

  @override
  String get autoUpdateHomeWidget => 'Автоматичне оновлення віджетів на головному екрані';

  @override
  String get backupTip => 'Експортовані дані слабо зашифровані. \nБудь ласка, зберігайте їх у безпеці.';

  @override
  String get backupVersionNotMatch => 'Версія резервного копіювання не збіглася.';

  @override
  String get battery => 'Акумулятор';

  @override
  String get bgRun => 'Запуск у фоновому режимі';

  @override
  String get bgRunTip => 'Цей перемикач лише вказує на те, що програма намагатиметься працювати у фоновому режимі. Чи може вона працювати у фоновому режимі, залежить від прав доступу. Для AOSP-орієнтованих Android ROM, будь ласка, вимкніть \"Оптимізацію акумулятора\" в цьому додатку. Для MIUI / HyperOS, будь ласка, змініть політику економії енергії на \"Нескінченна\".';

  @override
  String get closeAfterSave => 'Зберегти та закрити';

  @override
  String get cmd => 'Команда';

  @override
  String get collapseUITip => 'Сховати довгі списки, що є у UI за замовчуванням';

  @override
  String get conn => 'З\'єднання';

  @override
  String get container => 'Контейнер';

  @override
  String get containerTrySudoTip => 'Наприклад: У застосунку користувач це aaa, але Docker встановлений під користувачем root. У цьому випадку вам потрібно активувати цю опцію.';

  @override
  String get convert => 'Конвертувати';

  @override
  String get copyPath => 'Скопіювати шлях';

  @override
  String get cpuViewAsProgressTip => 'Відобразити використання кожного процесора у вигляді стовпчикової діаграми (старий стиль)';

  @override
  String get cursorType => 'Тип курсора';

  @override
  String get customCmd => 'Користувацькі команди';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Ім\'я Команди\": \"Команда\"';

  @override
  String get decode => 'Декодувати';

  @override
  String get decompress => 'Розпакувати';

  @override
  String get deleteServers => 'Масове видалення серверів';

  @override
  String get dirEmpty => 'Переконайтеся, що директорія пуста.';

  @override
  String get disconnected => 'Відключено';

  @override
  String get disk => 'Диск';

  @override
  String get diskIgnorePath => 'Ігнорувати шлях для диска';

  @override
  String get displayCpuIndex => 'Відобразити індекс ЦП';

  @override
  String dl2Local(Object fileName) {
    return 'Завантажити $fileName на локальний комп\'ютер?';
  }

  @override
  String get dockerEmptyRunningItems => 'Немає запущених контейнерів.\nЦе може бути через:\n- Користувача Docker, відмінного від користувача, налаштованого в додатку\n- змінну оточення DOCKER_HOST, яка не була правильно зчитана. Ви можете виконати `echo \$DOCKER_HOST` у терміналі, щоб побачити її значення.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Всього $count образів';
  }

  @override
  String get dockerNotInstalled => 'Docker не встановлено';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount запущено, $stoppedCount контейнерів зупинено.';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count контейнер(и) запущено.';
  }

  @override
  String get doubleColumnMode => 'Режим подвійної колонки';

  @override
  String get doubleColumnTip => 'Ця опція лише активує функцію, чи можна її насправді включити, залежить від ширини пристрою';

  @override
  String get editVirtKeys => 'Редагувати віртуальні клавіші';

  @override
  String get editor => 'Редактор';

  @override
  String get editorHighlightTip => 'Поточна підсвітка коду не ідеальна і може бути вимкнена для покращення.';

  @override
  String get encode => 'Кодувати';

  @override
  String get envVars => 'Змінні середовища';

  @override
  String get experimentalFeature => 'Експериментальна функція';

  @override
  String get extraArgs => 'Додаткові аргументи';

  @override
  String get fallbackSshDest => 'Резервна SSH адреса';

  @override
  String get fdroidReleaseTip => 'Якщо ви завантажили цей застосунок з F-Droid, рекомендується відключити цю опцію.';

  @override
  String get fgService => 'Служба переднього плану';

  @override
  String get fgServiceTip => 'Після увімкнення деякі моделі пристроїв можуть вилітати. Вимкнення може призвести до того, що деякі моделі не зможуть підтримувати SSH-з\'єднання у фоновому режимі. Будь ласка, дозвольте ServerBox права на сповіщення, фонову роботу та самопробудження в системних налаштуваннях.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Файл \'$file\' занадто великий ($size), макс $sizeMax';
  }

  @override
  String get followSystem => 'Слідувати системі';

  @override
  String get font => 'Шрифт';

  @override
  String get fontSize => 'Розмір шрифту';

  @override
  String get force => 'Примусово';

  @override
  String get fullScreen => 'Повноекранний режим';

  @override
  String get fullScreenJitter => 'Тремтіння в повноекранному режимі';

  @override
  String get fullScreenJitterHelp => 'Щоб уникнути вигоряння екрану';

  @override
  String get fullScreenTip => 'Чи слід увімкнути повноекранний режим під час повороту пристрою в горизонтальне положення? Ця опція стосується лише вкладки сервера.';

  @override
  String get goBackQ => 'Повернутися назад?';

  @override
  String get goto => 'Перейти до';

  @override
  String get hideTitleBar => 'Сховати заголовок';

  @override
  String get highlight => 'Підсвітка коду';

  @override
  String get homeWidgetUrlConfig => 'Налаштувати URL віджета на головному екрані';

  @override
  String get host => 'Хост';

  @override
  String httpFailedWithCode(Object code) {
    return 'Запит не вдався, код статусу: $code';
  }

  @override
  String get ignoreCert => 'Ігнорувати сертифікат';

  @override
  String get image => 'Зображення';

  @override
  String get imagesList => 'Список зображень';

  @override
  String get init => 'Ініціалізувати';

  @override
  String get inner => 'Внутрішній';

  @override
  String get install => 'Встановити';

  @override
  String get installDockerWithUrl => 'Будь ласка, спочатку встановіть Docker. (https://docs.docker.com/engine/install)';

  @override
  String get invalid => 'Недійсний';

  @override
  String get jumpServer => 'Стрибковий Сервер';

  @override
  String get keepForeground => 'Тримати застосунок на передньому плані!';

  @override
  String get keepStatusWhenErr => 'Зберегати останній стан сервера';

  @override
  String get keepStatusWhenErrTip => 'Тільки в разі виникнення помилки під час виконання скрипту';

  @override
  String get keyAuth => 'Аутентифікація ключем';

  @override
  String get letterCache => 'Кешування букв';

  @override
  String get letterCacheTip => 'Рекомендується відключити, але після вимкнення стане неможливим введення CJK (китайських, японських, корейських) символів.';

  @override
  String get license => 'Ліцензія';

  @override
  String get location => 'Місцезнаходження';

  @override
  String get loss => 'втрата пакетів';

  @override
  String madeWithLove(Object myGithub) {
    return 'Зроблено з ❤️ від $myGithub';
  }

  @override
  String get manual => 'Посібник';

  @override
  String get max => 'макс.';

  @override
  String get maxRetryCount => 'Кількість повторних спроб підключення до сервера';

  @override
  String get maxRetryCountEqual0 => 'Знову і знову буде намагатися повторно підключитися.';

  @override
  String get min => 'мін.';

  @override
  String get mission => 'Місія';

  @override
  String get more => 'Більше';

  @override
  String get moveOutServerFuncBtnsHelp => 'Включено: може відображатися під кожною карткою на вкладці Сервер. Вимкнено: може відображатися вгорі на сторінці деталей сервера.';

  @override
  String get ms => 'мс.';

  @override
  String get needHomeDir => 'Якщо ви користувач Synology, [дивіться тут](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Користувачі інших систем повинні знайти інформацію про те, як створити домашній каталог.';

  @override
  String get needRestart => 'Необхідно перезапустити застосунок';

  @override
  String get net => 'Мережа';

  @override
  String get netViewType => 'Тип перегляду мережі';

  @override
  String get newContainer => 'Новий контейнер';

  @override
  String get noLineChart => 'Не використовувати лінійні діаграми';

  @override
  String get noLineChartForCpu => 'Не використовувати лінійні діаграми для ЦП';

  @override
  String get noPrivateKeyTip => 'Приватного ключа немає, можливо, він був видалений або сталася помилка конфігурації.';

  @override
  String get noPromptAgain => 'Більше не запитувати';

  @override
  String get node => 'Вузол';

  @override
  String get notAvailable => 'Недоступний';

  @override
  String get onServerDetailPage => 'На сторінці деталі сервера';

  @override
  String get onlyOneLine => 'Відображати лише в один рядок (прокрутка)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Працює лише тоді, коли кількість ядер перевищує 8';

  @override
  String get openLastPath => 'Відкрити останній шлях';

  @override
  String get openLastPathTip => 'Для різних серверів будуть збережені різні логи. Записується шлях при виході';

  @override
  String get parseContainerStatsTip => 'Парсинг статусу зайнятості Docker є відносно повільним.';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% з $size';
  }

  @override
  String get permission => 'Дозволи';

  @override
  String get pingAvg => 'Середнє:';

  @override
  String get pingInputIP => 'Будь ласка, введіть цільовий IP / Домен.';

  @override
  String get pingNoServer => 'Немає сервера для пінгування.\nБудь ласка, додайте сервер у вкладці `Сервер`.';

  @override
  String get pkg => 'Пакет';

  @override
  String get plugInType => 'Тип вставки';

  @override
  String get port => 'Порт';

  @override
  String get preview => 'Попередній перегляд';

  @override
  String get privateKey => 'Приватний ключ';

  @override
  String get process => 'Процес';

  @override
  String get pushToken => 'Надіслати токен';

  @override
  String get pveIgnoreCertTip => 'Не рекомендується включати, будьте обережні з ризиками безпеки! Якщо ви використовуєте стандартний сертифікат від PVE, вам потрібно увімкнути цю опцію.';

  @override
  String get pveLoginFailed => 'Не вдалося увійти. Неможливо пройти аутентифікацію за допомогою імені користувача/пароля з конфігурації сервера для входу Linux PAM.';

  @override
  String get pveVersionLow => 'Ця функція наразі перебуває на стадії тестування та випробувалася лише на PVE 8+. Будь ласка, використовуйте її з обережністю.';

  @override
  String get pwd => 'Пароль';

  @override
  String get read => 'Читати';

  @override
  String get reboot => 'Перезавантажити';

  @override
  String get rememberPwdInMem => 'Запам\'ятати пароль у пам\'яті';

  @override
  String get rememberPwdInMemTip => 'Використовується для контейнерів, призупинення тощо.';

  @override
  String get rememberWindowSize => 'Запам\'ятати розмір вікна';

  @override
  String get remotePath => 'Віддалений шлях';

  @override
  String get restart => 'Перезапустити';

  @override
  String get result => 'Результат';

  @override
  String get rotateAngel => 'Кут повороту';

  @override
  String get route => 'Маршрут';

  @override
  String get run => 'Запустити';

  @override
  String get running => 'Виконання';

  @override
  String get sameIdServerExist => 'Сервер з таким ID вже існує';

  @override
  String get save => 'Зберегти';

  @override
  String get saved => 'Збережено';

  @override
  String get second => 'сек.';

  @override
  String get sensors => 'Датчики';

  @override
  String get sequence => 'Послідовність';

  @override
  String get server => 'Сервер';

  @override
  String get serverDetailOrder => 'Порядок віджетів на сторінці деталі';

  @override
  String get serverFuncBtns => 'Кнопки функцій сервера';

  @override
  String get serverOrder => 'Порядок сервера';

  @override
  String get sftpDlPrepare => 'Підготовка до підключення...';

  @override
  String get sftpEditorTip => 'Якщо порожньо, використовуйте вбудований редактор файлів програми. Якщо є значення, використовуйте редактор віддаленого сервера, наприклад, `vim` (рекомендується автоматично визначити відповідно до `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Використовуйте `rm -r`, щоб видалити папку в SFTP.';

  @override
  String get sftpSSHConnected => 'SFTP підключено';

  @override
  String get sftpShowFoldersFirst => 'Спочатку відображати директорії';

  @override
  String get showDistLogo => 'Показати логотип дистрибутива';

  @override
  String get shutdown => 'Вимкнення';

  @override
  String get size => 'Розмір';

  @override
  String get snippet => 'Фрагмент';

  @override
  String get softWrap => 'М\'ягкий перенос';

  @override
  String get specifyDev => 'Вказати пристрій';

  @override
  String get specifyDevTip => 'Наприклад, статистика мережевого трафіку за замовчуванням є для всіх пристроїв. Ви можете вказати певний пристрій тут.';

  @override
  String get speed => 'Швидкість';

  @override
  String spentTime(Object time) {
    return 'Витрачений час: $time';
  }

  @override
  String get sshTermHelp => 'Коли термінал прокрутний, горизонтальне проведення вибирає текст. Натискання кнопки клавіатури вмикає/вимикає клавіатуру. Іконка файлу відкриває поточний шлях SFTP. Кнопка буфера обміну копіює вміст, коли текст вибрано, і вставляє вміст з буфера обміну в термінал, коли текст не вибрано і є вміст у буфері обміну. Іконка коду вставляє фрагменти коду в термінал і виконує їх.';

  @override
  String sshTip(Object url) {
    return 'Ця функція наразі в експериментальній стадії. Будь ласка, повідомте про помилки за адресою $url або приєднуйтеся до нашої розробки.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Автоматичне переключення віртуальних клавіш';

  @override
  String get start => 'Старт';

  @override
  String get stat => 'Статистика';

  @override
  String get stats => 'Статистики';

  @override
  String get stop => 'Зупинити';

  @override
  String get stopped => 'Зупинено';

  @override
  String get storage => 'Сховище';

  @override
  String get supportFmtArgs => 'Підтримуються такі параметри форматування:';

  @override
  String get suspend => 'Призупинити';

  @override
  String get suspendTip => 'Функція призупинення потребує адміністративних прав та підтримки systemd.';

  @override
  String switchTo(Object val) {
    return 'Переключитися на $val';
  }

  @override
  String get sync => 'Синхронізація';

  @override
  String get syncTip => 'Може знадобитися перезапуск, щоб деякі зміни набрали чинності.';

  @override
  String get system => 'Система';

  @override
  String get tag => 'Теги';

  @override
  String get temperature => 'Температура';

  @override
  String get termFontSizeTip => 'Це налаштування вплине на розмір терміналу (ширину та висоту). Ви можете масштабувати на сторінці терміналу, щоб налаштувати розмір шрифту поточної сесії.';

  @override
  String get terminal => 'Термінал';

  @override
  String get test => 'Тест';

  @override
  String get textScaler => 'Масштабування тексту';

  @override
  String get textScalerTip => '1.0 => 100% (оригінальний розмір), працює лише на частині шрифта сторінки сервера, не рекомендується змінювати.';

  @override
  String get theme => 'Тема';

  @override
  String get time => 'Час';

  @override
  String get times => 'Рази';

  @override
  String get total => 'Всього';

  @override
  String get traffic => 'Трафік';

  @override
  String get trySudo => 'Спробуйте використовувати sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Невідомо';

  @override
  String get unkownConvertMode => 'Невідомий режим конвертації';

  @override
  String get update => 'Оновити';

  @override
  String get updateIntervalEqual0 => 'Ви встановили 0, автоматичне оновлення не відбудеться.\nНе можна розрахувати статус ЦП.';

  @override
  String get updateServerStatusInterval => 'Інтервал оновлення статусу сервера';

  @override
  String get upload => 'Завантаження';

  @override
  String get upsideDown => 'Доверху дном';

  @override
  String get uptime => 'Час роботи';

  @override
  String get useCdn => 'Використання CDN';

  @override
  String get useCdnTip => 'Нереспонсивним користувачам рекомендується використовувати CDN. Чи хочете ви його використовувати?';

  @override
  String get useNoPwd => 'Пароль не буде використовуватися';

  @override
  String get usePodmanByDefault => 'Використовувати Podman за замовчуванням';

  @override
  String get used => 'Використано';

  @override
  String get view => 'Переглянути';

  @override
  String get viewErr => 'Переглянути помилку';

  @override
  String get virtKeyHelpClipboard => 'Копіювати в буфер обміну, якщо вибраний термінал не порожній, в іншому випадку вставити вміст буфера обміну в термінал.';

  @override
  String get virtKeyHelpIME => 'Увімкнути/вимкнути клавіатуру';

  @override
  String get virtKeyHelpSFTP => 'Відкрити поточний каталог у SFTP.';

  @override
  String get waitConnection => 'Будь ласка, зачекайте, доки з\'єднання буде встановлено.';

  @override
  String get wakeLock => 'Залишити активним';

  @override
  String get watchNotPaired => 'Немає спарованого Apple Watch';

  @override
  String get webdavSettingEmpty => 'Налаштування WebDav порожнє';

  @override
  String get whenOpenApp => 'При відкритті програми';

  @override
  String get wolTip => 'Після налаштування WOL (Wake-on-LAN), при кожному підключенні до сервера відправляється запит WOL.';

  @override
  String get write => 'Записати';

  @override
  String get writeScriptFailTip => 'Запис у скрипт не вдався, можливо, через брак дозволів або каталог не існує.';

  @override
  String get writeScriptTip => 'Після підключення до сервера скрипт буде записано у ~/.config/server_box для моніторингу стану системи. Ви можете переглянути вміст скрипта.';
}
