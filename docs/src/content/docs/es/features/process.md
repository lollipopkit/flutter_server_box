---
title: Procesos y Servicios
description: Monitorear procesos y gestionar servicios systemd
---

## Gestión de Procesos

Vea y gestione los procesos en ejecución en sus servidores.

### Lista de Procesos

- Todos los procesos en ejecución con detalles
- PID (ID de Proceso)
- Uso de CPU y memoria
- Propiedad del usuario
- Comando del proceso

### Acciones de Proceso

- **Terminar (Kill)**: Finalizar procesos
- **Filtrar**: Por nombre o usuario
- **Ordenar**: Por CPU, memoria o PID
- **Buscar**: Encontrar procesos específicos

## Servicios Systemd

Gestione servicios systemd para el control de servicios.

### Lista de Servicios

- Todos los servicios systemd
- Estado activo/inactivo
- Estado habilitado/deshabilitado
- Descripción del servicio

### Acciones de Servicio

- **Iniciar**: Lanzar un servicio detenido
- **Detener**: Detener un servicio en ejecución
- **Reiniciar**: Reiniciar un servicio
- **Habilitar**: Habilitar el inicio automático al arrancar
- **Deshabilitar**: Deshabilitar el inicio automático
- **Ver Estado**: Consultar el estado del servicio y los registros
- **Recargar**: Recargar la configuración del servicio

## Requisitos

- El usuario SSH debe tener los permisos adecuados
- Para la gestión de servicios: puede ser necesario el acceso `sudo`
- Visualización de procesos: los permisos de usuario estándar suelen ser suficientes

## Consejos

- Use la lista de procesos para identificar los que consumen muchos recursos
- Verifique los registros de servicio para solucionar problemas
- Monitoree servicios críticos con la actualización automática
