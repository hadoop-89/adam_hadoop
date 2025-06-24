#!/bin/bash
# hive-config/init-hive-tables.sh

echo "📋 Initialisation des tables Hive..."

# Exécuter le script d'initialisation
docker exec -i hive-server beeline -u jdbc:hive2://localhost:10000 < hive-config/init-tables.sql

echo "✅ Tables Hive initialisées"

# Test des tables
echo "🧪 Test des tables créées..."
docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "
USE analytics;
SHOW TABLES;
DESCRIBE reviews;
SELECT COUNT(*) as total_reviews FROM reviews;
"

echo "🎉 Hive complètement configuré !"