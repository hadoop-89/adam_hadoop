#!/bin/bash
set -e

host="hbase"
port="9090"

echo "Waiting for HBase at $host:$port"
echo "Current environment:"
env | grep HBASE

until nc -z -v $host $port; do
  >&2 echo "HBase is unavailable at $host:$port - sleeping"
  sleep 2
done

>&2 echo "HBase is up - executing command"
# Initialize HBase tables
echo "Running init_hbase.py script..."
python init_hbase.py
