"""
API client for interacting with the AI API.
"""
import os
import json
import logging
import requests
import time
from kafka import KafkaConsumer, KafkaProducer

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[logging.FileHandler("api_client.log")]
)
logger = logging.getLogger("api_client")

# Configuration
API_BASE_URL = os.environ.get('API_BASE_URL', 'http://ai-api:8000')
KAFKA_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
KAFKA_TOPIC_PROCESSED_TEXT = os.environ.get('KAFKA_TOPIC_PROCESSED_TEXT', 'processed-data')
KAFKA_TOPIC_PROCESSED_IMAGES = os.environ.get('KAFKA_TOPIC_PROCESSED_IMAGES', 'processed-images')
KAFKA_TOPIC_AI_RESULTS = os.environ.get('KAFKA_TOPIC_AI_RESULTS', 'ai-results')

class AIApiClient:
    def __init__(self):
        """Initialize the AI API client."""
        self.text_consumer = self._create_consumer(KAFKA_TOPIC_PROCESSED_TEXT)
        self.image_consumer = self._create_consumer(KAFKA_TOPIC_PROCESSED_IMAGES)
        self.producer = self._create_producer()
        
    def _create_consumer(self, topic):
        """Create a Kafka consumer for a specific topic."""
        try:
            consumer = KafkaConsumer(
                topic,
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_deserializer=lambda m: json.loads(m.decode('utf-8')),
                auto_offset_reset='latest',
                enable_auto_commit=True,
                group_id=f'ai-api-client-{topic}'
            )
            return consumer
        except Exception as e:
            logger.error(f"Failed to create Kafka consumer for topic {topic}: {str(e)}")
            raise
            
    def _create_producer(self):
        """Create a Kafka producer."""
        try:
            producer = KafkaProducer(
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            return producer
        except Exception as e:
            logger.error(f"Failed to create Kafka producer: {str(e)}")
            raise
    
    def process_text(self, text_data):
        """Process text data through the AI API."""
        try:
            # Extract the necessary information from Kafka message
            text = text_data.get('content', '')
            doc_id = text_data.get('id', '')
            
            if not text or not doc_id:
                logger.warning("Missing required text data")
                return None
                
            # Prepare the request
            endpoint = f"{API_BASE_URL}/api/text"
            payload = {
                "text": text,
                "analysis_types": ["classification", "summary", "sentiment"]
            }
            
            # Send the request to the API
            response = requests.post(endpoint, json=payload)
            response.raise_for_status()
            
            # Process the response
            result = response.json()
            result['doc_id'] = doc_id
            result['timestamp'] = time.time()
            
            logger.info(f"Successfully processed text document {doc_id}")
            return result
        except requests.exceptions.RequestException as e:
            logger.error(f"API request error for text: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Error processing text data: {str(e)}")
            return None
    
    def process_image(self, image_data):
        """Process image data through the AI API."""
        try:
            # Extract the necessary information from Kafka message
            processed_image = image_data.get('processed_image', [])
            image_id = image_data.get('image_id', '')
            image_url = image_data.get('image_url', '')
            
            if not processed_image or not image_id:
                logger.warning("Missing required image data")
                return None
                
            # Prepare the request
            endpoint = f"{API_BASE_URL}/api/image"
            payload = {
                "image_data": processed_image,
                "height": image_data.get('height', 224),
                "width": image_data.get('width', 224),
                "channels": image_data.get('channels', 3),
                "detection_type": "object"
            }
            
            # Send the request to the API
            response = requests.post(endpoint, json=payload)
            response.raise_for_status()
            
            # Process the response
            result = response.json()
            result['image_id'] = image_id
            result['image_url'] = image_url
            result['timestamp'] = time.time()
            
            logger.info(f"Successfully processed image {image_id}")
            return result
        except requests.exceptions.RequestException as e:
            logger.error(f"API request error for image: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Error processing image data: {str(e)}")
            return None
    
    def send_result_to_kafka(self, result, data_type):
        """Send the API response to the results Kafka topic."""
        if not result:
            return False
            
        try:
            # Add metadata to the result
            result['data_type'] = data_type
            
            # Send to Kafka
            key = result.get('doc_id', result.get('image_id', 'unknown')).encode('utf-8')
            self.producer.send(KAFKA_TOPIC_AI_RESULTS, key=key, value=result)
            
            logger.info(f"Sent {data_type} result to Kafka")
            return True
        except Exception as e:
            logger.error(f"Error sending result to Kafka: {str(e)}")
            return False
            
    def run(self):
        """Main loop to process messages from Kafka."""
        logger.info("Starting AI API client")
        
        try:
            # Process text messages
            for message in self.text_consumer:
                try:
                    text_data = message.value
                    logger.info(f"Received text message: {text_data.get('id', 'unknown')}")
                    
                    result = self.process_text(text_data)
                    if result:
                        self.send_result_to_kafka(result, 'text')
                except Exception as e:
                    logger.error(f"Error processing text message: {str(e)}")
                    
            # Process image messages (this won't be reached in this implementation)
            for message in self.image_consumer:
                try:
                    image_data = message.value
                    logger.info(f"Received image message: {image_data.get('image_id', 'unknown')}")
                    
                    result = self.process_image(image_data)
                    if result:
                        self.send_result_to_kafka(result, 'image')
                except Exception as e:
                    logger.error(f"Error processing image message: {str(e)}")
                    
        except KeyboardInterrupt:
            logger.info("API client interrupted")
        finally:
            self.close()
            
    def close(self):
        """Close all Kafka connections."""
        try:
            if self.text_consumer:
                self.text_consumer.close()
            if self.image_consumer:
                self.image_consumer.close()
            if self.producer:
                self.producer.close()
            logger.info("Kafka connections closed")
        except Exception as e:
            logger.error(f"Error closing Kafka connections: {str(e)}")

if __name__ == "__main__":
    api_client = AIApiClient()
    api_client.run()
