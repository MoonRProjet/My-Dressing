# 👗 My Dressing - Smart Virtual Wardrobe

**My Dressing** est une application Flutter innovante conçue pour numériser, organiser et styliser votre garde-robe. Développée dans le cadre d'un stage **R&T**, l'application intègre des technologies d'Intelligence Artificielle pour automatiser les tâches fastidieuses et offrir une expérience utilisateur fluide.

## ✨ Fonctionnalités Majeures

### 🤖 Intelligence Artificielle & Traitement d'Image
- **Détourage Automatique** : Intégration de l'API **Remove.bg** via RapidAPI pour supprimer l'arrière-plan des vêtements en un clic.[cite: 1]
- **Détection Chromatique HSL** : Analyse locale de l'image (via `palette_generator`) pour identifier la couleur dominante.[cite: 1]
- **Filtres Dynamiques** : Le système génère des filtres de recherche uniquement pour les couleurs présentes dans votre dressing.[cite: 1]
- **Algorithme de Teinte** : Utilisation du modèle **HSL** (Hue, Saturation, Lightness) pour regrouper intelligemment les vêtements par familles de couleurs (ex: regrouper les nuances de bleu ou de noir).[cite: 1]

### 🛠 Gestion du Dressing
- **Inventaire Complet** : Classement par catégories (Hauts, Bas, Chaussures) et sous-catégories personnalisables.[cite: 1]
- **Mémoire des Marques** : Système d'auto-complétion qui retient vos marques préférées pour accélérer la saisie des nouveaux articles.[cite: 1]
- **Lookbook Interactif** : Canevas de montage permettant de glisser, redimensionner et superposer vos vêtements pour créer des tenues.[cite: 1]
- **Statistiques** : Visualisation de la répartition de votre garde-robe par catégorie.[cite: 1]

## 🚀 Aspects Techniques (Stage R&T)
- **Langage** : Dart / Flutter.[cite: 1]
- **Persistance** : Stockage local des données et des chemins d'images via `shared_preferences`.[cite: 1]
- **Réseau** : Communication asynchrone avec des API REST (Multipart requests).[cite: 1]
- **Qualité du code** : Code structuré, respectant les normes de sécurité (mounted checks) et "Zero Warnings".[cite: 1]

## 📦 Installation

1. **Cloner le projet**
   ```bash
   git clone [https://github.com/votre-username/my-dressing.git](https://github.com/votre-username/my-dressing.git)
