#!/bin/bash

# Script pour lancer uniquement l'infrastructure Hadoop sans API IA

echo "=== Démarrage de l'infrastructure Hadoop (sans API IA) ==="

# Vérification de Docker
if ! command -v docker &> /dev/null; then
    echo "Docker n'est pas installé. Veuillez installer Docker."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose n'est pas installé. Veuillez installer Docker Compose."
    exit 1
fi

# Arrêt et nettoyage des conteneurs précédents (si nécessaire)
echo "Arrêt des conteneurs existants (si présents)..."
docker-compose down --remove-orphans

# Pull des images avant de démarrer (pour éviter les timeouts)
echo "Récupération des images Docker (cela peut prendre quelques minutes)..."
docker-compose pull namenode datanode1 datanode2 zookeeper kafka

# Démarrer les services par étapes pour éviter les problèmes de dépendance
echo "Démarrage de ZooKeeper..."
docker-compose up -d zookeeper
sleep 10

echo "Démarrage de Kafka..."
docker-compose up -d kafka
sleep 10

echo "Démarrage du cluster HDFS (NameNode et DataNodes)..."
docker-compose up -d namenode datanode1 datanode2
sleep 15

echo "Démarrage des services Hive..."
docker-compose up -d hive-metastore-postgresql hive-metastore hive-server
sleep 15

echo "Démarrage du cluster Spark..."
docker-compose up -d spark-master spark-worker-1
sleep 10

echo "Démarrage des outils de monitoring..."
docker-compose up -d grafana prometheus

# Attendre que les services démarrent
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
if docker-compose ps kafka | grep -q "Up"; then
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

echo ""
echo "=== Accès aux interfaces ==="
echo "HDFS NameNode:     http://localhost:9870"
echo "Hive:              http://localhost:10002"
echo "Spark Master:      http://localhost:8080"
echo "Grafana:           http://localhost:3000"
echo "Prometheus:        http://localhost:9090"
echo ""

echo "Pour tester l'infrastructure Hadoop, exécutez:"
echo "bash test_hadoop_only.sh"
echo ""

echo "Pour démarrer l'ingestion de données sans l'API IA:"
echo "docker-compose up -d data-ingestion"
echo ""

echo "Pour arrêter tous les services:"
echo "docker-compose down"
echo ""
