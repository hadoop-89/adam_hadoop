#!/bin/bash

echo "🚀 Installation d'Hadoop et SSH en cours..."

# 🔹 Mettre à jour les paquets et installer les dépendances nécessaires
apt update && apt install -y \
    openjdk-8-jdk \
    openssh-server \
    sshpass \
    net-tools \
    nano \
    wget \
    curl \
    sudo

# 🔹 Définir les variables d’environnement globales JAVA et Hadoop
cat <<EOF > /etc/profile.d/hadoop.sh
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/usr/local/hadoop
export PATH=\$JAVA_HOME/bin:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin:\$PATH
export HDFS_NAMENODE_URI=hdfs://namenode:9000
EOF

source /etc/profile.d/hadoop.sh

# 🔹 Télécharger et installer Hadoop
HADOOP_VERSION="3.3.6"
wget https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
tar -xvzf hadoop-${HADOOP_VERSION}.tar.gz
mv hadoop-${HADOOP_VERSION} /usr/local/hadoop
rm hadoop-${HADOOP_VERSION}.tar.gz

# 🔹 Créer les dossiers pour HDFS
mkdir -p $HADOOP_HOME/data/namenode
mkdir -p $HADOOP_HOME/data/datanode

# 🔹 Configurer SSH pour accès sans mot de passe
mkdir -p /run/sshd
mkdir -p ~/.ssh
ssh-keygen -t rsa -P '' -f ~/.ssh/id_rsa

# 🔹 Copier les clés SSH vers datanodes (méthode sûre)
PUBKEY=$(cat ~/.ssh/id_rsa.pub)
for node in datanode1 datanode2; do
    sshpass -p "hadoop" ssh -o StrictHostKeyChecking=no hadoop@$node "
        mkdir -p ~/.ssh &&
        chmod 700 ~/.ssh &&
        echo '$PUBKEY' >> ~/.ssh/authorized_keys &&
        chmod 600 ~/.ssh/authorized_keys"
done

# 🔹 Formatage et démarrage HDFS uniquement sur le Namenode
if [ "$(hostname)" == "namenode" ]; then
    echo "🟢 Formatage du Namenode..."
    hdfs namenode -format -force
    echo "🟢 Démarrage du cluster HDFS..."
    start-dfs.sh
fi

echo "✅ Installation et configuration terminées ! 🚀"
