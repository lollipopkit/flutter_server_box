---
title: Conexión SSH
description: Cómo se establecen y gestionan las conexiones SSH
---

Entendiendo las conexiones SSH en Server Box.

Esta página trata de servidores añadidos por SSH. Un servidor puede añadirse en
cambio a través de la API HTTP de un agente monitor; en ese caso no lleva
credenciales SSH y nada de lo aquí descrito se le aplica.

## Flujo de Conexión

```text
Entrada de Usuario → Configuración Spi → genClient() → Cliente SSH → Sesión
```

### Paso 1: Configuración

El modelo `Spi` (Server Parameter Info) contiene:

```dart
class Spi {
  String id;                      // ID del servidor
  String name;                    // Nombre del servidor
  SshCredential? ssh;             // null en un servidor monitor
  MonitorHttpCredential? monitorHttp;
}

final class SshCredential {
  String ip;              // Dirección IP
  int port;               // Puerto SSH (por defecto 22)
  String user;            // Usuario
  String? pwd;            // Contraseña (cifrada)
  String? keyId;          // ID de la clave SSH
  String? alterUrl;       // URL alternativa
  List<String>? jumpIds;  // Cadena de servidores de salto
  String? proxyCommand;   // ProxyCommand, solo escritorio
}
```

Una cadena de saltos y un `ProxyCommand` se excluyen mutuamente;
`Spix.validate()` rechaza un servidor que defina ambos.

### Paso 2: Generación del Cliente

`genClient(spi)` crea el cliente SSH:

```dart
Future<SSHClient> genClient(Spi spi) async {
  final ssh = spi.ssh!;
  // 1. Establecer socket
  var socket = await connect(ssh.ip, ssh.port);

  // 2. Probar URL alternativa si falla
  if (socket == null && ssh.alterUrl != null) {
    socket = await connect(ssh.alterUrl, ssh.port);
  }

  if (socket == null) {
    throw ConnectionException('Unable to connect');
  }

  // 3. Autenticar
  final client = SSHClient(
    socket: socket,
    username: ssh.user,
    onPasswordRequest: () => ssh.pwd,
    onIdentityRequest: () => loadKey(ssh.keyId),
  );

  // 4. Verificar clave de host
  await verifyHostKey(client, spi);

  return client;
}
```

### Paso 3: De dónde sale el socket

`genClient` resuelve una de tres fuentes; todo lo que hay por encima de
`SSHSocket` es idéntico en los tres casos:

**Directo** — lo predeterminado, `SSHSocket.connect(ip, port)`, con repliegue a
`alterUrl` si falla.

**Servidor de salto** — conexión recursiva y luego una redirección local:

```dart
for (final jumpId in spi.resolvedJumpIds) {
  final jumpClient = await genClient(getJumpSpi(jumpId));
  return await jumpClient.forwardLocal(ssh.ip, ssh.port);
}
```

**ProxyCommand** — solo escritorio, ya que lanza un proceso:

```dart
if (ssh.proxyCommand != null) {
  return await ProxyCommandSocket.connect(
    command: ssh.proxyCommand,
    host: ssh.ip,
    port: ssh.port,
    user: ssh.user,
  );
}
```

## Métodos de Autenticación

### Autenticación por Contraseña

```dart
onPasswordRequest: () => ssh.pwd
```

- Contraseña almacenada cifrada en Hive
- Descifrada al conectar
- Enviada al servidor para verificación

### Autenticación por Clave Privada

```dart
onIdentityRequest: () async {
  final key = await PrivateKeyStore.get(ssh.keyId);
  return decyptPem(key.pem, key.password);
}
```

**Proceso de Carga de Clave:**
1. Recuperar clave cifrada de `PrivateKeyStore`
2. Descifrar contraseña (biometría/aviso)
3. Analizar formato PEM
4. Estandarizar finales de línea (LF)
5. Retornar para autenticación

### Interacción por Teclado (Keyboard-Interactive)

```dart
onUserInfoRequest: (instructions) async {
  // Gestionar desafío-respuesta
  return responses;
}
```

Soporta:
- Autenticación por contraseña
- Tokens OTP
- Autenticación de doble factor (2FA)

## Verificación de Clave de Host

### ¿Por qué verificar las claves de host?

Evita ataques de **Hombre en el Medio (MITM)** asegurando que te conectas al mismo servidor.

### Formato de Almacenamiento

```text
{spi.id}::{keyType}
```

Ejemplo:
```text
mi-servidor::ssh-ed25519
mi-servidor::ecdsa-sha2-nistp256
```

### Formatos de Huella Digital (Fingerprint)

**MD5 Hex:**
```text
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64:**
```text
SHA256:AbCdEf1234567890...=
```

### Flujo de Verificación

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final keyType = key.type;
  final fingerprint = md5Hex(key); // o base64

  final stored = SettingStore.sshKnownHostFingerprints
      ['${spi.id}::$keyType'];

  if (stored == null) {
    // Nuevo host - preguntar al usuario
    final trust = await promptUser(
      'Host desconocido',
      'Huella: $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostFingerprints
          ['${spi.id}::$keyType'] = fingerprint;
    }
  } else if (stored != fingerprint) {
    // Ha cambiado - advertir al usuario
    await warnUser(
      '¡La clave de host ha cambiado!',
      'Posible ataque MITM',
    );
  }
}
```

## Gestión de Sesiones

### Pool de Conexiones

Clientes activos mantenidos en `ServerProvider`:

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### Keep-Alive

Mantener la conexión durante la inactividad:

```dart
Timer.periodic(
  Duration(seconds: 30),
  (_) => client.sendKeepAlive(),
);
```

### Reconexión Automática

Al perder la conexión:

```dart
client.onError.listen((error) async {
  await Future.delayed(Duration(seconds: 5));
  reconnect();
});
```

## Ciclo de Vida de la Conexión

```text
┌─────────────┐
│   Inicial   │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│ Conectando  │ ←──┐
└──────┬──────┘   │
       │ éxito    │
       ↓          │ fallo (reintento)
┌─────────────┐   │
│ Conectado   │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│   Activo    │ ──→ Enviar comandos
└──────┬──────┘
       │
       ↓ (error/desconexión)
┌─────────────┐
│ Desconectado│
└─────────────┘
```

## Gestión de Errores

### Tiempo de Espera Agotado (Timeout)

```dart
try {
  await client.connect().timeout(
    Duration(seconds: 30),
  );
} on TimeoutException {
  throw ConnectionException('Tiempo de espera de conexión agotado');
}
```

### Fallo de Autenticación

```dart
onAuthFail: (error) {
  if (error.contains('password')) {
    return 'Contraseña no válida';
  } else if (error.contains('key')) {
    return 'Clave SSH no válida';
  }
  return 'Fallo de autenticación';
}
```

### Discrepancia en Clave de Host

```dart
onHostKeyMismatch: (stored, current) {
  showSecurityWarning(
    '¡La clave de host ha cambiado!',
    'Posible ataque MITM',
  );
}
```

## Consideraciones de Rendimiento

### Reutilización de Conexiones

- Reutilizar clientes entre funciones
- No desconectar/reconectar innecesariamente
- Pool de conexiones para operaciones concurrentes

### Ajustes Óptimos

- **Timeout**: 30 segundos (ajustable)
- **Keep-alive**: Cada 30 segundos
- **Retraso de reintento**: 5 segundos

### Eficiencia de Red

- Conexión única para múltiples operaciones
- Comandos en tubería (pipeline) cuando sea posible
- Evitar abrir múltiples conexiones
