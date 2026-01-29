---
title: Gestión de Docker
description: Monitorear y gestionar contenedores Docker
---

Server Box proporciona una interfaz intuitiva para gestionar contenedores Docker en sus servidores.

## Características

### Lista de Contenedores

- Ver todos los contenedores (en ejecución y detenidos)
- Visualización de ID y nombre del contenedor
- Información de la imagen
- Indicadores de estado
- Hora de creación

### Acciones de Contenedor

- **Iniciar**: Lanzar contenedores detenidos
- **Detener**: Detener de forma segura los contenedores en ejecución
- **Reiniciar**: Reiniciar contenedores
- **Eliminar**: Eliminar contenedores
- **Ver Logs**: Consultar los registros del contenedor
- **Inspeccionar**: Ver detalles del contenedor

### Detalles del Contenedor

- Variables de entorno
- Mapeos de puertos
- Montajes de volúmenes
- Configuración de red
- Uso de recursos

## Requisitos

- Docker debe estar instalado en su servidor
- El usuario SSH debe tener permisos de Docker
- Para usuarios que no son root, añadir al grupo docker:
  ```bash
  sudo usermod -aG docker su_nombre_de_usuario
  ```

## Acciones Rápidas

- Un toque: Ver detalles del contenedor
- Pulsación larga: Menú de acciones rápidas
- Deslizar: Inicio/parada rápida
- Selección masiva: Operaciones en múltiples contenedores

## Consejos

- Use la **actualización automática** para monitorear los cambios de estado de los contenedores
- Filtrar por contenedores en ejecución/detenidos
- Buscar contenedores por nombre o ID
