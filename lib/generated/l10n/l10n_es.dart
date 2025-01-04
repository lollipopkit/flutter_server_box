import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get aboutThanks => 'Gracias a los siguientes participantes.';

  @override
  String get acceptBeta => 'Aceptar actualizaciones de la versión de prueba';

  @override
  String get addSystemPrivateKeyTip => 'Actualmente no hay ninguna llave privada, ¿quieres agregar la que viene por defecto en el sistema (~/.ssh/id_rsa)?';

  @override
  String get added2List => 'Añadido a la lista de tareas';

  @override
  String get addr => 'Dirección';

  @override
  String get alreadyLastDir => 'Ya estás en el directorio superior';

  @override
  String get authFailTip => 'La autenticación ha fallado, por favor verifica si la contraseña/llave/host/usuario, etc., son incorrectos.';

  @override
  String get autoBackupConflict => 'Solo se puede activar una copia de seguridad automática a la vez';

  @override
  String get autoConnect => 'Conexión automática';

  @override
  String get autoRun => 'Ejecución automática';

  @override
  String get autoUpdateHomeWidget => 'Actualizar automáticamente el widget del escritorio';

  @override
  String get backupTip => 'Los datos exportados solo están encriptados de manera básica, por favor guárdalos en un lugar seguro.';

  @override
  String get backupVersionNotMatch => 'La versión de la copia de seguridad no coincide, no se puede restaurar';

  @override
  String get battery => 'Batería';

  @override
  String get bgRun => 'Ejecución en segundo plano';

  @override
  String get bgRunTip => 'Este interruptor solo indica que la aplicación intentará correr en segundo plano, si puede hacerlo o no depende de si tiene el permiso correspondiente. En Android puro, por favor desactiva la “optimización de batería” para esta app, en MIUI por favor cambia la estrategia de ahorro de energía a “Sin restricciones”.';

  @override
  String get cmd => 'Comando';

  @override
  String get collapseUITip => '¿Colapsar por defecto las listas largas en la UI?';

  @override
  String get conn => 'Conectar';

  @override
  String get container => 'Contenedor';

  @override
  String get containerTrySudoTip => 'Por ejemplo: si configuras el usuario dentro de la app como aaa, pero Docker está instalado bajo el usuario root, entonces necesitarás habilitar esta opción';

  @override
  String get convert => 'Convertir';

  @override
  String get copyPath => 'Copiar ruta';

  @override
  String get cpuViewAsProgressTip => 'Muestre la tasa de uso de cada CPU en estilo de barra de progreso (estilo antiguo)';

  @override
  String get cursorType => 'Tipo de cursor';

  @override
  String get customCmd => 'Comandos personalizados';

  @override
  String get customCmdDocUrl => 'https://github.com/lollipopkit/flutter_server_box/wiki#custom-commands';

  @override
  String get customCmdHint => '\"Nombre del comando\": \"Comando\"';

  @override
  String get decode => 'Decodificar';

  @override
  String get decompress => 'Descomprimir';

  @override
  String get deleteServers => 'Eliminar servidores en lote';

  @override
  String get dirEmpty => 'Asegúrate de que el directorio esté vacío';

  @override
  String get disconnected => 'Desconectado';

  @override
  String get disk => 'Disco';

  @override
  String get diskIgnorePath => 'Rutas de disco ignoradas';

  @override
  String get displayCpuIndex => 'Muestre el índice de CPU';

  @override
  String dl2Local(Object fileName) {
    return '¿Descargar $fileName a local?';
  }

  @override
  String get dockerEmptyRunningItems => 'No hay contenedores en ejecución.\nEsto podría deberse a que:\n- El usuario con el que se instaló Docker es diferente al configurado en la app\n- La variable de entorno DOCKER_HOST no se ha leído correctamente. Puedes obtenerla ejecutando `echo \$DOCKER_HOST` en el terminal.';

  @override
  String dockerImagesFmt(Object count) {
    return 'Total de $count imágenes';
  }

  @override
  String get dockerNotInstalled => 'Docker no está instalado';

  @override
  String dockerStatusRunningAndStoppedFmt(Object runningCount, Object stoppedCount) {
    return '$runningCount en ejecución, $stoppedCount detenidos';
  }

  @override
  String dockerStatusRunningFmt(Object count) {
    return '$count contenedores en ejecución';
  }

  @override
  String get doubleColumnMode => 'Modo de doble columna';

  @override
  String get doubleColumnTip => 'Esta opción solo habilita la función, si se puede activar o no depende del ancho del dispositivo';

  @override
  String get editVirtKeys => 'Editar teclas virtuales';

  @override
  String get editor => 'Editor';

  @override
  String get editorHighlightTip => 'El rendimiento del resaltado de código es bastante pobre actualmente, puedes elegir desactivarlo para mejorar.';

  @override
  String get encode => 'Codificar';

  @override
  String get envVars => 'Variable de entorno';

  @override
  String get experimentalFeature => 'Función experimental';

  @override
  String get extraArgs => 'Argumentos extra';

  @override
  String get fallbackSshDest => 'Destino SSH alternativo';

  @override
  String get fdroidReleaseTip => 'Si descargaste esta aplicación desde F-Droid, se recomienda desactivar esta opción.';

  @override
  String get fgService => 'Servicio en primer plano';

  @override
  String get fgServiceTip => 'Después de activarlo, algunos modelos de dispositivos pueden bloquearse. Desactivarlo puede hacer que algunos modelos no puedan mantener las conexiones SSH en segundo plano. Por favor, permita los permisos de notificación de ServerBox, la ejecución en segundo plano y el auto-despertar en la configuración del sistema.';

  @override
  String fileTooLarge(Object file, Object size, Object sizeMax) {
    return 'El archivo \'$file\' es demasiado grande \'$size\', supera el $sizeMax';
  }

  @override
  String get followSystem => 'Seguir al sistema';

  @override
  String get font => 'Fuente';

  @override
  String get fontSize => 'Tamaño de fuente';

  @override
  String get force => 'Forzar';

  @override
  String get fullScreen => 'Modo pantalla completa';

  @override
  String get fullScreenJitter => 'Temblores en modo pantalla completa';

  @override
  String get fullScreenJitterHelp => 'Prevención de quemaduras de pantalla';

  @override
  String get fullScreenTip => '¿Debe habilitarse el modo de pantalla completa cuando el dispositivo se rote al modo horizontal? Esta opción solo se aplica a la pestaña del servidor.';

  @override
  String get goBackQ => '¿Regresar?';

  @override
  String get goto => 'Ir a';

  @override
  String get hideTitleBar => 'Ocultar barra de título';

  @override
  String get highlight => 'Resaltar código';

  @override
  String get homeWidgetUrlConfig => 'Configuración de URL del widget de inicio';

  @override
  String get host => 'Anfitrión';

  @override
  String httpFailedWithCode(Object code) {
    return 'Fallo en la solicitud, código de estado: $code';
  }

  @override
  String get ignoreCert => 'Ignorar certificado';

  @override
  String get image => 'Imagen';

  @override
  String get imagesList => 'Lista de imágenes';

  @override
  String get init => 'Inicializar';

  @override
  String get inner => 'Interno';

  @override
  String get install => 'Instalar';

  @override
  String get installDockerWithUrl => 'Por favor instala Docker primero desde https://docs.docker.com/engine/install';

  @override
  String get invalid => 'Inválido';

  @override
  String get jumpServer => 'Servidor de salto';

  @override
  String get keepForeground => '¡Por favor, mantén la app en primer plano!';

  @override
  String get keepStatusWhenErr => 'Mantener el estado anterior del servidor';

  @override
  String get keepStatusWhenErrTip => 'Solo aplica cuando hay errores al ejecutar scripts';

  @override
  String get keyAuth => 'Autenticación con llave';

  @override
  String get letterCache => 'Caché de letras';

  @override
  String get letterCacheTip => 'Recomendado desactivar, pero después de desactivarlo, no se podrán ingresar caracteres CJK.';

  @override
  String get license => 'Licencia de código abierto';

  @override
  String get location => 'Ubicación';

  @override
  String get loss => 'Tasa de pérdida';

  @override
  String madeWithLove(Object myGithub) {
    return 'Hecho con ❤️ por $myGithub';
  }

  @override
  String get manual => 'Manual';

  @override
  String get max => 'Máximo';

  @override
  String get maxRetryCount => 'Número máximo de reintentos de conexión al servidor';

  @override
  String get maxRetryCountEqual0 => 'Reintentará infinitamente';

  @override
  String get min => 'Mínimo';

  @override
  String get mission => 'Misión';

  @override
  String get more => 'Más';

  @override
  String get moveOutServerFuncBtnsHelp => 'Activado: se mostrará debajo de cada tarjeta en la página de servidores. Desactivado: se mostrará en la parte superior de los detalles del servidor.';

  @override
  String get ms => 'milisegundos';

  @override
  String get needHomeDir => 'Si eres usuario de Synology, [consulta aquí](https://kb.synology.com/DSM/tutorial/user_enable_home_service). Los usuarios de otros sistemas deben buscar cómo crear un directorio home.';

  @override
  String get needRestart => 'Necesita reiniciar la app';

  @override
  String get net => 'Red';

  @override
  String get netViewType => 'Tipo de vista de red';

  @override
  String get newContainer => 'Crear contenedor nuevo';

  @override
  String get noLineChart => 'No utilice gráficos de líneas';

  @override
  String get noLineChartForCpu => 'No utilice gráficos lineales para la CPU';

  @override
  String get noPrivateKeyTip => 'La clave privada no existe, puede haber sido eliminada o hay un error de configuración.';

  @override
  String get noPromptAgain => 'No volver a preguntar';

  @override
  String get node => 'Nodo';

  @override
  String get notAvailable => 'No disponible';

  @override
  String get onServerDetailPage => 'En la página de detalles del servidor';

  @override
  String get onlyOneLine => 'Mostrar solo en una línea (desplazable)';

  @override
  String get onlyWhenCoreBiggerThan8 => 'Efectivo solo cuando el número de núcleos > 8';

  @override
  String get openLastPath => 'Abrir el último camino';

  @override
  String get openLastPathTip => 'Los diferentes servidores tendrán diferentes registros, y lo que se registra es la ruta de salida';

  @override
  String get parseContainerStatsTip => 'El análisis del estado de uso de Docker es bastante lento';

  @override
  String percentOfSize(Object percent, Object size) {
    return 'El $percent% de $size';
  }

  @override
  String get permission => 'Permisos';

  @override
  String get pingAvg => 'Promedio:';

  @override
  String get pingInputIP => 'Por favor, introduce la IP de destino o el dominio';

  @override
  String get pingNoServer => 'No hay servidores disponibles para hacer Ping\nPor favor, añade un servidor en la pestaña de servidores y vuelve a intentarlo';

  @override
  String get pkg => 'Gestión de paquetes';

  @override
  String get plugInType => 'Tipo de inserción';

  @override
  String get port => 'Puerto';

  @override
  String get preview => 'Vista previa';

  @override
  String get privateKey => 'Llave privada';

  @override
  String get process => 'Proceso';

  @override
  String get pushToken => 'Token de notificaciones';

  @override
  String get pveIgnoreCertTip => 'No se recomienda activarlo, ¡tenga cuidado con los riesgos de seguridad! Si está utilizando el certificado predeterminado de PVE, debe habilitar esta opción.';

  @override
  String get pveLoginFailed => 'Fallo al iniciar sesión. No se puede autenticar con el nombre de usuario/contraseña de la configuración del servidor para el inicio de sesión de Linux PAM.';

  @override
  String get pveVersionLow => 'Esta función está actualmente en fase de prueba y solo se ha probado en PVE 8+. Úsela con precaución.';

  @override
  String get pwd => 'Contraseña';

  @override
  String get read => 'Leer';

  @override
  String get reboot => 'Reiniciar';

  @override
  String get rememberPwdInMem => 'Recordar contraseña en la memoria';

  @override
  String get rememberPwdInMemTip => 'Utilizado para contenedores, suspensión, etc.';

  @override
  String get rememberWindowSize => 'Recordar el tamaño de la ventana';

  @override
  String get remotePath => 'Ruta remota';

  @override
  String get restart => 'Reiniciar';

  @override
  String get result => 'Resultado';

  @override
  String get rotateAngel => 'Ángulo de rotación';

  @override
  String get route => 'Enrutamiento';

  @override
  String get run => 'Ejecutar';

  @override
  String get running => 'En ejecución';

  @override
  String get sameIdServerExist => 'Ya existe un servidor con el mismo ID';

  @override
  String get save => 'Guardar';

  @override
  String get saved => 'Guardado';

  @override
  String get second => 'Segundo';

  @override
  String get sensors => 'Sensores';

  @override
  String get sequence => 'Secuencia';

  @override
  String get server => 'Servidor';

  @override
  String get serverDetailOrder => 'Orden de los componentes en la página de detalles del servidor';

  @override
  String get serverFuncBtns => 'Botones de función del servidor';

  @override
  String get serverOrder => 'Orden del servidor';

  @override
  String get sftpDlPrepare => 'Preparando para conectar al servidor...';

  @override
  String get sftpEditorTip => 'Si está vacío, use el editor de archivos incorporado de la aplicación. Si hay un valor, use el editor del servidor remoto, por ejemplo, `vim` (se recomienda detectar automáticamente según `EDITOR`).';

  @override
  String get sftpRmrDirSummary => 'Usar `rm -r` en SFTP para eliminar directorios';

  @override
  String get sftpSSHConnected => 'SFTP conectado...';

  @override
  String get sftpShowFoldersFirst => 'Mostrar carpetas primero';

  @override
  String get showDistLogo => 'Mostrar logo de distribución';

  @override
  String get shutdown => 'Apagar';

  @override
  String get size => 'Tamaño';

  @override
  String get snippet => 'Fragmento de código';

  @override
  String get softWrap => 'Salto de línea suave';

  @override
  String get specifyDev => 'Especificar dispositivo';

  @override
  String get specifyDevTip => 'Por ejemplo, las estadísticas de tráfico de red son por defecto para todos los dispositivos. Aquí puede especificar un dispositivo en particular.';

  @override
  String get speed => 'Velocidad';

  @override
  String spentTime(Object time) {
    return 'Tiempo gastado: $time';
  }

  @override
  String get sshTermHelp => 'Cuando el terminal es desplazable, arrastrar horizontalmente puede seleccionar texto. Hacer clic en el botón del teclado enciende/apaga el teclado. El icono de archivo abre el SFTP de la ruta actual. El botón del portapapeles copia el contenido cuando se selecciona texto y pega el contenido del portapapeles en el terminal cuando no se selecciona texto y hay contenido en el portapapeles. El icono de código pega fragmentos de código en el terminal y los ejecuta.';

  @override
  String sshTip(Object url) {
    return 'Esta función está en fase de pruebas.\n\nPor favor, informa los problemas en $url, o únete a nuestro desarrollo.';
  }

  @override
  String get sshVirtualKeyAutoOff => 'Desactivación automática de teclas virtuales';

  @override
  String get start => 'Iniciar';

  @override
  String get stat => 'Estadísticas';

  @override
  String get stats => 'Estadísticas';

  @override
  String get stop => 'Detener';

  @override
  String get stopped => 'Detenido';

  @override
  String get storage => 'Almacenamiento';

  @override
  String get supportFmtArgs => 'Soporta los siguientes argumentos de formato:';

  @override
  String get suspend => 'Suspender';

  @override
  String get suspendTip => 'La función de suspender necesita permisos de root y soporte de systemd.';

  @override
  String switchTo(Object val) {
    return 'Cambiar a $val';
  }

  @override
  String get sync => 'Sincronizar';

  @override
  String get syncTip => 'Puede que necesites reiniciar para que algunos cambios tengan efecto.';

  @override
  String get system => 'Sistema';

  @override
  String get tag => 'Etiqueta';

  @override
  String get temperature => 'Temperatura';

  @override
  String get termFontSizeTip => 'Este ajuste afectará el tamaño del terminal (ancho y alto). Puedes hacer zoom en la página del terminal para ajustar el tamaño de fuente de la sesión actual.';

  @override
  String get terminal => 'Terminal';

  @override
  String get test => 'Prueba';

  @override
  String get textScaler => 'Escalar texto';

  @override
  String get textScalerTip => '1.0 => 100% (tamaño original), solo afecta a ciertas fuentes en la página del servidor, no se recomienda modificar.';

  @override
  String get theme => 'Tema';

  @override
  String get time => 'Tiempo';

  @override
  String get times => 'Veces';

  @override
  String get total => 'Total';

  @override
  String get traffic => 'Tráfico';

  @override
  String get trySudo => 'Intentar con sudo';

  @override
  String get ttl => 'TTL';

  @override
  String get unknown => 'Desconocido';

  @override
  String get unkownConvertMode => 'Modo de conversión desconocido';

  @override
  String get update => 'Actualizar';

  @override
  String get updateIntervalEqual0 => 'Si configuras esto a 0, el estado del servidor no se refrescará automáticamente.\nY no se podrá calcular el uso de CPU.';

  @override
  String get updateServerStatusInterval => 'Intervalo de actualización del estado del servidor';

  @override
  String get upload => 'Subir';

  @override
  String get upsideDown => 'Invertir arriba por abajo';

  @override
  String get uptime => 'Tiempo de actividad';

  @override
  String get useCdn => 'Usando CDN';

  @override
  String get useCdnTip => 'Se recomienda a los usuarios no chinos utilizar CDN. ¿Le gustaría utilizarlo?';

  @override
  String get useNoPwd => 'Se usará sin contraseña';

  @override
  String get usePodmanByDefault => 'Usar Podman por defecto';

  @override
  String get used => 'Usado';

  @override
  String get view => 'Vista';

  @override
  String get viewErr => 'Ver error';

  @override
  String get virtKeyHelpClipboard => 'Si el terminal tiene caracteres seleccionados, entonces copiará los caracteres seleccionados al portapapeles, de lo contrario, pegará el contenido del portapapeles al terminal.';

  @override
  String get virtKeyHelpIME => 'Encender/apagar el teclado';

  @override
  String get virtKeyHelpSFTP => 'Abrir la ruta actual en SFTP.';

  @override
  String get waitConnection => 'Por favor, espera a que la conexión se establezca';

  @override
  String get wakeLock => 'Mantener despierto';

  @override
  String get watchNotPaired => 'No hay un Apple Watch emparejado';

  @override
  String get webdavSettingEmpty => 'La configuración de Webdav está vacía';

  @override
  String get whenOpenApp => 'Al abrir la App';

  @override
  String get wolTip => 'Después de configurar WOL (Wake-on-LAN), se envía una solicitud de WOL cada vez que se conecta el servidor.';

  @override
  String get write => 'Escribir';

  @override
  String get writeScriptFailTip => 'La escritura en el script falló, posiblemente por falta de permisos o porque el directorio no existe.';

  @override
  String get writeScriptTip => 'Después de conectarse al servidor, se escribirá un script en ~/.config/server_box para monitorear el estado del sistema. Puedes revisar el contenido del script.';
}
