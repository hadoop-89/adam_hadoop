#!/bin/bash
# Nettoyage complet et redémarrage de Hadoop

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${RED}🧹 === NETTOYAGE COMPLET HADOOP ===${NC}"
echo -e "${YELLOW}Ce script va tout supprimer et redémarrer proprement${NC}"

# 1. Arrêter tous les conteneurs
echo -e "\n${YELLOW}⏹️ Arrêt de tous les conteneurs...${NC}"
docker-compose down --remove-orphans -v || true
docker-compose down || true

# 2. Supprimer tous les conteneurs Hadoop (même orphelins)
echo -e "\n${YELLOW}🗑️ Suppression des conteneurs orphelins...${NC}"
docker ps -a --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard|spark|kafka|hive)" | xargs -r docker rm -f || true

# 3. Supprimer tous les volumes Hadoop
echo -e "\n${YELLOW}💾 Suppression des volumes persistants...${NC}"
docker volume ls -q | grep -E "(hadoop|namenode|datanode)" | xargs -r docker volume rm -f || true

# 4. Nettoyer les volumes spécifiques du compose
echo -e "\n${YELLOW}🧹 Nettoyage volumes Docker Compose...${NC}"
docker volume rm -f $(docker volume ls -q | grep "adam_hadoop" || true) 2>/dev/null || true

# 5. Nettoyage réseau
echo -e "\n${YELLOW}🌐 Nettoyage réseaux...${NC}"
docker network rm $(docker network ls -q | grep "hadoop") 2>/dev/null || true

# 6. Nettoyage général Docker
echo -e "\n${YELLOW}🧽 Nettoyage général Docker...${NC}"
docker system prune -f
docker volume prune -f

echo -e "\n${GREEN}✅ Nettoyage complet terminé!${NC}"

# 7. Vérification qu'il ne reste rien
echo -e "\n${BLUE}🔍 Vérification finale...${NC}"
remaining_containers=$(docker ps -a --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard)" || true)
if [ -n "$remaining_containers" ]; then
    echo -e "${RED}❌ Des conteneurs restent:${NC}"
    echo "$remaining_containers"
else
    echo -e "${GREEN}✅ Aucun conteneur Hadoop restant${NC}"
fi

remaining_volumes=$(docker volume ls -q | grep -E "(hadoop|namenode|datanode)" || true)
if [ -n "$remaining_volumes" ]; then
    echo -e "${RED}❌ Des volumes restent:${NC}"
    echo "$remaining_volumes"
else
    echo -e "${GREEN}✅ Aucun volume Hadoop restant${NC}"
fi

echo -e "\n${BLUE}🚀 === DÉMARRAGE PROPRE HADOOP ===${NC}"

# 8. Reconstruire et démarrer dans le bon ordre
echo -e "\n${YELLOW}📦 Construction des images...${NC}"
docker-compose build --no-cache

echo -e "\n${YELLOW}🖥️ Démarrage du NameNode d'abord...${NC}"
docker-compose up -d namenode

echo -e "\n${YELLOW}⏳ Attente NameNode (45s)...${NC}"
sleep 45

# Vérifier que NameNode fonctionne
echo -e "\n${BLUE}🔍 Vérification NameNode...${NC}"
if curl -f -s http://localhost:9870 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ NameNode opérationnel${NC}"
else
    echo -e "${RED}❌ NameNode pas encore prêt, attente 30s de plus...${NC}"
    sleep 30
fi

echo -e "\n${YELLOW}📊 Démarrage des DataNodes...${NC}"
docker-compose up -d datanode1 datanode2

echo -e "\n${YELLOW}⏳ Attente connexion DataNodes (60s)...${NC}"
sleep 60

# Vérifier les DataNodes
echo -e "\n${BLUE}🔍 Vérification DataNodes...${NC}"
datanode_count=0

if curl -f -s http://localhost:9864 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ DataNode1 opérationnel${NC}"
    ((datanode_count++))
else
    echo -e "${RED}❌ DataNode1 non accessible${NC}"
fi

if curl -f -s http://localhost:9865 >/dev/null 2>&1; then
    echo -e "${GREEN}✅ DataNode2 opérationnel${NC}"
    ((datanode_count++))
else
    echo -e "${RED}❌ DataNode2 non accessible${NC}"
fi

echo -e "\n${BLUE}📊 DataNodes connectés: $datanode_count/2${NC}"

# Vérifier la connexion HDFS
echo -e "\n${BLUE}🔍 Test connexion HDFS...${NC}"
if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HDFS accessible${NC}"
else
    echo -e "${RED}❌ HDFS non accessible, attente 30s...${NC}"
    sleep 30
fi

echo -e "\n${YELLOW}🌐 Démarrage services complémentaires...${NC}"
docker-compose up -d

echo -e "\n${YELLOW}⏳ Attente stabilisation cluster (30s)...${NC}"
sleep 30

# Test final HDFS
echo -e "\n${BLUE}🧪 Test final HDFS...${NC}"
if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HDFS complètement opérationnel${NC}"
    
    # Test rapport admin
    echo -e "\n${BLUE}📊 Rapport cluster:${NC}"
    docker exec namenode hdfs dfsadmin -report | head -10
else
    echo -e "${RED}❌ HDFS encore problématique${NC}"
fi

echo -e "\n${GREEN}🎉 === REDÉMARRAGE COMPLET TERMINÉ ===${NC}"

# Instructions pour charger les données
echo -e "\n${BLUE}📋 === PROCHAINES ÉTAPES ===${NC}"
echo -e "${YELLOW}1. Vérifiez le status:${NC}"
echo -e "   ./scripts/deploy.sh --status"
echo -e "\n${YELLOW}2. Si tout est OK, chargez les données:${NC}"
echo -e "   docker-compose run --rm data-loader"
echo -e "\n${YELLOW}3. Vérifiez les données:${NC}"
echo -e "   docker exec namenode hdfs dfs -ls /data"

echo -e "\n${GREEN}🔗 Accès:${NC}"
echo -e "• NameNode: http://localhost:9870"
echo -e "• DataNode1: http://localhost:9864"
echo -e "• DataNode2: http://localhost:9865"
echo -e "• Dashboard: http://localhost:8501"