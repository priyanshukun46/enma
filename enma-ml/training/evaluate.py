from typing import Dict, Any
import numpy as np
import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    precision_score,
    recall_score,
    f1_score,
    roc_auc_score,
    confusion_matrix,
    classification_report
)


def validate_dataset_quality(df: pd.DataFrame, target_col: str = "disrupted") -> Dict[str, Any]:
    """
    Performs data quality checks and returns a summary report.
    """
    total_records = len(df)
    missing_count = df.isnull().sum().sum()
    missing_pct = round((missing_count / (total_records * df.shape[1])) * 100.0, 2)
    duplicates = int(df.duplicated().sum())

    pos_count = int(df[target_col].sum()) if target_col in df.columns else 0
    neg_count = total_records - pos_count
    pos_pct = round((pos_count / total_records) * 100.0, 2) if total_records > 0 else 0.0

    report = {
        "total_records": total_records,
        "missing_values_count": int(missing_count),
        "missing_values_pct": missing_pct,
        "duplicate_rows": duplicates,
        "target_distribution": {
            "disrupted (1)": pos_count,
            "not_disrupted (0)": neg_count,
            "positive_class_pct": pos_pct,
        },
        "quality_passed": (missing_pct < 5.0 and duplicates == 0 and total_records >= 500),
    }
    return report


def evaluate_model_performance(model, X_test, y_test) -> Dict[str, Any]:
    """
    Calculates genuine evaluation metrics on the test dataset.
    """
    y_pred = model.predict(X_test)
    y_prob = model.predict_proba(X_test)[:, 1] if hasattr(model, "predict_proba") else y_pred

    acc = float(accuracy_score(y_test, y_pred))
    prec = float(precision_score(y_test, y_pred, zero_division=0))
    rec = float(recall_score(y_test, y_pred, zero_division=0))
    f1 = float(f1_score(y_test, y_pred, zero_division=0))
    
    try:
        roc = float(roc_auc_score(y_test, y_prob))
    except Exception:
        roc = 0.0

    cm = confusion_matrix(y_test, y_pred).tolist()

    return {
        "accuracy": round(acc, 4),
        "precision": round(prec, 4),
        "recall": round(rec, 4),
        "f1_score": round(f1, 4),
        "roc_auc": round(roc, 4),
        "confusion_matrix": cm,
    }
