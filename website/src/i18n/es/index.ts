import type { Translation } from '../i18n-types.js'

const es: Translation = {
  meta: {
    lang: 'es',
    title: 'ServerBox — Monitorización de servidores, SSH y operaciones en una app',
    description:
      'Administra servidores Linux, Unix y Windows con gráficas en vivo, terminal SSH táctil, SFTP, Docker, systemd, S.M.A.R.T., widgets y agente de IA.',
  },
  nav: {
    features: 'Funciones',
    capabilities: 'Capacidades',
    download: 'Descargar',
    docs: 'Docs',
    themes: 'Temas',
    os: 'ServerBox OS',
    beta: 'Beta',
    plugins: 'Plugins',
    otherApps: 'Más',
    signIn: 'Iniciar sesión',
    languageLabel: 'Idioma',
  },
  hero: {
    titlePrefix: 'Todos tus servidores,',
    titleSuffix: 'en tu bolsillo.',
    subtitle:
      'Telemetría en vivo, terminal SSH pensada para pantallas táctiles, SFTP, contenedores y operaciones asistidas por IA en un espacio nativo rápido para móvil y escritorio.',
    primaryAction: 'Descargar',
    secondaryAction: 'Explorar funciones',
  },
  screenshots: {
    label: 'Capturas interactivas de ServerBox',
    one: 'Captura de vista general de ServerBox',
    two: 'Captura de gráficas de ServerBox',
    three: 'Captura del terminal de ServerBox',
    four: 'Captura del explorador de archivos de ServerBox',
  },
  features: {
    title: 'Diseñado para operaciones reales.',
    subtitle:
      'Resuelve revisiones rutinarias y urgencias sin necesidad de abrir el portátil.',
    list: {
      title: 'Vista general',
      description:
        'Supervisa al instante el estado y uso de CPU, memoria, disco y red de cada nodo. Filtra por etiquetas o ubícalos en el globo 3D.',
    },
    charts: {
      title: 'Telemetría en vivo',
      description:
        'Gráficas en tiempo real e históricas de CPU, memoria, swap, E/S de disco, red, GPU, sensores y salud S.M.A.R.T.',
    },
    terminal: {
      title: 'Terminal SSH táctil',
      description:
        'Teclas virtuales dedicadas para manejar vim, tmux y htop con fluidez desde el móvil. Soporte nativo para jump hosts y ProxyCommand.',
    },
    files: {
      title: 'Gestor SFTP',
      description:
        'Explora, transfiere y edita archivos remotos al vuelo con vista previa renderizada para Markdown.',
    },
    containers: {
      title: 'Docker & Podman',
      description:
        'Contenedores agrupados por proyecto Compose con métricas en vivo, reinicio en un toque, logs en tiempo real y shell integrada.',
    },
    processes: {
      title: 'Inspector de procesos',
      description:
        'Ordena por CPU o memoria, filtra por nombre, usuario o PID y detén al instante procesos descontrolados.',
    },
    services: {
      title: 'Servicios systemd',
      description:
        'Las unidades con fallos se fijan automáticamente arriba para revisar sus logs y reiniciarlas con un solo toque.',
    },
    users: {
      title: 'Usuarios y grupos',
      description:
        'Audita cuentas del sistema, shells de inicio y permisos sudo. Gestiona usuarios y grupos sin memorizar banderas de CLI.',
    },
    agent: {
      title: 'Agente de IA',
      description:
        'Conecta tus proveedores LLM, servidores MCP y skills para delegar diagnósticos y tareas de mantenimiento.',
    },
    bench: {
      title: 'Benchmark en un toque',
      description:
        'Ejecuta YABS para medir disco, red y CPU, archiva los resultados y accede rápido a snippets y escritorio remoto.',
    },
    virt: {
      title: 'Virtualización',
      description:
        'Controla máquinas virtuales y contenedores en Proxmox VE y libvirt: encendido, vCPU, memoria, discos y consola.',
    },
    themes: {
      title: 'Tienda de temas',
      description:
        'Personaliza colores, iconos, fondos y pantalla de inicio desde la tienda integrada o diseña tu propio tema.',
    },
  },
  capabilities: {
    title: 'Un único flujo de trabajo nativo.',
    subtitle:
      'Olvídate de saltar entre clientes SSH, gestores SFTP y paneles de monitorización.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux y Windows',
  },
  os: {
    metaTitle: 'ServerBox OS (antes ServerBox Monitor) — El compañero de servidor para ServerBox',
    metaDescription:
      'ServerBox OS (antes ServerBox Monitor) lleva a tu servidor un escritorio en el navegador, más de 40 apps Docker en un clic, almacenamiento ZFS/RAID, modo Agent de IA, alertas y copias cifradas.',
    heroTitle: 'ServerBox OS',
    formerlyMonitor: 'Antes ServerBox Monitor',
    navPreview: 'Demo',
    navInstall: 'Instalar',
    navApp: 'App ServerBox',
    tagline: 'Tu servidor, en el navegador y en la app.',
    subtitle:
      'Un demonio ligero que dota a cualquier servidor Linux de un escritorio completo en el navegador, más de 40 apps autoalojadas y sincronización HTTPS instantánea con ServerBox — o arranca como sistema operativo dedicado.',
    monitorNote:
      'ServerBox OS es la evolución de ServerBox Monitor (server_box_monitor). Las instalaciones existentes de Monitor se actualizan en el acto con el mismo comando y siguen ofreciendo alertas push, widgets, watchOS y gráficas históricas para la app.',
    exploreAction: 'Explorar ServerBox OS',
    installAction: 'Instalar en Linux',
    images: 'Descargar imágenes',
    previewAction: 'Ver demostración',
    previewTitle: 'Míralo en acción',
    previewSubtitle:
      'Demostración en un servidor real: escritorio multiventana en el navegador, tienda de apps y modo Agent de IA.',
    previewPlay: 'Reproducir recorrido de ServerBox OS',
    previewYoutube: 'Ver en YouTube',
    featuresTitle: 'Todo del lado del servidor',
    featuresSubtitle: 'Un único binario en el host, accesible desde cualquier navegador o desde la app ServerBox.',
    desk: {
      title: 'Escritorio en el navegador',
      description:
        'Abre la dirección del servidor y accede a estado, archivos, terminal, contenedores, procesos y servicios en ventanas independientes.',
    },
    apps: {
      title: 'Tienda de apps en un clic',
      description:
        'Despliega más de 40 servicios con Docker Compose (Immich, Jellyfin, Gitea, Home Assistant) además de Tailscale, proxies inversos y modelos de IA locales.',
    },
    storage: {
      title: 'Almacenamiento y NAS',
      description:
        'Particiona y monta discos, crea matrices RAID y pools ZFS, supervisa S.M.A.R.T. y comparte carpetas por SMB y NFS.',
    },
    agent: {
      title: 'Modo Agent autónomo',
      description:
        'Encarga tareas al agente de IA: planifica pasos, pide confirmación antes de comandos críticos, usa sudo bajo tu permiso y se integra vía MCP.',
    },
    alerts: {
      title: 'Alertas multicanal',
      description:
        'Reglas de CPU, memoria, discos y servicios con aviso inmediato a la app, Telegram, Discord, ntfy, Bark, ServerChan, correo o webhook.',
    },
    backups: {
      title: 'Copias de seguridad cifradas',
      description:
        'Configuración respaldada en WebDAV con cifrado age; datos de contenedores respaldados según calendario en el disco elegido.',
    },
    security: {
      title: 'Cifrado y auditado',
      description:
        'Cuenta única, HTTPS obligatorio para modificaciones, credenciales cifradas en reposo y registro de auditoría completo.',
    },
    app: {
      title: 'Sincronización con la app',
      description:
        'Conecta el servidor por HTTPS en ServerBox junto con SSH o en su lugar: gráficas históricas, alertas push, widgets y tareas Agent.',
    },
    installTitle: 'Dos formas de desplegarlo',
    installSubtitle: 'Como servicio en tu distribución Linux actual o arrancando la imagen de sistema dedicado.',
    linuxTitle: 'En un servidor Linux existente',
    promptUser: '# systemd: servicio de usuario bajo tu propia cuenta',
    promptOpenrc: '# OpenRC (Alpine): registrado por root, ejecutado con tu usuario',
    promptRoot: '# systemd u OpenRC: servicio global como root',
    linuxNote:
      'Los permisos dependen de la cuenta con que se ejecute. Cambia install por upgrade o uninstall cuando quieras.',
    copy: 'Copiar comando',
    imageTitle: 'Como sistema operativo completo',
    stepWrite: 'Graba una imagen en un USB (dd, Etcher, Ventoy) o móntala en una máquina virtual.',
    stepBoot:
      'Arranca el equipo: la consola mostrará la URL web, la huella TLS y la ubicación de la contraseña inicial.',
    stepInstall: 'Ejecuta sbm-install <disco> para instalar el sistema de forma permanente.',
    liveNote:
      'Antes de instalar en disco, sbOS funciona en modo Live en memoria RAM y se reinicia al apagar.',
    note: 'ServerBox OS es código abierto bajo AGPLv3, igual que la app.',
    docs: 'Docs de Monitor',
    appAction: 'Obtener la app',
  },
  themes: {
    title: 'A tu estilo.',
    subtitle:
      'Previsualiza en vivo los temas oficiales aquí abajo. Instálalos desde Ajustes → Apariencia → Tienda de temas o importa un archivo .fsbt.',
    empty:
      'Aún no hay temas oficiales. Consulta la guía para crear y enviar el tuyo.',
    note:
      'Cada paquete de la tienda se verifica con SHA-256 antes de instalarse.',
    authoring: 'Guía de temas',
    download: 'Descargar .fsbt',
    source: 'Código',
    light: 'Claro',
    dark: 'Oscuro',
    search: 'Buscar temas o iconos',
    modeLabel: 'Modo',
    all: 'Todos',
    sortLabel: 'Ordenar',
    sortName: 'Nombre',
    sortUpdated: 'Recientes',
    noMatch: 'Ningún tema coincide. Prueba con otro término o modo.',
    storeTitle: 'Tienda de temas',
    storeSubtitle:
      'Explora todos los temas y paquetes de iconos oficiales renderizados en vivo con sus colores, componentes e iconos reales.',
    browse: 'Abrir Tienda de temas',
    back: 'Todos los temas',
    details: 'Detalles',
    icons: 'Iconos',
    tabIcons: 'Pestañas y estado activo',
    navIcons: 'Símbolos de navegación',
    palette: 'Paleta de colores',
    components: 'Componentes',
    splash: 'Pantalla de inicio',
    install: 'Instalación',
    installSteps:
      'En la app, abre “Ajustes → Apariencia → Tienda de temas” y elige {name}, o descarga el archivo .fsbt y selecciona “Instalar tema → Archivo”.',
    base: 'Normal',
    hovered: 'Al pasar',
    pressed: 'Pulsado',
    disabled: 'Desactivado',
    loadFailed: 'No se pudo cargar la vista previa del tema.',
    retry: 'Reintentar',
    iconPacks: 'Paquetes de iconos',
    iconPacksSubtitle:
      'Combina cualquier paquete de iconos con tu tema actual desde “Ajustes → Apariencia → Tienda de temas → Paquetes de iconos”.',
  },
  plugins: {
    title: 'Amplía ServerBox',
    subtitle:
      'Añade más funciones con los plugins oficiales.',
    empty: 'Aún no hay plugins oficiales.',
    download: 'Descargar',
  },
  download: {
    title: 'Nativo en cada plataforma.',
    subtitle:
      'Elige tu sistema operativo y tu fuente de descarga preferida.',
    copied: 'Comando copiado',
    copyPrompt: 'Copia este comando:',
    note:
      'Consejo: instala ServerBox OS en tus servidores para habilitar notificaciones push, widgets y gráficas históricas.',
  },
  cta: {
    title: 'Gratis y open source bajo AGPLv3.',
    subtitle:
      'Revisa el código en GitHub o descarga la última versión para tu dispositivo.',
    appStoreAction: 'App Store',
    githubAction: 'GitHub Releases',
  },
  pride: {
    badge: 'LGBTQ+ Friendly',
    title: 'Creado con Orgullo.',
    description:
      'ServerBox apoya con orgullo a la comunidad LGBTQ+. El tema oficial Pride en la Tienda de temas incluye las variantes Rainbow, Trans y Nonbinary.',
    rainbow: 'Rainbow',
    trans: 'Trans',
    nonbinary: 'Nonbinary',
  },
  otherApps: {
    title: 'Más servicios y apps.',
    subtitle:
      'Servicios en la nube y aplicaciones nativas creadas con el mismo enfoque en rapidez y diseño limpio.',
    servicesHeading: 'Servicios',
    appsHeading: 'Apps',
    llmapi: {
      title: 'LLM API',
      description:
        'Pasarela API unificada para los principales modelos LLM, lista para el agente de ServerBox, LLMBox o tus propias herramientas.',
    },
    uptimer: {
      title: 'Uptimer',
      description:
        'Monitorización ligera de disponibilidad y páginas de estado para tus webs, APIs y servidores con alertas al instante.',
    },
    llmbox: {
      title: 'LLMBox',
      tag: 'iOS · Android · macOS · Linux · Windows',
      description:
        'Cliente nativo y rápido para la API de OpenAI y modelos compatibles, con historial local, llamadas a herramientas y endpoints personalizados.',
      action: 'GitHub',
    },
    mfuse: {
      title: 'MFuse',
      tag: 'macOS · File Provider',
      description:
        'Monta SFTP, S3, WebDAV y almacenamiento remoto directamente en el Finder de macOS mediante File Provider nativo, sin extensiones de kernel.',
      action: 'mfuse.lollipopkit.com',
    },
  },
  footer: {
    features: 'Funciones',
    capabilities: 'Capacidades',
    releases: 'Versiones',
  },
}

export default es
