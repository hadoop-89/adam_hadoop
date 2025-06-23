import requests
import json
from datetime import datetime

def test_real_integration():
    print("🚀 === TEST INTÉGRATION HADOOP → IA (VERSION QUI MARCHE) ===")
    
    # 1. Lire les données depuis HDFS avec une méthode simple
    print("📁 Lecture données HDFS...")
    
    # Utiliser la commande hdfs directement
    import subprocess
    result = subprocess.run([
        "hdfs", "dfs", "-cat", "/data/text/reviews.csv"
    ], capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"❌ Erreur lecture HDFS: {result.stderr}")
        return False
    
    lines = result.stdout.strip().split('\n')
    print(f"✅ Lu {len(lines)} lignes depuis HDFS")
    
    # 2. Prendre quelques reviews pour test
    reviews = []
    for line in lines[1:4]:  # Sauter l'header, prendre 3 reviews
        parts = line.split(',')
        if len(parts) >= 2:
            review_text = parts[1].strip('"')
            reviews.append(review_text)
    
    print(f"📝 Reviews extraites: {len(reviews)}")
    
    # 3. Envoyer à l'API IA
    ia_api_url = "http://hadoop-ai-api:8001"
    
    batch_data = []
    for i, review in enumerate(reviews):
        batch_data.append({
            "data_type": "text",
            "content": review,
            "task": "sentiment",
            "metadata": {"id": f"review_{i+1}", "source": "hdfs"}
        })
    
    print("🤖 Envoi vers API IA...")
    response = requests.post(
        f"{ia_api_url}/analyze/batch",
        json=batch_data,
        timeout=60
    )
    
    if response.status_code == 200:
        result = response.json()
        print("✅ Analyse IA réussie!")
        print(f"   Total traité: {result['total_processed']}")
        
        for i, res in enumerate(result['batch_results']):
            if res['status'] == 'success':
                sentiment = res['result']['sentiment']['label']
                confidence = res['result']['sentiment']['confidence']
                print(f"   Review {i+1}: {sentiment} (confiance: {confidence})")
        
        return True
    else:
        print(f"❌ Erreur API IA: {response.status_code}")
        return False

if __name__ == "__main__":
    success = test_real_integration()
    print(f"\n🎯 Résultat: {'✅ SUCCÈS' if success else '❌ ÉCHEC'}")
