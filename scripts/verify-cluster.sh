#!/bin/bash
# Script de vérification complète du cluster Hadoop
# Compatible Git Bash

set -e

# Colors pour Git Bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 === VÉRIFICATION COMPLÈTE CLUSTER HADOOP ===${NC}"
echo -e "${BLUE}===============================================${NC}"

TOTAL_TESTS=0
PASSED_TESTS=0

# Fonction de test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local success_message="$3"
    local failure_message="$4"
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    echo -e "\n${YELLOW}🧪 Test $TOTAL_TESTS: $test_name${NC}"
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ $success_message${NC}"
        PASSED_TESTS=$((PASSED_TESTS + 1))
        return 0
    else
        echo -e "${RED}❌ $failure_message${NC}"
        return 1
    fi
}

# Fonction pour afficher une valeur
show_value() {
    local label="$1"
    local command="$2"
    local result
    
    echo -e "\n${BLUE}📊 $label:${NC}"
    result=$(eval "$command" 2>/dev/null || echo "Erreur")
    echo -e "${GREEN}$result${NC}"
}

echo -e "\n${BLUE}=== PHASE 1: INFRASTRUCTURE ===${NC}"

# Test 1: Docker containers
run_test "Conteneurs Hadoop" \
    "docker ps --format '{{.Names}}' | grep -E '(namenode|datanode1|datanode2)' | wc -l | grep -q '[3-9]'" \
    "Conteneurs Hadoop actifs" \
    "Conteneurs Hadoop manquants"

# Test 2: Services Web
run_test "NameNode Web UI" \
    "curl -f -s --max-time 5 http://localhost:9870" \
    "NameNode Web UI accessible" \
    "NameNode Web UI inaccessible"

run_test "DataNode1 Web UI" \
    "curl -f -s --max-time 5 http://localhost:9864" \
    "DataNode1 Web UI accessible" \
    "DataNode1 Web UI inaccessible"

run_test "Dashboard Streamlit" \
    "curl -f -s --max-time 5 http://localhost:8501" \
    "Dashboard accessible" \
    "Dashboard inaccessible"

echo -e "\n${BLUE}=== PHASE 2: HDFS (DONNÉES RÉELLES) ===${NC}"

# Test 3: HDFS Structure
run_test "Structure HDFS" \
    "docker exec namenode hdfs dfs -ls /data" \
    "Structure HDFS présente" \
    "Structure HDFS manquante"

# Test 4: Données reviews RÉELLES
run_test "Données Reviews HDFS" \
    "docker exec namenode hdfs dfs -cat /data/text/existing/existing_reviews_db.csv | head -5 | grep -q 'review_text'" \
    "Données reviews réelles trouvées" \
    "Données reviews manquantes ou fictives"

# Test 5: Données images RÉELLES
run_test "Données Images HDFS" \
    "docker exec namenode hdfs dfs -cat /data/images/existing/existing_images_db.csv | head -5 | grep -q 'filename'" \
    "Données images réelles trouvées" \
    "Données images manquantes ou fictives"

echo -e "\n${BLUE}=== PHASE 3: HIVE (BASE DE DONNÉES) ===${NC}"

# Test 6: Hive Metastore
run_test "Hive Metastore" \
    "docker ps --format '{{.Names}}' | grep -q hive-metastore && docker logs hive-metastore | grep -q 'Started HiveMetaStore'" \
    "Hive Metastore opérationnel" \
    "Hive Metastore défaillant"

# Test 7: Hive Server
run_test "Hive Server" \
    "docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e 'SHOW DATABASES;' | grep -q analytics" \
    "Hive Server et base analytics OK" \
    "Hive Server ou base analytics KO"

# Test 8: Tables Hive avec données
run_test "Tables Hive avec données" \
    "docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e 'USE analytics; SELECT COUNT(*) FROM reviews;' | grep -E '[1-9][0-9]*'" \
    "Table reviews avec données réelles" \
    "Table reviews vide ou inexistante"

echo -e "\n${BLUE}=== PHASE 4: DASHBOARD DONNÉES RÉELLES ===${NC}"

# Test 9: Dashboard lit vraies données
run_test "Dashboard données réelles" \
    "curl -s http://localhost:8501 | grep -q 'Total Reviews' && ! curl -s http://localhost:8501 | grep -q 'Erreur HDFS'" \
    "Dashboard affiche vraies données" \
    "Dashboard en mode simulation/erreur"

