#!/bin/bash

# Script de démarrage pour le projet Hadoop

echo "=== Démarrage du projet Hadoop ==="
echo "Ce script va lancer l'ensemble de l'infrastructure Hadoop"

# Vérification de Docker et Docker Compose
if ! command -v docker &> /dev/null; then
    echo "Docker n'est pas installé. Veuillez installer Docker."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose n'est pas installé. Veuillez installer Docker Compose."
    exit 1
fi

# Démarrage du cluster Hadoop
echo "Démarrage du cluster Hadoop..."
docker-compose up -d

# Attendre que les services soient disponibles
echo "Attente du démarrage des services (30 secondes)..."
sleep 30

# Vérification des services
echo "Vérification des services..."

# Vérifier HDFS NameNode
if curl -s "http://localhost:9870" > /dev/null; then
    echo "✅ HDFS NameNode est opérationnel"
else 
    echo "❌ HDFS NameNode n'est pas accessible"
fi

# Vérifier Hive
if curl -s "http://localhost:10002" > /dev/null; then
    echo "✅ Hive est opérationnel"
else
    echo "❌ Hive n'est pas accessible"
fi

# Vérifier Kafka
if nc -z localhost 9092; then
    echo "✅ Kafka est opérationnel"
else
    echo "❌ Kafka n'est pas accessible"
fi

# Vérifier Spark Master
if curl -s "http://localhost:8080" > /dev/null; then
    echo "✅ Spark Master est opérationnel"
else
    echo "❌ Spark Master n'est pas accessible"
fi

# Vérifier Grafana
if curl -s "http://localhost:3000" > /dev/null; then
    echo "✅ Grafana est opérationnel"
else
    echo "❌ Grafana n'est pas accessible"
fi

# Vérifier Prometheus
if curl -s "http://localhost:9090" > /dev/null; then
    echo "✅ Prometheus est opérationnel"
else
    echo "❌ Prometheus n'est pas accessible"
fi

echo ""
echo "=== Accès aux interfaces ==="
echo "HDFS NameNode:     http://localhost:9870"
echo "Hive:              http://localhost:10002"
echo "Spark Master:      http://localhost:8080"
echo "Grafana:           http://localhost:3000"
echo "Prometheus:        http://localhost:9090"
echo "Dashboard:         http://localhost:8050"
echo ""

echo "Pour démarrer les services d'ingestion et de traitement, exécutez:"
echo "docker-compose up data-ingestion data-processing api-interaction visualization"
echo ""

echo "Pour arrêter tous les services:"
echo "docker-compose down"
echo ""
