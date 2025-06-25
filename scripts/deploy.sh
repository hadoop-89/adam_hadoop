#!/bin/bash
# Script de déploiement COMPLET Hadoop - Tout-en-un avec délais et data-loader

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

echo -e "${BLUE}🚀 Hadoop Cluster Deployment (Complete)${NC}"
echo -e "${BLUE}=====================================${NC}"

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
        echo -e "${BLUE}📊 Mode: Status check only${NC}"
        ;;
    --no-data)
        ACTION="deploy"
        SKIP_DATA_LOADER=true
        echo -e "${BLUE}📋 Mode: Deploy without data loading${NC}"
        ;;
    --help|-h)
        echo -e "${YELLOW}Usage: $0 [--clean|--fresh|--status|--no-data|--help]${NC}"
        echo "  (no args)  Complete deployment with data loading"
        echo "  --clean    Clean restart with data loading"
        echo "  --fresh    Complete reset and fresh install"
        echo "  --status   Show current status only"
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

# ============ FONCTIONS ============

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
    echo -e "\n${RED}🧹 COMPLETE CLEANUP${NC}"
    
    # 1. Arrêter tous les conteneurs
    echo -e "${YELLOW}⏹️ Stopping all containers...${NC}"
    docker-compose down --remove-orphans -v || true
    
    # 2. Supprimer conteneurs orphelins
    echo -e "${YELLOW}🗑️ Removing orphaned containers...${NC}"
    docker ps -a --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard|spark|kafka|hive)" | xargs -r docker rm -f || true
    
    # 3. Supprimer volumes
    echo -e "${YELLOW}💾 Removing volumes...${NC}"
    docker volume ls -q | grep -E "(hadoop|namenode|datanode)" | xargs -r docker volume rm -f || true
    docker volume rm -f $(docker volume ls -q | grep "adam_hadoop" || true) 2>/dev/null || true
    
    # 4. Nettoyage général
    echo -e "${YELLOW}🧽 General cleanup...${NC}"
    docker system prune -f
    docker volume prune -f
    
    echo -e "${GREEN}✅ Complete cleanup finished${NC}"
}

wait_for_service() {
    local name=$1
    local url=$2
    local max_wait=${3:-180}
    local elapsed=0
    
    echo -e "${YELLOW}⏳ Waiting for $name...${NC}"
    
    while [[ $elapsed -lt $max_wait ]]; do
        if curl -f -s --max-time 3 "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $name is ready (${elapsed}s)${NC}"
            return 0
        fi
        
        sleep 5
        elapsed=$((elapsed + 5))
        
        if [[ $((elapsed % 30)) -eq 0 ]]; then
            echo -e "${BLUE}... still waiting (${elapsed}s/${max_wait}s)${NC}"
        fi
    done
    
    echo -e "${RED}❌ $name timeout after ${max_wait}s${NC}"
    return 1
}

check_datanodes_connection() {
    echo -e "\n${BLUE}🔍 Checking DataNodes connection...${NC}"
    
    local max_attempts=20
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        local connected_nodes=$(docker exec namenode hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | grep -o '[0-9]\+' | head -1 || echo "0")
        
        echo -e "${BLUE}Attempt $((attempt + 1))/$max_attempts: $connected_nodes/2 DataNodes connected${NC}"
        
        if [[ "$connected_nodes" -ge "2" ]]; then
            echo -e "${GREEN}✅ All DataNodes connected successfully!${NC}"
            return 0
        fi
        
        sleep 10
        ((attempt++))
    done
    
    echo -e "${YELLOW}⚠️ Only $connected_nodes/2 DataNodes connected after $((max_attempts * 10))s${NC}"
    echo -e "${YELLOW}💡 Cluster will work but with reduced redundancy${NC}"
    return 0  # Continue même si tous les DataNodes ne sont pas connectés
}

