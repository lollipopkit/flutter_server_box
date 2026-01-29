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

### Implementación Específica por Plataforma

**iOS:**
- Teclado personalizado basado en UIView
- Conmutable con un botón de teclado
- Mostrar/ocultar automáticamente basado en el enfoque

**Android:**
- Método de entrada personalizado
- Integrado con el teclado del sistema
- Botones de acción rápida

### Botones del Teclado

| Botón | Acción |
|--------|--------|
| **Conmutar** | Mostrar/ocultar teclado del sistema |
| **Ctrl** | Enviar modificador Ctrl |
| **Alt** | Enviar modificador Alt |
| **SFTP** | Abrir directorio actual |
| **Portapapeles** | Copiar/Pegar sensible al contexto |
| **Snippets** | Ejecutar fragmento de código |

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

## Optimizaciones de Rendimiento

- **Dirty rectangle**: Solo redibujar las regiones cambiadas
- **Caché de líneas**: Cachear las líneas renderizadas
- **Desplazamiento perezoso (Lazy scrolling)**: Desplazamiento virtual para búferes largos
- **Actualizaciones por lotes**: Unificar múltiples escrituras
- **Compresión**: Comprimir el búfer de desplazamiento
- **Debouncing**: Antirrebote para entradas rápidas
