---
title: Commandes personnalisées
description: Afficher la sortie des commandes personnalisées sur la page du serveur
---

Ajoutez des commandes shell personnalisées pour afficher leur sortie sur la page de détails du serveur.

## Configuration

1. Paramètres du serveur → Commandes personnalisées
2. Entrez les commandes au format JSON

## Format de base

```json
{
  "Nom d'affichage": "commande shell"
}
```

**Exemple :**
```json
{
  "Mémoire": "free -h",
  "Disque": "df -h",
  "Uptime": "uptime"
}
```

## Visualisation des résultats

Après la configuration, les commandes personnalisées apparaissent sur la page de détails du serveur et s'actualisent automatiquement.

## Noms de commandes spéciaux

### server_card_top_right

Affichage sur la carte du serveur de la page d'accueil (coin supérieur droit) :

```json
{
  "server_card_top_right": "votre-commande-ici"
}
```

## Conseils

**Utilisez des chemins absolus :**
```json
{"Mon script": "/usr/local/bin/mon-script.sh"}
```

**Commandes avec pipe :**
```json
{"Processus principal": "ps aux | sort -rk 3 | head -5"}
```

**Formater la sortie :**
```json
{"Charge CPU": "uptime | awk -F'load average:' '{print $2}'"}
```

**Gardez les commandes rapides :** Moins de 5 secondes pour une meilleure expérience.

**Limiter la sortie :**
```json
{"Logs": "tail -20 /var/log/syslog"}
```

## Sécurité

Les commandes s'exécutent avec les permissions de l'utilisateur SSH. Évitez les commandes qui modifient l'état du système.
