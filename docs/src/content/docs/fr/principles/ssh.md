---
title: Connexion SSH
description: Comment les connexions SSH sont établies et gérées
---

Comprendre les connexions SSH dans Server Box.

Cette page concerne les serveurs ajoutés par SSH. Un serveur peut au contraire
être ajouté via l'API HTTP d'un agent monitor : il ne porte alors aucun
identifiant SSH et rien de ce qui suit ne s'y applique.

## Flux de connexion

```text
Entrée utilisateur → Configuration Spi → genClient() → Client SSH → Session
```

### Étape 1 : Configuration

Le modèle `Spi` (Server Parameter Info) contient :

```dart
class Spi {
  String id;                      // Identifiant unique
  String name;                    // Nom du serveur
  SshCredential? ssh;             // null pour un serveur monitor
  MonitorHttpCredential? monitorHttp;
}

final class SshCredential {
  String ip;              // Adresse IP
  int port;               // Port SSH (par défaut 22)
  String user;            // Nom d'utilisateur
  String? pwd;            // Mot de passe (chiffré)
  String? keyId;          // ID de la clé SSH
  String? alterUrl;       // URL alternative
  List<String>? jumpIds;  // Chaîne de serveurs de rebond
  String? proxyCommand;   // ProxyCommand, bureau uniquement
}
```

Une chaîne de rebond et un `ProxyCommand` s'excluent mutuellement ;
`Spix.validate()` rejette un serveur qui définit les deux.

### Étape 2 : Génération du client

`genClient(spi)` crée le client SSH :

```dart
Future<SSHClient> genClient(Spi spi) async {
  final ssh = spi.ssh!;
  // 1. Établir le socket
  var socket = await connect(ssh.ip, ssh.port);

  // 2. Essayer l'URL alternative en cas d'échec
  if (socket == null && ssh.alterUrl != null) {
    socket = await connect(ssh.alterUrl, ssh.port);
  }

  if (socket == null) {
    throw ConnectionException('Unable to connect');
  }

  // 3. Authentifier
  final client = SSHClient(
    socket: socket,
    username: ssh.user,
    onPasswordRequest: () => ssh.pwd,
    onIdentityRequest: () => loadKey(ssh.keyId),
  );

  // 4. Vérifier la clé d'hôte
  await verifyHostKey(client, spi);

  return client;
}
```

### Étape 3 : D'où vient le socket

`genClient` résout l'une des trois sources ; tout ce qui se trouve au-dessus de
`SSHSocket` est identique dans les trois cas :

**Direct** — par défaut, `SSHSocket.connect(ip, port)`, avec repli sur
`alterUrl` en cas d'échec.

**Serveur de rebond** — connexion récursive, puis une redirection locale :

```dart
for (final jumpId in spi.resolvedJumpIds) {
  final jumpClient = await genClient(getJumpSpi(jumpId));
  return await jumpClient.forwardLocal(ssh.ip, ssh.port);
}
```

**ProxyCommand** — bureau uniquement, puisqu'un processus est lancé :

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

## Méthodes d'authentification

### Authentification par mot de passe

```dart
onPasswordRequest: () => ssh.pwd
```

- Mot de passe stocké chiffré dans Hive
- Déchiffré lors de la connexion
- Envoyé au serveur pour vérification

### Authentification par clé privée

```dart
onIdentityRequest: () async {
  final key = await PrivateKeyStore.get(ssh.keyId);
  return decyptPem(key.pem, key.password);
}
```

**Processus de chargement de la clé :**
1. Récupérer la clé chiffrée depuis `PrivateKeyStore`
2. Déchiffrer le mot de passe (biométrie/invite)
3. Analyser le format PEM
4. Standardiser les fins de ligne (LF)
5. Retourner pour l'authentification

### Keyboard-Interactive

```dart
onUserInfoRequest: (instructions) async {
  // Gérer le challenge-response
  return responses;
}
```

