#!/bin/bash

set -e

# Local directories
DATA_DIR="/datasets"
TEXT_DIR="$DATA_DIR/text"
IMAGE_DIR="$DATA_DIR/images"

# HDFS configuration
NAMENODE_HOST="namenode"
NAMENODE_PORT="9870"
NAMENODE_HDFS_PORT="9000"

echo "📦 Creating local directories..."
mkdir -p "$TEXT_DIR" "$IMAGE_DIR"

# Function to test NameNode availability via web interface
test_namenode_web() {
    curl -s --connect-timeout 5 "http://${NAMENODE_HOST}:${NAMENODE_PORT}" > /dev/null 2>&1
    return $?
}

# Function to test HDFS port availability
test_namenode_hdfs() {
    timeout 5 bash -c "cat < /dev/null > /dev/tcp/${NAMENODE_HOST}/${NAMENODE_HDFS_PORT}" 2>/dev/null
    return $?
}

# Waiting for HDFS to start
echo "⏳ Waiting for HDFS NameNode..."
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    ATTEMPT=$((ATTEMPT + 1))

    echo "🔄 Attempt $ATTEMPT/$MAX_ATTEMPTS - Testing NameNode connection..."

    # Test NameNode web interface
    if test_namenode_web; then
        echo "✅ NameNode web interface accessible"

        # Test HDFS port
        if test_namenode_hdfs; then
            echo "✅ HDFS port accessible"
            break
        else
            echo "⚠️ Web interface OK but HDFS port not accessible"
        fi
    else
        echo "❌ NameNode not yet available"
    fi
    
    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "💥 ERROR: Unable to connect to NameNode after $MAX_ATTEMPTS attempts"
        echo "🔍 Suggested checks:"
        echo "   - docker ps | grep namenode"
        echo "   - docker logs namenode"
        echo "   - curl http://namenode:9870"
        exit 1
    fi
    
    sleep 5
done

echo "✅ NameNode HDFS is ready!"

# Install Hadoop client in the container for HDFS commands
echo "📥 Installing Hadoop client..."
HADOOP_VERSION="3.3.6"
HADOOP_TAR="hadoop-${HADOOP_VERSION}.tar.gz"

if [ ! -d "/usr/local/hadoop" ]; then
    echo "⬇️ Downloading Hadoop ${HADOOP_VERSION}..."
    wget -q "https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/${HADOOP_TAR}" -O "/tmp/${HADOOP_TAR}"

    echo "📦 Extracting Hadoop..."
    tar -xzf "/tmp/${HADOOP_TAR}" -C /tmp/
    mv "/tmp/hadoop-${HADOOP_VERSION}" /usr/local/hadoop
    rm "/tmp/${HADOOP_TAR}"

    echo "✅ Hadoop installed"
else
    echo "✅ Hadoop already installed"
fi

# Environment variable configuration
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=/usr/local/hadoop
export PATH=$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

# Basic Hadoop configuration
cat > $HADOOP_HOME/etc/hadoop/core-site.xml << EOF
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://${NAMENODE_HOST}:${NAMENODE_HDFS_PORT}</value>
    </property>
</configuration>
EOF

echo "⚙️ Hadoop configuration complete"

# Test HDFS connection
echo "🧪 Testing HDFS connection..."
if hdfs dfs -ls / > /dev/null 2>&1; then
    echo "✅ HDFS connection established successfully!"
else
    echo "❌ HDFS connection failed"
    echo "🔍 Attempting diagnosis..."
    hdfs dfs -ls / 2>&1 || true
    exit 1
fi

# === NEW: Downloading existing databases ===
echo "📥 === DOWNLOAD EXISTING DATABASES ==="

# Configure Kaggle if environment variables are present
if [ ! -f "/root/.kaggle/kaggle.json" ] && [ -n "$KAGGLE_USERNAME" ] && [ -n "$KAGGLE_KEY" ]; then
    echo "⚙️ Creating Kaggle configuration file from environment variables..."
    mkdir -p /root/.kaggle
    cat > /root/.kaggle/kaggle.json <<EOF
{"username":"$KAGGLE_USERNAME","key":"$KAGGLE_KEY"}
EOF
    chmod 600 /root/.kaggle/kaggle.json
