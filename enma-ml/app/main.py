import logging
from typing import List
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware

from .config import PREDICTION_WINDOW_HOURS
from .schemas import (
    HealthResponse,
    RoadDisruptionInput,
    RoadDisruptionPredictionResponse,
    BatchPredictionRequest
)
from .predictor import predictor

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("enma.ml.api")

app = FastAPI(
    title="ENMA AI — Road Disruption Prediction ML Service",
    description="Machine Learning Disruption Probability and Explainability Service for North East India Logistics Corridors",
    version="1.0.0",
)

# Allow local Rails app integration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse, tags=["Health"])
def health_check():
    """
    Returns the operational status, loaded model artifact, and version.
    """
    return HealthResponse(
        status="healthy" if predictor.is_ready else "degraded",
        model_loaded=predictor.is_ready,
        model_version=predictor.metadata.get("model_version", "unknown"),
        algorithm=predictor.metadata.get("algorithm", "None"),
        prediction_window_hours=PREDICTION_WINDOW_HOURS
    )


@app.post("/predict", response_model=RoadDisruptionPredictionResponse, tags=["Inference"])
def predict_road_disruption(input_data: RoadDisruptionInput):
    """
    Predicts the probability of road corridor disruption within the next 24 hours
    along with explainable primary risk factors.
    """
    if not predictor.is_ready:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ML Disruption Model is not loaded on server."
        )

    try:
        response = predictor.predict(input_data)
        return response
    except Exception as e:
        logger.error(f"Prediction error for road_id {input_data.road_id}: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Inference execution failed: {str(e)}"
        )


@app.post("/predict/batch", response_model=List[RoadDisruptionPredictionResponse], tags=["Inference"])
def predict_batch(request: BatchPredictionRequest):
    """
    Batch prediction endpoint for multi-corridor network analysis.
    """
    if not predictor.is_ready:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="ML Disruption Model is not loaded on server."
        )

    results = []
    for road_input in request.roads:
        results.append(predictor.predict(road_input))
    return results


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
