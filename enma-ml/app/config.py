import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", 8000))
MODEL_PATH = Path(os.getenv("MODEL_PATH", str(BASE_DIR / "models" / "disruption_model.joblib")))
METADATA_PATH = Path(os.getenv("METADATA_PATH", str(BASE_DIR / "models" / "metadata.json")))
PREDICTION_WINDOW_HOURS = int(os.getenv("PREDICTION_WINDOW_HOURS", 24))
DEBUG = os.getenv("DEBUG", "false").lower() in ("true", "1", "yes")

# Risk classification thresholds for Disruption Probability
RISK_THRESHOLDS = {
    "LOW": (0.0, 0.25),
    "MODERATE": (0.26, 0.50),
    "HIGH": (0.51, 0.75),
    "CRITICAL": (0.76, 1.00),
}


def get_risk_level(prob: float) -> str:
    prob = max(0.0, min(1.0, float(prob)))
    if prob <= 0.25:
        return "low"
    elif prob <= 0.50:
        return "moderate"
    elif prob <= 0.75:
        return "high"
    else:
        return "critical"
