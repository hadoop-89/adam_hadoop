#!/bin/bash

set -e  # Stop the script on error

# Define variables
PROJECT_DIR=$(pwd)
YOLO_API_DIR="$PROJECT_DIR/yolo-api"
MODEL_URL="https://github.com/ultralytics/assets/releases/download/v0.0.0/yolov8n.pt"

# Create yolo-api directory if it doesn't exist
if [ ! -d "$YOLO_API_DIR" ]; then
    echo "📂 Creating yolo-api directory..."
    mkdir -p "$YOLO_API_DIR"
fi

# Create requirements.txt file
cat <<EOF > "$YOLO_API_DIR/requirements.txt"
flask
flask-cors
ultralytics
opencv-python
numpy
torch
EOF

echo "📜 requirements.txt file created."

# Download YOLOv8 model if not present
if [ ! -f "$YOLO_API_DIR/yolov8n.pt" ]; then
    echo "📥 Downloading YOLOv8 model..."
    wget -q "$MODEL_URL" -P "$YOLO_API_DIR/"
    echo "✅ Model downloaded."
else
    echo "✅ YOLOv8 model already present."
fi

# Check and start containers
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start it before running this script."
    exit 1
fi

echo "🚀 Starting Docker services..."
docker-compose up -d

echo "✅ Installation and configuration completed! YOLO API is accessible at http://localhost:8000/health"
