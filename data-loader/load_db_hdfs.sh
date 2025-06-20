#!/bin/bash

set -e

# Répertoires locaux
DATA_DIR="/datasets"
TEXT_DIR="$DATA_DIR/text"
IMAGE_DIR="$DATA_DIR/images"

# Répertoires HDFS
HDFS_TEXT_DIR="/data/text"
HDFS_IMAGE_DIR="/data/images"

echo "📦 Création des dossiers locaux..."
mkdir -p "$TEXT_DIR" "$IMAGE_DIR"

# Attente du démarrage de HDFS
echo "⏳ Attente du NameNode HDFS..."
until hdfs dfs -ls / > /dev/null 2>&1; do
    echo "🔄 HDFS non encore disponible, on attend..."
    sleep 5
done
echo "✅ HDFS est prêt !"

# Vérifie si kaggle CLI est dispo
if ! command -v kaggle &> /dev/null; then
    echo "❌ Kaggle CLI non installée"
    exit 1
fi

# Téléchargement des datasets
echo "⬇️ Téléchargement des datasets..."
kaggle datasets download -d snap/amazon-fine-food-reviews -p "$TEXT_DIR" --force
kaggle datasets download -d jessicali9530/celeba-dataset -p "$IMAGE_DIR" --force

# Extraction
echo "🗂️ Extraction des fichiers..."
unzip -o "$TEXT_DIR/amazon-fine-food-reviews.zip" -d "$TEXT_DIR"
unzip -o "$IMAGE_DIR/celeba-dataset.zip" -d "$IMAGE_DIR"

# Création des dossiers HDFS
echo "📁 Création des répertoires HDFS..."
hdfs dfs -mkdir -p "$HDFS_TEXT_DIR"
hdfs dfs -mkdir -p "$HDFS_IMAGE_DIR"

# Envoi vers HDFS
echo "🚀 Envoi des données vers HDFS..."
hdfs dfs -put -f "$TEXT_DIR/Reviews.csv" "$HDFS_TEXT_DIR/"
hdfs dfs -put -f "$IMAGE_DIR/img_align_celeba.zip" "$HDFS_IMAGE_DIR/"

echo "✅ Données chargées dans HDFS avec succès !"
