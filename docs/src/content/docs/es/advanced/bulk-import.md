---
title: Importación Masiva de Servidores
description: Importar múltiples servidores desde un archivo JSON
---

Importa múltiples configuraciones de servidor a la vez utilizando un archivo JSON.

## Formato JSON

:::danger[Advertencia de Seguridad]
**¡Nunca guardes contraseñas en texto plano en archivos!** Este ejemplo JSON muestra un campo de contraseña solo con fines demostrativos, pero deberías:

- **Preferir claves SSH** (`keyId`) en lugar de `pwd`; son más seguras
- **Usar gestores de secretos** o variables de entorno si debes usar contraseñas
- **Eliminar el archivo inmediatamente** después de la importación; no dejes credenciales tiradas
- **Añadir a .gitignore**: nunca subas archivos de credenciales al control de versiones
:::

```json
[
  {
    "name": "Mi Servidor",
    "ip": "example.com",
    "port": 22,
    "user": "root",
    "pwd": "password",
    "keyId": "",
    "tags": ["production"],
    "autoConnect": false
  }
]
```

## Campos

| Campo | Requerido | Descripción |
|-------|-----------|-------------|
| `name` | Sí | Nombre para mostrar |
| `ip` | Sí | Dominio o dirección IP |
| `port` | Sí | Puerto SSH (usualmente 22) |
| `user` | Sí | Usuario SSH |
| `pwd` | No | Contraseña (evitar - usar claves SSH en su lugar) |
| `keyId` | No | Nombre de la clave SSH (de Claves Privadas - recomendado) |
| `tags` | No | Etiquetas de organización |
| `autoConnect` | No | Autoconexión al iniciar |

## Pasos para Importar

1. Crea un archivo JSON con las configuraciones del servidor
2. Ajustes → Copia de seguridad → Importación masiva de servidores
3. Selecciona tu archivo JSON
4. Confirma la importación

## Ejemplo

```json
[
  {
    "name": "Producción",
    "ip": "prod.example.com",
    "port": 22,
    "user": "admin",
    "keyId": "mi-clave",
    "tags": ["production", "web"]
  },
  {
    "name": "Desarrollo",
    "ip": "dev.example.com",
    "port": 2222,
    "user": "dev",
    "keyId": "dev-clave",
    "tags": ["development"]
  }
]
```

## Consejos

- **Usa claves SSH** en lugar de contraseñas cuando sea posible
- **Prueba la conexión** después de la importación
- **Organiza con etiquetas** para una gestión más sencilla
- **Elimina el archivo JSON** después de la importación
- **Nunca subas** archivos JSON con credenciales al control de versiones
