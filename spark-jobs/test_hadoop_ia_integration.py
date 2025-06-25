# spark-jobs/test_hadoop_ia_integration.py

import requests
import json
from datetime import datetime

def test_ia_api_from_spark():
    """Simple AI API Testing from Spark Environment"""
    
    print("🚀 === HADOOP ↔ AI INTEGRATION TEST ===")
    
    # AI API URL (accessible from the Hadoop network)
    ia_api_url = "http://ai-api-unified:8001"
    
    try:
        # Test 1: Health check
        print("\n📋 Test 1: Health Check")
        response = requests.get(f"{ia_api_url}/health", timeout=10)
        
        if response.status_code == 200:
            print("✅ AI API accessible from Spark")
            print(f"   Response: {response.json()}")
        else:
            print(f"❌ Error health check: {response.status_code}")
            return False

        # Test 2: Sentiment analysis
        print("\n📝 Test 2: Sentiment Analysis")
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

        # Test 3: Image analysis
        print("\n🖼️ Test 3: Image Analysis")
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
            print("✅ Image analysis successful")
            objects_count = result['result']['object_detection']['objects_count']
            print(f"   Objects detected: {objects_count}")
        else:
            print(f"❌ Error image analysis: {response.status_code}")
            print(f"   DDetails: {response.text}")
            return False

        # Test 4: Batch processing
        print("\n📦 Test 4: Batch Processing")
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

            print("✅ Batch processing successful")
            print(f"   Total processed: {total_processed}")
            print(f"   Success: {successful}/{total_processed}")

            # Show some results
            for i, res in enumerate(result['batch_results'][:2]):
                if res['status'] == 'success':
                    if 'sentiment' in res['result']:
                        sentiment = res['result']['sentiment']['label']
                        print(f"   Item {i+1}: {sentiment}")
                    elif 'classification' in res['result']:
                        category = res['result']['classification']['category']
                        print(f"   Item {i+1}: {category}")
        else:
            print(f"❌ Error batch: {response.status_code}")
            return False

        print("\n🎉 === ALL TESTS PASSED ===")
        print("✅ Hadoop ↔ AI communication operational")
        print("✅ Sentiment analysis functional")
        print("✅ Object detection functional")
        print("✅ Batch processing operational")
        print("✅ Pipeline ready for data processing")

        return True
        
    except requests.RequestException as e:
        print(f"❌ Connection error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False

if __name__ == "__main__":
    success = test_ia_api_from_spark()
    
    if success:
        print("\n🚀 Hadoop ↔ AI integration validated successfully!")
        print("📋 Ready for production data processing")
    else:
        print("\n❌ Integration failed")

    exit(0 if success else 1)