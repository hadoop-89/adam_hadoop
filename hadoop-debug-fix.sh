#!/bin/bash
# Script de diagnostic et correction Hadoop

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 === DIAGNOSTIC HADOOP AVANCÉ ===${NC}"

# Fonction de diagnostic
diagnose_issue() {
    echo -e "\n${YELLOW}📋 Phase 1: Diagnostic des conteneurs${NC}"
    
    # État des conteneurs
    echo -e "${BLUE}Conteneurs en cours:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n${YELLOW}📋 Phase 2: Diagnostic réseau${NC}"
    
    # Test réseau entre conteneurs
    echo -e "${BLUE}Test connectivité namenode -> datanode1:${NC}"
    if docker exec namenode ping -c 2 datanode1 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ namenode -> datanode1 OK${NC}"
    else
        echo -e "${RED}❌ namenode -> datanode1 FAILED${NC}"
    fi
    
    echo -e "${BLUE}Test connectivité namenode -> datanode2:${NC}"
    if docker exec namenode ping -c 2 datanode2 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ namenode -> datanode2 OK${NC}"
    else
        echo -e "${RED}❌ namenode -> datanode2 FAILED${NC}"
    fi
    
    echo -e "\n${YELLOW}📋 Phase 3: Logs NameNode (dernières 15 lignes)${NC}"
    docker logs namenode | tail -15
    
    echo -e "\n${YELLOW}📋 Phase 4: Logs DataNode1 (dernières 10 lignes)${NC}"
    docker logs datanode1 | tail -10
    
    echo -e "\n${YELLOW}📋 Phase 5: Logs DataNode2 (dernières 10 lignes)${NC}"
    docker logs datanode2 | tail -10
    
    echo -e "\n${YELLOW}📋 Phase 6: Configuration NameNode${NC}"
    echo -e "${BLUE}Processus Java NameNode:${NC}"
    docker exec namenode ps aux | grep java || echo "Aucun processus Java trouvé"
    
    echo -e "\n${BLUE}Ports ouverts NameNode:${NC}"
    docker exec namenode netstat -tlnp 2>/dev/null | grep :9000 || echo "Port 9000 non ouvert"
    docker exec namenode netstat -tlnp 2>/dev/null | grep :9870 || echo "Port 9870 non ouvert"
    
    echo -e "\n${YELLOW}📋 Phase 7: Test direct commandes HDFS${NC}"
    echo -e "${BLUE}Test hdfs dfs -ls dans NameNode:${NC}"
    docker exec namenode hdfs dfs -ls / 2>&1 || echo "Commande HDFS échouée"
    
    echo -e "\n${BLUE}Test hdfs dfsadmin -report:${NC}"
    docker exec namenode hdfs dfsadmin -report 2>&1 || echo "Rapport HDFS échoué"
}

# Fonction de correction
fix_hdfs_issues() {
    echo -e "\n${BLUE}🛠️ === TENTATIVES DE CORRECTION ===${NC}"
    
    # Correction 1: Reformater le NameNode si nécessaire
    echo -e "\n${YELLOW}🔧 Correction 1: Vérification format NameNode${NC}"
    docker exec namenode bash -c "
        if [ ! -d '/hadoop/dfs/name/current' ]; then
            echo 'Reformatage du NameNode nécessaire...'
            hdfs namenode -format -force -nonInteractive
        else
            echo 'NameNode déjà formaté'
        fi
    " || echo "Erreur formatage NameNode"
    
    # Correction 2: Redémarrer NameNode
    echo -e "\n${YELLOW}🔧 Correction 2: Redémarrage NameNode${NC}"
    docker restart namenode
    
    echo -e "${BLUE}Attente redémarrage NameNode (30s)...${NC}"
    sleep 30
    
    # Correction 3: Redémarrer DataNodes
    echo -e "\n${YELLOW}🔧 Correction 3: Redémarrage DataNodes${NC}"
    docker restart datanode1 datanode2
    
    echo -e "${BLUE}Attente redémarrage DataNodes (45s)...${NC}"
    sleep 45
    
    # Correction 4: Test final
    echo -e "\n${YELLOW}🧪 Test après corrections${NC}"
    local attempts=0
    local max_attempts=10
    
    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
        echo -e "${BLUE}Tentative $attempts/$max_attempts...${NC}"
        
        if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HDFS fonctionne maintenant!${NC}"
            return 0
        fi
        
        sleep 10
    done
    
    echo -e "${RED}❌ HDFS toujours non fonctionnel après corrections${NC}"
    return 1
}

