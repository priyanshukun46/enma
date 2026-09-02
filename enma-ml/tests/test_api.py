import pytest
from fastapi.testclient import TestClient
import sys
from pathlib import Path

# Add app parent to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.main import app

client = TestClient(app)


def test_health_endpoint():
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
    assert data["model_loaded"] is True
    assert "model_version" in data


def test_predict_endpoint_valid():
    payload = {
        "road_id": 3,
        "rainfall_last_1h": 15.0,
        "rainfall_last_24h": 85.0,
        "forecast_rainfall_6h": 25.0,
        "forecast_rainfall_12h": 45.0,
        "forecast_rainfall_24h": 90.0,
        "severe_weather_flag": True,
        "historical_incident_count": 12,
        "historical_landslide_count": 7,
        "historical_flood_count": 2,
        "previous_road_closures": 4,
        "road_condition_score": 75.0,
        "elevation": 3850.0,
        "slope": 42.0,
        "recent_incident_count": 2,
        "recent_incident_severity_score": 95.0,
        "current_risk_score": 85.0
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["road_id"] == 3
    assert 0.0 <= data["disruption_probability"] <= 1.0
    assert data["risk_level"] in ["low", "moderate", "high", "critical"]
    assert data["prediction_window_hours"] == 24
    assert len(data["top_factors"]) > 0
    assert "narrative_explanation" in data


def test_predict_endpoint_nominal_conditions():
    payload = {
        "road_id": 10,
        "rainfall_last_1h": 0.0,
        "rainfall_last_24h": 2.0,
        "forecast_rainfall_6h": 0.0,
        "forecast_rainfall_12h": 0.0,
        "forecast_rainfall_24h": 5.0,
        "severe_weather_flag": False,
        "historical_incident_count": 0,
        "historical_landslide_count": 0,
        "historical_flood_count": 0,
        "previous_road_closures": 0,
        "road_condition_score": 10.0,
        "elevation": 80.0,
        "slope": 5.0,
        "recent_incident_count": 0,
        "recent_incident_severity_score": 0.0,
        "current_risk_score": 15.0
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["disruption_probability"] < 0.50
    assert data["risk_level"] in ["low", "moderate"]


def test_predict_invalid_input_validation():
    # Negative rainfall
    payload = {
        "road_id": 1,
        "rainfall_last_24h": -50.0
    }
    response = client.post("/predict", json=payload)
    assert response.status_code == 422  # Pydantic validation error
