#!/bin/bash
set -e

# Start the SSH server
echo "Starting SSH server..."
/usr/sbin/sshd

# Format HDFS if not already done
if [ ! -d "/hadoop/dfs/name/current" ]; then
    echo "Formatting NameNode..."
    hdfs namenode -format -force
fi

# Start the NameNode
echo "Starting NameNode..."
exec hdfs namenode