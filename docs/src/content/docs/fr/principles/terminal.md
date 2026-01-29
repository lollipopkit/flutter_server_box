---
title: Implémentation du terminal
description: Comment le terminal SSH fonctionne en interne
---

Le terminal SSH est l'une des fonctionnalités les plus complexes, basée sur un fork personnalisé de xterm.dart.

## Présentation de l'architecture

```
┌─────────────────────────────────────────────┐
│          Couche UI du terminal              │
│  - Gestion des onglets                      │
│  - Clavier virtuel                          │
│  - Sélection de texte                       │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│         Émulateur xterm.dart                │
│  - PTY (Pseudo Terminal)                    │
│  - Émulation VT100/ANSI                     │
│  - Moteur de rendu                          │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          Couche client SSH                  │
│  - Session SSH                              │
│  - Gestion des canaux                       │
│  - Streaming de données                     │
└─────────────────────────────────────────────┘
                ↓
┌─────────────────────────────────────────────┐
│          Serveur distant                    │
│  - Processus Shell                          │
│  - Exécution de commandes                   │
└─────────────────────────────────────────────┘
```

## Cycle de vie d'une session de terminal

### 1. Création de la session

```dart
Future<TerminalSession> createSession(Spi spi) async {
  // 1. Obtenir le client SSH
  final client = await genClient(spi);

  // 2. Créer le PTY
  final pty = await client.openPty(
    term: 'xterm-256color',
    cols: 80,
    rows: 24,
  );

  // 3. Initialiser l'émulateur de terminal
  final terminal = Terminal(
    backend: PtyBackend(pty),
  );

  // 4. Configurer le gestionnaire de redimensionnement
  terminal.onResize.listen((size) {
    pty.resize(size.cols, size.rows);
  });

  return TerminalSession(
    terminal: terminal,
    pty: pty,
    client: client,
  );
}
```

### 2. Émulation de terminal

Le fork xterm.dart fournit :

**Émulation VT100/ANSI :**
- Mouvement du curseur
- Couleurs (support 256 couleurs)
- Attributs de texte (gras, souligné, etc.)
- Régions de défilement
- Tampon d'écran alterné

**Rendu :**
- Rendu basé sur les lignes
- Support du texte bidirectionnel
- Support Unicode/emoji
- Redessins optimisés

### 3. Flux de données

```
Entrée utilisateur
    ↓
Clavier virtuel / Clavier physique
    ↓
Émulateur de terminal (touche → séquence d'échappement)
    ↓
Canal SSH (envoi)
    ↓
PTY distant
    ↓
Shell distant
    ↓
Sortie de commande
    ↓
Canal SSH (réception)
    ↓
Émulateur de terminal (analyse des codes ANSI)
    ↓
Rendu à l'écran
```

## Système multi-onglets

### Gestion des onglets

Les onglets maintiennent leur état lors de la navigation :
- Connexion SSH maintenue active
- État du terminal préservé
- Tampon de défilement conservé
- Historique de saisie retenu

## Clavier virtuel

### Implémentation spécifique à la plateforme

**iOS :**
- Clavier personnalisé basé sur UIView
- Basculable avec un bouton clavier
- Affichage/masquage automatique basé sur le focus

**Android :**
- Méthode de saisie personnalisée
- Intégré au clavier système
- Boutons d'action rapide

### Boutons du clavier

| Bouton | Action |
|--------|--------|
| **Basculer** | Afficher/masquer le clavier système |
| **Ctrl** | Envoyer le modificateur Ctrl |
| **Alt** | Envoyer le modificateur Alt |
| **SFTP** | Ouvrir le répertoire courant |
| **Presse-papiers** | Copier/Coller contextuel |
| **Snippets** | Exécuter un extrait de code |

## Sélection de texte

1. **Appui long** : Entrer en mode sélection
2. **Glisser** : Étendre la sélection
3. **Relâcher** : Copier dans le presse-papiers

## Police et dimensions

### Calcul de la taille

```dart
class TerminalDimensions {
  static Size calculate(double fontSize, Size screenSize) {
    final charWidth = fontSize * 0.6;  // Ratio d'aspect monospace
    final charHeight = fontSize * 1.2;

    final cols = (screenSize.width / charWidth).floor();
    final rows = (screenSize.height / charHeight).floor();

    return Size(cols.toDouble(), rows.toDouble());
  }
}
```

### Pincer pour zoomer (Pinch-to-Zoom)

```dart
GestureDetector(
  onScaleStart: () => _baseFontSize = currentFontSize,
  onScaleUpdate: (details) {
    final newFontSize = _baseFontSize * details.scale;
    resize(newFontSize);
  },
)
```

## Schéma de couleurs

- **Clair (Light)** : Fond clair, texte sombre
- **Sombre (Dark)** : Fond sombre, texte clair
- **AMOLED** : Fond noir pur

## Optimisations de performance

- **Dirty rectangle** : Ne redessiner que les régions modifiées
- **Mise en cache des lignes** : Mettre en cache les lignes rendues
- **Défilement paresseux (Lazy scrolling)** : Défilement virtuel pour les longs tampons
- **Mises à jour par lots** : Fusionner plusieurs écritures
- **Compression** : Compresser le tampon de défilement
- **Anti-rebond (Debouncing)** : Anti-rebond pour les saisies rapides
