import requests
import time
import json
from datetime import datetime

def test_services():
    """Test tous les services via réseau Docker"""
    
    print("[CHECK] Test des services depuis conteneur Docker...")
    
    services = [
        ("Hadoop NameNode", "http://namenode:9870/dfshealth.html"),
        ("API IA", "http://ai-api-unified:8001/health"),
        ("API YOLO", "http://yolo-api-server:8000/health")
    ]
    
    results = {}
    
    for name, url in services:
        try:
            response = requests.get(url, timeout=10)
            if response.status_code == 200:
                print(f"[OK] {name} - Healthy")
                results[name] = True
            else:
                print(f"[ERROR] {name} - Status: {response.status_code}")
                results[name] = False
        except Exception as e:
            print(f"[ERROR] {name} - Erreur: {e}")
            results[name] = False
    
    return results

def test_ai_integration():
    """Test intégration IA"""
    print("\n[AI] Test intégration IA...")
    
    try:
        # Test analyse de sentiment
        test_data = {
            "data_type": "text",
            "content": "Ce test d'intégration fonctionne parfaitement!",
            "task": "sentiment"
        }
        
        response = requests.post(
            "http://ai-api-unified:8001/analyze",
            json=test_data,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            if "result" not in result:
                print("[ERROR] Format réponse IA inattendu")
                print("Contenu de la réponse IA:", result)
                return False
        else:
            print(f"[ERROR] Analyse IA échouée: {response.status_code}")
            return False
            
        return True  # <-- Ajoute aussi ce return pour dire que tout s'est bien passé !
            
    except Exception as e:
        print(f"[ERROR] Erreur intégration IA: {e}")
        return False


def main():
    print("[START] TEST INTEGRATION DOCKER")
    print("=" * 40)
    
    # Test services
    service_results = test_services()
    
    # Test intégration IA
    ai_result = test_ai_integration()
    
    # Résumé
    healthy_services = sum(service_results.values())
    total_services = len(service_results)
    
    print(f"\n[STATS] RESULTATS")
    print("=" * 20)
    print(f"Services: {healthy_services}/{total_services} healthy")
    print(f"Intégration IA: {'[OK] Working' if ai_result else '[ERROR] Failed'}")
    
    if healthy_services >= 2 and ai_result:
        print("\n[SUCCESS] TEST INTEGRATION REUSSI")
        print("[OK] Fonctionnalité principale validée")
        return 0
    else:
        print("\n[ERROR] TEST INTEGRATION ECHOUE")
        print("[WARNING] Certains composants nécessitent attention")
        return 1

if __name__ == "__main__":
    exit(main())
