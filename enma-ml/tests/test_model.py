import pytest
import sys
from pathlib import Path
import pandas as pd
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from training.feature_engineering import FEATURE_COLUMNS, clean_and_prepare_features, extract_input_vector
from app.predictor import predictor
from app.schemas import RoadDisruptionInput


def test_feature_columns_consistency():
    assert len(FEATURE_COLUMNS) == 16
    assert "rainfall_last_24h" in FEATURE_COLUMNS
    assert "slope" in FEATURE_COLUMNS
    assert "recent_incident_severity_score" in FEATURE_COLUMNS


def test_clean_and_prepare_features():
    raw_df = pd.DataFrame([{
        "rainfall_last_24h": "75.5",
        "slope": 32.0,
        "severe_weather_flag": True
    }])
    cleaned = clean_and_prepare_features(raw_df)
    assert cleaned.shape[1] == len(FEATURE_COLUMNS)
    assert cleaned["severe_weather_flag"].iloc[0] == 1
    assert cleaned["rainfall_last_24h"].iloc[0] == 75.5


def test_predictor_loaded_and_predicts():
    assert predictor.is_ready is True
    sample_input = RoadDisruptionInput(
        road_id=2,
        rainfall_last_24h=70.0,
        slope=35.0,
        severe_weather_flag=True,
        historical_landslide_count=5,
        recent_incident_count=1,
        recent_incident_severity_score=75.0,
        current_risk_score=65.0
    )
    res = predictor.predict(sample_input)
    assert res.road_id == 2
    assert 0.0 <= res.disruption_probability <= 1.0
    assert res.prediction_window_hours == 24
    assert len(res.top_factors) >= 1