deploy_cluster_complete() {
    echo -e "\n${YELLOW}🏗️ COMPLETE HADOOP DEPLOYMENT${NC}"
    
    # 1. Build des images
    echo -e "\n${YELLOW}📦 Building images...${NC}"
    docker-compose build --no-cache
    
    # 2. Démarrage NameNode en premier
    echo -e "\n${YELLOW}🖥️ Starting NameNode first...${NC}"
    docker-compose up -d namenode
    
    # 3. Attendre NameNode
    echo -e "\n${YELLOW}⏳ Waiting for NameNode startup (45s)...${NC}"
    sleep 45
    
    if ! wait_for_service "NameNode" "http://localhost:9870" 120; then
        echo -e "${RED}❌ NameNode failed to start${NC}"
        echo -e "${YELLOW}💡 Check logs: docker logs namenode${NC}"
        return 1
    fi
    
    # 4. Démarrage DataNodes
    echo -e "\n${YELLOW}📊 Starting DataNodes...${NC}"
    docker-compose up -d datanode1 datanode2
    
    # 5. Attendre DataNodes
    echo -e "\n${YELLOW}⏳ Waiting for DataNodes startup (60s)...${NC}"
    sleep 60
    
    # Vérifier DataNodes individuellement
    wait_for_service "DataNode1" "http://localhost:9864" 60 || echo -e "${YELLOW}⚠️ DataNode1 not responding${NC}"
    wait_for_service "DataNode2" "http://localhost:9865" 60 || echo -e "${YELLOW}⚠️ DataNode2 not responding${NC}"
    
    # 6. Vérifier connexion HDFS
    echo -e "\n${BLUE}🧪 Testing HDFS connectivity...${NC}"
    if docker exec namenode hdfs dfs -ls '/' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS filesystem accessible${NC}"
    else
        echo -e "${RED}❌ HDFS not accessible yet, waiting 30s more...${NC}"
        sleep 30
        if docker exec namenode hdfs dfs -ls '/' >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HDFS now accessible${NC}"
        else
            echo -e "${RED}❌ HDFS still not accessible${NC}"
            return 1
        fi
    fi
    
    # 7. Vérifier connexion DataNodes
    check_datanodes_connection
    
    # 8. Démarrer services complémentaires
    echo -e "\n${YELLOW}🌐 Starting complementary services...${NC}"
    docker-compose up -d
    
    # 9. Attendre stabilisation
    echo -e "\n${YELLOW}⏳ Cluster stabilization (30s)...${NC}"
    sleep 30
    
    # 10. Services optionnels
    wait_for_service "Dashboard" "http://localhost:8501" 60 || echo -e "${YELLOW}⚠️ Dashboard not ready yet${NC}"
    wait_for_service "Spark Master" "http://localhost:8080" 30 || echo -e "${YELLOW}⚠️ Spark not ready yet${NC}"
    
    echo -e "\n${GREEN}✅ Hadoop cluster deployment completed!${NC}"
    return 0
}

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
            
            # Statistiques
            echo -e "\n${YELLOW}📈 Data statistics:${NC}"
            docker exec namenode hdfs dfs -du -h '/data/text/existing/' 2>/dev/null || echo "  Text data: checking..."
            docker exec namenode hdfs dfs -du -h '/data/images/existing/' 2>/dev/null || echo "  Image data: checking..."
        else
            echo -e "${YELLOW}⚠️ Data directory not found, but data-loader completed${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ Data loading failed${NC}"
        echo -e "${YELLOW}💡 Check logs: docker logs data-loader${NC}"
        return 1
    fi
}

show_containers() {
    echo -e "\n${BLUE}📊 Container Status:${NC}"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(namenode|datanode|dashboard|spark|kafka)" 2>/dev/null; then
        return 0
    else
        echo -e "${YELLOW}No Hadoop containers running${NC}"
        return 1
    fi
}