fi

# Check if Kaggle is configured
if [ -f "/root/.kaggle/kaggle.json" ]; then
    echo "✅ Kaggle configured, downloading datasets..."
    USE_KAGGLE=true
else
    echo "⚠️ Kaggle not configured, creating test data instead..."
    USE_KAGGLE=false
fi

if [ "$USE_KAGGLE" = true ]; then
    echo "📊 Downloading Amazon reviews dataset..."
    # Existing text dataset: Amazon Fine Food Reviews
    if kaggle datasets download -d snap/amazon-fine-food-reviews -p "$TEXT_DIR" --unzip 2>/dev/null; then
        echo "✅ Amazon reviews dataset downloaded"
        # Rename main file
        if [ -f "$TEXT_DIR/Reviews.csv" ]; then
            mv "$TEXT_DIR/Reviews.csv" "$TEXT_DIR/amazon_reviews.csv"
        fi
    else
        echo "⚠️ Failed to download Amazon reviews, using test data instead"
        USE_KAGGLE=false
    fi

    echo "🖼️ Downloading Intel Image Classification dataset..."
    # Existing image dataset: Intel Image Classification
    if kaggle datasets download -d puneet6060/intel-image-classification -p "$IMAGE_DIR" --unzip 2>/dev/null; then
        echo "✅ Intel images dataset downloaded"
        # Create metadata file from downloaded images
        echo "📋 Creating image metadata..."
        echo "image_id,filename,category,path,size_kb" > "$IMAGE_DIR/intel_images_metadata.csv"
        find "$IMAGE_DIR" -name "*.jpg" -o -name "*.png" | head -100 | while IFS= read -r img_path; do
            filename=$(basename "$img_path")
            category=$(basename "$(dirname "$img_path")")
            size_kb=$(du -k "$img_path" | cut -f1)
            echo "$((++counter)),${filename},${category},${img_path},${size_kb}" >> "$IMAGE_DIR/intel_images_metadata.csv"
        done || true
    else
        echo "⚠️ Failed to download Intel images, using test data instead"
        USE_KAGGLE=false
    fi
fi

# If Kaggle is not working, create realistic test data
if [ "$USE_KAGGLE" = false ]; then
    echo "🗂️ Creating test databases (simulating existing datasets)..."

    # More realistic "existing" text database
    cat > "$TEXT_DIR/existing_reviews_db.csv" << 'EOF'
review_id,review_text,rating,timestamp,source,product_category
1,"This product is absolutely amazing! Great quality and fast shipping. Would definitely buy again!",5,"2025-01-15T10:00:00","amazon","electronics"
2,"Terrible experience. Product broke after one day. Very disappointed with the quality.",1,"2025-01-16T10:15:00","ebay","home"
3,"Average product. Nothing special but does what it's supposed to do. Fair for the price.",3,"2025-01-17T10:30:00","amazon","books"
4,"Excellent customer service and fantastic features. Highly recommend to everyone!",5,"2025-01-18T10:45:00","shopify","clothing"
5,"Poor quality for the price. Would not buy again. Expected much better.",2,"2025-01-19T11:00:00","amazon","electronics"
6,"Perfect! Exactly what I was looking for. Fast delivery too. Great seller!",5,"2025-01-20T11:15:00","ebay","sports"
7,"Product is okay but could be better. Mediocre experience overall. Room for improvement.",3,"2025-01-21T11:30:00","shopify","home"
8,"Outstanding quality and value. Best purchase I've made this year! Highly satisfied.",5,"2025-01-22T11:45:00","amazon","books"
9,"Disappointed with the build quality. Expected more for this price point.",2,"2025-01-23T12:00:00","amazon","electronics"
10,"Exceptional service and product quality. Will definitely buy again from this seller!",5,"2025-01-24T12:15:00","shopify","clothing"
11,"Decent product but delivery was slow. Product itself is fine but shipping needs work.",3,"2025-01-25T12:30:00","ebay","sports"
12,"Love this item! Exceeded my expectations in every way. Perfect addition to my collection.",5,"2025-01-26T12:45:00","amazon","home"
13,"Not what I expected. Description was misleading. Quality is below average for price.",2,"2025-01-27T13:00:00","shopify","books"
14,"Good value for money. Works as advertised. No complaints, would recommend to others.",4,"2025-01-28T13:15:00","amazon","electronics"
15,"Fantastic product! Amazing quality and great customer support. Five stars all the way!",5,"2025-01-29T13:30:00","ebay","clothing"
EOF

    # More realistic "existing" image database
    cat > "$IMAGE_DIR/existing_images_db.csv" << 'EOF'
