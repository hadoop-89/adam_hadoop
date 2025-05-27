#!/bin/bash

# Script de test pour vérifier le fonctionnement de l'infrastructure Hadoop

echo "=== Test de l'infrastructure Hadoop ==="

# 1. Vérification de l'état des conteneurs
echo "Vérification des conteneurs Docker..."
docker-compose ps

# 2. Test HDFS
echo ""
echo "Test de HDFS - création d'un fichier test..."
echo "Ceci est un fichier test pour HDFS" > test_hdfs.txt
docker-compose exec namenode bash -c "hdfs dfs -mkdir -p /test"
docker-compose exec namenode bash -c "hdfs dfs -put /tmp/test_hdfs.txt /test/"
docker-compose exec namenode bash -c "hdfs dfs -ls /test"
docker-compose exec namenode bash -c "hdfs dfs -cat /test/test_hdfs.txt"

# 3. Test Hive
echo ""
echo "Test de Hive - création d'une table..."
docker-compose exec hive-server bash -c "beeline -u jdbc:hive2://localhost:10000 -e 'CREATE DATABASE IF NOT EXISTS test_db; USE test_db; CREATE TABLE IF NOT EXISTS test_table (id INT, name STRING);'"
docker-compose exec hive-server bash -c "beeline -u jdbc:hive2://localhost:10000 -e 'SHOW DATABASES;'"

# 4. Test Kafka
echo ""
echo "Test de Kafka - création d'un topic..."
docker-compose exec kafka bash -c "kafka-topics.sh --create --topic test-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1"
docker-compose exec kafka bash -c "kafka-topics.sh --list --bootstrap-server localhost:9092"

# 5. Envoi d'un message test à Kafka
echo ""
echo "Envoi d'un message test à Kafka..."
echo "Message test pour Kafka" | docker-compose exec -T kafka bash -c "kafka-console-producer.sh --topic test-topic --bootstrap-server localhost:9092"
echo "Lecture du message depuis Kafka..."
docker-compose exec kafka bash -c "kafka-console-consumer.sh --topic test-topic --bootstrap-server localhost:9092 --from-beginning --max-messages 1"

echo ""
echo "=== Tests terminés ==="
echo "Si tous les tests ont réussi, l'infrastructure est fonctionnelle."
