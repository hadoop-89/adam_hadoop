import requests
import json
from datetime import datetime

def final_hadoop_ia_test():
    print("🚀 === TEST INTÉGRATION FINALE HADOOP → IA ===")
    
    # 1. Récupérer les données depuis le NameNode via l'API
    print("📁 Récupération des données depuis HDFS...")
    
    try:
        # On utilise l'API NameNode pour lire le fichier
        namenode_url = "http://namenode:9870/webhdfs/v1/data/text/reviews.csv?op=OPEN"
        response = requests.get(namenode_url, allow_redirects=True)
        
        if response.status_code != 200:
            print(f"❌ Erreur lecture HDFS via API: {response.status_code}")
            return False
        
        # Parser les données CSV
        lines = response.text.strip().split('\n')
        print(f"✅ Lu {len(lines)} lignes depuis HDFS")
        
        # Extraire quelques reviews (sauter le header)
        reviews = []
        for line in lines[1:4]:
            parts = line.split(',')
            if len(parts) >= 2:
                # Nettoyer le texte de la review (enlever les guillemets)
                review_text = parts[1].strip('"')
                reviews.append(review_text)
        
        print(f"📝 Reviews extraites: {len(reviews)}")
        for i, review in enumerate(reviews):
            print(f"   {i+1}: {review[:50]}...")
        
        # 2. Envoyer à l'API IA
        print("\n🤖 Envoi vers API IA...")
        ia_api_url = "http://hadoop-ai-api:8001"
        
        batch_data = []
        for i, review in enumerate(reviews):
            batch_data.append({
                "data_type": "text",
                "content": review,
                "task": "sentiment",
                "metadata": {"id": f"review_{i+1}", "source": "hadoop_hdfs"}
            })
        
        response = requests.post(
            f"{ia_api_url}/analyze/batch",
            json=batch_data,
            timeout=60
        )
        
        if response.status_code == 200:
            result = response.json()
            print("✅ Analyse IA réussie!")
            print(f"   Total traité: {result['total_processed']}")
            
            # Afficher les résultats
            for i, res in enumerate(result['batch_results']):
                if res['status'] == 'success':
                    sentiment = res['result']['sentiment']['label']
                    confidence = res['result']['sentiment']['confidence']
                    print(f"   Review {i+1}: {sentiment} (confiance: {confidence})")
            
            print(f"\n🎯 === PIPELINE HADOOP → IA FONCTIONNEL ===")
            print("✅ Lecture données depuis HDFS")
            print("✅ Traitement par l'IA")
            print("✅ Analyse de sentiment réussie")
            print("✅ Votre projet est OPÉRATIONNEL!")
            
            return True
        else:
            print(f"❌ Erreur API IA: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Erreur: {e}")
        return False

if __name__ == "__main__":
    success = final_hadoop_ia_test()
    print(f"\n🏆 Résultat final: {'✅ SUCCÈS TOTAL' if success else '❌ ÉCHEC'}")
