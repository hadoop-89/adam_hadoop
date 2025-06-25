#!/bin/bash
set -e

echo "🚀 Starting DataNode..."

# Wait for NameNode to be available
echo "⏳ Waiting for NameNode..."
while ! nc -z namenode 9000; do
    echo "⏳ NameNode not accessible, retrying in 5s..."
    sleep 5
done

echo "✅ NameNode accessible!"

# Wait a bit longer for NameNode to be fully initialized
sleep 10

# Check that the data directory exists
mkdir -p /hadoop/dfs/data

# Start the DataNode
echo "🔄 Starting DataNode..."
exec hdfs datanode