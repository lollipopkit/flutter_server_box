import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get aboutThanks => 'Благодарности всем участникам.';

  @override
  String get acceptBeta => 'Принять обновления тестовой версии';

  @override
  String get addSystemPrivateKeyTip => 'В данный момент приватные ключи отсутствуют. Добавить системный приватный ключ (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Добавлено в список задач';

  @override
  String get addr => 'Адрес';

  @override
  String get alreadyLastDir => 'Уже в корневом каталоге';

  @override
  String get authFailTip => 'Аутентификация не удалась, пожалуйста, проверьте, правильны ли пароль/ключ/хост/пользователь и т.д.';

  @override
  String get autoBackupConflict => 'Может быть включено только одно автоматическое резервное копирование';

  @override
  String get autoConnect => 'Автоматическое подключение';

  @override
  String get autoRun => 'Автозапуск';

  @override
  String get autoUpdateHomeWidget => 'Автоматическое обновление виджета на главном экране';

  @override
  String get backupTip => 'Экспортированные данные зашифрованы простым способом \nПожалуйста, храните их в безопасности.';

  @override
  String get backupVersionNotMatch => 'Версия резервной копии не совпадает, восстановление невозможно';

  @override
  String get battery => 'Батарея';

  @override
  String get bgRun => 'Работа в фоновом режиме';

  @override
  String get bgRunTip => 'Этот переключатель означает, что программа будет пытаться работать в фоновом режиме, но фактическое выполнение зависит от того, включено ли разрешение. Для нативного Android отключите «Оптимизацию батареи» для этого приложения, для MIUI измените контроль активности на «Нет ограничений».';

  @override
  String get cmd => 'Команда';

  @override
  String get collapseUITip => 'Свернуть длинные списки в UI по умолчанию';

  @override
  String get conn => 'Подключение';

  @override
  String get container => 'Контейнер';

  @override
  String get containerTrySudoTip => 'Например: если пользователь в приложении установлен как aaa, но Docker установлен под пользователем root, тогда нужно включить эту опцию';

  @override
  String get convert => 'Конвертировать';

  @override
  String get copyPath => 'Копировать путь';

  @override
  String get cpuViewAsProgressTip => 'Отобразите уровень использования каждого процессора в виде индикатора выполнения (старый стиль)';

  @override
  String get cursorType => 'Тип курсора';

  @override
  String get customCmd => 'Пользовательские команды';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Имя команды\": \"Команда\"';

  @override
  String get decode => 'Декодировать';

  @override
  String get decompress => 'Разархивировать';

  @override
  String get deleteServers => 'Удалить серверы пакетно';

  @override
  String get dirEmpty => 'Пожалуйста, убедитесь, что папка пуста';

  @override
  String get disconnected => 'Отключено';

  @override
  String get disk => 'Диск';

  @override
  String get diskIgnorePath => 'Игнорировать путь к диску';

  @override
  String get displayCpuIndex => 'Отобразить индекс ЦП';

  @override
  String dl2Local(Object fileName) {
    return 'Загрузить $fileName на локальный диск?';
  }

  @override
  String get dockerEmptyRunningItems => 'Нет запущенных контейнеров.\nЭто может быть из-за:\n- пользователя Docker, отличного от пользователя, настроенного в приложении\n- переменной окружения DOCKER_HOST, которая не была правильно считана. Вы можете выполнить `echo \$DOCKER_HOST` в терминале, чтобы увидеть ее значение.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Всего $count образов';
  }

  @override
  String get dockerNotInstalled => 'Docker не установлен';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount запущено, $stoppedCount остановлено';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count контейнеров запущено';
  }

  @override
  String get doubleColumnMode => 'Режим двойной колонки';

  @override
  String get doubleColumnTip => 'Эта опция лишь включает функцию; фактическое применение зависит от ширины устройства';

  @override
  String get editVirtKeys => 'Редактировать виртуальные клавиши';

  @override
  String get editor => 'Редактор';

  @override
  String get editorHighlightTip => 'Текущая производительность подсветки кода неудовлетворительна, можно отключить для улучшения.';

  @override
  String get encode => 'Кодировать';

  @override
  String get envVars => 'Переменная окружения';

  @override
  String get experimentalFeature => 'Экспериментальная функция';

  @override
  String get extraArgs => 'Дополнительные аргументы';

  @override
  String get fallbackSshDest => 'Резервное место назначения SSH';

  @override
  String get fdroidReleaseTip => 'Если вы скачали это приложение с F-Droid, рекомендуется отключить эту опцию.';

  @override
  String get fgService => 'Сервис переднего плана';

  @override
  String get fgServiceTip => 'После включения некоторые модели устройств могут вылетать. Отключение может привести к тому, что некоторые модели не смогут поддерживать SSH-соединения в фоновом режиме. Пожалуйста, разрешите ServerBox права на уведомления, фоновую работу и самопробуждение в системных настройках.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Файл \'$file\' слишком большой \'$size\', превышает $sizeMax';
  }

  @override
  String get followSystem => 'Следовать за системой';

  @override
  String get font => 'Шрифт';

  @override
  String get fontSize => 'Размер шрифта';

  @override
  String get force => 'Принудительно';

  @override
  String get fullScreen => 'Полноэкранный режим';

  @override
  String get fullScreenJitter => 'Вибрация в полноэкранном режиме';

  @override
  String get fullScreenJitterHelp => 'Предотвращение выгорания экрана';

  @override
  String get fullScreenTip => 'Следует ли включить полноэкранный режим, когда устройство поворачивается в альбомный режим? Эта опция применяется только к вкладке сервера.';

  @override
  String get goBackQ => 'Вернуться?';

  @override
  String get goto => 'Перейти к';

  @override
  String get hideTitleBar => 'Скрыть заголовок';

  @override
  String get highlight => 'Подсветка кода';

  @override
  String get homeWidgetUrlConfig => 'Конфигурация URL виджета домашнего экрана';

  @override
  String get host => 'Хост';

  @override
  String httpFailedWithCode(Object code) {
    return 'ошибка запроса, код: $code';
  }

  @override
  String get ignoreCert => 'Игнорировать сертификат';

  @override
  String get image => 'Образ';

  @override
  String get imagesList => 'Список образов';

  @override
  String get init => 'Инициализировать';

  @override
  String get inner => 'Встроенный';

  @override
  String get install => 'установить';

  @override
  String get installDockerWithUrl => 'Пожалуйста, сначала установите Docker по адресу https://docs.docker.com/engine/install';

  @override
  String get invalid => 'Недействительный';

  @override
  String get jumpServer => 'прыжковый сервер';

  @override
  String get keepForeground => 'Пожалуйста, держите приложение в фокусе!';

  @override
  String get keepStatusWhenErr => 'Сохранять статус сервера при ошибке';

  @override
  String get keepStatusWhenErrTip => 'Применимо только в случае ошибки выполнения скрипта';

  @override
  String get keyAuth => 'Аутентификация по ключу';

  @override
  String get letterCache => 'Кэширование букв';

  @override
  String get letterCacheTip => 'Рекомендуется отключить, но после отключения будет невозможно вводить символы CJK.';

  @override
  String get license => 'Лицензия';

  @override
  String get location => 'Местоположение';

  @override
  String get loss => 'Потери пакетов';

  @override
  String madeWithLove(Object myGithub) {
    return 'Создано с ❤️ by $myGithub';
  }

  @override
  String get manual => 'Вручную';

  @override
  String get max => 'максимум';

  @override
  String get maxRetryCount => 'Максимальное количество попыток переподключения к серверу';

  @override
  String get maxRetryCountEqual0 => 'Будет бесконечно пытаться переподключиться';

  @override
  String get min => 'минимум';

  @override
  String get mission => 'Задача';

  @override
  String get more => 'Больше';

  @override
  String get moveOutServerFuncBtnsHelp => 'Включено: кнопки функций сервера отображаются под каждой карточкой на вкладке сервера. Выключено: отображается в верхней части страницы деталей сервера.';

  @override
  String get ms => 'мс';

  @override
  String get needHomeDir => 'Если вы пользователь Synology, [смотрите здесь](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Пользователям других систем нужно искать, как создать домашний каталог.';

  @override
  String get needRestart => 'Требуется перезапуск приложения';

  @override
  String get net => 'Сеть';

  @override
  String get netViewType => 'Тип визуализации сети';

  @override
  String get newContainer => 'Создать контейнер';

  @override
  String get noLineChart => 'Не использовать линейные графики';

  @override
  String get noLineChartForCpu => 'Не используйте линейные графики для ЦП';

  @override
  String get noPrivateKeyTip => 'Приватный ключ не существует, возможно, он был удален или есть ошибка в настройках.';

  @override
  String get noPromptAgain => 'Больше не спрашивать';

  @override
  String get node => 'Узел';

  @override
  String get notAvailable => 'Недоступно';

  @override
  String get onServerDetailPage => 'На странице деталей сервера';

  @override
  String get onlyOneLine => 'Отображать только в одной строке (прокручивается)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Действует только при количестве ядер больше 8';

  @override
  String get openLastPath => 'Открыть последний путь';

  @override
  String get openLastPathTip => 'Для разных серверов будут сохранены разные записи, записывается путь при выходе';

  @override
  String get parseContainerStatsTip => 'Анализ статуса использования Docker может быть медленным';

  @override
  String percentOfSize(Object percent, Object size) {
    return '$percent% от $size';
  }

  @override
  String get permission => 'Разрешения';

  @override
  String get pingAvg => 'В среднем:';

  @override
  String get pingInputIP => 'Пожалуйста, введите целевой IP или домен';

  @override
  String get pingNoServer => 'Нет доступных серверов для Ping\nПожалуйста, добавьте их на вкладке «Сервер» и попробуйте снова';

  @override
  String get pkg => 'Менеджер пакетов';

  @override
  String get plugInType => 'Тип вставки';

  @override
  String get port => 'Порт';

  @override
  String get preview => 'Предпросмотр';

  @override
  String get privateKey => 'Приватный ключ';

  @override
  String get process => 'Процесс';

  @override
  String get pushToken => 'Токен уведомлений';

  @override
  String get pveIgnoreCertTip => 'Не рекомендуется включать, обратите внимание на риски безопасности! Если вы используете стандартный сертификат от PVE, вам нужно включить эту опцию.';

  @override
  String get pveLoginFailed => 'Ошибка входа. Невозможно аутентифицироваться с помощью имени пользователя/пароля из конфигурации сервера для входа в Linux PAM.';

  @override
  String get pveVersionLow => 'Эта функция в настоящее время находится на стадии тестирования и была протестирована только на PVE 8+. Используйте ее с осторожностью.';

  @override
  String get pwd => 'Пароль';

  @override
  String get read => 'Чтение';

  @override
  String get reboot => 'Перезагрузка';

  @override
  String get rememberPwdInMem => 'Запомнить пароль в памяти';

  @override
  String get rememberPwdInMemTip => 'Используется для контейнеров, приостановки и т. д.';

  @override
  String get rememberWindowSize => 'Запомнить размер окна';

  @override
  String get remotePath => 'Удаленный путь';

  @override
  String get restart => 'Перезапустить';

  @override
  String get result => 'Результат';

  @override
  String get rotateAngel => 'Угол поворота';

  @override
  String get route => 'Маршрутизация';

  @override
  String get run => 'Запустить';

  @override
  String get running => 'Запущено';

  @override
  String get sameIdServerExist => 'Сервер с таким ID уже существует';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String get second => 'с';

  @override
  String get sensors => 'Датчики';

  @override
  String get sequence => 'Последовательность';

  @override
  String get server => 'Сервер';

  @override
  String get serverDetailOrder => 'Порядок элементов на странице деталей сервера';

  @override
  String get serverFuncBtns => 'Кнопки функций сервера';

  @override
  String get serverOrder => 'Порядок серверов';

  @override
  String get sftpDlPrepare => 'Подготовка подключения...';

  @override
  String get sftpEditorTip => 'Если пусто, используйте встроенный редактор файлов приложения. Если значение указано, используйте редактор удаленного сервера, например, `vim` (рекомендуется автоматически определять согласно `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Использовать `rm -r` в SFTP для удаления папок';

  @override
  String get sftpSSHConnected => 'SFTP подключен...';

  @override
  String get sftpShowFoldersFirst => 'Показывать папки в начале';

  @override
  String get showDistLogo => 'Показать лого дистрибутива';

  @override
  String get shutdown => 'Выключение';

  @override
  String get size => 'Размер';

  @override
  String get snippet => 'Фрагмент';

  @override
  String get softWrap => 'Мягкий перенос';

  @override
  String get specifyDev => 'Указать устройство';

  @override
  String get specifyDevTip => 'Например, статистика сетевого трафика по умолчанию относится ко всем устройствам. Здесь вы можете указать конкретное устройство.';

  @override
  String get speed => 'Скорость';

  @override
  String spentTime(Object time) {
    return 'Затрачено времени: $time';
  }

  @override
  String get sshTermHelp => 'Когда терминал можно прокручивать, горизонтальное перетаскивание позволяет выделить текст. Нажатие на кнопку клавиатуры включает/выключает клавиатуру. Иконка файла открывает текущий путь SFTP. Кнопка буфера обмена копирует содержимое, когда текст выделен, и вставляет содержимое из буфера обмена в терминал, когда текст не выделен, а в буфере есть содержимое. Иконка кода вставляет фрагменты кода в терминал и выполняет их.';

  @override
  String sshTip(Object url) {
    return 'Эта функция находится в стадии тестирования.\n\nПожалуйста, отправляйте отчеты о проблемах на $url или присоединяйтесь к нашей разработке.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Автоматическое переключение виртуальных клавиш';

  @override
  String get start => 'Старт';

  @override
  String get stat => 'Статистика';

  @override
  String get stats => 'Статистика';

  @override
  String get stop => 'Остановить';

  @override
  String get stopped => 'Остановлено';

  @override
  String get storage => 'Хранение';

  @override
  String get supportFmtArgs => 'Поддерживаются следующие форматы аргументов:';

  @override
  String get suspend => 'Приостановить';

  @override
  String get suspendTip => 'Функция приостановки требует прав root и поддержки systemd.';

  @override
  String switchTo(Object val) {
    return 'Переключиться на $val';
  }

  @override
  String get sync => 'Синхронизировать';

  @override
  String get syncTip => 'Возможно, потребуется перезагрузка, чтобы некоторые изменения вступили в силу.';

  @override
  String get system => 'Система';

  @override
  String get tag => 'Теги';

  @override
  String get temperature => 'Температура';

  @override
  String get termFontSizeTip => 'Эта настройка повлияет на размер терминала (ширина и высота). Вы можете масштабировать страницу терминала, чтобы调整 размер шрифта текущей сессии.';

  @override
  String get terminal => 'Терминал';

  @override
  String get test => 'Тест';

  @override
  String get textScaler => 'Масштабирование текста';

  @override
  String get textScalerTip => '1.0 => 100% (исходный размер), применяется только к части шрифтов на странице сервера, изменение не рекомендуется.';

  @override
  String get theme => 'Тема';

  @override
  String get time => 'Время';

  @override
  String get times => 'Раз';

  @override
  String get total => 'Всего';

  @override
  String get traffic => 'Трафик';

  @override
  String get trySudo => 'Попробовать использовать sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Неизвестно';

  @override
  String get unkownConvertMode => 'Неизвестный режим конвертации';

  @override
  String get update => 'Обновление';

  @override
  String get updateIntervalEqual0 => 'Если установлено 0, статус сервера не будет автоматически обновляться.\nТакже не будет рассчитано использование ЦП.';

  @override
  String get updateServerStatusInterval => 'Интервал обновления статуса сервера';

  @override
  String get upload => 'Загрузить';

  @override
  String get upsideDown => 'Перевернуть';

  @override
  String get uptime => 'Время работы';

  @override
  String get useCdn => 'Использование CDN';

  @override
  String get useCdnTip => 'Не китайским пользователям рекомендуется использовать CDN. Хотели бы вы его использовать?';

  @override
  String get useNoPwd => 'Будет использоваться без пароля';

  @override
  String get usePodmanByDefault => 'Использовать Podman по умолчанию';

  @override
  String get used => 'Использовано';

  @override
  String get view => 'Вид';

  @override
  String get viewErr => 'Просмотр ошибок';

  @override
  String get virtKeyHelpClipboard => 'Если в терминале выделен текст, то он копируется в буфер обмена, в противном случае содержимое буфера вставляется в терминал.';

  @override
  String get virtKeyHelpIME => 'Включить/выключить клавиатуру';

  @override
  String get virtKeyHelpSFTP => 'Открыть текущий путь в SFTP.';

  @override
  String get waitConnection => 'Пожалуйста, дождитесь установки соединения';

  @override
  String get wakeLock => 'Держать включенным';

  @override
  String get watchNotPaired => 'Apple Watch не сопряжены';

  @override
  String get webdavSettingEmpty => 'Настройки Webdav пусты';

  @override
  String get whenOpenApp => 'При открытии приложения';

  @override
  String get wolTip => 'После настройки WOL (Wake-on-LAN) при каждом подключении к серверу отправляется запрос WOL.';

  @override
  String get write => 'Запись';

  @override
  String get writeScriptFailTip => 'Запись скрипта не удалась, возможно, из-за отсутствия прав или потому что, директории не существует.';

  @override
  String get writeScriptTip => 'После подключения к серверу скрипт будет записан в ~/.config/server_box для мониторинга состояния системы. Вы можете проверить содержимое скрипта.';
}
