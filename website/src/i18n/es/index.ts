import type { Translation } from '../i18n-types.js'

const es: Translation = {
  meta: {
    lang: 'es',
    title: 'ServerBox — Monitorización de servidores, SSH y administración',
    description:
      'ServerBox ofrece gráficas de estado, terminal SSH, SFTP, Docker, gestión de procesos y systemd, monitorización S.M.A.R.T., notificaciones push, widgets y compatibilidad con watchOS para servidores Linux, Unix y Windows.',
  },
  nav: {
    features: 'Funciones',
    capabilities: 'Capacidades',
    download: 'Descargar',
    docs: 'Documentación',
    themes: 'Temas',
    os: 'ServerBox OS',
    beta: 'Beta',
    plugins: 'Plugins',
    languageLabel: 'Idioma',
  },
  hero: {
    titlePrefix: 'Estado del servidor,',
    titleSuffix: 'en tu bolsillo.',
    subtitle:
      'ServerBox reúne en una sola app gráficas de estado, terminal SSH, SFTP, Docker, gestión de procesos, systemd, monitorización S.M.A.R.T., notificaciones push, widgets y compatibilidad con watchOS.',
    primaryAction: 'Descargar ServerBox',
    secondaryAction: 'Ver funciones',
  },
  screenshots: {
    label: 'Capturas interactivas de ServerBox',
    one: 'Captura de vista general de ServerBox',
    two: 'Captura de gráficas de ServerBox',
    three: 'Captura del terminal de ServerBox',
    four: 'Captura del explorador de archivos de ServerBox',
  },
  features: {
    title: 'Todas las herramientas que necesitas para el mantenimiento diario de servidores, en un solo espacio.',
    subtitle:
      'Herramientas prácticas y directas: cada sección responde a una necesidad real de mantenimiento de servidores.',
    list: {
      title: 'Lista de servidores',
      description:
        'Consulta de un vistazo el estado de conexión y el uso de CPU, memoria, disco y red de cada servidor. Filtra por etiqueta o búscalos en el globo.',
    },
    charts: {
      title: 'Gráficos de estado',
      description:
        'Consulta en tiempo real gráficos de CPU, memoria, swap, discos, E/S de disco y red, además de datos de sensores, GPU y batería. También puedes ver el historial o seleccionar una métrica para consultar sus detalles.',
    },
    terminal: {
      title: 'Terminal SSH',
      description:
        'Una terminal completa que incluye teclas virtuales para el móvil y permite ejecutar htop, vim y más. Conéctate directamente, mediante un host intermedio o con ProxyCommand.',
    },
    files: {
      title: 'Archivos por SFTP',
      description:
        'Explora, sube, descarga y edita archivos directamente. Los archivos Markdown se abren con una vista previa renderizada.',
    },
    containers: {
      title: 'Docker y Podman',
      description:
        'Consulta los contenedores agrupados por proyecto de Compose y su uso de CPU, memoria y red. Inícialos, detenlos, reinícialos o elimínalos; consulta sus logs o abre una shell dentro. Las imágenes y los ajustes tienen sus propias pestañas.',
    },
    processes: {
      title: 'Procesos',
      description:
        'Consulta todos los procesos y su uso de CPU y memoria. Ordénalos como quieras, búscalos por nombre, usuario o PID y detenlos directamente desde la lista.',
    },
    services: {
      title: 'Servicios de systemd',
      description:
        'Las unidades de systemd que han fallado aparecen al principio de la lista. Reinicia una unidad o consulta sus logs con un toque.',
    },
    users: {
      title: 'Usuarios y grupos',
      description:
        'Consulta las cuentas del sistema y sus shells de inicio de sesión y permisos de sudo. Añade o elimina usuarios, y añade, edita o elimina grupos.',
    },
    agent: {
      title: 'Agente de IA',
      description:
        'Usa el asistente integrado en la app para gestionar tus servidores y conéctalo a los proveedores de modelos, servidores MCP y skills que prefieras.',
    },
    bench: {
      title: 'Benchmark',
      description:
        'Ejecuta Yet Another Bench Script para probar el disco, la red y la CPU de un servidor y guardar los resultados. El menú Más también ofrece accesos a snippets, escritorio remoto y virtualización.',
    },
    virt: {
      title: 'Virtualización',
      description:
        'Gestiona máquinas virtuales y contenedores en libvirt y Proxmox VE. Inicia o detén instancias, ajusta vCPU, memoria y discos, y abre sus consolas.',
    },
    themes: {
      title: 'Tienda de temas',
      description:
        'Temas oficiales con sus propios colores, fondos y pantallas de inicio, instalados desde la app. También puedes crear el tuyo.',
    },
  },
  capabilities: {
    title: 'Todas las herramientas. Una app.',
    subtitle:
      'ServerBox reúne conexiones de terminal, transferencia de archivos, consulta de servicios, monitorización de hardware y notificaciones del dispositivo en un mismo flujo de trabajo.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux y Windows',
  },
  os: {
    metaTitle: 'ServerBox OS — el lado servidor de ServerBox',
    metaDescription:
      'ServerBox OS es ServerBox Monitor en tu servidor: un escritorio en el navegador con una tienda de apps, almacenamiento, Agent mode, alertas y copias de seguridad. Instálalo en Linux o arráncalo como sistema completo.',
    heroTitle: 'ServerBox OS',
    tagline: 'El lado servidor de ServerBox.',
    subtitle:
      'ServerBox Monitor se ejecuta en el propio servidor. La app se conecta a él, y su escritorio integrado en el navegador permite administrar la máquina sin la app. Instálalo en un servidor Linux que ya tengas o arráncalo como sistema completo.',
    installAction: 'Instalar en Linux',
    images: 'Descargar imágenes',
    previewAction: 'Ver el recorrido',
    previewTitle: 'Míralo en marcha',
    previewSubtitle:
      'ServerBox OS está en beta. Un recorrido breve en un servidor real: el escritorio en el navegador, sus apps y el modo Agent en acción.',
    previewPlay: 'Reproducir el recorrido de ServerBox OS',
    previewYoutube: 'Ver en YouTube',
    featuresTitle: 'Qué se ejecuta en el servidor',
    featuresSubtitle: 'Un programa en la máquina, accesible desde el navegador o la app.',
    desk: {
      title: 'Un escritorio en el navegador',
      description:
        'Abre la dirección del servidor y cada función aparecerá como una app en una ventana: estado, archivos, terminal, contenedores, procesos y servicios.',
    },
    apps: {
      title: 'Tienda de apps',
      description:
        'Despliega más de 40 servicios autoalojados con Docker Compose, como Immich, Jellyfin, Gitea y Home Assistant, y añade apps para Tailscale, proxies inversos, kernels y modelos de IA locales.',
    },
    storage: {
      title: 'Almacenamiento y uso compartido',
      description:
        'Particiona, formatea y monta discos, crea matrices RAID y pools ZFS, consulta S.M.A.R.T. y comparte carpetas mediante SMB y NFS.',
    },
    agent: {
      title: 'Agent mode',
      description:
        'Asigna una tarea a un Agent de IA en la máquina. La planifica, pregunta antes de ejecutar comandos arriesgados, usa sudo solo si lo permites y accede a las apps desplegadas mediante MCP.',
    },
    alerts: {
      title: 'Alertas',
      description:
        'Las reglas sobre CPU, memoria, discos y servicios envían notificaciones a la app, Telegram, Discord, ntfy, Bark, ServerChan, correo electrónico o un webhook.',
    },
    backups: {
      title: 'Copias de seguridad',
      description:
        'La configuración se guarda en WebDAV, cifrada con age; los datos de los contenedores se guardan según un calendario en el disco que elijas.',
    },
    security: {
      title: 'Una contraseña',
      description:
        'Una cuenta inicia sesión con su contraseña. Cualquier acción que no sea de lectura requiere HTTPS, las credenciales se cifran en reposo y se auditan los inicios de sesión y las acciones de root.',
    },
    app: {
      title: 'Con la app',
      description:
        'Añade el servidor en ServerBox mediante HTTPS en lugar de SSH, o usa ambos: consulta el estado y el historial, y accede al terminal, los archivos, las tareas de Agent mode y las apps web desde el teléfono.',
    },
    installTitle: 'Dos formas de ejecutarlo',
    installSubtitle: 'En un servidor Linux que ya tengas o como sistema completo en una máquina dedicada.',
    linuxTitle: 'En un servidor Linux',
    promptUser: '# systemd: un servicio de usuario que se ejecuta con tu propia cuenta',
    promptOpenrc: '# OpenRC (Alpine): root escribe el servicio, que sigue ejecutándose con tu cuenta',
    promptRoot: '# Con cualquiera de los dos sistemas init, como root',
    linuxNote:
      'La cuenta con la que se ejecuta determina lo que puede hacer. Sustituye install por upgrade o uninstall para actualizarlo o eliminarlo.',
    copy: 'Copiar comando de instalación',
    imageTitle: 'Como sistema completo',
    stepWrite: 'Descarga una imagen y escríbela en una memoria USB (dd, Etcher, Ventoy), o móntala en una máquina virtual.',
    stepBoot:
      'Arráncalo. La consola muestra la dirección que debes abrir, la huella del certificado que debes comparar y dónde encontrar la primera contraseña.',
    stepInstall: 'sbm-install <disco> borra ese disco e instala el sistema en él.',
    liveNote:
      'Hasta que se instale, se ejecuta desde la memoria: la base de datos, las imágenes y los datos de las apps se pierden al reiniciar.',
    note: 'ServerBox OS es de código abierto bajo AGPLv3, igual que la app.',
    docs: 'Documentación de Monitor',
    appAction: 'Obtener la app',
  },
  themes: {
    title: 'A tu manera.',
    subtitle:
      'Los temas oficiales que se muestran aquí también están disponibles en la tienda de temas de la app. Instálalos desde Ajustes → Apariencia → Tienda de temas, o descarga un paquete y elige Instalar tema → Archivo.',
    empty:
      'Todavía no hay temas oficiales. Cada tema es una carpeta con un manifest.toml que incluye esquemas de color claro y oscuro, estilos de componentes, iconos, fondo y pantalla de inicio. La guía explica cómo crear un tema y enviarlo a la tienda.',
    note:
      'La app comprueba el SHA-256 de cada paquete de la tienda antes de instalarlo.',
    authoring: 'Crear un tema',
    download: 'Descargar .fsbt',
    source: 'Código',
    light: 'Claro',
    dark: 'Oscuro',
    search: 'Buscar temas',
    modeLabel: 'Modo',
    all: 'Todos',
    sortLabel: 'Ordenar',
    sortName: 'Nombre',
    sortUpdated: 'Actualizados recientemente',
    noMatch: 'Ningún tema coincide. Prueba con otro nombre u otro modo.',
    storeTitle: 'Tienda de temas',
    storeSubtitle:
      'Explora todos los temas oficiales de ServerBox tal como se muestran en la app, con sus colores, componentes, iconos y pantallas de inicio. Instala un tema desde la app o descarga su paquete.',
    browse: 'Abrir la tienda de temas',
    back: 'Todos los temas',
    details: 'Detalles',
    icons: 'Iconos',
    tabIcons: 'Pestañas y su estado seleccionado',
    navIcons: 'Símbolos',
    palette: 'Paleta',
    components: 'Componentes',
    splash: 'Pantalla de inicio',
    install: 'Instalar',
    installSteps:
      'En la app, abre “Ajustes → Apariencia → Tienda de temas” y selecciona {name}. También puedes descargar un paquete y elegir “Instalar tema → Archivo”.',
    base: 'Normal',
    hovered: 'Al pasar',
    pressed: 'Pulsado',
    disabled: 'Desactivado',
    loadFailed: 'No se pudo cargar la vista previa de este tema.',
    retry: 'Reintentar',
    iconPacks: 'Paquetes de iconos',
    iconPacksSubtitle:
      'Los paquetes de iconos se eligen por separado y funcionan con cualquier tema. Instálalos desde “Ajustes → Apariencia → Tienda de temas → Paquetes de iconos”.',
  },
  plugins: {
    title: 'Amplía ServerBox',
    subtitle:
      'Instala plugins oficiales de ServerBox para añadir funciones a la app.',
    empty: 'Todavía no hay plugins oficiales.',
    download: 'Descargar',
  },
  download: {
    title: 'Varias plataformas y opciones de descarga.',
    subtitle:
      'Elige una fuente de descarga de confianza. Descarga la app de iOS desde App Store o consigue un .ipa sin firmar en GitHub Releases y fírmalo por tu cuenta. La app de macOS es compatible con Apple silicon e Intel y está disponible en GitHub Releases y Homebrew. Los instaladores para Android, Linux y Windows se pueden descargar directamente.',
    copied: 'Comando copiado',
    copyPrompt: 'Copia este comando:',
    note:
      'Descarga paquetes solo de fuentes de confianza. Para usar notificaciones push del servidor, datos para widgets y monitorización independiente, instala ServerBox OS en tus servidores.',
  },
  cta: {
    title: 'ServerBox es gratis y open source bajo AGPLv3.',
    subtitle:
      'Consigue ServerBox en App Store, GitHub Releases, F-Droid u OpenAPK.',
    appStoreAction: 'Abrir App Store',
    githubAction: 'Descargar desde GitHub Releases',
  },
  footer: {
    features: 'Funciones',
    capabilities: 'Capacidades',
    releases: 'Versiones',
  },
}

export default es
