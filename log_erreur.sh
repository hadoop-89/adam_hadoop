# 1. CHECK THE CURRENT STATUS OF CONTAINERS
echo "🔍 Container status:"
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# 2. CHECK THE LOGS OF THE NAMENODE (often the cause)
echo "📋 NameNode logs (last 20 lines):"
docker logs namenode --tail 20

# 3. CHECK THE LOGS OF THE DATANODES
echo "📋 DataNode1 logs:"
docker logs datanode1 --tail 15

echo "📋 DataNode2 logs:"
docker logs datanode2 --tail 15

# 4. CHECK THE LOGS OF THE DATA-LOADER
echo "📋 Data-loader logs:"
docker logs data-loader --tail 20

# 5. MANUAL HDFS TEST
echo "🧪 Manual HDFS test:"
docker exec namenode hdfs dfs -ls / 2>&1 || echo "HDFS not accessible"

# 6. CHECK NETWORK CONNECTIVITY
echo "🌐 Network test:"
docker exec namenode ping -c 2 datanode1 || echo "Network NameNode->DataNode1 KO"
docker exec namenode ping -c 2 datanode2 || echo "Network NameNode->DataNode2 KO"

# 7. CHECK PORTS
echo "🔌 NameNode ports:"
docker exec namenode netstat -tlnp | grep -E "(9000|9870)" || echo "HDFS ports not open"