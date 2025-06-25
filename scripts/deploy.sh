#!/bin/bash
# Script de déploiement COMPLET - TOUS SERVICES HADOOP + IA

set -e

# Colors pour Git Bash
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

echo -e "${BLUE}🚀 Complete Hadoop + AI Cluster Deployment${NC}"
echo -e "${BLUE}=========================================${NC}"

# Aller au répertoire du projet
cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"
echo -e "${YELLOW}📂 Project: $PROJECT_ROOT${NC}"

# Parse arguments
ACTION="deploy"
SKIP_DATA_LOADER=false

case "${1:-}" in
    --clean) 
        ACTION="clean"
        echo -e "${YELLOW}🧹 Mode: Clean restart with data loading${NC}"
        ;;
    --fresh) 
        ACTION="fresh" 
        echo -e "${RED}🧹 Mode: Fresh deployment (complete reset)${NC}"
        ;;
    --status) 
        ACTION="status"
        echo -e "${BLUE}📊 Mode: Complete status check${NC}"
        ;;
    --debug)
        ACTION="debug"
        echo -e "${RED}🔧 Mode: Debug all services${NC}"
        ;;
    --ordered)
        ACTION="ordered"
        echo -e "${BLUE}🚀 Mode: Ordered deployment all services${NC}"
        ;;
    --no-data)
        ACTION="deploy"
        SKIP_DATA_LOADER=true
        echo -e "${BLUE}📋 Mode: Deploy without data loading${NC}"
        ;;
    --help|-h)
        echo -e "${YELLOW}Usage: $0 [--clean|--fresh|--status|--debug|--ordered|--no-data|--help]${NC}"
        echo "  (no args)  Complete deployment with data loading"
        echo "  --clean    Clean restart with data loading"
        echo "  --fresh    Complete reset and fresh install"
        echo "  --status   Complete status of all services"
        echo "  --debug    Debug mode for all services"
        echo "  --ordered  Ordered deployment of all services"
        echo "  --no-data  Deploy cluster without loading data"
        echo "  --help     Show this help"
        exit 0
        ;;
    "")
        echo -e "${BLUE}📋 Mode: Complete deployment with data${NC}"
        ;;
    *)
        echo -e "${RED}❌ Unknown option: $1${NC}"
        echo "Use --help for usage"
        exit 1
        ;;
esac

# ============ FONCTIONS DE BASE ============

check_docker() {
    echo -e "\n${YELLOW}🔍 Checking Docker...${NC}"
    
    if ! command -v docker >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker command not found${NC}"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        echo -e "${RED}❌ Docker daemon not running${NC}"
        echo -e "${YELLOW}💡 Start Docker Desktop and try again${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Docker is running${NC}"
    
    if [[ ! -f "docker-compose.yml" ]]; then
        echo -e "${RED}❌ docker-compose.yml not found${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ docker-compose.yml found${NC}"
}

complete_cleanup() {
    echo -e "\n${RED}🧹 COMPLETE CLEANUP ALL SERVICES${NC}"
    
    # 1. Arrêter tous les conteneurs
    echo -e "${YELLOW}⏹️ Stopping all containers...${NC}"
    docker-compose down --remove-orphans -v || true
    
    # 2. Supprimer conteneurs orphelins
    echo -e "${YELLOW}🗑️ Removing orphaned containers...${NC}"
    docker ps -a --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard|spark|kafka|hive|zookeeper|scraper)" | xargs -r docker rm -f || true
    
    # 3. Supprimer volumes
    echo -e "${YELLOW}💾 Removing volumes...${NC}"
    docker volume ls -q | grep -E "(hadoop|namenode|datanode|kafka|hive)" | xargs -r docker volume rm -f || true
    
    # 4. Nettoyage général
    echo -e "${YELLOW}🧽 General cleanup...${NC}"
    docker system prune -f
    docker volume prune -f
    
    echo -e "${GREEN}✅ Complete cleanup finished${NC}"
}

# ============ FONCTIONS DE VÉRIFICATION ============

