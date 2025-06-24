---
- name: "🏥 Quick Hadoop Health Check"
  hosts: localhost
  connection: local
  gather_facts: yes
  
  tasks:
    - name: "📊 Check NameNode"
      uri:
        url: "http://localhost:9870"
        method: GET
        status_code: 200
      register: namenode_check
      
    - name: "📊 Check DataNode1"
      uri:
        url: "http://localhost:9864"
        method: GET
        status_code: 200
      register: datanode1_check
      
    - name: "📊 Check Dashboard"
      uri:
        url: "http://localhost:8501"
        method: GET
        status_code: 200
      register: dashboard_check
      ignore_errors: yes
      
    - name: "🐳 Check containers"
      shell: docker ps --format "{{.Names}}: {{.Status}}" | grep -E "(namenode|datanode|dashboard)"
      register: containers
      
    - name: "📁 Quick HDFS test"
      shell: docker exec namenode hdfs dfs -ls /
      register: hdfs_test
      ignore_errors: yes
      
    - name: "✅ Health Report"
      debug:
        msg: |
          🎉 HADOOP HEALTH CHECK RESULTS
          ==============================
          
          📊 Services:
          • NameNode: {{ '✅ OK' if namenode_check.status == 200 else '❌ FAIL' }}
          • DataNode1: {{ '✅ OK' if datanode1_check.status == 200 else '❌ FAIL' }}
          • Dashboard: {{ '✅ OK' if dashboard_check.status == 200 else '❌ FAIL' }}
          
          🐳 Containers:
          {{ containers.stdout }}
          
          📁 HDFS: {{ '✅ OK' if hdfs_test.rc == 0 else '❌ FAIL' }}
          
          🔗 Access:
          • http://localhost:9870 (NameNode)
          • http://localhost:8501 (Dashboard)