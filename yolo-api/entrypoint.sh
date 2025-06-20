#!/bin/bash

# Activation de l'environnement YOLO
cd /app/yolov8

# Lancer le serveur Flask pour exposer YOLOv8 comme API
python detect.py --source 0 --weights yolov8n.pt --conf 0.5 --save-txt
