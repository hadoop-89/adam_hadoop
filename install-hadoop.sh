#!/bin/bash

echo "🚀 Hadoop and SSH installation in progress..."

# 🔹 Update packages and install necessary dependencies
apt update && apt install -y \
    openjdk-8-jdk \
    openssh-server \
    sshpass \
    net-tools \
    nano \
    wget \
    curl \
    sudo

# 🔹 Set global environment variables for JAVA and Hadoop
cat <<EOF > /etc/profile.d/hadoop.sh
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/usr/local/hadoop
export PATH=\$JAVA_HOME/bin:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$PATH
export HDFS_NAMENODE_URI=hdfs://namenode:9000
EOF

source /etc/profile.d/hadoop.sh

# 🔹 Download and install Hadoop
HADOOP_VERSION="3.3.6"
wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
tar -xvzf hadoop-${HADOOP_VERSION}.tar.gz
mv hadoop-${HADOOP_VERSION} /usr/local/hadoop
rm hadoop-${HADOOP_VERSION}.tar.gz

# 🔹 Create directories for HDFS
mkdir -p $HADOOP_HOME/data/namenode
mkdir -p $HADOOP_HOME/data/datanode

# 🔹 Configure SSH for passwordless access
mkdir -p /run/sshd
mkdir -p ~/.ssh
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

# 🔹 Copy SSH keys to datanodes (secure method)
PUBKEY=$(cat ~/.ssh/id_rsa.pub)
for node in datanode1 datanode2; do
    sshpass -p "hadoop" ssh -o StrictHostKeyChecking=no hadoop@$node "
        mkdir -p ~/.ssh &&
        chmod 700 ~/.ssh &&
        echo '$PUBKEY' >> ~/.ssh/authorized_keys &&
        chmod 600 ~/.ssh/authorized_keys"
done

# 🔹 Format and start HDFS only on the NameNode
if [ "$(hostname)" == "namenode" ]; then
    echo "🟢 Formatting NameNode..."
    hdfs namenode -format -force
    echo "🟢 Starting HDFS cluster..."
    start-dfs.sh
fi

echo "✅ Installation and configuration completed! 🚀"
