#!/bin/bash

set -e

# Répertoires locaux
DATA_DIR="/datasets"
TEXT_DIR="$DATA_DIR/text"
IMAGE_DIR="$DATA_DIR/images"

# Configuration HDFS
NAMENODE_HOST="namenode"
NAMENODE_PORT="9870"
NAMENODE_HDFS_PORT="9000"

echo "📦 Création des dossiers locaux..."
mkdir -p "$TEXT_DIR" "$IMAGE_DIR"

# Fonction pour tester la disponibilité du NameNode via l'interface web
test_namenode_web() {
    curl -s --connect-timeout 5 "http://${NAMENODE_HOST}:${NAMENODE_PORT}" > /dev/null 2>&1
    return $?
}

# Fonction pour tester la disponibilité du port HDFS
test_namenode_hdfs() {
    timeout 5 bash -c "cat < /dev/null > /dev/tcp/${NAMENODE_HOST}/${NAMENODE_HDFS_PORT}" 2>/dev/null
    return $?
}

# Attente du démarrage de HDFS
echo "⏳ Attente du NameNode HDFS..."
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))
    
    echo "🔄 Tentative $ATTEMPT/$MAX_ATTEMPTS - Test de connexion au NameNode..."
    
    # Test de l'interface web du NameNode
    if test_namenode_web; then
        echo "✅ Interface web du NameNode accessible"
        
        # Test du port HDFS
        if test_namenode_hdfs; then
            echo "✅ Port HDFS accessible"
            break
        else
            echo "⚠️ Interface web OK mais port HDFS non accessible"
        fi
    else
        echo "❌ NameNode non encore disponible"
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "💥 ERREUR: Impossible de se connecter au NameNode après $MAX_ATTEMPTS tentatives"
        echo "🔍 Vérifications suggérées:"
        echo "   - docker ps | grep namenode"
        echo "   - docker logs namenode"
        echo "   - curl http://namenode:9870"
        exit 1
    fi
    
    sleep 5
done

echo "✅ NameNode HDFS est prêt !"

# Installation d'Hadoop client dans le conteneur pour les commandes HDFS
echo "📥 Installation du client Hadoop..."
HADOOP_VERSION="3.3.6"
HADOOP_TAR="hadoop-${HADOOP_VERSION}.tar.gz"

if [ ! -d "/usr/local/hadoop" ]; then
    echo "⬇️ Téléchargement d'Hadoop ${HADOOP_VERSION}..."
    wget -q "https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TAR}" -O "/tmp/${HADOOP_TAR}"
    
    echo "📦 Extraction d'Hadoop..."
    tar -xzf "/tmp/${HADOOP_TAR}" -C /tmp/
    mv "/tmp/hadoop-${HADOOP_VERSION}" /usr/local/hadoop
    rm "/tmp/${HADOOP_TAR}"
    
    echo "✅ Hadoop installé"
else
    echo "✅ Hadoop déjà installé"
fi

# Configuration des variables d'environnement
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/usr/local/hadoop
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

# Configuration de base pour Hadoop
cat > $HADOOP_HOME/etc/hadoop/core-site.xml << EOF
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${NAMENODE_HOST}:${NAMENODE_HDFS_PORT}</value>
    </property>
</configuration>
EOF

echo "⚙️ Configuration Hadoop terminée"

# Test de connexion HDFS
echo "🧪 Test de connexion HDFS..."
if hdfs dfs -ls / > /dev/null 2>&1; then
    echo "✅ Connexion HDFS établie avec succès !"
else
    echo "❌ Échec de la connexion HDFS"
    echo "🔍 Tentative de diagnostic..."
    hdfs dfs -ls / 2>&1 || true
    exit 1
fi

