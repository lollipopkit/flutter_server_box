---
title: Problemas Comunes
description: Soluciones a problemas frecuentes
---

## Problemas de Conexión

### SSH no conecta

**Síntomas:** Tiempo de espera agotado (timeout), conexión rechazada, fallo de autenticación

**Soluciones:**

1. **Verificar el tipo de servidor:** Solo se admiten sistemas tipo Unix (Linux, macOS, Android/Termux)
2. **Probar manualmente:** `ssh usuario@servidor -p puerto`
3. **Comprobar el cortafuegos:** El puerto 22 debe estar abierto
4. **Verificar credenciales:** Usuario y contraseña/clave correctos

### Desconexiones frecuentes

**Síntomas:** El terminal se desconecta tras un periodo de inactividad

**Soluciones:**

1. **Keep-alive del servidor:**
   ```bash
   # /etc/ssh/sshd_config
   ClientAliveInterval 60
   ClientAliveCountMax 3
   ```

2. **Desactivar optimización de batería:**
   - MIUI: Batería → "Sin restricciones"
   - Android: Ajustes → Aplicaciones → Desactivar optimización
   - iOS: Activar actualización en segundo plano

## Problemas de Entrada

### No se pueden escribir ciertos caracteres

**Solución:** Ajustes → Tipo de teclado → Cambiar a `visiblePassword`

Nota: Es posible que la entrada CJK (chino, japonés, coreano) no funcione tras este cambio.

## Problemas de la Aplicación

### La aplicación se cierra al iniciar

**Síntomas:** La aplicación no se abre, pantalla en negro

**Causas:** Ajustes corruptos, especialmente tras usar el editor JSON

**Soluciones:**

1. **Borrar datos de la aplicación:**
   - Android: Ajustes → Aplicaciones → ServerBox → Borrar datos
   - iOS: Eliminar y reinstalar

2. **Restaurar copia de seguridad:** Importar una copia de seguridad creada antes de cambiar los ajustes

### Problemas con Copia de Seguridad/Restauración

**La copia de seguridad no funciona:**
- Comprobar espacio de almacenamiento
- Verificar que la aplicación tiene permisos de almacenamiento
- Probar una ubicación diferente

**La restauración falla:**
- Verificar la integridad del archivo de copia de seguridad
- Comprobar la compatibilidad de la versión de la aplicación

## Problemas con Widgets

### El Widget no se actualiza

**iOS:**
- Esperar hasta 30 minutos para la actualización automática
- Eliminar y volver a añadir el widget
- Comprobar que la URL termina en `/status`

**Android:**
- Pulsar el widget para forzar la actualización
- Verificar que el ID del widget coincide con la configuración en los ajustes de la aplicación

**watchOS:**
- Reiniciar la aplicación del reloj
- Esperar unos minutos tras cambiar la configuración
- Verificar el formato de la URL

### El Widget muestra un error

- Verificar que ServerBox Monitor se está ejecutando en el servidor
- Probar la URL en un navegador
- Comprobar las credenciales de autenticación

## Problemas de Rendimiento

### La aplicación va lenta

**Soluciones:**
- Reducir la tasa de refresco en los ajustes
- Comprobar la velocidad de la red
- Desactivar servidores no utilizados

### Alto consumo de batería

**Soluciones:**
- Aumentar los intervalos de refresco
- Desactivar la actualización en segundo plano
- Cerrar sesiones SSH no utilizadas

## Obtener Ayuda

Si los problemas persisten:

1. **Buscar en GitHub Issues:** https://github.com/lollipopkit/flutter_server_box/issues
2. **Crear nueva Issue:** Incluir versión de la aplicación, plataforma y pasos para reproducir
3. **Consultar la Wiki:** Esta documentación y la Wiki de GitHub