check_service_health() {
    local name=$1
    local url=$2
    local timeout=${3:-5}
    
    if curl -f -s --max-time "$timeout" "$url" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_port_health() {
    local host=$1
    local port=$2
    local timeout=${3:-3}
    
    if timeout "$timeout" bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

check_kafka_health() {
    if docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

check_hive_health() {
    # Test Hive Metastore
    if ! docker exec hive-metastore ps aux | grep -q "HiveMetaStore" 2>/dev/null; then
        return 1
    fi
    
    # Test HiveServer2
    if docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# ============ FONCTIONS DE DÉPLOIEMENT ============

wait_for_service() {
    local name=$1
    local url_or_port=$2
    local max_wait=${3:-180}
    local elapsed=0
    
    echo -e "${YELLOW}⏳ Waiting for $name...${NC}"
    
    while [[ $elapsed -lt $max_wait ]]; do
        local success=false
        
        # Distinction HTTP vs port check
        if [[ "$url_or_port" == http* ]]; then
            if check_service_health "$name" "$url_or_port" 3; then
                success=true
            fi
        else
            # Port check
            local port="${url_or_port##*:}"
            if check_port_health "localhost" "$port" 3; then
                success=true
            fi
        fi
        
        if [[ "$success" == true ]]; then
            echo -e "${GREEN}✅ $name is ready (${elapsed}s)${NC}"
            return 0
        fi
        
        sleep 10
        elapsed=$((elapsed + 10))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            echo -e "${BLUE}... still waiting (${elapsed}s/${max_wait}s)${NC}"
        fi
    done
    
    echo -e "${RED}❌ $name timeout after ${max_wait}s${NC}"
    return 1
}

# CORRECTION DE LA FONCTION deploy_all_services_ordered()
# =====================================================

deploy_all_services_ordered() {
    echo -e "\n${YELLOW}🏗️ COMPLETE ORDERED DEPLOYMENT${NC}"
    
    # Phase 1: Build
    echo -e "\n${YELLOW}📦 Phase 1: Building images...${NC}"
    docker-compose build --no-cache
    
    # Phase 2: Infrastructure services
    echo -e "\n${YELLOW}🏗️ Phase 2: Infrastructure Services${NC}"
    docker-compose up -d zookeeper
    sleep 15
    docker-compose up -d kafka
    sleep 20
    
    # Vérifier Kafka
    if wait_for_service "Kafka" "9092" 60; then
        echo -e "${GREEN}✅ Kafka infrastructure ready${NC}"
    else
        echo -e "${YELLOW}⚠️ Kafka not responding, continuing...${NC}"
    fi
    
    # Phase 3: Hadoop Core
    echo -e "\n${YELLOW}🖥️ Phase 3: Hadoop Core${NC}"
    docker-compose up -d namenode
    sleep 45
    
    if ! wait_for_service "NameNode" "http://localhost:9870" 120; then
        echo -e "${RED}❌ NameNode failed to start${NC}"
        return 1
    fi
    
    # Phase 4: DataNodes
    echo -e "\n${YELLOW}📊 Phase 4: Hadoop DataNodes${NC}"
    docker-compose up -d datanode1 datanode2
    sleep 60
    
    # Vérifier DataNodes
    wait_for_service "DataNode1" "http://localhost:9864" 60 || echo -e "${YELLOW}⚠️ DataNode1 not responding${NC}"
    wait_for_service "DataNode2" "http://localhost:9865" 60 || echo -e "${YELLOW}⚠️ DataNode2 not responding${NC}"
    
    # Phase 5: HDFS Basic Verification (AVANT data-loader)
    echo -e "\n${BLUE}🧪 Phase 5: Basic HDFS Verification${NC}"
    if docker exec namenode bash -c 'hdfs dfs -ls /' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS filesystem accessible (basic)${NC}"
    else
        echo -e "${RED}❌ HDFS basic access failed${NC}"
        echo -e "${YELLOW}💡 Checking NameNode logs...${NC}"
        docker logs namenode | tail -10
        return 1
    fi
    
    # Phase 6: Vérification DataNodes connection
    echo -e "\n${BLUE}🔍 Phase 6: DataNodes Connection Check${NC}"
    check_datanodes_connection
    
    # Phase 7: DATA LOADING (CRUCIAL - Crée la structure /data/)
    echo -e "\n${YELLOW}📥 Phase 7: Data Loading & HDFS Structure Creation${NC}"
    
    # Vérifier qu'au moins 1 DataNode est connecté avant data loading
    local connected_nodes=$(docker exec namenode hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | grep -o '[0-9]\+' | head -1 || echo "0")
    if [[ "$connected_nodes" -eq "0" ]]; then
        echo -e "${RED}❌ No DataNodes connected, cannot load data${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ HDFS ready with $connected_nodes DataNode(s) connected${NC}"
    
    # LANCER LE DATA-LOADER MAINTENANT
    echo -e "\n${YELLOW}📦 Running data-loader to create HDFS structure...${NC}"
    if docker-compose run --rm data-loader; then
        echo -e "${GREEN}✅ Data loading completed successfully!${NC}"
        
        # Vérifier que /data/ a été créé
        if docker exec namenode hdfs dfs -ls '/data' >/dev/null 2>&1; then
            echo -e "${GREEN}✅ /data directory structure created${NC}"
            
            # Afficher structure créée
            echo -e "\n${YELLOW}📊 Created HDFS structure:${NC}"
            docker exec namenode hdfs dfs -ls -R '/data' | head -15
        else
            echo -e "${RED}❌ /data directory not created by data-loader${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Data loading failed${NC}"
        echo -e "${YELLOW}💡 Check data-loader logs...${NC}"
        docker-compose logs data-loader | tail -10
        return 1
    fi
    
    # Phase 8: Spark Cluster
    echo -e "\n${YELLOW}⚡ Phase 8: Spark Cluster${NC}"
    docker-compose up -d spark-master
    sleep 25
    docker-compose up -d spark-worker
    sleep 20
    
    if wait_for_service "Spark Master" "http://localhost:8080" 60; then
        echo -e "${GREEN}✅ Spark cluster ready${NC}"
    else
        echo -e "${YELLOW}⚠️ Spark not responding, continuing...${NC}"
    fi
    
    # Phase 9: Hive Services
    echo -e "\n${YELLOW}🗄️ Phase 9: Hive Data Services${NC}"
    docker-compose up -d hive-metastore
    sleep 35
    docker-compose up -d hive-server
    sleep 40
    
    # Phase 10: Application Services
    echo -e "\n${YELLOW}🌐 Phase 10: Application Services${NC}"
    docker-compose up -d dashboard scraper
    sleep 25
    
    # Phase 11: VÉRIFICATION FINALE HDFS (APRÈS data-loader)
    echo -e "\n${BLUE}🧪 Phase 11: Final HDFS Verification${NC}"
    if docker exec namenode hdfs dfs -ls '/data' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS with data structure accessible${NC}"
        
        # Statistiques finales
        echo -e "\n${YELLOW}📈 Final HDFS Statistics:${NC}"
        for data_path in "text/existing" "images/existing" "text/scraped" "images/scraped"; do
            local files=$(docker exec namenode hdfs dfs -ls "/data/$data_path/" 2>/dev/null | grep -v "Found" | wc -l || echo "0")
            local size=$(docker exec namenode hdfs dfs -du -h "/data/$data_path/" 2>/dev/null | awk '{print $1}' || echo "N/A")
            echo -e "  /data/$data_path: $files files ($size)"
        done
    else
        echo -e "${RED}❌ HDFS data structure not accessible${NC}"
        return 1
    fi
    
    echo -e "\n${GREEN}✅ Complete ordered deployment with data loading finished!${NC}"
    return 0
}

check_datanodes_connection() {
    echo -e "\n${BLUE}🔍 Checking DataNodes connection...${NC}"
    
    local max_attempts=15
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local connected_nodes=$(docker exec namenode hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | grep -o '[0-9]\+' | head -1 || echo "0")
        
        echo -e "${BLUE}Attempt $((attempt + 1))/$max_attempts: $connected_nodes/2 DataNodes connected${NC}"
        
        if [[ "$connected_nodes" -ge "2" ]]; then
            echo -e "${GREEN}✅ All DataNodes connected successfully!${NC}"
            return 0
        elif [[ "$connected_nodes" -ge "1" ]]; then
            echo -e "${YELLOW}⚠️ Only $connected_nodes/2 DataNodes connected, but proceeding...${NC}"
            return 0
        fi
        
        sleep 15
        ((attempt++))
    done
    
    echo -e "${YELLOW}⚠️ Only $connected_nodes/2 DataNodes connected after $((max_attempts * 15))s${NC}"
    return 0
}

# ============ FONCTIONS DE STATUS ============

show_complete_service_health() {
    echo -e "\n${BLUE}🏥 COMPLETE SERVICE HEALTH CHECK${NC}"
    echo -e "${BLUE}===============================${NC}"
    
    local healthy=0
    local total=0
    
    # Services HTTP
    local http_services=(
        "NameNode:http://localhost:9870"
        "DataNode1:http://localhost:9864"
        "DataNode2:http://localhost:9865"
        "Dashboard:http://localhost:8501"
        "Spark Master:http://localhost:8080"
    )
    
    echo -e "\n${YELLOW}🌐 HTTP Services:${NC}"
    for service in "${http_services[@]}"; do
        local name="${service%%:*}"
        local url="${service#*:}"
        ((total++))
        
        if check_service_health "$name" "$url" 5; then
            echo -e "${GREEN}✅ $name${NC}"
            ((healthy++))
        else
            echo -e "${RED}❌ $name${NC}"
        fi
    done
    
    # Services Port
    local port_services=(
        "Kafka:9092"
        "Zookeeper:2181"
        "Hive Metastore:9083"
        "Hive Server:10000"
    )
    
    echo -e "\n${YELLOW}🔌 Port Services:${NC}"
    for service in "${port_services[@]}"; do
        local name="${service%%:*}"
        local port="${service#*:}"
        ((total++))
        
        if check_port_health "localhost" "$port" 3; then
            echo -e "${GREEN}✅ $name (port $port)${NC}"
            ((healthy++))
        else
            echo -e "${RED}❌ $name (port $port)${NC}"
        fi
    done
    
    # Services spéciaux
    echo -e "\n${YELLOW}🔍 Specialized Services:${NC}"
    
    # Kafka test
    ((total++))
    if check_kafka_health; then
        echo -e "${GREEN}✅ Kafka Broker${NC}"
        ((healthy++))
    else
        echo -e "${RED}❌ Kafka Broker${NC}"
    fi
    
    # Hive test
    ((total++))
    if check_hive_health; then
        echo -e "${GREEN}✅ Hive Complete Stack${NC}"
        ((healthy++))
    else
        echo -e "${RED}❌ Hive Complete Stack${NC}"
    fi
    
    # HDFS test
    ((total++))
    if docker exec namenode hdfs dfs -ls '/' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS Filesystem${NC}"
        ((healthy++))
        
        local connected_nodes=$(docker exec namenode hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | grep -o '[0-9]\+' | head -1 || echo "0")
        echo -e "${GREEN}📊 DataNodes connected: $connected_nodes/2${NC}"
        
        if docker exec namenode hdfs dfs -ls '/data' >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Data loaded in HDFS${NC}"
        else
            echo -e "${YELLOW}⚠️ No data in HDFS${NC}"
        fi
    else
        echo -e "${RED}❌ HDFS Filesystem${NC}"
    fi
    
    # Résumé final
    local percentage=$((healthy * 100 / total))
    echo -e "\n${BLUE}📈 Health Summary: ${GREEN}$healthy${NC}/${BLUE}$total${NC} services healthy (${percentage}%)${NC}"
    
    if [[ $percentage -ge 85 ]]; then
        echo -e "\n${GREEN}🎉 Excellent! All critical services are healthy!${NC}"
        return 0
    elif [[ $percentage -ge 70 ]]; then
        echo -e "\n${YELLOW}⚠️ Good! Most services are healthy${NC}"
        return 1
    else
        echo -e "\n${RED}❌ Issues detected in multiple services${NC}"
        return 2
    fi
}

show_containers_complete() {
    echo -e "\n${BLUE}📊 COMPLETE CONTAINER STATUS${NC}"
    echo -e "${BLUE}===========================${NC}"
    
    # Tous les conteneurs du projet
    echo -e "\n${YELLOW}🐳 All Project Containers:${NC}"
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(namenode|datanode|dashboard|spark|kafka|hive|zookeeper|scraper)" 2>/dev/null; then
        echo ""
    else
        echo -e "${YELLOW}No project containers running${NC}"
        return 1
    fi
    
    # Conteneurs arrêtés
    echo -e "${YELLOW}💤 Stopped Containers:${NC}"
    local stopped=$(docker ps -a --format "table {{.Names}}\t{{.Status}}" | grep -E "(namenode|datanode|dashboard|spark|kafka|hive|zookeeper|scraper)" | grep "Exited\|Created" || echo "None")
    if [[ "$stopped" == "None" ]]; then
        echo -e "${GREEN}✅ No stopped containers${NC}"
    else
        echo "$stopped"
    fi
    
    return 0
}

show_data_status() {
    echo -e "\n${BLUE}📁 DATA STATUS${NC}"
    echo -e "${BLUE}=============${NC}"
    
    if docker exec namenode hdfs dfs -ls '/' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS accessible${NC}"
        
        # Structure HDFS
        echo -e "\n${YELLOW}📂 HDFS Structure:${NC}"
        docker exec namenode hdfs dfs -ls -R '/data' 2>/dev/null | head -15 || echo "  No /data directory found"
        
        # Statistiques de stockage
        echo -e "\n${YELLOW}💾 Storage Statistics:${NC}"
        docker exec namenode hdfs dfs -df -h 2>/dev/null || echo "  Unable to get storage stats"
        
        # Données par type
        echo -e "\n${YELLOW}📊 Data by Type:${NC}"
        for data_type in "text/existing" "text/scraped" "images/existing" "images/scraped"; do
            local size=$(docker exec namenode hdfs dfs -du -h "/data/$data_type/" 2>/dev/null | awk '{print $1}' || echo "0")
            local count=$(docker exec namenode hdfs dfs -ls "/data/$data_type/" 2>/dev/null | wc -l || echo "0")
            echo -e "  $data_type: $size ($count files)"
        done
        
    else
        echo -e "${RED}❌ HDFS not accessible${NC}"
    fi
    
    # Kafka topics
    echo -e "\n${YELLOW}📡 Kafka Topics:${NC}"
    if check_kafka_health; then
        local topics=$(docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null || echo "Unable to list topics")
        echo "  $topics"
    else
        echo -e "${RED}❌ Kafka not accessible${NC}"
    fi
    
    # Hive databases
    echo -e "\n${YELLOW}🗄️ Hive Databases:${NC}"
    if check_hive_health; then
        docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;" 2>/dev/null | grep -E "(analytics|default)" || echo "  Unable to list databases"
    else
        echo -e "${RED}❌ Hive not accessible${NC}"
    fi
}

# ============ FONCTIONS DE DEBUG ============

debug_all_services() {
    echo -e "\n${RED}🔧 DEBUG MODE - ALL SERVICES${NC}"
    echo -e "${RED}============================${NC}"
    
    local services=("namenode" "datanode1" "datanode2" "spark-master" "spark-worker" "kafka" "zookeeper" "hive-metastore" "hive-server" "dashboard" "scraper")
    
    for service in "${services[@]}"; do
        echo -e "\n${YELLOW}🔍 Debugging $service...${NC}"
        
        if docker ps --format "{{.Names}}" | grep -q "^$service$"; then
            echo -e "${GREEN}✅ $service is running${NC}"
            
            # Status détaillé
            local status=$(docker ps --format "{{.Status}}" --filter "name=$service")
            echo -e "${BLUE}Status: $status${NC}"
            
            # Logs récents
            echo -e "${BLUE}Last 5 log lines:${NC}"
            docker logs "$service" 2>&1 | tail -5 | sed 's/^/  /'
            
            # Resource usage
            local stats=$(docker stats "$service" --no-stream --format "CPU: {{.CPUPerc}}, Memory: {{.MemUsage}}" 2>/dev/null || echo "Stats unavailable")
            echo -e "${BLUE}Resources: $stats${NC}"
            
        else
            echo -e "${RED}❌ $service is not running${NC}"
            
            # Vérifier si le conteneur existe mais est arrêté
            local container_status=$(docker ps -a --format "{{.Names}}\t{{.Status}}" | grep "^$service" || echo "Container not found")
            echo -e "${BLUE}Container status: $container_status${NC}"
            
            # Si arrêté, montrer pourquoi
            if docker ps -a --format "{{.Names}}" | grep -q "^$service$"; then
                echo -e "${BLUE}Exit reason (last 3 lines):${NC}"
                docker logs "$service" 2>&1 | tail -3 | sed 's/^/  /'
            fi
        fi
    done
    
    # Network check
    echo -e "\n${YELLOW}🌐 Network Connectivity:${NC}"
    local network_name=$(docker network ls | grep hadoop | awk '{print $2}' | head -1)
    if [[ -n "$network_name" ]]; then
        echo -e "${GREEN}✅ Network: $network_name${NC}"
    else
        echo -e "${RED}❌ No Hadoop network found${NC}"
    fi
    
    # Volume check
    echo -e "\n${YELLOW}💾 Volumes:${NC}"
    docker volume ls | grep -E "(hadoop|namenode|datanode)" | sed 's/^/  /' || echo "  No Hadoop volumes found"
}

# ============ FONCTION DE CHARGEMENT DES DONNÉES ============

load_data() {
    if [[ "$SKIP_DATA_LOADER" == "true" ]]; then
        echo -e "\n${BLUE}📋 Skipping data loading (--no-data flag)${NC}"
        return 0
    fi
    
    echo -e "\n${BLUE}📥 === DATA LOADING PHASE ===${NC}"
    
    # Vérifier que HDFS est prêt
    echo -e "${YELLOW}🔍 Final HDFS check before data loading...${NC}"
    if ! docker exec namenode hdfs dfs -ls '/' >/dev/null 2>&1; then
        echo -e "${RED}❌ HDFS not ready for data loading${NC}"
        return 1
    fi
    
    # Vérifier qu'au moins 1 DataNode est connecté
    local connected_nodes=$(docker exec namenode hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | grep -o '[0-9]\+' | head -1 || echo "0")
    if [[ "$connected_nodes" -eq "0" ]]; then
        echo -e "${RED}❌ No DataNodes connected, cannot load data${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ HDFS ready with $connected_nodes DataNode(s) connected${NC}"
    
    # Lancer data-loader
    echo -e "\n${YELLOW}📦 Running data-loader...${NC}"
    if docker-compose run --rm data-loader; then
        echo -e "${GREEN}✅ Data loading completed successfully!${NC}"
        
        # Vérifier les données chargées
        echo -e "\n${BLUE}🔍 Verifying loaded data...${NC}"
        if docker exec namenode hdfs dfs -ls '/data' >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Data directory created${NC}"
            
            # Afficher structure
            echo -e "\n${YELLOW}📊 Data structure:${NC}"
            docker exec namenode hdfs dfs -ls -R '/data' | head -20
            
            # Statistiques détaillées
            echo -e "\n${YELLOW}📈 Detailed statistics:${NC}"
            for data_path in "/data/text/existing" "/data/images/existing" "/data/text/scraped" "/data/images/scraped"; do
                local size=$(docker exec namenode hdfs dfs -du -h "$data_path/" 2>/dev/null | awk '{print $1}' || echo "N/A")
                local files=$(docker exec namenode hdfs dfs -ls "$data_path/" 2>/dev/null | grep -v "Found" | wc -l || echo "0")
                echo -e "  ${data_path}: ${size} (${files} files)"
            done
        else
            echo -e "${YELLOW}⚠️ Data directory not found, but data-loader completed${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Data loading failed${NC}"
        echo -e "${YELLOW}💡 Check logs: docker-compose logs data-loader${NC}"
        return 1
    fi
}

# ============ FONCTIONS D'AFFICHAGE ============

show_access_info() {
    echo -e "\n${BLUE}📊 COMPLETE ACCESS INFORMATION${NC}"
    echo -e "${BLUE}=============================${NC}"
    
    echo -e "\n${GREEN}🌐 Web Interfaces:${NC}"
    echo -e "${GREEN}• NameNode Web UI: http://localhost:9870${NC}"
    echo -e "${GREEN}• DataNode1 Web UI: http://localhost:9864${NC}"
    echo -e "${GREEN}• DataNode2 Web UI: http://localhost:9865${NC}"
    echo -e "${GREEN}• Streamlit Dashboard: http://localhost:8501${NC}"
    echo -e "${GREEN}• Spark Master UI: http://localhost:8080${NC}"
    
    echo -e "\n${YELLOW}🔌 Service Ports:${NC}"
    echo -e "${YELLOW}• Kafka Broker: localhost:9092${NC}"
    echo -e "${YELLOW}• Zookeeper: localhost:2181${NC}"
    echo -e "${YELLOW}• Hive Metastore: localhost:9083${NC}"
    echo -e "${YELLOW}• Hive Server: localhost:10000${NC}"
    
    echo -e "\n${BLUE}💡 Useful Commands:${NC}"
    echo -e "  $0 --status        # Complete cluster health"
    echo -e "  $0 --debug         # Debug all services"
    echo -e "  $0 --clean         # Clean restart with data"
    echo -e "  $0 --ordered       # Ordered deployment"
    echo -e "  $0 --fresh         # Complete reset"
    echo -e "  docker exec namenode hdfs dfs -ls '/data'  # Browse HDFS"
    echo -e "  docker exec kafka kafka-topics --bootstrap-server localhost:9092 --list  # List Kafka topics"
    echo -e "  docker exec hive-server beeline -u jdbc:hive2://localhost:10000  # Hive CLI"
    echo -e "  docker-compose logs [service]  # View service logs"
}

# ============ LOGIQUE PRINCIPALE ============

check_docker

case $ACTION in
    "status")
        show_containers_complete
        show_complete_service_health
        show_data_status
        show_access_info
        ;;
        
    "debug")
        debug_all_services
        show_complete_service_health
        ;;
        
    "ordered")
        complete_cleanup
        if deploy_all_services_ordered; then
            load_data
            show_complete_service_health
        else
            echo -e "${RED}❌ Ordered deployment failed${NC}"
            exit 1
        fi
        ;;
        
    "clean")
        echo -e "\n${YELLOW}🧹 Clean restart with complete deployment...${NC}"
        complete_cleanup
        if deploy_all_services_ordered; then
            load_data
        else
            echo -e "${RED}❌ Cluster deployment failed${NC}"
            exit 1
        fi
        ;;
        
    "fresh")
        echo -e "\n${RED}🧹 Fresh deployment - complete reset...${NC}"
        complete_cleanup
        if deploy_all_services_ordered; then
            load_data
        else
            echo -e "${RED}❌ Fresh deployment failed${NC}"
            exit 1
        fi
        ;;
        
    "deploy")
        # Vérifier si déjà en cours
        if show_containers_complete >/dev/null 2>&1; then
            echo -e "\n${GREEN}✅ Containers already running${NC}"
            echo -e "${BLUE}📋 Performing complete health check...${NC}"
            
            if show_complete_service_health; then
                echo -e "\n${GREEN}🎉 Cluster is healthy and ready!${NC}"
                
                # Vérifier si données présentes
                if docker exec namenode hdfs dfs -ls '/data' >/dev/null 2>&1; then
                    echo -e "${GREEN}✅ Data already loaded${NC}"
                else
                    echo -e "${YELLOW}📥 No data found, loading...${NC}"
                    load_data
                fi
            else
                echo -e "\n${YELLOW}⚠️ Some services have issues${NC}"
                echo -e "${YELLOW}💡 Try: $0 --clean for a restart${NC}"
                echo -e "${YELLOW}💡 Or: $0 --debug for detailed diagnosis${NC}"
            fi
        else
            echo -e "\n${YELLOW}📋 No containers running, starting complete deployment...${NC}"
            if deploy_all_services_ordered; then
                load_data
            else
                echo -e "${RED}❌ Deployment failed${NC}"
                exit 1
            fi
        fi
        ;;
esac

# Résumé final
echo -e "\n${GREEN}✅ Operation completed!${NC}"

# Afficher les infos d'accès si le cluster tourne
if [[ $ACTION != "status" ]] && [[ $ACTION != "debug" ]] && docker ps --format "{{.Names}}" | grep -q "namenode"; then
    show_complete_service_health
    show_access_info
    
    echo -e "\n${BLUE}🎯 Next Steps:${NC}"
    echo -e "  • Visit http://localhost:9870 to browse HDFS"
    echo -e "  • Visit http://localhost:8501 for the dashboard"
    echo -e "  • Run '$0 --status' anytime for complete health check"
    echo -e "  • Run '$0 --debug' if any issues occur"
    echo -e "\n${GREEN}🚀 Your complete Hadoop + AI cluster is ready for the presentation!${NC}"
fi