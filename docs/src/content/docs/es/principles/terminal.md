---
title: Implementación de la Terminal
description: Cómo funciona internamente la terminal SSH
---

La terminal SSH es una de las funciones más complejas, construida sobre un fork personalizado de xterm.dart.

## Resumen de la Arquitectura

```
┌─────────────────────────────────────────────┐
│          Capa de UI de la Terminal          │
│  - Gestión de pestañas                      │
│  - Teclado virtual                          │
│  - Selección de texto                       │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│           Emulador xterm.dart               │
│  - PTY (Pseudo Terminal)                    │
│  - Emulación VT100/ANSI                     │
│  - Motor de renderizado                     │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│            Capa de Cliente SSH              │
│  - Sesión SSH                               │
│  - Gestión de canales                       │
│  - Streaming de datos                       │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│             Servidor Remoto                 │
│  - Proceso de Shell                         │
│  - Ejecución de comandos                    │
└─────────────────────────────────────────────┘
```

## Ciclo de Vida de la Sesión de Terminal

### 1. Creación de la Sesión

```dart
Future<TerminalSession> createSession(Spi spi) async {
  // 1. Obtener cliente SSH
  final client = await genClient(spi);

  // 2. Crear PTY
  final pty = await client.openPty(
    term: 'xterm-256color',
    cols: 80,
    rows: 24,
  );

  // 3. Inicializar emulador de terminal
  final terminal = Terminal(
    backend: PtyBackend(pty),
  );

  // 4. Configurar manejador de cambio de tamaño
  terminal.onResize.listen((size) {
    pty.resize(size.cols, size.rows);
  });

  return TerminalSession(
    terminal: terminal,
    pty: pty,
    client: client,
  );
}
```

### 2. Emulación de Terminal

El fork de xterm.dart proporciona:

**Emulación VT100/ANSI:**
- Movimiento del cursor
- Colores (soporte para 256 colores)
- Atributos de texto (negrita, subrayado, etc.)
- Regiones de desplazamiento
- Búfer de pantalla alternativo

**Renderizado:**
- Renderizado basado en líneas
- Soporte para texto bidireccional
- Soporte para Unicode/emoji
- Redibujado optimizado

### 3. Flujo de Datos

```
Entrada del Usuario
    ↓
Teclado Virtual / Teclado Físico
    ↓
Emulador de Terminal (tecla → secuencia de escape)
    ↓
Canal SSH (envío)
    ↓
PTY Remoto
    ↓
Shell Remoto
    ↓
Salida del Comando
    ↓
Canal SSH (recepción)
    ↓
Emulador de Terminal (analizar códigos ANSI)
    ↓
Renderizado en Pantalla
```

## Sistema de Múltiples Pestañas

### Gestión de Pestañas

Las pestañas mantienen su estado durante la navegación:
- La conexión SSH se mantiene activa
- Se preserva el estado de la terminal
- Se mantiene el búfer de desplazamiento
- Se retiene el historial de entrada

## Teclado Virtual

El teclado virtual es un widget de Flutter mostrado sobre la terminal en todas
las plataformas (las teclas disponibles se definen en
`lib/data/model/ssh/virtual_key.dart`). En móvil se muestra junto al teclado del
sistema.

### Botones del Teclado

| Botón | Acción |
|--------|--------|
| **Esc / Tab / Home / End / PgUp / PgDn / flechas** | Enviar la tecla correspondiente |
| **Ctrl / Alt / Shift** | Alternar el modificador para la siguiente tecla |
| **IME** | Mostrar/ocultar el teclado del sistema |
| **Portapapeles** | Copiar/pegar según el contexto |
| **SFTP** | Abrir el directorio actual en el navegador SFTP |
| **Snippet** | Elegir y ejecutar un snippet |
| **Símbolos** | `/ \ _ + = - ( ) [ ] { } < >` y más |

El conjunto y el orden de teclas se pueden personalizar en los ajustes.

## Selección de Texto

1. **Pulsación larga**: Entrar en modo selección
2. **Arrastrar**: Extender la selección
3. **Soltar**: Copiar al portapapeles

## Fuente y Dimensiones

### Cálculo de Tamaño

```dart
class TerminalDimensions {
  static Size calculate(double fontSize, Size screenSize) {
    final charWidth = fontSize * 0.6;  // Relación de aspecto monoespaciada
    final charHeight = fontSize * 1.2;

    final cols = (screenSize.width / charWidth).floor();
    final rows = (screenSize.height / charHeight).floor();

    return Size(cols.toDouble(), rows.toDouble());
  }
}
```

### Pellizcar para Ampliar (Pinch-to-Zoom)

```dart
GestureDetector(
  onScaleStart: () => _baseFontSize = currentFontSize,
  onScaleUpdate: (details) {
    final newFontSize = _baseFontSize * details.scale;
    resize(newFontSize);
  },
)
```

## Esquema de Colores

- **Claro (Light)**: Fondo claro, texto oscuro
- **Oscuro (Dark)**: Fondo oscuro, texto claro
- **AMOLED**: Fondo negro puro

## Rendimiento

El fork de xterm.dart renderiza con un painter personalizado y solo repinta
cuando la terminal se actualiza; las escrituras de salida se almacenan en búfer
y se agrupan antes de pasarlas al emulador.

## Funciones Especiales

### Ejecución de Snippets

Al elegir un snippet, su contenido se pega en la terminal y se ejecuta con un retorno de carro.

### Acceso Rápido SFTP

La tecla virtual **SFTP** abre el directorio de trabajo actual en el navegador SFTP.

### Keep-Alive

Las conexiones se mantienen en la capa del protocolo SSH (ver
[Conexión SSH](/docs/principles/ssh/)), no inyectando bytes en la terminal.
