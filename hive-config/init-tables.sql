CREATE DATABASE IF NOT EXISTS analytics;
USE analytics;

-- Table des reviews depuis HDFS
CREATE TABLE IF NOT EXISTS reviews (
    review_id STRING,
    review_text STRING,
    rating INT,
    timestamp STRING,
    source STRING
) 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE
LOCATION 'hdfs://namenode:9000/data/text/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Table des métadonnées images
CREATE TABLE IF NOT EXISTS images (
    image_id STRING,
    filename STRING,
    category STRING,
    timestamp STRING,
    source STRING,
    size_kb INT
) 
ROW FORMAT DELIMITED 
FIELDS TERMINATED BY ',' 
STORED AS TEXTFILE
LOCATION 'hdfs://namenode:9000/data/images/'
TBLPROPERTIES ('skip.header.line.count'='1');

-- Table des résultats IA (pour les futures analyses)
CREATE TABLE IF NOT EXISTS ia_results (
    original_id STRING,
    analysis_type STRING,
    result STRING,
    confidence DOUBLE,
    processed_at STRING
) 
STORED AS PARQUET
LOCATION 'hdfs://namenode:9000/data/ia_results/';

-- Vue analytics combinée
CREATE VIEW IF NOT EXISTS analytics_view AS
SELECT 
    r.review_id,
    r.review_text,
    r.rating,
    r.source,
    r.timestamp,
    ia.result as sentiment,
    ia.confidence
FROM reviews r
LEFT JOIN ia_results ia ON r.review_id = ia.original_id
WHERE ia.analysis_type = 'sentiment' OR ia.analysis_type IS NULL;

-- Quelques requêtes de test
SELECT 'Tables créées avec succès' as status;
SELECT COUNT(*) as total_reviews FROM reviews;
SELECT source, COUNT(*) as count FROM reviews GROUP BY source;