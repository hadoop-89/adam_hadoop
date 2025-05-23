# Projet Hadoop et IA

## Objectif Global

Le but global est de développer un projet complet de gestion de grandes bases de données et d'utilisation de modèles d'intelligence artificielle. Le projet est divisé en deux grandes parties :

1. **Projet Hadoop** (Infrastructure et traitement des données)
2. **Projet IA** (Développement d'une API pour un LLM et un modèle d'images)

---

## Projet Hadoop : Infrastructure et Traitement des Données

### 1. Déploiement Hadoop & Stockage
- Architecture Hadoop avec Docker compose (nombre de nœuds DataNode modulable).
- Choix libre des bases de données (Hive, HBase, etc.).
- Automatisation de l'installation avec Ansible.

### 2. Ingestion et streaming des données
- Scraping web en temps réel (Kafka + Spark Streaming conseillé).
- Transformation et stockage des données dans Hadoop.

### 3. Prétraitement des données (avant envoi à l'API IA)
- Nettoyage des bases de données (texte et image).
- Tokenisation des textes (possibilité de traitement côté API).
- Conversion des images en tableau d'octets pour optimisation.

### 4. Interaction avec l'API IA
- Envoi des données textes et images via l'API IA.
- Stockage des résultats IA dans une base de données exploitables.

### 5. DevOps & Automatisation
- Pipeline CI/CD (GitLab CI/GitHub Actions).
- Monitoring, logging, testing.
- Optionnel : déploiement automatique via Docker.

### 6. Visualisation & Exploitation
- Tableaux de bord pour visualiser les analyses des données.
- Optionnel : visualisation générale des informations des bases de données.

---

## Projet IA : API pour LLM & Vision

### 1. Développement de l’API IA
- API REST commune (point d'entrée unique).
- Déploiement avec FastAPI ou Flask.
- Retour des données dans un format optimisé.

### 2. Modèle IA
- Fine-tuning LLM (GPT/BERT) pour :
  - Classification des sujets
  - Résumé automatique
  - Analyse de sentiment
- Adaptation modèle YOLO pour la détection d'images.

### 3. Ré-entraînement du modèle YOLO avec images scrapées
- Récupération depuis Hadoop.
- Prétraitement des images (redimensionnement, conversion, nettoyage).
- Génération des annotations (manuelle ou semi-automatique).
- Fine-tuning YOLO (référence : [Ultralytics training](https://docs.ultralytics.com/fr/modes/train/)).

### 4. DevOps & Industrialisation
- Pipeline CI/CD pour IA (GitLab CI/GitHub Actions).
- Monitoring, logging, testing.
- Déploiement automatique (image Docker).

---

## Rédaction du Rapport
- Présentation du projet et architecture globale.
- Pour Hadoop : architecture, choix des bases de données, stratégie scraping, analyse performance.
- Pour IA : architecture API, choix framework, présentation et analyse performance des modèles.
- Présentation stratégie DevOps et CI/CD.

---

## Livrables attendus
- Rapport document Word ou PDF.
- 2 repositories GitHub (codes Hadoop et IA en anglais).

---

## Deadline
- Rapport : 3 Juin 2025 (23h59).
- Code : 12 Juin 2025 (23h59).
- Soutenance : 13 Juin 2025 (9h-12h30 et 14h-17h30).

