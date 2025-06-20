#!/bin/bash

set -e  # Arrêter le script en cas d'erreur

# Définition des variables
PROJECT_DIR=$(pwd)
YOLO_API_DIR="$PROJECT_DIR/yolo-api"
MODEL_URL="https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt"

# Création du répertoire yolo-api si non existant
if [ ! -d "$YOLO_API_DIR" ]; then
    echo "📂 Création du dossier yolo-api..."
    mkdir -p "$YOLO_API_DIR"
fi

# Création du fichier requirements.txt
cat <<EOF > "$YOLO_API_DIR/requirements.txt"
flask
flask-cors
ultralytics
opencv-python
numpy
torch
EOF

echo "📜 Fichier requirements.txt créé."

# Téléchargement du modèle YOLOv8 si non présent
if [ ! -f "$YOLO_API_DIR/yolov8n.pt" ]; then
    echo "📥 Téléchargement du modèle YOLOv8..."
    wget -q "$MODEL_URL" -P "$YOLO_API_DIR/"
    echo "✅ Modèle téléchargé."
else
    echo "✅ Modèle YOLOv8 déjà présent."
fi

# Vérification et lancement des conteneurs
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker n'est pas démarré. Veuillez le lancer avant d'exécuter ce script."
    exit 1
fi

echo "🚀 Démarrage des services Docker..."
docker-compose up -d

echo "✅ Installation terminée. YOLO API est accessible sur http://localhost:8000/health"
