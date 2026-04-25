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
    four: 'Captura de herramientas de ServerBox',
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
    items: {
      statusChart: 'Gráficas',
      sshTerminal: 'Terminal SSH',
      sftp: 'SFTP',
      docker: 'Docker',
      process: 'Procesos',
      systemd: 'Systemd',
      smart: 'S.M.A.R.T',
      gpu: 'GPU',
      sensors: 'Sensores',
      push: 'Alertas',
      homeWidget: 'Widget',
      watchos: 'watchOS',
    },
  },
  download: {
    title: 'Cada plataforma, cada fuente.',
    subtitle:
      'Elige el canal adecuado para tu dispositivo. iOS usa App Store; macOS usa App Store o Homebrew; Android, Linux y Windows también tienen paquetes directos.',
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
