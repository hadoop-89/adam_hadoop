#!/bin/bash
set -e

# Démarrer le serveur SSH
echo "Starting SSH server..."
/usr/sbin/sshd

# Lancer le DataNode
echo "Starting DataNode..."
exec hdfs datanode