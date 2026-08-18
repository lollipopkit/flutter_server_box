---
title: Widgets de Pantalla de Inicio
description: Añade widgets de estado del servidor a tu pantalla de inicio
---

Requiere tener instalado [ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/tree/main/monitor) en tus servidores.

## Requisitos Previos

Instala primero ServerBox Monitor en tu servidor. Consulta la [Wiki de ServerBox Monitor](https://github.com/lollipopkit/flutter_server_box/blob/main/monitor/README.md) para ver las instrucciones de configuración.

Tras la instalación, tu servidor debería tener:
- Un punto de acceso (endpoint) HTTP/HTTPS
- El punto de acceso API `/status`
- Autenticación opcional

## Formato de URL

```
https://tu-servidor.com/status
```

Debe terminar en `/status`.

## Widget de iOS

### Configuración

1. Mantén pulsada la pantalla de inicio → Toca el símbolo **+**
2. Busca "ServerBox"
3. Elige el tamaño del widget
4. Mantén pulsado el widget → **Editar widget**
5. Introduce la URL terminada en `/status`

### Notas

- Debe usar HTTPS (excepto IPs locales)
- Tasa máxima de refresco: 30 minutos (límite de iOS)
- Añade varios widgets para varios servidores

## Widget de Android

### Configuración

1. Mantén pulsada la pantalla de inicio → **Widgets**
2. Busca "ServerBox" → Añadir a la pantalla de inicio
3. Anota el número de ID del widget que aparece
4. Abre la app ServerBox → Ajustes
5. Toca en **Configurar enlace de widget de inicio**
6. Añade la entrada: `Widget ID` = `URL de estado`

Ejemplo:
- Clave (Key): `17`
- Valor (Value): `https://mi-servidor.com/status`

7. Toca el widget en la pantalla de inicio para refrescarlo

## watchOS

El reloj lee cada servidor de su agente monitor por sí mismo, así que solo puede
mostrar servidores que tengan uno configurado. Configura primero el agente en la
página de edición del servidor — como método de conexión, o junto a SSH.

### Configuración

1. Abre la app en el iPhone → Ajustes → **Ajustes de iOS**
2. Toca **App del Watch**
3. Elige los servidores a mostrar. Se conserva el orden en que los elijas, y el
   reloj recorre esa lista
4. Espera a que la app del reloj se sincronice

**Servidor del widget de pantalla bloqueada** es una entrada aparte en la misma
página — un servidor en lugar de una lista.

### Notas

- Prueba a reiniciar la app del reloj si no se actualiza
- Verifica que el teléfono y el reloj están conectados
- **URL de estado heredadas** solo aparece si ya tienes alguna, guardada por una
  versión anterior. Nada crea nuevas

## Solución de Problemas

### El Widget no se actualiza

**iOS:** Espera hasta 30 minutos, luego elimínalo y vuelve a añadirlo.
**Android:** Toca el widget para forzar el refresco, verifica el ID en los ajustes.
**watchOS:** Reinicia la app del reloj, espera unos minutos.

### El Widget muestra un error

- Verifica que ServerBox Monitor se está ejecutando
- Prueba la URL en un navegador
- Comprueba que la URL termina en `/status`

## Seguridad

- **Usa siempre HTTPS** cuando sea posible
- **IPs locales solo** en redes de confianza
