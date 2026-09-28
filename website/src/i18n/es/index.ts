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
      'Instala desde App Store, GitHub Releases, F-Droid, OpenAPK o el CDN del proyecto.',
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