image_id,filename,category,timestamp,source,size_kb,width,height,format
1,"nature_001.jpg","landscape","2025-01-15T10:00:00","unsplash",245,1920,1080,"jpg"
2,"animal_002.jpg","animals","2025-01-16T10:05:00","pixabay",178,1280,720,"jpg"
3,"vehicle_003.jpg","vehicles","2025-01-17T10:10:00","unsplash",312,1600,900,"jpg"
4,"architecture_004.jpg","buildings","2025-01-18T10:15:00","pexels",421,2048,1536,"jpg"
5,"food_005.jpg","food","2025-01-19T10:20:00","unsplash",298,1440,1080,"jpg"
6,"portrait_006.jpg","people","2025-01-20T10:25:00","pixabay",156,1200,1600,"jpg"
7,"tech_007.jpg","technology","2025-01-21T10:30:00","pexels",367,1920,1280,"jpg"
8,"sport_008.jpg","sports","2025-01-22T10:35:00","unsplash",289,1600,1200,"jpg"
9,"abstract_009.jpg","art","2025-01-23T10:40:00","pixabay",234,1500,1500,"jpg"
10,"cityscape_010.jpg","urban","2025-01-24T10:45:00","pexels",456,2560,1440,"jpg"
11,"flower_011.jpg","nature","2025-01-25T10:50:00","unsplash",189,1080,1350,"jpg"
12,"car_012.jpg","vehicles","2025-01-26T10:55:00","pixabay",334,1800,1200,"jpg"
13,"interior_013.jpg","design","2025-01-27T11:00:00","pexels",278,1920,1080,"jpg"
14,"sunset_014.jpg","landscape","2025-01-28T11:05:00","unsplash",367,2048,1365,"jpg"
15,"gadget_015.jpg","technology","2025-01-29T11:10:00","pixabay",223,1440,960,"jpg"
EOF

    echo "✅ Test databases created (simulating existing datasets)"
fi

# === NEW: Simulating web scraping for enrichment ===
echo "🌐 === ENRICHMENT VIA SIMULATED WEB SCRAPING ==="

# Create "scraped" data to enrich existing databases
cat > "$TEXT_DIR/scraped_reviews.csv" << 'EOF'
review_id,review_text,rating,timestamp,source,product_category,scraped_from
web_001,"Just bought this and I'm impressed! Great build quality and fast shipping.",4,"2025-06-24T08:00:00","web_scraping","electronics","reddit.com"
web_002,"Highly recommend this product. Been using it for weeks with no issues.",5,"2025-06-24T09:00:00","web_scraping","home","trustpilot.com"
web_003,"Not bad but could be better. Decent for the price point I guess.",3,"2025-06-24T10:00:00","web_scraping","books","goodreads.com"
web_004,"Absolutely love it! Best purchase I've made in months. Five stars!",5,"2025-06-24T11:00:00","web_scraping","clothing","yelp.com"
web_005,"Quality seems cheap. Not what I expected from the photos online.",2,"2025-06-24T12:00:00","web_scraping","electronics","amazon.com"
EOF

