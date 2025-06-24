#!/bin/bash
# hive-config/start-hive.sh

echo "🚀 Démarrage des services Hive..."

# Démarrer Hive Metastore
echo "📊 Démarrage du Metastore..."
docker-compose up -d hive-metastore

# Attendre que le Metastore soit prêt
echo "⏳ Attente du Metastore (30s)..."
sleep 30

# Vérifier que le Metastore fonctionne
if docker logs hive-metastore 2>&1 | grep -q "Started HiveMetaStore"; then
    echo "✅ Metastore démarré avec succès"
else
    echo "❌ Problème avec le Metastore"
    docker logs hive-metastore | tail -10
    exit 1
fi

# Créer les répertoires Hive dans HDFS
echo "📁 Création des répertoires Hive dans HDFS..."
docker exec namenode bash -c "
hdfs dfs -mkdir -p /user/hive/warehouse
hdfs dfs -chmod 777 /user/hive/warehouse
hdfs dfs -mkdir -p /tmp/hive
hdfs dfs -chmod 777 /tmp/hive
"

# Démarrer HiveServer2
echo "🖥️ Démarrage de HiveServer2..."
docker-compose up -d hive-server

# Attendre que HiveServer2 soit prêt
echo "⏳ Attente de HiveServer2 (20s)..."
sleep 20

# Test de connexion
echo "🧪 Test de connexion Hive..."
if docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;" >/dev/null 2>&1; then
    echo "✅ HiveServer2 opérationnel"
else
    echo "❌ Problème avec HiveServer2"
    docker logs hive-server | tail -10
    exit 1
fi

echo "🎉 Services Hive démarrés avec succès !"
echo "📊 Connexion : docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000"