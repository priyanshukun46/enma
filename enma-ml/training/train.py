import os
import sys
import json
import datetime
from pathlib import Path

# Ensure training dir is in sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent))

import joblib
import pandas as pd
import numpy as np

from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.preprocessing import StandardScaler
from sklearn.pipeline import Pipeline

from feature_engineering import (
    FEATURE_COLUMNS,
    TARGET_COLUMN,
    clean_and_prepare_features
)
from generate_dataset import generate_synthetic_ner_dataset
from evaluate import validate_dataset_quality, evaluate_model_performance

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_PATH = BASE_DIR / "data" / "raw" / "ner_road_disruption_dataset.csv"
MODELS_DIR = BASE_DIR / "models"
MODELS_DIR.mkdir(parents=True, exist_ok=True)
MODEL_OUT = MODELS_DIR / "disruption_model.joblib"
METADATA_OUT = MODELS_DIR / "metadata.json"


def train_models():
    print("=" * 60)
    print("🚀 ResQWay ML ROAD DISRUPTION PREDICTION — TRAINING PIPELINE")
    print("=" * 60)

    # 1. Dataset Loading or Generation
    if not DATA_PATH.exists():
        print(f"Dataset not found at {DATA_PATH}. Generating synthetic NER dataset...")
        df = generate_synthetic_ner_dataset(n_samples=6000, seed=42)
    else:
        print(f"Loading existing dataset from {DATA_PATH}...")
        df = pd.read_csv(DATA_PATH)

    # 2. Data Quality Validation
    print("\n[Step 1] Validating Dataset Quality...")
    quality_report = validate_dataset_quality(df, target_col=TARGET_COLUMN)
    print(json.dumps(quality_report, indent=2))

    # 3. Feature Preparation
    print("\n[Step 2] Processing Features and Target...")
    X = clean_and_prepare_features(df)
    y = df[TARGET_COLUMN].astype(int)

    # 4. Stratified Train/Test Split (80% Train, 20% Test)
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.20, random_state=42, stratify=y
    )
    print(f"Train samples: {len(X_train)} | Test samples: {len(X_test)}")
    print(f"Train positive rate: {y_train.mean()*100:.1f}% | Test positive rate: {y_test.mean()*100:.1f}%")

    # 5. Define Candidate Models
    candidates = {
        "LogisticRegression": Pipeline([
            ("scaler", StandardScaler()),
            ("classifier", LogisticRegression(class_weight="balanced", max_iter=1000, random_state=42))
        ]),
        "RandomForestClassifier": RandomForestClassifier(
            n_estimators=150,
            max_depth=12,
            min_samples_split=4,
            class_weight="balanced",
            random_state=42,
            n_jobs=-1
        ),
        "GradientBoostingClassifier": GradientBoostingClassifier(
            n_estimators=120,
            learning_rate=0.08,
            max_depth=5,
            random_state=42
        )
    }

    # 6. Train and Evaluate Each Candidate
    print("\n[Step 3] Training and Evaluating Candidate Models...")
    results = {}

    for name, model in candidates.items():
        print(f"  Training {name}...")
        model.fit(X_train, y_train)
        metrics = evaluate_model_performance(model, X_test, y_test)
        results[name] = {
            "model": model,
            "metrics": metrics
        }
        print(f"    ✓ Accuracy: {metrics['accuracy']:.4f} | Recall: {metrics['recall']:.4f} | F1: {metrics['f1_score']:.4f} | ROC-AUC: {metrics['roc_auc']:.4f}")

    # 7. Model Selection (Prioritize Recall & F1 for safety/disaster response logistics)
    # Missing a road disruption in disaster response is far more critical than a false alarm.
    best_name = max(
        results.keys(),
        key=lambda k: (results[k]["metrics"]["recall"] * 0.5 + results[k]["metrics"]["f1_score"] * 0.3 + results[k]["metrics"]["roc_auc"] * 0.2)
    )
    best_model = results[best_name]["model"]
    best_metrics = results[best_name]["metrics"]

    print("\n" + "=" * 60)
    print(f"🏆 SELECTED CHAMPION MODEL: {best_name}")
    print(f"Reasoning: Highest weighted balance of Recall ({best_metrics['recall']:.4f}) and F1 Score ({best_metrics['f1_score']:.4f}) to minimize missed road hazards.")
    print("=" * 60)

    # 8. Feature Importance Analysis
    feature_importances = {}
    if hasattr(best_model, "feature_importances_"):
        for feat, imp in zip(FEATURE_COLUMNS, best_model.feature_importances_):
            feature_importances[feat] = round(float(imp), 4)
    elif hasattr(best_model.named_steps.get("classifier", None), "coef_"):
        coefs = np.abs(best_model.named_steps["classifier"].coef_[0])
        for feat, imp in zip(FEATURE_COLUMNS, coefs):
            feature_importances[feat] = round(float(imp), 4)

    # 9. Save Model Artifact and Versioned Metadata
    print(f"\n[Step 4] Persisting Champion Model to {MODEL_OUT}...")
    joblib.dump(best_model, MODEL_OUT)

    metadata = {
        "model_version": "1.0.0",
        "trained_at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "algorithm": best_name,
        "features": FEATURE_COLUMNS,
        "target": TARGET_COLUMN,
        "prediction_window_hours": 24,
        "dataset_info": {
            "total_records": len(df),
            "train_samples": len(X_train),
            "test_samples": len(X_test),
            "positive_class_ratio": round(float(y.mean()), 4),
            "dataset_type": "Synthetic NER Disaster Logistics Simulation Dataset"
        },
        "all_model_benchmarks": {
            k: v["metrics"] for k, v in results.items()
        },
        "selected_metrics": best_metrics,
        "feature_importances": dict(sorted(feature_importances.items(), key=lambda x: x[1], reverse=True)),
        "selection_rationale": "Prioritized high recall (minimizing false negatives during landslides/floods) combined with strong ROC-AUC discrimination."
    }

    with open(METADATA_OUT, "w") as f:
        json.dump(metadata, f, indent=2)

    print(f"✓ Metadata saved to {METADATA_OUT}")
    print("\nTraining completed successfully! Model is ready for FastAPI inference.")
    return metadata


if __name__ == "__main__":
    train_models()
