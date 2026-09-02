import json
import logging
from pathlib import Path
from typing import Dict, Any, List, Tuple
import joblib
import numpy as np
import pandas as pd

from .config import MODEL_PATH, METADATA_PATH, PREDICTION_WINDOW_HOURS, get_risk_level
from .schemas import (
    RoadDisruptionInput,
    RoadDisruptionPredictionResponse,
    PredictionFactor
)

logger = logging.getLogger("enma.ml.predictor")

# Feature dictionary matching training feature_engineering
FEATURE_COLUMNS = [
    "rainfall_last_1h",
    "rainfall_last_24h",
    "forecast_rainfall_6h",
    "forecast_rainfall_12h",
    "forecast_rainfall_24h",
    "severe_weather_flag",
    "historical_incident_count",
    "historical_landslide_count",
    "historical_flood_count",
    "previous_road_closures",
    "road_condition_score",
    "elevation",
    "slope",
    "recent_incident_count",
    "recent_incident_severity_score",
    "current_risk_score",
]

FEATURE_LABELS = {
    "rainfall_last_1h": ("Hourly Rainfall", "🌧", 25.0),
    "rainfall_last_24h": ("24h Accumulated Rainfall", "🌧", 60.0),
    "forecast_rainfall_6h": ("6h Forecast Rainfall", "🌦", 30.0),
    "forecast_rainfall_12h": ("12h Forecast Rainfall", "🌦", 50.0),
    "forecast_rainfall_24h": ("24h Forecast Rainfall", "🌧", 80.0),
    "severe_weather_flag": ("Severe Weather Alert", "⚡", 0.5),
    "historical_incident_count": ("Historical Incidents", "📜", 5.0),
    "historical_landslide_count": ("Landslide Hazard History", "🪨", 3.0),
    "historical_flood_count": ("Flood Hazard History", "🌊", 2.0),
    "previous_road_closures": ("Past Closures", "🚧", 2.0),
    "road_condition_score": ("Pavement Degradation", "🛣", 60.0),
    "elevation": ("Mountain Elevation", "🏔", 2000.0),
    "slope": ("Steep Terrain Slope", "⛰", 28.0),
    "recent_incident_count": ("Recent Active Incidents", "📍", 1.0),
    "recent_incident_severity_score": ("Incident Severity", "🚨", 50.0),
    "current_risk_score": ("Baseline Risk Score", "🤖", 50.0),
}


class DisruptionPredictor:
    def __init__(self, model_path: Path = MODEL_PATH, metadata_path: Path = METADATA_PATH):
        self.model_path = model_path
        self.metadata_path = metadata_path
        self.model = None
        self.metadata = {}
        self.load()

    def load(self):
        try:
            if self.model_path.exists():
                self.model = joblib.load(self.model_path)
                logger.info(f"Loaded trained ML model from {self.model_path}")
            else:
                logger.warning(f"Model file not found at {self.model_path}")

            if self.metadata_path.exists():
                with open(self.metadata_path, "r") as f:
                    self.metadata = json.load(f)
                logger.info(f"Loaded metadata for model version {self.metadata.get('model_version')}")
        except Exception as e:
            logger.error(f"Error loading ML artifacts: {e}", exc_info=True)

    @property
    def is_ready(self) -> bool:
        return self.model is not None

    def predict(self, input_data: RoadDisruptionInput) -> RoadDisruptionPredictionResponse:
        if not self.is_ready:
            raise RuntimeError("ML disruption model is not loaded.")

        input_dict = input_data.model_dump()
        row = {}
        for col in FEATURE_COLUMNS:
            val = input_dict.get(col, 0.0)
            if col == "severe_weather_flag":
                row[col] = 1 if bool(val) else 0
            else:
                row[col] = float(val) if val is not None else 0.0

        df = pd.DataFrame([row], columns=FEATURE_COLUMNS)

        # Generate Disruption Probability
        if hasattr(self.model, "predict_proba"):
            prob = float(self.model.predict_proba(df)[0, 1])
        else:
            prob = float(self.model.predict(df)[0])

        prob = max(0.0, min(1.0, prob))
        risk_level = get_risk_level(prob)

        # Identify Top Contributing Factors
        top_factors, narrative = self._explain_prediction(input_dict, prob, risk_level)

        return RoadDisruptionPredictionResponse(
            road_id=input_data.road_id,
            disruption_probability=round(prob, 4),
            risk_level=risk_level,
            prediction_window_hours=PREDICTION_WINDOW_HOURS,
            model_version=self.metadata.get("model_version", "1.0.0"),
            top_factors=top_factors,
            narrative_explanation=narrative,
            model_metadata={
                "algorithm": self.metadata.get("algorithm", "MLClassifier"),
                "trained_at": self.metadata.get("trained_at", ""),
                "selection_rationale": self.metadata.get("selection_rationale", ""),
                "metrics": self.metadata.get("selected_metrics", {})
            }
        )

    def _explain_prediction(
        self, input_dict: Dict[str, Any], prob: float, risk_level: str
    ) -> Tuple[List[PredictionFactor], str]:
        factors = []
        importances = self.metadata.get("feature_importances", {})

        # Compute factor scores combining feature value ratio and model weight
        candidate_factors = []
        for feat, (label, icon, threshold) in FEATURE_LABELS.items():
            val = float(input_dict.get(feat, 0.0))
            if feat == "severe_weather_flag":
                if val > 0.5:
                    candidate_factors.append((
                        feat, label, icon, val,
                        "Active severe meteorological cloudburst/flood warning.",
                        2.5
                    ))
            elif val >= threshold:
                ratio = (val / threshold)
                weight = importances.get(feat, 0.05)
                score = ratio * (1.0 + weight * 5.0)
                desc = f"{label} exceeds normal threshold ({val} vs baseline {threshold})."
                candidate_factors.append((feat, label, icon, val, desc, score))

        # Sort candidate factors by impact score
        candidate_factors.sort(key=lambda x: x[5], reverse=True)

        for feat, label, icon, val, desc, score in candidate_factors[:4]:
            imp_level = "high" if score >= 2.0 else "medium"
            factors.append(
                PredictionFactor(
                    feature=feat,
                    importance=imp_level,
                    label=f"{icon} {label}",
                    value=round(val, 1),
                    description=desc
                )
            )

        if not factors:
            factors.append(
                PredictionFactor(
                    feature="nominal_flow",
                    importance="low",
                    label="🟢 Nominal Conditions",
                    value=round(prob * 100.0, 1),
                    description="Environmental and incident telemetry remain within stable baseline limits."
                )
            )

        # Build human-readable narrative summary
        if risk_level in ("critical", "high"):
            factor_names = ", ".join([f.label for f in factors[:3]])
            narrative = f"ML model predicts a {prob*100:.1f}% disruption probability ({risk_level.upper()} RISK) within the next {PREDICTION_WINDOW_HOURS} hours driven primarily by {factor_names}."
        elif risk_level == "moderate":
            narrative = f"Moderate disruption probability ({prob*100:.1f}%) detected over next {PREDICTION_WINDOW_HOURS} hours. Precautionary transport speed limits and alternate corridor readiness advised."
        else:
            narrative = f"Low disruption probability ({prob*100:.1f}%). High confidence that corridor remains open and accessible under current meteorological forecast."

        return factors, narrative


predictor = DisruptionPredictor()
