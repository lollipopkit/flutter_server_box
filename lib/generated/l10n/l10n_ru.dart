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
  String get askAiInsertTerminal => 'Вставить в терминал';

  @override
  String get remoteDesktop => 'Удалённый рабочий стол';

  @override
  String get askAiRiskReadOnly => 'Только чтение';

  @override
  String get askAiRiskCaution => 'Изменяет систему';

  @override
  String get askAiRiskUnvetted => 'Непроверенный хост';

  @override
  String get askAiRiskDestructive => 'Высокий риск';

  @override
  String get askAiAutoRunSafeCommands =>
      'Автоматически выполнять команды только для чтения';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Выполняется, только если и модель, и локальная проверка считают команду только для чтения';

  @override
  String get askAiHistory => 'История диалогов';

  @override
  String get askAiNewConversation => 'Новый диалог';

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
  String nTags(int count) {
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
  String icloudBackupStatusSummary(String lastModified, String remoteState) {
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
  String clearServerStatsContent(String serverName) {
    return 'Вы уверены, что хотите очистить статистику соединений для сервера \"$serverName\"? Это действие не может быть отменено.';
  }

  @override
  String clearServerStatsTitle(String serverName) {
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
  String get customCmd => 'Пользовательские команды';

  @override
  String get deleteServers => 'Удалить серверы пакетно';

  @override
  String get deleteDirRecursive => 'Удалить папку и всё её содержимое';

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
  String dl2Local(String fileName) {
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
  String fileTooLarge(String file, String size, String sizeMax) {
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
  String jumpServersNotFoundFmt(String serverName, String jumpIds) {
    return 'Промежуточные серверы для $serverName не найдены: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(String name) {
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
  String madeWithLove(String myGithub) {
    return 'Создано с ❤️ by $myGithub';
  }

  @override
  String get maxConcurrency => 'Максимальная параллельность';

  @override
  String get maxRetryCount =>
      'Максимальное количество попыток переподключения к серверу';

  @override
  String get mirror => 'Зеркало';

  @override
  String get needRestart => 'Требуется перезапуск приложения';

  @override
  String get newContainer => 'Создать контейнер';

  @override
  String get noConnectionStatsData => 'Нет данных статистики соединений';

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
  String get privateKey => 'Приватный ключ';

  @override
  String privateKeyNotFoundFmt(String keyId) {
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
  String get proxyCommandNeedsLinux =>
      'ProxyCommand выполняется в среде Linux на этом устройстве. Сначала установите систему Linux.';

  @override
  String get proxyCommandMobileTip =>
      'На телефоне команда выполняется в выбранной системе Linux. Сначала установите в неё используемые инструменты (nc, socat, …).';

  @override
  String get pveIgnoreCertTip =>
      'Не рекомендуется включать, обратите внимание на риски безопасности! Если вы используете стандартный сертификат от PVE, вам нужно включить эту опцию.';

  @override
  String get pvePasswordRequired =>
      'Требуется пароль PVE. Задайте его в настройках сервера.';

  @override
  String get pveOtpRequired =>
      'На этом сервере PVE включена двухфакторная аутентификация. Введите код OTP.';

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
    String distro,
    String installed,
    String latest,
    String pm,
  ) {
    return 'Установлен $distro $installed, доступен $latest. Обновление заменит весь контейнер: данные $pm будут потеряны';
  }

  @override
  String linuxSystemInUse(String name) {
    return 'Закройте терминалы на $name, прежде чем удалять';
  }

  @override
  String get rootfsSubtitle =>
      'Пользовательское окружение Linux на этом устройстве';

  @override
  String rootfsInstallTip(String distro, String version, int size) {
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
  String selected(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get sendTo => 'Отправить в…';

  @override
  String get serverFuncBtns => 'Кнопки функций сервера';

  @override
  String get serverOrder => 'Порядок серверов';

  @override
  String get serverOverview => 'Обзор серверов';

  @override
  String get serverOverviewTip =>
      'Показывать сводку вверху списка серверов и панель серверов над открытым сервером';

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
  String spentTime(String time) {
    return 'Затрачено времени: $time';
  }

  @override
  String sshConfigAllExist(int duplicateCount) {
    return 'Все серверы уже существуют (найдено $duplicateCount дубликатов)';
  }

  @override
  String sshConfigDuplicatesSkipped(int duplicateCount) {
    return '$duplicateCount дубликатов будут пропущены';
  }

  @override
  String get sshConfigFound => 'Мы нашли SSH-конфигурацию в вашей системе';

  @override
  String sshConfigFoundServers(int totalCount) {
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
  String sshConfigImported(int count) {
    return 'Импортировано $count серверов из SSH-конфигурации';
  }

  @override
  String sshHostKeyChangedDesc(String serverName) {
    return 'SSH-ключ хоста для $serverName изменился. Продолжайте только если доверяете этому серверу.';
  }

  @override
  String get sshHostKeyType => 'Тип ключа хоста SSH';

  @override
  String get sshKnownHostKeys => 'Известные хосты';

  @override
  String get sshKnownHostKeysTip => 'Ключи хостов, принятые этим приложением';

  @override
  String sshHostKeyNewDesc(String serverName) {
    return 'Получен новый SSH-ключ хоста от $serverName. Проверьте отпечаток перед продолжением.';
  }

  @override
  String sshHostKeyStoredFingerprint(String fingerprint) {
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
  String sshConfigServersToImport(int importCount) {
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
  String switchTo(String val) {
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
  String get viewDetails => 'Просмотр деталей';

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
      'В настройках терминала их можно переставить, включить другие (файлы, sudo, F1–F12…) или скрыть те, которыми вы не пользуетесь.';

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
  String portForward_deleteConfirmFmt(String name) {
    return 'Удалить $name?';
  }

  @override
  String get sponsor => 'Спонсор';

  @override
  String get sortByJoinTime => 'По времени добавления';

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
  String get tmuxNewSession => 'Новая сессия';

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
  String get tmuxAttached => 'Подключена';

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
  String serviceExitStatus(int code) {
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
  String geoDataCurrent(String month) {
    return '$month уже установлен.';
  }

  @override
  String geoDataConsent(String download, String disk) {
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
  String benchmarkEstimatedTime(int minutes) {
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
  String funcUnavailableFmt(String func) {
    return '$func недоступно через это подключение к серверу.';
  }

  @override
  String funcNeedsAgentGrant(String func, String setting) {
    return 'Для «$func» нужно включить $setting в Monitor agent.';
  }

  @override
  String funcNeedsAgentUpdate(String func) {
    return 'Для «$func» нужна более новая версия Monitor agent.';
  }

  @override
  String get portForwardRemoteNeedsAgent =>
      'Для удалённой переадресации через Monitor agent нужна более новая версия: обновите его на сервере.';

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
  String agentRetentionFmt(String kept) {
    return 'Агент хранит $kept';
  }

  @override
  String get agentServerTools => 'Инструменты серверов';

  @override
  String get agentServerToolsTip =>
      'Выполнять команды и читать или записывать файлы на ваших серверах, подключаться к другим хостам по SSH и использовать действия самого ServerBox.';

  @override
  String get agentTerminalTools => 'Терминал';

  @override
  String get agentTerminalToolsTip =>
      'В собственных чатах терминала: читать то, что он показывает, и выполнять команды на его сервере.';

  @override
  String get agentToolTerminalScreen => 'Прочитать экран';

  @override
  String get agentProviders => 'Провайдеры';

  @override
  String get agentProvidersTip => 'Ключи API, модели и модель для нового чата';

  @override
  String get agentTools => 'Инструменты';

  @override
  String get agentToolsTip => 'Что может использовать Agent, и его серверы MCP';

  @override
  String get agentSnippetToolsTip =>
      'Просмотр, добавление, изменение и удаление snippets. Изменения подтверждаются.';

  @override
  String get agentVirtToolsTip =>
      'Чтение ВМ и контейнеров, загруженных вкладкой «Виртуализация».';

  @override
  String get agentBenchmarkToolsTip =>
      'Чтение результатов бенчмарка; запуск или остановка с вашего одобрения.';

  @override
  String get agentRemoteDesktopToolsTip =>
      'Список профилей удалённого рабочего стола; подключение и отключение с вашего одобрения.';

  @override
  String get agentSkills => 'Skills';

  @override
  String get agentSkillsTip =>
      'Инструкции для определённых задач, устанавливаются с GitHub или по ссылке';

  @override
  String get agentPermissions => 'Разрешения';

  @override
  String get agentEmptyHint =>
      'Спросите о своих серверах или попросите Agent что-то на них сделать.';

  @override
  String get agentTerminalEmptyHint =>
      'Спросите об этом сервере. Agent может читать этот терминал и выполнять здесь команды.';

  @override
  String oldestSampleFmt(String time) {
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
  String atTimeFmt(String time) {
    return 'в $time';
  }

  @override
  String get stored => 'сохранено';

  @override
  String lastSampleFmt(String ago) {
    return 'последний замер $ago';
  }

  @override
  String staleSinceFmt(String ago, String time) {
    return 'Всё, что ниже, — на $time ($ago).';
  }

  @override
  String noDataBeforeFmt(String time) {
    return 'нет данных до $time';
  }

  @override
  String loadingRangeFmt(String range) {
    return 'Загрузка $range…';
  }

  @override
  String noStoredHistoryFor(String metric) {
    return 'Нет сохранённой истории для «$metric»';
  }

  @override
  String devicesFmt(int count) {
    return 'устройств: $count';
  }

  @override
  String devicesBusiestFmt(int count, String name) {
    return 'устройств: $count · самое загруженное — $name';
  }

  @override
  String devicesPlottedFmt(int plotted, int total) {
    return '$plotted из $total устройств';
  }

  @override
  String sensorsHottestFmt(int count, String name) {
    return 'датчиков: $count · самый горячий — $name';
  }

  @override
  String get oneDeviceAtLeast => 'Хотя бы одно устройство остаётся на графике.';

  @override
  String shownOfFmt(int shown, int total, String what) {
    return '$shown из $total ($what)';
  }

  @override
  String countOfFmt(int count, String what) {
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
  String diskWarningFmt(int count) {
    return 'предупреждений: $count';
  }

  @override
  String diskWrongOfFmt(int total, int wrong) {
    return '$wrong из $total устройств';
  }

  @override
  String get diskSmartSortedTip => 'Худшие сверху';

  @override
  String readAgoFmt(String ago) {
    return 'прочитано $ago';
  }

  @override
  String processesFmt(int count) {
    return 'процессов: $count';
  }

  @override
  String diskFailingFmt(int count) {
    return '$count с ошибками';
  }

  @override
  String get diskSmartOpenTip => 'Нажмите, чтобы увидеть атрибуты';

  @override
  String get cycle => 'Циклы';

  @override
  String get window => 'окно';

  @override
  String ofFmt(String total) {
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
  String get transportNoneOn =>
      'Оба выключены — к этому серверу нельзя подключиться.';

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
  String tagCreateFmt(String tag) {
    return 'Создать #$tag';
  }

  @override
  String get tagOnThisServer => 'на этом сервере';

  @override
  String tagServersFmt(int count) {
    return 'серверов: $count';
  }

  @override
  String tagOnThisServerFmt(int count) {
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
  String scheduledTaskNextInFmt(String time) {
    return 'in $time';
  }

  @override
  String get scheduledTaskEnabled => 'Enabled';

  @override
  String get scheduledTaskCommentedOut => 'Commented out';

  @override
  String scheduledTaskSummaryFmt(int enabled, int total) {
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
  String scheduledTaskEmptyFmt(String user) {
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
  String cronEveryMinsFmt(int minutes) {
    return 'Каждые $minutes мин.';
  }

  @override
  String cronHourlyAtFmt(String minute) {
    return 'Каждый час в :$minute';
  }

  @override
  String cronEveryHoursFmt(int hours) {
    return 'Каждые $hours ч.';
  }

  @override
  String cronEveryHoursAtFmt(int hours, String minute) {
    return 'Каждые $hours ч. в :$minute';
  }

  @override
  String cronDailyAtFmt(String time) {
    return 'Каждый день в $time';
  }

  @override
  String cronWeekdaysAtFmt(String time) {
    return 'По будням в $time';
  }

  @override
  String cronWeekdayAtFmt(String day, String time) {
    return 'Каждый $day в $time';
  }

  @override
  String cronMonthlyAtFmt(int day, String time) {
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
  String get remoteDesktopExitFullScreen => 'Выйти из полноэкранного режима';

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
  String get remoteDesktopAddProfile => 'Добавить профиль';

  @override
  String get remoteDesktopNoProfiles =>
      'Нет профилей удалённого рабочего стола';

  @override
  String get remoteDesktopAdd => 'Добавить удалённый рабочий стол';

  @override
  String get remoteDesktopEdit => 'Изменить удалённый рабочий стол';

  @override
  String get remoteDesktopTargetTip =>
      'Адрес определяется через SSH-сервер или агент Monitor. localhost указывает на эту машину.';

  @override
  String get remoteDesktopDomain => 'Домен (необязательно)';

  @override
  String get remoteDesktopPassword => 'Пароль (необязательно)';

  @override
  String get remoteDesktopSavePassword => 'Сохранить пароль';

  @override
  String get remoteDesktopSavePasswordTip =>
      'Хранится в зашифрованной базе данных. Резервные копии включают сохранённые пароли и шифруются только при заданном пароле резервной копии.';

  @override
  String get remoteDesktopShareSession => 'Поделиться сеансом';

  @override
  String get remoteDesktopProtocol => 'Протокол';

  @override
  String get remoteDesktopUniqueName =>
      'Имена профилей должны быть уникальными для этого сервера.';

  @override
  String get remoteDesktopVncPasswordLength =>
      'Классические пароли VNC ограничены 8 байтами ASCII.';

  @override
  String get remoteDesktopNameRequired => 'Введите имя профиля.';

  @override
  String get remoteDesktopHostRequired => 'Введите целевой хост.';

  @override
  String get remoteDesktopPortRequired => 'Введите допустимый порт.';

  @override
  String get remoteDesktopUsernameRequired => 'Введите имя пользователя RDP.';

  @override
  String get remoteDesktopNameInvalid =>
      'Имя профиля — не более 64 символов, без переносов строки.';

  @override
  String get remoteDesktopHostInvalid =>
      'Целевой хост не может содержать пробелы или переносы строки.';

  @override
  String get remoteDesktopCredentialInvalid =>
      'Имя пользователя и домен — не более 256 символов, без переносов строки.';

  @override
  String get remoteDesktopVncPasswordAscii =>
      'Классические пароли VNC могут содержать только символы ASCII.';

  @override
  String get remoteDesktopCertificateRequired =>
      'Требуется подтверждение сертификата';

  @override
  String get remoteDesktopWaiting => 'Ожидание рабочего стола…';

  @override
  String get remoteDesktopCertificateChanged =>
      'Сертификат удалённого рабочего стола изменился';

  @override
  String get remoteDesktopTrustCertificate => 'Доверять сертификату?';

  @override
  String get remoteDesktopCertificateChangedTip =>
      'Отпечаток сертификата больше не совпадает с сохранённым значением. Проверьте новый отпечаток, прежде чем заменять доверие.';

  @override
  String get remoteDesktopCertificateUnverifiedTip =>
      'Системе не удалось проверить этот сертификат. Проверьте его отпечаток SHA-256, прежде чем продолжить.';

  @override
  String get remoteDesktopReplaceTrust => 'Заменить доверие';

  @override
  String get remoteDesktopTrustReconnect => 'Доверять и подключиться снова';

  @override
  String remoteDesktopDeleteProfile(String name) {
    return 'Удалить профиль удалённого рабочего стола «$name»?';
  }

  @override
  String remoteDesktopReconnectAttempt(int attempt) {
    return 'Повторное подключение ($attempt/3)…';
  }

  @override
  String remoteDesktopPreviousCertificate(String fingerprint) {
    return 'Ранее доверенный отпечаток\n$fingerprint';
  }

  @override
  String remoteDesktopCertificateSubject(String subject) {
    return 'Субъект: $subject';
  }

  @override
  String remoteDesktopCertificateIssuer(String issuer) {
    return 'Издатель: $issuer';
  }

  @override
  String remoteDesktopCertificateValidity(String start, String end) {
    return 'Действителен: $start – $end';
  }

  @override
  String get pveAuthToken => 'API-токен';

  @override
  String get pveVersionLow =>
      'Эта функция в настоящее время находится на стадии тестирования и была протестирована только на PVE 8+. Используйте ее с осторожностью.';

  @override
  String get pveTokenId => 'ID токена';

  @override
  String get pveTokenSecret => 'Секрет токена';

  @override
  String get pveTokenTip =>
      'Создайте его в PVE: Датацентр → Права доступа → API Tokens. Нужны права VM.Audit, VM.PowerMgmt, VM.Console, VM.Snapshot, VM.Snapshot.Rollback, Datastore.Audit и Sys.Audit на отображаемых путях; при включённом разделении привилегий выдайте их самому токену.';

  @override
  String pveTokenNoPrivileges(String account, String command) {
    return 'Токену $account ничего не видно на этом хосте. Токен с разделением привилегий не наследует права пользователя; выдайте их на хосте PVE:\n$command\nили снимите для токена флажок «Privilege Separation».';
  }

  @override
  String pveUserNoPrivileges(String account, String command) {
    return '$account ничего не видно на этом хосте. Выдайте права на хосте PVE:\n$command';
  }

  @override
  String get pveTokenIdInvalid =>
      'ID токена должен иметь вид user@realm!tokenid';

  @override
  String get pvePasswordAuthTip =>
      'Вход выполняется от имени пользователя SSH в realm PAM с паролем SSH, а если SSH использует ключ — с паролем PVE ниже. При необходимости запрашивается код двухфакторной аутентификации.';

  @override
  String get pveCertUnpinned =>
      'Пока ничего не подтверждено. Если сертификат не подписан доверенным CA, при следующем подключении он будет показан для подтверждения.';

  @override
  String get pveCertForget => 'Забыть сертификат';

  @override
  String get pveCertForgetTip =>
      'При следующем подключении сертификат PVE снова будет показан для подтверждения.';

  @override
  String get virtualization => 'Виртуализация';

  @override
  String get virtIntro =>
      'Управление виртуальными машинами и контейнерами на хостах Proxmox VE и libvirt/KVM: состояние, управление питанием и консоли.';

  @override
  String get virtIntroPveMoved =>
      'Proxmox VE перенесён со страницы сервера в эту вкладку. Карточка PVE сервера открывает её здесь.';

  @override
  String get virtIntroLibvirt =>
      'Сервер с установленным virsh из libvirt отображается как хост вместе с его виртуальными машинами QEMU/KVM.';

  @override
  String get virtIntroTransports =>
      'Оба работают по SSH, через агент Monitor или на этом устройстве.';

  @override
  String get virtIntroTokens =>
      'PVE может входить по API-токену вместо пароля. Задаётся на странице редактирования сервера, в разделе PVE.';

  @override
  String get virtIntroInBar => 'Она добавлена на панель вкладок.';

  @override
  String get virtIntroInMore =>
      'Она находится в разделе «Ещё». Во вкладках дома в настройках её можно перенести на панель вкладок.';

  @override
  String get virtGuests => 'Виртуальные машины';

  @override
  String get virtHosts => 'Хосты';

  @override
  String get virtCheckServer => 'Проверить этот сервер';

  @override
  String get virtCheckAll => 'Проверить все серверы';

  @override
  String get virtProbeNotChecked => 'Ещё не проверен';

  @override
  String get virtProbeAbsent => 'Не хост';

  @override
  String virtProbeContainer(String kind) {
    return 'Контейнер $kind';
  }

  @override
  String get virtProbeContainerTip =>
      'Этот сервер работает в контейнере, то есть это гость, а не хост. Управлять им нужно с хоста, на котором он запущен.';

  @override
  String get virtProbePve => 'PVE, не настроен';

  @override
  String virtPveSetupTip(String version) {
    return 'На этом сервере работает $version. Укажите доступ к API в настройках сервера (рекомендуется API-токен), чтобы управлять здесь его виртуальными машинами и контейнерами.';
  }

  @override
  String get virtNoHosts => 'Нет хостов виртуализации';

  @override
  String get virtNoHostsTip =>
      'Сервер с Proxmox VE и указанным доступом к API является хостом, как и сервер, на котором отвечает virsh. Остальные серверы можно проверить в переключателе хостов.';

  @override
  String get virtNoGuests => 'Нет виртуальных машин или контейнеров';

  @override
  String get virtPaused => 'Приостановлена';

  @override
  String get virtStarting => 'Запуск…';

  @override
  String get virtStopping => 'Остановка…';

  @override
  String get virtRebooting => 'Перезагрузка…';

  @override
  String get virtMigrating => 'Миграция…';

  @override
  String get virtBackingUp => 'Резервное копирование…';

  @override
  String get virtResume => 'Возобновить';

  @override
  String get virtOverview => 'Обзор';

  @override
  String get virtConsole => 'Консоль';

  @override
  String get virtConsoleNone =>
      'Для этой гостевой системы консоль не настроена';

  @override
  String get virtConsoleGraphical => 'Графическая';

  @override
  String get virtVncPasswordNeeded => 'Этот дисплей запрашивает пароль';

  @override
  String get virtConsoleSerialTip =>
      'Открывает последовательную консоль гостя через virsh на хосте. «Отключить» или Ctrl+] возвращает в оболочку хоста.';

  @override
  String virtConsoleVia(String transport) {
    return 'через $transport';
  }

  @override
  String get virtConsoleEnterTip => 'Нет вывода? Нажмите Enter';

  @override
  String virtConsoleAutoEnter(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds секунд',
      few: '$seconds секунды',
      one: '$seconds секунду',
    );
    return 'Enter будет нажат через $_temp0, чтобы показать приглашение';
  }

  @override
  String get virtConsoleEnterNow => 'Сейчас';

  @override
  String get virtOffTip =>
      'Запустите, чтобы видеть здесь ЦП, память, диск и сеть в реальном времени.';

  @override
  String get virtAllocated => 'Выделено';

  @override
  String virtRunningCount(int running, int total) {
    return '$running работают · всего $total';
  }

  @override
  String get virtTemplate => 'Шаблон';

  @override
  String get virtAutostart => 'Запускается вместе с хостом';

  @override
  String get virtErrUnreachable => 'Не удалось связаться с этим хостом';

  @override
  String get virtErrNotConfigured => 'Настройки PVE этого сервера неполные';

  @override
  String get virtErrNotConfiguredTip =>
      'Проверьте адрес, а также пароль или API-токен в настройках сервера.';

  @override
  String get virtErrAuthFailed => 'Хост отклонил вход';

  @override
  String get virtErrCertUnconfirmed => 'Подтвердите сертификат хоста';

  @override
  String get virtErrCertChanged => 'Сертификат хоста изменился';

  @override
  String get virtErrRelayNotGranted => 'Агент Monitor не пересылает соединения';

  @override
  String get virtErrExecNotGranted => 'Агент Monitor не выполняет команды';

  @override
  String get virtErrNotInstalled => 'virsh не установлен на этом сервере';

  @override
  String get virtErrServerRemoved => 'Этот сервер больше не существует';

  @override
  String get virtErrSudoRequired => 'Для доступа к libvirt sudo требует пароль';

  @override
  String get virtErrSudoRejected => 'sudo отклонил пароль';

  @override
  String get virtErrInvalidResponse => 'Хост ответил в неожиданном виде';

  @override
  String get virtErrActionFailed => 'Хост отклонил действие';

  @override
  String get remoteSessionIdleTimeout => 'Закрывать после ухода';

  @override
  String get remoteSessionIdleTimeoutTip =>
      'Сколько удалённый рабочий стол или консоль гостя остаются подключёнными после того, как вы их покинули. Перед закрытием уведомление даёт 10 секунд, чтобы сохранить подключение.';

  @override
  String get remoteSessionKeepAlive => 'Не закрывать';

  @override
  String get remoteSessionClosedAway => 'Закрыто из-за бездействия';

  @override
  String remoteSessionClosingIn(int seconds) {
    return 'Закроется через $seconds с';
  }

  @override
  String get virtSnapshots => 'Снимки';

  @override
  String get virtSnapshotCreate => 'Сделать снимок';

  @override
  String get virtSnapshotNone => 'Снимков пока нет';

  @override
  String get virtSnapshotWithMemory => 'Диски и память';

  @override
  String get virtSnapshotDiskOnly => 'Только диски';

  @override
  String get virtSnapshotParent => 'Родитель';

  @override
  String get virtSnapshotRevert => 'Откатить';

  @override
  String get virtSnapshotMemory => 'Включить память';

  @override
  String get virtSnapshotMemoryTip =>
      'После отката гость продолжит работу с этого момента.';

  @override
  String get virtSnapshotMemoryAlways =>
      'Здесь снимок работающего гостя всегда включает память.';

  @override
  String get virtSnapshotMemoryOff =>
      'Гость не запущен, поэтому сохраняются только диски.';

  @override
  String get virtSnapshotNameInvalid =>
      'Сначала буква, затем буквы, цифры, - или _; от 2 до 40 символов.';

  @override
  String get virtSnapshotNameTaken => 'Снимок с таким именем уже есть.';

  @override
  String get virtSnapshotRevertTip =>
      'Откат отменит все изменения, сделанные после снимка.';

  @override
  String virtSnapshotRevertAsk(String guest, String snapshot) {
    return 'Откатить $guest к $snapshot? Все изменения после него будут потеряны.';
  }

  @override
  String virtSnapshotRevertStops(String guest) {
    return 'В этом снимке нет памяти: $guest будет остановлен.';
  }

  @override
  String get virtSnapshotStartAfter => 'Запустить после';

  @override
  String get virtVolumes => 'Тома';

  @override
  String get virtNoPools => 'Нет пулов хранения';

  @override
  String get virtNoNetworks => 'Нет сетей';

  @override
  String get virtPoolInactive =>
      'Пул не активен, поэтому его тома нельзя перечислить.';

  @override
  String get virtShared => 'Общий для узлов';

  @override
  String get virtBackingFile => 'Базовый файл';

  @override
  String get virtNetIsolated => 'Изолированная';

  @override
  String get virtNetBridged => 'Мост';

  @override
  String get virtNetRouted => 'Маршрутизируемая';

  @override
  String get virtBridge => 'Мост';

  @override
  String get virtPorts => 'Порты';

  @override
  String get virtAttachedGuests => 'Гости в ней';

  @override
  String get virtNoAttachedGuests => 'Гостей нет';

  @override
  String get virtCreateVm => 'Новая виртуальная машина';

  @override
  String get virtCreateLxc => 'Новый контейнер';

  @override
  String get virtCreateGuest => 'Новая виртуальная машина или контейнер';

  @override
  String get virtKindVm => 'Виртуальная машина';

  @override
  String get virtKindLxc => 'Контейнер';

  @override
  String get virtHostname => 'Имя хоста';

  @override
  String get virtInstallMedia => 'Установочный носитель';

  @override
  String get virtNoIsos => 'На этом хосте нет ISO-образов';

  @override
  String get virtNoTemplates =>
      'На этом хосте нет шаблонов контейнеров. Скачать шаблон можно в разделе «Шаблоны CT» хранилища в PVE.';

  @override
  String get virtNoDiskStorage =>
      'На этом хосте нет хранилища для нового диска';

  @override
  String get virtStartAfterCreate => 'Запустить после создания';

  @override
  String get virtUnprivileged => 'Непривилегированный контейнер';

  @override
  String get virtUnprivilegedTip => 'Его root — обычный пользователь на хосте.';

  @override
  String get virtSshKeys => 'Открытые ключи SSH';

  @override
  String get virtCredentialsTip => 'Пароль root, ключи SSH или и то и другое.';

  @override
  String virtCreated(String name) {
    return '$name создан';
  }

  @override
  String virtCreatedNotStarted(String name) {
    return '$name создан, но не запустился';
  }

  @override
  String get virtErrExists => 'Гость или диск с таким именем уже существует';

  @override
  String get virtCreateNameInvalidLibvirt =>
      'Буквы, цифры, ., _ и -, начиная с буквы или цифры; до 63 символов.';

  @override
  String get virtCreateNameInvalidPve =>
      'Буквы, цифры и -, части разделены точками; до 63 символов.';

  @override
  String get virtCreateNameTaken => 'Гость с таким именем уже есть.';

  @override
  String get virtCreateVmidTaken => 'Этот VMID занят.';

  @override
  String get virtCreateCoresInvalid => 'Больше ядер, чем допускает этот хост.';

  @override
  String get virtCreateMemoryInvalid => 'Недостаточно памяти.';

  @override
  String get virtCreateStorageMissing => 'Выберите, где будет диск.';

  @override
  String get virtCreateDiskInvalid => 'От 1 ГиБ до 64 ТиБ.';

  @override
  String get virtCreateTemplateMissing => 'Выберите шаблон.';

  @override
  String get virtCreateCredentialsMissing =>
      'Задайте пароль root или ключ SSH.';

  @override
  String virtCreatePasswordShort(int min) {
    return 'Не менее $min символов.';
  }

  @override
  String get virtCreateSshKeysInvalid =>
      'По одному открытому ключу OpenSSH на строку.';

  @override
  String get virtDeleteDisks => 'Удалить и его диски';

  @override
  String get virtDeleteDisksPve =>
      'Его диски удаляются вместе с ним; установочный носитель сохранится.';

  @override
  String virtDeleted(String name) {
    return '$name удалён';
  }

  @override
  String get pveTokenTipCreate =>
      'Для создания и удаления гостей также нужны VM.Allocate, VM.Config.*, Datastore.AllocateSpace и SDN.Use.';

  @override
  String get pveTokenTipHardware =>
      'Для изменения оборудования нужны VM.Config.CPU, VM.Config.Memory, VM.Config.Disk, VM.Config.CDROM, VM.Config.Network и VM.Config.Options; для новых дисков и интерфейсов также Datastore.AllocateSpace и SDN.Use. Для видеокарты и устройств USB и PCI нужна также VM.Config.HWType; для устройства через сопоставление ресурсов нужна Mapping.Use на нём, а для списка сопоставлений — Mapping.Audit.';

  @override
  String get pveTokenTipBackup =>
      'Клонирование требует VM.Clone, резервное копирование и восстановление — VM.Backup, превращение в шаблон — VM.Allocate; заданиям резервного копирования нужны ещё Sys.Audit для чтения и Sys.Modify на / для создания, изменения и удаления, а также Datastore.AllocateSpace там, куда попадает копия или резервная копия.';

  @override
  String get virtErrConflict => 'Изменено в другом месте';

  @override
  String get virtErrConflictTip =>
      'Кто-то изменил эту конфигурацию после того, как она была прочитана здесь, поэтому ничего не изменено. Она прочитана заново: повторите изменение, если оно ещё нужно.';

  @override
  String get virtHardware => 'Оборудование';

  @override
  String get virtHwAddDisk => 'Добавить диск';

  @override
  String get virtHwAddMount => 'Добавить точку монтирования';

  @override
  String get virtHwAddNic => 'Добавить сетевой интерфейс';

  @override
  String get virtHwAppliesOnRestart =>
      'Сохранено. Вступит в силу при следующем запуске.';

  @override
  String get virtHwAutostart => 'Запускать вместе с хостом';

  @override
  String get virtHwAutostartPve => 'onboot · запуск в порядке VMID';

  @override
  String get virtHwBalloonLibvirt => 'Текущая память';

  @override
  String get virtHwBalloonNote =>
      'Позволяет хосту забирать свободную память гостя при нехватке памяти';

  @override
  String get virtHwBoot => 'Загрузка';

  @override
  String get virtHwBootOrder => 'Порядок загрузки';

  @override
  String get virtHwBootTip =>
      'Стрелки меняют порядок; нажатие включает или выключает загрузку с устройства.';

  @override
  String get virtHwCdrom => 'CD-ROM';

  @override
  String get virtHwConfigFile => 'Файл конфигурации';

  @override
  String get virtHwCores => 'Ядра';

  @override
  String get virtHwCpuTypeDefault => 'По умолчанию';

  @override
  String get virtHwDeleteVolume => 'Также удалить его том';

  @override
  String get virtHwDetach => 'Отключить';

  @override
  String get virtHwDiskHotplug => 'Горячее подключение: можно добавить на ходу';

  @override
  String get virtHwDisksLxc => 'Корневой диск и точки монтирования';

  @override
  String get virtHwEject => 'Извлечь';

  @override
  String get virtHwEmpty => 'Без носителя';

  @override
  String get virtHwFirewall => 'Брандмауэр';

  @override
  String virtHwFree(String size) {
    return 'свободно $size';
  }

  @override
  String get virtHwGrow => 'Увеличить';

  @override
  String get virtHwGrowNote => 'Диск можно только увеличить.';

  @override
  String get virtHwGrowNoteRunning =>
      'Диск можно только увеличить. После увеличения на ходу раздел нужно расширить внутри гостя.';

  @override
  String get virtHwGuestUsed => 'Используется гостем';

  @override
  String virtHwHostCpus(int threads, int allocated) {
    return 'Хост $threads потоков · выделено $allocated';
  }

  @override
  String virtHwHostMem(String total, String allocated) {
    return 'Хост $total · выделено $allocated';
  }

  @override
  String get virtHwHotplugNow => 'Горячее подключение: сразу вступает в силу.';

  @override
  String get virtHwIssueBootEmpty => 'Отметьте хотя бы одно устройство';

  @override
  String virtHwIssueCpuCount(int max) {
    return 'Всего от 1 до $max vCPU';
  }

  @override
  String get virtHwIssueCpuOnline => 'Активные vCPU: от 1 до общего числа';

  @override
  String get virtHwIssueDiskShrink =>
      'Больше текущего: диски только увеличиваются';

  @override
  String get virtHwIssueDiskSize => 'От 1 до 65536 ГиБ';

  @override
  String virtHwIssueMemory(int min, int max) {
    return 'От $min до $max МиБ';
  }

  @override
  String get virtHwIssueMemoryMin => 'Не больше памяти';

  @override
  String get virtHwIssueMountPoint => 'Абсолютный путь, например /data';

  @override
  String get virtHwIssueStorageSpace => 'Больше, чем свободно в хранилище';

  @override
  String get virtHwLater => 'Вступит в силу после перезапуска';

  @override
  String get virtHwLess => 'Меньше';

  @override
  String get virtHwLinkDown => 'Отключён';

  @override
  String get virtHwLinkNote =>
      'Выключено — гость видит отключённый кабель; перезапуск не нужен';

  @override
  String get virtHwLinkUp => 'Подключён';

  @override
  String get virtHwMac => 'MAC-адрес';

  @override
  String get virtHwModel => 'Модель';

  @override
  String get virtHwMore => 'Больше';

  @override
  String get virtHwMountFromPool =>
      'Точки монтирования выделяются прямо из хранилища';

  @override
  String get virtHwMountPoint => 'Точка монтирования';

  @override
  String get virtHwMoveDown => 'Вниз';

  @override
  String get virtHwMoveUp => 'Вверх';

  @override
  String get virtHwNewDisk => 'Новый диск';

  @override
  String get virtHwNewMount => 'Новая точка монтирования';

  @override
  String get virtHwNewNic => 'Новый сетевой интерфейс';

  @override
  String get virtHwNicHotplug => 'Интерфейсы virtio подключаются на ходу';

  @override
  String get virtHwNics => 'Сетевые интерфейсы';

  @override
  String get virtHwNoMedia => 'Нет носителя';

  @override
  String get virtHwNoNetworks => 'Здесь нет сетей или мостов';

  @override
  String get virtHwNoStorage => 'Здесь нет хранилища для дисков';

  @override
  String get virtHwOnline => 'Активные vCPU';

  @override
  String get virtHwPendingBanner =>
      'Часть изменений оборудования вступит в силу после перезапуска';

  @override
  String get virtHwPickNet => 'Выберите сеть';

  @override
  String get virtHwPickPool => 'Выберите хранилище и размер';

  @override
  String get virtHwProcessor => 'Процессор';

  @override
  String get virtHwRemove => 'Удалить';

  @override
  String get virtHwRemoveCdrom => 'Удалить CD-ROM';

  @override
  String virtHwRemoveDiskAsk(String disk, String guest) {
    return 'Удалить $disk из $guest?';
  }

  @override
  String virtHwRemoveNicAsk(String nic, String guest) {
    return 'Удалить $nic из $guest?';
  }

  @override
  String get virtHwResources => 'Ресурсы';

  @override
  String get virtHwRestartNow => 'Перезапустить';

  @override
  String get virtHwRevert => 'Отменить';

  @override
  String get virtHwRevertAll => 'Отменить все';

  @override
  String get virtSetRenameStopped =>
      'Выключите гостя, чтобы переименовать: libvirt переименовывает только неработающего гостя.';

  @override
  String virtSetIssueDescription(int max) {
    return 'Не более $max байт (UTF-8), без управляющих символов.';
  }

  @override
  String get virtSetManualStart => 'Запуск вручную';

  @override
  String get virtSetProtection => 'Защита';

  @override
  String get virtSetProtectionNote =>
      'Запрещает удалять гостя и менять его диски';

  @override
  String get virtSetIrreversible => 'Нельзя отменить';

  @override
  String get virtSetDeleteStopFirst => 'Выключите его перед удалением.';

  @override
  String get virtSetDeleteProtected =>
      'Включена защита: сначала отключите её в разделе «Общие».';

  @override
  String get virtSetDeleteAgain => 'Нажмите ещё раз для подтверждения';

  @override
  String virtSetDeleteConfirm(String name) {
    return 'Удалить $name';
  }

  @override
  String get virtSetDeleteVm => 'Удалить виртуальную машину';

  @override
  String get virtSetDeleteLxc => 'Удалить контейнер';

  @override
  String get virtHwSockets => 'Сокеты';

  @override
  String get virtHwSource => 'Источник';

  @override
  String get virtHwSwap => 'Подкачка';

  @override
  String get virtHwTopology => 'Сокеты × ядра';

  @override
  String virtHwTopologyValue(int sockets, int cores, int threads) {
    return '$sockets сокет. × $cores ядер × $threads пот.';
  }

  @override
  String virtHwTotal(String size) {
    return 'всего $size';
  }

  @override
  String get virtHwVolumeKept =>
      'Удалён, но работающий гость ещё использует диск, поэтому том сохранён. Диск будет отключён при следующем запуске.';

  @override
  String get virtHwBus => 'Шина';

  @override
  String get virtHwCache => 'Кэш';

  @override
  String get virtHwBusStopped =>
      'Шину можно сменить только у остановленного гостя.';

  @override
  String get virtHwMacGenerate => 'Сгенерировать';

  @override
  String get virtHwIssueMac =>
      'Нужен одноадресный MAC-адрес, например 52:54:00:12:34:56';

  @override
  String get virtHwIssueStopFirst => 'Сначала остановите гостя';

  @override
  String get virtHwIssueStorageMissing => 'Сначала выберите хранилище';

  @override
  String get virtHwIssueDevice => 'Сначала выберите устройство';

  @override
  String get virtHwDevices => 'CD-ROM и проброс';

  @override
  String get virtHwDevicesEmpty => 'Проброс USB и PCI, CD-ROM, TPM';

  @override
  String get virtHwAddDevice => 'Добавить устройство';

  @override
  String get virtHwNewDevice => 'Новое устройство';

  @override
  String get virtHwUsbHotplug =>
      'Проброс USB поддерживает горячее подключение.';

  @override
  String get virtHwPci => 'Проброс PCI';

  @override
  String get virtHwIommuOffTitle => 'У хоста нет IOMMU';

  @override
  String get virtHwIommuOffBody =>
      'Сначала включите VT-d или AMD-Vi в BIOS хоста и IOMMU в его ядре. До этого гость с PCI-устройством не запустится.';

  @override
  String get virtHwPciTitle => 'Нужен IOMMU на хосте';

  @override
  String get virtHwPciBody =>
      'После проброса хост не сможет использовать устройство, а гость — мигрировать на ходу.';

  @override
  String virtHwIommuGroup(int group) {
    return 'Группа IOMMU $group';
  }

  @override
  String virtHwIommuShared(int count) {
    return '$count устройств в одной группе IOMMU пробрасываются вместе';
  }

  @override
  String get virtHwNoHostDevices => 'На этом хосте нет устройств для проброса';

  @override
  String get virtHwMappingsOnly =>
      'Здесь доступны только сопоставления ресурсов: PVE разрешает пробрасывать устройство напрямую только root@pam, вошедшему по паролю. Создайте сопоставления в Датацентр → Сопоставления ресурсов.';

  @override
  String get virtHwTpmNote => 'Windows 11 требует TPM 2.0.';

  @override
  String get virtHwDisplay => 'Дисплей';

  @override
  String get virtHwProtocol => 'Протокол';

  @override
  String get virtHwListen => 'Прослушивание';

  @override
  String get virtHwGpu => 'Видеокарта';

  @override
  String get virtHwListenAllTitle => 'Консоль открыта в сеть';

  @override
  String get virtHwListenAllBody =>
      'При прослушивании всех адресов консоль может открыть любой, кто достигает хоста. Оставьте 127.0.0.1 и подключайтесь через SSH-туннель.';

  @override
  String get virtHwFirmware => 'Прошивка';

  @override
  String get virtHwUefiSub =>
      'OVMF · поддерживает Secure Boot, нужна для Windows 11';

  @override
  String get virtHwBiosSub => 'SeaBIOS · старые системы и диски MBR';

  @override
  String get virtHwSecureBootNote =>
      'Загружает только подписанные ядра и загрузчики';

  @override
  String get virtHwFirmwareWarnTitle =>
      'Не меняйте прошивку установленной системы';

  @override
  String get virtHwFirmwareWarnBody =>
      'Переключение между UEFI и BIOS делает установленную систему незагружаемой.';

  @override
  String get virtHwFirmwareStopped =>
      'Прошивку можно сменить только у остановленного гостя.';

  @override
  String get virtHwSecureBootVars =>
      'Включение или выключение Secure Boot создаёт переменные EFI заново; сохранённые в них записи загрузки будут потеряны.';

  @override
  String get virtHwEfiStorage => 'Где хранить переменные EFI';

  @override
  String virtHwSwitchFirmwareAsk(String guest, String firmware) {
    return 'Переключить $guest на $firmware?';
  }

  @override
  String get virtCloneName => 'Новое имя';

  @override
  String get virtCloneFull => 'Полный клон';

  @override
  String get virtCloneCopyDisks => 'Копировать содержимое дисков';

  @override
  String get virtCloneLinkedNote =>
      'Выкл.: связанный клон, зависящий от дисков шаблона';

  @override
  String get virtCloneFullOnly =>
      'Связанный клон можно сделать только из шаблона';

  @override
  String get virtCloneEmptyNote => 'Выкл.: новые пустые диски того же размера';

  @override
  String get virtCloneStopFirst => 'Перед клонированием выключите её.';

  @override
  String get virtCloneFullShort => 'Полный';

  @override
  String get virtCloneLinkedShort => 'Связанный';

  @override
  String get virtCloneEmptyShort => 'Пустые диски';

  @override
  String get virtCloning => 'Клонирование…';

  @override
  String virtCloned(String name) {
    return 'Клонировано как $name';
  }

  @override
  String get virtBackupPlan => 'План';

  @override
  String get virtBackupPlanWhere => 'Датацентр → Резервное копирование';

  @override
  String get virtBackupNoPlanShort => 'Нет плана';

  @override
  String get virtBackupNoPlan =>
      'Ни одно плановое задание резервного копирования не включает этот гостевой хост.';

  @override
  String get virtBackupKeep => 'Хранить';

  @override
  String get virtBackupJobDisabled => 'Это задание отключено.';

  @override
  String virtBackupCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count копий',
      few: '$count копии',
      one: '$count копия',
    );
    return '$_temp0';
  }

  @override
  String virtSnapshotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count снимков',
      few: '$count снимка',
      one: '$count снимок',
    );
    return '$_temp0';
  }

  @override
  String get virtBackupNoStorage =>
      'На этом узле нет хранилища для резервных копий.';

  @override
  String get virtBackupLiveTip => 'Работает: режим snapshot, без остановки';

  @override
  String get virtBackupStoppedTip => 'Выключен: копируется как есть';

  @override
  String get virtBackupNow => 'Создать копию';

  @override
  String get virtBackupNotes => 'Заметки';

  @override
  String get virtBackupProtected =>
      'Защищена: её нельзя удалить, пока защита не снята в PVE.';

  @override
  String virtBackupVerified(String state) {
    return 'Проверка: $state';
  }

  @override
  String get virtBackupRestoreOverwrites =>
      'Восстановление перезапишет текущие диски';

  @override
  String get virtBackupStopFirst => 'Перед восстановлением выключите её.';

  @override
  String get virtBackupRestoreAgain =>
      'Диски и конфигурация гостя будут заменены данными из копии.';

  @override
  String get virtBackupDeleteConfirm => 'Удалить копию';

  @override
  String get virtBackupRestoreNew => 'Восстановить как новый';

  @override
  String get virtBackupRestoreConfirm => 'Восстановить поверх';

  @override
  String get virtBackupDone => 'Копия создана';

  @override
  String get virtBackupDeleted => 'Копия удалена';

  @override
  String virtBackupRestored(String time) {
    return 'Восстановлено из $time';
  }

  @override
  String pveNeedsPrivilege(
    String account,
    String privilege,
    String path,
    String command,
  ) {
    return 'У $account нет $privilege на $path. Выдайте на хосте PVE:\n$command';
  }

  @override
  String get virtCanDelete => 'Можно удалить';

  @override
  String get virtInUse => 'Используется';

  @override
  String get virtOps => 'Действия';

  @override
  String get virtPool => 'Пул хранения';

  @override
  String get virtPoolNew => 'Новый пул хранения';

  @override
  String get virtStorageAdd => 'Добавить хранилище';

  @override
  String virtPoolUsedPct(String pct) {
    return 'Занято $pct%';
  }

  @override
  String get virtPoolInUse =>
      'Виртуальная машина использует том здесь, поэтому пул нельзя остановить или удалить.';

  @override
  String get virtPoolDelete => 'Удалить пул';

  @override
  String get virtStorageRemove => 'Убрать хранилище';

  @override
  String virtPoolDeleteAsk(String name) {
    return 'Удалить пул $name? Удаляется его определение; тома остаются на месте.';
  }

  @override
  String virtStorageRemoveAsk(String name) {
    return 'Убрать хранилище $name из конфигурации PVE? Данные на нём сохранятся.';
  }

  @override
  String virtPoolDeleteKeepsVolumes(int count) {
    return 'Его тома ($count) остаются на диске.';
  }

  @override
  String get virtPoolDeleteStorage => 'Удалить и каталог (только если пуст)';

  @override
  String virtPoolStopAsk(String name) {
    return 'Остановить пул $name? До запуска нельзя будет просматривать и создавать тома.';
  }

  @override
  String get virtStorageClusterWide =>
      'Это относится ко всем узлам кластера, где есть это хранилище.';

  @override
  String get virtStorageDisable => 'Отключить';

  @override
  String get virtStorageEnable => 'Включить';

  @override
  String virtStorageDisableAsk(String name) {
    return 'Отключить хранилище $name? ВМ с дисками на нём не запустятся, пока его снова не включат.';
  }

  @override
  String get virtPoolLogicalNote =>
      'Используется существующая группа томов как есть; ничего не форматируется.';

  @override
  String get virtPoolMountPoint => 'Точка монтирования';

  @override
  String get virtPoolSourceNfs => 'Источник (host:/путь)';

  @override
  String get virtPoolSourceVg => 'Группа томов';

  @override
  String get virtPoolSourceThin => 'Группа томов / thin pool';

  @override
  String get virtPoolSourceZfs => 'Пул ZFS';

  @override
  String get virtPoolTypeVg => 'Группа томов LVM';

  @override
  String get virtResNameEmpty => 'Введите имя';

  @override
  String get virtResNotFound => 'Больше нет на этом хосте';

  @override
  String get virtResUnsupported => 'Этот хост этого не поддерживает';

  @override
  String get virtResNameInvalid =>
      'Такое имя хост не примет (буквы, цифры, . _ -)';

  @override
  String get virtResSourceInvalid => 'Недопустимый путь или источник';

  @override
  String get virtResTargetInvalid => 'Нужен абсолютный путь';

  @override
  String get virtResCidrInvalid =>
      'Адрес с префиксом, например 192.168.150.1/24';

  @override
  String get virtResDhcpInvalid =>
      'Два адреса в сети по порядку, без адреса хоста';

  @override
  String get virtResSubnetTaken => 'Эта подсеть уже занята другой сетью';

  @override
  String get virtResBridgeInvalid => 'Недопустимое имя интерфейса';

  @override
  String get virtResFormat => 'Пул не поддерживает этот формат';

  @override
  String get virtVolNew => 'Новый том';

  @override
  String virtVolCount(int count) {
    return 'Томов: $count';
  }

  @override
  String get virtVolNone => 'В этом пуле пока нет томов.';

  @override
  String get virtVolEmptyAttach =>
      'Новый том можно позже подключить к любой ВМ';

  @override
  String get virtVolEmptyUpload => 'Можно также сразу загрузить ISO';

  @override
  String get virtVolPveName => 'PVE называет том по его ВМ: vm-<VMID>-disk-<N>';

  @override
  String get virtVolUsers => 'Используется';

  @override
  String get virtVolAllocated => 'Выделено';

  @override
  String get virtVolGrowFromGuest =>
      'Используется ВМ: увеличьте его в разделе «Оборудование» этой ВМ';

  @override
  String get virtVolInUse => 'Этот том использует ВМ';

  @override
  String virtVolBackingOf(String names) {
    return 'Базовый файл для $names';
  }

  @override
  String get virtVolIsBase =>
      'На этом томе основаны другие тома; его удаление их повредит';

  @override
  String get virtVolAttach => 'Подключить к ВМ';

  @override
  String get virtVolAttachNote =>
      'Подключается как новый диск на шину первого диска';

  @override
  String virtVolAttached(String name) {
    return 'Подключено к $name';
  }

  @override
  String get virtVolInsert => 'Вставить в CD-ROM';

  @override
  String virtVolInserted(String name) {
    return 'Вставлено в CD-ROM $name';
  }

  @override
  String virtVolNoCdrom(String name) {
    return 'У $name нет привода CD-ROM';
  }

  @override
  String virtVolDeleteAsk(String name, String pool) {
    return 'Удалить том $name из $pool? Его содержимое будет потеряно навсегда.';
  }

  @override
  String get virtUploadIso => 'Загрузить ISO';

  @override
  String virtUploadTo(String pool) {
    return 'Загрузить в $pool';
  }

  @override
  String virtUploadDone(String name) {
    return '$name загружен';
  }

  @override
  String get virtNetConfig => 'Конфигурация';

  @override
  String get virtNetConfigFile => 'Файл конфигурации';

  @override
  String get virtNetInternal => 'Внутренняя';

  @override
  String get virtNetBridgePorts => 'Порты моста';

  @override
  String get virtNetHostBridge => 'Мост хоста';

  @override
  String get virtNetPortsHint => 'eno2; пусто — внутренний мост';

  @override
  String get virtNetDhcpRange => 'Диапазон DHCP';

  @override
  String get virtNetDhcpTip => 'dnsmasq раздаёт ВМ адреса';

  @override
  String get virtNetVlanTip => 'Сетевые карты ВМ могут нести VLAN-тег';

  @override
  String get virtNetNatTip =>
      'Через хост: ВМ выходят наружу, извне к ним не попасть';

  @override
  String get virtNetRoutedTip =>
      'Маршрутизируется хостом без NAT: в LAN нужен обратный маршрут';

  @override
  String get virtNetIsolatedTip => 'Связь только между ВМ и хостом';

  @override
  String get virtNetBridgedTip =>
      'ВМ подключаются к мосту хоста, в его физическую сеть';

  @override
  String get virtNetNew => 'Новая сеть';

  @override
  String get virtNetNewBridge => 'Новый мост Linux';

  @override
  String get virtNetVirtual => 'Виртуальная сеть';

  @override
  String get virtNetDelete => 'Удалить сеть';

  @override
  String virtNetDeleteAsk(String name) {
    return 'Удалить сеть $name? Она будет остановлена, а определение удалено.';
  }

  @override
  String virtNetDeleteAskPve(String name, String node) {
    return 'Убрать мост $name с $node? Сейчас он уйдёт из ожидающей конфигурации, а с хоста — после её применения.';
  }

  @override
  String virtNetInUse(int count) {
    return 'ВМ в этой сети: $count. Удалить нельзя.';
  }

  @override
  String virtNetStopAsk(String name, int count) {
    return 'Остановить $name? $count ВМ в ней потеряют сеть до повторного запуска.';
  }

  @override
  String get virtNetInactivePve =>
      'Не активен: новый мост ждёт в ожидающей конфигурации до её применения.';

  @override
  String get virtNetPveApplyNote =>
      'Сохраняется как ожидающее изменение и вступает в силу после применения конфигурации (ifreload -a).';

  @override
  String get virtNetPendingSaved =>
      'Сохранено как ожидающее: примените конфигурацию, чтобы оно вступило в силу';

  @override
  String virtNetPendingTitle(String node) {
    return 'Ожидающие изменения сети на $node';
  }

  @override
  String get virtNetPendingTip =>
      'PVE хранит изменения сети в interfaces.new до их применения.';

  @override
  String get virtNetPendingShow => 'Показать изменения';

  @override
  String get virtNetApply => 'Применить конфигурацию';

  @override
  String virtNetApplyAsk(String node) {
    return 'Применить ожидающую конфигурацию сети на $node? PVE перезагрузит сеть хоста (ifreload -a): ошибка в ней может отрезать хост.';
  }

  @override
  String virtNetRevertAsk(String node) {
    return 'Отменить ожидающую конфигурацию сети на $node?';
  }

  @override
  String get pveTokenTipStorage =>
      'Управление хранилищем требует Datastore.Allocate на /storage (добавление, отключение, удаление), Datastore.AllocateSpace (тома) и Datastore.AllocateTemplate (загрузки); мосты Linux и применение сетевой конфигурации требуют Sys.Modify на узле.';

  @override
  String get virtCreateUnnamed => 'Без имени';

  @override
  String get virtCreateNotChosen => 'Не выбрано';

  @override
  String get virtCreateKindVmSub => 'qm · полноценная виртуальная машина KVM';

  @override
  String get virtCreateKindLxcSub => 'pct · общее ядро с хостом, легче';

  @override
  String get virtCloudImage => 'Облачный образ';

  @override
  String get virtCloudImageTip =>
      'Диск с готовой системой: копируется, увеличивается до размера из раздела «Хранилище» и настраивается cloud-init при первой загрузке. Сам образ не меняется.';

  @override
  String get virtNoCloudImagesLibvirt =>
      'Облачных образов нет: поместите образ qcow2 или raw в пул (загрузите в «Хранилище»), который не использует ни одна ВМ.';

  @override
  String get virtNoCloudImagesPve =>
      'Облачных образов нет: загрузите образ qcow2, raw или vmdk в хранилище с типом содержимого Import (PVE 8.2+).';

  @override
  String get virtCreateWindowsTitle => 'Windows 11 требует UEFI и TPM 2.0';

  @override
  String get virtCreateWindowsBody => 'Выберите выше UEFI и включите TPM.';

  @override
  String get virtCreateWindowsNoTpm =>
      'На этом хосте нет программного TPM (swtpm): установите его, чтобы дать ВМ TPM.';

  @override
  String virtCreateImageSize(String size) {
    return 'Образ занимает $size: диск должен быть не меньше.';
  }

  @override
  String get virtCreateImageMissing => 'Выберите облачный образ.';

  @override
  String get virtCreateIncomplete =>
      'Сначала заполните части, отмеченные оранжевым.';

  @override
  String virtCreateOn(String host) {
    return 'Создаётся на $host';
  }

  @override
  String get virtCiTip =>
      'Учётная запись с sudo; вход по паролю, SSH-ключу или обоим.';

  @override
  String get virtCiUserInvalid =>
      'Строчные буквы, цифры, _ и -, начиная с буквы или _';

  @override
  String get virtCiCredentialsMissing => 'Задайте пароль или SSH-ключ.';

  @override
  String get virtCiHostnamePve => 'Имя хоста — это имя ВМ.';

  @override
  String get virtCiStatic => 'Статический';

  @override
  String get virtCiAddressInvalid =>
      'IPv4-адрес с префиксом, например 10.0.0.5/24';

  @override
  String get virtCiGatewayInvalid => 'IPv4-адрес, например 10.0.0.1';

  @override
  String get virtCiDnsFromDhcp => 'Пусто: из DHCP';

  @override
  String get virtCiDnsInvalid => 'IP-адреса через пробел или запятую';

  @override
  String get virtCiSearch => 'Домен поиска';

  @override
  String get virtCiSeedNote =>
      'Записывается в небольшой ISO рядом с диском, подключается как CD-ROM и удаляется вместе с ВМ. Хранится только хеш пароля.';

  @override
  String get virtCiNoToolTitle =>
      'На хосте нет средства для создания данных cloud-init';

  @override
  String virtCiNoToolBody(String tools) {
    return 'Установите на хост одно из: $tools. Без cloud-init образ запустится без учётной записи для входа.';
  }

  @override
  String get virtHwCloudInitNote =>
      'То, что cloud-init читает при первой загрузке. Не установочный носитель: вставлять сюда нечего.';

  @override
  String get virtHwCdromLater =>
      'Пока ВМ работает, привод добавится при следующем запуске (SATA и IDE не поддерживают горячее подключение).';

  @override
  String virtCreateDiskKept(String size) {
    return 'Диск оставлен размером $size, как у самого образа, — больше запрошенного: диск никогда не урезается меньше системы на нём.';
  }

  @override
  String get virtCiEditTip =>
      'Что cloud-init настраивает в этой ВМ: учётную запись с sudo, способ входа в неё, имя хоста и адрес.';

  @override
  String get virtCiForeignTitle =>
      'В этом seed больше, чем записывает это приложение';

  @override
  String get virtCiForeignBody =>
      'Настройки, сделанные в другом месте (пакеты, команды, другие учётные записи), здесь не показаны. При сохранении seed заменяется тем, что показано здесь.';

  @override
  String get virtCiPasswordKept => 'Задан. Оставьте пустым, чтобы сохранить';

  @override
  String get virtCiRemovePassword => 'Удалить пароль';

  @override
  String get virtCiRemovePasswordNote => 'Вход только по SSH-ключу';

  @override
  String get virtCiKeysAdded =>
      'Ключи добавляются к учётной записи. Ключ, убранный здесь, остаётся в системе, пока его не удалят там, а новое имя пользователя создаёт новую учётную запись рядом со старой.';

  @override
  String get virtCiEffectTitle => 'Вступит в силу при следующей загрузке';

  @override
  String get virtCiEffectLibvirt =>
      'При сохранении записывается новый seed с новым ID экземпляра.';

  @override
  String get virtCiEffectPve =>
      'PVE сразу перезаписывает свой диск cloud-init; ID экземпляра вычисляется из этих настроек, поэтому любое изменение здесь даёт новый.';

  @override
  String get virtCiNewInstance =>
      'При следующей загрузке cloud-init считает систему новым экземпляром: заново задаёт имя хоста, создаёт учётную запись, если её нет, задаёт пароль, добавляет ключи и заново записывает настройки сети. Он также создаёт новые SSH-ключи хоста, поэтому SSH-клиенты предупредят, что ключ хоста изменился. До этой загрузки ничего не меняется.';

  @override
  String get virtCiSaved => 'Сохранено. Вступит в силу при следующей загрузке.';

  @override
  String get virtSnapshotExternal => 'Только диски на ходу';

  @override
  String get virtSnapshotExternalTip =>
      'Гость продолжает работать. Каждый диск получает слой qcow2 в выбранном пуле; гость остаётся на цепочке.';

  @override
  String get virtSnapshotFormInternal => 'Внутренний (в образе)';

  @override
  String get virtSnapshotOverlayPool => 'Пул слоёв';

  @override
  String get virtSnapshotOverlayBeside => 'Рядом с каждым диском';

  @override
  String get virtSnapshotExternalNoMemory =>
      'Внешний снимок никогда не содержит память: гость не останавливается.';

  @override
  String get virtSnapshotChain => 'Цепочка дисков';

  @override
  String virtSnapshotChainDepth(String count) {
    return '$count слоёв';
  }

  @override
  String get virtSnapshotChainFile => 'Файл';

  @override
  String get virtSnapshotChainActive => 'Используется сейчас';

  @override
  String get virtSnapshotChainBase => 'Базовый образ';

  @override
  String get virtSnapshotNoSupport =>
      'Хранилище гостя не поддерживает снимки, поэтому создать его нельзя.';

  @override
  String get virtSnapshotRevertChain =>
      'Откат на цепочке сливает работающий слой в образ и делает все последующие снимки непригодными. Откатиться можно только к новейшему снимку.';

  @override
  String get virtSnapshotRevertHasChildren =>
      'Отказано, пока на этом снимке стоит более поздний.';

  @override
  String get virtSnapshotDiff => 'Отличия от текущего';

  @override
  String get virtSnapshotDiffNone =>
      'Конфигурация не изменилась с этого снимка.';

  @override
  String get virtSnapshotDiffShow => 'Сравнить с текущим';

  @override
  String get virtSnapshotDiffGroupCpu => 'Процессор';

  @override
  String get virtSnapshotDiffGroupMemory => 'Память';

  @override
  String get virtSnapshotDiffGroupDisks => 'Диски';

  @override
  String get virtSnapshotDiffGroupNic => 'Интерфейсы';

  @override
  String get virtSnapshotDiffGroupFirmware => 'Прошивка';

  @override
  String get virtSnapshotDiffGroupBoot => 'Загрузка';

  @override
  String get virtSnapshotDiffGroupOther => 'Прочее';

  @override
  String virtSnapshotDiffValue(String after, String before) {
    return '$before → $after';
  }

  @override
  String get virtSnapshotDiffRemoved => 'удалено';

  @override
  String get virtSnapshotDiffAdded => 'добавлено';

  @override
  String virtSnapshotDiffAsk(String snapshot) {
    return 'Что изменится при откате к $snapshot:';
  }

  @override
  String virtSnapshotDiffHost(String error) {
    return 'Узел не смог сказать, что отличается: $error';
  }

  @override
  String virtSnapshotExternalExists(String count) {
    return 'Гость уже на $count слоях; этот снимок добавит ещё один.';
  }

  @override
  String get virtToTemplate => 'Сделать шаблоном';

  @override
  String get virtToTemplateNote =>
      'Шаблон нельзя запустить и нельзя вернуть в гостя. Его диски становятся базовыми образами, которые разделяет связанный клон.';

  @override
  String virtToTemplateConfirm(String name) {
    return 'Сделать $name шаблоном?';
  }

  @override
  String get virtToTemplateIrreversible =>
      'Это необратимо: шаблон нельзя вернуть в гостя.';

  @override
  String get virtToTemplateStopped => 'Сначала выключите его.';

  @override
  String get virtToTemplateSnapshots =>
      'Гость со снимками не может стать шаблоном.';

  @override
  String virtTemplateCreated(String name) {
    return '$name теперь шаблон';
  }

  @override
  String get virtTemplateTip => 'Шаблон запускается только после клонирования.';

  @override
  String get virtCloneStorageSame => 'Как у источника';

  @override
  String get virtCloneNodeSame => 'Как у источника';

  @override
  String get virtCloneStorageContent =>
      'Это хранилище не хранит диски виртуальных машин.';

  @override
  String get virtCloneStorageShared =>
      'Для копирования на другой узел нужно общее хранилище.';

  @override
  String get virtCloneNodeUnknown => 'У этого хоста нет такого узла.';

  @override
  String get virtCloneLinkedTarget =>
      'Связанный клон использует диски шаблона, поэтому не может указать хранилище или узел.';

  @override
  String get virtBackupJobs => 'Задания резервного копирования';

  @override
  String get virtBackupJobsNone =>
      'Нет задания резервного копирования по расписанию. Добавьте его, чтобы копировать гостей регулярно.';

  @override
  String get virtBackupJobNew => 'Новое задание';

  @override
  String get virtBackupJobRun => 'Запустить сейчас';

  @override
  String get virtBackupJobRunAsk =>
      'Запустить это задание резервного копирования сейчас?';

  @override
  String virtBackupJobDeleteAsk(String id) {
    return 'Удалить задание $id? Сделанные копии останутся.';
  }

  @override
  String get virtBackupJobSaved => 'Задание сохранено';

  @override
  String get virtBackupJobDeleted => 'Задание удалено';

  @override
  String get virtBackupJobStarted => 'Задание запущено';

  @override
  String get virtBackupSchedule => 'Расписание';

  @override
  String get virtBackupScheduleHelp =>
      'Подмножество календарных событий systemd: 02:30, mon..fri 02:30, sat 03:00, daily, hourly, */15.';

  @override
  String get virtBackupScheduleInvalid => 'Хост не принимает такое расписание.';

  @override
  String virtBackupScheduleNext(String times) {
    return 'Следующие запуски: $times';
  }

  @override
  String get virtBackupSelection => 'Гости';

  @override
  String get virtBackupSelectionAll => 'Все гости';

  @override
  String get virtBackupSelectionList => 'Выбранные гости';

  @override
  String get virtBackupSelectionNone => 'Выберите хотя бы одного гостя.';

  @override
  String get virtBackupMail => 'Уведомление';

  @override
  String get virtBackupNotesTemplate => 'Заметки к копии';

  @override
  String virtBackupNotesTemplateTip(String vars) {
    return 'Заметки добавляются к каждой копии задания. Заменяются: $vars.';
  }

  @override
  String get virtBackupPrune => 'Хранение';

  @override
  String get virtBackupPruneTip =>
      'Параметры хранения PVE, напр. keep-last=7,keep-daily=4. Пусто: из хранилища или узла.';

  @override
  String get virtBackupJobNode => 'Узел';

  @override
  String get virtBackupJobNodeAny => 'Каждый узел';

  @override
  String get virtBackupEnabled => 'Включено';

  @override
  String get virtBackupOptions => 'Параметры';

  @override
  String get virtBackupProtect => 'Защитить';

  @override
  String get virtBackupProtectTip =>
      'Защищённая копия не удаляется по хранению и не может быть удалена, пока защита не снята.';

  @override
  String get virtBackupEditNotes => 'Заметки';

  @override
  String get virtBackupSaveNotes => 'Сохранить';

  @override
  String get virtBackupEdited => 'Копия обновлена';

  @override
  String get virtBackupRestoreStorage => 'Восстановить в хранилище';

  @override
  String get virtBackupRestoreStorageSame => 'Как в копии';

  @override
  String get virtCloneStorageMissing =>
      'Ни одно хранилище на этом узле не хранит диски виртуальных машин.';

  @override
  String get virtBackupCompress => 'Сжатие';

  @override
  String get virtBackupUnprotect => 'Снять защиту';

  @override
  String get virtBackupModeStops =>
      'suspend и stop прерывают работу гостя на время копирования.';

  @override
  String get virtBackupScheduleValidate => 'Проверить на хосте';

  @override
  String virtBackupSelected(int count) {
    return 'Выбрано: $count';
  }

  @override
  String get virtBackupExcludeTip =>
      'Берутся все гости узла. Выключите одного, чтобы исключить его.';

  @override
  String virtNetEditAsk(int count) {
    return 'Работающая сеть сохраняет текущее состояние до перезапуска. Перезапуск отключит ВМ в этой сети ($count).';
  }

  @override
  String get virtNetEditAskNoGuest =>
      'Работающая сеть сохраняет текущее состояние до перезапуска.';

  @override
  String get virtNetEditRestart => 'Перезапустить, чтобы применить сейчас';

  @override
  String get virtNetEditRestartNote =>
      'ВМ в этой сети теряют связь на время перезапуска.';

  @override
  String get virtNetEditPending =>
      'В определении есть изменение, которое работающая сеть ещё не применила.';

  @override
  String get virtNetRestart => 'Перезапустить';

  @override
  String virtNetRestartAsk(String name, int count) {
    return 'Перезапустить $name? ВМ в этой сети ($count) останутся без связи, пока она не вернётся.';
  }

  @override
  String virtNetRestartAskNone(String name) {
    return 'Перезапустить $name? В ней ничего нет.';
  }

  @override
  String get virtNetHosts => 'Статические адреса';

  @override
  String get virtNetHostAdd => 'Добавить адрес';

  @override
  String get virtNetHostMac => 'MAC';

  @override
  String get virtNetHostIp => 'Адрес';

  @override
  String get virtNetHostName => 'Имя (необязательно)';

  @override
  String get virtNetHostEmpty =>
      'Ни одному MAC не назначен свой адрес: каждая ВМ получает адрес из диапазона DHCP.';

  @override
  String get virtNetHostOthers =>
      'Каждая другая ВМ получает адрес из диапазона DHCP.';

  @override
  String get virtNetHostInvalid =>
      'MAC, адрес или имя, которые хост отклонит, или один и тот же MAC дважды.';

  @override
  String get virtNetManagementIface =>
      'Этот интерфейс несёт собственный адрес хоста. Изменение или применение отрежет хост от сети.';

  @override
  String get virtNetManagementTip =>
      'Он несёт управляющий трафик хоста или находится под интерфейсом, который его несёт: приложение его не изменяет.';

  @override
  String get virtNetPhysicalTip =>
      'Физический интерфейс принадлежит хосту: приложение изменяет только мосты.';

  @override
  String get virtNetVlanAware => 'Поддержка VLAN';

  @override
  String get virtCiExpire => 'Срок действия пароля истекает';

  @override
  String get virtCiExpireNote =>
      'При первом входе с ним нужно задать новый. Только libvirt: PVE записывает \"expire: false\" и такой настройки не имеет.';

  @override
  String get virtCiSearchHint => 'lab.example dev.lab.example';

  @override
  String get virtCiSearchTip =>
      'Несколько, через пробел; resolv.conf сохраняет первые несколько.';

  @override
  String virtCiNicsTip(int count) {
    return 'Сетевых карт в сетевой конфигурации seed: $count; форма изменяет первую.';
  }

  @override
  String get virtUsbByVendor => 'По производителю и продукту';

  @override
  String get virtUsbByAddress => 'По адресу';

  @override
  String get virtUsbAddressTip =>
      'Устройство привязано к этому адресу: всё, что туда подключено, передаётся ВМ. libvirt обозначает USB hostdev номером шины и устройства.';

  @override
  String virtUsbPortNote(int bus, String port) {
    return 'шина $bus · порт $port';
  }

  @override
  String get virtSbUnsupported =>
      'В дескрипторах прошивки хоста нет прошивки Secure Boot с зарегистрированными ключами, поэтому домен с ним не запустится.';

  @override
  String get virtCreateSecureBoot => 'Secure Boot';

  @override
  String get virtCreateSecureBootNote =>
      'Загружаются только подписанные ядра и загрузчики.';

  @override
  String virtUsbAddressNote(int bus, int device) {
    return 'шина $bus · устройство $device';
  }

  @override
  String get virtHwRevertPendingTitle => 'Отменить ожидающие изменения';

  @override
  String virtHwRevertPendingBody(String name) {
    return '$name возвращается к тому, что сейчас работает: определение перезаписывается из работающего, и следующий запуск получит ровно то, что есть сейчас. Файл NVRAM и прошивка остаются без изменений.';
  }

  @override
  String virtHwRevertAllAsk(String name) {
    return 'Отменить все изменения, ожидающие следующего запуска $name?';
  }

  @override
  String get virtBackupPlanNew => 'Новый план';

  @override
  String get virtBackupPlanNewTip =>
      'Расписание, по которому копируется только этот гостевой хост.';

  @override
  String virtBackupPlanOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Также копирует ещё $count гостей',
      few: 'Также копирует ещё $count гостей',
      one: 'Также копирует ещё $count гостя',
      zero: 'Других гостей нет',
    );
    return '$_temp0';
  }

  @override
  String get reduceMotion => 'Уменьшение движения';

  @override
  String get copyLink => 'Копировать ссылку';

  @override
  String funcNeedsAgentPermission(String func) {
    return 'У вашей учётной записи на этом Monitor agent нет разрешения на $func. Обратитесь к администратору agent.';
  }

  @override
  String funcNeedsAgentHttps(String func) {
    return 'Для $func нужен HTTPS к этому Monitor agent или разрешённый HTTP и в agent, и в этом приложении.';
  }

  @override
  String funcNeedsAgentSetup(String func) {
    return '$func не настроено на этом Monitor agent; это должен сделать его администратор сервера.';
  }

  @override
  String get monitorFilesReadOnly =>
      'Только чтение: эта учётная запись может просматривать файлы на agent, но не изменять их.';

  @override
  String get monitorAccess => 'Доступ';

  @override
  String get monitorAccounts => 'Учётные записи';

  @override
  String get monitorRoles => 'Роли';

  @override
  String get monitorRole => 'Роль';

  @override
  String get monitorChangePassword => 'Сменить пароль';

  @override
  String get monitorNewPassword => 'Новый пароль';

  @override
  String get monitorCurrentPassword => 'Ваш текущий пароль';

  @override
  String get monitorReauthTip =>
      'Для изменения доступа снова нужен ваш пароль.';

  @override
  String get monitorPasswordTooShort => 'Не менее 8 символов';

  @override
  String get monitorPasswordMismatch => 'Пароли не совпадают';

  @override
  String get monitorErrReauth => 'Неверный пароль.';

  @override
  String get monitorErrLastAdmin =>
      'У agent должна быть хотя бы одна учётная запись администратора.';

  @override
  String get monitorErrConflict => 'Уже существует или ещё используется.';

  @override
  String get monitorErrForbidden => 'Это может сделать только администратор.';

  @override
  String get monitorRoleNameRule =>
      'Строчные буквы, цифры, - и _, до 32 символов';

  @override
  String get monitorGrantShell => 'Shell и команды';

  @override
  String get monitorGrantShellTip =>
      'Терминал, процессы, службы, контейнеры, сниппеты, питание — от учётной записи agent';

  @override
  String get monitorGrantSshTerminal => 'Терминал панели через SSH';

  @override
  String get monitorGrantVirt => 'Виртуализация';

  @override
  String get monitorGrantVirtTip =>
      'Proxmox VE, libvirt и BMC, к которым подключается агент, в его веб-панели';

  @override
  String get monitorGrantFiles => 'Файлы';

  @override
  String get monitorGrantConnect => 'Исходящие подключения';

  @override
  String get monitorGrantConnectTip =>
      'Локальная и динамическая переадресация портов, удалённый рабочий стол';

  @override
  String get monitorGrantConnectAllow =>
      'Разрешённые цели (IP или CIDR, при необходимости :порт или :от-до; по одной на строку, пусто = куда угодно)';

  @override
  String get monitorGrantListen => 'Прослушивание на сервере';

  @override
  String get monitorGrantListenTip => 'Удалённая переадресация портов';

  @override
  String get monitorGrantListenPublic => 'Адреса не loopback';

  @override
  String get monitorGrantPorts => 'Диапазон портов (пусто = любой)';

  @override
  String get monitorGrantOff => 'Выкл.';

  @override
  String get monitorBuiltin => 'Встроенная';

  @override
  String get monitorAdminRoleTip =>
      'Управляет учётными записями, ролями и настройками agent';

  @override
  String get monitorYou => 'Вы';

  @override
  String get monitorNoAccessToSettings =>
      'Изменять настройки этого agent может только администратор.';

  @override
  String get monitorPasswordNotSaved =>
      'Пароль на агенте изменён, но приложению не удалось его сохранить. Обновите пароль Monitor в настройках этого сервера.';

  @override
  String get firewall => 'Брандмауэр';

  @override
  String get firewallLinuxOnly =>
      'Управление брандмауэром поддерживает серверы Linux с ufw или firewalld.';

  @override
  String get firewallNeedsRoot =>
      'Для чтения правил брандмауэра нужны права root. Введите пароль sudo, чтобы продолжить.';

  @override
  String get firewallIncoming => 'Входящий';

  @override
  String get firewallOutgoing => 'Исходящий';

  @override
  String get firewallRouted => 'Пересылаемый';

  @override
  String get firewallDefaultPolicy => 'Политика по умолчанию';

  @override
  String get firewallLogging => 'Журналирование';

  @override
  String get firewallRules => 'Правила';

  @override
  String get firewallRule => 'Правило';

  @override
  String get firewallAddRule => 'Добавить правило';

  @override
  String get firewallAnywhere => 'Любой';

  @override
  String firewallFromFmt(String source) {
    return 'от $source';
  }

  @override
  String get firewallFrom => 'Откуда';

  @override
  String get firewallTo => 'Куда';

  @override
  String get firewallProtocol => 'Протокол';

  @override
  String get firewallInterface => 'Интерфейс';

  @override
  String get firewallComment => 'Комментарий';

  @override
  String get firewallAppProfile => 'Профиль приложения';

  @override
  String get firewallPrepend => 'Поместить перед всеми остальными правилами';

  @override
  String get firewallIpv6Off =>
      'IPv6 выключен (IPV6=no): правила v6 не загружаются.';

  @override
  String get firewallReload => 'Перезагрузить';

  @override
  String get firewallNothingMatched =>
      'Укажите порт, профиль приложения, адрес или интерфейс.';

  @override
  String get firewallInvalidPort =>
      'Недопустимый порт. Используйте 22, 80,443 или 6000:6010.';

  @override
  String get firewallTooManyPorts =>
      'Не более 15 портов; диапазон считается за два.';

  @override
  String get firewallPortsNeedProtocol =>
      'Для списка или диапазона портов нужен tcp или udp.';

  @override
  String get firewallInvalidAddress =>
      'Недопустимый адрес. Используйте IP-адрес или сеть, например 192.168.1.0/24.';

  @override
  String get firewallMixedIpVersions =>
      'Откуда и Куда должны быть оба IPv4 или оба IPv6.';

  @override
  String get firewallInvalidInterface => 'Недопустимое имя интерфейса.';

  @override
  String get firewallInvalidComment =>
      'Комментарий не может содержать \' или переносы строк.';

  @override
  String get firewallInvalidProtocol => 'Неподдерживаемый протокол.';

  @override
  String get firewallInterfaceIn => 'Входящий интерфейс';

  @override
  String get firewallInterfaceOut => 'Исходящий интерфейс';

  @override
  String get firewallSourcePort => 'Порт источника';

  @override
  String get firewallMoreOptions => 'Дополнительные параметры';

  @override
  String get firewallNoneInstalled =>
      'На этом сервере не установлены ни ufw, ни firewalld. Установите один из них через менеджер пакетов системы, например `apt install ufw` или `dnf install firewalld`.';

  @override
  String get firewallKeepAccess =>
      'Сначала оставить порты этого приложения открытыми';

  @override
  String firewallWillRefuseFmt(String access) {
    return '$access: новые подключения этого приложения будут отклоняться. Текущее подключение сохранится, пока не оборвётся.';
  }

  @override
  String firewallMayRefuseFmt(String access) {
    return '$access: новые подключения этого приложения могут отклоняться. Это зависит от адреса или интерфейса, через который они приходят, а приложение не может это определить.';
  }

  @override
  String firewallRateLimitedFmt(String access) {
    return '$access: подключения будут ограничены по частоте. Адрес, открывший 6 и более подключений за 30 секунд, будет отклонён, а это приложение может переподключаться так часто.';
  }

  @override
  String get firewallConflict =>
      'ufw и firewalld включены одновременно. Оба записывают правила ядра, и решает тот, что загрузился последним.';

  @override
  String get firewallDefaultZone => 'Зона по умолчанию';

  @override
  String get firewallZone => 'Зона';

  @override
  String get firewallTarget => 'Target';

  @override
  String get firewallMasquerade => 'Masquerade';

  @override
  String get firewallServices => 'Службы';

  @override
  String get firewallPorts => 'Порты';

  @override
  String get firewallSources => 'Источники';

  @override
  String get firewallInterfaces => 'Интерфейсы';

  @override
  String get firewallRichRules => 'Rich rules';

  @override
  String get firewallForwardPorts => 'Перенаправленные порты';

  @override
  String get firewallRuntimeOnly => 'только runtime';

  @override
  String get firewallPermanentOnly => 'только permanent';

  @override
  String get firewallThisConnection => 'это подключение';

  @override
  String get firewallDefaultTag => 'по умолчанию';

  @override
  String get firewallDrift =>
      'Действующая конфигурация отличается от сохранённой. После reload или перезагрузки будет действовать сохранённая.';

  @override
  String firewallDriftLockoutFmt(String access) {
    return 'После reload или перезагрузки $access будет отклоняться: сохранённая конфигурация его не пропускает.';
  }

  @override
  String get firewallSaveRuntime => 'Сохранить как permanent';

  @override
  String get firewallReloadLoses =>
      'Изменения, не сохранённые как permanent, будут потеряны.';

  @override
  String get firewallPanic => 'Включён режим panic: все пакеты отбрасываются.';

  @override
  String get firewallPanicOff => 'Выключить режим panic';

  @override
  String get firewallStoppedNote =>
      'firewalld остановлен. Изменения сохраняются и вступят в силу при запуске.';

  @override
  String get firewallInvalidSource =>
      'Недопустимый источник. Используйте адрес, сеть вроде 192.168.1.0/24, ipset:ИМЯ или MAC-адрес.';

  @override
  String get firewallInvalidRichRule =>
      'Rich rule начинается с «rule» и занимает одну строку.';

  @override
  String get firewallInvalidForwardPort =>
      'Используйте port=80:proto=tcp:toport=8080, с toport, toaddr или обоими.';

  @override
  String get monitorSyncNeedsServer =>
      'Выберите сервер, агент monitor которого хранит резервную копию.';

  @override
  String get monitorBackupUnsupported =>
      'Этот агент monitor не может хранить резервные копии. Обновите агент.';

  @override
  String get monitorBackupAdminOnly =>
      'Хранить резервные копии на агенте monitor может только учётная запись администратора.';

  @override
  String monitorBackupTooLarge(String max) {
    return 'Резервная копия больше, чем принимает агент monitor ($max).';
  }

  @override
  String get monitorBackupTooMany =>
      'Агент monitor уже хранит максимально допустимое число резервных копий. Сначала удалите одну.';

  @override
  String get virtCreateVmidInvalid => 'VMID от 100 до 999999999.';

  @override
  String get virtCreateNodeOffline => 'Этот узел не в сети.';

  @override
  String get virtCreateMediaMissing =>
      'Этого установочного образа нет на хосте.';

  @override
  String get virtCreateNetworkMissing =>
      'Новая машина не может использовать эту сеть.';

  @override
  String get virtCreateNotOffered =>
      'Этот хост не предлагает этого для новой ВМ.';

  @override
  String get virtCreateSecureBootNeedsUefi => 'Для Secure Boot нужен UEFI.';

  @override
  String get virtGuestNotStopped => 'Сначала выключите её.';

  @override
  String get virtGuestIsTemplate => 'Это уже шаблон.';

  @override
  String get virtCreateImageBigger =>
      'Образ больше диска: сделайте диск не меньше образа.';

  @override
  String get virtBackupIssueStorage =>
      'Это хранилище не содержит резервных копий на этом узле.';

  @override
  String get virtBackupIssueOption =>
      'PVE не принимает такой режим или сжатие.';

  @override
  String get virtBackupIssueNodeOffline => 'Узел задания не в сети.';

  @override
  String get programWaiting => 'Ожидает вас';

  @override
  String get programWaitingPermission => 'Ожидает вашего подтверждения';

  @override
  String get programWaitingQuestion => 'Ожидает вашего ответа';

  @override
  String get programWaitingAuth => 'Ожидает входа в систему';

  @override
  String get programStatus => 'Состояние программы';

  @override
  String get programIdle => 'Неактивна';

  @override
  String get programThisShell => 'Эта оболочка';

  @override
  String get programProgress => 'Ход выполнения';

  @override
  String get programCommandRunning => 'Выполняется команда';

  @override
  String get programCommandSucceeded => 'Последняя команда выполнена успешно';

  @override
  String programCommandFailed(int code) {
    return 'Последняя команда завершилась с кодом $code';
  }

  @override
  String get programStatusAlerts =>
      'Уведомлять, когда программе нужно ваше внимание';

  @override
  String get programStatusAlertsTip =>
      'Для невидимого терминала: когда программа сообщает, что ожидает вас, завершилась или выдала ошибку (OSC 7501, OSC 9;4), либо завершается команда, выполнявшаяся не менее 30 секунд (OSC 133).';

  @override
  String get termLineHeight => 'Высота строки';

  @override
  String get termLineHeightTip =>
      'Высота строки терминала в диапазоне от 1,0 до 2,0 размера шрифта. Как и размер шрифта, этот параметр влияет на количество помещающихся строк.';

  @override
  String get termFontTip =>
      'Если файл шрифта не выбран, терминал использует системный моноширинный шрифт, а для отсутствующих глифов — шрифты с глифами CJK и emoji.';
}