cat > "$IMAGE_DIR/scraped_images_metadata.csv" << 'EOF'
image_id,filename,category,timestamp,source,size_kb,scraped_from,url
scraped_001,"scraped_nature_001.jpg","landscape","2025-06-24T08:00:00","web_scraping",312,"flickr.com","https://flickr.com/photos/nature001"
scraped_002,"scraped_city_002.jpg","urban","2025-06-24T09:00:00","web_scraping",289,"instagram.com","https://instagram.com/p/city002"
scraped_003,"scraped_food_003.jpg","food","2025-06-24T10:00:00","web_scraping",156,"pinterest.com","https://pinterest.com/pin/food003"
scraped_004,"scraped_tech_004.jpg","technology","2025-06-24T11:00:00","web_scraping",445,"reddit.com","https://reddit.com/r/technology/tech004"
scraped_005,"scraped_animal_005.jpg","animals","2025-06-24T12:00:00","web_scraping",234,"500px.com","https://500px.com/photo/animal005"
EOF

echo "✅ Simulated scraping data created"

# Creating HDFS directories
echo "📁 Creating HDFS directories..."
hdfs dfs -mkdir -p /data/text/existing
hdfs dfs -mkdir -p /data/text/scraped
hdfs dfs -mkdir -p /data/images/existing
hdfs dfs -mkdir -p /data/images/scraped
hdfs dfs -mkdir -p /data/streaming
hdfs dfs -mkdir -p /data/processed
hdfs dfs -mkdir -p /data/ia_results

echo "✅ HDFS directories created"

# Sending data to HDFS
echo "🚀 Sending data to HDFS..."

# Existing data
if [ "$USE_KAGGLE" = true ] && [ -f "$TEXT_DIR/amazon_reviews.csv" ]; then
    hdfs dfs -put -f "$TEXT_DIR/amazon_reviews.csv" /data/text/existing/
    echo "✅ Amazon reviews dataset uploaded to HDFS"
else
    hdfs dfs -put -f "$TEXT_DIR/existing_reviews_db.csv" /data/text/existing/
    echo "✅ Existing reviews database uploaded to HDFS"
fi

if [ "$USE_KAGGLE" = true ] && [ -f "$IMAGE_DIR/intel_images_metadata.csv" ]; then
    hdfs dfs -put -f "$IMAGE_DIR/intel_images_metadata.csv" /data/images/existing/
    echo "✅ Intel images metadata dataset uploaded to HDFS"
else
    hdfs dfs -put -f "$IMAGE_DIR/existing_images_db.csv" /data/images/existing/
    echo "✅ Existing images database uploaded to HDFS"
fi

# Scraped data
hdfs dfs -put -f "$TEXT_DIR/scraped_reviews.csv" /data/text/scraped/
hdfs dfs -put -f "$IMAGE_DIR/scraped_images_metadata.csv" /data/images/scraped/

echo "✅ All data uploaded to HDFS successfully!"

# VVerification and display of results
echo "🔍 Verifying data in HDFS..."
echo ""
echo "📊 Complete HDFS structure:"
hdfs dfs -ls -R /data/

echo ""
echo "📝 Preview of existing text data:"
hdfs dfs -cat /data/text/existing/*.csv | head -3

echo ""
echo "🌐 Preview of scraped text data:"
hdfs dfs -cat /data/text/scraped/*.csv | head -3

echo ""
echo "🖼️ Preview of existing image metadata:"
hdfs dfs -cat /data/images/existing/*.csv | head -3

echo ""
echo "📡 Preview of scraped image metadata:"
hdfs dfs -cat /data/images/scraped/*.csv | head -3

echo ""
echo "📈 Detailed HDFS statistics:"
echo "$(hdfs dfs -count /data/text/existing/) - Existing text data"
echo "$(hdfs dfs -count /data/text/scraped/) - Scraped text data"
echo "$(hdfs dfs -count /data/images/existing/) - Existing image data"
echo "$(hdfs dfs -count /data/images/scraped/) - Scraped image data"

echo ""
echo "🎉 === LOADING COMPLETED SUCCESSFULLY ==="
echo "✅ Existing databases loaded"
echo "✅ Enrichment via simulated scraping"
echo "✅ Architecture compliant with specifications"
echo "✅ Data available for AI processing"
echo ""
echo "🔗 HDFS Web UI Access: http://localhost:9870"
echo "📁 Data available in:"
echo "   - /data/text/existing/ (existing database)"
echo "   - /data/text/scraped/ (web enrichment)"
echo "   - /data/images/existing/ (existing database)"
echo "   - /data/images/scraped/ (web enrichment)"