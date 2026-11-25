# AI service model setup

FarmMind intentionally does not return fabricated disease predictions. Start the API without weights to get `/health` with `model_loaded: false`; `/predict` will respond with HTTP 503 until a real classifier is installed.

Place a TensorFlow/Keras image classifier at `model/plant_disease.keras` and a matching ordered class list at `model/labels.json`. The classifier must accept RGB 224×224 images normalized to 0–1 and return one score per label. A PlantVillage-trained MobileNetV2/EfficientNet model is a suitable starting point. Configure alternate paths with `FARMMIND_MODEL_PATH` and `FARMMIND_LABELS_PATH`. Set `FARMMIND_MIN_CONFIDENCE` to adjust the rejection threshold.

Run from this directory:

```powershell
py -3.11 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

The API accepts `POST /predict` as multipart form-data field `file`. It requires a real trained checkpoint and matching labels file. Unclear, unsupported, or low-confidence images are rejected or flagged rather than presented as a confirmed diagnosis.

