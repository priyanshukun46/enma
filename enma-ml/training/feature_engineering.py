from typing import Dict, Any, List, Tuple
import pandas as pd
import numpy as np

# Canonical feature column names used for training and inference
FEATURE_COLUMNS: List[str] = [
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

TARGET_COLUMN: str = "disrupted"

FEATURE_METADATA: Dict[str, Dict[str, Any]] = {
    "rainfall_last_1h": {"label": "Hourly Rainfall", "unit": "mm", "icon": "🌧", "threshold": 25.0},
    "rainfall_last_24h": {"label": "24h Accumulated Rainfall", "unit": "mm", "icon": "🌧", "threshold": 60.0},
    "forecast_rainfall_6h": {"label": "6h Forecast Rainfall", "unit": "mm", "icon": "🌦", "threshold": 30.0},
    "forecast_rainfall_12h": {"label": "12h Forecast Rainfall", "unit": "mm", "icon": "🌦", "threshold": 50.0},
    "forecast_rainfall_24h": {"label": "24h Forecast Rainfall", "unit": "mm", "icon": "🌧", "threshold": 80.0},
    "severe_weather_flag": {"label": "Severe Weather Alert", "unit": "bool", "icon": "⚡", "threshold": 0.5},
    "historical_incident_count": {"label": "Historical Incident Frequency", "unit": "events", "icon": "📜", "threshold": 5.0},
    "historical_landslide_count": {"label": "Historical Landslide Zone", "unit": "events", "icon": "🪨", "threshold": 3.0},
    "historical_flood_count": {"label": "Historical Flood Inundation", "unit": "events", "icon": "🌊", "threshold": 2.0},
    "previous_road_closures": {"label": "Previous Road Closures", "unit": "closures", "icon": "🚧", "threshold": 2.0},
    "road_condition_score": {"label": "Pavement Structural Degradation", "unit": "score", "icon": "🛣", "threshold": 60.0},
    "elevation": {"label": "High-Altitude Pass Elevation", "unit": "m", "icon": "🏔", "threshold": 2000.0},
    "slope": {"label": "Steep Terrain Slope", "unit": "deg", "icon": "⛰", "threshold": 25.0},
    "recent_incident_count": {"label": "Recent Active Field Incidents", "unit": "incidents", "icon": "📍", "threshold": 1.0},
    "recent_incident_severity_score": {"label": "Recent Incident Severity", "unit": "score", "icon": "🚨", "threshold": 50.0},
    "current_risk_score": {"label": "Baseline Rule-Based Risk", "unit": "score", "icon": "🤖", "threshold": 50.0},
}


def clean_and_prepare_features(df: pd.DataFrame) -> pd.DataFrame:
    """
    Validates, fills missing values, and casts data types for features.
    """
    df_clean = df.copy()

    for col in FEATURE_COLUMNS:
        if col not in df_clean.columns:
            if col == "severe_weather_flag":
                df_clean[col] = False
            else:
                df_clean[col] = 0.0

    # Type casting
    df_clean["severe_weather_flag"] = df_clean["severe_weather_flag"].astype(int)

    numeric_cols = [c for c in FEATURE_COLUMNS if c != "severe_weather_flag"]
    for c in numeric_cols:
        df_clean[c] = pd.to_numeric(df_clean[c], errors="coerce").fillna(0.0)

    return df_clean[FEATURE_COLUMNS]


def extract_input_vector(input_dict: Dict[str, Any]) -> pd.DataFrame:
    """
    Converts a single input dictionary/Pydantic model to a 1-row DataFrame
    matching the exact feature schema.
    """
    row = {}
    for col in FEATURE_COLUMNS:
        val = input_dict.get(col, 0.0)
        if col == "severe_weather_flag":
            row[col] = 1 if bool(val) else 0
        else:
            row[col] = float(val) if val is not None else 0.0

    return pd.DataFrame([row], columns=FEATURE_COLUMNS)
