// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get acceptBeta => 'Принять обновления тестовой версии';

  @override
  String get addSystemPrivateKeyTip =>
      'В данный момент приватные ключи отсутствуют. Добавить системный приватный ключ (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Добавлено в список задач';

  @override
  String get askAi => 'Спросить ИИ';

  @override
  String get askAiAwaitingResponse => 'Ожидание ответа ИИ...';

  @override
  String get askAiEndpointTip =>
      'Домен или полный URL. Путь дополняется по выбранному протоколу.';

  @override
  String get askAiProtocolTip =>
      'Авто пробует Responses, затем Chat Completions.';

  @override
  String get askAiCommandInserted => 'Команда вставлена в терминал';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Настройте $fields в настройках.';
  }

  @override
  String get askAiDisclaimer =>
      'ИИ может ошибаться. Используйте с осторожностью.';

  @override
  String get askAiInsertTerminal => 'Вставить в терминал';

  @override
  String get askAiNoResponse => 'Нет ответа';

  @override
  String get askAiAgentWelcome => 'Что сделаем на этом сервере?';

  @override
  String get askAiAgentPromptHint =>
      'Попросите агента что-нибудь проверить или починить…';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Проанализируй выделенный вывод терминала и объясни, что произошло';

  @override
  String get askAiTerminalContext => 'Контекст терминала';

  @override
  String get askAiReviewNeeded => 'Проверить';

  @override
  String get askAiReviewAction => 'Проверить предложенную команду';

  @override
  String get askAiReviewBeforeContinuing =>
      'Сначала проверьте или отклоните текущее предложение';

  @override
  String get askAiApproveRun => 'Одобрить и выполнить';

  @override
  String get askAiDecline => 'Отклонить';

  @override
  String get askAiActionDeclined => 'Предложенная команда отклонена.';

  @override
  String get askAiInterrupted => 'Ответ агента прерван.';

  @override
  String get askAiRiskReadOnly => 'Только чтение';

  @override
  String get askAiRiskCaution => 'Изменяет систему';

  @override
  String get askAiRiskUnvetted => 'Непроверенный хост';

  @override
  String get askAiRiskDestructive => 'Высокий риск';

  @override
  String get askAiHighRiskConfirmTitle => 'Выполнить команду с высоким риском?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Команда может внести изменения, которые трудно отменить. Проверьте внимательно.';

  @override
  String get askAiNoCommandOutput => 'Команда завершилась без вывода.';

  @override
  String get askAiOutputTruncated =>
      'Длинный вывод обрезан перед отправкой обратно агенту.';

  @override
  String get askAiAutoApproved => 'Одобрено автоматически';

  @override
  String get askAiAutoRunSafeCommands =>
      'Автоматически выполнять команды только для чтения';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Выполняется, только если и модель, и локальная проверка считают команду только для чтения';

  @override
  String get askAiSendOnEnter => 'Enter отправляет';

  @override
  String get askAiSendOnEnterTip =>
      'Enter отправляет, Shift+Enter — новая строка. Выкл.: Enter — новая строка, Cmd/Ctrl+Enter отправляет.';

  @override
  String get askAiApiKeyOptional =>
      'Оставьте пустым для локального или без аутентификации';

  @override
  String get askAiHistory => 'История диалогов';

  @override
  String get askAiNewConversation => 'Новый диалог';

  @override
  String get askAiNoHistory => 'Сохранённых бесед пока нет';

  @override
  String get askAiNoHistoryMessages => 'Сообщений пока нет';

  @override
  String get askAiUntitledConversation => 'Без названия';

  @override
  String get askAiRenameConversation => 'Переименовать диалог';

  @override
  String get askAiDeleteConversationTitle => 'Удалить этот диалог?';

  @override
  String get askAiDeleteConversationTip =>
      'Удаляет её с этого устройства. Отменить нельзя.';

  @override
  String get askAiClearHistoryTitle =>
      'Очистить историю агента для этого сервера?';

  @override
  String get askAiClearHistoryTip =>
      'Все сохранённые беседы агента для этого сервера будут удалены.';

  @override
  String get askAiRestoredReview =>
      'Команда взята из истории. Проверьте её снова';

  @override
  String get agentWelcome => 'Что сделаем на ваших серверах?';

  @override
  String get agentWelcomeTip =>
      'Пусть агент разберётся с проблемой или выполнит задачу';

  @override
  String get agentPromptHint =>
      'Попросите агента проверить серверы или выполнить на них действие…';

  @override
  String get agentNoHistory => 'Нет сохранённых глобальных диалогов агента';

  @override
  String get agentClearHistoryTitle => 'Очистить глобальную историю агента?';

  @override
  String get agentClearHistoryTip =>
      'Все глобальные диалоги агента будут удалены с этого устройства.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Чтение файла';

  @override
  String get agentToolWriteFile => 'Запись файла';

  @override
  String get agentToolFailed => 'Не удалось выполнить инструмент.';

  @override
  String agentToolCallsFmt(Object count) {
    return 'Вызовов инструментов: $count';
  }

  @override
  String get agentFloat => 'Поверх других вкладок';

  @override
  String get agentToolSshConnect => 'Подключение по SSH';

  @override
  String get agentToolSshDisconnect => 'Отключить SSH';

  @override
  String get agentSshConnectTitle => 'Подключение к новому хосту';

  @override
  String get agentAuthMethod => 'Аутентификация';

  @override
  String get agentSshConnectTip =>
      'Агенту нужно SSH-подключение. Введите пароль здесь';

  @override
  String get agentAdHocSessions => 'Временные подключения';

  @override
  String get agentSaveServerTitle => 'Сохранить как сервер';

  @override
  String get agentSaveServerTip =>
      'Этот хост и введённый пароль сохраняются на этом устройстве';

  @override
  String get agentMonitorOptional => 'Агент monitor (необязательно)';

  @override
  String get authFailTip =>
      'Не удалось пройти аутентификацию. Проверьте данные';

  @override
  String get autoBackupConflict =>
      'Может быть включено только одно автоматическое резервное копирование';

  @override
  String get autoConnect => 'Автоматическое подключение';

  @override
  String get autoRun => 'Автозапуск';

  @override
  String get autoUpdateHomeWidget =>
      'Автоматическое обновление виджета на главном экране';

  @override
  String get availableTabs => 'Доступные вкладки';

  @override
  String get backupEncrypted => 'Резервная копия зашифрована';

  @override
  String get backupNotEncrypted => 'Резервная копия не зашифрована';

  @override
  String get backupPassword => 'Пароль резервной копии';

  @override
  String get backupPasswordRemoved => 'Пароль резервной копии удален';

  @override
  String get backupPasswordSet => 'Пароль резервной копии установлен';

  @override
  String get backupPasswordTip =>
      'Установите пароль для шифрования файлов резервных копий. Оставьте пустым, чтобы отключить шифрование.';

  @override
  String get backupPasswordWrong => 'Неверный пароль резервной копии';

  @override
  String get connectAll => 'Подключить все';

  @override
  String get disconnectAll => 'Отключить все';

  @override
  String get distIcon => 'Значки дистрибутивов';

  @override
  String get distIconConsent =>
      'Включая это, вы сами решаете показывать эти знаки — исключительно для того, чтобы обозначить дистрибутив, который, судя по всему, работает на сервере.';

  @override
  String get distIconIntroLegal =>
      'Это приложение не содержит никаких знаков дистрибутивов. Если задать адрес, изображение будет загружаться оттуда — источник выбираете вы, а пока он не задан, ничего не отображается. Знак говорит лишь о том, что это устройство прочитало с удалённой системы; эти сведения могут быть неверными или устаревшими и не обозначают ни производную сборку, ни пересборку, ни какую-либо конкретную версию.\n\nКаждый знак является товарным знаком своего владельца и используется здесь только для указания на систему, которую он обозначает.';

  @override
  String get distIconTip =>
      'Показывать рядом с каждым сервером небольшой значок системы, которая на нём предположительно работает';

  @override
  String get distNameMap => 'Сопоставление имён';

  @override
  String get distNameMapTip =>
      'Только для дистрибутива, у которого файл там, где вы размещаете знаки, называется иначе. Ключ — имя, которое использует это приложение, значение — имя, которое нужно загрузить. Оставьте пустым, пока ни один знак не пропадает.';

  @override
  String get logoUrl => 'Адрес логотипа';

  @override
  String get logoUrlTip => 'Большое изображение вверху страницы сервера.';

  @override
  String get markUrl => 'Адрес знака';

  @override
  String get markUrlTip =>
      'Маленький знак рядом с именем сервера в списках. Пусто — не показывать.\n\nЭто не то же изображение, что логотип: рисунок, читаемый во всю ширину, при 20 px превращается в пятно.';

  @override
  String get navTabMenuTip =>
      'Нажмите и удерживайте вкладку — или щёлкните правой кнопкой — чтобы подключить или отключить всё сразу.';

  @override
  String nTags(Object count) {
    return 'Тегов: $count';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Для удалённых резервных копий требуется непустой пароль резервного копирования';

  @override
  String get monitorHttpsRequired =>
      'Удалённому агенту monitor нужен HTTPS, если для него не разрешён HTTP.';

  @override
  String get monitorAllowInsecureHttp => 'Разрешить HTTP';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Только в доверенной частной сети, которая сама шифрует транспорт, например Tailscale';

  @override
  String get backupTip =>
      'Экспортированные данные могут быть зашифрованы паролем. \nПожалуйста, храните их в безопасности.';

  @override
  String get icloudBackupStatusTitle => 'Состояние резервной копии';

  @override
  String get icloudBackupStatusLoading =>
      'Загрузка состояния резервной копии iCloud…';

  @override
  String get icloudBackupStatusError =>
      'Не удалось прочитать метаданные резервной копии iCloud';

  @override
  String get icloudBackupStatusEmpty =>
      'Файл резервной копии в iCloud пока не найден';

  @override
  String get icloudBackupStateUploading => 'Выгружается';

  @override
  String get icloudBackupStateConflict => 'Обнаружен конфликт';

  @override
  String get icloudBackupStateUploaded => 'Выгружено';

  @override
  String get icloudBackupStateWaiting => 'Ожидание iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Последняя копия: $lastModified\nСостояние: $remoteState';
  }

  @override
  String get bgRun => 'Работа в фоновом режиме';

  @override
  String get bgRunTip =>
      'Этот переключатель означает, что программа будет пытаться работать в фоновом режиме, но фактическое выполнение зависит от того, включено ли разрешение. Для нативного Android отключите «Оптимизацию батареи» для этого приложения, для MIUI измените контроль активности на «Нет ограничений».';

  @override
  String get clearAllStatsContent =>
      'Вы уверены, что хотите очистить всю статистику соединений сервера? Это действие не может быть отменено.';

  @override
  String get clearAllStatsTitle => 'Очистить всю статистику';

  @override
  String clearServerStatsContent(Object serverName) {
    return 'Вы уверены, что хотите очистить статистику соединений для сервера \"$serverName\"? Это действие не может быть отменено.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Очистить статистику $serverName';
  }

  @override
  String get clearThisServerStats => 'Очистить статистику этого сервера';

  @override
  String get compactDatabase => 'Сжать базу данных';

  @override
  String compactDatabaseContent(Object size) {
    return 'Размер базы данных: $size\n\nЭто перестроит базу данных для уменьшения размера файла. Данные не будут удалены.';
  }

  @override
  String get closeAfterSave => 'Сохранить и закрыть';

  @override
  String get collapseUITip => 'Свернуть длинные списки в UI по умолчанию';

  @override
  String get connectionDetails => 'Детали соединения';

  @override
  String get connectionStats => 'Статистика соединений';

  @override
  String get connectionStatsDesc =>
      'Просмотр коэффициента успешности подключения к серверу и истории';

  @override
  String get containerTrySudoTip =>
      'Например: если пользователь в приложении установлен как aaa, но Docker установлен под пользователем root, тогда нужно включить эту опцию';

  @override
  String get containerSudoPasswordRequired =>
      'Для доступа к Docker требуется пароль sudo. Пожалуйста, введите ваш пароль.';

  @override
  String get containerSudoPasswordIncorrect =>
      'Пароль sudo неверен или не разрешён. Пожалуйста, попробуйте снова.';

  @override
  String get copyPath => 'Копировать путь';

  @override
  String get cpuViewAsProgressTip =>
      'Отобразите уровень использования каждого процессора в виде индикатора выполнения (старый стиль)';

  @override
  String get customCmd => 'Пользовательские команды';

  @override
  String get deleteServers => 'Удалить серверы пакетно';

  @override
  String get deleteDirRecursive => 'Удалить папку и всё её содержимое';

  @override
  String get desktopTerminalTip =>
      'Команда для открытия эмулятора терминала при запуске SSH-сеансов.';

  @override
  String get dirEmpty => 'Пожалуйста, убедитесь, что папка пуста';

  @override
  String get discoverSshServers => 'Обнаружить SSH серверы';

  @override
  String get discoveryFailed => 'Обнаружение не удалось';

  @override
  String get discoverySettings => 'Настройки обнаружения';

  @override
  String get distro => 'Дистрибутив';

  @override
  String distroSwitchTip(Object from, Object to) {
    return 'Заменить $from на $to. Всё, что установлено внутри $from, будет удалено, а вместо него будет загружен и распакован $to.';
  }

  @override
  String get diskHealth => 'Состояние диска';

  @override
  String get displayCpuIndex => 'Отобразить индекс ЦП';

  @override
  String dl2Local(Object fileName) {
    return 'Загрузить $fileName на локальный диск?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'Нет запущенных контейнеров.\nЭто может быть из-за:\n- пользователя Docker, отличного от пользователя, настроенного в приложении\n- переменной окружения DOCKER_HOST, которая не была правильно считана. Вы можете выполнить `echo \$DOCKER_HOST` в терминале, чтобы увидеть ее значение.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Всего $count образов';
  }

  @override
  String get dockerProjectOther => 'Другое';

  @override
  String get dockerPruneTip =>
      'Удалите неиспользуемые данные, чтобы освободить место на диске';

  @override
  String get dockerStatistics => 'Статистика Docker';

  @override
  String get doubleColumnMode => 'Режим двойной колонки';

  @override
  String get doubleColumnTip =>
      'Эта опция лишь включает функцию; фактическое применение зависит от ширины устройства';

  @override
  String get editVirtKeys => 'Виртуальные клавиши';

  @override
  String get editorHighlightTip =>
      'Текущая производительность подсветки кода неудовлетворительна, можно отключить для улучшения.';

  @override
  String get enableMdns => 'Включить mDNS';

  @override
  String get enableMdnsDesc =>
      'Использовать mDNS/Bonjour для обнаружения SSH служб';

  @override
  String get envVars => 'Переменная окружения';

  @override
  String get extraArgs => 'Дополнительные аргументы';

  @override
  String get fallbackSshDest => 'Резервное место назначения SSH';

  @override
  String get fdroidReleaseTip =>
      'Если вы скачали это приложение с F-Droid, рекомендуется отключить эту опцию.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'Файл \'$file\' слишком большой \'$size\', превышает $sizeMax';
  }

  @override
  String get fileDirGone => 'Этой папки больше нет';

  @override
  String get fileDirGoneTip => 'Он удалён или переименован';

  @override
  String get fullScreen => 'Полный экран';

  @override
  String get fullScreenJitter => 'Вибрация в полноэкранном режиме';

  @override
  String get fullScreenJitterHelp => 'Предотвращение выгорания экрана';

  @override
  String get fullScreenTip =>
      'Следует ли включить полноэкранный режим, когда устройство поворачивается в альбомный режим? Эта опция применяется только к вкладке сервера.';

  @override
  String get githubGistIdOptional => 'ID Gist (необязательно)';

  @override
  String get githubGistToken => 'Токен GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'Токен пуст';

  @override
  String get goto => 'Перейти к';

  @override
  String get homeTabs => 'Вкладки дома';

  @override
  String get homeTabsCustomizeDesc =>
      'Настройте, какие вкладки появляются на главной странице и их порядок';

  @override
  String get homeWidgetUrlConfig => 'Конфигурация URL виджета домашнего экрана';

  @override
  String get ignoreCert => 'Игнорировать сертификат';

  @override
  String get image => 'Образ';

  @override
  String get macDmgBody =>
      'App Store требует запускать это приложение в песочнице, а из песочницы нельзя открыть терминал. Версия DMG может.\n\nВерсия из App Store может перестать обновляться.';

  @override
  String get macDmgImportDenied =>
      'macOS не дал прочитать данные предыдущей версии';

  @override
  String get macDmgImported => 'Данные предыдущей версии импортированы';

  @override
  String get macDmgImportFailed =>
      'Не удалось прочитать данные предыдущей версии';

  @override
  String get macDmgTip =>
      'Локальный терминал и запуск сниппетов локально (версия DMG)';

  @override
  String get macDmgTitle => 'Сборка DMG';

  @override
  String get showHiddenFiles => 'Показывать скрытые файлы';

  @override
  String get sshKeyAlgorithm => 'Алгоритм';

  @override
  String get sshKeyComment => 'Комментарий';

  @override
  String get sshKeyGenerate => 'Создать пару ключей';

  @override
  String get sshKeyGenerating => 'Создание…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'Закрытый ключ [$name] не разблокирован.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Необязательно. Ключ с парольной фразой хранится в зашифрованном виде, и она запрашивается при первом использовании ключа.';

  @override
  String get sshKeyPassphraseWrong => 'Неверная парольная фраза.';

  @override
  String get sshKeyPublicKey => 'Открытый ключ';

  @override
  String get sshKeyPublicKeyTip =>
      'Добавьте эту строку в ~/.ssh/authorized_keys на сервере.';

  @override
  String get sshKeyRecommended => 'Рекомендуется';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Введите парольную фразу закрытого ключа [$name].';
  }

  @override
  String get ungrouped => 'Без группы';

  @override
  String get unused => 'Не используется';

  @override
  String get dangling => 'Висячий';

  @override
  String get pruneUnusedImages => 'Очистить неиспользуемые образы';

  @override
  String get pruneDanglingImages => 'Очистить висячие образы';

  @override
  String get pruneImages => 'Очистить образы';

  @override
  String get unusedTaggedImages => 'Неиспользуемые с тегами';

  @override
  String get pruneDanglingImagesTip => 'Удаляет только висячие образы.';

  @override
  String get pruneUnusedImagesTip =>
      'Также удаляет образы с тегами, не используемые контейнерами.';

  @override
  String get includeUnusedVolumesTip =>
      'Также удаляет тома, не используемые контейнерами.';

  @override
  String get pruneCommandPreview => 'Предпросмотр команды';

  @override
  String get pruneForceSshTip =>
      '-f пропускает интерактивное подтверждение и всегда включён при выполнении через SSH.';

  @override
  String get pruneVolumes => 'Очистить тома';

  @override
  String get pruneUnusedData => 'Очистить неиспользуемые данные';

  @override
  String get pull => 'Pull';

  @override
  String get invalidHostFormat =>
      'Некорректный формат хоста. Допустимы только символы IPv4, IPv6 и доменных имён.';

  @override
  String get jumpServer => 'прыжковый сервер';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'Промежуточные серверы для $serverName не найдены: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '«$name» уже существует';
  }

  @override
  String get noJumpServerAvailable => 'Нет доступного промежуточного сервера.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'Промежуточный сервер и ProxyCommand нельзя использовать вместе.';

  @override
  String get keepForeground => 'Пожалуйста, держите приложение в фокусе!';

  @override
  String get keepStatusWhenErr => 'Сохранять статус сервера при ошибке';

  @override
  String get keepStatusWhenErrTip =>
      'Применимо только в случае ошибки выполнения скрипта';

  @override
  String get keyAuth => 'Аутентификация по ключу';

  @override
  String get lastFailure => 'Последний сбой';

  @override
  String get lastSuccess => 'Последний успех';

  @override
  String get letterCache => 'Обычный ввод с клавиатуры';

  @override
  String get letterCacheTip =>
      'Когда параметр включен, ввод проходит через обычный IME, что на некоторых системах позволяет избежать запросов защищенной клавиатуры в терминале.';

  @override
  String get linuxShellTip =>
      'С какой оболочки запускается терминал. Пусто — вернуть /bin/sh.';

  @override
  String get linuxNetTip =>
      'DNS-серверы. Пусто — вернуть значения по умолчанию';

  @override
  String madeWithLove(Object myGithub) {
    return 'Создано с ❤️ by $myGithub';
  }

  @override
  String get maxConcurrency => 'Максимальная параллельность';

  @override
  String get maxRetryCount =>
      'Максимальное количество попыток переподключения к серверу';

  @override
  String mismatchSystem(Object system) {
    return 'Несоответствующая система: $system';
  }

  @override
  String get mirror => 'Зеркало';

  @override
  String get needRestart => 'Требуется перезапуск приложения';

  @override
  String get netViewType => 'Тип визуализации сети';

  @override
  String get newContainer => 'Создать контейнер';

  @override
  String get noConnectionStatsData => 'Нет данных статистики соединений';

  @override
  String get noLineChart => 'Не использовать линейные графики';

  @override
  String get noPrivateKeyTip =>
      'Приватный ключ не существует, возможно, он был удален или есть ошибка в настройках.';

  @override
  String get noPromptAgain => 'Больше не спрашивать';

  @override
  String get openLastPath => 'Открыть последний путь';

  @override
  String get openLastPathTip =>
      'Для разных серверов будут сохранены разные записи, записывается путь при выходе';

  @override
  String get parseContainerStatsTip =>
      'Анализ статуса использования Docker может быть медленным';

  @override
  String get plugInType => 'Тип вставки';

  @override
  String get preferDiskAmount => 'Приоритетное отображение объёма диска';

  @override
  String get privateKey => 'Приватный ключ';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'Закрытый ключ [$keyId] не найден.';
  }

  @override
  String get bmcPowerOnAction => 'Включить';

  @override
  String get bmcShutdown => 'Выключить';

  @override
  String get bmcForceOff => 'Принудительно выключить';

  @override
  String get restart => 'Перезапустить';

  @override
  String get bmcPowerCycle => 'Полный перезапуск питания';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return 'Отправить на $server? Сервису будет послано «$resetType»';
  }

  @override
  String get bmcPowerDone => 'Состояние питания изменилось';

  @override
  String get bmcPowerAccepted =>
      'Принято, но состояние питания не изменилось. Мягкая операция зависит от ОС';

  @override
  String get bmcPowerUnsupported =>
      'Эта служба ничего не допускает для этого действия';

  @override
  String get bmcUnauthorized => 'BMC отклонил учётную запись';

  @override
  String get bmcAccountMissing => 'Для этого BMC не задана учётная запись';

  @override
  String get bmcPowerOn => 'Включён';

  @override
  String get bmcPowerOff => 'Выключен';

  @override
  String get bmcCertRejected =>
      'Сертификат отклонён — проверьте его в настройках сервера';

  @override
  String get bmcNotAService => 'По этому адресу нет службы Redfish';

  @override
  String get bmcNoSystem => 'Служба не сообщает ни об одной системе';

  @override
  String get bmcSensorsTruncated => 'Показаны только первые датчики';

  @override
  String get bmcMultipleSystems => 'Показана только первая система';

  @override
  String get bmcTip =>
      'BMC — отдельный компьютер на материнской плате, доступный тогда, когда операционная система хоста недоступна. Настроенный здесь, он сообщает состояние питания и показания аппаратных датчиков, пока сервер выключен или завис. Требуется Redfish, он есть у большинства серверного оборудования примерно с 2016 года.';

  @override
  String get bmcCert => 'Сертификат';

  @override
  String get bmcCertPinned => 'Проверен и закреплён';

  @override
  String get bmcCertUnreviewed =>
      'Ещё не проверен — нажмите, чтобы посмотреть сертификат';

  @override
  String get bmcCertReview =>
      'Самоподписанный сертификат. Сверьте его перед принятием. Дальше доверяется только он.';

  @override
  String get bmcCertChanged => 'Сертификат не совпадает. Проверьте.';

  @override
  String get bmcCertExpired => 'Просрочен.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Принят ранее: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'Адрес BMC должен быть URL, например https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Эта сборка работает в песочнице: команда получает пустой home, не ваш, поэтому всё, что читает ~/.ssh, падает. Версия DMG — нет.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'Не удалось прочитать файл закрытого ключа $path: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Эта сборка не может читать файлы вне своего контейнера, поэтому ключ по пути $path недоступен. Импортируйте ключ в настройках или используйте сборку DMG.';
  }

  @override
  String get pushToken => 'Токен уведомлений';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand поддерживается только на настольных платформах.';

  @override
  String get pveIgnoreCertTip =>
      'Не рекомендуется включать, обратите внимание на риски безопасности! Если вы используете стандартный сертификат от PVE, вам нужно включить эту опцию.';

  @override
  String get pveServerClientMissing =>
      'SSH-клиент для этого сервера недоступен.';

  @override
  String get pveAddressMissing =>
      'Не указан адрес PVE. Задайте его в настройках сервера.';

  @override
  String get pvePasswordRequired =>
      'Требуется пароль PVE. Задайте его в настройках сервера.';

  @override
  String get pveOtpRequired =>
      'На этом сервере PVE включена двухфакторная аутентификация. Введите код OTP.';

  @override
  String get pveOtpChallengeExpired =>
      'Срок действия запроса OTP истёк. Обновите и попробуйте снова.';

  @override
  String get pveOtpCodeRequired => 'Требуется код OTP.';

  @override
  String get pveOtpVerificationFailed =>
      'Проверка OTP не удалась. Попробуйте снова с новым кодом.';

  @override
  String get pveOtpTitle => 'Проверка OTP';

  @override
  String get pveOtpLabel => 'Код OTP';

  @override
  String get pveInvalidResponseBody =>
      'Вход в PVE вернул некорректное тело ответа.';

  @override
  String get pveInvalidResponseData =>
      'Ответ на вход в PVE не содержал корректных данных.';

  @override
  String get pveMissingAuthTicket =>
      'Вход в PVE выполнен, но билет аутентификации не возвращён.';

  @override
  String get pveVersionLow =>
      'Эта функция в настоящее время находится на стадии тестирования и была протестирована только на PVE 8+. Используйте ее с осторожностью.';

  @override
  String get pveLoadingForwarding => 'Установка SSH-туннеля…';

  @override
  String get pveLoadingLogin => 'Аутентификация в PVE…';

  @override
  String get pveLoadingData => 'Получение данных кластера…';

  @override
  String get pveLoadingConnect => 'Подключение…';

  @override
  String get pvePassword => 'Пароль PVE';

  @override
  String get pvePasswordHint => 'Требуется при аутентификации SSH по ключу';

  @override
  String get read => 'Чтение';

  @override
  String get recentConnections => 'Недавние соединения';

  @override
  String get rememberPwdInMem => 'Запомнить пароль в памяти';

  @override
  String get rememberPwdInMemTip =>
      'Используется для контейнеров, приостановки и т. д.';

  @override
  String get remotePath => 'Удаленный путь';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return 'Установлен $distro $installed, доступен $latest. Обновление заменит весь контейнер: данные $pm будут потеряны';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Закройте терминалы на $name, прежде чем удалять';
  }

  @override
  String get rootfsSubtitle =>
      'Пользовательское окружение Linux на этом устройстве';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return 'Скачивает $distro $version (около $size МБ) и распаковывает на устройстве.';
  }

  @override
  String get sameIdServerExist => 'Сервер с таким ID уже существует';

  @override
  String get second => 'с';

  @override
  String get serverFilesUnavailableTip =>
      'Нужен SSH к этому серверу или установленный server_box_monitor с включённым файловым API.';

  @override
  String get back => 'Назад';

  @override
  String get history => 'История';

  @override
  String get homeDir => 'Домашняя папка';

  @override
  String selected(Object count) {
    return 'Выбрано: $count';
  }

  @override
  String get sendTo => 'Отправить в…';

  @override
  String get serverDetailOrder =>
      'Порядок элементов на странице деталей сервера';

  @override
  String get serverFuncBtns => 'Кнопки функций сервера';

  @override
  String get serverOrder => 'Порядок серверов';

  @override
  String get serverTabRequired => 'Вкладку сервера нельзя удалить';

  @override
  String get shareServerRiskTip =>
      'Этот QR-код содержит настройки подключения открытым текстом. Любой, кто его отсканирует или сфотографирует, сможет подключиться.';

  @override
  String get sftpDlPrepare => 'Подготовка подключения...';

  @override
  String get sftpEditorTip =>
      'Пусто — встроенный редактор. Например `vim` (лучше брать из `EDITOR`).';

  @override
  String get sftpRmrDirSummary =>
      'Использовать `rm -r` в SFTP для удаления папок';

  @override
  String get sftpSSHConnected => 'SFTP подключен...';

  @override
  String get sftpShowFoldersFirst => 'Показывать папки в начале';

  @override
  String get specifyDev => 'Указать устройство';

  @override
  String get specifyDevTip =>
      'Сетевой трафик по умолчанию считается по всем устройствам; укажите одно здесь';

  @override
  String get tempIsCelsiusTip =>
      'Если включено, значение температуры считается в градусах Цельсия, а не в миллицельсиях. Включайте, только если температура отображается неверно (например, 0,1 °C вместо 58 °C).';

  @override
  String spentTime(Object time) {
    return 'Затрачено времени: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Все серверы уже существуют (найдено $duplicateCount дубликатов)';
  }

  @override
  String get sshConnectionModeTip =>
      'Встроенный: использовать терминал приложения. Системный SSH: запускать системную команду ssh во внешнем терминале.';

  @override
  String get sshConnectionModeUseBuiltin => 'Использовать встроенный терминал';

  @override
  String get sshConnectionModeUseSystem => 'Использовать системный SSH';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return '$duplicateCount дубликатов будут пропущены';
  }

  @override
  String get sshConfigFound => 'Мы нашли SSH-конфигурацию в вашей системе';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return 'Найдено $totalCount серверов';
  }

  @override
  String get sshConfigImport => 'Импорт SSH Конфигурации';

  @override
  String get sshConfigImportPermission =>
      'Хотите ли вы дать разрешение на чтение ~/.ssh/config и автоматический импорт настроек сервера?';

  @override
  String get sshConfigImportTip =>
      'Предложение прочитать ~/.ssh/config при создании первого сервера';

  @override
  String sshConfigImported(Object count) {
    return 'Импортировано $count серверов из SSH-конфигурации';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'SSH-ключ хоста для $serverName изменился. Продолжайте только если доверяете этому серверу.';
  }

  @override
  String get sshHostKeyType => 'Тип ключа хоста SSH';

  @override
  String get sshKnownHostKeys => 'Известные хосты';

  @override
  String get sshKnownHostKeysTip => 'Ключи хостов, принятые этим приложением';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'Получен новый SSH-ключ хоста от $serverName. Проверьте отпечаток перед продолжением.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Сохранённый отпечаток: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Код подтверждения';

  @override
  String get sshConfigManualSelect =>
      'Хотели бы вы вручную выбрать файл конфигурации SSH?';

  @override
  String get sshConfigNoServers => 'Серверы не найдены в SSH-конфигурации';

  @override
  String get sshConfigPermissionDenied =>
      'Невозможно получить доступ к файлу конфигурации SSH из-за разрешений macOS.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return '$importCount серверов будут импортированы';
  }

  @override
  String get sshTermHelp =>
      'Когда терминал можно прокручивать, горизонтальное перетаскивание позволяет выделить текст. Нажатие на кнопку клавиатуры включает/выключает клавиатуру. Иконка файла открывает текущий путь SFTP. Кнопка буфера обмена копирует содержимое, когда текст выделен, и вставляет содержимое из буфера обмена в терминал, когда текст не выделен, а в буфере есть содержимое. Иконка кода вставляет фрагменты кода в терминал и выполняет их.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Автоматическое переключение виртуальных клавиш';

  @override
  String get supportFmtArgs => 'Поддерживаются следующие форматы аргументов:';

  @override
  String get suspendTip =>
      'Функция приостановки требует прав root и поддержки systemd.';

  @override
  String switchTo(Object val) {
    return 'Переключиться на $val';
  }

  @override
  String get syncAppSettings => 'Синхронизировать настройки приложения';

  @override
  String get syncAppSettingsTip =>
      'Включить тему, макет, редактор, терминал и другие настройки устройства в автоматическую синхронизацию.';

  @override
  String get termFontSizeTip =>
      'Эта настройка повлияет на размер терминала (ширина и высота). Вы можете масштабировать страницу терминала, чтобы调整 размер шрифта текущей сессии.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (исходный размер), применяется только к части шрифтов на странице сервера, изменение не рекомендуется.';

  @override
  String get times => 'Раз';

  @override
  String get trySudo => 'Попробовать использовать sudo';

  @override
  String get sudoPromptNotFound => 'В данный момент нет запроса пароля sudo.';

  @override
  String get updateServerStatusInterval =>
      'Интервал обновления статуса сервера';

  @override
  String get useNoPwd => 'Будет использоваться без пароля';

  @override
  String get usePodmanByDefault => 'Использовать Podman по умолчанию';

  @override
  String get used => 'Использовано';

  @override
  String get view => 'Вид';

  @override
  String get viewDetails => 'Просмотр деталей';

  @override
  String get virtKeyHelpClipboard =>
      'Если в терминале выделен текст, то он копируется в буфер обмена, в противном случае содержимое буфера вставляется в терминал.';

  @override
  String get virtKeyHelpIME => 'Включить/выключить клавиатуру';

  @override
  String get virtKeyHelpSFTP => 'Открыть текущий путь в SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Выбрать сниппет и выполнить его в этом терминале.';

  @override
  String get virtKeyHelpTmux => 'Переключение между сессиями и окнами tmux.';

  @override
  String get virtKeyIntroActions => 'Быстрые действия';

  @override
  String get virtKeyIntroActionsTip =>
      'Эти клавиши ничего не вводят, а открывают нужное. Удерживайте клавишу, чтобы прочитать, что она делает.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'В настройках терминала их можно переставить или скрыть те, которыми вы не пользуетесь.';

  @override
  String get virtKeyIntroModifiers => 'Модификаторы';

  @override
  String get virtKeyIntroModifiersTip =>
      'Нажмите одну, чтобы включить, затем букву на клавиатуре. Она действует ровно на одну клавишу.';

  @override
  String get virtKeyIntroNav => 'Перемещение курсора';

  @override
  String get virtKeyIntroNavTip =>
      'Эти клавиши двигают курсор. Удерживайте стрелку, чтобы повторять её.';

  @override
  String get virtKeyIntroSelect =>
      'Пока в терминале есть что прокручивать, перетаскивание вбок выделяет текст.';

  @override
  String get virtKeyRows => 'Строк показывать сразу';

  @override
  String get virtKeyRowsTip =>
      'Остальные — на отдельной странице, пролистываемой вбок.';

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
  String get wolTip =>
      'После настройки WOL (Wake-on-LAN) при каждом подключении к серверу отправляется запрос WOL.';

  @override
  String get write => 'Запись';

  @override
  String get writeScriptFailTip =>
      'Запись скрипта не удалась, возможно, из-за отсутствия прав или потому что, директории не существует.';

  @override
  String get writeScriptTip =>
      'После подключения к серверу скрипт будет записан в `~/.config/server_box` \n | `/tmp/server_box` для мониторинга состояния системы. Вы можете проверить содержимое скрипта.';

  @override
  String get menuGitHubRepository => 'Репозиторий GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'Обнаружена эмуляция Podman Docker. Пожалуйста, переключитесь на Podman в настройках.';

  @override
  String get betaTip =>
      'Функция ещё в бета-тестировании. Её работа не гарантируется.';

  @override
  String get portForward_startPrompt =>
      'Добавьте правило проброса порта, чтобы начать';

  @override
  String get portForward_localHost => 'Локальный хост';

  @override
  String get portForward_localPort => 'Локальный порт';

  @override
  String get portForward_remoteHost => 'Удалённый хост';

  @override
  String get portForward_remotePort => 'Удалённый порт';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return 'Удалить $name?';
  }

  @override
  String get sponsor => 'Спонсор';

  @override
  String get sortByJoinTime => 'По времени добавления';

  @override
  String get serverHistory => 'История сервера';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'Автоподключение к tmux';

  @override
  String get tmuxAuto => 'Автоматический tmux';

  @override
  String get tmuxAutoTip =>
      'Автоматически запускать tmux или подключаться к нему при соединении по SSH';

  @override
  String get tmuxSessionSelector => 'Выбор сессии';

  @override
  String get tmuxSessionSelectorTip =>
      'Показывать выбор сессии при подключении';

  @override
  String get tmuxDefaultSessionName => 'Имя сессии по умолчанию';

  @override
  String get tmuxSessionName => 'Имя сессии';

  @override
  String get tmuxExistingSessions => 'Существующие сессии';

  @override
  String get tmuxNewSession => 'Новая сессия';

  @override
  String get tmuxWindows => 'Окна';

  @override
  String get tmuxNewWindow => 'Новое окно';

  @override
  String get tmuxNoWindowsFound => 'Окон не найдено';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count окна',
      many: '$count окон',
      few: '$count окна',
      one: '1 окно',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count панели',
      many: '$count панелей',
      few: '$count панели',
      one: '1 панель',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Подключена';

  @override
  String get tmuxActive => 'Активна';

  @override
  String tmuxActiveAt(String time) {
    return 'активна: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'подключена: $time';
  }

  @override
  String get tmuxSkip => 'Пропустить';

  @override
  String get tmuxNotAvailable => 'tmux недоступен';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Неожиданное количество сегментов в ответе контейнера: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Уже выполняется другая операция с контейнером';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count процесса',
      many: '$count процессов',
      few: '$count процесса',
      one: '$count процесс',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'Формат списка процессов не поддерживается.';

  @override
  String get processParseInvalidRows =>
      'Не удалось прочитать некоторые записи процессов.';

  @override
  String get processParseInvalidWindowsJson =>
      'Не удалось прочитать ответ со списком процессов Windows.';

  @override
  String get processParseInvalidWindowsRows =>
      'Не удалось прочитать некоторые записи процессов Windows.';

  @override
  String get processKillTargetChanged =>
      'Процесс изменился или завершился. Обновите список и повторите попытку.';

  @override
  String get watchServers => 'Серверы на часах';

  @override
  String get watchServersTip =>
      'Часы сами обращаются к monitor, поэтому доступны только серверы с ним.';

  @override
  String get watchNoMonitorServer =>
      'Ни на одном сервере не настроен агент monitor';

  @override
  String get watchLegacyUrls => 'Устаревшие URL статуса';

  @override
  String get accessoryWidgetServer => 'Сервер для виджета экрана блокировки';

  @override
  String get systemdMissing => 'На этом сервере нет systemd';

  @override
  String get systemdMissingTip =>
      '`systemctl` здесь не установлен, поэтому юнитов для показа нет.';

  @override
  String initSystemFmt(String init) {
    return 'Похоже, эта машина использует $init.';
  }

  @override
  String get systemdListFailed => 'Не удалось получить список юнитов';

  @override
  String get systemdUserScopeMissing => 'Пользовательские юниты не показаны';

  @override
  String get systemdUserScopeMissingTip =>
      'У этой учётной записи нет пользовательской шины сеанса на сервере, поэтому показаны только системные юниты.';

  @override
  String get serverUnreachable =>
      'Не удалось выполнить команду на этом сервере';

  @override
  String get containerNoRuntime => 'Здесь нет среды выполнения контейнеров';

  @override
  String get containerNoRuntimeTip =>
      'Ни `docker`, ни `podman` не ответили на этой машине. Если один из них установлен для другой учётной записи, включите «Попробовать использовать sudo» в настройках.';

  @override
  String get containerUnreadable =>
      'Среда выполнения контейнеров ответила в неожиданном формате';

  @override
  String get power => 'Питание';

  @override
  String get continueInTerminal => 'Продолжить в терминале';

  @override
  String get askAiRiskUnknown => 'Не определено';

  @override
  String get agentLocalExec => 'Выполнять команды на этом устройстве';

  @override
  String get agentLocalExecTip =>
      'Позволяет агенту работать на машине, где запущен ServerBox. Даже команды только для чтения проверяются';

  @override
  String get agentLocalExecRootfsTip =>
      'Позволяет агенту работать локально, в пределах контейнера Linux, установленного ServerBox';

  @override
  String macDmgImportedPartly(String path) {
    return 'Данные ранее установленной сборки импортированы. Загруженные файлы остались в $path.';
  }

  @override
  String get bmcAccount => 'Учётная запись';

  @override
  String get bmcAccountUnset =>
      'Не выбрана — нажмите, чтобы выбрать или создать';

  @override
  String bmcAccountShared(int count) {
    return 'Используется на $count серверах';
  }

  @override
  String get bmcAccounts => 'Учётные записи BMC';

  @override
  String get bmcAccountSharedTip => 'Изменение здесь затронет их все.';

  @override
  String bmcAccountInUse(int count) {
    return 'Её используют $count серверов. Адрес останется, учётная запись — нет.';
  }

  @override
  String get bmcStaleWrite =>
      'BMC изменился во время записи. Повторите попытку.';

  @override
  String get send => 'Отправить';
}
