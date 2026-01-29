---
title: Ajustes Ocultos (JSON)
description: Accede a ajustes avanzados mediante el editor JSON
---

Algunos ajustes están ocultos en la interfaz de usuario pero son accesibles a través del editor JSON.

## Acceso

Mantén pulsado **Ajustes** en el menú lateral para abrir el editor JSON.

## Ajustes Ocultos Comunes

### timeOut

Tiempo de espera de conexión en segundos.

```json
{"timeOut": 10}
```

**Tipo:** entero | **Predeterminado:** 5 | **Rango:** 1-60

### recordHistory

Guardar historial (rutas SFTP, etc.).

```json
{"recordHistory": true}
```

**Tipo:** booleano | **Predeterminado:** true

### textFactor

Factor de escala de texto.

```json
{"textFactor": 1.2}
```

**Tipo:** doble | **Predeterminado:** 1.0 | **Rango:** 0.8-1.5

## Encontrar Más Ajustes

Todos los ajustes están definidos en [`setting.dart`](https://github.com/lollipopkit/flutter_server_box/blob/main/lib/data/store/setting.dart).

Busca:
```dart
late final settingName = StoreProperty(box, 'settingKey', defaultValue);
```

## ⚠️ Importante

**Antes de editar:**
- **Crea una copia de seguridad**: unos ajustes incorrectos pueden hacer que la app no se abra
- **Edita con cuidado**: el JSON debe ser válido

## Recuperación

Si la aplicación no se abre tras editar:
1. Borra los datos de la aplicación (último recurso)
2. Reinstala la aplicación
3. Restaura desde una copia de seguridad
