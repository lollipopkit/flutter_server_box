import type { Translation } from '../i18n-types.js'

const es: Translation = {
  meta: {
    lang: 'es',
    title: 'ServerBox — Estado de servidores, SSH y operaciones en una app Flutter',
    description:
      'ServerBox monitoriza servidores Linux, Unix y Windows con gráficas, terminal SSH, SFTP, Docker, procesos, systemd, S.M.A.R.T, notificaciones, widgets y watchOS.',
  },
  nav: {
    features: 'Funciones',
    capabilities: 'Capacidades',
    download: 'Descargar',
    docs: 'Documentación',
    themes: 'Temas',
    plugins: 'Plugins',
    monitor: 'Monitor',
    languageLabel: 'Idioma',
  },
  hero: {
    titlePrefix: 'Estado del servidor,',
    titleSuffix: 'en tu bolsillo.',
    subtitle:
      'ServerBox reúne gráficas, terminal SSH, SFTP, Docker, control de procesos, systemd, S.M.A.R.T, alertas, widgets y watchOS en una sola app Flutter.',
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
  gallery: {
    title: 'Cada pantalla, en cada dispositivo.',
    subtitle:
      '31 capturas de iPhone, iPad y macOS, plegadas para que la página siga siendo ligera hasta que las pidas.',
    count: '{count} capturas',
  },
  features: {
    title: 'Un espacio compacto para el mantenimiento diario.',
    subtitle:
      'Una superficie operativa enfocada: cada bloque corresponde a un flujo real de mantenimiento.',
    charts: {
      title: 'Gráficas de estado',
      description:
        'Controla CPU, memoria, sensores, GPU, red, disco y salud del host desde gráficas móviles densas.',
    },
    workspace: {
      title: 'Espacio multiplataforma',
      description:
        'Usa ServerBox en iOS, Android, macOS, Linux y Windows con la misma interfaz Flutter.',
    },
    terminal: {
      title: 'Terminal SSH y SFTP',
      description:
        'Abre sesiones de terminal y archivos desde una tarjeta de servidor, con dartssh2 y xterm.dart.',
    },
    native: {
      title: 'Integraciones nativas',
      description:
        'Autenticación biométrica, notificaciones, widgets y watchOS mantienen cerca el contexto del servidor.',
    },
    platforms: {
      title: 'Docker, procesos, systemd',
      description:
        'Inspecciona contenedores, procesos y servicios sin salir del flujo de monitorización.',
    },
  },
  capabilities: {
    title: 'Todas las herramientas. Una app.',
    subtitle:
      'ServerBox mantiene terminal, transferencia de archivos, servicios, salud de hardware y alertas en el mismo flujo.',
    installIosPrompt: '# iOS',
    installReleasePrompt: '# Android, Linux y Windows',
  },
  themes: {
    title: 'A tu manera.',
    subtitle:
      'Los temas oficiales de ServerBox, los mismos que ofrece la tienda de temas de la app. Instálalos desde Ajustes → Apariencia → Tienda de temas, o descarga un paquete y elige Instalar tema → Archivo.',
    empty:
      'Todavía no hay temas oficiales. Un tema es una carpeta con un manifest.toml: colores claros y oscuros, estilos de componentes, iconos, fondo y pantalla de inicio. La guía explica cómo crear uno y publicarlo en la tienda.',
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
      'Todos los temas oficiales de ServerBox, dibujados como los dibuja la app: colores, componentes, iconos y pantalla de inicio. Instálalos desde la tienda de la app o descarga el paquete.',
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
      'En la app, abre Ajustes → Apariencia → Tienda de temas y elige {name}. O descarga el paquete y elige Instalar tema → Archivo.',
    base: 'Normal',
    hovered: 'Al pasar',
    pressed: 'Pulsado',
    disabled: 'Desactivado',
    loadFailed: 'No se pudo cargar la vista previa de este tema.',
    retry: 'Reintentar',
    previewNote:
      'Las vistas previas muestran los iconos y colores del tema; el resto de la interfaz es orientativo.',
  },
  plugins: {
    title: 'Plugins.',
    subtitle:
      'Los plugins oficiales de ServerBox, instalados desde la tienda de plugins de la app.',
    empty: 'Todavía no hay plugins oficiales.',
    download: 'Descargar',
  },
  download: {
    title: 'Cada plataforma, cada fuente.',
    subtitle:
      'Elige una fuente de confianza para tu dispositivo. En iOS, la aplicación está disponible en App Store. En macOS, la versión de App Store solo es compatible con Apple silicon; los usuarios de Intel pueden instalarla desde GitHub Releases o Homebrew. También hay descargas directas para Android, Linux y Windows.',
    copied: 'Comando copiado',
    copyPrompt: 'Copia este comando:',
    note:
      'Descarga solo desde fuentes de confianza. Para notificaciones del servidor, widgets y monitorización companion, instala ServerBoxMonitor en tus servidores.',
  },
  cta: {
    title: 'ServerBox es gratis y open source bajo AGPLv3.',
    subtitle:
      'Instala desde App Store, GitHub Releases, F-Droid u OpenAPK.',
    appStoreAction: 'Abrir App Store',
    githubAction: 'Descargar desde GitHub Releases',
  },
  footer: {
    features: 'Funciones',
    capabilities: 'Capacidades',
    releases: 'Versiones',
  },
  monitor: {
    meta: {
      title: 'ServerBox Monitor — el agente que vigila tu servidor',
      description: 'ServerBox Monitor se ejecuta en tu servidor: guarda el historial del estado, envía alertas a tu teléfono, mantiene al día los widgets y la app de Watch, y sirve un panel web.',
    },
    nav: {
      why: 'Por qué un agente',
      panel: 'Panel web',
      alerts: 'Alertas',
      access: 'Acceso',
      install: 'Instalar',
    },
    hero: {
      eyebrow: 'ServerBox Monitor',
      title: 'Una muestra cada 7 segundos. La guarda. Se lo dice a tu teléfono.',
      subtitle: 'Un pequeño agente en Rust que se ejecuta en tu servidor. Guarda el historial en SQLite, envía alertas, mantiene al día los widgets de ServerBox y la app de Watch, y sirve un panel web — y la app lo alcanza sin SSH.',
      installLabel: 'Instalar en Linux con systemd u OpenRC',
      installNote: 'Se ejecuta con tu propia cuenta, no como root.',
      copy: 'Copiar',
      copied: 'Copiado',
      guide: 'Guía de configuración',
      terminalLabel: 'El agente instalándose y después tomando muestras',
      installed: 'instalado como servicio systemctl --user',
      listening: 'escuchando en 0.0.0.0:3770',
      sampled: 'muestra',
      cadence: 'cada 7 s — interval_seconds, por defecto',
      pushLabel: 'Alertas del agente en la pantalla de bloqueo de un iPhone',
      widgetLabel: 'Un widget de ServerBox alimentado por el agente',
    },
    keywords: {
      history: 'Historial en SQLite',
      push: 'Alertas push',
      panel: 'Panel web',
      roles: 'Roles y permisos',
      docker: 'Docker',
    },
    why: {
      title: 'Lo que el agente añade a SSH',
      subtitle: 'Para mirar un servidor basta con SSH. El agente sigue mirando cuando tú no lo haces.',
      history: {
        title: 'Historial de antes de abrir la app',
        description: 'El agente toma muestras por su cuenta y guarda el resultado, así que las gráficas muestran la noche en que dormías. Tú decides cuánto se conserva.',
      },
      alerts: {
        title: 'Alertas en tu teléfono',
        description: 'Reglas sobre CPU, memoria, swap, disco, red y temperatura, enviadas a iOS, Bark, ServerChan o cualquier webhook.',
      },
      widgets: {
        title: 'Widgets y Watch siempre al día',
        description: 'Los widgets y la app de Watch leen del agente, así que se actualizan con ServerBox cerrado.',
      },
      reach: {
        title: 'Sin abrir SSH',
        description: 'La app habla con el agente por HTTP. Úsalo donde SSH no llega, o junto a SSH en el mismo servidor.',
      },
    },
    panel: {
      title: 'Un panel web en cada agente',
      subtitle: 'Cada agente sirve su propio panel en el puerto 3770. O publica el panel una sola vez e inicia sesión en varios agentes desde una misma página.',
      dashboard: {
        title: 'Gráficas en vivo e historial guardado',
        description: 'CPU, memoria, discos, red, GPU y sensores, en vivo y a lo largo de lo que el agente guardó — con la salida de tus propios comandos al lado.',
      },
      terminal: {
        title: 'Terminal y archivos en el navegador',
        description: 'Una terminal que sigue funcionando al cerrar la pestaña y continúa donde estaba, y un explorador limitado a los directorios que indiques.',
      },
      machine: {
        title: 'Las partes de la máquina que se mueven',
        description: 'Contenedores en Docker o Podman, servicios, procesos, cron, el firewall y los usuarios del sistema. El agente construye y comprueba cada acción; el panel solo la pide.',
      },
      reach: {
        title: 'Lo que está junto al servidor',
        description: 'Escritorios RDP y VNC, BMC por Redfish y máquinas virtuales en Proxmox VE o libvirt, a través del agente.',
      },
    },
    alerts: {
      title: 'Alertas donde ya miras',
      subtitle: 'Una regla es una métrica y un umbral. Cuando salta, todos los canales que configuraste se enteran.',
      rule: 'Una regla de config.toml',
      push: 'Notificación de iOS',
      webhook: 'Un webhook hacia una app de chat',
      widget: 'Widget de pantalla de inicio',
    },
    access: {
      title: 'Tú decides qué puede hacer cada cuenta',
      subtitle: 'Leer el estado está abierto a todas las cuentas. Lo demás se concede, y se puede retirar.',
      roles: {
        title: 'Roles y permisos',
        description: 'Shell, archivos, reenvío de puertos y virtualización son permisos que un admin concede a un rol. Retira uno y lo que lo usaba se cierra.',
      },
      transport: {
        title: 'TLS para todo lo que no sea leer',
        description: 'Los comandos, los archivos y los reenvíos necesitan TLS o una petición desde el mismo equipo. TLS integrado, un proxy inverso o un túnel sirven.',
      },
      account: {
        title: 'Se ejecuta como tú',
        description: 'El instalador ejecuta el agente con tu propia cuenta, así que la shell que da es la de esa cuenta, no la de root.',
      },
      audit: {
        title: 'Cada acceso queda registrado',
        description: 'Quién, cuándo, desde dónde, qué y cómo terminó. Nunca contraseñas ni claves.',
      },
    },
    install: {
      title: 'Instalar',
      subtitle: 'Tres pasos de un servidor nuevo a ver su estado en tu teléfono.',
      step1: {
        title: 'Instala el agente',
        description: 'El instalador elige systemd u OpenRC y descarga la última versión. Añade --permissions read para empezar con un admin sin permisos.',
      },
      step2: {
        title: 'Inicia sesión',
        description: 'El primer arranque crea la cuenta admin con una contraseña aleatoria, guardada junto a la base de datos en initial-admin-credentials.txt. Cámbiala y luego borra el archivo:',
      },
      step3: {
        title: 'Añádelo a ServerBox',
        description: 'En la app, añade el servidor como agente Monitor con su dirección y cuenta. O abre el panel en el puerto 3770.',
      },
      tabs: {
        systemd: 'systemd',
        openrc: 'OpenRC (Alpine)',
        docker: 'Docker',
      },
      dockerNote: 'Se compila desde este repositorio.',
    },
    cta: {
      title: 'Gratis y de código abierto, como la app.',
      subtitle: 'El agente vive en el repositorio de ServerBox, con la misma licencia.',
      app: 'Consigue ServerBox',
      source: 'Código del agente',
    },
  },
}

export default es
