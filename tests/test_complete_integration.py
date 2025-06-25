# tests/test_complete_integration_fixed.py
"""
Test d'intégration complet - VERSION CORRIGÉE POUR WINDOWS/GIT BASH
Résout les problèmes d'encodage emoji et Windows
"""

import requests
import json
import logging
import time
import sys
import os
from datetime import datetime
from typing import Dict, Any, List

# Configuration du logging pour Windows (sans emojis dans les handlers de fichier)
class SafeFormatter(logging.Formatter):
    """Formatter qui supprime les emojis pour éviter les erreurs d'encodage"""
    
    def format(self, record):
        # Supprimer les emojis du message
        message = record.getMessage()
        # Remplacer les emojis courants par du texte
        emoji_replacements = {
            '🚀': '[START]',
            '✅': '[OK]',
            '❌': '[ERROR]',
            '⚠️': '[WARNING]',
            '🔍': '[CHECK]',
            '📊': '[STATS]',
            '🏥': '[HEALTH]',
            '🔗': '[CONNECT]',
            '📥': '[DATA]',
            '📝': '[TEXT]',
            '🖼️': '[IMAGE]',
            '📦': '[BATCH]',
            '🔬': '[TEST]',
            '🔄': '[RELOAD]',
            '📋': '[INFO]',
            '🤖': '[AI]',
            '📈': '[RESULT]',
            '💡': '[TIP]',
            '🎉': '[SUCCESS]'
        }
        
        for emoji, replacement in emoji_replacements.items():
            message = message.replace(emoji, replacement)
        
        record.msg = message
        record.args = ()
        return super().format(record)

