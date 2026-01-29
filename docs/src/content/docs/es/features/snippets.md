---
title: Snippets
description: Guardar y ejecutar comandos de shell personalizados
---

Los snippets le permiten guardar comandos de shell utilizados con frecuencia para una ejecución rápida.

## Crear Snippets

1. Vaya a la pestaña **Snippets**
2. Toque el botón **+**
3. Complete los detalles del snippet:
   - **Nombre**: Nombre descriptivo para el snippet
   - **Comando**: El comando de shell a ejecutar
   - **Descripción**: Notas opcionales
4. Guarde el snippet

## Usar Snippets

1. Abra un servidor
2. Toque el botón **Snippet**
3. Seleccione un snippet para ejecutar
4. Vea la salida en la terminal

## Características de los Snippets

- **Ejecución Rápida**: Ejecución de comandos con un solo toque
- **Variables**: Usar variables específicas del servidor
- **Organización**: Agrupar snippets relacionados
- **Importar/Exportar**: Compartir snippets entre dispositivos
- **Sincronización**: Sincronización en la nube opcional

## Ejemplos de Snippets

### Actualización del Sistema
```bash
sudo apt update && sudo apt upgrade -y
```

### Limpieza de Disco
```bash
sudo apt autoremove -y && sudo apt clean
```

### Limpieza de Docker
```bash
docker system prune -a
```

### Ver Registros del Sistema
```bash
journalctl -n 50 -f
```

## Consejos

- Use **nombres descriptivos** para una fácil identificación
- Añada **comentarios** para comandos complejos
- Pruebe los comandos antes de guardarlos como snippets
- Organice los snippets por categoría o tipo de servidor
