from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
import os
import time

app = FastAPI(title="CleverTap Event Ingestion Service")

START_TIME = time.time()


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/ready")
def ready():
    # Add any dependency checks here (Kafka, DB, etc.)
    return {"status": "ready"}


@app.get("/metrics/info")
def info():
    return {
        "service": "event-ingestion",
        "version": os.getenv("APP_VERSION", "unknown"),
        "uptime_seconds": int(time.time() - START_TIME),
        "region": os.getenv("AWS_REGION", "unknown"),
        "environment": os.getenv("APP_ENV", "unknown"),
    }


@app.post("/ingest")
def ingest_event(event: dict):
    if not event.get("account_id") or not event.get("event_name"):
        raise HTTPException(status_code=400, detail="account_id and event_name are required")

    # Placeholder — real impl would publish to Kafka
    return {"status": "accepted", "event_name": event["event_name"]}