Supporte :
- L'authentification par mot de passe
- Les jetons OTP
- L'authentification à deux facteurs (2FA)

## Vérification de la clé d'hôte

### Pourquoi vérifier les clés d'hôte ?

Empêche les attaques de type **Man-in-the-Middle (MITM)** en s'assurant que vous vous connectez au même serveur.

### Format de stockage

```text
{spi.id}::{keyType}
```

Exemple :
```text
mon-serveur::ssh-ed25519
mon-serveur::ecdsa-sha2-nistp256
```

### Formats d'empreinte

**MD5 Hex :**
```text
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64 :**
```text
SHA256:AbCdEf1234567890...=
```

### Flux de vérification

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final keyType = key.type;
  final fingerprint = md5Hex(key); // ou base64

  final stored = SettingStore.sshKnownHostFingerprints
      ['${spi.id}::$keyType'];

  if (stored == null) {
    // Nouvel hôte - inviter l'utilisateur
    final trust = await promptUser(
      'Hôte inconnu',
      'Empreinte : $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostFingerprints
          ['${spi.id}::$keyType'] = fingerprint;
    }
  } else if (stored != fingerprint) {
    // Modifié - avertir l'utilisateur
    await warnUser(
      'La clé d\'hôte a changé !',
      'Attaque MITM possible',
    );
  }
}
```

## Gestion des sessions

### Mise en commun des connexions (Pooling)

Clients actifs maintenus dans `ServerProvider` :

```dart
class ServerProvider {
  final Map<String, SSHClient> _clients = {};

  SSHClient getClient(String spiId) {
    return _clients[spiId] ??= connect(spiId);
  }
}
```

### Keep-Alive

Maintenir la connexion pendant l'inactivité :

```dart
Timer.periodic(
  Duration(seconds: 30),
  (_) => client.sendKeepAlive(),
);
```

### Reconnexion automatique

En cas de perte de connexion :

```dart
client.onError.listen((error) async {
  await Future.delayed(Duration(seconds: 5));
  reconnect();
});
```

## Cycle de vie de la connexion

```text
┌─────────────┐
│   Initial   │
└──────┬──────┘
       │ connect()
       ↓
┌─────────────┐
│ Connexion   │ ←──┐
└──────┬──────┘   │
       │ succès   │
       ↓          │ échec (retry)
┌─────────────┐   │
│  Connecté   │───┘
└──────┬──────┘
       │
       ↓
┌─────────────┐
│    Actif    │ ──→ Envoyer des commandes
└──────┬──────┘
       │
       ↓ (erreur/déconnexion)
┌─────────────┐
│ Déconnecté  │
└─────────────┘
```

## Gestion des erreurs

### Délai d'attente de connexion (Timeout)

```dart
try {
  await client.connect().timeout(
    Duration(seconds: 30),
  );
} on TimeoutException {
  throw ConnectionException('Délai d\'attente de connexion dépassé');
}
```

### Échec d'authentification

```dart
onAuthFail: (error) {
  if (error.contains('password')) {
    return 'Mot de passe invalide';
  } else if (error.contains('key')) {
    return 'Clé SSH invalide';
  }
  return 'Authentification échouée';
}
```

### Discordance de clé d'hôte

```dart
onHostKeyMismatch: (stored, current) {
  showSecurityWarning(
    'La clé d\'hôte a changé !',
    'Attaque MITM possible',
  );
}
```

## Considérations de performance

### Réutilisation de la connexion

- Réutiliser les clients entre les fonctionnalités
- Ne pas déconnecter/reconnecter inutilement
- Mutualiser les connexions pour les opérations simultanées

### Paramètres optimaux

- **Timeout** : 30 secondes (ajustable)
- **Keep-alive** : Toutes les 30 secondes
- **Délai de relecture** : 5 secondes

### Efficacité du réseau

- Connexion unique pour plusieurs opérations
- Commandes en pipeline si possible
- Éviter d'ouvrir plusieurs connexions
