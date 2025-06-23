#!/bin/bash
set -e

echo "🚀 Démarrage du DataNode..."

# Attendre que le NameNode soit disponible
echo "⏳ Attente du NameNode..."
while ! nc -z namenode 9000; do
    echo "⏳ NameNode non accessible, nouvelle tentative dans 5s..."
    sleep 5
done

echo "✅ NameNode accessible !"

# Attendre un peu plus pour que le NameNode soit complètement initialisé
sleep 10

# Vérifier que le répertoire de données existe
mkdir -p /hadoop/dfs/data

# Démarrer le DataNode
echo "🔄 Démarrage du DataNode..."
exec hdfs datanode