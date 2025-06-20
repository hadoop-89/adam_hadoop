import re
import base64
from PIL import Image
import io

def clean_text(text):
    """Nettoyage basique du texte"""
    if not text:
        return ""
    
    # Enlever les URLs
    text = re.sub(r'http\S+', '', text)
    
    # Enlever les caractères spéciaux
    text = re.sub(r'[^a-zA-Z0-9\s]', '', text)
    
    # Enlever les espaces multiples
    text = ' '.join(text.split())
    
    return text.lower().strip()

def tokenize_simple(text):
    """Tokenisation simple (split par espaces)"""
    return text.split()

def convert_image_to_bytes(image_path):
    """Convertir image en base64 pour envoi API"""
    try:
        with Image.open(image_path) as img:
            # Redimensionner si trop grande
            if img.width > 800 or img.height > 800:
                img.thumbnail((800, 800))
            
            # Convertir en bytes
            buffer = io.BytesIO()
            img.save(buffer, format='JPEG')
            img_bytes = buffer.getvalue()
            
            # Encoder en base64
            return base64.b64encode(img_bytes).decode('utf-8')
    except Exception as e:
        print(f"Erreur conversion image: {e}")
        return None

# Fonction pour prétraiter un batch de données
def preprocess_batch(data_batch):
    """Prétraiter un batch de données pour l'API IA"""
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