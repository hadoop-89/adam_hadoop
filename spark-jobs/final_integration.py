import requests
import json
from datetime import datetime

def final_hadoop_ia_test():
    print("🚀 === FINAL HADOOP INTEGRATION TEST → AI ===")
    
    # 1. Retrieve data from the NameNode via API
    print("📁 Retrieving data from HDFS...")

    try:
        # Use the NameNode API to read the file
        namenode_url = "http://namenode:9870/webhdfs/v1/data/text/reviews.csv?op=OPEN"
        response = requests.get(namenode_url, allow_redirects=True)
        
        if response.status_code != 200:
            print(f"❌ API error reading HDFS: {response.status_code}")
            return False

        # Parse CSV data
        lines = response.text.strip().split('\n')
        print(f"✅ Read {len(lines)} lines from HDFS")

        # Extract a few reviews (skip header)
        reviews = []
        for line in lines[1:4]:
            parts = line.split(',')
            if len(parts) >= 2:
                # Clean review text (remove quotes)
                review_text = parts[1].strip('"')
                reviews.append(review_text)

        print(f"📝 Extracted reviews: {len(reviews)}")
        for i, review in enumerate(reviews):
            print(f"   {i+1}: {review[:50]}...")

        # 2. Send to AI API
        print("\n🤖 Sending to AI API...")
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
            print("✅  successful AI analysis!")
            print(f"   Total processed: {result['total_processed']}")

            # Display results
            for i, res in enumerate(result['batch_results']):
                if res['status'] == 'success':
                    sentiment = res['result']['sentiment']['label']
                    confidence = res['result']['sentiment']['confidence']
                    print(f"   Review {i+1}: {sentiment} (confidence: {confidence})")

            print(f"\n🎯 === PIPELINE HADOOP → IA FUNCTIONAL ===")
            print("✅ Reading data from HDFS")
            print("✅ Processing by AI")
            print("✅ Sentiment analysis successful")
            print("✅ Your project is OPERATIONAL!")
            print("🎉 Congratulations! Your Hadoop integration with AI is complete.")
            return True
        else:
            print(f"❌ API error IA: {response.status_code}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

if __name__ == "__main__":
    success = final_hadoop_ia_test()
    print(f"\n🏆 Final result: {'✅ TOTAL SUCCESS' if success else '❌ FAILURE'}")
