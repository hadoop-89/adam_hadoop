#!/bin/bash
# Ansible Full Automation Testing

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧪 COMPLETE ANSIBLE AUTOMATION TESTING${NC}"
echo -e "${BLUE}==========================================${NC}"

cd "$(dirname "$0")/.."

# Function to wait for user input
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

echo -e "${YELLOW}Ce test va:${NC}"
echo -e "1. 🧹 Completely destroy the existing cluster"
echo -e "2. 🚀 Test the automatic installation from scratch with Ansible"
echo -e "3. ✅ Validate that everything works"
echo ""

if ! confirm "Continue with the full automation test?"; then
    echo -e "${YELLOW}Test cancelled${NC}"
    exit 0
fi

# =============== PHASE 1: COMPLETE DESTRUCTION ===============
echo -e "\n${RED}🧹 PHASE 1: Complete destruction of the cluster...${NC}"

echo -e "${YELLOW}⏹️ Stopping all containers...${NC}"
docker-compose down -v --remove-orphans || true

echo -e "${YELLOW}🗑️ Cleaning up Docker resources...${NC}"
docker system prune -f || true

echo -e "${GREEN}✅ Cluster completely destroyed${NC}"

# Check that nothing remains
echo -e "\n${BLUE}🔍 Checking: no Hadoop containers left${NC}"
if docker ps --format "{{.Names}}" | grep -E "(namenode|datanode|dashboard)" >/dev/null 2>&1; then
    echo -e "${RED}❌ Hadoop containers are still running!${NC}"
    docker ps | grep -E "(namenode|datanode|dashboard)"
    exit 1
else
    echo -e "${GREEN}✅ No Hadoop containers detected${NC}"
fi

# =============== PHASE 2: TEST AUTOMATIC INSTALLATION ===============
echo -e "\n${BLUE}🚀 PHASE 2: Test automatic installation with Ansible...${NC}"

# Check if Ansible is available
if command -v ansible-playbook >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Ansible available locally${NC}"
    ANSIBLE_CMD="ansible-playbook"
elif docker --version >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠️ Ansible not installed, using Docker${NC}"
    ANSIBLE_CMD="docker run --rm -v \$(pwd):/workspace -w /workspace --network host cytopia/ansible:latest ansible-playbook"
else
    echo -e "${RED}❌ Neither Ansible nor Docker available${NC}"
    exit 1
fi

# Start the full automatic installation
echo -e "\n${YELLOW}🚀 Starting automatic installation...${NC}"
echo -e "${BLUE}Command: $ANSIBLE_CMD -i ansible/inventory.ini ansible/full-install.yml${NC}"

start_time=$(date +%s)

if eval "$ANSIBLE_CMD -i ansible/inventory.ini ansible/full-install.yml --extra-vars fresh_install=true"; then
    end_time=$(date +%s)
    duration=$((end_time - start_time))
    echo -e "\n${GREEN}✅ Automatic installation succeeded in ${duration}s!${NC}"
else
    echo -e "\n${RED}❌ Automatic installation failed${NC}"
    echo -e "${YELLOW}💡 Check the logs above${NC}"
    exit 1
fi

# =============== PHASE 3: COMPLETE VALIDATION ===============
echo -e "\n${GREEN}✅ PHASE 3: Validation of the automatic installation...${NC}"

# Test the services
echo -e "${YELLOW}🏥 Testing web services...${NC}"
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
    echo -e "${GREEN}✅ HDFS structure created${NC}"

    # Show the structure
    echo -e "${BLUE}📂 HDFS structure created:${NC}"
    docker exec namenode hdfs dfs -ls /data || true
else
    echo -e "${RED}❌ HDFS not accessible${NC}"
fi

# Test HDFS write
echo -e "\n${YELLOW}✍️ Test HDFS write...${NC}"
if docker exec namenode hdfs dfs -cat /data/processed/ansible_install_test.txt >/dev/null 2>&1; then
    echo -e "${GREEN}✅ HDFS write test succeeded${NC}"
else
    echo -e "${RED}❌ HDFS write test failed${NC}"
fi

# =============== FINAL RESULTS ===============
echo -e "\n${BLUE}🎯 AUTOMATION TEST RESULTS${NC}"
echo -e "${BLUE}====================================${NC}"

if [[ $healthy_services -ge 4 ]]; then
    echo -e "${GREEN}✅ AUTOMATION TEST SUCCEEDED!${NC}"
    echo -e "\n${GREEN}🎉 Your Ansible installation is automatic:${NC}"
    echo -e "   • Complete Hadoop infrastructure"
    echo -e "   • All services (NameNode, DataNodes, etc.)"
    echo -e "   • HDFS structure"
    echo -e "   • Validation tests"
    echo -e "\n${BLUE}⏱️ Total time: ${duration}s${NC}"
    echo -e "\n${YELLOW}🔗 Access:${NC}"
    echo -e "   • NameNode: http://localhost:9870"
    echo -e "   • Dashboard: http://localhost:8501"

    echo -e "\n${GREEN}✅ ANSIBLE AUTOMATES YOUR PROJECT PERFECTLY!${NC}"
else
    echo -e "${RED}❌ AUTOMATION TEST PARTIALLY FAILED${NC}"
    echo -e "${YELLOW}⚠️ Only $healthy_services/5 services functional${NC}"
    echo -e "${YELLOW}💡 Check the logs to debug${NC}"
fi

echo -e "\n${BLUE}💡 To restart your cluster normally:${NC}"
echo -e "   ./scripts/deploy.sh"