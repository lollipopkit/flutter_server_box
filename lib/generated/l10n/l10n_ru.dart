// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get crashCollect => 'Диагностические данные';

  @override
  String get crashCollectIntro =>
      'ServerBox записывает происходящее во время работы, чтобы можно было исправлять проблемы. Выберите, сколько данных отправлять.';

  @override
  String get crashCollectNone => 'Ничего';

  @override
  String get crashCollectNoneTip =>
      'Отчёты остаются на устройстве; после сбоя вы можете отправить один вручную.';

  @override
  String get crashCollectBasic => 'Основные данные';

  @override
  String get crashCollectBasicTip =>
      'Включает только сведения о сбое; журналы и данные о производительности не включаются. **Это помогает нам улучшать приложение и исправлять ошибки.**';

  @override
  String get crashCollectFull => 'Полные данные';

  @override
  String get crashCollectFullTip =>
      'Помимо журнала сбоя, включаются данные о производительности и сведения о том, какие функции используются: они помогают найти, что работает медленно и какие функции действительно нужны.';

  @override
  String get crashCollectFooter =>
      'На всех уровнях известные имена серверов, адреса и имена пользователей заменяются заполнителями уже при записи. Позже уровень сбора можно изменить в настройках.';

  @override
  String get privacy => 'Конфиденциальность';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get crashLastRunFailed =>
      'ServerBox неожиданно завершил работу во время последнего запуска.';

  @override
  String get crashReportTitle => 'Отчёт о сбое';

  @override
  String get crashReportHint =>
      'Это журнал предыдущего запуска. Известные имена и адреса серверов заменены заполнителями, но другие данные могут остаться. Внимательно прочитайте отчёт перед отправкой.';

  @override
  String get crashReportSubmit => 'Копировать и сообщить';

  @override
  String get preReleaseUpdates => 'Получать обновления предварительных версий';

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
  String get remoteDesktop => 'Удалённый рабочий стол';

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
  String get askAiResend => 'Resend';

  @override
  String get askAiResendTip =>
      'Всё после этого сообщения будет удалено — ответы, команды и их результаты.';

  @override
  String get askAiDeleteTip =>
      'Это сообщение и всё после него будет удалено — ответы, команды и их результаты.';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'Размеры контекста для разных моделей взяты с models.dev. Одна таблица уже встроена в приложение; нажмите, чтобы загрузить более новую.';

  @override
  String get askAiContextFallback => 'нет в таблице';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      'Насколько должен заполниться контекст модели, прежде чем предыдущие сообщения будут сведены в краткое содержание. При раннем сжатии детали теряются быстрее, а при позднем модель может отклонить запрос.';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'Сколько токенов помещается в контекст этой модели. В автоматическом режиме размер определяется по названию; укажите число, если провайдер предоставляет меньшее окно, чем поддерживает модель.';

  @override
  String get askAiConversationCompacted =>
      'Предыдущие сообщения были сведены в краткое содержание, чтобы продолжить разговор.';

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
  String get askAiAllowInsecure => 'Разрешить незашифрованный HTTP';

  @override
  String get askAiAllowInsecureTip =>
      'Разрешает подключения по http:// к самостоятельно размещённым моделям по адресам, отличным от localhost. Ключ API и любой контекст терминала будут отправлены без шифрования; localhost это не затрагивает.';

  @override
  String get askAiInsecureEndpoint =>
      'Эта конечная точка использует http://. Включите «Разрешить незашифрованный HTTP» в настройках AI, чтобы использовать её.';

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
  String get floatOverTabs => 'Поверх других вкладок';

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
  String get distIconIntroLegal =>
      'Знак говорит лишь о том, что это устройство прочитало с удалённой системы; эти сведения могут быть неверными или устаревшими и не обозначают ни производную сборку, ни пересборку, ни какую-либо конкретную версию. Если определить не удалось, рисуется обычный значок.\n\nКаждый знак является товарным знаком своего владельца и используется здесь только для указания на систему, которую он обозначает.';

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
  String get logoUrlTip =>
      'Большое изображение вверху страницы сервера, в его собственных цветах.';

  @override
  String get globe => 'Глобус';

  @override
  String get locationTip =>
      'Где этот сервер отображается на глобусе. Сначала широта, затем долгота, в градусах — например 39.9042, 116.4074.';

  @override
  String get markUrl => 'Адрес знака';

  @override
  String get markUrlTip =>
      'Маленький знак рядом с именем сервера в списках. Пусто — не показывать.\n\nЭто не то же изображение, что логотип';

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
  String get plainHttpTitle => 'Этот агент отдаётся по незашифрованному HTTP';

  @override
  String get plainHttpTip =>
      'Пароль и всё, что запрашивает приложение, пойдут открытым текстом. Пока ничего не отправлено.';

  @override
  String get allowForThisServer => 'Разрешить для этого сервера';

  @override
  String get viewError => 'Посмотреть ошибку';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Только в доверенной частной сети, которая сама шифрует транспорт, например Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Читать состояние этого сервера через HTTP API агента **monitor**, а не выполняя команды по SSH.\n\nАгент нужно сначала установить на сервер; от него зависят графики, приложение для часов и виджеты.\n\n[Как установить monitor]($url)';
  }

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
  String get trayReadings => 'Показания';

  @override
  String get trayChart => 'График';

  @override
  String get trayChartNone => 'Нет';

  @override
  String get trayCompact => 'Компактные строки';

  @override
  String get trayCompactTip =>
      'По одной строке на сервер, без графика. Linux всегда использует однострочный макет, поскольку меню панели передаётся через D-Bus, который переносит метку вместо произвольного макета; при этом выбранный график может быть добавлен как изображение.';

  @override
  String get trayKeepRunning => 'Продолжать работу в системном трее';

  @override
  String get trayKeepRunningTip =>
      'При закрытии окна приложение остаётся в меню или области уведомлений и продолжает следить за серверами. Отключите эту настройку, чтобы кнопка закрытия завершала работу приложения.';

  @override
  String get bgRunNeedsNotification =>
      'Для работы в фоне нужно постоянное уведомление, а у приложения нет разрешения на уведомления. Нажмите, чтобы разрешить.';

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
  String get containerReclaimable => 'Reclaimable';

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
  String get noConnectionMethod => 'Настройте SSH, агент monitor или оба';

  @override
  String get preferredTransport => 'Сначала пробовать';

  @override
  String get preferredTransportTip =>
      'Откуда читается статус и какое соединение команда откроет первым. Второе остаётся доступным.';

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
  String get liveActivity => 'Активность в реальном времени';

  @override
  String get liveActivityTip =>
      'Показывает сеансы терминала на экране блокировки и в Dynamic Island. Имя сервера и состояние подключения видны без разблокировки устройства.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS не разрешает. Переключатели находятся в разделах Настройки › ServerBox › Активности в реальном времени и Настройки › Face ID и код-пароль › Активности в реальном времени.';

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
  String get serverFuncBtns => 'Кнопки функций сервера';

  @override
  String get serverOrder => 'Порядок серверов';

  @override
  String get serverTabEmpty => 'Серверов пока нет';

  @override
  String get serverTabRequired => 'Вкладку сервера нельзя удалить';

  @override
  String get shareCodeHint =>
      'Передайте эти цифры получателю отдельно. В QR-коде их нет.';

  @override
  String get shareCodePrompt => '6-значный код';

  @override
  String get shareCodeTitle => 'Одноразовый код';

  @override
  String get shareExpired =>
      'Срок действия этих данных истёк. Попросите отправить новые.';

  @override
  String get shareImportFile => 'Из полученного файла';

  @override
  String get shareImportTitle => 'Импорт общего сервера';

  @override
  String get shareIncludesKey => 'В передаваемые данные включён закрытый ключ.';

  @override
  String get shareOmittedBmc =>
      'Учётные данные BMC. Адрес включён, а учётные данные — нет.';

  @override
  String get shareOmittedJump =>
      'Промежуточный сервер, поскольку на этом устройстве он хранится как отдельный сервер.';

  @override
  String get shareOmittedKeyPath =>
      'Файл ключа, поскольку путь к нему действителен только на этом устройстве.';

  @override
  String get shareOmittedMissingKey =>
      'Закрытый ключ, поскольку его нет в хранилище ключей этого устройства.';

  @override
  String get shareOmittedTip =>
      'Не включено; получателю потребуется настроить:';

  @override
  String get sharePassphraseTip =>
      'Эта парольная фраза шифрует файл. Она нужна получателю для импорта сервера, и восстановить её невозможно.';

  @override
  String shareQrTip(int minutes) {
    return 'Данные подключения в этом QR-коде зашифрованы. Срок действия истечёт через $minutes мин.';
  }

  @override
  String get shareScanQr => 'Сканировать QR-код';

  @override
  String shareServerExists(String name) {
    return 'Сервер «$name» на этом устройстве уже использует этот адрес. Всё равно импортировать?';
  }

  @override
  String get shareTooBigForQr =>
      'Данные слишком велики для QR-кода. Отправьте их как файл.';

  @override
  String get shareTooNew =>
      'Эти данные созданы в более новой версии ServerBox. Обновите приложение, чтобы открыть их.';

  @override
  String get shareUnreadable =>
      'Это недопустимые данные общего доступа ServerBox.';

  @override
  String get shareVia => 'Способ отправки';

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
  String get sftpUnavailableUseScp =>
      'Если у этого хоста нет подсистемы SFTP, как у многих встраиваемых устройств, переключите передачу файлов на SCP в настройках сервера.';

  @override
  String get sshFileTransportTip =>
      'SFTP подходит для любого современного устройства. SCP — для старого или встраиваемого хоста, у SSH-сервера которого нет подсистемы SFTP: ему нужна команда `scp` и оболочка, в которой есть и обычные файловые утилиты (`find`, `stat`, `mv`, `chmod`).';

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
      'Эта настройка повлияет на размер терминала (ширина и высота). Вы можете масштабировать страницу терминала, чтобы изменить размер шрифта текущей сессии.';

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
  String get portForwardBetaTitle => 'Перенаправление портов (бета)';

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
  String get processSearchHint => 'Имя, пользователь или PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Показать потоки ядра: $count',
      one: 'Показать $count поток ядра',
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
  String get watchServers => 'Серверы на часах';

  @override
  String get watchServersTip =>
      'Часы сами обращаются к monitor, поэтому доступны только серверы с ним.';

  @override
  String get watchNoMonitorServer =>
      'Ни на одном сервере не настроен агент monitor';

  @override
  String get legacyStatusGoneTitle => 'URL-адреса статуса больше не работают';

  @override
  String get legacyStatusGoneBody =>
      'Приложение для часов и виджеты читали адрес `/status`, введённый вручную. Эта конечная точка удалена: она возвращала только текущие значения текстом, поэтому графики были невозможны.\n\nТеперь они читают аутентифицированный API агента monitor, строят графики и синхронизируются с приложением сами. Настройте сервер в приложении один раз — часы и виджеты подхватят его.';

  @override
  String get services => 'Службы';

  @override
  String get status => 'Состояние';

  @override
  String get enable => 'Включить';

  @override
  String get disable => 'Отключить';

  @override
  String get starting => 'Запускается';

  @override
  String get stopping => 'Останавливается';

  @override
  String get serviceManagerUnsupported => 'Неподдерживаемый менеджер служб';

  @override
  String get serviceManagerUnsupportedTip =>
      'Этот сервер использует менеджер служб, который ServerBox пока не поддерживает. Поддерживаются systemd, procd и OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Управляется через $manager';
  }

  @override
  String get serviceListFailed => 'Не удалось получить список служб';

  @override
  String get serviceDetailsUnavailable =>
      'Некоторые сведения о службах недоступны';

  @override
  String get serviceDetailsUnavailableTip =>
      'Список доступен, но менеджер не вернул все сведения о состоянии или автозапуске.';

  @override
  String get systemdUserScopeMissing => 'Пользовательские юниты не показаны';

  @override
  String get systemdUserScopeMissingTip =>
      'У этой учётной записи нет пользовательской шины сеанса на сервере, поэтому показаны только системные юниты.';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Другие units: $count',
      one: 'Ещё $count unit',
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
    return 'Остановлена $duration назад';
  }

  @override
  String serviceExitStatus(String code) {
    return 'код завершения $code';
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
      other: 'Последние строки: $count',
      one: 'Последняя строка',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable =>
      'Эта учётная запись не может читать journal';

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
  String get fan => 'Вентилятор';

  @override
  String get clockSpeed => 'Частота';

  @override
  String get vendor => 'Производитель';

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

  @override
  String get privacyBlur => 'Приватность в фоне';

  @override
  String get privacyBlurTip => 'Скрывать содержимое приложения в переключателе';

  @override
  String get floatReturnToTab => 'Вернуть во вкладку';

  @override
  String get termInFloatWindow => 'Этот терминал открыт в плавающем окне';

  @override
  String get globeEnabledTip =>
      'Показывать серверы на глобусе там, где находятся их адреса. Выключено убирает кнопку и прекращает любые запросы.';

  @override
  String get geoShardsConsentAttribution =>
      'IP-геолокация от [DB-IP](https://db-ip.com), CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Частный адрес';

  @override
  String get geoMissNoData => 'Нет данных о местоположении';

  @override
  String get globeGuide =>
      'Нажмите здесь, чтобы увидеть серверы на глобусе — там, где находятся их адреса.';

  @override
  String get publicIp => 'Публичный IP';

  @override
  String get geoData => 'Данные городского уровня';

  @override
  String get geoDataTip =>
      'После загрузки для всех геолокационных запросов используются данные, хранящиеся на этом устройстве. Адреса серверов и сведения о запросах не передаются сервису загрузки.';

  @override
  String get geoDataMissing => 'Не загружены';

  @override
  String get geoDataUnreachable => 'Не удалось получить данные.';

  @override
  String get geoDataRemoveFailed => 'Не удалось удалить данные.';

  @override
  String geoDataCurrent(Object month) {
    return '$month уже установлен.';
  }

  @override
  String geoDataConsent(Object download, Object disk) {
    return '**Размер загрузки: $download · Место на устройстве: $disk.** Полный набор данных хранится на этом устройстве, а все последующие геолокационные запросы выполняются локально. Адреса серверов и сведения о запросах не передаются сервису загрузки.\n\nОбновляется ежемесячно. Новая версия заменяет установленные данные, не сохраняя дополнительную копию. Данные можно удалить в любой момент.';
  }

  @override
  String get benchmark => 'Тест производительности';

  @override
  String get benchmarkIntro =>
      'Запускает на этом сервере Yet Another Bench Script для проверки диска, сети и процессора. Полный тест занимает 10–20 минут и продолжает выполняться, если покинуть эту страницу или закрыть приложение.';

  @override
  String get benchmarkNoRuns => 'Результатов тестирования пока нет.';

  @override
  String get benchmarkRunning => 'Выполняется тест производительности';

  @override
  String get benchmarkStartFailed =>
      'Не удалось запустить тест производительности';

  @override
  String get benchmarkCancelConfirm =>
      'Остановить этот тест? Все полученные результаты будут потеряны.';

  @override
  String get benchmarkDeleteConfirm => 'Удалить результат этого теста?';

  @override
  String get benchmarkNothingSelected =>
      'Все этапы отключены. Будет собрана только информация о системе; это займёт несколько секунд.';

  @override
  String get benchmarkDiskTip =>
      'fio с четырьмя размерами блоков; около 3 минут. Записывает тестовый файл размером 2 ГБ в рабочий каталог и требует столько же свободного места.';

  @override
  String get benchmarkNetworkTip =>
      'iperf3 с общедоступными серверами; около 4 минут.';

  @override
  String get benchmarkReducedNetwork => 'Меньше расположений';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Три расположения вместо семи. Примерный объём трафика снизится с $full до $reduced.';
  }

  @override
  String get benchmarkCpuTip =>
      'Загружает Geekbench, проприетарную программу, и **публикует результат на общедоступной странице geekbench.com**, включая модель процессора, число ядер и объём памяти.';

  @override
  String get benchmarkSensitiveOptions =>
      'Следующие параметры скачивают и запускают стороннее ПО на этом сервере либо отправляют сведения о сервере третьим лицам. По умолчанию они выключены.';

  @override
  String get benchmarkIpInfoTip =>
      'Передаёт публичный адрес этого сервера сервису ip-api.com по незашифрованному протоколу HTTP.';

  @override
  String get benchmarkIpInfo => 'Узнать владельца IP-адреса';

  @override
  String get benchmarkPreferBin => 'Загрузить fio и iperf3';

  @override
  String get benchmarkPreferBinTip =>
      'Загружает их с GitHub вместо использования пакетов хоста. Включайте только в том случае, если на хосте не установлена ни одна из этих программ.';

  @override
  String get benchmarkWorkDir => 'Рабочий каталог';

  @override
  String get benchmarkWorkDirTip =>
      'Определяет файловую систему для тестирования диска. Если оставить поле пустым, будет использован домашний каталог учётной записи.';

  @override
  String benchmarkEstimatedTime(String minutes) {
    return 'Около $minutes мин.';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Около $size трафика';
  }

  @override
  String get benchmarkPhaseSystem => 'Чтение информации о системе';

  @override
  String get benchmarkPhaseDisk => 'Тестирование диска';

  @override
  String get benchmarkPhaseNetwork => 'Тестирование сети';

  @override
  String get benchmarkPhaseCpu => 'Тестирование процессора';

  @override
  String get benchmarkPhaseDone => 'Завершение';

  @override
  String get benchmarkResultUnreadable =>
      'Не удалось прочитать этот результат как JSON. Ниже приведён исходный текст.';

  @override
  String get benchmarkViewOnGeekbench => 'Открыть в Geekbench';

  @override
  String get benchmarkGeekbenchPublic =>
      'Этот результат общедоступен по указанной выше ссылке.';

  @override
  String get benchmarkSingleCore => 'Одно ядро';

  @override
  String get benchmarkMultiCore => 'Несколько ядер';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Отправка';

  @override
  String get benchmarkRecv => 'Получение';

  @override
  String get benchmarkLatency => 'Задержка';

  @override
  String get benchmarkVirt => 'Виртуализация';

  @override
  String get benchmarkRawLog => 'Журнал выполнения';

  @override
  String benchmarkUpstream(String version) {
    return 'На основе Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'Запуск';

  @override
  String get benchmarkNoOutputYet =>
      'Вывода пока нет. Перед выводом первой строки YABS проверяет доступность google.com и icanhazip.com. В сетях, где заблокирован хотя бы один из этих сайтов, проверка может занять несколько минут.';

  @override
  String get tagsEmptyTip =>
      'Тегов пока нет. Добавьте тег при редактировании сервера, и он появится здесь.';

  @override
  String get benchmarkNoServers =>
      'Сначала добавьте сервер, затем вернитесь, чтобы запустить бенчмарк.';

  @override
  String get schemaTooNewTitle => 'Эти данные новее приложения';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Они записаны более новой версией ServerBox (версия хранилища v$stored); эта версия читает данные до v$supported. Данные не изменялись.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Переустановите более новую версию, и все данные снова откроются как прежде.';

  @override
  String get schemaTooNewExportPlain => 'Экспортировать без пароля';

  @override
  String get schemaTooNewPlainWarn =>
      'Файл будет содержать в открытом виде все закрытые SSH-ключи, пароли серверов и ключи API. Получивший файл получит доступ ко всему этому.';

  @override
  String get schemaTooNewWipe => 'Удалить все данные';

  @override
  String get schemaTooNewWipeConfirm =>
      'Все серверы, ключи, сниппеты и настройки на этом устройстве будут удалены без возможности отмены. Экспортированная здесь резервная копия станет единственной оставшейся копией.';

  @override
  String get schemaTooNewWipeDone =>
      'Данные удалены. Откройте приложение снова, чтобы начать с чистого листа.';

  @override
  String get schemaTooNewWipeFailed =>
      'Не удалось удалить часть данных, и эта версия по-прежнему не может открыть оставшиеся данные. Переустановите более новую версию, чтобы получить к ним доступ.';

  @override
  String get systemUsers => 'Users';

  @override
  String get userManagerLinuxOnly =>
      'Управление системными пользователями сейчас поддерживается только на серверах Linux.';

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
      'Изменения пользователя root сразу применяются ко всем сеансам.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Дополнительные группы';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Создать домашний каталог';

  @override
  String get userMoveHome =>
      'Переместить существующий домашний каталог при изменении пути';

  @override
  String get userRemoveHome => 'Удалить домашний каталог';

  @override
  String get userPasswordCreateTip =>
      'Оставьте пароль пустым, чтобы создать учётную запись с заблокированным входом по паролю.';

  @override
  String get userPasswordEditTip =>
      'Оставьте поле пустым, чтобы сохранить текущий пароль.';

  @override
  String funcUnavailableFmt(Object func) {
    return '$func недоступно через это подключение к серверу.';
  }

  @override
  String get rangeLive => 'В реальном времени';

  @override
  String get diskIo => 'Диск (ввод-вывод)';

  @override
  String get peak => 'пик';

  @override
  String get hardware => 'Оборудование';

  @override
  String get cores => 'Ядра';

  @override
  String get historyNoStored =>
      'Историю хранит только агент monitor. Это подключение хранит лишь то, что приложение увидело после подключения.';

  @override
  String get noHistoryYet => 'Измерений ещё нет';

  @override
  String get noData => 'нет данных';

  @override
  String get from => 'С';

  @override
  String get to => 'По';

  @override
  String get beyondRetention => 'дальше, чем хранит этот агент';

  @override
  String agentRetentionFmt(Object kept) {
    return 'Агент хранит $kept';
  }

  @override
  String oldestSampleFmt(Object time) {
    return 'самый старый замер $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'Конец диапазона должен быть позже его начала.';

  @override
  String get samples => 'замеров';

  @override
  String get unavailable => 'недоступно';

  @override
  String get metricUnavailableTip =>
      'Остальная часть страницы не затронута. Проверьте на хосте команду, из которой берётся это значение.';

  @override
  String get waitingFirstSample => 'Ожидание первого замера';

  @override
  String atTimeFmt(Object time) {
    return 'в $time';
  }

  @override
  String get stored => 'сохранено';

  @override
  String lastSampleFmt(Object ago) {
    return 'последний замер $ago';
  }

  @override
  String staleSinceFmt(Object ago, Object time) {
    return 'Всё, что ниже, — на $time ($ago).';
  }

  @override
  String noDataBeforeFmt(Object time) {
    return 'нет данных до $time';
  }

  @override
  String loadingRangeFmt(Object range) {
    return 'Загрузка $range…';
  }

  @override
  String noStoredHistoryFor(Object metric) {
    return 'Нет сохранённой истории для «$metric»';
  }

  @override
  String devicesFmt(Object count) {
    return 'устройств: $count';
  }

  @override
  String devicesBusiestFmt(Object count, Object name) {
    return 'устройств: $count · самое загруженное — $name';
  }

  @override
  String devicesPlottedFmt(Object plotted, Object total) {
    return '$plotted из $total устройств';
  }

  @override
  String sensorsHottestFmt(Object count, Object name) {
    return 'датчиков: $count · самый горячий — $name';
  }

  @override
  String get oneDeviceAtLeast => 'Хотя бы одно устройство остаётся на графике.';

  @override
  String shownOfFmt(Object shown, Object total, Object what) {
    return '$shown из $total ($what)';
  }

  @override
  String countOfFmt(Object count, Object what) {
    return '$what: $count';
  }

  @override
  String get unitDevices => 'устройства';

  @override
  String get unitSensors => 'датчики';

  @override
  String get unitBatteries => 'батареи';

  @override
  String get unitCommands => 'команды';

  @override
  String get unitReadings => 'показания';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => 'самый горячий';

  @override
  String get oldest => 'самый старый';

  @override
  String get notApplicable => 'неприменимо';

  @override
  String get attributes => 'атрибуты';

  @override
  String get powerOnHours => 'Часов работы';

  @override
  String get powerCycles => 'Циклов включения';

  @override
  String get lifeLeft => 'Остаток ресурса';

  @override
  String get lifetimeWrite => 'Всего записано';

  @override
  String get lifetimeRead => 'Всего прочитано';

  @override
  String get averageErase => 'Среднее число стираний';

  @override
  String get unsafeShutdowns => 'Аварийных выключений';

  @override
  String get diskAllPassed => 'все PASSED';

  @override
  String diskWarningFmt(num count) {
    return 'предупреждений: $count';
  }

  @override
  String diskWrongOfFmt(Object total, Object wrong) {
    return '$wrong из $total устройств';
  }

  @override
  String get diskSmartSortedTip => 'Худшие сверху';

  @override
  String readAgoFmt(Object ago) {
    return 'прочитано $ago';
  }

  @override
  String processesFmt(Object count) {
    return 'процессов: $count';
  }

  @override
  String diskFailingFmt(Object count) {
    return '$count с ошибками';
  }

  @override
  String get diskSmartOpenTip => 'Нажмите, чтобы увидеть атрибуты';

  @override
  String get cycle => 'Циклы';

  @override
  String get window => 'окно';

  @override
  String ofFmt(Object total) {
    return 'из $total';
  }

  @override
  String get serverDetailCards => 'Карточки страницы сведений';

  @override
  String get connection => 'Подключение';

  @override
  String get connectionTip =>
      'Оба могут быть включены одновременно. Порядок — это порядок, в котором к ним обращаются.';

  @override
  String transportOrderFmt(Object first, Object second) {
    return 'Перетащите, чтобы изменить порядок. Сначала — $first; если он не отвечает, сессию берёт на себя $second.';
  }

  @override
  String transportOnlyFmt(Object name) {
    return 'Включён только $name, поэтому переключаться не на что.';
  }

  @override
  String get transportNoneOn =>
      'Оба выключены — к этому серверу нельзя подключиться.';

  @override
  String get transportOffKept =>
      'выключено — настройки сохранены, обращений нет';

  @override
  String get transportDialledFirst => 'обращение первым';

  @override
  String get transportFallback => 'запасной';

  @override
  String get transportOnlyMethod => 'единственный способ';

  @override
  String get transportOff => 'выключено';

  @override
  String get thisDevice => 'Это устройство';

  @override
  String get localServerTip =>
      'Считывает данные этого устройства напрямую, запуская здесь скрипт состояния. SSH и Monitor HTTP не используются, их настройки сохраняются.';

  @override
  String get localServerUnsupported =>
      'На этой платформе нельзя читать это устройство как сервер. Поддерживаются Linux, Windows и DMG-сборка для macOS.';

  @override
  String get remoteDesktopIntro =>
      'Открывает рабочий стол RDP или VNC сервера прямо в приложении. Подключение идёт через SSH-соединение сервера или его агент Monitor, поэтому порт рабочего стола не нужно открывать в сеть.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Сохраняйте профиль для каждого рабочего стола через кнопку «Удалённый рабочий стол» на сервере или на вкладке «Удалённый рабочий стол».';

  @override
  String get localServerIntro =>
      'Добавляет устройство, на котором работает ServerBox, как сервер. Состояние, процессы, службы, контейнеры, терминал и файлы работают без SSH и агента Monitor.';

  @override
  String get localServerAdd => 'Добавить это устройство';

  @override
  String get localServerIntroFooter =>
      'Это можно включить и позже на странице редактирования сервера, в разделе «Подключение».';

  @override
  String get transportSectionOff =>
      'Выключено. Поля ниже сохраняются на случай, если вы включите его снова.';

  @override
  String get monitorAgent => 'Агент monitor';

  @override
  String get plainHttpEditTip =>
      'Учётные данные и метрики идут по сети без шифрования. Ограничьтесь локальной сетью или адресом Tailscale либо поставьте агента за TLS.';

  @override
  String get behaviour => 'Поведение';

  @override
  String get optional => 'Необязательное';

  @override
  String get optionalTip =>
      'Ничто здесь не нужно для подключения. Откройте один — и его поля займут место формы.';

  @override
  String get sshAdvanced => 'SSH, дополнительно';

  @override
  String get sshAdvancedTip =>
      'Запасной адрес, ProxyCommand, промежуточный сервер, передача файлов, путь на сервере';

  @override
  String get sshLegacyAlgorithms => 'Устаревшие алгоритмы';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Для старых SSH-серверов, например маршрутизаторов или коммутаторов, которые предлагают только SHA-1-ключ хоста `ssh-rsa` или SHA-1-обмен ключами. Менее безопасно; включайте только для хостов, которым это необходимо.';

  @override
  String get appearanceAndPlace => 'Вид и место';

  @override
  String get appearanceAndPlaceTip => 'Логотип, координаты';

  @override
  String get statusCollection => 'Сбор статуса';

  @override
  String get statusCollectionTip =>
      'Какие команды выполняются, свои команды, какое устройство читать';

  @override
  String get tagAllTags => 'Все теги';

  @override
  String get tagMatching => 'Совпадения';

  @override
  String get tagNewHint => 'Новый тег';

  @override
  String tagCreateFmt(Object tag) {
    return 'Создать #$tag';
  }

  @override
  String get tagOnThisServer => 'на этом сервере';

  @override
  String tagServersFmt(Object count) {
    return 'серверов: $count';
  }

  @override
  String tagOnThisServerFmt(Object count) {
    return '$count на этом сервере';
  }

  @override
  String get tagMatchesTyped => 'совпадает с введённым';

  @override
  String get tagEditorTip =>
      'Ввод фильтрует список; кнопка создаёт тег и сразу ставит его на этот сервер. Карандаш переименовывает его на всех серверах, где он есть. Тег, которого нет ни на одном сервере, исчезает при сохранении.';

  @override
  String get tagRenamesOnSave => 'Переименования применяются при сохранении';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'Управление запланированными задачами сейчас поддерживается только на серверах Linux.';

  @override
  String get scheduledTaskUnavailable => 'crontab недоступен на этом сервере.';

  @override
  String get scheduledTaskPreserveTip =>
      'Комментарии, переменные окружения и нераспознанные строки в этом crontab будут сохранены.';

  @override
  String get scheduledTaskSchedule => 'Schedule';

  @override
  String get scheduledTaskAdd => 'Add task';

  @override
  String get scheduledTaskNextRun => 'Next run';

  @override
  String scheduledTaskNextInFmt(Object time) {
    return 'in $time';
  }

  @override
  String get scheduledTaskEnabled => 'Enabled';

  @override
  String get scheduledTaskCommentedOut => 'Commented out';

  @override
  String scheduledTaskSummaryFmt(num enabled, num total) {
    return 'Всего: $total · включено: $enabled';
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
      'Если выключено, строка записывается закомментированной.';

  @override
  String scheduledTaskEmptyFmt(Object user) {
    return 'У пользователя $user нет запланированных задач. Добавленные здесь задачи записываются в crontab этой учётной записи.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'День месяца';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'День недели';

  @override
  String get cronErrScheduleEmpty => 'Укажите расписание.';

  @override
  String get cronErrCommandEmpty => 'Укажите команду.';

  @override
  String get cronErrLineBreak =>
      'Строка crontab не может содержать переносы строк.';

  @override
  String get cronErrMacro =>
      'Макрос должен состоять из одного слова, например @reboot.';

  @override
  String get cronErrFieldCount =>
      'Расписание cron должно содержать пять полей либо макрос, например @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(Object minutes) {
    return 'Каждые $minutes мин.';
  }

  @override
  String cronHourlyAtFmt(Object minute) {
    return 'Каждый час в :$minute';
  }

  @override
  String cronEveryHoursFmt(Object hours) {
    return 'Каждые $hours ч.';
  }

  @override
  String cronEveryHoursAtFmt(Object hours, Object minute) {
    return 'Каждые $hours ч. в :$minute';
  }

  @override
  String cronDailyAtFmt(Object time) {
    return 'Каждый день в $time';
  }

  @override
  String cronWeekdaysAtFmt(Object time) {
    return 'По будням в $time';
  }

  @override
  String cronWeekdayAtFmt(Object day, Object time) {
    return 'Каждый $day в $time';
  }

  @override
  String cronMonthlyAtFmt(Object day, Object time) {
    return '$day-го числа каждого месяца в $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart => 'Вступит в силу после перезапуска Agent';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Интервал расширенного цикла';

  @override
  String get idlePause => 'Приостанавливать, если нет наблюдателей';

  @override
  String get idlePauseTip =>
      'В расширенном цикле запускаются smartctl, sensors и amd-smi. Если приостанавливать его, когда ни один клиент не запрашивает данные, диск не будет просыпаться без необходимости.';

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
      'Метрика: cpu / memory / swap / disk / network / temperature. Фильтр: cpu0 для одного ядра, used / free / avail для памяти, rx / tx для сети; для диска и температуры он игнорируется. Порог: оператор сравнения и значение, например >=80%, >=70c или >10m/s.';

  @override
  String get pushChannels => 'Каналы уведомлений';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Задано в Agent, значение скрыто';

  @override
  String get pushSecretKeep => 'Оставьте пустым, чтобы сохранить';

  @override
  String get pushTestTip =>
      'Отправляет одно уведомление через канал с текущими настройками, независимо от того, сохранены они или нет.';

  @override
  String get pushTestSent => 'Канал принял уведомление';

  @override
  String get pushTestFailed => 'Канал отклонил уведомление';

  @override
  String get pushTestMessage => 'Тестовое уведомление от ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'В этом Agent нет отправителя для данного типа канала, поэтому его настройки не отображаются. Канал можно удалить здесь или изменить в config.toml Agent.';

  @override
  String get pushJsonInvalid => 'не является допустимым JSON';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Если выключено, Agent ничего не удаляет и его база данных растёт без ограничений.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Запускать очистку каждые';

  @override
  String get retentionMaxDbSize => 'Ограничение размера базы данных';

  @override
  String get corsOrigins => 'Разрешённые источники CORS';

  @override
  String get corsOriginsTip =>
      'Источники, с которых веб-панель может обращаться к этому Agent. Пустое значение разрешает только запросы с того же источника.';

  @override
  String get monitorNoRemoteAccess =>
      'Этот агент настроен только для мониторинга. Здесь нельзя открыть терминал, выполнять команды и просматривать файлы. Чтобы включить эти функции, измените раздел [remote_access] в config.toml агента.';

  @override
  String get alerts => 'Оповещения';

  @override
  String get online => 'в сети';

  @override
  String get densityCards => 'Карточки';

  @override
  String get densityRows => 'Строки';

  @override
  String get densityGrid => 'Сетка';

  @override
  String get connect => 'Подключиться';

  @override
  String get disconnect => 'Отключиться';

  @override
  String get searchServerTip =>
      'Ищет по именам и адресам — двум данным, которые редактор запрашивает первыми.';

  @override
  String get addServerTip =>
      'Заполните одно из полей, отсканируйте QR-код или импортируйте файл, которым кто-то поделился.';

  @override
  String get move => 'Переместить';

  @override
  String get moveToTop => 'В начало';

  @override
  String get moveToBottom => 'В конец';

  @override
  String get groupByTag => 'Группировать по тегу';

  @override
  String get groupByTagTip => 'Теги задаются в редакторе сервера.';

  @override
  String get connecting => 'Подключение…';

  @override
  String get authShort => 'Авториз.';

  @override
  String get remoteDesktopFitToWindow => 'По размеру окна';

  @override
  String get remoteDesktopActualSize => 'Фактический размер';

  @override
  String get remoteDesktopZoom => 'Масштаб';

  @override
  String get remoteDesktopViewOnly => 'Только просмотр';

  @override
  String get remoteDesktopDisableViewOnly => 'Отключить режим просмотра';

  @override
  String get remoteDesktopSendClipboardText =>
      'Отправить текст из буфера обмена';

  @override
  String get remoteDesktopShowKeyboard => 'Показать клавиатуру';

  @override
  String get remoteDesktopMoreControls => 'Дополнительные элементы управления';

  @override
  String get remoteDesktopUseDirectPointer =>
      'Использовать прямое управление указателем';

  @override
  String get remoteDesktopUseTouchpadPointer =>
      'Использовать указатель тачпада';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Отправить Ctrl+Alt+Delete';

  @override
  String get remoteDesktopReconnect => 'Переподключиться';

  @override
  String get remoteDesktopFullScreen => 'На весь экран';

  @override
  String get remoteDesktopCloseSession => 'Закрыть сеанс';

  @override
  String get remoteDesktopConnected => 'Подключено';

  @override
  String get remoteDesktopConnecting => 'Подключение';

  @override
  String get remoteDesktopReconnecting => 'Повторное подключение';

  @override
  String get remoteDesktopDisconnected => 'Отключено';

  @override
  String get remoteDesktopGuideTouch => 'Тачпад';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Один палец двигает указатель как тачпад, касание — щелчок. Касание двумя пальцами — правый щелчок, перетаскивание двумя — прокрутка, щипок — масштаб. Коснитесь дважды и не отпускайте палец, чтобы перетаскивать.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Открывает экранную клавиатуру. Введённый текст отправляется на удалённый рабочий стол.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Прекращает отправку указателя и клавиш, чтобы смотреть без случайных щелчков.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Здесь находятся Ctrl+Alt+Delete, переподключение и полноэкранный режим.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'А также прямой указатель: палец щёлкает там, где касается.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'Буфер обмена VNC поддерживает только текст в кодировке Latin-1.';

  @override
  String get remoteDesktopConnect => 'Connect';

  @override
  String get remoteDesktopAddProfile => 'Add profile';

  @override
  String get remoteDesktopNoProfiles => 'No remote desktop profiles';

  @override
  String get remoteDesktopAdd => 'Add remote desktop';

  @override
  String get remoteDesktopEdit => 'Edit remote desktop';

  @override
  String get remoteDesktopTargetTip =>
      'The target is resolved from the SSH server or monitor agent. Localhost refers to that machine.';

  @override
  String get remoteDesktopDomain => 'Domain (optional)';

  @override
  String get remoteDesktopPassword => 'Password (optional)';

  @override
  String get remoteDesktopSavePassword => 'Save password';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Stored in the encrypted database and backups.';

  @override
  String get remoteDesktopShareSession => 'Share session';

  @override
  String get remoteDesktopProtocol => 'Protocol';

  @override
  String get remoteDesktopUniqueName =>
      'Profile names must be unique for this server.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'Classic VNC passwords are limited to 8 ASCII bytes.';

  @override
  String get remoteDesktopNameRequired => 'Enter a profile name.';

  @override
  String get remoteDesktopHostRequired => 'Enter a target host.';

  @override
  String get remoteDesktopPortRequired => 'Enter a valid port.';

  @override
  String get remoteDesktopUsernameRequired => 'Enter the RDP username.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Classic VNC passwords must contain ASCII characters only.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Certificate confirmation required';

  @override
  String get remoteDesktopWaiting => 'Waiting for desktop…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Remote desktop certificate changed';

  @override
  String get remoteDesktopTrustCertificate => 'Trust certificate?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'The certificate fingerprint no longer matches the saved value. Verify the new fingerprint before replacing trust.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'The system could not verify this certificate. Verify its SHA-256 fingerprint before continuing.';

  @override
  String get remoteDesktopReplaceTrust => 'Replace trust';

  @override
  String get remoteDesktopTrustReconnect => 'Trust and reconnect';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'Delete remote desktop profile “$name”?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Reconnecting ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Previously trusted\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Subject: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Issuer: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Valid: $start – $end';
  }
}
