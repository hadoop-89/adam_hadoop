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

# Création de données de test réalistes
echo "🗂️ Création de données de test..."
cat > "$TEXT_DIR/reviews.csv" << 'DATA'
review_id,review_text,rating
1,"This product is absolutely amazing! Great quality and fast shipping.",5
2,"Terrible experience. Product broke after one day. Very disappointed.",1
3,"Average product. Nothing special but does what it's supposed to do.",3
4,"Excellent customer service and fantastic features. Highly recommend!",5
5,"Poor quality for the price. Would not buy again.",2
6,"Perfect! Exactly what I was looking for. Fast delivery too.",5
7,"Product is okay but could be better. Mediocre experience overall.",3
8,"Outstanding quality and value. Best purchase I've made this year!",5
DATA

# Création des répertoires HDFS
echo "📁 Création des répertoires HDFS..."
hdfs dfs -mkdir -p "$HDFS_TEXT_DIR"
hdfs dfs -mkdir -p "$HDFS_IMAGE_DIR"

# Envoi vers HDFS
echo "🚀 Envoi des données vers HDFS..."
hdfs dfs -put -f "$TEXT_DIR/reviews.csv" "$HDFS_TEXT_DIR/"

# Vérification
echo "✅ Données chargées dans HDFS avec succès !"
hdfs dfs -ls "$HDFS_TEXT_DIR"
hdfs dfs -cat "$HDFS_TEXT_DIR/reviews.csv" | head -3

echo "📊 Résumé des données chargées:"
echo "- Fichier texte: reviews.csv (8 reviews)"
echo "- Localisation HDFS: $HDFS_TEXT_DIR/reviews.csv"
