#!/bin/bash
# hive-config/init-hive-tables.sh

echo "📋 Initializing Hive Tables..."

# Execute initialization script
docker exec -i hive-server beeline -u jdbc:hive2://localhost:10000 < hive-config/init-tables.sql

echo "✅ Hive Tables Initialized Successfully!"

# Test des tables
echo "🧪 Testing Created Tables..."
docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "
USE analytics;
SHOW TABLES;
DESCRIBE reviews;
SELECT COUNT(*) as total_reviews FROM reviews;
"

echo "🎉 Hive Completely Configured!"