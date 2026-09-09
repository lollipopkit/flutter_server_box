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
  plugins: {
    metaTitle: 'Plugins de ServerBox — amplía la app sin esperar una versión',
    metaDescription:
      'Los plugins añaden a ServerBox páginas, tarjetas y lecturas de estado. Cada uno es un módulo pequeño y aislado que declara los permisos que necesita, y la app verifica cada paquete que descarga.',
    title: 'Amplía la app sin esperar una versión.',
    subtitle:
      'Un plugin añade una página, una tarjeta, una pestaña de inicio o lecturas de estado. Es un módulo pequeño, corre aislado y solo puede hacer lo que su manifiesto pidió y tú aceptaste.',
    how: {
      sandbox: {
        title: 'Corre aislado',
        description:
          'Un plugin es JavaScript en un runtime aislado: sin sistema de archivos, sin red y sin conexión propia a tus servidores. Todo lo que hace, se lo pide a la app.',
      },
      permissions: {
        title: 'Pide antes de actuar',
        description:
          'Su manifiesto nombra lo que necesita — ejecutar un comando, alcanzar un host, ver tu lista de servidores — y esa lista es la que aceptas al instalarlo. Una llamada no concedida falla en el acto.',
      },
      anyRepo: {
        title: 'Cualquier repositorio, bytes verificados',
        description:
          'La app instala desde cualquier dirección de repositorio por HTTPS — una petición para su árbol más reciente — y comprueba cada paquete con la suma que indicó su archivo. Un paquete sin suma se rechaza salvo que lo autorices.',
      },
    },
    listTitle: 'En el repositorio oficial',
    listSubtitle:
      '{count} plugins, desarrollados en este repositorio y publicados aparte de la app.',
    asks: 'Pide',
    asksNothing: 'nada',
    appearsIn: 'Aparece en',
    languages: 'Idiomas',
    source: 'Código',
    install: {
      title: 'Instalar uno',
      stepOne: 'En la app, abre Ajustes → Plugins → Tienda de plugins.',
      stepTwo:
        'Elige un plugin y pulsa Instalar. El repositorio oficial ya está en la lista.',
      stepThree:
        'Lee lo que pide y acepta. Antes de ejecutar nada, la app comprueba la descarga con la suma del repositorio.',
      address:
        'La dirección del repositorio, si la quitaste y quieres volver a añadirla:',
      copy: 'Copiar dirección',
    },
    write: {
      title: 'Escribir uno',
      description:
        'Un plugin es un único módulo ES en TypeScript o JavaScript, probado contra un host simulado con bun test — sin app y sin paso de compilación. En escritorio puedes apuntar la app a su carpeta: editar y reiniciar es todo el ciclo.',
      sdk: 'SDK',
      examples: 'Plugins de ejemplo',
      repository: 'Repositorio oficial',
    },
    home: 'Inicio',
  },
  footer: {
    features: 'Funciones',
    capabilities: 'Capacidades',
    releases: 'Versiones',
  },
}

export default es
