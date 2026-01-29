---
title: SSH-Verbindung
description: Wie SSH-Verbindungen aufgebaut und verwaltet werden
---

Verständnis der SSH-Verbindungen in Server Box.

## Verbindungsablauf

```
Benutzereingabe → Spi-Konfiguration → genClient() → SSH-Client → Sitzung
```

### Schritt 1: Konfiguration

Das `Spi` (Server Parameter Info) Modell enthält:

```dart
class Spi {
  String name;       // Servername
  String ip;         // IP-Adresse
  int port;          // SSH-Port (Standard 22)
  String user;       // Benutzername
  String? pwd;       // Passwort (verschlüsselt)
  String? keyId;     // SSH-Schlüssel-ID
  String? jumpId;    // Jump-Server-ID
  String? alterUrl;  // Alternative URL
}
```

### Schritt 2: Client-Generierung

`genClient(spi)` erstellt den SSH-Client:

```dart
Future<SSHClient> genClient(Spi spi) async {
  // 1. Socket aufbauen
  var socket = await connect(spi.ip, spi.port);

  // 2. Alternative URL versuchen, falls fehlgeschlagen
  if (socket == null && spi.alterUrl != null) {
    socket = await connect(spi.alterUrl, spi.port);
  }

  if (socket == null) {
    throw ConnectionException('Unable to connect');
  }

  // 3. Authentifizieren
  final client = SSHClient(
    socket: socket,
    username: spi.user,
    onPasswordRequest: () => spi.pwd,
    onIdentityRequest: () => loadKey(spi.keyId),
  );

  // 4. Host-Key verifizieren
  await verifyHostKey(client, spi);

  return client;
}
```

### Schritt 3: Jump-Server (falls konfiguriert)

Für Jump-Server, rekursive Verbindung:

```dart
if (spi.jumpId != null) {
  final jumpClient = await genClient(getJumpSpi(spi.jumpId));
  final forwarded = await jumpClient.forwardLocal(
    spi.ip,
    spi.port,
  );
  // Über weitergeleiteten Socket verbinden
}
```

## Authentifizierungsmethoden

### Passwort-Authentifizierung

```dart
onPasswordRequest: () => spi.pwd
```

- Passwort verschlüsselt in Hive gespeichert
- Bei Verbindung entschlüsselt
- Zur Verifizierung an den Server gesendet

### Private-Key-Authentifizierung

```dart
onIdentityRequest: () async {
  final key = await KeyStore.get(spi.keyId);
  return decyptPem(key.pem, key.password);
}
```

**Schlüssel-Ladeprozess:**
1. Verschlüsselten Schlüssel aus `KeyStore` abrufen
2. Passwort entschlüsseln (Biometrie/Eingabeaufforderung)
3. PEM-Format parsen
4. Zeilenenden standardisieren (LF)
5. Zur Authentifizierung zurückgeben

### Tastatur-Interaktiv (Keyboard-Interactive)

```dart
onUserInfoRequest: (instructions) async {
  // Challenge-Response handhaben
  return responses;
}
```

Unterstützt:
- Passwort-Authentifizierung
- OTP-Token
- Zwei-Faktor-Authentifizierung (2FA)

## Host-Key-Verifizierung

### Warum Host-Keys verifizieren?

Verhindert **Man-in-the-Middle (MITM)** Angriffe, indem sichergestellt wird, dass Sie sich mit demselben Server verbinden.

### Speicherformat

```
{spi.id}::{keyType}
```

Beispiel:
```
mein-server::ssh-ed25519
mein-server::ecdsa-sha2-nistp256
```

### Fingerabdruck-Formate

**MD5 Hex:**
```
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64:**
```
SHA256:AbCdEf1234567890...=
```

### Verifizierungsablauf

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final keyType = key.type;
  final fingerprint = md5Hex(key); // oder base64

  final stored = SettingStore.sshKnownHostsFingerprints
      ['${spi.id}::$keyType'];

  if (stored == null) {
    // Neuer Host - Benutzer fragen
    final trust = await promptUser(
      'Unbekannter Host',
      'Fingerabdruck: $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostsFingerprints
          ['${spi.id}::$keyType'] = fingerprint;
    }
  } else if (stored != fingerprint) {
    // Geändert - Benutzer warnen
    await warnUser(
      'Host-Key geändert!',
      'Möglicher MITM-Angriff',
    );
  }
}
```

## Sitzungsverwaltung

### Verbindungs-Pooling

Aktive Clients werden im `ServerProvider` verwaltet:

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### Keep-Alive

Verbindung bei Inaktivität aufrechterhalten:

```dart
Timer.periodic(
  Duration(seconds: 30),
  (_) => client.sendKeepAlive(),
);
```

### Automatische Wiederverbindung

Bei Verbindungsverlust:

```dart
client.onError.listen((error) async {
  await Future.delayed(Duration(seconds: 5));
  reconnect();
});
```

## Lebenszyklus einer Verbindung

```
┌─────────────┐
│   Initial   │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│ Verbinden   │ ←──┐
└──────┬──────┘   │
       │ Erfolg   │
       ↓          │ Fehler (Retry)
┌─────────────┐   │
│ Verbunden   │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│   Aktiv     │ ──→ Befehle senden
└──────┬──────┘
       │
       ↓ (Fehler/Trennung)
┌─────────────┐
│ Getrennt    │
└─────────────┘
```

## Fehlerbehandlung

### Verbindungs-Timeout

```dart
try {
  await client.connect().timeout(
    Duration(seconds: 30),
  );
} on TimeoutException {
  throw ConnectionException('Verbindungs-Timeout');
}
```

### Authentifizierungsfehler

```dart
onAuthFail: (error) {
  if (error.contains('password')) {
    return 'Ungültiges Passwort';
  } else if (error.contains('key')) {
    return 'Ungültiger SSH-Schlüssel';
  }
  return 'Authentifizierung fehlgeschlagen';
}
```

### Host-Key-Abweichung

```dart
onHostKeyMismatch: (stored, current) {
  showSecurityWarning(
    'Host-Key hat sich geändert!',
    'Möglicher MITM-Angriff',
  );
}
```

## Leistungsaspekte

### Wiederverwendung von Verbindungen

- Wiederverwendung von Clients über Funktionen hinweg
- Nicht unnötig trennen/wiederverbinden
- Verbindungs-Pooling für gleichzeitige Operationen

### Optimale Einstellungen

- **Timeout**: 30 Sekunden (anpassbar)
- **Keep-Alive**: Alle 30 Sekunden
- **Wiederholungsverzögerung**: 5 Sekunden

### Netzwerkeffizienz

- Einzelne Verbindung für mehrere Operationen
- Befehle pipelinen, wenn möglich
- Das Öffnen mehrerer Verbindungen vermeiden
