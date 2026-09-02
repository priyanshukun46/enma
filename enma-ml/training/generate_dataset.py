import os
import random
from pathlib import Path
import numpy as np
import pandas as pd

DATA_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
DATA_DIR.mkdir(parents=True, exist_ok=True)
OUTPUT_CSV = DATA_DIR / "ner_road_disruption_dataset.csv"


def generate_synthetic_ner_dataset(n_samples: int = 6000, seed: int = 42) -> pd.DataFrame:
    """
    Generates a realistic, reproducible synthetic dataset modeling North Eastern Region (NER)
    road disruption conditions for training and benchmarking the ENMA ML model.

    NOTE: Clearly marked as SYNTHETIC DEMONSTRATION DATASET for development and testing.
    """
    np.random.seed(seed)
    random.seed(seed)

    records = []

    # Road profiles representing North East India corridors
    road_corridors = [
        {"id": 1, "name": "NH-27 Assam Arterial", "state": "Assam", "elev_base": 120, "slope_base": 8, "hazard_base": 0.10},
        {"id": 2, "name": "NH-13 Trans-Arunachal", "state": "Arunachal Pradesh", "elev_base": 1850, "slope_base": 34, "hazard_base": 0.35},
        {"id": 3, "name": "NH-229 Sela Pass", "state": "Arunachal Pradesh", "elev_base": 3850, "slope_base": 42, "hazard_base": 0.50},
        {"id": 4, "name": "NH-06 Meghalaya Corridor", "state": "Meghalaya", "elev_base": 1450, "slope_base": 24, "hazard_base": 0.25},
        {"id": 5, "name": "SH-05 Cherrapunjee Highland", "state": "Meghalaya", "elev_base": 1300, "slope_base": 36, "hazard_base": 0.45},
        {"id": 6, "name": "NH-02 Imphal Lifeline", "state": "Manipur", "elev_base": 980, "slope_base": 22, "hazard_base": 0.25},
        {"id": 7, "name": "NH-102 Moreh Border", "state": "Manipur", "elev_base": 650, "slope_base": 16, "hazard_base": 0.15},
        {"id": 8, "name": "NH-29 Kohima Mountain", "state": "Nagaland", "elev_base": 1520, "slope_base": 32, "hazard_base": 0.35},
        {"id": 9, "name": "NH-54 Aizawl Ridge", "state": "Mizoram", "elev_base": 1250, "slope_base": 30, "hazard_base": 0.30},
        {"id": 10, "name": "NH-08 Tripura Central", "state": "Tripura", "elev_base": 80, "slope_base": 9, "hazard_base": 0.10},
        {"id": 11, "name": "NH-10 Teesta River Canyon", "state": "Sikkim", "elev_base": 1720, "slope_base": 44, "hazard_base": 0.55},
        {"id": 12, "name": "NH-27S Haflong Hill", "state": "Assam", "elev_base": 850, "slope_base": 28, "hazard_base": 0.30},
    ]

    for _ in range(n_samples):
        road = random.choice(road_corridors)

        # Weather simulation (monsoon seasonality)
        is_monsoon = random.random() < 0.60
        if is_monsoon:
            rainfall_24h = np.random.exponential(scale=55.0)
            rainfall_1h = min(rainfall_24h * np.random.uniform(0.1, 0.4), 120.0)
            forecast_24h = np.random.exponential(scale=65.0)
            forecast_12h = forecast_24h * np.random.uniform(0.4, 0.7)
            forecast_6h = forecast_12h * np.random.uniform(0.4, 0.7)
            severe_weather_flag = rainfall_24h > 80.0 or forecast_24h > 90.0 or random.random() < 0.20
        else:
            rainfall_24h = np.random.exponential(scale=8.0)
            rainfall_1h = min(rainfall_24h * np.random.uniform(0.1, 0.3), 20.0)
            forecast_24h = np.random.exponential(scale=10.0)
            forecast_12h = forecast_24h * 0.5
            forecast_6h = forecast_12h * 0.5
            severe_weather_flag = random.random() < 0.03

        # Historical profile
        hist_incidents = int(np.random.poisson(lam=road["hazard_base"] * 15))
        hist_landslides = int(min(hist_incidents, np.random.poisson(lam=road["hazard_base"] * 10)))
        hist_floods = int(max(0, hist_incidents - hist_landslides))
        prev_closures = int(np.random.poisson(lam=road["hazard_base"] * 4))

        # Terrain & road condition
        elevation = max(50.0, float(np.random.normal(loc=road["elev_base"], scale=150.0)))
        slope = max(2.0, min(65.0, float(np.random.normal(loc=road["slope_base"], scale=6.0))))
        road_condition_score = max(5.0, min(100.0, float(np.random.normal(loc=40.0 + road["hazard_base"] * 40, scale=18.0))))

        # Real-time incident telemetry
        has_recent = random.random() < (0.15 + (0.35 if is_monsoon else 0.0) + (road["hazard_base"] * 0.25))
        if has_recent:
            recent_count = random.randint(1, 4)
            recent_severity = float(np.random.choice([45.0, 75.0, 95.0], p=[0.4, 0.4, 0.2]))
        else:
            recent_count = 0
            recent_severity = 0.0

        # Baseline rule-based score proxy
        current_risk_score = min(100.0, max(5.0, (
            (min(rainfall_24h, 150) / 150 * 30.0) +
            (min(hist_landslides, 10) / 10 * 20.0) +
            (recent_severity * 0.25) +
            (road_condition_score * 0.15) +
            (min(slope, 50) / 50 * 10.0)
        )))

        # Ground-truth disruption probability formulation (Physical Domain Model)
        # 1. Slope x Rainfall saturation interaction (landslide mechanic)
        saturation_risk = (rainfall_24h / 100.0) * (slope / 35.0) * 0.45

        # 2. Recent critical incident direct obstruction
        incident_impact = (recent_severity / 100.0) * (recent_count / 2.0) * 0.35

        # 3. Pavement failure & structural degradation
        pavement_risk = (road_condition_score / 100.0) * 0.15

        # 4. Severe weather forecast surge
        forecast_surge = (forecast_24h / 120.0) * (1.3 if severe_weather_flag else 0.8) * 0.20

        # Latent logit with noise
        logit = (saturation_risk + incident_impact + pavement_risk + forecast_surge - 0.45) * 3.2
        prob = 1.0 / (1.0 + np.exp(-logit))

        # Binary label with realistic stochasticity
        disrupted = 1 if (random.random() < prob) else 0

        records.append({
            "road_id": road["id"],
            "road_name": road["name"],
            "state": road["state"],
            "rainfall_last_1h": round(rainfall_1h, 1),
            "rainfall_last_24h": round(rainfall_24h, 1),
            "forecast_rainfall_6h": round(forecast_6h, 1),
            "forecast_rainfall_12h": round(forecast_12h, 1),
            "forecast_rainfall_24h": round(forecast_24h, 1),
            "severe_weather_flag": severe_weather_flag,
            "historical_incident_count": hist_incidents,
            "historical_landslide_count": hist_landslides,
            "historical_flood_count": hist_floods,
            "previous_road_closures": prev_closures,
            "road_condition_score": round(road_condition_score, 1),
            "elevation": round(elevation, 1),
            "slope": round(slope, 1),
            "recent_incident_count": recent_count,
            "recent_incident_severity_score": round(recent_severity, 1),
            "current_risk_score": round(current_risk_score, 1),
            "disrupted": disrupted
        })

    df = pd.DataFrame(records)
    df.to_csv(OUTPUT_CSV, index=False)
    print(f"✓ Synthetic NER Road Disruption Dataset created with {len(df)} records at: {OUTPUT_CSV}")
    print(f"  Class balance: {df['disrupted'].mean()*100:.1f}% disrupted ({df['disrupted'].sum()}/{len(df)})")
    return df


if __name__ == "__main__":
    generate_synthetic_ner_dataset()
