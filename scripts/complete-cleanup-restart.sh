#!/bin/bash
# Complete cleanup and restart of Hadoop

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🧹 === COMPLETE HADOOP CLEANUP ===${NC}"
echo -e "${YELLOW}This script will remove everything and restart cleanly${NC}"

# 1. Stop all containers
echo -e "\n${YELLOW}⏹️ Stopping all containers...${NC}"
docker-compose down --remove-orphans -v || true
docker-compose down || true

# 2. Remove all Hadoop containers (including orphaned ones)
echo -e "\n${YELLOW}🗑️ Removing orphaned containers...${NC}"
docker ps -a --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard|spark|kafka|hive)" | xargs -r docker rm -f || true

# 3. Remove all Hadoop volumes
echo -e "\n${YELLOW}💾 Removing persistent volumes...${NC}"
docker volume ls -q | grep -E "(hadoop|namenode|datanode)" | xargs -r docker volume rm -f || true

# 4. Clean up specific compose volumes
echo -e "\n${YELLOW}🧹 Cleaning up Docker Compose volumes...${NC}"
docker volume rm -f $(docker volume ls -q | grep "adam_hadoop" || true) 2>/dev/null || true

# 5. Clean up networks
echo -e "\n${YELLOW}🌐 Cleaning up networks...${NC}"
docker network rm $(docker network ls -q | grep "hadoop") 2>/dev/null || true

# 6. General Docker cleanup
echo -e "\n${YELLOW}🧽 General Docker cleanup...${NC}"
docker system prune -f
docker volume prune -f

echo -e "\n${GREEN}✅ Complete cleanup finished!${NC}"

# 7. Check that nothing remains
echo -e "\n${BLUE}🔍 Final check...${NC}"
remaining_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard)" || true)
if [ -n "$remaining_containers" ]; then
    echo -e "${RED}❌ Some containers remain:${NC}"
    echo "$remaining_containers"
else
    echo -e "${GREEN}✅ No remaining Hadoop containers${NC}"
fi

remaining_volumes=$(docker volume ls -q | grep -E "(hadoop|namenode|datanode)" || true)
if [ -n "$remaining_volumes" ]; then
    echo -e "${RED}❌ Some volumes remain:${NC}"
    echo "$remaining_volumes"
else
    echo -e "${GREEN}✅ No remaining Hadoop volumes${NC}"
fi

echo -e "\n${BLUE}🚀 === STARTING HADOOP CLEANLY ===${NC}"

# 8. Rebuild and start in the correct order
echo -e "\n${YELLOW}📦 Building  images...${NC}"
docker-compose build --no-cache

echo -e "\n${YELLOW}🖥️ Starting NameNode first...${NC}"
docker-compose up -d namenode

echo -e "\n${YELLOW}⏳ Waiting for NameNode (45s)...${NC}"
sleep 45

# Check if NameNode is working
echo -e "\n${BLUE}🔍 Checking NameNode...${NC}"
if curl -f -s http://localhost:9870 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ NameNode is operational${NC}"
else
    echo -e "${RED}❌ NameNode is not ready yet, waiting 30s more...${NC}"
    sleep 30
fi

echo -e "\n${YELLOW}📊 Starting DataNodes...${NC}"
docker-compose up -d datanode1 datanode2

echo -e "\n${YELLOW}⏳ Waiting for DataNodes (60s)...${NC}"
sleep 60

# Check DataNodes
echo -e "\n${BLUE}🔍 Checking DataNodes...${NC}"
datanode_count=0

if curl -f -s http://localhost:9864 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ DataNode1 is operational${NC}"
    ((datanode_count++))
else
    echo -e "${RED}❌ DataNode1 is not accessible${NC}"
fi

if curl -f -s http://localhost:9865 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ DataNode2 is operational${NC}"
    ((datanode_count++))
else
    echo -e "${RED}❌ DataNode2 is not accessible${NC}"
fi

echo -e "\n${BLUE}📊 DataNodes connected: $datanode_count/2${NC}"

# Check HDFS connection
echo -e "\n${BLUE}🔍 Testing HDFS connection...${NC}"
if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HDFS is accessible${NC}"
else
    echo -e "${RED}❌ HDFS is not accessible, waiting 30s...${NC}"
    sleep 30
fi

echo -e "\n${YELLOW}🌐 Starting additional services...${NC}"
docker-compose up -d

echo -e "\n${YELLOW}⏳ Waiting for cluster stabilization (30s)...${NC}"
sleep 30

# Test final HDFS
echo -e "\n${BLUE}🧪 Test final HDFS...${NC}"
if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HDFS is fully operational${NC}"
    echo -e "${YELLOW}📁 Creating directories...${NC}"
    # Test rapport admin
    echo -e "\n${BLUE}📊 Reporting cluster:${NC}"
    docker exec namenode hdfs dfsadmin -report | head -10
else
    echo -e "${RED}❌ HDFS is still problematic${NC}"
fi

echo -e "\n${GREEN}🎉 === COMPLETE RESTART FINISHED ===${NC}"

# Instructions pour charger les données
echo -e "\n${BLUE}📋 === NEXT STEPS ===${NC}"
echo -e "${YELLOW}1. Check the status:${NC}"
echo -e "   ./scripts/deploy.sh --status"
echo -e "\n${YELLOW}2. If everything is OK, load the data:${NC}"
echo -e "   docker-compose run --rm data-loader"
echo -e "\n${YELLOW}3. Check the data:${NC}"
echo -e "   docker exec namenode hdfs dfs -ls /data"

echo -e "\n${GREEN}🔗 Access:${NC}"
echo -e "• NameNode: http://localhost:9870"
echo -e "• DataNode1: http://localhost:9864"
echo -e "• DataNode2: http://localhost:9865"
echo -e "• Dashboard: http://localhost:8501"