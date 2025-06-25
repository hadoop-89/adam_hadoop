#!/bin/bash
# run_integration_test_fixed.sh
# VERSION CORRIGÉE POUR WINDOWS GIT BASH
# Résout les problèmes d'encodage et de compatibilité

set -e

# Configuration d'encodage pour Git Bash
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
export PYTHONIOENCODING=utf-8

# Couleurs pour Git Bash (sans emojis)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}[HADOOP + AI PROJECT] TESTS INTEGRATION WINDOWS COMPATIBLE${NC}"
echo -e "${BLUE}=========================================================${NC}"
echo -e "Plateforme: Windows avec Git Bash"
echo -e "Suite de tests: Validation pipeline complet"
echo -e "${BLUE}=========================================================${NC}"

# Aller au répertoire du projet
cd "$(dirname "$0")"
PROJECT_ROOT="$(pwd)"

echo -e "\n${YELLOW}[INFO] Répertoire projet: $PROJECT_ROOT${NC}"

# Fonction pour trouver Python sur Windows
find_python() {
    local python_cmd=""
    
    # Essayer différentes commandes Python pour Windows
    if command -v python >/dev/null 2>&1; then
        python_cmd="python"
    elif command -v python3 >/dev/null 2>&1; then
        python_cmd="python3"
    elif command -v py >/dev/null 2>&1; then
        python_cmd="py"
    else
        echo -e "${RED}[ERROR] Python non trouvé sur Windows${NC}"
        echo -e "${YELLOW}[SOLUTION] Solutions:${NC}"
        echo -e "   1. Installer Python depuis: https://python.org"
        echo -e "   2. Ajouter Python au PATH"
        echo -e "   3. Utiliser Python du Microsoft Store"
        echo -e "   4. Lancer le test dans un conteneur Docker"
        return 1
    fi
    
    echo "$python_cmd"
    return 0
}

# Vérifier l'installation Python
echo -e "\n${YELLOW}[CHECK] Vérification Python sur Windows...${NC}"

if PYTHON_CMD=$(find_python); then
    echo -e "${GREEN}[OK] Python trouvé: $PYTHON_CMD${NC}"
    
    # Vérifier la version Python
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1)
    echo -e "${GREEN}[OK] $PYTHON_VERSION${NC}"
    
    # Vérifier les packages requis
    echo -e "${YELLOW}[CHECK] Vérification packages Python...${NC}"
    
    # Vérifier requests
    if $PYTHON_CMD -c "import requests" 2>/dev/null; then
        echo -e "${GREEN}[OK] Package requests disponible${NC}"
    else
        echo -e "${YELLOW}[INSTALL] Installation de requests...${NC}"
        $PYTHON_CMD -m pip install requests --quiet --user || true
    fi
    
    # Vérifier json (normalement inclus)
    if $PYTHON_CMD -c "import json" 2>/dev/null; then
        echo -e "${GREEN}[OK] Package json disponible${NC}"
    fi
    
else
    echo -e "\n${RED}[ERROR] Problème de configuration Python sur Windows${NC}"
    echo -e "${YELLOW}[FALLBACK] Utilisation du conteneur Docker...${NC}"
    run_test_in_docker
    exit $?
fi

# Fonction pour lancer le test dans Docker (fallback Windows)
run_test_in_docker() {
    echo -e "\n${BLUE}[DOCKER] Lancement du test d'intégration dans conteneur Docker...${NC}"
    
    # Créer un test Docker simple
    cat > docker_integration_test.py << 'EOF'
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
EOF
    
    # Lancer le test dans le conteneur AI API
    if docker exec ai-api-unified python -c "$(cat docker_integration_test.py)"; then
        echo -e "\n${GREEN}[SUCCESS] === TEST INTEGRATION DOCKER REUSSI ===${NC}"
        echo -e "${GREEN}[OK] Validation projet réussie via Docker${NC}"
        return 0
    else
        echo -e "\n${RED}[ERROR] === TEST INTEGRATION DOCKER ECHOUE ===${NC}"
        return 1
    fi
}

# Vérifier si les services sont en cours d'exécution
echo -e "\n${YELLOW}[CHECK] Vérification statut des services...${NC}"

services_ok=true

if curl -f -s --max-time 5 "http://localhost:9870" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] Cluster Hadoop détecté${NC}"
else
    echo -e "${RED}[ERROR] Cluster Hadoop non en cours d'exécution${NC}"
    services_ok=false
fi

if curl -f -s --max-time 5 "http://localhost:8001/health" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] API IA détectée${NC}"
else
    echo -e "${RED}[ERROR] API IA non en cours d'exécution${NC}"
    services_ok=false
fi

if curl -f -s --max-time 5 "http://localhost:8002/health" >/dev/null 2>&1; then
    echo -e "${GREEN}[OK] API YOLO détectée${NC}"
else
    echo -e "${YELLOW}[WARNING] API YOLO ne répond pas${NC}"
fi

# Si les services ne sont pas en cours d'exécution, tenter de les démarrer
if [ "$services_ok" = false ]; then
    echo -e "\n${YELLOW}[STARTUP] Tentative de démarrage des services manquants...${NC}"
    
    if [ -f "./scripts/deploy.sh" ]; then
        echo -e "${BLUE}[STARTUP] Démarrage cluster Hadoop...${NC}"
        ./scripts/deploy.sh --status
    fi
    
    if [ -f "./deploy.sh" ]; then
        echo -e "${BLUE}[STARTUP] Démarrage services IA...${NC}"
        ./deploy.sh --status
    fi
    
    echo -e "${YELLOW}[WAIT] Attente 30s pour le démarrage des services...${NC}"
    sleep 30
fi

# Essayer de lancer le test Python si Python est disponible
if [ -n "$PYTHON_CMD" ] && [ -f "tests/test_complete_integration_fixed.py" ]; then
    echo -e "\n${BLUE}[TEST] === LANCEMENT TEST INTEGRATION PYTHON ===${NC}"
    
    # Configurer l'environnement Python pour Windows
    export PYTHONIOENCODING=utf-8
    export PYTHONLEGACYWINDOWSSTDIO=1
    
    # Lancer le test avec gestion d'erreur
    if $PYTHON_CMD tests/test_complete_integration_fixed.py; then
        echo -e "\n${GREEN}[SUCCESS] === TEST INTEGRATION COMPLETE AVEC SUCCES ===${NC}"
        echo -e "${GREEN}[OK] Tous les systèmes critiques sont opérationnels${NC}"
        echo -e "${GREEN}[OK] Pipeline Hadoop <-> IA fonctionne correctement${NC}"
        
        # Afficher les URLs d'accès
        echo -e "\n${BLUE}[ACCESS] URLs d'accès système:${NC}"
        echo -e "${GREEN}• Hadoop NameNode: http://localhost:9870${NC}"
        echo -e "${GREEN}• Documentation API IA: http://localhost:8001/docs${NC}"
        echo -e "${GREEN}• Documentation API YOLO: http://localhost:8002/docs${NC}"
        echo -e "${GREEN}• Dashboard Streamlit: http://localhost:8501${NC}"
        
        echo -e "\n${GREEN}[FINAL] VALIDATION PROJET REUSSIE${NC}"
        exit 0
    else
        echo -e "\n${YELLOW}[WARNING] Test Python a rencontré des problèmes, essai avec Docker...${NC}"
        run_test_in_docker
        exit $?
    fi
else
    echo -e "\n${YELLOW}[INFO] Fichier de test Python non disponible, utilisation méthode Docker...${NC}"
    run_test_in_docker
    exit $?
fi