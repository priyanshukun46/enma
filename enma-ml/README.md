# 🤖 ResQWay ML — Road Disruption Prediction Engine

This standalone microservice provides genuine Machine Learning road disruption predictions and explainability for the **ResQWay** North Eastern Region Logistics Platform.

---

## 🏗 System Architecture

```
  ┌────────────────────────────────────────────────────────┐
  │               ResQWay PLATFORM (Rails)                 │
  │   - Road Network, Incidents, Weather & GIS Database    │
  └───────────────────────────┬────────────────────────────┘
                              │ POST /predict
                              ▼
  ┌────────────────────────────────────────────────────────┐
  │              Python FastAPI ML Service                 │
  │   - Pydantic Input Validation                          │
  │   - Feature Pipeline & Transformation                  │
  │   - Trained Classifier (Logistic / Random Forest / GB) │
  │   - Disruption Probability (0.00 – 1.00)               │
  │   - Explainable Primary Risk Drivers                   │
  └────────────────────────────────────────────────────────┘
```

---

## 📊 Feature Pipeline (16 Canonical Telemetry Features)

| Feature | Category | Unit | Description |
| :--- | :--- | :--- | :--- |
| `rainfall_last_1h` | Weather | mm | Accumulated rainfall in the past 1 hour |
| `rainfall_last_24h` | Weather | mm | Accumulated rainfall in the past 24 hours |
| `forecast_rainfall_6h` | Weather | mm | 6-hour forward precipitation forecast |
| `forecast_rainfall_12h` | Weather | mm | 12-hour forward precipitation forecast |
| `forecast_rainfall_24h` | Weather | mm | 24-hour forward precipitation forecast |
| `severe_weather_flag` | Weather | boolean | Active IMD/meteorological red/orange alert |
| `historical_incident_count` | Historical | count | All-time recorded disruptions on corridor |
| `historical_landslide_count`| Historical | count | Past recorded slope/rockfall failures |
| `historical_flood_count` | Historical | count | Past recorded water overtopping events |
| `previous_road_closures` | Historical | count | Complete historical highway closures |
| `road_condition_score` | Road | score (0-100)| Physical degradation (100 = critical failure) |
| `elevation` | Geographic | meters | Pass / ridge elevation above sea level |
| `slope` | Geographic | degrees | Mountain gradient steepness |
| `recent_incident_count` | Real-Time | count | Active nearby field incidents in last 48h |
| `recent_incident_severity_score`| Real-Time | score (0-100)| Max severity of active field incidents |
| `current_risk_score` | Real-Time | score (0-100)| Rule-based hybrid risk baseline score |

**Target Variable**: `disrupted` (`0` = Accessible, `1` = Road Disrupted / Closed).

---

## 🚦 Disruption Risk Classification Tiers

- **`0.00 – 0.25`**: 🟢 **LOW RISK** — Normal corridor logistics transit.
- **`0.26 – 0.50`**: 🟡 **MODERATE RISK** — Precautionary transport advisory.
- **`0.51 – 0.75`**: 🟠 **HIGH RISK** — Warning: high probability of disruption; detour recommended.
- **`0.76 – 1.00`**: 🔴 **CRITICAL RISK** — Severe disruption expected; emergency closure likely.

---

## 🚀 Quick Start & Running the ML Service

### 1. Setup Virtual Environment & Dependencies
```bash
cd enma-ml
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Train the Model Pipeline
```bash
python training/train.py
```
This performs dataset validation, train/test split, trains candidate models (Logistic Regression, Random Forest, Gradient Boosting), compares evaluation metrics, and persists `models/disruption_model.joblib` and `models/metadata.json`.

### 3. Start the FastAPI Service
```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 4. Run Automated Tests
```bash
pytest tests
```

---

## 📡 API Endpoints

### `GET /health`
Returns service health, loaded model status, and version.

**Response:**
```json
{
  "status": "healthy",
  "model_loaded": true,
  "model_version": "1.0.0",
  "algorithm": "LogisticRegression",
  "prediction_window_hours": 24
}
```

### `POST /predict`
Predicts disruption probability and provides explainable contributing factors.

**Example Request:**
```json
{
  "road_id": 3,
  "rainfall_last_1h": 15.0,
  "rainfall_last_24h": 85.0,
  "forecast_rainfall_6h": 25.0,
  "forecast_rainfall_12h": 45.0,
  "forecast_rainfall_24h": 90.0,
  "severe_weather_flag": true,
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
```

**Example Response:**
```json
{
  "road_id": 3,
  "disruption_probability": 0.824,
  "risk_level": "critical",
  "prediction_window_hours": 24,
  "model_version": "1.0.0",
  "top_factors": [
    {
      "feature": "severe_weather_flag",
      "importance": "high",
      "label": "⚡ Severe Weather Alert",
      "value": 1.0,
      "description": "Active severe meteorological cloudburst/flood warning."
    },
    {
      "feature": "recent_incident_severity_score",
      "importance": "high",
      "label": "🚨 Incident Severity",
      "value": 95.0,
      "description": "Incident Severity exceeds normal threshold (95.0 vs baseline 50.0)."
    },
    {
      "feature": "rainfall_last_24h",
      "importance": "high",
      "label": "🌧 24h Accumulated Rainfall",
      "value": 85.0,
      "description": "24h Accumulated Rainfall exceeds normal threshold (85.0 vs baseline 60.0)."
    }
  ],
  "narrative_explanation": "ML model predicts a 82.4% disruption probability (CRITICAL RISK) within the next 24 hours driven primarily by ⚡ Severe Weather Alert, 🚨 Incident Severity, 🌧 24h Accumulated Rainfall."
}
```