# Création de données de test
echo "🗂️ Création de données de test..."
cat > "$TEXT_DIR/reviews.csv" << 'EOF'
review_id,review_text,rating,timestamp,source
1,"This product is absolutely amazing! Great quality and fast shipping.",5,"2025-06-22T10:00:00","amazon"
2,"Terrible experience. Product broke after one day. Very disappointed.",1,"2025-06-22T10:15:00","ebay"
3,"Average product. Nothing special but does what it's supposed to do.",3,"2025-06-22T10:30:00","amazon"
4,"Excellent customer service and fantastic features. Highly recommend!",5,"2025-06-22T10:45:00","shopify"
5,"Poor quality for the price. Would not buy again.",2,"2025-06-22T11:00:00","amazon"
6,"Perfect! Exactly what I was looking for. Fast delivery too.",5,"2025-06-22T11:15:00","ebay"
7,"Product is okay but could be better. Mediocre experience overall.",3,"2025-06-22T11:30:00","shopify"
8,"Outstanding quality and value. Best purchase I've made this year!",5,"2025-06-22T11:45:00","amazon"
9,"Disappointed with the build quality. Expected more for this price.",2,"2025-06-22T12:00:00","amazon"
10,"Exceptional service and product quality. Will definitely buy again!",5,"2025-06-22T12:15:00","shopify"
EOF

# Création d'un dataset d'images simulé (métadonnées)
cat > "$IMAGE_DIR/image_metadata.csv" << 'EOF'
image_id,filename,category,timestamp,source,size_kb
1,"cat_001.jpg","animals","2025-06-22T10:00:00","unsplash",245
2,"dog_002.jpg","animals","2025-06-22T10:05:00","pixabay",178
3,"car_003.jpg","vehicles","2025-06-22T10:10:00","unsplash",312
4,"house_004.jpg","architecture","2025-06-22T10:15:00","pexels",421
5,"food_005.jpg","food","2025-06-22T10:20:00","unsplash",298
6,"nature_006.jpg","landscape","2025-06-22T10:25:00","pixabay",156
7,"person_007.jpg","people","2025-06-22T10:30:00","pexels",367
8,"tech_008.jpg","technology","2025-06-22T10:35:00","unsplash",289
EOF

echo "✅ Données de test créées"

# Création des répertoires HDFS
echo "📁 Création des répertoires HDFS..."
hdfs dfs -mkdir -p /data/text
hdfs dfs -mkdir -p /data/images
hdfs dfs -mkdir -p /data/streaming
hdfs dfs -mkdir -p /data/processed
hdfs dfs -mkdir -p /data/ia_results

echo "✅ Répertoires HDFS créés"

# Envoi des données vers HDFS
echo "🚀 Envoi des données vers HDFS..."
hdfs dfs -put -f "$TEXT_DIR/reviews.csv" /data/text/
hdfs dfs -put -f "$IMAGE_DIR/image_metadata.csv" /data/images/

echo "✅ Données chargées dans HDFS avec succès !"

# Vérification et affichage des résultats
echo "🔍 Vérification des données dans HDFS..."
echo ""
echo "📊 Structure HDFS:"
hdfs dfs -ls /data/

echo ""
echo "📝 Contenu du fichier texte:"
hdfs dfs -cat /data/text/reviews.csv | head -5

echo ""
echo "🖼️ Métadonnées images:"
hdfs dfs -cat /data/images/image_metadata.csv | head -5

echo ""
echo "📈 Statistiques HDFS:"
echo "$(hdfs dfs -count /data/text/) - Répertoire texte"
echo "$(hdfs dfs -count /data/images/) - Répertoire images"

echo ""
echo "🎉 === CHARGEMENT TERMINÉ AVEC SUCCÈS ==="
echo "✅ Hadoop client installé et configuré"
echo "✅ Connexion HDFS établie"
echo "✅ Répertoires HDFS créés"
echo "✅ Données de test chargées"
echo "✅ $(hdfs dfs -cat /data/text/reviews.csv | wc -l) lignes de reviews chargées"
echo "✅ $(hdfs dfs -cat /data/images/image_metadata.csv | wc -l) métadonnées d'images chargées"
echo ""
echo "🔗 Accès HDFS Web UI: http://localhost:9870"
echo "📁 Données disponibles dans: /data/text/ et /data/images/"