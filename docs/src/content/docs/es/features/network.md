---
title: Herramientas de Red
description: Herramientas de prueba y diagnóstico de red
---

Server Box incluye varias herramientas de red para pruebas y diagnósticos.

## iPerf

Realice pruebas de velocidad de red entre su dispositivo y el servidor.

### Características

- **Velocidad de Carga/Descarga**: Probar el ancho de banda
- **Modo Servidor**: Usar el servidor como servidor iPerf
- **Modo Cliente**: Conectarse a servidores iPerf
- **Parámetros Personalizados**: Duración, flujos paralelos, etc.

### Uso

1. Abra un servidor
2. Toque **iPerf**
3. Elija el modo servidor o cliente
4. Configure los parámetros
5. Inicie la prueba

## Ping

Pruebe la conectividad y latencia de la red.

### Características

- **Ping ICMP**: Herramienta de ping estándar
- **Recuento de Paquetes**: Especificar el número de paquetes
- **Tamaño de Paquete**: Tamaño de paquete personalizado
- **Intervalo**: Tiempo entre pings

### Uso

1. Abra un servidor
2. Toque **Ping**
3. Ingrese el host de destino
4. Configure los parámetros
5. Comience el ping

## Wake on LAN

Despierte servidores remotos mediante un paquete mágico.

### Características

- **Dirección MAC**: MAC del dispositivo de destino
- **Broadcast**: Enviar paquete mágico de difusión
- **Perfiles Guardados**: Almacenar configuraciones de WoL

### Requisitos

- El dispositivo de destino debe ser compatible con Wake-on-LAN
- WoL debe estar habilitado en la BIOS/UEFI
- El dispositivo debe estar en estado de suspensión o apagado suave
- El dispositivo debe estar en la misma red o ser accesible vía broadcast

## Consejos

- Use iPerf para diagnosticar cuellos de botella en la red
- Haga ping a múltiples hosts para comparar la latencia
- Guarde perfiles de WoL para dispositivos despertados con frecuencia
