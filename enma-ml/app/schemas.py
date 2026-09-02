from typing import List, Optional, Any, Dict
from pydantic import BaseModel, Field


class PredictionFactor(BaseModel):
    feature: str
    importance: str
    label: str
    value: float
    description: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_version: str
    algorithm: Optional[str] = None
    prediction_window_hours: int = 24


class RoadDisruptionInput(BaseModel):
    road_id: int
    rainfall_last_1h: float = Field(default=0.0, ge=0.0, le=500.0, description="Rainfall in mm during the last 1 hour")
    rainfall_last_24h: float = Field(default=0.0, ge=0.0, le=1000.0, description="Rainfall in mm during the last 24 hours")
    forecast_rainfall_6h: float = Field(default=0.0, ge=0.0, le=500.0, description="Forecast rainfall in mm for next 6 hours")
    forecast_rainfall_12h: float = Field(default=0.0, ge=0.0, le=800.0, description="Forecast rainfall in mm for next 12 hours")
    forecast_rainfall_24h: float = Field(default=0.0, ge=0.0, le=1200.0, description="Forecast rainfall in mm for next 24 hours")
    severe_weather_flag: bool = Field(default=False, description="Whether severe meteorological warning is active")
    historical_incident_count: int = Field(default=0, ge=0, description="Historical hazard incidents recorded on corridor")
    historical_landslide_count: int = Field(default=0, ge=0, description="Historical landslide events recorded")
    historical_flood_count: int = Field(default=0, ge=0, description="Historical flood/inundation events")
    previous_road_closures: int = Field(default=0, ge=0, description="Past recorded closures")
    road_condition_score: float = Field(default=50.0, ge=0.0, le=100.0, description="Pavement degradation index (100 = critical failure, 0 = excellent)")
    elevation: float = Field(default=500.0, ge=0.0, le=7000.0, description="Corridor elevation in meters")
    slope: float = Field(default=15.0, ge=0.0, le=90.0, description="Terrain slope gradient in degrees")
    recent_incident_count: int = Field(default=0, ge=0, description="Active incidents logged within proximity in last 48h")
    recent_incident_severity_score: float = Field(default=0.0, ge=0.0, le=100.0, description="Peak severity score of recent nearby incidents")
    current_risk_score: float = Field(default=20.0, ge=0.0, le=100.0, description="Hybrid rule-based baseline risk score")


class BatchPredictionRequest(BaseModel):
    roads: List[RoadDisruptionInput]


class RoadDisruptionPredictionResponse(BaseModel):
    road_id: int
    disruption_probability: float
    risk_level: str
    prediction_window_hours: int
    model_version: str
    top_factors: List[PredictionFactor]
    narrative_explanation: str
    model_metadata: Dict[str, Any] = {}
