import json
import os
from pathlib import Path
from typing import Any

import numpy as np
from fastapi import FastAPI, File, HTTPException, UploadFile
from PIL import Image, UnidentifiedImageError

app = FastAPI(title="FarmMind Plant Analysis", version="1.0.0")
MODEL_PATH = Path(os.getenv("FARMMIND_MODEL_PATH", "model/plant_disease.keras"))
LABELS_PATH = Path(os.getenv("FARMMIND_LABELS_PATH", "model/labels.json"))
MIN_CONFIDENCE = float(os.getenv("FARMMIND_MIN_CONFIDENCE", "0.55"))
model: Any = None
labels: list[str] = []
load_error: str | None = None


def load_classifier() -> None:
    global model, labels, load_error
    try:
        if not MODEL_PATH.is_file() or not LABELS_PATH.is_file():
            load_error = "No trained classifier found. Install a PlantVillage-trained Keras model and matching labels file."
            return
        import tensorflow as tf
        model = tf.keras.models.load_model(MODEL_PATH)
        labels = json.loads(LABELS_PATH.read_text(encoding="utf-8"))
        if not isinstance(labels, list) or not labels:
            raise ValueError("labels.json must contain a non-empty array of class names")
        load_error = None
    except Exception as exc:
        model = None
        load_error = f"Model could not be loaded: {exc}"


@app.on_event("startup")
def startup() -> None:
    load_classifier()


@app.get("/health")
def health() -> dict[str, Any]:
    return {"status": "ready" if model is not None else "model_unavailable", "model_loaded": model is not None,
            "message": "Classifier loaded" if model is not None else load_error}


def explain(label: str) -> tuple[str, list[str], list[str]]:
    if "___" not in label:
        return "Unknown", [], []
    plant, disease = label.split("___", 1)
    disease = disease.replace("_", " ")
    plant = plant.replace("_", " ")
    if disease.lower() in {"healthy", "healthy leaf"}:
        return plant, ["No disease pattern was identified in the supported classes."], ["Continue routine monitoring and follow local crop guidance."]
    return plant, [f"The image resembles the model class {disease}. Visual image results may be inaccurate."], [
        "Separate affected leaves when practical and avoid handling healthy plants immediately afterward.",
        "Check several leaves and consult a local agronomist before applying treatment.",
        "Use locally approved prevention and treatment guidance for this crop.",
    ]


@app.post("/predict")
async def predict(file: UploadFile = File(...)) -> dict[str, Any]:
    if model is None:
        raise HTTPException(status_code=503, detail={"error": load_error or "Model unavailable"})
    if file.content_type not in {"image/jpeg", "image/png", "image/webp"}:
        raise HTTPException(status_code=415, detail="Upload a JPEG, PNG, or WebP leaf image")
    raw = await file.read()
    if not raw or len(raw) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Image must be under 10 MB")
    try:
        image = Image.open(__import__("io").BytesIO(raw)).convert("RGB").resize((224, 224))
    except (UnidentifiedImageError, OSError):
        raise HTTPException(status_code=400, detail="The uploaded file is not a readable image")
    tensor = np.asarray(image, dtype=np.float32)[None, ...] / 255.0
    try:
        predictions = np.asarray(model.predict(tensor, verbose=0))[0]
        if len(predictions) != len(labels):
            raise ValueError("Model output count does not match labels.json")
        index = int(np.argmax(predictions))
        confidence = float(predictions[index])
    except Exception as exc:
        raise HTTPException(status_code=503, detail=f"Classifier inference failed: {exc}")
    if confidence < MIN_CONFIDENCE:
        return {"supported": False, "message": "The image is unclear or outside supported classes. Try a well-lit, close photo of one leaf.", "confidence": confidence}
    label = labels[index]
    plant, symptoms, actions = explain(label)
    if plant == "Unknown":
        return {"supported": False, "message": "This image class is not mapped to a supported crop.", "confidence": confidence}
    disease = label.split("___", 1)[1].replace("_", " ")
    return {"supported": True, "plant": plant, "predicted_disease": disease, "confidence": confidence,
            "symptoms": symptoms, "preventive_actions": actions,
            "disclaimer": "Possible image-based classification only. This is not a confirmed diagnosis."}
