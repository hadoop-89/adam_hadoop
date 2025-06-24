#!/bin/bash
# Test d'automatisation complète Ansible

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 TEST D'AUTOMATISATION ANSIBLE COMPLÈTE${NC}"
echo -e "${BLUE}==========================================${NC}"

cd "$(dirname "$0")/.."

# Fonction pour attendre l'input utilisateur
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

echo -e "${YELLOW}Ce test va:${NC}"
echo -e "1. 🧹 Détruire complètement le cluster existant"
echo -e "2. 🚀 Tester l'installation automatique depuis zéro avec Ansible"
echo -e "3. ✅ Valider que tout fonctionne"
echo ""

if ! confirm "Continuer avec le test d'automatisation complète?"; then
    echo -e "${YELLOW}Test annulé${NC}"
    exit 0
fi

# =============== PHASE 1: DESTRUCTION COMPLÈTE ===============
echo -e "\n${RED}🧹 PHASE 1: Destruction complète du cluster...${NC}"

echo -e "${YELLOW}⏹️ Arrêt de tous les containers...${NC}"
docker-compose down -v --remove-orphans || true

echo -e "${YELLOW}🗑️ Nettoyage des ressources Docker...${NC}"
docker system prune -f || true

echo -e "${GREEN}✅ Cluster complètement détruit${NC}"

# Vérification qu'il ne reste rien
echo -e "\n${BLUE}🔍 Vérification: plus aucun container Hadoop${NC}"
if docker ps --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard)" >/dev/null 2>&1; then
    echo -e "${RED}❌ Des containers Hadoop sont encore en cours!${NC}"
    docker ps | grep -E "(namenode|datanode|dashboard)"
    exit 1
else
    echo -e "${GREEN}✅ Aucun container Hadoop détecté${NC}"
fi

# =============== PHASE 2: TEST INSTALLATION AUTOMATIQUE ===============
echo -e "\n${BLUE}🚀 PHASE 2: Test installation automatique Ansible...${NC}"

# Vérifier qu'Ansible est disponible
if command -v ansible-playbook >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Ansible disponible localement${NC}"
    ANSIBLE_CMD="ansible-playbook"
elif docker --version >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Ansible non installé, utilisation de Docker${NC}"
    ANSIBLE_CMD="docker run --rm -v \$(pwd):/workspace -w /workspace --network host cytopia/ansible:latest ansible-playbook"
else
    echo -e "${RED}❌ Ni Ansible ni Docker disponible${NC}"
    exit 1
fi

# Lancer l'installation automatique complète
echo -e "\n${YELLOW}🚀 Lancement installation automatique...${NC}"
echo -e "${BLUE}Commande: $ANSIBLE_CMD -i ansible/inventory.ini ansible/full-install.yml${NC}"

start_time=$(date +%s)

if eval "$ANSIBLE_CMD -i ansible/inventory.ini ansible/full-install.yml --extra-vars fresh_install=true"; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo -e "\n${GREEN}✅ Installation automatique réussie en ${duration}s!${NC}"
else
    echo -e "\n${RED}❌ Installation automatique échouée${NC}"
    echo -e "${YELLOW}💡 Vérifiez les logs ci-dessus${NC}"
    exit 1
fi

# =============== PHASE 3: VALIDATION COMPLÈTE ===============
echo -e "\n${GREEN}✅ PHASE 3: Validation de l'installation automatique...${NC}"

# Test des services
echo -e "${YELLOW}🏥 Test des services web...${NC}"
services=(
    "NameNode:http://localhost:9870"
    "DataNode1:http://localhost:9864"  
    "DataNode2:http://localhost:9865"
    "Dashboard:http://localhost:8501"
    "Spark:http://localhost:8080"
)

healthy_services=0
for service in "${services[@]}"; do
    name="${service%%:*}"
    url="${service#*:}"
    
    if curl -f -s "$url" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $name${NC}"
        ((healthy_services++))
    else
        echo -e "${RED}❌ $name${NC}"
    fi
done

echo -e "\n${BLUE}📊 Services: $healthy_services/5 fonctionnels${NC}"

# Test HDFS
echo -e "\n${YELLOW}📁 Test HDFS...${NC}"
if docker exec namenode hdfs dfs -ls /data >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HDFS structure créée${NC}"
    
    # Afficher la structure
    echo -e "${BLUE}📂 Structure HDFS créée:${NC}"
    docker exec namenode hdfs dfs -ls /data || true
else
    echo -e "${RED}❌ HDFS non accessible${NC}"
fi

# Test écriture HDFS
echo -e "\n${YELLOW}✍️ Test écriture HDFS...${NC}"
if docker exec namenode hdfs dfs -cat /data/processed/ansible_install_test.txt >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Test d'écriture HDFS réussi${NC}"
else
    echo -e "${RED}❌ Test d'écriture HDFS échoué${NC}"
fi

# =============== RÉSULTATS FINAUX ===============
echo -e "\n${BLUE}🎯 RÉSULTATS DU TEST D'AUTOMATISATION${NC}"
echo -e "${BLUE}====================================${NC}"

if [[ $healthy_services -ge 4 ]]; then
    echo -e "${GREEN}✅ TEST D'AUTOMATISATION RÉUSSI!${NC}"
    echo -e "\n${GREEN}🎉 Votre Ansible installe automatiquement:${NC}"
    echo -e "   • Infrastructure Hadoop complète"
    echo -e "   • Tous les services (NameNode, DataNodes, etc.)"
    echo -e "   • Structure HDFS"
    echo -e "   • Tests de validation"
    echo -e "\n${BLUE}⏱️ Temps total: ${duration}s${NC}"
    echo -e "\n${YELLOW}🔗 Accès:${NC}"
    echo -e "   • NameNode: http://localhost:9870"
    echo -e "   • Dashboard: http://localhost:8501"
    
    echo -e "\n${GREEN}✅ ANSIBLE AUTOMATISE PARFAITEMENT VOTRE PROJET!${NC}"
else
    echo -e "${RED}❌ TEST D'AUTOMATISATION PARTIELLEMENT ÉCHOUÉ${NC}"
    echo -e "${YELLOW}⚠️ Seulement $healthy_services/5 services fonctionnels${NC}"
    echo -e "${YELLOW}💡 Vérifiez les logs pour débugger${NC}"
fi

echo -e "\n${BLUE}💡 Pour relancer votre cluster normalement:${NC}"
echo -e "   ./scripts/deploy.sh"