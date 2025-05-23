"""
Module for storing AI results in a database.
"""
import os
import json
import logging
import time
from kafka import KafkaConsumer
import happybase

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler("results_storage.log")]
)
logger = logging.getLogger("results_storage")

# Configuration
KAFKA_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
KAFKA_TOPIC_AI_RESULTS = os.environ.get('KAFKA_TOPIC_AI_RESULTS', 'ai-results')
HBASE_HOST = os.environ.get('HBASE_HOST', 'hbase')
HBASE_PORT = int(os.environ.get('HBASE_PORT', 9090))

class ResultsStorage:
    def __init__(self):
        """Initialize the results storage system."""
        self.consumer = self._create_consumer()
        self.connection = None
        self._connect_to_hbase()
        self._ensure_tables_exist()
        
    def _create_consumer(self):
        """Create a Kafka consumer for the AI results topic."""
        try:
            consumer = KafkaConsumer(
                KAFKA_TOPIC_AI_RESULTS,
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                auto_offset_reset='latest',
                enable_auto_commit=True,
                group_id='ai-results-storage'
            )
            return consumer
        except Exception as e:
            logger.error(f"Failed to create Kafka consumer: {str(e)}")
            raise
            
    def _connect_to_hbase(self):
        """Connect to HBase."""
        retry_count = 0
        max_retries = 5
        
        while retry_count < max_retries:
            try:
                self.connection = happybase.Connection(HBASE_HOST, HBASE_PORT)
                logger.info("Connected to HBase")
                return
            except Exception as e:
                retry_count += 1
                logger.error(f"Failed to connect to HBase (attempt {retry_count}/{max_retries}): {str(e)}")
                if retry_count < max_retries:
                    time.sleep(5)
                else:
                    raise
    
    def _ensure_tables_exist(self):
        """Create required HBase tables if they don't exist."""
        try:
            tables = self.connection.tables()
            tables = [t.decode('utf-8') for t in tables]
            
            if 'text_results' not in tables:
                logger.info("Creating 'text_results' table")
                self.connection.create_table(
                    'text_results',
                    {
                        'metadata': dict(),  # Document metadata
                        'classification': dict(),  # Classification results
                        'summary': dict(),  # Summary results
                        'sentiment': dict()  # Sentiment results
                    }
                )
                
            if 'image_results' not in tables:
                logger.info("Creating 'image_results' table")
                self.connection.create_table(
                    'image_results',
                    {
                        'metadata': dict(),  # Image metadata
                        'detection': dict(),  # Object detection results
                    }
                )
                
            logger.info("HBase tables validated")
        except Exception as e:
            logger.error(f"Failed to validate/create HBase tables: {str(e)}")
            raise
    
    def store_text_result(self, result):
        """Store a text analysis result in HBase."""
        try:
            table = self.connection.table('text_results')
            row_key = result.get('doc_id', f"unknown-{int(time.time())}")
            
            # Prepare data for storage
            data = {
                'metadata:doc_id': str(result.get('doc_id', '')),
                'metadata:timestamp': str(result.get('timestamp', time.time())),
            }
            
            # Add classification data
            if 'classification' in result:
                for i, cls in enumerate(result['classification']):
                    data[f'classification:class_{i}_name'] = str(cls.get('class', ''))
                    data[f'classification:class_{i}_score'] = str(cls.get('score', 0))
            
            # Add summary data
            if 'summary' in result:
                data['summary:text'] = result['summary']
            
            # Add sentiment data
            if 'sentiment' in result:
                data['sentiment:score'] = str(result['sentiment'].get('score', 0))
                data['sentiment:label'] = result['sentiment'].get('label', '')
            
            # Store in HBase
            table.put(row_key, data)
            logger.info(f"Stored text result for document {row_key}")
            return True
        except Exception as e:
            logger.error(f"Failed to store text result: {str(e)}")
            return False
    
    def store_image_result(self, result):
        """Store an image analysis result in HBase."""
        try:
            table = self.connection.table('image_results')
            row_key = result.get('image_id', f"unknown-{int(time.time())}")
            
            # Prepare data for storage
            data = {
                'metadata:image_id': str(result.get('image_id', '')),
                'metadata:image_url': str(result.get('image_url', '')),
                'metadata:timestamp': str(result.get('timestamp', time.time())),
            }
            
            # Add detection data
            if 'detections' in result:
                for i, det in enumerate(result['detections']):
                    data[f'detection:object_{i}_class'] = str(det.get('class', ''))
                    data[f'detection:object_{i}_confidence'] = str(det.get('confidence', 0))
                    data[f'detection:object_{i}_box'] = json.dumps(det.get('box', {}))
            
            # Store in HBase
            table.put(row_key, data)
            logger.info(f"Stored image result for image {row_key}")
            return True
        except Exception as e:
            logger.error(f"Failed to store image result: {str(e)}")
            return False
    
    def run(self):
        """Main loop to process messages from Kafka and store them in HBase."""
        logger.info("Starting results storage service")
        
        try:
            for message in self.consumer:
                try:
                    result = message.value
                    data_type = result.get('data_type')
                    
                    if data_type == 'text':
                        self.store_text_result(result)
                    elif data_type == 'image':
                        self.store_image_result(result)
                    else:
                        logger.warning(f"Unknown data type: {data_type}")
                except Exception as e:
                    logger.error(f"Error processing result: {str(e)}")
        except KeyboardInterrupt:
            logger.info("Results storage service interrupted")
        finally:
            self.close()
    
    def close(self):
        """Close all connections."""
        try:
            if self.consumer:
                self.consumer.close()
            if self.connection:
                self.connection.close()
            logger.info("Connections closed")
        except Exception as e:
            logger.error(f"Error closing connections: {str(e)}")

if __name__ == "__main__":
    storage = ResultsStorage()
    storage.run()