# Fonction de reconstruction complète
rebuild_cluster() {
    echo -e "\n${RED}🔨 === RECONSTRUCTION COMPLÈTE ===${NC}"
    
    # Arrêt complet
    echo -e "${YELLOW}⏹️ Arrêt complet du cluster...${NC}"
    docker-compose down --remove-orphans -v
    
    # Nettoyage volumes
    echo -e "${YELLOW}🗑️ Suppression volumes corrompus...${NC}"
    docker volume rm $(docker volume ls -q | grep hadoop) 2>/dev/null || true
    
    # Reconstruction avec configuration corrigée
    echo -e "${YELLOW}🏗️ Reconstruction avec configuration corrigée...${NC}"
    
    # Corriger les fichiers de configuration si nécessaire
    echo -e "${BLUE}Vérification configuration HDFS...${NC}"
    
    # Corriger hdfs-site.xml du NameNode
    cat > hadoop-namenode/hdfs-site.xml << 'EOF'
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///hadoop/dfs/name</value>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>0.0.0.0:9870</value>
    </property>
    <property>
        <name>dfs.namenode.rpc-address</name>
        <value>0.0.0.0:9000</value>
    </property>
    <property>
        <name>dfs.permissions.enabled</name>
        <value>false</value>
    </property>
    <property>
        <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
        <value>false</value>
    </property>
    <property>
        <name>dfs.namenode.safemode.threshold-pct</name>
        <value>0.99</value>
    </property>
</configuration>
EOF

    echo -e "${GREEN}✅ Configuration NameNode corrigée${NC}"
    
    # Rebuild et redémarrage ordonné
    echo -e "${YELLOW}📦 Rebuild images...${NC}"
    docker-compose build --no-cache namenode datanode1 datanode2
    
    echo -e "${YELLOW}🖥️ Démarrage NameNode seul...${NC}"
    docker-compose up -d namenode
    
    # Attente plus longue pour NameNode
    echo -e "${BLUE}Attente NameNode (60s)...${NC}"
    sleep 60
    
    # Test NameNode
    if curl -f -s http://localhost:9870 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ NameNode Web UI accessible${NC}"
    else
        echo -e "${RED}❌ NameNode Web UI inaccessible${NC}"
        return 1
    fi
    
    # Test HDFS NameNode seul
    if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS accessible sur NameNode seul${NC}"
    else
        echo -e "${RED}❌ HDFS non accessible même sur NameNode seul${NC}"
        return 1
    fi
    
    # Démarrage DataNodes
    echo -e "${YELLOW}📊 Démarrage DataNodes...${NC}"
    docker-compose up -d datanode1 datanode2
    
    # Attente DataNodes
    echo -e "${BLUE}Attente DataNodes (60s)...${NC}"
    sleep 60
    
    # Test final
    if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS fonctionne avec DataNodes!${NC}"
        
        # Démarrer le reste
        echo -e "${YELLOW}🌐 Démarrage services complémentaires...${NC}"
        docker-compose up -d
        
        return 0
    else
        echo -e "${RED}❌ HDFS toujours non fonctionnel${NC}"
        return 1
    fi
}

# Menu principal
echo -e "${YELLOW}Que voulez-vous faire?${NC}"
echo -e "1. ${BLUE}Diagnostic seulement${NC}"
echo -e "2. ${YELLOW}Diagnostic + tentatives de correction${NC}"
echo -e "3. ${RED}Reconstruction complète du cluster${NC}"
echo -e "4. ${GREEN}Test rapide HDFS${NC}"

read -p "Votre choix (1-4): " choice

case $choice in
    1)
        diagnose_issue
        ;;
    2)
        diagnose_issue
        fix_hdfs_issues
        ;;
    3)
        diagnose_issue
        rebuild_cluster
        ;;
    4)
        echo -e "${BLUE}Test rapide HDFS...${NC}"
        if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HDFS fonctionne${NC}"
            docker exec namenode hdfs dfs -ls /
        else
            echo -e "${RED}❌ HDFS ne fonctionne pas${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Choix invalide${NC}"
        ;;
esac

echo -e "\n${BLUE}🎯 Fin du diagnostic${NC}"