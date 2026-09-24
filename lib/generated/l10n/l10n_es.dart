// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get crashCollect => 'Datos de diagnóstico';

  @override
  String get crashCollectIntro =>
      'ServerBox registra lo que ocurre mientras se ejecuta para poder solucionar los problemas. Elige cuánta información se envía.';

  @override
  String get crashCollectNone => 'Nada';

  @override
  String get crashCollectNoneTip =>
      'Los informes se conservan en este dispositivo; después de un fallo, puedes enviar uno manualmente.';

  @override
  String get crashCollectBasic => 'Información básica';

  @override
  String get crashCollectBasicTip =>
      'Solo se incluye información sobre el fallo; no se incluyen registros ni datos de rendimiento. **Esto nos ayuda a mejorar la aplicación y corregir errores.**';

  @override
  String get crashCollectFull => 'Información completa';

  @override
  String get crashCollectFullTip =>
      'Además del registro del fallo, se incluyen datos de rendimiento y el uso de funciones: **Sirven para localizar qué va lento y qué funciones se usan realmente.**';

  @override
  String get crashCollectFooter =>
      'En todos los niveles, los nombres de servidores conocidos, sus direcciones y nombres de usuario se sustituyen por marcadores al registrarlos. Puedes cambiar el nivel de recopilación más adelante en Ajustes.';

  @override
  String get privacy => 'Privacidad';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get crashLastRunFailed =>
      'ServerBox se cerró inesperadamente durante la última ejecución.';

  @override
  String get crashReportTitle => 'Informe de fallo';

  @override
  String get crashReportHint =>
      'Este es el registro de la ejecución anterior. Los nombres y direcciones de servidor conocidos se han sustituido por marcadores, pero pueden quedar otros datos. Lee el informe detenidamente antes de enviarlo.';

  @override
  String get crashReportSubmit => 'Copiar e informar';

  @override
  String get preReleaseUpdates => 'Recibir actualizaciones preliminares';

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
  String get remoteDesktop => 'Escritorio remoto';

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
  String get askAiResend => 'Resend';

  @override
  String get askAiResendTip =>
      'Se descartará todo lo posterior a este mensaje: las respuestas, los comandos y sus resultados.';

  @override
  String get askAiDeleteTip =>
      'Se eliminará este mensaje y todo lo posterior: las respuestas, los comandos y sus resultados.';

  @override
  String get askAiModelTable => 'Model table';

  @override
  String get askAiModelTableTip =>
      'Tamaños de contexto por nombre de modelo, obtenidos de models.dev. La app incluye una copia; toca para descargar una más reciente.';

  @override
  String get askAiContextFallback => 'no aparece en la tabla';

  @override
  String get askAiCompactAt => 'Summarise at';

  @override
  String get askAiCompactAtTip =>
      'Indica cuánto se llena el contexto antes de resumir los turnos anteriores. Hacerlo antes pierde detalles más pronto; hacerlo después aumenta el riesgo de que el modelo rechace la solicitud.';

  @override
  String get askAiContextTokens => 'Context size';

  @override
  String get askAiContextTokensTip =>
      'Número de tokens que admite el modelo. El modo automático lo busca por nombre; indica un número si tu proveedor ofrece un contexto menor que el del modelo.';

  @override
  String get askAiConversationCompacted =>
      'Se resumieron los mensajes anteriores para poder continuar la conversación.';

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
  String get askAiAllowInsecure => 'Permitir HTTP sin cifrar';

  @override
  String get askAiAllowInsecureTip =>
      'Permite conexiones http:// a modelos propios en direcciones distintas de localhost. La clave API y cualquier contexto de terminal se enviarán sin cifrar; localhost no se ve afectado.';

  @override
  String get askAiInsecureEndpoint =>
      'Este endpoint usa http://. Activa «Permitir HTTP sin cifrar» en los ajustes de AI para usarlo.';

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
  String get floatOverTabs => 'Flotar sobre otras pestañas';

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
  String get connectAll => 'Conectar todo';

  @override
  String get disconnectAll => 'Desconectar todo';

  @override
  String get distIcon => 'Marcas de distribución';

  @override
  String get distIconIntroLegal =>
      'Una marca solo indica lo que este dispositivo leyó del sistema remoto, información que puede ser errónea o estar desactualizada, y no identifica ni un derivado, ni una recompilación, ni una versión concreta. Cuando no se puede identificar, se dibuja un icono genérico.\n\nCada marca es una marca registrada de su respectivo propietario y aquí solo se usa para referirse al sistema que identifica.';

  @override
  String get distIconTip =>
      'Mostrar junto a cada servidor una pequeña marca del sistema que parece estar ejecutando';

  @override
  String get distNameMap => 'Correspondencia de nombres';

  @override
  String get distNameMapTip =>
      'Solo para una distribución cuyo archivo se llame de otro modo donde alojes las marcas. La clave es el nombre que usa esta aplicación; el valor es el nombre que se debe descargar. Déjalo vacío mientras no falte ninguna marca.';

  @override
  String get logoUrl => 'URL del logotipo';

  @override
  String get logoUrlTip =>
      'La imagen grande en la parte superior de la página de un servidor, en sus propios colores.';

  @override
  String get globe => 'Globo';

  @override
  String get locationTip =>
      'Dónde se dibuja este servidor en el globo. Latitud y luego longitud, en grados — por ejemplo 39.9042, 116.4074.';

  @override
  String get markUrl => 'URL de la marca';

  @override
  String get markUrlTip =>
      'La marca pequeña junto al nombre de un servidor en las listas. Vacío: ninguna.\n\nNo es la misma imagen que el logotipo';

  @override
  String get navTabMenuTip =>
      'Mantén pulsada una pestaña, o haz clic derecho en ella, para conectar o desconectar de una vez todo lo que contiene.';

  @override
  String nTags(Object count) {
    return '$count etiquetas';
  }

  @override
  String get remoteBackupPasswordRequired =>
      'Las copias de seguridad remotas requieren una contraseña de copia no vacía';

  @override
  String get monitorSyncServerTip =>
      'La copia de seguridad se guarda en el agente monitor de este servidor, encriptada con la contraseña de respaldo. Su panel puede guardar el archivo y devolverlo sin poder leerlo.';

  @override
  String get monitorSyncNeedsServer =>
      'Elige el servidor a cuyo agente monitor va la copia de seguridad.';

  @override
  String get monitorHttpsRequired =>
      'Un agente de monitor remoto necesita HTTPS, salvo que se permita HTTP.';

  @override
  String get monitorAllowInsecureHttp => 'Permitir HTTP';

  @override
  String get plainHttpTitle => 'Este agente se sirve por HTTP sin cifrar';

  @override
  String get plainHttpTip =>
      'La contraseña y todo lo que esta app pide viajarían sin cifrar. Todavía no se ha enviado nada.';

  @override
  String get allowForThisServer => 'Permitir para este servidor';

  @override
  String get viewError => 'Ver el error';

  @override
  String get monitorAllowInsecureHttpTip =>
      'Solo en una red privada de confianza que cifre el transporte por sí misma, como Tailscale';

  @override
  String monitorHttpTip(String url) {
    return 'Leer el estado de este servidor desde la API HTTP de un agente **monitor**, en lugar de ejecutar comandos por SSH.\n\nHay que instalar el agente en el servidor primero; las tendencias, la app del reloj y los widgets dependen de él.\n\n[Instalar un agente monitor]($url)';
  }

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
  String get trayReadings => 'Lecturas';

  @override
  String get trayChart => 'Gráfico';

  @override
  String get trayChartNone => 'Ninguno';

  @override
  String get trayCompact => 'Filas compactas';

  @override
  String get trayCompactTip =>
      'Una línea por servidor, sin el gráfico. Linux siempre utiliza un diseño de una sola línea porque su menú del panel se envía mediante D-Bus, que transporta una etiqueta en lugar de un diseño personalizado; aun así, puede incluir el gráfico seleccionado como imagen.';

  @override
  String get trayKeepRunning => 'Seguir ejecutándose en la bandeja';

  @override
  String get trayKeepRunningTip =>
      'Al cerrar la ventana, la aplicación permanece en la bandeja del sistema y sigue supervisando tus servidores. Desactiva esta opción para que el botón de cierre termine la aplicación.';

  @override
  String get bgRunNeedsNotification =>
      'Para ejecutarse en segundo plano hace falta una notificación permanente, y esta app no tiene permiso de notificaciones. Toca para concederlo.';

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
  String get ungrouped => 'Sin agrupar';

  @override
  String get containerReclaimable => 'Reclaimable';

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
  String get noConnectionMethod => 'Configura SSH, un agente monitor, o ambos';

  @override
  String get preferredTransport => 'Intentar primero';

  @override
  String get preferredTransportTip =>
      'De dónde se lee el estado y qué conexión abre primero un comando. La otra sigue disponible.';

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
  String get liveActivity => 'Actividad en vivo';

  @override
  String get liveActivityTip =>
      'Muestra las sesiones de terminal en la pantalla bloqueada y en Dynamic Island. El nombre del servidor y el estado de la conexión se muestran allí sin desbloquear el dispositivo.';

  @override
  String get liveActivitySystemDisabled =>
      'iOS no lo permite. Los interruptores están en Ajustes › ServerBox › Actividades en vivo y Ajustes › Face ID y código › Actividades en vivo.';

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
  String get serverFuncBtns => 'Botones de función del servidor';

  @override
  String get serverOrder => 'Orden del servidor';

  @override
  String get serverTabEmpty => 'Aún no hay servidores';

  @override
  String get serverTabRequired =>
      'La pestaña del servidor no se puede eliminar';

  @override
  String get shareCodeHint =>
      'Comunica estos dígitos al destinatario por separado. No están incluidos en el código QR.';

  @override
  String get shareCodePrompt => 'Código de 6 dígitos';

  @override
  String get shareCodeTitle => 'Código de un solo uso';

  @override
  String get shareExpired =>
      'Este contenido compartido ha caducado. Solicita uno nuevo.';

  @override
  String get shareImportFile => 'Desde un archivo compartido';

  @override
  String get shareImportTitle => 'Importar servidor compartido';

  @override
  String get shareIncludesKey =>
      'El contenido compartido incluye la clave privada.';

  @override
  String get shareOmittedBmc =>
      'Las credenciales de BMC. La dirección está incluida, pero las credenciales no.';

  @override
  String get shareOmittedJump =>
      'El servidor de salto, porque está guardado como otro servidor en este dispositivo.';

  @override
  String get shareOmittedKeyPath =>
      'El archivo de clave, porque su ruta solo es válida en este dispositivo.';

  @override
  String get shareOmittedMissingKey =>
      'La clave privada, porque no está en el almacén de claves de este dispositivo.';

  @override
  String get shareOmittedTip =>
      'No se incluye; el destinatario debe configurar:';

  @override
  String get sharePassphraseTip =>
      'Esta contraseña cifra el archivo. El destinatario la necesita para importar el servidor y no se puede recuperar.';

  @override
  String shareQrTip(int minutes) {
    return 'Los datos de conexión de este código QR están cifrados. El contenido compartido caduca en $minutes minutos.';
  }

  @override
  String get shareScanQr => 'Escanear un código QR';

  @override
  String shareServerExists(String name) {
    return '«$name» ya utiliza esta dirección en este dispositivo. ¿Importarlo de todos modos?';
  }

  @override
  String get shareTooBigForQr =>
      'Es demasiado grande para un código QR. Compártelo como archivo.';

  @override
  String get shareTooNew =>
      'Este contenido se creó con una versión más reciente de ServerBox. Actualiza la aplicación para abrirlo.';

  @override
  String get shareUnreadable =>
      'Este no es un contenido compartido válido de ServerBox.';

  @override
  String get shareVia => 'Compartir mediante';

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
  String get sftpUnavailableUseScp =>
      'Si este host no tiene subsistema SFTP, como ocurre en muchos dispositivos embebidos, cambia su transferencia de archivos a SCP en los ajustes del servidor.';

  @override
  String get sshFileTransportTip =>
      'SFTP sirve para cualquier equipo actual. Elige SCP para un host antiguo o embebido cuyo servidor SSH no tiene subsistema SFTP: necesita el comando `scp` y un shell que además tenga las utilidades de archivos habituales (`find`, `stat`, `mv`, `chmod`).';

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
  String get virtKeyRows => 'Filas visibles a la vez';

  @override
  String get virtKeyRowsTip =>
      'El resto va en una página aparte, que se desliza lateralmente.';

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
  String get portForwardBetaTitle => 'Redirección de puertos (beta)';

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
  String get processSearchHint => 'Nombre, usuario o PID';

  @override
  String processShowKernelThreads(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hilos del kernel',
      one: '1 hilo del kernel',
    );
    return 'Mostrar $_temp0';
  }

  @override
  String get processForceKill => 'Force kill';

  @override
  String get processStarted => 'Started';

  @override
  String get processThreads => 'Threads';

  @override
  String get watchServers => 'Servidores en el reloj';

  @override
  String get watchServersTip =>
      'El reloj consulta al monitor por su cuenta, así que solo se pueden elegir servidores con uno.';

  @override
  String get watchNoMonitorServer =>
      'Ningún servidor tiene un agente monitor configurado';

  @override
  String get legacyStatusGoneTitle => 'Las URL de estado ya no funcionan';

  @override
  String get legacyStatusGoneBody =>
      'La app del reloj y los widgets leían una dirección `/status` escrita a mano. Ese endpoint se ha eliminado: solo podía devolver valores actuales como texto, por eso nunca pudieron mostrar una gráfica.\n\nAhora leen la API autenticada del agente monitor, dibujan tendencias y se mantienen sincronizados con la app por sí solos. Configura el servidor una vez en la app y cada reloj y widget lo recogerá.';

  @override
  String get services => 'Servicios';

  @override
  String get status => 'Estado';

  @override
  String get enable => 'Habilitar';

  @override
  String get disable => 'Deshabilitar';

  @override
  String get starting => 'Iniciando';

  @override
  String get stopping => 'Deteniendo';

  @override
  String get serviceManagerUnsupported => 'Gestor de servicios no compatible';

  @override
  String get serviceManagerUnsupportedTip =>
      'Este servidor utiliza un gestor de servicios que ServerBox aún no admite. Se admiten systemd, procd y OpenRC.';

  @override
  String serviceManagerFmt(String manager) {
    return 'Gestionado por $manager';
  }

  @override
  String get serviceListFailed => 'No se pudieron listar los servicios';

  @override
  String get serviceDetailsUnavailable =>
      'Algunos detalles del servicio no están disponibles';

  @override
  String get serviceDetailsUnavailableTip =>
      'La lista se puede usar, pero el gestor no devolvió toda la información de estado o inicio automático.';

  @override
  String get systemdUserScopeMissing => 'No se listan las unidades de usuario';

  @override
  String get systemdUserScopeMissingTip =>
      'Esta cuenta no tiene bus de sesión de usuario en el servidor, por lo que solo se muestran las unidades del sistema.';

  @override
  String get serviceSearchHint => 'Unit name';

  @override
  String get serviceNeedsAttention => 'Needs attention';

  @override
  String serviceOtherUnits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unidades más',
      one: '1 unidad más',
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
    return 'Detenido hace $duration';
  }

  @override
  String serviceExitStatus(String code) {
    return 'estado de salida $code';
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
      other: 'Últimas $count líneas',
      one: 'Última línea',
    );
    return '$_temp0';
  }

  @override
  String get serviceJournalUnreadable => 'Esta cuenta no puede leer el journal';

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
  String get fan => 'Ventilador';

  @override
  String get clockSpeed => 'Reloj';

  @override
  String get vendor => 'Fabricante';

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

  @override
  String get privacyBlur => 'Privacidad en segundo plano';

  @override
  String get privacyBlurTip => 'Ocultar el contenido de la app en el selector';

  @override
  String get floatReturnToTab => 'Volver a la pestaña';

  @override
  String get termInFloatWindow => 'Esta terminal está en la ventana flotante';

  @override
  String get globeEnabledTip =>
      'Dibujar los servidores en un globo, donde están sus direcciones. Desactivado quita el botón y detiene toda consulta.';

  @override
  String get geoShardsConsentAttribution =>
      'Geolocalización IP por [DB-IP](https://db-ip.com), CC BY 4.0.';

  @override
  String get geoMissPrivate => 'Dirección privada';

  @override
  String get geoMissNoData => 'Sin datos de ubicación';

  @override
  String get globeGuide =>
      'Toca aquí para ver tus servidores en un globo, donde están sus direcciones.';

  @override
  String get publicIp => 'IP pública';

  @override
  String get geoData => 'Datos a nivel de ciudad';

  @override
  String get geoDataTip =>
      'Tras la descarga, todas las consultas de ubicación usan los datos guardados en este dispositivo. No se envían al servicio de descarga direcciones de servidores ni actividad de consulta.';

  @override
  String get geoDataMissing => 'No descargados';

  @override
  String get geoDataUnreachable => 'No se han podido obtener los datos.';

  @override
  String get geoDataRemoveFailed => 'No se han podido eliminar los datos.';

  @override
  String geoDataCurrent(Object month) {
    return '$month ya está instalado.';
  }

  @override
  String geoDataConsent(Object download, Object disk) {
    return '**Descarga: $download · Almacenamiento en el dispositivo: $disk.** El conjunto de datos completo se guarda en este dispositivo y todas las consultas de ubicación posteriores se realizan localmente. No se envían al servicio de descarga direcciones de servidores ni actividad de consulta.\n\nSe actualiza cada mes. Una versión más reciente sustituye los datos instalados sin conservar una copia adicional. Puedes eliminarlos en cualquier momento.';
  }

  @override
  String get benchmark => 'Prueba de rendimiento';

  @override
  String get benchmarkIntro =>
      'Ejecuta Yet Another Bench Script en este servidor para probar el disco, la red y la CPU. Una ejecución completa tarda entre 10 y 20 minutos y continúa aunque salgas de esta página o cierres la aplicación.';

  @override
  String get benchmarkNoRuns => 'Aún no hay pruebas de rendimiento.';

  @override
  String get benchmarkRunning => 'Prueba de rendimiento en curso';

  @override
  String get benchmarkStartFailed =>
      'No se pudo iniciar la prueba de rendimiento';

  @override
  String get benchmarkCancelConfirm =>
      '¿Detener esta prueba? Se perderán todas las mediciones realizadas hasta ahora.';

  @override
  String get benchmarkDeleteConfirm => '¿Eliminar el resultado de esta prueba?';

  @override
  String get benchmarkNothingSelected =>
      'Todas las fases están desactivadas. Solo se recopilará información del sistema y tardará unos segundos.';

  @override
  String get benchmarkDiskTip =>
      'fio con cuatro tamaños de bloque; unos 3 minutos. Escribe un archivo de prueba de 2 GB en el directorio de trabajo y necesita ese espacio libre.';

  @override
  String get benchmarkNetworkTip =>
      'iperf3 contra servidores públicos; unos 4 minutos.';

  @override
  String get benchmarkReducedNetwork => 'Menos ubicaciones';

  @override
  String benchmarkReducedNetworkTip(String full, String reduced) {
    return 'Tres ubicaciones en lugar de siete. El tráfico aproximado baja de $full a $reduced.';
  }

  @override
  String get benchmarkCpuTip =>
      'Descarga Geekbench, un programa propietario, y **publica el resultado en una página pública de geekbench.com**, incluidos el modelo de CPU, el número de núcleos y la memoria.';

  @override
  String get benchmarkSensitiveOptions =>
      'Las siguientes opciones descargan y ejecutan software de terceros en este servidor o envían información del servidor a terceros. Están desactivadas de forma predeterminada.';

  @override
  String get benchmarkIpInfoTip =>
      'Envía la dirección pública de este servidor a ip-api.com mediante HTTP sin cifrar.';

  @override
  String get benchmarkIpInfo => 'Consultar propietario de la IP';

  @override
  String get benchmarkPreferBin => 'Descargar fio e iperf3';

  @override
  String get benchmarkPreferBinTip =>
      'Los descarga de GitHub en lugar de usar los paquetes del host. Actívalo solo si el host no tiene instalado ninguno de los dos.';

  @override
  String get benchmarkWorkDir => 'Directorio de trabajo';

  @override
  String get benchmarkWorkDirTip =>
      'Determina qué sistema de archivos mide la prueba de disco. Si se deja vacío, se usa el directorio personal de la cuenta de inicio de sesión.';

  @override
  String benchmarkEstimatedTime(String minutes) {
    return 'Unos $minutes min';
  }

  @override
  String benchmarkEstimatedTraffic(String size) {
    return 'Unos $size de tráfico';
  }

  @override
  String get benchmarkPhaseSystem => 'Leyendo información del sistema';

  @override
  String get benchmarkPhaseDisk => 'Probando el disco';

  @override
  String get benchmarkPhaseNetwork => 'Probando la red';

  @override
  String get benchmarkPhaseCpu => 'Probando la CPU';

  @override
  String get benchmarkPhaseDone => 'Finalizando';

  @override
  String get benchmarkResultUnreadable =>
      'No se pudo interpretar este resultado como JSON. El texto original aparece abajo.';

  @override
  String get benchmarkViewOnGeekbench => 'Ver en Geekbench';

  @override
  String get benchmarkGeekbenchPublic =>
      'Este resultado está publicado de forma pública en el enlace anterior.';

  @override
  String get benchmarkSingleCore => 'Un núcleo';

  @override
  String get benchmarkMultiCore => 'Varios núcleos';

  @override
  String get benchmarkIops => 'IOPS';

  @override
  String get benchmarkSend => 'Subida';

  @override
  String get benchmarkRecv => 'Bajada';

  @override
  String get benchmarkLatency => 'Latencia';

  @override
  String get benchmarkVirt => 'Virtualización';

  @override
  String get benchmarkRawLog => 'Registro de ejecución';

  @override
  String benchmarkUpstream(String version) {
    return 'Con tecnología de Yet Another Bench Script ($version)';
  }

  @override
  String get benchmarkPhaseStarting => 'Iniciando';

  @override
  String get benchmarkNoOutputYet =>
      'Aún no hay salida. Antes de mostrar la primera línea, YABS comprueba si se puede acceder a google.com e icanhazip.com. En redes que bloquean cualquiera de estos sitios, puede tardar varios minutos.';

  @override
  String get tagsEmptyTip =>
      'Aún no hay etiquetas. Añade una al editar un servidor y aparecerá aquí.';

  @override
  String get benchmarkNoServers =>
      'Añade primero un servidor y vuelve después para ejecutar el benchmark.';

  @override
  String get schemaTooNewTitle =>
      'Estos datos son más recientes que la aplicación';

  @override
  String schemaTooNewBody(int stored, int supported) {
    return 'Los escribió una versión más reciente de ServerBox (almacenamiento v$stored); esta versión puede leer hasta v$supported. No se ha modificado nada.';
  }

  @override
  String get schemaTooNewReinstall =>
      'Vuelve a instalar esa versión más reciente y todo se abrirá como antes.';

  @override
  String get schemaTooNewExportPlain => 'Exportar sin contraseña';

  @override
  String get schemaTooNewPlainWarn =>
      'El archivo contendrá en texto sin cifrar todas las claves privadas SSH, contraseñas de servidores y claves API. Quien obtenga el archivo tendrá acceso a todo ello.';

  @override
  String get schemaTooNewWipe => 'Eliminar todos los datos';

  @override
  String get schemaTooNewWipeConfirm =>
      'Se eliminarán todos los servidores, claves, fragmentos y ajustes de este dispositivo, y no se podrá deshacer. Una copia de seguridad exportada aquí sería la única copia restante.';

  @override
  String get schemaTooNewWipeDone =>
      'Datos eliminados. Abre la aplicación de nuevo para empezar desde cero.';

  @override
  String get schemaTooNewWipeFailed =>
      'No se han podido eliminar algunos datos y esta versión aún no puede abrir lo que queda. Vuelve a instalar la versión más reciente para acceder a ellos.';

  @override
  String get systemUsers => 'Users';

  @override
  String get userManagerLinuxOnly =>
      'La gestión de usuarios del sistema solo admite servidores Linux por ahora.';

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
      'Los cambios en root se aplican inmediatamente a todas las sesiones.';

  @override
  String get userComment => 'Comment';

  @override
  String get userPrimaryGroup => 'Primary group';

  @override
  String get userSupplementaryGroups => 'Grupos adicionales';

  @override
  String get userLoginShell => 'Login shell';

  @override
  String get userCreateHome => 'Crear el directorio personal';

  @override
  String get userMoveHome =>
      'Mover el directorio personal existente al cambiar la ruta';

  @override
  String get userRemoveHome => 'Eliminar el directorio personal';

  @override
  String get userPasswordCreateTip =>
      'Deja la contraseña vacía para crear una cuenta con el acceso por contraseña bloqueado.';

  @override
  String get userPasswordEditTip =>
      'Deja la contraseña vacía para conservar la actual.';

  @override
  String funcUnavailableFmt(Object func) {
    return '$func no está disponible con la conexión de este servidor.';
  }

  @override
  String get rangeLive => 'En vivo';

  @override
  String get diskIo => 'E/S de disco';

  @override
  String get peak => 'pico';

  @override
  String get hardware => 'Hardware';

  @override
  String get cores => 'Núcleos';

  @override
  String get historyNoStored =>
      'Solo un agente monitor almacena el historial. Esta conexión conserva lo que la app ha visto desde que se conectó.';

  @override
  String get noHistoryYet => 'Aún no hay mediciones';

  @override
  String get noData => 'sin datos';

  @override
  String get from => 'Desde';

  @override
  String get to => 'Hasta';

  @override
  String get beyondRetention => 'más atrás de lo que este agente guardó';

  @override
  String agentRetentionFmt(Object kept) {
    return 'El agente guarda $kept';
  }

  @override
  String oldestSampleFmt(Object time) {
    return 'muestra más antigua $time';
  }

  @override
  String get rangeEndsBeforeItStarts =>
      'El fin del intervalo debe ser posterior a su inicio.';

  @override
  String get samples => 'muestras';

  @override
  String get unavailable => 'no disponible';

  @override
  String get metricUnavailableTip =>
      'El resto de la página no está afectado. Revisa en el host el comando del que procede esta lectura.';

  @override
  String get waitingFirstSample => 'Esperando la primera muestra';

  @override
  String atTimeFmt(Object time) {
    return 'a las $time';
  }

  @override
  String get stored => 'almacenado';

  @override
  String lastSampleFmt(Object ago) {
    return 'última muestra $ago';
  }

  @override
  String staleSinceFmt(Object ago, Object time) {
    return 'Todo lo de abajo es de $time, $ago.';
  }

  @override
  String noDataBeforeFmt(Object time) {
    return 'sin datos antes de $time';
  }

  @override
  String loadingRangeFmt(Object range) {
    return 'Cargando $range…';
  }

  @override
  String noStoredHistoryFor(Object metric) {
    return 'No hay historial almacenado de $metric';
  }

  @override
  String devicesFmt(Object count) {
    return '$count dispositivos';
  }

  @override
  String devicesBusiestFmt(Object count, Object name) {
    return '$count dispositivos · $name el más ocupado';
  }

  @override
  String devicesPlottedFmt(Object plotted, Object total) {
    return '$plotted de $total dispositivos';
  }

  @override
  String sensorsHottestFmt(Object count, Object name) {
    return '$count sensores · $name el más caliente';
  }

  @override
  String get oneDeviceAtLeast =>
      'Al menos un dispositivo permanece en el gráfico.';

  @override
  String shownOfFmt(Object shown, Object total, Object what) {
    return '$shown de $total $what';
  }

  @override
  String countOfFmt(Object count, Object what) {
    return '$count $what';
  }

  @override
  String get unitDevices => 'dispositivos';

  @override
  String get unitSensors => 'sensores';

  @override
  String get unitBatteries => 'baterías';

  @override
  String get unitCommands => 'comandos';

  @override
  String get unitReadings => 'lecturas';

  @override
  String get unitGpus => 'GPU';

  @override
  String get hottest => 'el más caliente';

  @override
  String get oldest => 'el más antiguo';

  @override
  String get notApplicable => 'no aplicable';

  @override
  String get attributes => 'atributos';

  @override
  String get powerOnHours => 'Horas encendido';

  @override
  String get powerCycles => 'Ciclos de encendido';

  @override
  String get lifeLeft => 'Vida restante';

  @override
  String get lifetimeWrite => 'Escritura total';

  @override
  String get lifetimeRead => 'Lectura total';

  @override
  String get averageErase => 'Borrados medios';

  @override
  String get unsafeShutdowns => 'Apagados inseguros';

  @override
  String get diskAllPassed => 'todos PASSED';

  @override
  String diskWarningFmt(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count advertencias',
      one: '1 advertencia',
    );
    return '$_temp0';
  }

  @override
  String diskWrongOfFmt(Object total, Object wrong) {
    return '$wrong de $total dispositivos';
  }

  @override
  String get diskSmartSortedTip => 'Peor primero';

  @override
  String readAgoFmt(Object ago) {
    return 'leído $ago';
  }

  @override
  String processesFmt(Object count) {
    return '$count procesos';
  }

  @override
  String diskFailingFmt(Object count) {
    return '$count con fallos';
  }

  @override
  String get diskSmartOpenTip => 'Toca uno para ver sus atributos';

  @override
  String get cycle => 'Ciclos';

  @override
  String get window => 'ventana';

  @override
  String ofFmt(Object total) {
    return 'de $total';
  }

  @override
  String get serverDetailCards => 'Tarjetas de la página de detalles';

  @override
  String get connection => 'Conexión';

  @override
  String get connectionTip =>
      'Ambos pueden estar activos a la vez. El orden es el orden en que se marcan.';

  @override
  String transportOrderFmt(Object first, Object second) {
    return 'Arrastra para cambiar el orden. Se marca $first primero; si no responde, $second lleva la sesión por su cuenta.';
  }

  @override
  String transportOnlyFmt(Object name) {
    return 'Solo $name está activo, así que no hay nada a lo que recurrir.';
  }

  @override
  String get transportNoneOn =>
      'Ambos están desactivados: no se puede conectar con este servidor.';

  @override
  String get transportOffKept =>
      'desactivado — los ajustes se conservan, nunca se marca';

  @override
  String get transportDialledFirst => 'se marca primero';

  @override
  String get transportFallback => 'alternativa';

  @override
  String get transportOnlyMethod => 'único método';

  @override
  String get transportOff => 'desactivado';

  @override
  String get thisDevice => 'Este dispositivo';

  @override
  String get localServerTip =>
      'Lee este dispositivo directamente ejecutando aquí el script de estado. No se usan SSH ni Monitor HTTP, y su configuración se conserva.';

  @override
  String get localServerUnsupported =>
      'Esta plataforma no puede leer este dispositivo como servidor. Linux, Windows y la versión DMG de macOS sí pueden.';

  @override
  String get remoteDesktopIntro =>
      'Abre el escritorio RDP o VNC de un servidor dentro de la app. La conexión pasa por la conexión SSH del servidor o por su agente Monitor, así que el puerto del escritorio no tiene que ser accesible desde la red.';

  @override
  String get remoteDesktopIntroProfiles =>
      'Guarda un perfil por escritorio desde el botón Escritorio remoto de un servidor o desde la pestaña Escritorio remoto.';

  @override
  String get localServerIntro =>
      'Añade como servidor el dispositivo que ejecuta ServerBox. El estado, los procesos, los servicios, los contenedores, la terminal y los archivos funcionan sin SSH ni agente Monitor.';

  @override
  String get localServerAdd => 'Añadir este dispositivo';

  @override
  String get localServerIntroFooter =>
      'También puede activarse más tarde, en la página de edición de un servidor, en Conexión.';

  @override
  String get transportSectionOff =>
      'Desactivado. Los campos de abajo se conservan para cuando vuelvas a activarlo.';

  @override
  String get monitorAgent => 'Agente monitor';

  @override
  String get plainHttpEditTip =>
      'Las credenciales y las métricas cruzan la red sin cifrar. Limítalo a una LAN o a una dirección de Tailscale, o pon el agente detrás de TLS.';

  @override
  String get behaviour => 'Comportamiento';

  @override
  String get optional => 'Opcional';

  @override
  String get optionalTip =>
      'Nada de esto hace falta para conectar. Abre uno y sus campos toman el formulario.';

  @override
  String get sshAdvanced => 'SSH avanzado';

  @override
  String get sshAdvancedTip =>
      'Destino alternativo, ProxyCommand, servidor de salto, transporte de archivos, ruta remota';

  @override
  String get sshLegacyAlgorithms => 'Algoritmos obsoletos';

  @override
  String get sshLegacyAlgorithmsTip =>
      'Para servidores SSH antiguos, como routers o switches, que solo ofrecen una clave de host SHA-1 `ssh-rsa` o un intercambio de claves SHA-1. Es menos seguro; actívalo solo para hosts que lo necesiten.';

  @override
  String get appearanceAndPlace => 'Apariencia y ubicación';

  @override
  String get appearanceAndPlaceTip => 'Logotipo, coordenadas';

  @override
  String get statusCollection => 'Recogida de estado';

  @override
  String get statusCollectionTip =>
      'Qué comandos se ejecutan, comandos propios, qué dispositivo se lee';

  @override
  String get tagAllTags => 'Todas las etiquetas';

  @override
  String get tagMatching => 'Coincidencias';

  @override
  String get tagNewHint => 'Nueva etiqueta';

  @override
  String tagCreateFmt(Object tag) {
    return 'Crear #$tag';
  }

  @override
  String get tagOnThisServer => 'en este servidor';

  @override
  String tagServersFmt(Object count) {
    return '$count servidores';
  }

  @override
  String tagOnThisServerFmt(Object count) {
    return '$count en este servidor';
  }

  @override
  String get tagMatchesTyped => 'coincide con lo que escribiste';

  @override
  String get tagEditorTip =>
      'Lo que escribes filtra la lista; el botón crea la etiqueta y la pone en este servidor en un solo paso. El lápiz la renombra en todos los servidores que la llevan. Una etiqueta que ningún servidor lleva desaparece al guardar.';

  @override
  String get tagRenamesOnSave => 'Los cambios de nombre se aplican al guardar';

  @override
  String get scheduledTasks => 'Scheduled tasks';

  @override
  String get scheduledTaskLinuxOnly =>
      'La gestión de tareas programadas solo admite servidores Linux por ahora.';

  @override
  String get scheduledTaskUnavailable =>
      'crontab no está disponible en este servidor.';

  @override
  String get scheduledTaskPreserveTip =>
      'Se conservan los comentarios, las variables de entorno y las líneas no reconocidas de este crontab.';

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
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total tareas',
      one: '1 tarea',
    );
    String _temp1 = intl.Intl.pluralLogic(
      enabled,
      locale: localeName,
      other: '$enabled activadas',
      one: '1 activada',
    );
    return '$_temp0 · $_temp1';
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
      'Al desactivarla, la línea se guarda como comentario.';

  @override
  String scheduledTaskEmptyFmt(Object user) {
    return 'No hay tareas programadas para $user. Lo que añadas aquí se escribirá en el crontab de esa cuenta.';
  }

  @override
  String get scheduledTaskFieldMinute => 'Minute';

  @override
  String get scheduledTaskFieldHour => 'Hour';

  @override
  String get scheduledTaskFieldDayOfMonth => 'Day of month';

  @override
  String get scheduledTaskFieldMonth => 'Month';

  @override
  String get scheduledTaskFieldDayOfWeek => 'Day of week';

  @override
  String get cronErrScheduleEmpty => 'Debes indicar una programación.';

  @override
  String get cronErrCommandEmpty => 'Debes indicar un comando.';

  @override
  String get cronErrLineBreak =>
      'Una línea de crontab no puede contener saltos de línea.';

  @override
  String get cronErrMacro =>
      'Una macro consta de una sola palabra, como @reboot.';

  @override
  String get cronErrFieldCount =>
      'Una programación cron tiene cinco campos, o una macro como @reboot.';

  @override
  String get cronAtBoot => 'At boot';

  @override
  String get cronEveryMin => 'Every minute';

  @override
  String cronEveryMinsFmt(Object minutes) {
    return 'Cada $minutes minutos';
  }

  @override
  String cronHourlyAtFmt(Object minute) {
    return 'Cada hora a los :$minute';
  }

  @override
  String cronEveryHoursFmt(Object hours) {
    return 'Cada $hours horas';
  }

  @override
  String cronEveryHoursAtFmt(Object hours, Object minute) {
    return 'Cada $hours horas a los :$minute';
  }

  @override
  String cronDailyAtFmt(Object time) {
    return 'Todos los días a las $time';
  }

  @override
  String cronWeekdaysAtFmt(Object time) {
    return 'De lunes a viernes a las $time';
  }

  @override
  String cronWeekdayAtFmt(Object day, Object time) {
    return 'Cada $day a las $time';
  }

  @override
  String cronMonthlyAtFmt(Object day, Object time) {
    return 'El día $day de cada mes a las $time';
  }

  @override
  String get monitorSettings => 'Monitor settings';

  @override
  String get monitorAgentDefault => 'Agent default';

  @override
  String get monitorNeedsRestart => 'Se aplica después de reiniciar el agent';

  @override
  String get monitorCollection => 'Collection';

  @override
  String get extendedInterval => 'Intervalo de recopilación ampliada';

  @override
  String get idlePause => 'Pausar cuando nadie esté consultando';

  @override
  String get idlePauseTip =>
      'La recopilación ampliada ejecuta smartctl, sensors y amd-smi. Pausarla cuando ningún cliente consulta evita activar un disco para obtener datos que nadie está leyendo.';

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
      'Métrica: cpu / memory / swap / disk / network / temperature. Coincidencia: cpu0 para un núcleo, used / free / avail para memoria y rx / tx para red; disk y temperature ignoran este campo. Umbral: un comparador y un valor, como >=80%, >=70c o >10m/s.';

  @override
  String get pushChannels => 'Canales de notificación';

  @override
  String get pushType => 'Type';

  @override
  String get pushRate => 'Rate limit';

  @override
  String get pushHeaders => 'Headers';

  @override
  String get pushSecretSet => 'Configurado en el agent; no se muestra';

  @override
  String get pushSecretKeep => 'Dejar en blanco para conservar';

  @override
  String get pushTestTip =>
      'Envía una notificación por este canal con la configuración que aparece aquí, esté guardada o no.';

  @override
  String get pushTestSent => 'El canal aceptó la notificación';

  @override
  String get pushTestFailed => 'El canal rechazó la notificación';

  @override
  String get pushTestMessage => 'Notificación de prueba de ServerBox Monitor';

  @override
  String get pushUnknownType =>
      'Este agent no puede enviar por este tipo de canal, por lo que no se muestra su configuración. Puedes eliminarlo aquí o editarlo en el config.toml del agent.';

  @override
  String get pushJsonInvalid => 'no es JSON válido';

  @override
  String get dataRetention => 'Data retention';

  @override
  String get dataRetentionTip =>
      'Si está desactivado, el agent no elimina nada y su base de datos crece sin límite.';

  @override
  String get retentionMetrics => 'Keep metrics';

  @override
  String get retentionAlerts => 'Keep alerts';

  @override
  String get retentionCleanup => 'Ejecutar limpieza cada';

  @override
  String get retentionMaxDbSize => 'Límite de tamaño de la base de datos';

  @override
  String get corsOrigins => 'Orígenes permitidos por CORS';

  @override
  String get corsOriginsTip =>
      'Orígenes desde los que un panel web puede llamar a este agent. Vacío significa que solo se permite el mismo origen.';

  @override
  String get monitorNoRemoteAccess =>
      'Este agente está configurado solo para supervisar. Aquí no puedes abrir un terminal, ejecutar comandos ni explorar archivos. Para activar estas funciones, edita [remote_access] en el config.toml del agente.';

  @override
  String get alerts => 'Alertas';

  @override
  String get online => 'en línea';

  @override
  String get densityCards => 'Tarjetas';

  @override
  String get densityRows => 'Filas';

  @override
  String get densityGrid => 'Cuadrícula';

  @override
  String get connect => 'Conectar';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get searchServerTip =>
      'Busca nombres y direcciones: los dos datos que el editor solicita primero.';

  @override
  String get addServerTip =>
      'Rellena uno, escanea un código QR o importa un archivo que alguien haya compartido.';

  @override
  String get move => 'Mover';

  @override
  String get moveToTop => 'Mover al principio';

  @override
  String get moveToBottom => 'Mover al final';

  @override
  String get groupByTag => 'Agrupar por etiqueta';

  @override
  String get groupByTagTip =>
      'Las etiquetas se definen en el editor del servidor.';

  @override
  String get connecting => 'Conectando…';

  @override
  String get authShort => 'Auth';

  @override
  String get remoteDesktopFitToWindow => 'Ajustar a la ventana';

  @override
  String get remoteDesktopActualSize => 'Tamaño real';

  @override
  String get remoteDesktopZoom => 'Ampliación';

  @override
  String get remoteDesktopViewOnly => 'Solo lectura';

  @override
  String get remoteDesktopDisableViewOnly => 'Desactivar solo lectura';

  @override
  String get remoteDesktopSendClipboardText => 'Enviar texto del portapapeles';

  @override
  String get remoteDesktopShowKeyboard => 'Mostrar teclado';

  @override
  String get remoteDesktopMoreControls => 'Más controles';

  @override
  String get remoteDesktopUseDirectPointer => 'Usar puntero directo';

  @override
  String get remoteDesktopUseTouchpadPointer => 'Usar puntero del panel táctil';

  @override
  String get remoteDesktopSendCtrlAltDelete => 'Enviar Ctrl+Alt+Supr';

  @override
  String get remoteDesktopReconnect => 'Reconectar';

  @override
  String get remoteDesktopFullScreen => 'Pantalla completa';

  @override
  String get remoteDesktopCloseSession => 'Cerrar sesión';

  @override
  String get remoteDesktopConnected => 'Conectado';

  @override
  String get remoteDesktopConnecting => 'Conectando';

  @override
  String get remoteDesktopReconnecting => 'Reconectando';

  @override
  String get remoteDesktopDisconnected => 'Desconectado';

  @override
  String get remoteDesktopGuideTouch => 'Panel táctil';

  @override
  String get remoteDesktopGuideTouchTip =>
      'Un dedo mueve el puntero como un panel táctil y un toque hace clic. Toca con dos dedos para clic derecho, arrastra con dos para desplazarte y pellizca para hacer zoom. Toca dos veces y mantén el dedo para arrastrar.';

  @override
  String get remoteDesktopGuideKeyboardTip =>
      'Abre el teclado en pantalla. Lo que escribas se envía al escritorio remoto.';

  @override
  String get remoteDesktopGuideViewOnlyTip =>
      'Deja de enviar el puntero y las teclas, para mirar sin hacer clic por accidente.';

  @override
  String get remoteDesktopGuideMoreTip =>
      'Aquí están Ctrl+Alt+Supr, reconectar y pantalla completa.';

  @override
  String get remoteDesktopGuidePointerTip =>
      'También el puntero directo, en el que un dedo hace clic donde toca.';

  @override
  String get remoteDesktopVncClipboardLatin1Only =>
      'El portapapeles VNC solo admite texto Latin-1.';
}
