---
title: Descripción General de la Arquitectura
description: Arquitectura de alto nivel de la aplicación
---

Flutter Server Box sigue una arquitectura por capas con una clara separación de responsabilidades.

## Capas de la Arquitectura

```
┌─────────────────────────────────────────────────┐
│           Capa de Presentación (UI)             │
│          lib/view/page/, lib/view/widget/       │
│  - Páginas, Widgets, Controladores              │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│           Capa de Lógica de Negocio             │
│              lib/data/provider/                 │
│  - Riverpod Providers, State Notifiers          │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│            Capa de Acceso a Datos               │
│         lib/data/store/, lib/data/model/        │
│  - Hive Stores, Modelos de Datos                │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│          Capa de Integración Externa            │
│  - SSH (dartssh2), Terminal (xterm), SFTP       │
│  - Código específico de plataforma (iOS, etc.)  │
└─────────────────────────────────────────────────┘
```

## Fundamentos de la Aplicación

### Punto de Entrada Principal

`lib/main.dart` inicializa la aplicación:

```dart
void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### Widget Raíz

`MyApp` proporciona:
- **Gestión de Temas**: Cambio entre tema claro/oscuro
- **Configuración de Rutas**: Estructura de navegación
- **Provider Scope**: Raíz para la inyección de dependencias

### Página de Inicio

`HomePage` sirve como núcleo de navegación:
- **Interfaz de Pestañas**: Servidor, Snippet, Contenedor, SSH
- **Gestión de Estado**: Estado por pestaña
- **Navegación**: Acceso a funciones

## Sistemas Principales

### Gestión de Estado: Riverpod

**¿Por qué Riverpod?**
- Seguridad en tiempo de compilación
- Facilidad para realizar pruebas
- Sin dependencia del Build context
- Funciona en todas las plataformas

**Tipos de Provider Utilizados:**
- `StateProvider`: Estado mutable simple
- `AsyncNotifierProvider`: Estados de carga/error/datos
- `StreamProvider`: Flujos de datos en tiempo real
- Future providers: Operaciones asíncronas únicas

### Persistencia de Datos: Hive CE

**¿Por qué Hive CE?**
- Sin dependencias de código nativo
- Almacenamiento clave-valor rápido
- Tipado seguro con generación de código
- Sin necesidad de anotaciones manuales de campos

**Almacenes (Stores):**
- `SettingStore`: Preferencias de la app
- `ServerStore`: Configuraciones de servidores
- `SnippetStore`: Fragmentos de comandos
- `KeyStore`: Claves SSH

### Modelos Inmutables: Freezed

**Beneficios:**
- Inmutabilidad en tiempo de compilación
- Tipos Union para el estado
- Serialización JSON integrada
- Extensiones CopyWith

## Estrategia Multiplataforma

### Sistema de Plugins

Los plugins de Flutter proporcionan la integración con la plataforma:

| Plataforma | Método de Integración |
|------------|-----------------------|
| iOS | CocoaPods, Swift/Obj-C |
| Android | Gradle, Kotlin/Java |
| macOS | CocoaPods, Swift |
| Linux | CMake, C++ |
| Windows | CMake, C# |

### Funciones Específicas por Plataforma

**Solo iOS:**
- Widgets de pantalla de inicio
- Actividades en Directo (Live Activities)
- Compañero de Apple Watch

**Solo Android:**
- Servicio en segundo plano
- Notificaciones push
- Acceso al sistema de archivos

**Solo Escritorio:**
- Integración en la barra de menús
- Múltiples ventanas
- Barra de título personalizada

## Dependencias Personalizadas

### Rama (Fork) de dartssh2

Cliente SSH mejorado con:
- Mejor soporte para móviles
- Gestión de errores mejorada
- Optimizaciones de rendimiento

### Rama (Fork) de xterm.dart

Emulador de terminal con:
- Renderizado optimizado para móviles
- Soporte para gestos táctiles
- Integración con teclado virtual

### fl_lib

Paquete de utilidades compartidas con:
- Widgets comunes
- Extensiones
- Funciones de ayuda

## Sistema de Compilación

### Paquete fl_build

Sistema de compilación personalizado para:
- Compilaciones multiplataforma
- Firma de código
- Empaquetado de recursos (assets)
- Gestión de versiones

### Proceso de Compilación

```
make.dart (versión) → fl_build (compilación) → Salida de plataforma
```

1. **Pre-compilación**: Cálculo de la versión desde Git
2. **Compilación**: Compilar para la plataforma de destino
3. **Post-compilación**: Empaquetado y firma

## Ejemplo de Flujo de Datos

### Actualización del Estado del Servidor

```
1. El temporizador se activa →
2. El Provider llama al servicio →
3. El servicio ejecuta el comando SSH →
4. La respuesta se analiza en el modelo →
5. Se actualiza el estado →
6. La UI se reconstruye con los nuevos datos
```

### Flujo de Acción del Usuario

```
1. El usuario toca un botón →
2. El Widget llama al método del provider →
3. El Provider actualiza el estado →
4. El cambio de estado activa la reconstrucción →
5. El nuevo estado se refleja en la UI
```

## Arquitectura de Seguridad

### Protección de Datos

- **Contraseñas**: Cifradas con flutter_secure_storage
- **Claves SSH**: Cifradas en reposo
- **Huellas de Host**: Almacenadas de forma segura
- **Datos de Sesión**: No se persisten

### Seguridad de Conexión

- **Verificación de Clave de Host**: Detección de MITM
- **Cifrado**: Cifrado SSH estándar
- **Sin Texto Plano**: Los datos sensibles nunca se almacenan en plano
