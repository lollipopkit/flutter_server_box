---
title: Extraits (Snippets)
description: Enregistrer et exécuter des commandes shell personnalisées
---

Les extraits (Snippets) vous permettent d'enregistrer les commandes shell fréquemment utilisées pour une exécution rapide.

## Créer des extraits

1. Allez dans l'onglet **Snippets**
2. Appuyez sur le bouton **+**
3. Remplissez les détails de l'extrait :
   - **Nom** : Nom convivial pour l'extrait
   - **Commande** : La commande shell à exécuter
   - **Description** : Notes facultatives
4. Enregistrez l'extrait

## Utiliser des extraits

1. Ouvrez un serveur
2. Appuyez sur le bouton **Snippet**
3. Sélectionnez un extrait à exécuter
4. Visualisez la sortie dans le terminal

## Fonctionnalités des extraits

- **Exécution rapide** : Exécution de la commande en un seul appui
- **Variables** : Utiliser des variables spécifiques au serveur
- **Organisation** : Grouper les extraits associés
- **Import/Export** : Partager des extraits entre appareils
- **Synchronisation** : Synchronisation cloud facultative

## Exemples d'extraits

### Mise à jour du système
```bash
sudo apt update && sudo apt upgrade -y
```

### Nettoyage du disque
```bash
sudo apt autoremove -y && sudo apt clean
```

### Nettoyage Docker
```bash
docker system prune -a
```

### Voir les logs système
```bash
journalctl -n 50 -f
```

## Conseils

- Utilisez des **noms descriptifs** pour une identification facile
- Ajoutez des **commentaires** pour les commandes complexes
- Testez les commandes avant de les enregistrer comme extraits
- Organisez les extraits par catégorie ou par type de serveur
