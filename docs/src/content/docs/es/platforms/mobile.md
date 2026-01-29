---
title: Funciones Móviles
description: Funciones específicas para iOS y Android
---

Flutter Server Box proporciona varias funciones específicas para dispositivos móviles iOS y Android.

## Autenticación Biométrica

Asegura tus servidores con autenticación biométrica:

- **iOS**: Face ID o Touch ID
- **Android**: Autenticación por huella dactilar

Actívalo en Ajustes > Seguridad > Autenticación biométrica.

## Widgets de Pantalla de Inicio

Añade widgets de estado del servidor a tu pantalla de inicio para una monitorización rápida.

### iOS

- Mantén pulsada la pantalla de inicio
- Toca en **+** para añadir un widget
- Busca "Flutter Server Box"
- Elige el tamaño del widget:
  - Pequeño: Estado de un solo servidor
  - Mediano: Múltiples servidores
  - Grande: Información detallada

### Android

- Mantén pulsada la pantalla de inicio
- Toca en **Widgets**
- Busca "Flutter Server Box"
- Selecciona el tipo de widget

## Ejecución en Segundo Plano

### Android

Mantén las conexiones activas en segundo plano:

- Actívalo en Ajustes > Avanzado > Ejecución en segundo plano
- Requiere exclusión de la optimización de batería
- Notificaciones persistentes para conexiones activas

### iOS

Se aplican limitaciones de segundo plano:

- Las conexiones pueden pausarse en segundo plano
- Reconexión rápida al volver a la app
- Soporte para actualización en segundo plano

## Notificaciones Push

Recibe notificaciones para:

- Alertas de servidor fuera de línea
- Avisos de alto uso de recursos
- Alertas de finalización de tareas

Configúralo en Ajustes > Notificaciones.

## Funciones de UI Móvil

- **Deslizar para refrescar**: Actualiza el estado del servidor
- **Acciones de deslizamiento**: Operaciones rápidas de servidor
- **Modo horizontal**: Mejor experiencia de terminal
- **Teclado virtual**: Atajos de terminal

## Integración de Archivos

- **App Archivos (iOS)**: Acceso directo SFTP desde Archivos
- **Storage Access Framework (Android)**: Comparte archivos con otras apps
- **Selector de documentos**: Selección de archivos sencilla
