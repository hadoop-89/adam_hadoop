#!/bin/bash
set -e

# Démarrer le serveur SSH
echo "Starting SSH server..."
/usr/sbin/sshd

# Format HDFS si ce n'est pas déjà fait
if [ ! -d "/hadoop/dfs/name/current" ]; then
    echo "Formatting NameNode..."
    hdfs namenode -format -force
fi

# Lancer le NameNode
echo "Starting NameNode..."
exec hdfs namenode