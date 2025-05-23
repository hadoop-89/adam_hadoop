"""
Image processing module for preparing images for the AI API.
"""
import os
import io
import sys
import logging
import numpy as np
from PIL import Image
import requests
from hdfs import InsecureClient
from kafka import KafkaProducer
import json

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("image_processor.log"),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger("image_processor")

# Configuration
HDFS_URL = os.environ.get('HDFS_URL', 'http://namenode:9870')
KAFKA_BOOTSTRAP_SERVERS = os.environ.get('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092')
KAFKA_TOPIC_IMAGES = os.environ.get('KAFKA_TOPIC_IMAGES', 'processed-images')
IMAGE_SIZE = (224, 224)  # Standard size for many AI models

class ImageProcessor:
    def __init__(self):
        """Initialize the image processor."""
        self.hdfs_client = InsecureClient(HDFS_URL, user='hdfs')
        self.producer = self._create_kafka_producer()
        
    def _create_kafka_producer(self):
        """Create a Kafka producer instance."""
        try:
            producer = KafkaProducer(
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8')
            )
            return producer
        except Exception as e:
            logger.error(f"Failed to create Kafka producer: {str(e)}")
            raise

    def download_image(self, image_url):
        """Download an image from a URL."""
        try:
            response = requests.get(image_url, timeout=10)
            response.raise_for_status()
            return Image.open(io.BytesIO(response.content))
        except Exception as e:
            logger.error(f"Error downloading image from {image_url}: {str(e)}")
            return None

    def preprocess_image(self, image):
        """Preprocess the image for AI processing."""
        try:
            if not image:
                return None
            
            # Convert to RGB if needed
            if image.mode != 'RGB':
                image = image.convert('RGB')
            
            # Resize image to standard size
            image = image.resize(IMAGE_SIZE, Image.LANCZOS)
            
            # Convert to numpy array
            img_array = np.array(image)
            
            # Normalize pixel values to range [0, 1]
            img_array = img_array.astype('float32') / 255.0
            
            # Convert numpy array to list for JSON serialization
            img_bytes = img_array.tolist()
            
            return img_bytes
        except Exception as e:
            logger.error(f"Error preprocessing image: {str(e)}")
            return None

    def process_and_send(self, image_url, image_id):
        """Process an image and send to Kafka."""
        try:
            # Download and preprocess the image
            image = self.download_image(image_url)
            if not image:
                return False
            
            processed_image = self.preprocess_image(image)
            if not processed_image:
                return False
            
            # Create message
            message = {
                'image_id': image_id,
                'image_url': image_url,
                'processed_image': processed_image,
                'height': IMAGE_SIZE[0],
                'width': IMAGE_SIZE[1],
                'channels': 3
            }
            
            # Send to Kafka
            self.producer.send(
                KAFKA_TOPIC_IMAGES,
                key=image_id.encode('utf-8'),
                value=message
            )
            logger.info(f"Processed and sent image {image_id} to Kafka")
            return True
        except Exception as e:
            logger.error(f"Error processing image {image_id}: {str(e)}")
            return False

    def process_image_urls_from_hdfs(self, hdfs_path):
        """Process image URLs stored in HDFS."""
        try:
            logger.info(f"Processing image URLs from {hdfs_path}")
            
            # Check if the path exists
            if not self.hdfs_client.status(hdfs_path, strict=False):
                logger.warning(f"Path {hdfs_path} does not exist in HDFS")
                return 0
            
            # Get list of files in the directory
            files = self.hdfs_client.list(hdfs_path)
            
            processed_count = 0
            for file in files:
                file_path = os.path.join(hdfs_path, file)
                
                # Read the parquet file
                with self.hdfs_client.read(file_path) as reader:
                    # Parse the parquet content
                    # Note: In a real implementation, you'd use a proper parquet library
                    # This is a placeholder
                    content = reader.read()
                    # Process each image URL
                    # Placeholder for actual parquet processing
                    
                processed_count += 1
            
            logger.info(f"Processed {processed_count} image URL files")
            return processed_count
        except Exception as e:
            logger.error(f"Error processing image URLs from HDFS: {str(e)}")
            return 0

    def close(self):
        """Close the Kafka producer."""
        if self.producer:
            self.producer.close()
            logger.info("Kafka producer closed")

if __name__ == "__main__":
    processor = ImageProcessor()
    
    try:
        # Process image URLs from HDFS
        processor.process_image_urls_from_hdfs('/data/image_urls')
        
        # Example of direct processing
        processor.process_and_send('https://example.com/image.jpg', 'test_image_1')
    finally:
        processor.close()
