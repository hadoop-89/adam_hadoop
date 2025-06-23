# spark-jobs/test_hadoop_ia_integration.py

import requests
import json
from datetime import datetime

def test_ia_api_from_spark():
    """Test simple de l'API IA depuis l'environnement Spark"""
    
    print("🚀 === TEST INTÉGRATION HADOOP ↔ IA ===")
    
    # URL de l'API IA (accessible depuis le réseau Hadoop)
    ia_api_url = "http://hadoop-ai-api:8001"
    
    try:
        # Test 1: Health check
        print("\n📋 Test 1: Health Check")
        response = requests.get(f"{ia_api_url}/health", timeout=10)
        
        if response.status_code == 200:
            print("✅ API IA accessible depuis Spark")
            print(f"   Réponse: {response.json()}")
        else:
            print(f"❌ Erreur health check: {response.status_code}")
            return False
        
        # Test 2: Analyse de sentiment
        print("\n📝 Test 2: Analyse de sentiment")
        text_data = {
            "data_type": "text",
            "content": "This Hadoop and AI integration is working amazingly well!",
            "task": "sentiment",
            "metadata": {
                "source": "spark_test",
                "timestamp": datetime.now().isoformat()
            }
        }
        
        response = requests.post(
            f"{ia_api_url}/analyze",
            json=text_data,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Analyse de sentiment réussie")
            print(f"   Sentiment: {result['result']['sentiment']['label']}")
            print(f"   Confiance: {result['result']['sentiment']['confidence']}")
        else:
            print(f"❌ Erreur analyse sentiment: {response.status_code}")
            print(f"   Détails: {response.text}")
            return False
        
        # Test 3: Analyse d'image
        print("\n🖼️ Test 3: Analyse d'image")
        image_data = {
            "data_type": "image",
            "content": "dGVzdA==",  # base64 simple
            "task": "detection",
            "metadata": {
                "source": "spark_test",
                "timestamp": datetime.now().isoformat()
            }
        }
        
        response = requests.post(
            f"{ia_api_url}/analyze",
            json=image_data,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Analyse d'image réussie")
            objects_count = result['result']['object_detection']['objects_count']
            print(f"   Objets détectés: {objects_count}")
        else:
            print(f"❌ Erreur analyse image: {response.status_code}")
            print(f"   Détails: {response.text}")
            return False
        
        # Test 4: Traitement par batch
        print("\n📦 Test 4: Traitement par batch")
        batch_data = [
            {
                "data_type": "text",
                "content": "Excellent performance!",
                "task": "sentiment",
                "metadata": {"id": "test1", "source": "hadoop"}
            },
            {
                "data_type": "text",
                "content": "This is terrible quality",
                "task": "sentiment", 
                "metadata": {"id": "test2", "source": "hadoop"}
            },
            {
                "data_type": "text",
                "content": "Machine learning and big data integration",
                "task": "classification",
                "metadata": {"id": "test3", "source": "hadoop"}
            }
        ]
        
        response = requests.post(
            f"{ia_api_url}/analyze/batch",
            json=batch_data,
            timeout=60
        )
        
        if response.status_code == 200:
            result = response.json()
            total_processed = result['total_processed']
            successful = sum(1 for r in result['batch_results'] if r['status'] == 'success')
            
            print("✅ Traitement par batch réussi")
            print(f"   Total traité: {total_processed}")
            print(f"   Succès: {successful}/{total_processed}")
            
            # Afficher quelques résultats
            for i, res in enumerate(result['batch_results'][:2]):
                if res['status'] == 'success':
                    if 'sentiment' in res['result']:
                        sentiment = res['result']['sentiment']['label']
                        print(f"   Item {i+1}: {sentiment}")
                    elif 'classification' in res['result']:
                        category = res['result']['classification']['category']
                        print(f"   Item {i+1}: {category}")
        else:
            print(f"❌ Erreur batch: {response.status_code}")
            return False
        
        print("\n🎉 === TOUS LES TESTS RÉUSSIS ===")
        print("✅ Communication Hadoop ↔ IA opérationnelle")
        print("✅ Analyse de sentiment fonctionnelle")
        print("✅ Détection d'objets fonctionnelle") 
        print("✅ Traitement par batch opérationnel")
        print("✅ Pipeline prêt pour traitement de données")
        
        return True
        
    except requests.RequestException as e:
        print(f"❌ Erreur de connexion: {e}")
        return False
    except Exception as e:
        print(f"❌ Erreur inattendue: {e}")
        return False

if __name__ == "__main__":
    success = test_ia_api_from_spark()
    
    if success:
        print("\n🚀 Intégration Hadoop ↔ IA validée avec succès!")
        print("📋 Prêt pour le traitement de données en production")
    else:
        print("\n❌ Échec de l'intégration")
    
    exit(0 if success else 1)