show_service_health() {
    echo -e "\n${BLUE}🏥 Service Health Check:${NC}"
    
    local services=(
        "NameNode Web:http://localhost:9870"
        "DataNode1:http://localhost:9864"
        "DataNode2:http://localhost:9865"
        "Dashboard:http://localhost:8501"
        "Spark Master:http://localhost:8080"
    )
    
    local healthy=0
    local total=${#services[@]}
    
    for service in "${services[@]}"; do
        local name="${service%%:*}"
        local url="${service#*:}"
        
        if curl -f -s --max-time 5 "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $name${NC}"
            ((healthy++))
        else
            echo -e "${RED}❌ $name${NC}"
        fi
    done
    
    echo -e "\n${BLUE}📈 Health Summary: ${GREEN}$healthy${NC}/${BLUE}$total${NC} services healthy"
    
    # Vérifier HDFS et DataNodes
    if [[ $healthy -gt 0 ]]; then
        echo -e "\n${BLUE}📊 HDFS Status:${NC}"
        if docker exec namenode hdfs dfs -ls '/' >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HDFS accessible${NC}"
            
            local connected_nodes=$(docker exec namenode hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | grep -o '[0-9]\+' | head -1 || echo "0")
            echo -e "${GREEN}📊 DataNodes connected: $connected_nodes/2${NC}"
            
            if docker exec namenode hdfs dfs -ls '/data' >/dev/null 2>&1; then
                echo -e "${GREEN}✅ Data loaded in HDFS${NC}"
            else
                echo -e "${YELLOW}⚠️ No data in HDFS${NC}"
            fi
        else
            echo -e "${RED}❌ HDFS not accessible${NC}"
        fi
    fi
    
    if [[ $healthy -eq $total ]]; then
        echo -e "\n${GREEN}🎉 All services are healthy!${NC}"
        return 0
    elif [[ $healthy -gt 0 ]]; then
        echo -e "\n${YELLOW}⚠️ Some services need attention${NC}"
        return 1
    else
        echo -e "\n${RED}❌ No services responding${NC}"
        return 2
    fi
}


wait_for_service() {
    local name=$1
    local url=$2
    local max_wait=${3:-180}  # 3 minutes par défaut
    local elapsed=0
    
    echo -e "${YELLOW}⏳ Waiting for $name...${NC}"
    
    while [[ $elapsed -lt $max_wait ]]; do
        if check_service_health "$name" "$url" 3; then
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

test_hdfs() {
    echo -e "\n${YELLOW}🧪 Testing HDFS...${NC}"
    
    # Test basique de connexion HDFS
    if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS filesystem accessible${NC}"
        
        # Test lecture de données
        if docker exec namenode hdfs dfs -ls /data >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HDFS data directory accessible${NC}"
        else
            echo -e "${YELLOW}⚠️ HDFS data directory not found (normal on first run)${NC}"
        fi
        
        return 0
    else
        echo -e "${RED}❌ HDFS not accessible${NC}"
        return 1
    fi
}

run_data_loader() {
    echo -e "\n${YELLOW}⬇️ Loading datasets into HDFS...${NC}"
    if [[ -f "$HOME/.kaggle/kaggle.json" ]]; then
        docker-compose run --rm -v "$HOME/.kaggle":/root/.kaggle data-loader
    else
        docker-compose run --rm -e KAGGLE_USERNAME -e KAGGLE_KEY data-loader
    fi
}

fix_hive() {
    echo -e "\n${YELLOW}🔧 Fixing Hive configuration...${NC}"
    
    # Arrêter les services Hive
    echo -e "${YELLOW}⏹️ Stopping Hive services...${NC}"
    docker-compose stop hive-metastore hive-server || true
    docker-compose rm -f hive-metastore hive-server || true
    
    # Nettoyer les volumes problématiques
    echo -e "${YELLOW}🗑️ Cleaning problematic volumes...${NC}"
    docker volume rm $(docker volume ls -q | grep postgres) 2>/dev/null || true
    
    # Redémarrer Hive avec nouvelle configuration
    echo -e "${YELLOW}🚀 Starting Hive with Derby configuration...${NC}"
    docker-compose up -d hive-metastore hive-server
    
    # Attendre le démarrage
    echo -e "${YELLOW}⏳ Waiting for Hive to start (60s)...${NC}"
    sleep 60
    
    # Test Hive
    if docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e "SHOW DATABASES;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Hive is now working properly!${NC}"
        return 0
    else
        echo -e "${RED}❌ Hive still has issues${NC}"
        echo -e "${YELLOW}💡 Check logs: docker logs hive-server${NC}"
        return 1
    fi
}

deploy_cluster() {
    echo -e "\n${YELLOW}📦 Starting Hadoop cluster...${NC}"
    
    # Démarrer les services
    if docker-compose up -d; then
        echo -e "${GREEN}✅ Docker Compose started${NC}"
    else
        echo -e "${RED}❌ Failed to start containers${NC}"
        echo -e "${YELLOW}💡 Try: docker-compose logs${NC}"
        return 1
    fi
    
    # Attendre les services critiques
    echo -e "\n${YELLOW}⏳ Waiting for services to start...${NC}"
    
    # NameNode est critique
    if wait_for_service "NameNode" "http://localhost:9870" 120; then
        echo -e "${GREEN}✅ NameNode started successfully${NC}"
    else
        echo -e "${RED}❌ NameNode failed to start${NC}"
        echo -e "${YELLOW}💡 Check: docker logs namenode${NC}"
        return 1
    fi
    
    # Attendre un peu pour que HDFS s'initialise
    echo -e "${YELLOW}⏳ Waiting for HDFS initialization...${NC}"
    sleep 20
    
    # Dashboard
    wait_for_service "Dashboard" "http://localhost:8501" 60 || echo -e "${YELLOW}⚠️ Dashboard not ready yet${NC}"
    
    # Test HDFS
    test_hdfs || echo -e "${YELLOW}⚠️ HDFS might need more time${NC}"

    # Charger les données pour créer la structure HDFS
    run_data_loader || echo -e "${YELLOW}⚠️ Data loader failed${NC}"
    
    return 0
}



show_access_info() {
    echo -e "\n${BLUE}📊 Access Information:${NC}"
    echo -e "${GREEN}• NameNode Web UI: http://localhost:9870${NC}"
    echo -e "${GREEN}• DataNode1 Web UI: http://localhost:9864${NC}"
    echo -e "${GREEN}• DataNode2 Web UI: http://localhost:9865${NC}"
    echo -e "${GREEN}• Streamlit Dashboard: http://localhost:8501${NC}"
    echo -e "${GREEN}• Spark Master UI: http://localhost:8080${NC}"
    
    echo -e "\n${YELLOW}💡 Useful commands:${NC}"
    echo -e "  $0 --status        # Check cluster health"
    echo -e "  $0 --clean         # Clean restart with data"
    echo -e "  $0 --fresh         # Complete reset"
    echo -e "  $0 --no-data       # Deploy without data loading"
    echo -e "  docker exec namenode hdfs dfs -ls '/data'  # Browse HDFS data"
    echo -e "  docker-compose logs [service]  # View logs"
}

# ============ LOGIQUE PRINCIPALE ============

check_docker

case $ACTION in
    "status")
        show_containers
        show_service_health
        show_access_info
        ;;
        
    "clean")
        echo -e "\n${YELLOW}🧹 Clean restart with complete deployment...${NC}"
        complete_cleanup
        if deploy_cluster_complete; then
            load_data
        else
            echo -e "${RED}❌ Cluster deployment failed${NC}"
            exit 1
        fi
        ;;
        
    "fresh")
        echo -e "\n${RED}🧹 Fresh deployment - complete reset...${NC}"
        complete_cleanup
        if deploy_cluster_complete; then
            load_data
        else
            echo -e "${RED}❌ Fresh deployment failed${NC}"
            exit 1
        fi
        ;;
        
    "deploy")
        # Vérifier si déjà en cours
        if show_containers >/dev/null 2>&1; then
            echo -e "\n${GREEN}✅ Containers already running${NC}"
            echo -e "${BLUE}📋 Performing health check...${NC}"
            
            if show_service_health; then
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
            fi
        else
            echo -e "\n${YELLOW}📋 No containers running, starting complete deployment...${NC}"
            if deploy_cluster_complete; then
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
if [[ $ACTION != "status" ]] && docker ps --format "{{.Names}}" | grep -q "namenode"; then
    show_service_health
    show_access_info
    
    echo -e "\n${BLUE}🎯 Next steps:${NC}"
    echo -e "  • Visit http://localhost:9870 to browse HDFS"
    echo -e "  • Visit http://localhost:8501 for the dashboard"
    echo -e "  • Run '$0 --status' anytime to check health"
    echo -e "\n${GREEN}🚀 Your Hadoop cluster with data is ready for the presentation!${NC}"
fi