import asyncio
import uuid
import time
import json
import logging
from typing import List, Dict, Any

# Global State Dictionary maintaining real-time metrics
SYSTEM_STATE = {
    "active_users": 0,
    "queue_length": 0,
    "active_jobs": [],
    "recent_logs": [],
    "queued_jobs": []
}

QUEUE: List[Dict[str, Any]] = []
ACTIVE_JOBS: List[Dict[str, Any]] = []
LOGS: List[Dict[str, Any]] = []
CONNECTIONS: List[Any] = []

MAX_ACTIVE_JOBS = 2
MAX_LOGS = 50

async def broadcast_state():
    """Builds and broadcasts the latest SYSTEM_STATE via websockets."""
    if not CONNECTIONS:
        return
        
    SYSTEM_STATE["queue_length"] = len(QUEUE)
    SYSTEM_STATE["active_jobs"] = ACTIVE_JOBS
    SYSTEM_STATE["queued_jobs"] = [q for q in QUEUE]
    SYSTEM_STATE["recent_logs"] = LOGS[-MAX_LOGS:]
    SYSTEM_STATE["active_users"] = len(CONNECTIONS)
    
    payload = json.dumps(SYSTEM_STATE)
    
    # Broadcast to all connected websocket clients
    disconnected = []
    for conn in CONNECTIONS:
        try:
            await conn.send_text(payload)
        except Exception:
            disconnected.append(conn)
            
    for d in disconnected:
        if d in CONNECTIONS:
            CONNECTIONS.remove(d)

def add_log(event: str, user_id: str = "System", status: str = "info"):
    """Adds a log entry and trims the history."""
    log_entry = {
        "time": time.time(),
        "event": event,
        "user_id": user_id,
        "status": status
    }
    LOGS.append(log_entry)
    if len(LOGS) > MAX_LOGS:
        LOGS.pop(0)
        
    try:
        loop = asyncio.get_running_loop()
        loop.create_task(broadcast_state())
    except RuntimeError:
        pass

async def enqueue_request(user_id: str, req_type: str, stock: str = None, query: str = None) -> str:
    """Adds a new request to the global processing queue."""
    req_id = str(uuid.uuid4())
    req_obj = {
        "request_id": req_id,
        "user_id": user_id,
        "type": req_type,
        "status": "queued",
        "timestamp": time.time(),
        "stock": stock,
        "query": query,
    }
    QUEUE.append(req_obj)
    
    desc = f"query" if req_type == "chat" else "signal" if req_type == "alert" else "intelligence"
    target = stock or query or "system"
    add_log(f"Queued {req_type} request for {target}", user_id, "info")
    
    # Trigger UI update
    await broadcast_state()
    return req_id

async def queue_processor_loop():
    """Background worker loops to process queued tasks sequentially."""
    logging.getLogger("uvicorn").info("Starting Demo Queue Processor Loop...")
    add_log("System Queue Processor initialized.", status="info")
    await broadcast_state()
    
    while True:
        # Check if we can pull a job and QUEUE is not empty
        if len(ACTIVE_JOBS) < MAX_ACTIVE_JOBS and len(QUEUE) > 0:
            # Drop from queue -> Push to processing
            req = QUEUE.pop(0)
            req["status"] = "processing"
            ACTIVE_JOBS.append(req)
            
            target = req["stock"] or req["query"] or "system"
            add_log(f"Started processing {req['type']} for {target}", req["user_id"], "info")
            await broadcast_state()
            
            # Spin up process asynchronously to prevent blocking the worker assignment loop
            asyncio.create_task(_process_job(req))
            
        await asyncio.sleep(0.5)

async def _process_job(req: dict):
    """Executes the specific job (simulated with a delay)."""
    # Artificial Delay block for Demo Visibility
    await asyncio.sleep(2.0)
    
    # Complete
    if req in ACTIVE_JOBS:
        ACTIVE_JOBS.remove(req)
        
    req["status"] = "completed"
    
    # Optionally store historically if needed
    target = req["stock"] or req["query"] or "system"
    add_log(f"Completed {req['type']} for {target}", req["user_id"], "info")
    await broadcast_state()

class ConnectionManager:
    """WebSocket routing manager."""
    def __init__(self):
        self.active_connections: List[Any] = []

    async def connect(self, websocket: Any):
        await websocket.accept()
        CONNECTIONS.append(websocket)
        add_log("Developer Dashboard connected", "DEV", "info")
        await broadcast_state()

    def disconnect(self, websocket: Any):
        if websocket in CONNECTIONS:
            CONNECTIONS.remove(websocket)
            add_log("Developer Dashboard disconnected", "DEV", "warning")
            # asyncio.create_task(broadcast_state()) # Optional
            
manager = ConnectionManager()
