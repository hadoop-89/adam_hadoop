#!/bin/bash
# Script de déploiement SIMPLE - Sans problèmes Windows - Version finale

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

echo -e "${BLUE}🚀 Hadoop Cluster Deployment (Simple)${NC}"
echo -e "${BLUE}====================================${NC}"

# Aller au répertoire du projet
cd "$(dirname "$0")/.."
PROJECT_ROOT="$(pwd)"
echo -e "${YELLOW}📂 Project: $PROJECT_ROOT${NC}"

# Parse arguments
ACTION="deploy"
case "${1:-}" in
    --clean) 
        ACTION="clean"
        echo -e "${YELLOW}🧹 Mode: Clean restart${NC}"
        ;;
    --fresh) 
        ACTION="fresh" 
        echo -e "${RED}🧹 Mode: Fresh deployment${NC}"
        ;;
    --status) 
        ACTION="status"
        echo -e "${BLUE}📊 Mode: Status check${NC}"
        ;;
    --fix-hive)
        ACTION="fix-hive"
        echo -e "${YELLOW}🔧 Mode: Fix Hive${NC}"
        ;;
    --help|-h)
        echo -e "${YELLOW}Usage: $0 [--clean|--fresh|--status|--fix-hive|--help]${NC}"
        echo "  (no args)  Deploy or check current cluster"
        echo "  --clean    Stop and restart containers"
        echo "  --fresh    Complete reset with data removal"
        echo "  --status   Show current status only"
        echo "  --fix-hive Fix Hive configuration issues"
        echo "  --help     Show this help"
        exit 0
        ;;
    "")
        echo -e "${BLUE}📋 Mode: Smart deployment${NC}"
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

show_containers() {
    echo -e "\n${BLUE}📊 Container Status:${NC}"
    
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(namenode|datanode|dashboard|spark|kafka)" 2>/dev/null; then
        return 0
    else
        echo -e "${YELLOW}No Hadoop containers running${NC}"
        return 1
    fi
}

check_service_health() {
    local name=$1
    local url=$2
    local timeout=${3:-5}
    
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s --max-time $timeout "$url" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ $name${NC}"
            return 0
        else
            echo -e "${RED}❌ $name${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️ $name (curl not available)${NC}"
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
        
        if check_service_health "$name" "$url"; then
            ((healthy++))
        fi
    done
    
    echo -e "\n${BLUE}📈 Health Summary: ${GREEN}$healthy${NC}/${BLUE}$total${NC} services healthy"
    
    if [[ $healthy -eq $total ]]; then
        echo -e "${GREEN}🎉 All services are healthy!${NC}"
        return 0
    elif [[ $healthy -gt 0 ]]; then
        echo -e "${YELLOW}⚠️ Some services need attention${NC}"
        return 1
    else
        echo -e "${RED}❌ No services responding${NC}"
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
    echo -e "${GREEN}• Kafka (internal): localhost:9092${NC}"
    
    echo -e "\n${YELLOW}💡 Useful commands:${NC}"
    echo -e "  $0 --status     # Check cluster health"
    echo -e "  $0 --clean      # Clean restart"
    echo -e "  $0 --fix-hive   # Fix Hive issues"
    echo -e "  docker-compose logs [service]  # View logs"
    echo -e "  docker exec namenode hdfs dfs -ls /  # Browse HDFS"
}

# ============ LOGIQUE PRINCIPALE ============

check_docker

case $ACTION in
    "status")
        show_containers
        show_service_health
        if docker ps --format "{{.Names}}" | grep -q "namenode"; then
            test_hdfs
        fi
        show_access_info
        ;;
        
    "clean")
        echo -e "\n${YELLOW}🧹 Stopping containers...${NC}"
        docker-compose down --remove-orphans || true
        echo -e "${GREEN}✅ Containers stopped${NC}"
        
        deploy_cluster
        ;;
        
    "fresh")
        echo -e "\n${RED}🧹 Fresh deployment - cleaning everything...${NC}"
        docker-compose down -v --remove-orphans || true
        docker volume prune -f || true
        echo -e "${GREEN}✅ Clean slate ready${NC}"
        
        deploy_cluster
        ;;
        
    "fix-hive")
        fix_hive
        ;;
        
    "deploy")
        # Vérifier si déjà en cours
        if show_containers >/dev/null 2>&1; then
            echo -e "\n${GREEN}✅ Containers already running${NC}"
            echo -e "${BLUE}📋 Performing health check...${NC}"
            
            if show_service_health; then
                echo -e "\n${GREEN}🎉 Cluster is healthy and ready!${NC}"
            else
                echo -e "\n${YELLOW}⚠️ Some services have issues${NC}"
                echo -e "${YELLOW}💡 Try: $0 --clean for a restart${NC}"
                echo -e "${YELLOW}💡 Try: $0 --fix-hive if Hive issues${NC}"
            fi
        else
            echo -e "\n${YELLOW}📋 No containers running, starting cluster...${NC}"
            deploy_cluster
        fi
        ;;
esac

# Résumé final
echo -e "\n${GREEN}✅ Operation completed!${NC}"

# Afficher les infos d'accès si le cluster tourne
if [[ $ACTION != "status" ]] && docker ps --format "{{.Names}}" | grep -q "namenode"; then
    show_service_health
    show_access_info
fi

echo -e "\n${BLUE}🎯 Next steps:${NC}"
echo -e "  • Visit http://localhost:9870 to see HDFS"
echo -e "  • Visit http://localhost:8501 for the dashboard"
echo -e "  • Run '$0 --status' anytime to check health"
echo -e "  • Run '$0 --fix-hive' if Hive has issues"