#!/bin/bash

# Script de test pour vérifier uniquement l'infrastructure Hadoop (sans API IA)

echo "=== Test de l'infrastructure Hadoop (sans API IA) ==="

# 1. Vérification de l'état des conteneurs principaux
echo "Vérification des conteneurs Hadoop..."
docker-compose ps namenode datanode1 datanode2 hive-server spark-master kafka

echo ""
echo "=== Tests HDFS ==="
# 2. Test HDFS - Création d'un répertoire et fichier
echo "Création d'un fichier test pour HDFS..."
echo "Ceci est un fichier test pour HDFS" > test_hdfs.txt
docker-compose exec -T namenode bash -c "cat > /tmp/test_hdfs.txt" < test_hdfs.txt
docker-compose exec namenode bash -c "hdfs dfs -mkdir -p /test"
echo "Copie du fichier vers HDFS..."
docker-compose exec namenode bash -c "hdfs dfs -put /tmp/test_hdfs.txt /test/"
echo "Vérification du fichier dans HDFS..."
docker-compose exec namenode bash -c "hdfs dfs -ls /test"
echo "Contenu du fichier dans HDFS:"
docker-compose exec namenode bash -c "hdfs dfs -cat /test/test_hdfs.txt"

echo ""
echo "=== Tests Hive ==="
# 3. Test Hive - Création d'une base de données et table
echo "Création d'une base de données et table Hive..."
docker-compose exec hive-server bash -c "beeline -u jdbc:hive2://localhost:10000 -e 'CREATE DATABASE IF NOT EXISTS test_db; USE test_db; CREATE TABLE IF NOT EXISTS test_table (id INT, name STRING);'"
echo "Liste des bases de données Hive:"
docker-compose exec hive-server bash -c "beeline -u jdbc:hive2://localhost:10000 -e 'SHOW DATABASES;'"
echo "Insertion de données test dans Hive:"
docker-compose exec hive-server bash -c "beeline -u jdbc:hive2://localhost:10000 -e 'USE test_db; INSERT INTO test_table VALUES (1, \"test1\"), (2, \"test2\");'"
echo "Vérification des données dans Hive:"
docker-compose exec hive-server bash -c "beeline -u jdbc:hive2://localhost:10000 -e 'USE test_db; SELECT * FROM test_table;'"

echo ""
echo "=== Tests Kafka ==="
# 4. Test Kafka - Création d'un topic et envoi/réception de message
echo "Création d'un topic Kafka 'test-topic'..."
docker-compose exec kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --create --topic test-topic --bootstrap-server localhost:9092 --partitions 1 --replication-factor 1 2>/dev/null || echo 'Le topic existe déjà'"
echo "Liste des topics Kafka:"
docker-compose exec kafka bash -c "/opt/bitnami/kafka/bin/kafka-topics.sh --list --bootstrap-server localhost:9092"
echo "Envoi d'un message test à Kafka..."
echo "Message test pour Kafka - $(date)" | docker-compose exec -T kafka bash -c "/opt/bitnami/kafka/bin/kafka-console-producer.sh --topic test-topic --bootstrap-server localhost:9092"
echo "Lecture du message depuis Kafka (attendre quelques secondes)..."
docker-compose exec kafka bash -c "/opt/bitnami/kafka/bin/kafka-console-consumer.sh --topic test-topic --bootstrap-server localhost:9092 --from-beginning --max-messages 1 --timeout-ms 5000"

echo ""
echo "=== Test Spark ==="
# 5. Test de Spark - Vérification de l'état via l'API REST
echo "Vérification de l'état du cluster Spark..."
curl -s http://localhost:8080/json/ | grep -q "status\": \"ALIVE" && echo "✅ Spark Master est ACTIF" || echo "❌ Spark Master n'est pas en bon état"

echo ""
echo "=== Tous les tests sont terminés ==="
echo "Si tous les tests ont réussi, votre infrastructure Hadoop est fonctionnelle!"
echo ""
echo "Vous pouvez maintenant:"
echo "1. Explorer les interfaces Web pour HDFS, Hive et Spark"
echo "2. Démarrer le service d'ingestion de données: docker-compose up -d data-ingestion"
echo "3. Visualiser et explorer les données dans HDFS et Hive"
