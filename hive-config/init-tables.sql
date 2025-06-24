CREATE DATABASE IF NOT EXISTS analytics;
USE analytics;

DROP TABLE IF EXISTS reviews;
CREATE EXTERNAL TABLE reviews (
    review_id STRING,
    review_text STRING,
    rating INT,
    timestamp STRING,
    source STRING,
    product_category STRING
) 
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   'separatorChar' = ',',
   'quoteChar' = '"',
   'escapeChar' = '\\'
)
STORED AS TEXTFILE
LOCATION 'hdfs://namenode:9000/data/text/existing/'
TBLPROPERTIES ('skip.header.line.count'='1');

DROP TABLE IF EXISTS images;
CREATE EXTERNAL TABLE images (
    image_id STRING,
    filename STRING,
    category STRING,
    timestamp STRING,
    source STRING,
    size_kb INT,
    width INT,
    height INT,
    format STRING
) 
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES (
   'separatorChar' = ',',
   'quoteChar' = '"',
   'escapeChar' = '\\'
)
STORED AS TEXTFILE
LOCATION 'hdfs://namenode:9000/data/images/existing/'
TBLPROPERTIES ('skip.header.line.count'='1');

DROP TABLE IF EXISTS ia_results;
CREATE TABLE ia_results (
    original_id STRING,
    analysis_type STRING,
    result STRING,
    confidence DOUBLE,
    processed_at STRING
) 
STORED AS PARQUET
LOCATION 'hdfs://namenode:9000/data/ia_results/';

SELECT 'Tables Hive créées avec succès' as status;