#!/bin/bash
# hive-config/start-hive.sh

echo "🚀 Starting Hive Services..."

# Start Hive Metastore
echo "📊 Starting Metastore..."
docker-compose up -d hive-metastore

# Wait for Metastore to be ready
echo "⏳ Waiting for Metastore (30s)..."
sleep 30

# Check that Metastore is working
if docker logs hive-metastore 2>&1 | grep -q "Started HiveMetaStore"; then
    echo "✅ Metastore started successfully"
else
    echo "❌ Problem with Metastore"
    docker logs hive-metastore | tail -10
    exit 1
fi

# Create Hive directories in HDFS
echo "📁 Creating Hive directories in HDFS..."
docker exec namenode bash -c "
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod 777 /user/hive/warehouse
hdfs dfs -mkdir -p /tmp/hive
hdfs dfs -chmod 777 /tmp/hive
"

# Start HiveServer2
echo "🖥️ Starting HiveServer2..."
docker-compose up -d hive-server

# Wait for HiveServer2 to be ready
echo "⏳ Waiting for HiveServer2 (20s)..."
sleep 20

# Test connection
echo "🧪 Testing Hive connection..."
if docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;" >/dev/null 2>&1; then
    echo "✅ HiveServer2 operational"
else
    echo "❌ Problem with HiveServer2"
    docker logs hive-server | tail -10
    exit 1
fi

echo "🎉 Hive Services started successfully!"
echo "📊 Connection: docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000"