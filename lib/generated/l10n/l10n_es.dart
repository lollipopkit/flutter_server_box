// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get acceptBeta => 'Aceptar actualizaciones de la versión de prueba';

  @override
  String get addSystemPrivateKeyTip =>
      'Actualmente no hay ninguna llave privada, ¿quieres agregar la que viene por defecto en el sistema (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Añadido a la lista de tareas';

  @override
  String get askAi => 'Preguntar a la IA';

  @override
  String get askAiAwaitingResponse => 'Esperando la respuesta de la IA...';

  @override
  String get askAiEndpointTip =>
      'Un dominio o una URL completa. La ruta se completa según el protocolo elegido.';

  @override
  String get askAiProtocolTip =>
      'Auto prueba Responses y luego Chat Completions.';

  @override
  String get askAiCommandInserted => 'Comando insertado en el terminal';

  @override
  String askAiConfigMissing(Object fields) {
    return 'Configura $fields en Ajustes.';
  }

  @override
  String get askAiDisclaimer =>
      'La IA puede equivocarse. Úsala con precaución.';

  @override
  String get askAiInsertTerminal => 'Insertar en el terminal';

  @override
  String get askAiNoResponse => 'Sin respuesta';

  @override
  String get askAiAgentWelcome => '¿Qué hacemos en este servidor?';

  @override
  String get askAiAgentPromptHint =>
      'Pide al Agente que revise o arregle algo...';

  @override
  String get askAiAnalyzeSelectionPrompt =>
      'Analiza la salida seleccionada del terminal y explica qué pasó';

  @override
  String get askAiTerminalContext => 'Contexto del terminal';

  @override
  String get askAiReviewNeeded => 'Revisar';

  @override
  String get askAiReviewAction => 'Revisar el comando propuesto';

  @override
  String get askAiReviewBeforeContinuing =>
      'Revisa o rechaza la sugerencia actual primero';

  @override
  String get askAiApproveRun => 'Aprobar y ejecutar';

  @override
  String get askAiDecline => 'Rechazar';

  @override
  String get askAiActionDeclined => 'El comando propuesto fue rechazado.';

  @override
  String get askAiInterrupted => 'La respuesta del Agente se interrumpió.';

  @override
  String get askAiRiskReadOnly => 'Solo lectura';

  @override
  String get askAiRiskCaution => 'Modifica el sistema';

  @override
  String get askAiRiskUnvetted => 'Host no verificado';

  @override
  String get askAiRiskDestructive => 'Riesgo alto';

  @override
  String get askAiHighRiskConfirmTitle =>
      '¿Ejecutar un comando de riesgo alto?';

  @override
  String get askAiHighRiskConfirmBody =>
      'Este comando puede hacer cambios difíciles de deshacer. Revísalo con cuidado.';

  @override
  String get askAiNoCommandOutput => 'El comando terminó sin salida.';

  @override
  String get askAiOutputTruncated =>
      'La salida larga se truncó antes de devolverla al Agente.';

  @override
  String get askAiAutoApproved => 'Aprobado automáticamente';

  @override
  String get askAiAutoRunSafeCommands =>
      'Ejecutar automáticamente los comandos de solo lectura';

  @override
  String get askAiAutoRunSafeCommandsTip =>
      'Solo se ejecuta si el modelo y la comprobación local lo consideran de solo lectura';

  @override
  String get askAiSendOnEnter => 'Enter envía';

  @override
  String get askAiSendOnEnterTip =>
      'Enter envía, Shift+Enter nueva línea. Desactivado: Enter nueva línea, Cmd/Ctrl+Enter envía.';

  @override
  String get askAiApiKeyOptional =>
      'Déjalo vacío para local o sin autenticación';

  @override
  String get askAiHistory => 'Historial de conversaciones';

  @override
  String get askAiNewConversation => 'Nueva conversación';

  @override
  String get askAiNoHistory => 'Aún no hay conversaciones guardadas';

  @override
  String get askAiNoHistoryMessages => 'Todavía no hay mensajes';

  @override
  String get askAiUntitledConversation => 'Sin título';

  @override
  String get askAiRenameConversation => 'Renombrar conversación';

  @override
  String get askAiDeleteConversationTitle => '¿Eliminar esta conversación?';

  @override
  String get askAiDeleteConversationTip =>
      'La borra de este dispositivo. No se puede deshacer.';

  @override
  String get askAiClearHistoryTitle =>
      '¿Borrar el historial del Agente de este servidor?';

  @override
  String get askAiClearHistoryTip =>
      'Se borrarán todas las conversaciones del Agent guardadas de este servidor.';

  @override
  String get askAiRestoredReview =>
      'Este comando viene del historial. Revísalo otra vez';

  @override
  String get agentWelcome => '¿Qué hacemos en tus servidores?';

  @override
  String get agentWelcomeTip =>
      'Deja que el Agent diagnostique un problema o haga una tarea';

  @override
  String get agentPromptHint =>
      'Pide al Agente que revise u opere tus servidores...';

  @override
  String get agentNoHistory =>
      'No hay conversaciones globales del Agente guardadas';

  @override
  String get agentClearHistoryTitle =>
      '¿Borrar el historial global del Agente?';

  @override
  String get agentClearHistoryTip =>
      'Se eliminarán de este dispositivo todas las conversaciones globales del Agente.';

  @override
  String get agentToolShell => 'Shell';

  @override
  String get agentToolReadFile => 'Leer archivo';

  @override
  String get agentToolWriteFile => 'Escribir archivo';

  @override
  String get agentToolFailed => 'Falló la ejecución de la herramienta.';

  @override
  String agentToolCallsFmt(Object count) {
    return '$count llamadas de herramienta';
  }

  @override
  String get agentFloat => 'Flotar sobre otras pestañas';

  @override
  String get agentToolSshConnect => 'Conectar por SSH';

  @override
  String get agentToolSshDisconnect => 'Desconectar SSH';

  @override
  String get agentSshConnectTitle => 'Conectar a un host nuevo';

  @override
  String get agentAuthMethod => 'Autenticación';

  @override
  String get agentSshConnectTip =>
      'El Agent quiere una conexión SSH. Escribe la contraseña aquí';

  @override
  String get agentAdHocSessions => 'Conexiones temporales';

  @override
  String get agentSaveServerTitle => 'Guardar como servidor';

  @override
  String get agentSaveServerTip =>
      'Este host y la contraseña que escribas se guardan en este dispositivo';

  @override
  String get agentMonitorOptional => 'Agente monitor (opcional)';

  @override
  String get authFailTip => 'Fallo de autenticación. Comprueba los datos';

  @override
  String get autoBackupConflict =>
      'Solo se puede activar una copia de seguridad automática a la vez';

  @override
  String get autoConnect => 'Conexión automática';

  @override
  String get autoRun => 'Ejecución automática';

  @override
  String get autoUpdateHomeWidget =>
      'Actualizar automáticamente el widget del escritorio';

  @override
  String get availableTabs => 'Pestañas disponibles';

  @override
  String get backupEncrypted => 'El respaldo está encriptado';

  @override
  String get backupNotEncrypted => 'El respaldo no está encriptado';

  @override
  String get backupPassword => 'Contraseña de respaldo';

  @override
  String get backupPasswordRemoved => 'Contraseña de respaldo eliminada';

  @override
  String get backupPasswordSet => 'Contraseña de respaldo establecida';

  @override
  String get backupPasswordTip =>
      'Establece una contraseña para encriptar archivos de respaldo. Déjalo vacío para desactivar la encriptación.';

  @override
  String get backupPasswordWrong => 'Contraseña de respaldo incorrecta';

  @override
  String get remoteBackupPasswordRequired =>
      'Remote backups require a non-empty backup password';

  @override
  String get monitorHttpsRequired =>
      'Un agente de monitor remoto necesita HTTPS, salvo que se permita HTTP.';

  @override
  String get monitorAllowInsecureHttp => 'Permitir HTTP';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Solo en una red privada de confianza que cifre el transporte por sí misma, como Tailscale';

  @override
  String get backupTip =>
      'Los datos exportados pueden ser encriptados con contraseña. \nPor favor guárdalos en un lugar seguro.';

  @override
  String get icloudBackupStatusTitle => 'Estado de la copia de seguridad';

  @override
  String get icloudBackupStatusLoading =>
      'Cargando el estado de la copia de iCloud...';

  @override
  String get icloudBackupStatusError =>
      'No se pueden leer los metadatos de la copia de iCloud';

  @override
  String get icloudBackupStatusEmpty =>
      'Aún no se ha encontrado ningún archivo de copia en iCloud';

  @override
  String get icloudBackupStateUploading => 'Subiendo';

  @override
  String get icloudBackupStateConflict => 'Conflicto detectado';

  @override
  String get icloudBackupStateUploaded => 'Subida';

  @override
  String get icloudBackupStateWaiting => 'Esperando a iCloud';

  @override
  String icloudBackupStatusSummary(Object lastModified, Object remoteState) {
    return 'Última copia: $lastModified\nEstado: $remoteState';
  }

  @override
  String get bgRun => 'Ejecución en segundo plano';

  @override
  String get bgRunTip =>
      'Este interruptor solo indica que la aplicación intentará correr en segundo plano, si puede hacerlo o no depende de si tiene el permiso correspondiente. En Android puro, por favor desactiva la “optimización de batería” para esta app, en MIUI por favor cambia la estrategia de ahorro de energía a “Sin restricciones”.';

  @override
  String get clearAllStatsContent =>
      '¿Estás seguro de que quieres limpiar todas las estadísticas de conexión del servidor? Esta acción no se puede deshacer.';

  @override
  String get clearAllStatsTitle => 'Limpiar todas las estadísticas';

  @override
  String clearServerStatsContent(Object serverName) {
    return '¿Estás seguro de que quieres limpiar las estadísticas de conexión del servidor \"$serverName\"? Esta acción no se puede deshacer.';
  }

  @override
  String clearServerStatsTitle(Object serverName) {
    return 'Limpiar estadísticas de $serverName';
  }

  @override
  String get clearThisServerStats => 'Limpiar estadísticas de este servidor';

  @override
  String get compactDatabase => 'Compactar base de datos';

  @override
  String compactDatabaseContent(Object size) {
    return 'Tamaño de la base de datos: $size\n\nEsto reorganizará la base de datos para reducir el tamaño del archivo. No se eliminará ningún dato.';
  }

  @override
  String get closeAfterSave => 'Guardar y cerrar';

  @override
  String get collapseUITip =>
      '¿Colapsar por defecto las listas largas en la UI?';

  @override
  String get connectionDetails => 'Detalles de conexión';

  @override
  String get connectionStats => 'Estadísticas de conexión';

  @override
  String get connectionStatsDesc =>
      'Ver la tasa de éxito de conexión del servidor e historial';

  @override
  String get containerTrySudoTip =>
      'Por ejemplo: si configuras el usuario dentro de la app como aaa, pero Docker está instalado bajo el usuario root, entonces necesitarás habilitar esta opción';

  @override
  String get containerSudoPasswordRequired =>
      'Se requiere contraseña de sudo para acceder a Docker. Por favor ingrese su contraseña.';

  @override
  String get containerSudoPasswordIncorrect =>
      'La contraseña de sudo es incorrecta o no está permitida. Por favor intente de nuevo.';

  @override
  String get copyPath => 'Copiar ruta';

  @override
  String get cpuViewAsProgressTip =>
      'Muestre la tasa de uso de cada CPU en estilo de barra de progreso (estilo antiguo)';

  @override
  String get customCmd => 'Comandos personalizados';

  @override
  String get deleteServers => 'Eliminar servidores en lote';

  @override
  String get deleteDirRecursive => 'Eliminar la carpeta y todo su contenido';

  @override
  String get desktopTerminalTip =>
      'Comando utilizado para abrir el emulador de terminal al iniciar sesiones SSH.';

  @override
  String get dirEmpty => 'Asegúrate de que el directorio esté vacío';

  @override
  String get discoverSshServers => 'Descubrir servidores SSH';

  @override
  String get discoveryFailed => 'Falló el descubrimiento';

  @override
  String get discoverySettings => 'Configuración de descubrimiento';

  @override
  String get distro => 'Distribución';

  @override
  String distroSwitchTip(Object from, Object to) {
    return 'Reemplazar $from por $to. Se elimina todo lo instalado dentro de $from y, en su lugar, se descarga y descomprime $to.';
  }

  @override
  String get diskHealth => 'Salud del disco';

  @override
  String get displayCpuIndex => 'Muestre el índice de CPU';

  @override
  String dl2Local(Object fileName) {
    return '¿Descargar $fileName a local?';
  }

  @override
  String get dockerEmptyRunningItems =>
      'No hay contenedores en ejecución.\nEsto podría deberse a que:\n- El usuario con el que se instaló Docker es diferente al configurado en la app\n- La variable de entorno DOCKER_HOST no se ha leído correctamente. Puedes obtenerla ejecutando `echo \$DOCKER_HOST` en el terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Total de $count imágenes';
  }

  @override
  String get dockerProjectOther => 'Otros';

  @override
  String get dockerPruneTip =>
      'Elimina los datos no utilizados para liberar espacio en disco';

  @override
  String get dockerStatistics => 'Estadísticas de Docker';

  @override
  String get doubleColumnMode => 'Modo de doble columna';

  @override
  String get doubleColumnTip =>
      'Esta opción solo habilita la función, si se puede activar o no depende del ancho del dispositivo';

  @override
  String get editVirtKeys => 'Teclas virtuales';

  @override
  String get editorHighlightTip =>
      'El rendimiento del resaltado de código es bastante pobre actualmente, puedes elegir desactivarlo para mejorar.';

  @override
  String get enableMdns => 'Habilitar mDNS';

  @override
  String get enableMdnsDesc => 'Usar mDNS/Bonjour para descubrir servicios SSH';

  @override
  String get envVars => 'Variable de entorno';

  @override
  String get extraArgs => 'Argumentos extra';

  @override
  String get fallbackSshDest => 'Destino SSH alternativo';

  @override
  String get fdroidReleaseTip =>
      'Si descargaste esta aplicación desde F-Droid, se recomienda desactivar esta opción.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'El archivo \'$file\' es demasiado grande \'$size\', supera el $sizeMax';
  }

  @override
  String get fileDirGone => 'Esta carpeta ya no está aquí';

  @override
  String get fileDirGoneTip => 'Se eliminó o se renombró';

  @override
  String get fullScreen => 'Pantalla completa';

  @override
  String get fullScreenJitter => 'Temblores en modo pantalla completa';

  @override
  String get fullScreenJitterHelp => 'Prevención de quemaduras de pantalla';

  @override
  String get fullScreenTip =>
      '¿Debe habilitarse el modo de pantalla completa cuando el dispositivo se rote al modo horizontal? Esta opción solo se aplica a la pestaña del servidor.';

  @override
  String get githubGistIdOptional => 'ID del Gist (opcional)';

  @override
  String get githubGistToken => 'Token de GitHub Gist';

  @override
  String get githubGistTokenEmpty => 'El token está vacío';

  @override
  String get goto => 'Ir a';

  @override
  String get homeTabs => 'Pestañas de inicio';

  @override
  String get homeTabsCustomizeDesc =>
      'Personaliza qué pestañas aparecen en la página de inicio y su orden';

  @override
  String get homeWidgetUrlConfig => 'Configuración de URL del widget de inicio';

  @override
  String get ignoreCert => 'Ignorar certificado';

  @override
  String get image => 'Imagen';

  @override
  String get macDmgBody =>
      'La App Store exige que esta app esté en un sandbox, y un sandbox no puede abrir un terminal. La versión DMG sí.\n\nLa versión de la App Store puede dejar de actualizarse.';

  @override
  String get macDmgImportDenied =>
      'macOS no dejó leer los datos de la versión anterior';

  @override
  String get macDmgImported => 'Datos de la versión anterior importados';

  @override
  String get macDmgImportFailed =>
      'No se pudieron leer los datos de la versión anterior';

  @override
  String get macDmgTip =>
      'Terminal local y ejecutar snippets en local (versión DMG)';

  @override
  String get macDmgTitle => 'Versión DMG';

  @override
  String get showHiddenFiles => 'Mostrar archivos ocultos';

  @override
  String get sshKeyAlgorithm => 'Algoritmo';

  @override
  String get sshKeyComment => 'Comentario';

  @override
  String get sshKeyGenerate => 'Generar par de claves';

  @override
  String get sshKeyGenerating => 'Generando…';

  @override
  String sshKeyLockedFmt(String name) {
    return 'La clave privada [$name] no se ha desbloqueado.';
  }

  @override
  String get sshKeyPassphraseTip =>
      'Opcional. Una clave con frase de contraseña se guarda cifrada y se pide la primera vez que una conexión la usa.';

  @override
  String get sshKeyPassphraseWrong => 'Frase de contraseña incorrecta.';

  @override
  String get sshKeyPublicKey => 'Clave pública';

  @override
  String get sshKeyPublicKeyTip =>
      'Añade esta línea a ~/.ssh/authorized_keys en el servidor.';

  @override
  String get sshKeyRecommended => 'Recomendado';

  @override
  String sshKeyUnlockTip(String name) {
    return 'Introduce la frase de contraseña de la clave privada [$name].';
  }

  @override
  String get unused => 'Sin usar';

  @override
  String get dangling => 'Colgante';

  @override
  String get pruneUnusedImages => 'Limpiar imágenes sin usar';

  @override
  String get pruneDanglingImages => 'Limpiar imágenes colgantes';

  @override
  String get pruneImages => 'Limpiar imágenes';

  @override
  String get unusedTaggedImages => 'Etiquetadas sin usar';

  @override
  String get pruneDanglingImagesTip => 'Elimina solo las imágenes colgantes.';

  @override
  String get pruneUnusedImagesTip =>
      'También elimina imágenes etiquetadas que ningún contenedor utiliza.';

  @override
  String get includeUnusedVolumesTip =>
      'También elimina volúmenes que ningún contenedor utiliza.';

  @override
  String get pruneCommandPreview => 'Vista previa del comando';

  @override
  String get pruneForceSshTip =>
      '-f omite la confirmación interactiva y siempre está activado al ejecutar por SSH.';

  @override
  String get pruneVolumes => 'Limpiar volúmenes';

  @override
  String get pruneUnusedData => 'Limpiar datos sin usar';

  @override
  String get pull => 'Extraer';

  @override
  String get invalidHostFormat =>
      'Formato de host no válido. Solo se permiten caracteres de IPv4, IPv6 y dominios.';

  @override
  String get jumpServer => 'Servidor de salto';

  @override
  String jumpServersNotFoundFmt(Object serverName, Object jumpIds) {
    return 'No se encontraron servidores de salto para $serverName: $jumpIds';
  }

  @override
  String nameAlreadyExistsFmt(Object name) {
    return '«$name» ya existe';
  }

  @override
  String get noJumpServerAvailable =>
      'No hay ningún servidor de salto disponible.';

  @override
  String get jumpServerAndProxyCommandCannotBeUsedTogether =>
      'El servidor de salto y ProxyCommand no se pueden usar a la vez.';

  @override
  String get keepForeground => '¡Por favor, mantén la app en primer plano!';

  @override
  String get keepStatusWhenErr => 'Mantener el estado anterior del servidor';

  @override
  String get keepStatusWhenErrTip =>
      'Solo aplica cuando hay errores al ejecutar scripts';

  @override
  String get keyAuth => 'Autenticación con llave';

  @override
  String get lastFailure => 'Último fallo';

  @override
  String get lastSuccess => 'Último éxito';

  @override
  String get letterCache => 'Entrada normal del teclado';

  @override
  String get letterCacheTip =>
      'Cuando está activado, la entrada pasa por el IME normal, lo que puede evitar avisos de teclado seguro en el terminal en algunos sistemas.';

  @override
  String get linuxShellTip =>
      'Con qué shell arranca un terminal. Vacío restaura /bin/sh.';

  @override
  String get linuxNetTip =>
      'Servidores DNS. Vacío restaura los valores por defecto';

  @override
  String madeWithLove(Object myGithub) {
    return 'Hecho con ❤️ por $myGithub';
  }

  @override
  String get maxConcurrency => 'Concurrencia máxima';

  @override
  String get maxRetryCount =>
      'Número máximo de reintentos de conexión al servidor';

  @override
  String mismatchSystem(Object system) {
    return 'Sistema no coincidente: $system';
  }

  @override
  String get mirror => 'Espejo';

  @override
  String get needRestart => 'Necesita reiniciar la app';

  @override
  String get netViewType => 'Tipo de vista de red';

  @override
  String get newContainer => 'Crear contenedor nuevo';

  @override
  String get noConnectionStatsData =>
      'No hay datos de estadísticas de conexión';

  @override
  String get noLineChart => 'No utilice gráficos de líneas';

  @override
  String get noPrivateKeyTip =>
      'La clave privada no existe, puede haber sido eliminada o hay un error de configuración.';

  @override
  String get noPromptAgain => 'No volver a preguntar';

  @override
  String get onlyOneLine => 'Mostrar solo en una línea (desplazable)';

  @override
  String get openLastPath => 'Abrir el último camino';

  @override
  String get openLastPathTip =>
      'Los diferentes servidores tendrán diferentes registros, y lo que se registra es la ruta de salida';

  @override
  String get parseContainerStatsTip =>
      'El análisis del estado de uso de Docker es bastante lento';

  @override
  String get plugInType => 'Tipo de inserción';

  @override
  String get preferDiskAmount =>
      'Priorizar la visualización de la capacidad del disco';

  @override
  String get privateKey => 'Llave privada';

  @override
  String privateKeyNotFoundFmt(Object keyId) {
    return 'No se encontró la clave privada [$keyId].';
  }

  @override
  String get bmcPowerOnAction => 'Encender';

  @override
  String get bmcShutdown => 'Apagar';

  @override
  String get bmcForceOff => 'Forzar apagado';

  @override
  String get restart => 'Reiniciar';

  @override
  String get bmcPowerCycle => 'Ciclo de energía';

  @override
  String bmcPowerConfirm(String server, String resetType) {
    return '¿Enviar esto a $server? Se pedirá \"$resetType\" al servicio';
  }

  @override
  String get bmcPowerDone => 'El estado de energía cambió';

  @override
  String get bmcPowerAccepted =>
      'Aceptado, pero el estado de energía no ha cambiado. Una operación suave depende del sistema operativo';

  @override
  String get bmcPowerUnsupported =>
      'Este servicio no permite nada para esa acción';

  @override
  String get bmcUnauthorized => 'El BMC rechazó la cuenta';

  @override
  String get bmcAccountMissing =>
      'No hay ninguna cuenta configurada para este BMC';

  @override
  String get bmcPowerOn => 'Encendido';

  @override
  String get bmcPowerOff => 'Apagado';

  @override
  String get bmcCertRejected =>
      'Certificado rechazado: revísalo en los ajustes del servidor';

  @override
  String get bmcNotAService => 'No hay servicio Redfish en esta dirección';

  @override
  String get bmcNoSystem => 'El servicio no informa de ningún sistema';

  @override
  String get bmcSensorsTruncated => 'Solo se muestran los primeros sensores';

  @override
  String get bmcMultipleSystems => 'Solo se muestra el primer sistema';

  @override
  String get bmcTip =>
      'El BMC es un ordenador aparte en la placa base, accesible cuando el sistema operativo del host no lo está. Configurado aquí, informa del estado de energía y de los sensores de hardware mientras el servidor está apagado o bloqueado. Necesita Redfish, presente en la mayoría del hardware empresarial desde alrededor de 2016.';

  @override
  String get bmcCert => 'Certificado';

  @override
  String get bmcCertPinned => 'Revisado y fijado';

  @override
  String get bmcCertUnreviewed =>
      'Aún sin revisar: toca para ver el certificado';

  @override
  String get bmcCertReview =>
      'Un certificado autofirmado. Compáralo antes de aceptarlo. Después solo se confía en ese exacto.';

  @override
  String get bmcCertChanged => 'El certificado no coincide. Compruébalo.';

  @override
  String get bmcCertExpired => 'Caducado.';

  @override
  String bmcCertWas(String fingerprint) {
    return 'Aceptado anteriormente: $fingerprint';
  }

  @override
  String get bmcAddrInvalid =>
      'La dirección del BMC debe ser una URL, p. ej. https://10.0.0.9';

  @override
  String get proxyCommandSandboxed =>
      'Esta versión está en un sandbox: el comando recibe un home vacío, no el tuyo, así que falla todo lo que lea ~/.ssh. La versión DMG no.';

  @override
  String privateKeyFileUnreadable(String path, String reason) {
    return 'No se puede leer el archivo de clave privada $path: $reason';
  }

  @override
  String privateKeyFileSandboxed(String path) {
    return 'Esta compilación no puede leer archivos fuera de su contenedor, por lo que la clave en $path es inaccesible. Importa la clave en Ajustes o usa la versión DMG.';
  }

  @override
  String get pushToken => 'Token de notificaciones';

  @override
  String get proxyCommandOnlySupportedOnDesktop =>
      'ProxyCommand solo se admite en plataformas de escritorio.';

  @override
  String get pveIgnoreCertTip =>
      'No se recomienda activarlo, ¡tenga cuidado con los riesgos de seguridad! Si está utilizando el certificado predeterminado de PVE, debe habilitar esta opción.';

  @override
  String get pveServerClientMissing =>
      'El cliente SSH de este servidor no está disponible.';

  @override
  String get pveAddressMissing =>
      'Falta la dirección de PVE. Configúrala en los ajustes del servidor.';

  @override
  String get pvePasswordRequired =>
      'Se requiere la contraseña de PVE. Configúrala en los ajustes del servidor.';

  @override
  String get pveOtpRequired =>
      'Este servidor PVE tiene la autenticación en dos pasos activada. Introduce el código OTP.';

  @override
  String get pveOtpChallengeExpired =>
      'El desafío OTP ha caducado. Actualiza e inténtalo de nuevo.';

  @override
  String get pveOtpCodeRequired => 'Se requiere el código OTP.';

  @override
  String get pveOtpVerificationFailed =>
      'Falló la verificación del OTP. Inténtalo con un código nuevo.';

  @override
  String get pveOtpTitle => 'Verificación OTP';

  @override
  String get pveOtpLabel => 'Código OTP';

  @override
  String get pveInvalidResponseBody =>
      'El inicio de sesión de PVE devolvió un cuerpo de respuesta no válido.';

  @override
  String get pveInvalidResponseData =>
      'La respuesta del inicio de sesión de PVE no contenía datos válidos.';

  @override
  String get pveMissingAuthTicket =>
      'El inicio de sesión de PVE se completó, pero no se devolvió ningún ticket de autenticación.';

  @override
  String get pveVersionLow =>
      'Esta función está actualmente en fase de prueba y solo se ha probado en PVE 8+. Úsela con precaución.';

  @override
  String get pveLoadingForwarding => 'Estableciendo el túnel SSH...';

  @override
  String get pveLoadingLogin => 'Autenticando con PVE...';

  @override
  String get pveLoadingData => 'Obteniendo datos del clúster...';

  @override
  String get pveLoadingConnect => 'Conectando...';

  @override
  String get pvePassword => 'Contraseña de PVE';

  @override
  String get pvePasswordHint =>
      'Necesaria cuando se usa autenticación SSH por clave';

  @override
  String get read => 'Leer';

  @override
  String get recentConnections => 'Conexiones recientes';

  @override
  String get rememberPwdInMem => 'Recordar contraseña en la memoria';

  @override
  String get rememberPwdInMemTip =>
      'Utilizado para contenedores, suspensión, etc.';

  @override
  String get remotePath => 'Ruta remota';

  @override
  String rootfsUpdateTip(
    Object distro,
    Object installed,
    Object latest,
    Object pm,
  ) {
    return '$distro $installed está instalado; hay $latest. Actualizar reemplaza todo el contenedor: se pierden los datos de $pm';
  }

  @override
  String linuxSystemInUse(Object name) {
    return 'Cierra los terminales de $name antes de borrarlo';
  }

  @override
  String get rootfsSubtitle =>
      'Un espacio de usuario Linux en este dispositivo';

  @override
  String rootfsInstallTip(Object distro, Object version, Object size) {
    return 'Descarga $distro $version (unos $size MB) y lo descomprime en este dispositivo.';
  }

  @override
  String get sameIdServerExist => 'Ya existe un servidor con el mismo ID';

  @override
  String get second => 'Segundo';

  @override
  String get serverFilesUnavailableTip =>
      'Necesita SSH a este servidor, o server_box_monitor con su API de archivos activa.';

  @override
  String get back => 'Atrás';

  @override
  String get history => 'Historial';

  @override
  String get homeDir => 'Inicio';

  @override
  String selected(Object count) {
    return '$count seleccionados';
  }

  @override
  String get sendTo => 'Enviar a…';

  @override
  String get serverDetailOrder =>
      'Orden de los componentes en la página de detalles del servidor';

  @override
  String get serverFuncBtns => 'Botones de función del servidor';

  @override
  String get serverOrder => 'Orden del servidor';

  @override
  String get serverTabRequired =>
      'La pestaña del servidor no se puede eliminar';

  @override
  String get shareServerRiskTip =>
      'Este código QR contiene los datos de conexión en texto claro. Quien lo escanee o fotografíe puede conectarse.';

  @override
  String get sftpDlPrepare => 'Preparando para conectar al servidor...';

  @override
  String get sftpEditorTip =>
      'Vacío usa el editor integrado. Por ejemplo `vim` (se sugiere leer `EDITOR`).';

  @override
  String get sftpRmrDirSummary =>
      'Usar `rm -r` en SFTP para eliminar directorios';

  @override
  String get sftpSSHConnected => 'SFTP conectado...';

  @override
  String get sftpShowFoldersFirst => 'Mostrar carpetas primero';

  @override
  String get specifyDev => 'Especificar dispositivo';

  @override
  String get specifyDevTip =>
      'El tráfico de red cuenta todos los dispositivos por defecto; indica uno aquí';

  @override
  String get tempIsCelsiusTip =>
      'Si se activa, el valor de temperatura se tratará como grados Celsius en lugar de milicelsius. Actívalo solo si la temperatura se muestra mal (por ejemplo, 0,1 °C en lugar de 58 °C).';

  @override
  String spentTime(Object time) {
    return 'Tiempo gastado: $time';
  }

  @override
  String sshConfigAllExist(Object duplicateCount) {
    return 'Todos los servidores ya existen (se encontraron $duplicateCount duplicados)';
  }

  @override
  String get sshConnectionModeTip =>
      'Integrado: usar el terminal de la app. SSH del sistema: lanzar el comando ssh del sistema en un terminal externo.';

  @override
  String get sshConnectionModeUseBuiltin => 'Usar el terminal integrado';

  @override
  String get sshConnectionModeUseSystem => 'Usar el SSH del sistema';

  @override
  String sshConfigDuplicatesSkipped(Object duplicateCount) {
    return 'Se omitirán $duplicateCount duplicados';
  }

  @override
  String get sshConfigFound => 'Encontramos configuración SSH en tu sistema';

  @override
  String sshConfigFoundServers(Object totalCount) {
    return 'Se encontraron $totalCount servidores';
  }

  @override
  String get sshConfigImport => 'Importar Configuración SSH';

  @override
  String get sshConfigImportPermission =>
      '¿Te gustaría dar permiso para leer ~/.ssh/config e importar automáticamente la configuración de servidores?';

  @override
  String get sshConfigImportTip =>
      'Sugerencia para leer ~/.ssh/config al crear el primer servidor';

  @override
  String sshConfigImported(Object count) {
    return 'Se importaron $count servidores desde la configuración SSH';
  }

  @override
  String sshHostKeyChangedDesc(Object serverName) {
    return 'La clave de host SSH de $serverName ha cambiado. Continúa solo si confías en este servidor.';
  }

  @override
  String get sshHostKeyType => 'Tipo de clave de host SSH';

  @override
  String get sshKnownHostKeys => 'Hosts conocidos';

  @override
  String get sshKnownHostKeysTip =>
      'Las claves de host que esta app ha aceptado';

  @override
  String sshHostKeyNewDesc(Object serverName) {
    return 'Se recibió una nueva clave de host SSH de $serverName. Revisa la huella antes de confiar.';
  }

  @override
  String sshHostKeyStoredFingerprint(Object fingerprint) {
    return 'Huella almacenada: $fingerprint';
  }

  @override
  String get sshVerificationCode => 'Código de verificación';

  @override
  String get sshConfigManualSelect =>
      '¿Te gustaría seleccionar manualmente el archivo de configuración SSH?';

  @override
  String get sshConfigNoServers =>
      'No se encontraron servidores en la configuración SSH';

  @override
  String get sshConfigPermissionDenied =>
      'No se puede acceder al archivo de configuración SSH debido a los permisos de macOS.';

  @override
  String sshConfigServersToImport(Object importCount) {
    return 'Se importarán $importCount servidores';
  }

  @override
  String get sshTermHelp =>
      'Cuando el terminal es desplazable, arrastrar horizontalmente puede seleccionar texto. Hacer clic en el botón del teclado enciende/apaga el teclado. El icono de archivo abre el SFTP de la ruta actual. El botón del portapapeles copia el contenido cuando se selecciona texto y pega el contenido del portapapeles en el terminal cuando no se selecciona texto y hay contenido en el portapapeles. El icono de código pega fragmentos de código en el terminal y los ejecuta.';

  @override
  String get sshVirtualKeyAutoOff =>
      'Desactivación automática de teclas virtuales';

  @override
  String get supportFmtArgs => 'Soporta los siguientes argumentos de formato:';

  @override
  String get suspendTip =>
      'La función de suspender necesita permisos de root y soporte de systemd.';

  @override
  String switchTo(Object val) {
    return 'Cambiar a $val';
  }

  @override
  String get syncAppSettings => 'Sincronizar los ajustes de la app';

  @override
  String get syncAppSettingsTip =>
      'Incluir el tema, el diseño, el editor, el terminal y otras preferencias del dispositivo en la sincronización automática.';

  @override
  String get termFontSizeTip =>
      'Este ajuste afectará el tamaño del terminal (ancho y alto). Puedes hacer zoom en la página del terminal para ajustar el tamaño de fuente de la sesión actual.';

  @override
  String get textScalerTip =>
      '1.0 => 100% (tamaño original), solo afecta a ciertas fuentes en la página del servidor, no se recomienda modificar.';

  @override
  String get times => 'Veces';

  @override
  String get trySudo => 'Intentar con sudo';

  @override
  String get sudoPromptNotFound =>
      'No hay solicitud de contraseña de sudo activa.';

  @override
  String get updateServerStatusInterval =>
      'Intervalo de actualización del estado del servidor';

  @override
  String get useNoPwd => 'Se usará sin contraseña';

  @override
  String get usePodmanByDefault => 'Usar Podman por defecto';

  @override
  String get used => 'Usado';

  @override
  String get view => 'Vista';

  @override
  String get viewDetails => 'Ver detalles';

  @override
  String get virtKeyHelpClipboard =>
      'Si el terminal tiene caracteres seleccionados, entonces copiará los caracteres seleccionados al portapapeles, de lo contrario, pegará el contenido del portapapeles al terminal.';

  @override
  String get virtKeyHelpIME => 'Encender/apagar el teclado';

  @override
  String get virtKeyHelpSFTP => 'Abrir la ruta actual en SFTP.';

  @override
  String get virtKeyHelpSnippet =>
      'Elige un fragmento y ejecútalo en esta terminal.';

  @override
  String get virtKeyHelpTmux => 'Cambia entre sesiones y ventanas de tmux.';

  @override
  String get virtKeyIntroActions => 'Atajos';

  @override
  String get virtKeyIntroActionsTip =>
      'Estas teclas no escriben, abren algo. Mantén pulsada una para leer qué hace.';

  @override
  String get virtKeyIntroCustomizeTip =>
      'En los ajustes de la terminal puedes reordenarlas u ocultar las que no uses.';

  @override
  String get virtKeyIntroModifiers => 'Modificadores';

  @override
  String get virtKeyIntroModifiersTip =>
      'Pulsa una para activarla y luego una letra del teclado. Se aplica solo a esa tecla.';

  @override
  String get virtKeyIntroNav => 'Navegación';

  @override
  String get virtKeyIntroNavTip =>
      'Estas teclas mueven el cursor. Mantén pulsada una flecha para repetirla.';

  @override
  String get virtKeyIntroSelect =>
      'Mientras la terminal tenga contenido que desplazar, arrastra en horizontal para seleccionar texto.';

  @override
  String get waitConnection =>
      'Por favor, espera a que la conexión se establezca';

  @override
  String get wakeLock => 'Mantener despierto';

  @override
  String get watchNotPaired => 'No hay un Apple Watch emparejado';

  @override
  String get webdavSettingEmpty => 'La configuración de Webdav está vacía';

  @override
  String get whenOpenApp => 'Al abrir la App';

  @override
  String get wolTip =>
      'Después de configurar WOL (Wake-on-LAN), se envía una solicitud de WOL cada vez que se conecta el servidor.';

  @override
  String get write => 'Escribir';

  @override
  String get writeScriptFailTip =>
      'La escritura en el script falló, posiblemente por falta de permisos o porque el directorio no existe.';

  @override
  String get writeScriptTip =>
      'Después de conectarse al servidor, se escribirá un script en `~/.config/server_box` \n | `/tmp/server_box` para monitorear el estado del sistema. Puedes revisar el contenido del script.';

  @override
  String get menuGitHubRepository => 'Repositorio de GitHub';

  @override
  String get podmanDockerEmulationDetected =>
      'Detectada emulación de Podman Docker. Por favor, cambie a Podman en la configuración.';

  @override
  String get betaTip =>
      'Esta función sigue en fase beta. No se garantiza su funcionamiento.';

  @override
  String get portForward_startPrompt =>
      'Añade una regla de reenvío de puertos para empezar';

  @override
  String get portForward_localHost => 'Host local';

  @override
  String get portForward_localPort => 'Puerto local';

  @override
  String get portForward_remoteHost => 'Host remoto';

  @override
  String get portForward_remotePort => 'Puerto remoto';

  @override
  String portForward_deleteConfirmFmt(Object name) {
    return '¿Eliminar $name?';
  }

  @override
  String get sponsor => 'Patrocinador';

  @override
  String get sortByJoinTime => 'Por fecha de adición';

  @override
  String get serverHistory => 'Historial del servidor';

  @override
  String get portForwardBetaTitle => 'Port Forward (Beta)';

  @override
  String get tmuxAutoAttach => 'Conexión automática a tmux';

  @override
  String get tmuxAuto => 'tmux automático';

  @override
  String get tmuxAutoTip =>
      'Iniciar o adjuntar tmux automáticamente al conectar por SSH';

  @override
  String get tmuxSessionSelector => 'Selector de sesiones';

  @override
  String get tmuxSessionSelectorTip =>
      'Mostrar el selector de sesiones al conectar';

  @override
  String get tmuxDefaultSessionName => 'Nombre de sesión por defecto';

  @override
  String get tmuxSessionName => 'Nombre de la sesión';

  @override
  String get tmuxExistingSessions => 'Sesiones existentes';

  @override
  String get tmuxNewSession => 'Nueva sesión';

  @override
  String get tmuxWindows => 'Ventanas';

  @override
  String get tmuxNewWindow => 'Nueva ventana';

  @override
  String get tmuxNoWindowsFound => 'No se encontraron ventanas';

  @override
  String tmuxWindowCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ventanas',
      one: '1 ventana',
    );
    return '$_temp0';
  }

  @override
  String tmuxPaneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paneles',
      one: '1 panel',
    );
    return '$_temp0';
  }

  @override
  String get tmuxAttached => 'Adjuntada';

  @override
  String get tmuxActive => 'Activa';

  @override
  String tmuxActiveAt(String time) {
    return 'activa: $time';
  }

  @override
  String tmuxAttachedAt(String time) {
    return 'adjuntada: $time';
  }

  @override
  String get tmuxSkip => 'Omitir';

  @override
  String get tmuxNotAvailable => 'tmux no está disponible';

  @override
  String containerSegmentsMismatch(int count) {
    return 'Número inesperado de segmentos en la respuesta del contenedor: $count';
  }

  @override
  String get containerOperationInProgress =>
      'Ya hay otra operación de contenedor en curso';

  @override
  String processCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count procesos',
      one: '1 proceso',
    );
    return '$_temp0';
  }

  @override
  String get processParseUnsupportedOutput =>
      'El formato de la lista de procesos no es compatible.';

  @override
  String get processParseInvalidRows =>
      'No se pudieron leer algunas entradas de procesos.';

  @override
  String get processParseInvalidWindowsJson =>
      'No se pudo leer la respuesta de procesos de Windows.';

  @override
  String get processParseInvalidWindowsRows =>
      'No se pudieron leer algunas entradas de procesos de Windows.';

  @override
  String get processKillTargetChanged =>
      'El proceso cambió o finalizó. Actualiza la lista e inténtalo de nuevo.';

  @override
  String get watchServers => 'Servidores en el reloj';

  @override
  String get watchServersTip =>
      'El reloj consulta al monitor por su cuenta, así que solo se pueden elegir servidores con uno.';

  @override
  String get watchNoMonitorServer =>
      'Ningún servidor tiene un agente monitor configurado';

  @override
  String get watchLegacyUrls => 'URL de estado heredadas';

  @override
  String get accessoryWidgetServer =>
      'Servidor del widget de pantalla bloqueada';

  @override
  String get systemdMissing => 'No hay systemd en este servidor';

  @override
  String get systemdMissingTip =>
      '`systemctl` no está instalado aquí, por lo que no hay unidades que listar.';

  @override
  String initSystemFmt(String init) {
    return 'Esta máquina parece usar $init.';
  }

  @override
  String get systemdListFailed => 'No se pudieron listar las unidades';

  @override
  String get systemdUserScopeMissing => 'No se listan las unidades de usuario';

  @override
  String get systemdUserScopeMissingTip =>
      'Esta cuenta no tiene bus de sesión de usuario en el servidor, por lo que solo se muestran las unidades del sistema.';

  @override
  String get serverUnreachable =>
      'No se pudo ejecutar ningún comando en este servidor';

  @override
  String get containerNoRuntime =>
      'Aquí no hay entorno de ejecución de contenedores';

  @override
  String get containerNoRuntimeTip =>
      'Ni `docker` ni `podman` respondieron en esta máquina. Si uno está instalado para otra cuenta, activa «Intentar con sudo» en los ajustes.';

  @override
  String get containerUnreadable =>
      'El entorno de ejecución de contenedores respondió de forma inesperada';

  @override
  String get power => 'Energía';

  @override
  String get continueInTerminal => 'Continuar en la terminal';

  @override
  String get askAiRiskUnknown => 'Sin clasificar';

  @override
  String get agentLocalExec => 'Ejecutar comandos en este dispositivo';

  @override
  String get agentLocalExecTip =>
      'Deja que el Agent trabaje en la máquina que ejecuta ServerBox. Incluso los comandos de solo lectura se revisan';

  @override
  String get agentLocalExecRootfsTip =>
      'Deja que el Agent trabaje en local, limitado al contenedor Linux que instaló ServerBox';

  @override
  String macDmgImportedPartly(String path) {
    return 'Se importaron los datos de la versión instalada anteriormente. Los archivos descargados se quedaron en $path.';
  }

  @override
  String get bmcAccount => 'Cuenta';

  @override
  String get bmcAccountUnset =>
      'Ninguna seleccionada: toca para elegir o crear una';

  @override
  String bmcAccountShared(int count) {
    return 'Usada por $count servidores';
  }

  @override
  String get bmcAccounts => 'Cuentas de BMC';

  @override
  String get bmcAccountSharedTip => 'Editarla cambia lo que todos ellos usan.';

  @override
  String bmcAccountInUse(int count) {
    return '$count servidores la usan. Conservan su dirección y pierden la cuenta.';
  }

  @override
  String get bmcStaleWrite =>
      'El BMC cambió mientras se escribía. Inténtalo de nuevo.';

  @override
  String get send => 'Enviar';
}
