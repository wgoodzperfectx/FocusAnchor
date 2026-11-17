"""Experimental FastAPI inference and synthetic replay; never executes actions."""

from __future__ import annotations

from functools import lru_cache
import json
from pathlib import Path
from typing import Literal

from fastapi import FastAPI, Query
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
import joblib
import numpy as np
import pandas as pd
from pydantic import BaseModel, ConfigDict, Field


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_VERSION = "0.1-replay"
M1_PATH = ROOT / "models/m1_replay_rf60.joblib"
M2_PATH = ROOT / "models/m2_receptivity_xgb.joblib"
FIXTURES_PATH = ROOT / "service/replay_fixtures.json"

app = FastAPI(title="FocusAnchor Modeling Replay", version=SCHEMA_VERSION,
              description="Research replay only. Responses are evidence/candidates; no Agent or device action.")


@app.exception_handler(RequestValidationError)
async def invalid_request_handler(_request, exc: RequestValidationError) -> JSONResponse:
    paths = ["/".join(str(part) for part in error["loc"]) for error in exc.errors()]
    return JSONResponse(status_code=422, content={"code": "INVALID_REQUEST", "field_paths": paths})


class StrictModel(BaseModel):
    model_config = ConfigDict(extra="forbid")


class PhysioWindow(StrictModel):
    schema_version: Literal["0.1-replay"]
    source: Literal["replay"]
    timestamp_ms: int = Field(ge=0)
    window_seconds: int
    signal_quality: Literal["good", "degraded", "invalid", "unknown"]
    features: dict[str, float]


class TaskContext(StrictModel):
    task_status: Literal["none", "pending", "active", "paused"]
    user_requested_help: bool = False


class M2CandidateRequest(StrictModel):
    schema_version: Literal["0.1-replay"]
    source: Literal["replay"]
    timestamp_ms: int = Field(ge=0)
    context_quality: Literal["good", "degraded", "invalid", "unknown"]
    features: dict[str, float]
    task_context: TaskContext


def unknown_m1(req: PhysioWindow, reason: str, ood: bool = False) -> dict:
    return {"schema_version": SCHEMA_VERSION, "model_version": "wesad_rf60_replay_001",
            "timestamp_ms": req.timestamp_ms, "source": "replay", "physio_state": "unknown",
            "stress_probability": None, "signal_quality": req.signal_quality,
            "calibration_status": "uncalibrated", "uncertainty": None,
            "ood": ood, "reason_codes": [reason], "executable": False}


def abstain_m2(req: M2CandidateRequest, reason: str, score: float | None = None,
               uncertainty: float | None = None, ood: bool = False) -> dict:
    return {"schema_version": SCHEMA_VERSION, "policy_version": "mpud_receptivity_replay_001",
            "timestamp_ms": req.timestamp_ms, "source": "replay", "action": "abstain",
            "need_score": None, "receptivity_score": score, "uncertainty": uncertainty,
            "ood": ood, "reason_codes": [reason], "requires_consent": True,
            "gated": False, "executable": False}


@lru_cache(maxsize=2)
def load_bundle(path: str) -> dict | None:
    try:
        return joblib.load(path)
    except Exception:
        return None


def feature_vector(features: dict[str, float], bundle: dict) -> tuple[np.ndarray | None, str | None]:
    names = bundle["features"]
    if set(features) != set(names):
        return None, "FEATURE_SET_MISMATCH"
    values = np.array([features[name] for name in names], dtype=float)
    if not np.isfinite(values).all():
        return None, "NONFINITE_FEATURE"
    bounds = bundle["feature_bounds_1_99"]
    if any(value < bounds[name][0] or value > bounds[name][1]
           for name, value in zip(names, values)):
        return None, "OUT_OF_DISTRIBUTION"
    return values.reshape(1, -1), None


@app.get("/v1/health")
def health() -> dict:
    return {"status": "replay_only", "schema_version": SCHEMA_VERSION,
            "m1_artifact_available": M1_PATH.is_file(),
            "m2_artifact_available": M2_PATH.is_file(),
            "agent_connected": False, "device_connected": False}


@app.post("/v1/m1/estimate")
def estimate_m1(req: PhysioWindow) -> dict:
    if req.signal_quality != "good":
        return unknown_m1(req, "BAD_SIGNAL")
    if req.window_seconds != 60:
        return unknown_m1(req, "UNSUPPORTED_WINDOW")
    bundle = load_bundle(str(M1_PATH))
    if bundle is None:
        return unknown_m1(req, "MODEL_UNAVAILABLE")
    vector, error = feature_vector(req.features, bundle)
    if error:
        return unknown_m1(req, error, ood=error == "OUT_OF_DISTRIBUTION")
    assert vector is not None
    try:
        probability = float(bundle["model"].predict_proba(pd.DataFrame(vector, columns=bundle["features"]))[0, 1])
    except Exception:
        return unknown_m1(req, "MODEL_ERROR")
    return {"schema_version": SCHEMA_VERSION, "model_version": "wesad_rf60_replay_001",
            "timestamp_ms": req.timestamp_ms, "source": "replay", "physio_state": "unknown",
            "stress_probability": probability, "signal_quality": req.signal_quality,
            "calibration_status": "uncalibrated", "uncertainty": 1 - abs(2 * probability - 1),
            "ood": False, "reason_codes": ["REPLAY_UNCALIBRATED"], "executable": False}


@app.post("/v1/m2/decision-candidate")
def estimate_m2(req: M2CandidateRequest) -> dict:
    if req.context_quality != "good":
        return abstain_m2(req, "BAD_CONTEXT")
    bundle = load_bundle(str(M2_PATH))
    if bundle is None:
        return abstain_m2(req, "MODEL_UNAVAILABLE")
    vector, error = feature_vector(req.features, bundle)
    if error:
        return abstain_m2(req, error, ood=error == "OUT_OF_DISTRIBUTION")
    assert vector is not None
    try:
        raw = float(bundle["model"].predict_proba(vector)[0, 1])
        selected = bundle["selected_probability_by_calibration_brier"]
        score = float(bundle["calibration"].predict_proba([[raw]])[0, 1]) if selected == "platt" else raw
    except Exception:
        return abstain_m2(req, "MODEL_ERROR")
    uncertainty = 1 - abs(2 * score - 1)
    if req.task_context.task_status == "none":
        return abstain_m2(req, "NO_TASK", score, uncertainty)
    if not req.task_context.user_requested_help:
        return abstain_m2(req, "NEED_UNOBSERVED", score, uncertainty)
    if uncertainty > 0.5:
        return abstain_m2(req, "UNCERTAIN_RECEPTIVITY", score, uncertainty)
    action = "ask" if score >= 0.5 else "defer"
    return {"schema_version": SCHEMA_VERSION, "policy_version": "mpud_receptivity_replay_001",
            "timestamp_ms": req.timestamp_ms, "source": "replay", "action": action,
            "need_score": None, "receptivity_score": score, "uncertainty": uncertainty,
            "ood": False, "reason_codes": ["USER_REQUEST_AND_ESM_CLICK_PROXY"],
            "requires_consent": True, "gated": False, "executable": False}


@app.get("/v1/replay/next")
def replay_next(cursor: int = Query(default=0, ge=0)) -> dict:
    fixtures = json.loads(FIXTURES_PATH.read_text(encoding="utf-8"))
    index = cursor % len(fixtures)
    return {"schema_version": SCHEMA_VERSION, "source": "synthetic_fixture",
            "cursor": index, "next_cursor": index + 1, "fixture": fixtures[index]}
