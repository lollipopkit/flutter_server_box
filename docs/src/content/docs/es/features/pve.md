---
title: Proxmox (PVE)
description: Gestión de Proxmox Virtual Environment
---

Flutter Server Box incluye soporte para gestionar la plataforma de virtualización Proxmox VE.

## Características

### Gestión de VM

- **Listar VMs**: Ver todas las máquinas virtuales
- **Estado de VM**: Comprobar estados de ejecución/detención
- **Acciones de VM**: Iniciar, detener, reiniciar VMs
- **Detalles de VM**: Ver configuración y recursos

### Gestión de Contenedores (LXC)

- **Listar Contenedores**: Ver todos los contenedores LXC
- **Estado de Contenedores**: Monitorear estados de contenedores
- **Acciones de Contenedor**: Iniciar, detener, reiniciar contenedores
- **Acceso a Consola**: Acceso de terminal a contenedores

### Monitoreo de Nodos

- **Uso de Recursos**: CPU, memoria, disco, red
- **Estado del Nodo**: Comprobar la salud del nodo
- **Vista de Cluster**: Descripción general del cluster multi-nodo

## Configuración

### Añadir Servidor PVE

1. Añada el servidor como una conexión SSH normal
2. Asegúrese de que el usuario tenga permisos de PVE
3. Acceda a las funciones de PVE desde la página de detalles del servidor

### Permisos Requeridos

El usuario de PVE necesita:

- **VM.Audit**: Ver el estado de la VM
- **VM.PowerMgmt**: Iniciar/detener VMs
- **VM.Console**: Acceso a la consola

Ejemplo de configuración de permisos:

```bash
pveum useradd myuser -password mypass
pveum aclmod /vms -user myuser@pve -role VMAdmin
```

## Uso

### Gestión de VM

1. Abra el servidor con PVE
2. Toque el botón **PVE**
3. Vea la lista de VMs
4. Toque la VM para ver detalles
5. Use los botones de acción para la gestión

### Gestión de Contenedores

1. Abra el servidor con PVE
2. Toque el botón **PVE**
3. Cambie a la pestaña de Contenedores
4. Vea y gestione contenedores LXC

### Monitoreo

- Uso de recursos en tiempo real
- Gráficos de datos históricos
- Soporte para múltiples nodos

## Características por Estado

### Implementadas

- Listado y estado de VM
- Listado y estado de contenedores
- Operaciones básicas de VM (inicio/parada/reinicio)
- Monitoreo de recursos

### Planeadas

- Creación de VM desde plantillas
- Gestión de instantáneas (snapshots)
- Acceso a consola
- Gestión de almacenamiento
- Configuración de red

## Requisitos

- **Versión de PVE**: 6.x o 7.x
- **Acceso**: Acceso SSH al host PVE
- **Permisos**: Roles de usuario de PVE adecuados
- **Red**: Conectividad a la API de PVE (vía SSH)

## Consejos

- Use un **usuario de PVE dedicado** con permisos limitados
- Monitoree el **uso de recursos** para un rendimiento óptimo
- Verifique el **estado de la VM** antes del mantenimiento
- Use **instantáneas** antes de cambios importantes
