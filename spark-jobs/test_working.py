import requests
import json
from datetime import datetime

def test_real_integration():
    print("🚀 === HADOOP INTEGRATION → IA TEST (WORKING VERSION) ===")
    
    # 1. Read data from HDFS with a simple method
    print("📁 Reading data from HDFS...")

    # Use the hdfs command directly
    import subprocess
    result = subprocess.run([
        "hdfs", "dfs", "-cat", "/data/text/reviews.csv"
    ], capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"❌ Error reading HDFS: {result.stderr}")
        return False
    
    lines = result.stdout.strip().split('\n')
    print(f"✅ Read {len(lines)} lines from HDFS")

    # 2. Take a few reviews for testing
    reviews = []
    for line in lines[1:4]:  # Skip header, take 3 reviews
        parts = line.split(',')
        if len(parts) >= 2:
            review_text = parts[1].strip('"')
            reviews.append(review_text)

    print(f"📝 Extracted reviews: {len(reviews)}")

    # 3. Send to IA API
    ia_api_url = "http://hadoop-ai-api:8001"
    
    batch_data = []
    for i, review in enumerate(reviews):
        batch_data.append({
            "data_type": "text",
            "content": review,
            "task": "sentiment",
            "metadata": {"id": f"review_{i+1}", "source": "hdfs"}
        })
    
    print("🤖 Sending to IA API...")
    response = requests.post(
        f"{ia_api_url}/analyze/batch",
        json=batch_data,
        timeout=60
    )
    
    if response.status_code == 200:
        result = response.json()
        print("✅ IA analysis successful!")
        print(f"   Total processed: {result['total_processed']}")
        
        for i, res in enumerate(result['batch_results']):
            if res['status'] == 'success':
                sentiment = res['result']['sentiment']['label']
                confidence = res['result']['sentiment']['confidence']
                print(f"   Review {i+1}: {sentiment} (confidence: {confidence})")
        print("\n🎯 === PIPELINE HADOOP → IA FUNCTIONAL ===")
        return True
    else:
        print(f"❌ Error IA API: {response.status_code}")
        return False

if __name__ == "__main__":
    success = test_real_integration()
    print(f"\n🎯 RResult: {'✅ SUCCESS' if success else '❌ FAILURE'}")
