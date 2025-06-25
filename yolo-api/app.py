from flask import Flask, request, jsonify, render_template_string
import torch
from ultralytics import YOLO
import cv2
import numpy as np
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Allow cross-origin requests

# Load YOLOv8 model
MODEL_PATH = "yolov8n.pt"  # Make sure to download this file
model = YOLO(MODEL_PATH)

# Home page with a simple interface
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>YOLOv8 API</title>
    <style>
        body { font-family: Arial, sans-serif; text-align: center; padding: 20px; }
        h1 { color: #2c3e50; }
        form { margin-top: 20px; }
        input { margin: 10px; }
        .result { margin-top: 20px; padding: 10px; border: 1px solid #ddd; display: inline-block; }
    </style>
</head>
<body>
    <h1>YOLOv8 API - Détection d'objets</h1>
    <p>Envoyez une image pour tester la détection d'objets.</p>
    <form id="uploadForm">
        <input type="file" id="imageInput" accept="image/*" required>
        <button type="submit">Envoyer</button>
    </form>
    <div class="result" id="result"></div>

    <script>
        document.getElementById("uploadForm").addEventListener("submit", async function(event) {
            event.preventDefault();
            let formData = new FormData();
            let imageFile = document.getElementById("imageInput").files[0];
            if (!imageFile) {
                alert("Veuillez sélectionner une image.");
                return;
            }
            formData.append("image", imageFile);

            let response = await fetch("/predict", { method: "POST", body: formData });
            let result = await response.json();
            document.getElementById("result").innerText = JSON.stringify(result, null, 2);
        });
    </script>
</body>
</html>
"""

@app.route('/')
def home():
    return render_template_string(HTML_TEMPLATE)

@app.route('/predict', methods=['POST'])
def predict():
    try:
        # Check if an image has been uploaded
        if 'image' not in request.files:
            return jsonify({'error': 'No image uploaded'}), 400

        file = request.files['image']
        image = np.frombuffer(file.read(), np.uint8)
        image = cv2.imdecode(image, cv2.IMREAD_COLOR)

        if image is None:
            return jsonify({'error': 'Invalid image file'}), 400

        # Run YOLO inference
        results = model(image)

        detections = []
        for result in results:
            boxes = result.boxes
            for box in boxes:
                class_id = int(box.cls.item()) if torch.is_tensor(box.cls) else int(box.cls)
                confidence = float(box.conf.item()) if torch.is_tensor(box.conf) else float(box.conf)
                bbox = box.xyxy.cpu().numpy().tolist() if torch.is_tensor(box.xyxy) else box.xyxy.tolist()

                detections.append({
                    "class": class_id,
                    "confidence": confidence,
                    "bbox": bbox
                })

        return jsonify(detections)
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'API is running'}), 200

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0", port=8000)