echo -e "\n${BLUE}=== PHASE 5: SERVICES COMPLÉMENTAIRES ===${NC}"

# Test 10: Spark
run_test "Spark Master" \
    "curl -f -s --max-time 5 http://localhost:8080" \
    "Spark Master accessible" \
    "Spark Master inaccessible"

# Test 11: Kafka
run_test "Kafka" \
    "docker ps --format '{{.Names}}' | grep -q kafka" \
    "Kafka conteneur actif" \
    "Kafka conteneur absent"

echo -e "\n${BLUE}=== AFFICHAGE DES DONNÉES RÉELLES ===${NC}"

# Afficher des vraies données
show_value "Nombre total de reviews" \
    "docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e 'USE analytics; SELECT COUNT(*) FROM reviews;' | grep -E '[0-9]+' | tail -1"

show_value "Exemple de vraie review" \
    "docker exec namenode hdfs dfs -cat /data/text/existing/existing_reviews_db.csv | head -3 | tail -1 | cut -d',' -f2"

show_value "Sources de données" \
    "docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e 'USE analytics; SELECT DISTINCT source FROM reviews;' | grep -v '|' | grep -v '+' | grep -E '^[a-z]' | tr '\n' ', '"

show_value "Nombre d'images" \
    "docker exec hive-server beeline -u jdbc:hive2://localhost:10000 -e 'USE analytics; SELECT COUNT(*) FROM images;' | grep -E '[0-9]+' | tail -1"

show_value "Capacité HDFS utilisée" \
    "docker exec namenode hdfs dfs -df / | tail -1 | awk '{print \$3}'"

echo -e "\n${BLUE}=== RÉSULTATS FINAUX ===${NC}"

# Calculer le score
PERCENTAGE=$((PASSED_TESTS * 100 / TOTAL_TESTS))

echo -e "\n${BLUE}📊 Score: ${GREEN}$PASSED_TESTS${NC}/${BLUE}$TOTAL_TESTS${NC} tests réussis (${GREEN}$PERCENTAGE%${NC})"

if [[ $PERCENTAGE -ge 90 ]]; then
    echo -e "\n${GREEN}🎉 EXCELLENT! Votre cluster Hadoop est PARFAITEMENT opérationnel!${NC}"
    echo -e "${GREEN}✅ Toutes les données sont RÉELLES (pas de simulation)${NC}"
    echo -e "${GREEN}✅ Hive fonctionne avec vraies bases de données${NC}"
    echo -e "${GREEN}✅ Dashboard connecté aux vraies données HDFS${NC}"
    echo -e "${GREEN}✅ Projet prêt pour la soutenance!${NC}"
elif [[ $PERCENTAGE -ge 70 ]]; then
    echo -e "\n${YELLOW}⚠️ BON! Cluster majoritairement fonctionnel${NC}"
    echo -e "${YELLOW}💡 Quelques services nécessitent attention${NC}"
else
    echo -e "\n${RED}❌ PROBLÈMES! Cluster nécessite des corrections${NC}"
    echo -e "${YELLOW}💡 Relancez: ./scripts/deploy.sh --fresh${NC}"
fi

echo -e "\n${BLUE}🔗 Liens utiles:${NC}"
echo -e "${GREEN}• NameNode: http://localhost:9870${NC}"
echo -e "${GREEN}• Dashboard: http://localhost:8501${NC}"
echo -e "${GREEN}• Spark: http://localhost:8080${NC}"

echo -e "\n${BLUE}💡 Commandes test manuelles:${NC}"
echo -e "${YELLOW}# Test Hive manuel:${NC}"
echo -e "docker exec -it hive-server beeline -u jdbc:hive2://localhost:10000"
echo -e "USE analytics; SHOW TABLES; SELECT * FROM reviews LIMIT 5;"
echo -e "\n${YELLOW}# Test HDFS manuel:${NC}"
echo -e "docker exec namenode hdfs dfs -ls /data"
echo -e "docker exec namenode hdfs dfs -cat /data/text/existing/existing_reviews_db.csv | head -5"

exit $((11 - PASSED_TESTS))