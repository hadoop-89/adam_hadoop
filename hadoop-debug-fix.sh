#!/bin/bash
# Hadoop diagnostic and remediation script

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 === ADVANCED HADOOP DIAGNOSTIC ===${NC}"

# Diagnostic function
diagnose_issue() {
    echo -e "\n${YELLOW}📋 Phase 1: Container diagnostics${NC}"
    
    # Container status
    echo -e "${BLUE}Running containers:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    echo -e "\n${YELLOW}📋 Phase 2: Network diagnostics${NC}"
    
    # Test network between containers
    echo -e "${BLUE}Test connectivity namenode -> datanode1:${NC}"
    if docker exec namenode ping -c 2 datanode1 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ namenode -> datanode1 OK${NC}"
    else
        echo -e "${RED}❌ namenode -> datanode1 FAILED${NC}"
    fi
    
    echo -e "${BLUE}Test connectivity namenode -> datanode2:${NC}"
    if docker exec namenode ping -c 2 datanode2 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ namenode -> datanode2 OK${NC}"
    else
        echo -e "${RED}❌ namenode -> datanode2 FAILED${NC}"
    fi

    echo -e "\n${YELLOW}📋 Phase 3: Logs NameNode (last 15 lines)${NC}"
    docker logs namenode | tail -15

    echo -e "\n${YELLOW}📋 Phase 4: Logs DataNode1 (last 10 lines)${NC}"
    docker logs datanode1 | tail -10

    echo -e "\n${YELLOW}📋 Phase 5: Logs DataNode2 (last 10 lines)${NC}"
    docker logs datanode2 | tail -10
    
    echo -e "\n${YELLOW}📋 Phase 6: Configuration NameNode${NC}"
    echo -e "${BLUE}Processus Java NameNode:${NC}"
    docker exec namenode ps aux | grep java || echo "No Java processes found"

    echo -e "\n${BLUE}Open ports NameNode:${NC}"
    docker exec namenode netstat -tlnp 2>/dev/null | grep :9000 || echo "Port 9000 not open"
    docker exec namenode netstat -tlnp 2>/dev/null | grep :9870 || echo "Port 9870 not open"

    echo -e "\n${YELLOW}📋 Phase 7: Test direct HDFS commands${NC}"
    echo -e "${BLUE}Test hdfs dfs -ls in NameNode:${NC}"
    docker exec namenode hdfs dfs -ls / 2>&1 || echo "HDFS command failed"

    echo -e "\n${BLUE}Test hdfs dfsadmin -report:${NC}"
    docker exec namenode hdfs dfsadmin -report 2>&1 || echo "HDFS report failed"
}

# Fix function
fix_hdfs_issues() {
    echo -e "\n${BLUE}🛠️ === ATTEMPTS TO FIX ===${NC}"

    # Fix 1: Reformat NameNode if necessary
    echo -e "\n${YELLOW}🔧 Fix 1: Check NameNode format${NC}"
    docker exec namenode bash -c "
        if [ ! -d '/hadoop/dfs/name/current' ]; then
            echo 'Reformatting NameNode required...'
            hdfs namenode -format -force -nonInteractive
        else
            echo 'NameNode already formatted'
        fi
    " || echo "NameNode formatting error"

    # Fix 2: Restart NameNode
    echo -e "\n${YELLOW}🔧 Fix 2: Restart NameNode${NC}"
    docker restart namenode

    echo -e "${BLUE}Waiting for NameNode restart (30s)...${NC}"
    sleep 30

    # Fix 3: Restart DataNodes
    echo -e "\n${YELLOW}🔧 Fix 3: Restart DataNodes${NC}"
    docker restart datanode1 datanode2

    echo -e "${BLUE}Waiting for DataNodes restart (45s)...${NC}"
    sleep 45

    # Fix 4: Final test
    echo -e "\n${YELLOW}🧪 Test after fixes${NC}"
    local attempts=0
    local max_attempts=10
    
    while [ $attempts -lt $max_attempts ]; do
        attempts=$((attempts + 1))
        echo -e "${BLUE}Attempt $attempts/$max_attempts...${NC}"
        
        if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HDFS is now working!${NC}"
            return 0
        fi
        
        sleep 10
    done

    echo -e "${RED}❌ HDFS is still not working after fixes${NC}"
    return 1
}

# Full rebuild function
rebuild_cluster() {
    echo -e "\n${RED}🔨 === FULL REBUILD ===${NC}"

    # Complete stop
    echo -e "${YELLOW}⏹️ Stopping the entire cluster...${NC}"
    docker-compose down --remove-orphans -v

    # Clean up volumes
    echo -e "${YELLOW}🗑️ Removing corrupted volumes...${NC}"
    docker volume rm $(docker volume ls -q | grep hadoop) 2>/dev/null || true

    # Rebuild with fixed configuration
    echo -e "${YELLOW}🏗️ Rebuilding with fixed configuration...${NC}"

    # Fix configuration files if necessary
    echo -e "${BLUE}Checking HDFS configuration...${NC}"

    # Fix hdfs-site.xml for NameNode
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

    echo -e "${GREEN}✅ NameNode configuration fixed${NC}"

    # Rebuild and orderly restart
    echo -e "${YELLOW}📦 Rebuilding images...${NC}"
    docker-compose build --no-cache namenode datanode1 datanode2

    echo -e "${YELLOW}🖥️ Starting NameNode alone...${NC}"
    docker-compose up -d namenode

    # Longer wait for NameNode
    echo -e "${BLUE}Waiting for NameNode (60s)...${NC}"
    sleep 60
    
    # Test NameNode
    if curl -f -s http://localhost:9870 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ NameNode Web UI accessible${NC}"
    else
        echo -e "${RED}❌ NameNode Web UI inaccessible${NC}"
        return 1
    fi
    
    # HDFS NameNode Test Only
    if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS accessible on NameNode only${NC}"
    else
        echo -e "${RED}❌ HDFS not accessible even on NameNode only${NC}"
        return 1
    fi

    # Starting DataNodes
    echo -e "${YELLOW}📊 Starting DataNodes...${NC}"
    docker-compose up -d datanode1 datanode2

    # Waiting for DataNodes
    echo -e "${BLUE}Waiting for DataNodes (60s)...${NC}"
    sleep 60

    # Final test
    if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
        echo -e "${GREEN}✅ HDFS is working with DataNodes!${NC}"

        # Starting the rest
        echo -e "${YELLOW}🌐 Starting complementary services...${NC}"
        docker-compose up -d
        
        return 0
    else
        echo -e "${RED}❌ HDFS is still not working${NC}"
        return 1
    fi
}

# Main menu
echo -e "${YELLOW}What would you like to do?${NC}"
echo -e "1. ${BLUE}Diagnosis only${NC}"
echo -e "2. ${YELLOW}Diagnosis + fix attempts${NC}"
echo -e "3. ${RED}Full cluster rebuild${NC}"
echo -e "4. ${GREEN}Quick HDFS test${NC}"

read -p "Your choice (1-4): " choice

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
        echo -e "${BLUE}Testing rapid HDFS...${NC}"
        if docker exec namenode hdfs dfs -ls / >/dev/null 2>&1; then
            echo -e "${GREEN}✅ HDFS is working${NC}"
            docker exec namenode hdfs dfs -ls /
        else
            echo -e "${RED}❌ HDFS is not working${NC}"
        fi
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        ;;
esac

echo -e "\n${BLUE}🎯 End of diagnosis${NC}"