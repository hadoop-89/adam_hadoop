import re
import base64
from PIL import Image
import io

def clean_text(text):
    """Basic text cleaning"""
    if not text:
        return ""

    # Remove URLs
    text = re.sub(r'http\S+', '', text)

    # Remove special characters
    text = re.sub(r'[^a-zA-Z0-9\s]', '', text)

    # Remove multiple spaces
    text = ' '.join(text.split())
    
    return text.lower().strip()

def tokenize_simple(text):
    """Simple tokenization (split by spaces)"""
    return text.split()

def convert_image_to_bytes(image_path):
    """Convert image to base64 for API sending"""
    try:
        with Image.open(image_path) as img:
            # Resize if too large
            if img.width > 800 or img.height > 800:
                img.thumbnail((800, 800))

            # Convert to bytes
            buffer = io.BytesIO()
            img.save(buffer, format='JPEG')
            img_bytes = buffer.getvalue()

            # Encode to base64
            return base64.b64encode(img_bytes).decode('utf-8')
    except Exception as e:
        print(f"Error converting image: {e}")
        return None

# Function to preprocess a batch of data
def preprocess_batch(data_batch):
    """Preprocess a batch of data for the AI API"""
    processed = []
    
    for item in data_batch:
        if item.get('type') == 'text':
            processed_text = clean_text(item['content'])
            tokens = tokenize_simple(processed_text)
            
            processed.append({
                'id': item['id'],
                'type': 'text',
                'content': processed_text,
                'tokens': tokens,
                'token_count': len(tokens)
            })
            
        elif item.get('type') == 'image':
            img_bytes = convert_image_to_bytes(item['path'])
            if img_bytes:
                processed.append({
                    'id': item['id'],
                    'type': 'image',
                    'content': img_bytes,
                    'format': 'base64'
                })
    
    return processed