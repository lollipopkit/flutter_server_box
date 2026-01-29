---
title: Comandos Personalizados
description: Mostrar la salida de comandos personalizados en la página del servidor
---

Añade comandos shell personalizados para mostrar su salida en la página de detalles del servidor.

## Configuración

1. Ajustes del servidor → Comandos personalizados
2. Introduce los comandos en formato JSON

## Formato Básico

```json
{
  "Nombre a mostrar": "comando shell"
}
```

**Ejemplo:**
```json
{
  "Memoria": "free -h",
  "Disco": "df -h",
  "Tiempo de actividad": "uptime"
}
```

## Ver Resultados

Tras la configuración, los comandos personalizados aparecerán en la página de detalles del servidor y se actualizarán automáticamente.

## Nombres de Comando Especiales

### server_card_top_right

Se muestra en la tarjeta del servidor de la página de inicio (esquina superior derecha):

```json
{
  "server_card_top_right": "tu-comando-aquí"
}
```

## Consejos

**Usa rutas absolutas:**
```json
{"Mi Script": "/usr/local/bin/mi-script.sh"}
```

**Comandos con tuberías (pipes):**
```json
{"Proceso principal": "ps aux | sort -rk 3 | head -5"}
```

**Formatear salida:**
```json
{"Carga de CPU": "uptime | awk -F'load average:' '{print $2}'"}
```

**Mantén los comandos rápidos:** Menos de 5 segundos para una mejor experiencia.

**Limitar salida:**
```json
{"Logs": "tail -20 /var/log/syslog"}
```

## Seguridad

Los comandos se ejecutan con los permisos del usuario SSH. Evita comandos que modifiquen el estado del sistema.
