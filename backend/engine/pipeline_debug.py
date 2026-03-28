"""
Pipeline tracing helpers for end-to-end backend debugging.
"""
import json
import os
from datetime import datetime


TRACE_PATH = os.path.join(os.path.dirname(__file__), "..", "pipeline_trace.log")


def trace_event(stage: str, payload: dict):
    record = {
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "stage": stage,
        "payload": payload,
    }
    try:
        with open(TRACE_PATH, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=True) + "\n")
    except Exception:
        pass
