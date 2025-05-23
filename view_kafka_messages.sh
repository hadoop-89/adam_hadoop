#!/bin/bash

# Script pour visualiser les messages Kafka en temps réel

echo "=== Visualisation des messages Kafka (raw-data) ==="
echo "Appuyez sur Ctrl+C pour quitter"
echo ""

# Vérifier si le topic existe
TOPIC_EXISTS=$(docker-compose exec -T kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092 | grep raw-data")

if [ -z "$TOPIC_EXISTS" ]; then
    echo "Le topic 'raw-data' n'existe pas encore."
    echo "Création du topic 'raw-data'..."
    docker-compose exec kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --create --topic raw-data --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1"
fi

echo "Attente des messages sur le topic 'raw-data'..."
echo "Appuyez sur Ctrl+C pour quitter le mode de lecture."
docker-compose exec kafka bash -c "/opt/bitnami/kafka/bin/kafka-console-consumer.sh --topic raw-data --bootstrap-server localhost:9092 --from-beginning"