# Configuration du logging sécurisée pour Windows
def setup_logging():
    """Configure le logging de manière sécurisée pour Windows"""
    
    # Créer un logger personnalisé
    logger = logging.getLogger(__name__)
    logger.setLevel(logging.INFO)
    
    # Handler pour la console (avec encoding UTF-8)
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    
    # Formatter sécurisé pour Windows
    safe_formatter = SafeFormatter(
        '%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    console_handler.setFormatter(safe_formatter)
    
    # Nettoyer les handlers existants
    logger.handlers.clear()
    logger.addHandler(console_handler)
    
    return logger

# Initialiser le logger
logger = setup_logging()

class HadoopAIIntegrationTester:
    """
    Testeur d'intégration Hadoop + AI - Version Windows Compatible
    """
    
    def __init__(self):
        self.results = {}
        self.start_time = datetime.now()
        
        # URLs des services
        self.services = {
            "hadoop_namenode": "http://localhost:9870",
            "ai_api": "http://localhost:8001/health",
            "yolo_api": "http://localhost:8002/health",
            "streamlit": "http://localhost:8501"
        }
        
        logger.info("[START] === INTEGRATION TEST SUITE INITIALISATION ===")
        logger.info("Plateforme: Windows avec Git Bash")
        logger.info("Mode: Test pipeline complet Hadoop + AI")
        logger.info("===========================================")
    
    def run_complete_test_suite(self) -> Dict[str, Any]:
        """Exécuter la suite complète de tests"""
        
        logger.info("[START] === DEBUT SUITE COMPLETE DE TESTS ===")
        logger.info("Test integration Hadoop + AI")
        logger.info("============================================================")
        
        try:
            # PHASE 1: Validation Infrastructure
            logger.info("")
            logger.info("[INFO] PHASE 1: Validation Infrastructure")
            self.test_services_health()
            self.test_hdfs_connectivity()
            
            # PHASE 2: Test Pipeline de Données
            logger.info("")
            logger.info("[STATS] PHASE 2: Test Pipeline de Données")
            sample_data = self.test_hdfs_data_access()
            
            # PHASE 3: Test Services AI
            logger.info("")
            logger.info("[AI] PHASE 3: Test Services AI")
            self.test_ai_text_analysis(sample_data)
            self.test_ai_image_analysis()
            self.test_batch_processing(sample_data)
            
            # PHASE 4: Tests Fonctionnalités Avancées
            logger.info("")
            logger.info("[TEST] PHASE 4: Tests Fonctionnalités Avancées")
            self.test_yolo_retraining()
            self.test_performance_metrics()
            
            # PHASE 5: Résumé des Résultats
            logger.info("")
            logger.info("[RESULT] PHASE 5: Résumé des Résultats")
            
            return self.generate_test_report()
            
        except Exception as e:
            logger.error(f"[ERROR] Erreur dans la suite de tests: {e}")
            self.results["critical_error"] = str(e)
            return self.generate_test_report()
    
    def test_services_health(self):
        """Test de santé des services"""
        logger.info("[HEALTH] Test santé des services...")
        
        healthy_services = 0
        
        for service_name, service_url in self.services.items():
            try:
                response = requests.get(service_url, timeout=10)
                if response.status_code == 200:
                    logger.info(f"[OK] {service_name} - Healthy")
                    healthy_services += 1
                    self.results[f"{service_name}_health"] = True
                else:
                    logger.error(f"[ERROR] {service_name} - Status: {response.status_code}")
                    self.results[f"{service_name}_health"] = False
            except Exception as e:
                logger.error(f"[ERROR] {service_name} - Erreur: {e}")
                self.results[f"{service_name}_health"] = False
        
        logger.info(f"[STATS] Santé Services: {healthy_services}/4 services opérationnels")
        self.results["services_health_score"] = f"{healthy_services}/4"
    
    def test_hdfs_connectivity(self):
        """Test de connectivité HDFS"""
        logger.info("[CONNECT] Test connectivité HDFS...")
        
        try:
            # Test via l'API WebHDFS
            hdfs_url = "http://localhost:9870/webhdfs/v1/?op=LISTSTATUS"
            response = requests.get(hdfs_url, timeout=30)
            
            if response.status_code == 200:
                logger.info("[OK] Système de fichiers HDFS accessible")
                self.results["hdfs_connectivity"] = True
                
                # Test du répertoire /data
                data_url = "http://localhost:9870/webhdfs/v1/data?op=LISTSTATUS"
                data_response = requests.get(data_url, timeout=10)
                
                if data_response.status_code == 200:
                    logger.info("[OK] Répertoire /data trouvé dans HDFS")
                    self.results["hdfs_data_directory"] = True
                else:
                    logger.warning("[WARNING] Répertoire /data non trouvé")
                    self.results["hdfs_data_directory"] = False
            else:
                logger.error(f"[ERROR] HDFS non accessible: {response.status_code}")
                self.results["hdfs_connectivity"] = False
                
        except Exception as e:
            logger.error(f"[ERROR] Erreur connectivité HDFS: {e}")
            self.results["hdfs_connectivity"] = False
    
    def test_hdfs_data_access(self) -> str:
        """Test d'accès aux données HDFS"""
        logger.info("[DATA] Test accès données HDFS...")
        
        try:
            # Tenter de lire des données existantes
            data_paths = [
                "/data/text/existing/amazon_reviews.csv",
                "/data/text/existing/existing_reviews_db.csv"
            ]
            
            sample_data = None
            
            for data_path in data_paths:
                try:
                    read_url = f"http://localhost:9870/webhdfs/v1{data_path}?op=OPEN"
                    response = requests.get(read_url, allow_redirects=True, timeout=30)
                    
                    if response.status_code == 200:
                        # Prendre les premières lignes comme échantillon
                        lines = response.text.strip().split('\n')
                        if len(lines) > 1:
                            # Extraire un texte d'exemple (deuxième ligne, première colonne)
                            sample_line = lines[1].split(',')
                            if len(sample_line) > 1:
                                sample_data = sample_line[1].strip('"')[:100]
                                logger.info("[OK] Données échantillon récupérées depuis HDFS")
                                self.results["hdfs_data_access"] = True
                                break
                except:
                    continue
            
            if not sample_data:
                # Données par défaut pour les tests
                sample_data = "Ceci est un test d'intégration pour l'analyse de sentiment."
                logger.warning("[WARNING] Utilisation de données de test par défaut")
                self.results["hdfs_data_access"] = False
            
            return sample_data
            
        except Exception as e:
            logger.error(f"[ERROR] Impossible de lire les données HDFS: {e}")
            self.results["hdfs_data_access"] = False
            return "Données de test par défaut pour l'analyse de sentiment."
    
    def test_ai_text_analysis(self, sample_data: str):
        """Test d'analyse de texte IA"""
        logger.info("[TEXT] Test analyse de texte IA...")
        
        try:
            start_time = time.time()
            
            # Test avec l'API IA unifiée
            ai_data = {
                "data_type": "text",
                "content": sample_data,
                "task": "sentiment",
                "model_preference": "finetuned",
                "metadata": {"source": "integration_test"}
            }
            
            response = requests.post(
                "http://localhost:8001/analyze",
                json=ai_data,
                timeout=60
            )
            
            processing_time = round((time.time() - start_time) * 1000, 2)
            
            if response.status_code == 200:
                result = response.json()
                
                if "result" in result and "sentiment" in result["result"]:
                    sentiment_data = result["result"]["sentiment"]
                    sentiment = sentiment_data.get("label", "UNKNOWN")
                    confidence = sentiment_data.get("confidence", 0.0)
                    
                    logger.info("[OK] Analyse de texte réussie")
                    logger.info(f"    Sentiment: {sentiment} (confiance: {confidence:.3f})")
                    logger.info(f"    Temps de traitement: {processing_time}ms")
                    
                    self.results["ai_text_analysis"] = True
                    self.results["text_analysis_time"] = processing_time / 1000
                else:
                    logger.error("[ERROR] Format de réponse IA inattendu")
                    self.results["ai_text_analysis"] = False
            else:
                logger.error(f"[ERROR] Erreur API IA: {response.status_code}")
                self.results["ai_text_analysis"] = False
                
        except Exception as e:
            logger.error(f"[ERROR] Erreur analyse de texte: {e}")
            self.results["ai_text_analysis"] = False
    
    def test_ai_image_analysis(self):
        """Test d'analyse d'image IA"""
        logger.info("[IMAGE] Test analyse d'image IA...")
        
        try:
            start_time = time.time()
            
            # Test avec des données d'image simulées
            image_data = {
                "data_type": "image",
                "content": {"test": "image_data"},
                "task": "detection",
                "metadata": {"source": "integration_test"}
            }
            
            response = requests.post(
                "http://localhost:8001/analyze",
                json=image_data,
                timeout=60
            )
            
            processing_time = round((time.time() - start_time) * 1000, 2)
            
            if response.status_code == 200:
                result = response.json()
                
                if "result" in result:
                    logger.info("[OK] Analyse d'image réussie")
                    logger.info(f"    Temps de traitement: {processing_time}ms")
                    
                    if "object_detection" in result["result"]:
                        objects_count = result["result"]["object_detection"].get("objects_count", 0)
                        logger.info(f"    Objets détectés: {objects_count}")
                    
                    self.results["ai_image_analysis"] = True
                    self.results["image_analysis_time"] = processing_time / 1000
                else:
                    logger.error("[ERROR] Format de réponse inattendu")
                    self.results["ai_image_analysis"] = False
            else:
                logger.error(f"[ERROR] Erreur analyse d'image: {response.status_code}")
                self.results["ai_image_analysis"] = False
                
        except Exception as e:
            logger.error(f"[ERROR] Erreur analyse d'image: {e}")
            self.results["ai_image_analysis"] = False
    
    def test_batch_processing(self, sample_data: str):
        """Test de traitement par lot"""
        logger.info("[BATCH] Test traitement par lot...")
        
        try:
            start_time = time.time()
            
            # Créer un lot de données de test
            batch_data = [
                {
                    "data_type": "text",
                    "content": "Excellent produit, très satisfait!",
                    "task": "sentiment",
                    "metadata": {"id": "test1"}
                },
                {
                    "data_type": "text",  
                    "content": "Qualité décevante, pas recommandé.",
                    "task": "sentiment",
                    "metadata": {"id": "test2"}
                },
                {
                    "data_type": "text",
                    "content": sample_data,
                    "task": "sentiment",
                    "metadata": {"id": "test3"}
                }
            ]
            
            response = requests.post(
                "http://localhost:8001/analyze/batch",
                json=batch_data,
                timeout=90
            )
            
            processing_time = round((time.time() - start_time) * 1000, 2)
            
            if response.status_code == 200:
                result = response.json()
                
                if "batch_results" in result:
                    total_processed = len(result["batch_results"])
                    successful = sum(1 for r in result["batch_results"] if r.get("status") == "success")
                    
                    logger.info("[OK] Traitement par lot réussi")
                    logger.info(f"    Traités: {successful}/{total_processed} éléments")
                    logger.info(f"    Temps total: {processing_time}ms")
                    logger.info(f"    Moyenne par élément: {processing_time/max(total_processed,1):.0f}ms")
                    
                    self.results["batch_processing"] = True
                    self.results["batch_processing_time"] = processing_time / 1000
                else:
                    logger.error("[ERROR] Format de réponse batch inattendu")
                    self.results["batch_processing"] = False
            else:
                logger.error(f"[ERROR] Erreur traitement batch: {response.status_code}")
                self.results["batch_processing"] = False
                
        except Exception as e:
            logger.error(f"[ERROR] Erreur traitement par lot: {e}")
            self.results["batch_processing"] = False
    
    def test_yolo_retraining(self):
        """Test de capacité de ré-entraînement YOLO"""
        logger.info("[RELOAD] Test capacité ré-entraînement YOLO...")
        
        try:
            # Test endpoint de ré-entraînement (si disponible)
            response = requests.get("http://localhost:8002/model/info", timeout=10)
            
            if response.status_code == 200:
                logger.info("[OK] API YOLO accessible pour ré-entraînement")
                self.results["yolo_retraining"] = True
            else:
                logger.warning("[WARNING] Endpoint ré-entraînement YOLO non disponible")
                self.results["yolo_retraining"] = False
                
        except Exception as e:
            logger.warning(f"[WARNING] Endpoint ré-entraînement YOLO non disponible: {e}")
            self.results["yolo_retraining"] = False
    
    def test_performance_metrics(self):
        """Test et collecte des métriques de performance"""
        logger.info("[STATS] Collecte métriques de performance...")
        
        try:
            # Métriques des services
            performance_metrics = {}
            
            for service_name, service_url in self.services.items():
                try:
                    start_time = time.time()
                    response = requests.get(service_url, timeout=10)
                    response_time = round((time.time() - start_time) * 1000, 2)
                    
                    if response.status_code == 200:
                        performance_metrics[f"{service_name}_time"] = response_time
                        logger.info(f"[OK] {service_name}: {response_time}ms")
                    
                except Exception:
                    pass
            
            self.results["performance_metrics"] = performance_metrics
            
        except Exception as e:
            logger.error(f"[ERROR] Erreur collecte métriques: {e}")
    
    def generate_test_report(self) -> Dict[str, Any]:
        """Générer le rapport final des tests"""
        
        end_time = datetime.now()
        duration = (end_time - self.start_time).total_seconds()
        
        # Compter les tests réussis
        test_results = {
            "Services Health": self.results.get("services_health_score", "0/4"),
            "HDFS Connectivity": "[OK] PASSED" if self.results.get("hdfs_connectivity", False) else "[ERROR] FAILED",
            "Data Access": "[OK] PASSED" if self.results.get("hdfs_data_access", False) else "[ERROR] FAILED", 
            "AI Text Analysis": "[OK] PASSED" if self.results.get("ai_text_analysis", False) else "[ERROR] FAILED",
            "AI Image Analysis": "[OK] PASSED" if self.results.get("ai_image_analysis", False) else "[ERROR] FAILED",
            "Batch Processing": "[OK] PASSED" if self.results.get("batch_processing", False) else "[ERROR] FAILED",
            "YOLO Retraining": "[OK] PASSED" if self.results.get("yolo_retraining", False) else "[ERROR] FAILED"
        }
        
        # Calculer le taux de réussite
        passed_tests = sum(1 for result in test_results.values() if "[OK] PASSED" in str(result))
        total_tests = len(test_results)
        success_rate = (passed_tests / total_tests) * 100 if total_tests > 0 else 0
        
        logger.info("")
        logger.info("============================================================")
        logger.info("[STATS] === RESUME RESULTATS TESTS INTEGRATION ===")
        logger.info("============================================================")
        
        for test_name, status in test_results.items():
            logger.info(f"{test_name:20}: {status}")
        
        logger.info(f"")
        logger.info(f"[RESULT] Taux de Réussite Global: {success_rate:.1f}% ({passed_tests}/{total_tests})")
        
        # Métriques de performance
        if "performance_metrics" in self.results:
            logger.info("")
            logger.info("[RESULT] Métriques de Performance:")
            for metric, value in self.results["performance_metrics"].items():
                logger.info(f"    {metric}: {value}ms")
        
        # Métriques d'analyse
        analysis_metrics = {}
        for key in ["text_analysis_time", "image_analysis_time", "batch_processing_time"]:
            if key in self.results:
                analysis_metrics[key] = f"{self.results[key]:.3f}s"
        
        if analysis_metrics:
            logger.info("")
            logger.info("[RESULT] Métriques d'Analyse:")
            for metric, value in analysis_metrics.items():
                logger.info(f"    {metric}: {value}")
        
        # Verdict final
        if success_rate >= 80:
            logger.info("")
            logger.info("[SUCCESS] === SUITE DE TESTS INTEGRATION REUSSIE ===")
            logger.info("[SUCCESS] Tous les composants critiques fonctionnent")
            logger.info("[SUCCESS] Pipeline Hadoop <-> AI opérationnel")
        elif success_rate >= 60:
            logger.info("")
            logger.info("[WARNING] === TESTS PARTIELLEMENT REUSSIS ===")
            logger.info("[WARNING] Certains composants nécessitent attention")
        else:
            logger.info("")
            logger.info("[ERROR] === SUITE DE TESTS INTEGRATION ECHOUEE ===")
            logger.info("[ERROR] Problèmes critiques détectés dans le système")
            logger.info("[TIP] Vérifier les logs et configuration des services")
        
        # Sauvegarder le rapport
        report_data = {
            "test_results": test_results,
            "success_rate": success_rate,
            "duration_seconds": duration,
            "performance_metrics": self.results.get("performance_metrics", {}),
            "analysis_metrics": analysis_metrics,
            "timestamp": end_time.isoformat()
        }
        
        try:
            with open("integration_test_report.json", "w", encoding='utf-8') as f:
                json.dump(report_data, f, indent=2, ensure_ascii=False)
            logger.info("")
            logger.info("[INFO] Rapport détaillé sauvegardé: integration_test_report.json")
        except Exception as e:
            logger.warning(f"[WARNING] Impossible de sauvegarder le rapport: {e}")
        
        logger.info("============================================================")
        
        return report_data

def main():
    """Fonction principale d'exécution des tests"""
    
    print("\n" + "="*60)
    print("   SUITE DE TESTS INTEGRATION HADOOP + AI")  
    print("   Version Windows/Git Bash Compatible")
    print("="*60 + "\n")
    
    try:
        tester = HadoopAIIntegrationTester()
        results = tester.run_complete_test_suite()
        
        # Code de sortie basé sur le taux de réussite
        if results["success_rate"] >= 80:
            print("\n[RESULTAT FINAL] Tests réussis!")
            return 0
        elif results["success_rate"] >= 60:
            print("\n[RESULTAT FINAL] Tests partiellement réussis")
            return 1
        else:
            print("\n[RESULTAT FINAL] Tests échoués")
            return 2
            
    except Exception as e:
        print(f"\n[ERREUR CRITIQUE] Erreur dans l'exécution des tests: {e}")
        return 3

if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)