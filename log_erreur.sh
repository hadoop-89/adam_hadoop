# 1. VÉRIFIER L'ÉTAT ACTUEL DES CONTENEURS
echo "🔍 État des conteneurs:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. VÉRIFIER LES LOGS DU NAMENODE (souvent la cause)
echo "📋 Logs NameNode (dernières 20 lignes):"
docker logs namenode --tail 20

# 3. VÉRIFIER LES LOGS DES DATANODES
echo "📋 Logs DataNode1:"
docker logs datanode1 --tail 15

echo "📋 Logs DataNode2:" 
docker logs datanode2 --tail 15

# 4. VÉRIFIER LES LOGS DU DATA-LOADER
echo "📋 Logs Data-loader:"
docker logs data-loader --tail 20

# 5. TEST MANUEL HDFS
echo "🧪 Test manuel HDFS:"
docker exec namenode hdfs dfs -ls / 2>&1 || echo "HDFS non accessible"

# 6. VÉRIFIER LA CONNECTIVITÉ RÉSEAU
echo "🌐 Test réseau:"
docker exec namenode ping -c 2 datanode1 || echo "Réseau NameNode->DataNode1 KO"
docker exec namenode ping -c 2 datanode2 || echo "Réseau NameNode->DataNode2 KO"

# 7. VÉRIFIER LES PORTS
echo "🔌 Ports NameNode:"
docker exec namenode netstat -tlnp | grep -E "(9000|9870)" || echo "Ports HDFS non ouverts"