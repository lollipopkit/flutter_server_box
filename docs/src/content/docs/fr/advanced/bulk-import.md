---
title: Importation massive de serveurs
description: Importer plusieurs serveurs à partir d'un fichier JSON
---

Importez plusieurs configurations de serveur en une seule fois à l'aide d'un fichier JSON.

## Format JSON

:::danger[Avertissement de sécurité]
**Ne stockez jamais de mots de passe en clair dans des fichiers !** Cet exemple JSON montre un champ de mot de passe à des fins de démonstration uniquement, mais vous devriez :

- **Préférer les clés SSH** (`keyId`) au lieu de `pwd` - elles sont plus sûres
- **Utiliser des gestionnaires de mots de passe** ou des variables d'environnement si vous devez utiliser des mots de passe
- **Supprimer le fichier immédiatement** après l'importation - ne laissez pas traîner des identifiants
- **Ajouter au .gitignore** - ne validez jamais de fichiers d'identifiants dans le contrôle de version
:::

```json
[
  {
    "name": "Mon serveur",
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

## Champs

| Champ | Requis | Description |
|-------|----------|-------------|
| `name` | Oui | Nom d'affichage |
| `ip` | Oui | Domaine ou adresse IP |
| `port` | Oui | Port SSH (généralement 22) |
| `user` | Oui | Nom d'utilisateur SSH |
| `pwd` | Non | Mot de passe (à éviter - utilisez plutôt des clés SSH) |
| `keyId` | Non | Nom de la clé SSH (à partir des clés privées - recommandé) |
| `tags` | Non | Tags d'organisation |
| `autoConnect` | Non | Connexion automatique au démarrage |

## Étapes d'importation

1. Créer un fichier JSON avec les configurations de serveur
2. Paramètres → Sauvegarde → Importation massive de serveurs
3. Sélectionnez votre fichier JSON
4. Confirmez l'importation

## Exemple

```json
[
  {
    "name": "Production",
    "ip": "prod.example.com",
    "port": 22,
    "user": "admin",
    "keyId": "my-key",
    "tags": ["production", "web"]
  },
  {
    "name": "Développement",
    "ip": "dev.example.com",
    "port": 2222,
    "user": "dev",
    "keyId": "dev-key",
    "tags": ["development"]
  }
]
```

## Conseils

- **Utilisez des clés SSH** au lieu de mots de passe lorsque cela est possible
- **Testez la connexion** après l'importation
- **Organisez avec des tags** pour une gestion plus facile
- **Supprimez le fichier JSON** après l'importation
- **Ne validez jamais** de fichiers JSON contenant des identifiants dans le contrôle de version
