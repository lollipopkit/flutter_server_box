---
title: Connexion SSH
description: Comment les connexions SSH sont établies et gérées
---

Comprendre les connexions SSH dans Server Box.

## Flux de connexion

```
Entrée utilisateur → Configuration Spi → genClient() → Client SSH → Session
```

### Étape 1 : Configuration

Le modèle `Spi` (Server Parameter Info) contient :

```dart
class Spi {
  String name;       // Nom du serveur
  String ip;         // Adresse IP
  int port;          // Port SSH (par défaut 22)
  String user;       // Nom d'utilisateur
  String? pwd;       // Mot de passe (chiffré)
  String? keyId;     // ID de la clé SSH
  String? jumpId;    // ID du serveur de rebond (Jump server)
  String? alterUrl;  // URL alternative
}
```

### Étape 2 : Génération du client

`genClient(spi)` crée le client SSH :

```dart
Future<SSHClient> genClient(Spi spi) async {
  // 1. Établir le socket
  var socket = await connect(spi.ip, spi.port);

  // 2. Essayer l'URL alternative en cas d'échec
  if (socket == null && spi.alterUrl != null) {
    socket = await connect(spi.alterUrl, spi.port);
  }

  if (socket == null) {
    throw ConnectionException('Unable to connect');
  }

  // 3. Authentifier
  final client = SSHClient(
    socket: socket,
    username: spi.user,
    onPasswordRequest: () => spi.pwd,
    onIdentityRequest: () => loadKey(spi.keyId),
  );

  // 4. Vérifier la clé d'hôte
  await verifyHostKey(client, spi);

  return client;
}
```

### Étape 3 : Serveur de rebond (si configuré)

Pour les serveurs de rebond, connexion récursive :

```dart
if (spi.jumpId != null) {
  final jumpClient = await genClient(getJumpSpi(spi.jumpId));
  final forwarded = await jumpClient.forwardLocal(
    spi.ip,
    spi.port,
  );
  // Se connecter via le socket transféré
}
```

## Méthodes d'authentification

### Authentification par mot de passe

```dart
onPasswordRequest: () => spi.pwd
```

- Mot de passe stocké chiffré dans Hive
- Déchiffré lors de la connexion
- Envoyé au serveur pour vérification

### Authentification par clé privée

```dart
onIdentityRequest: () async {
  final key = await KeyStore.get(spi.keyId);
  return decyptPem(key.pem, key.password);
}
```

**Processus de chargement de la clé :**
1. Récupérer la clé chiffrée depuis `KeyStore`
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

```
{spi.id}::{keyType}
```

Exemple :
```
mon-serveur::ssh-ed25519
mon-serveur::ecdsa-sha2-nistp256
```

### Formats d'empreinte

**MD5 Hex :**
```
aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99
```

**Base64 :**
```
SHA256:AbCdEf1234567890...=
```

### Flux de vérification

```dart
Future<void> verifyHostKey(SSHClient client, Spi spi) async {
  final key = await client.hostKey;
  final keyType = key.type;
  final fingerprint = md5Hex(key); // ou base64

  final stored = SettingStore.sshKnownHostsFingerprints
      ['${spi.id}::$keyType'];

  if (stored == null) {
    // Nouvel hôte - inviter l'utilisateur
    final trust = await promptUser(
      'Hôte inconnu',
      'Empreinte : $fingerprint',
    );
    if (trust) {
      SettingStore.sshKnownHostsFingerprints
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

```
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
