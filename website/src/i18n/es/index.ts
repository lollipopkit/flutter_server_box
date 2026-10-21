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
  features: {
    title: 'Un espacio compacto para el mantenimiento diario.',
    subtitle:
      'Una superficie operativa enfocada: cada bloque corresponde a un flujo real de mantenimiento.',
    list: {
      title: 'Lista de servidores',
      description:
        'Consulta de un vistazo el estado de conexión y el uso de CPU, memoria, disco y red de cada servidor. Filtra por etiqueta o búscalos en el globo.',
    },
    charts: {
      title: 'Gráficos de estado',
      description:
        'Gráficos en tiempo real de CPU, memoria, swap, discos, E/S de disco y red, además de sensores, GPU y baterías. Consulta el historial o abre una métrica para ver sus detalles.',
    },
    terminal: {
      title: 'Terminal SSH',
      description:
        'Una terminal completa con teclas virtuales en el móvil, lista para htop, vim y mucho más. Conéctate directamente, mediante un host de salto o con un ProxyCommand.',
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
        'Todos los procesos con su CPU y memoria, ordenados como quieras y buscables por nombre, usuario o PID. Detén uno desde la lista.',
    },
    services: {
      title: 'Servicios de systemd',
      description:
        'Primero las unidades fallidas, luego el resto. Reinicia una unidad o lee sus logs con un toque.',
    },
    users: {
      title: 'Usuarios y grupos',
      description:
        'Consulta las cuentas del sistema con la shell de inicio de sesión y el acceso a sudo destacados. Crea o elimina usuarios, y crea, edita o elimina grupos.',
    },
    agent: {
      title: 'Agente de IA',
      description:
        'Un asistente dentro de la app que conoce tus servidores, con los proveedores de modelos, servidores MCP y skills que elijas.',
    },
    bench: {
      title: 'Benchmark',
      description:
        'Ejecuta Yet Another Bench Script para medir el disco, la red y la CPU de un servidor, y guarda los resultados. El menú Más también permite abrir snippets, el escritorio remoto y la virtualización.',
    },
    virt: {
      title: 'Virtualización',
      description:
        'Máquinas virtuales y contenedores en libvirt y Proxmox VE: inícialos y detenlos, cambia vCPU, memoria y discos, y abre sus consolas.',
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
    iconPacks: 'Paquetes de iconos',
    iconPacksSubtitle:
      'Iconos que se eligen aparte del tema y se dibujan sobre el que esté en uso. Instálalos en la app desde Ajustes → Apariencia → Tienda de temas → Paquetes de iconos.',
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
      'Elige una fuente de confianza para tu dispositivo. iOS está en App Store, o como .ipa sin firmar en GitHub Releases para que lo firmes tú. Las versiones de macOS para Apple silicon e Intel están en GitHub Releases y Homebrew. Android, Linux y Windows tienen descargas directas.',
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
}

export default es
