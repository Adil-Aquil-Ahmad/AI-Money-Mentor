from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from queue_manager import manager, SYSTEM_STATE, QUEUE, LOGS, enqueue_request
import asyncio

router = APIRouter()

@router.get("/state")
async def get_state():
    """Returns the full current system state block."""
    SYSTEM_STATE["queue_length"] = len(QUEUE)
    return SYSTEM_STATE

@router.get("/queue")
async def get_queue():
    """Returns only the queued and active jobs matrix."""
    return {"queued": QUEUE, "active": SYSTEM_STATE["active_jobs"]}

@router.get("/logs")
async def get_logs():
    """Returns the history of logs."""
    return {"logs": LOGS}
    
@router.post("/simulate")
async def simulate_request(req_type: str = "intelligence", target: str = "Simulated Stock", user_id: str = "TestUser"):
    """Simulates an arbitrary request arriving into the backend queue manually."""
    req_id = await enqueue_request(user_id=user_id, req_type=req_type, stock=target)
    return {"status": "enqueued", "request_id": req_id}

@router.websocket("")
async def websocket_dev_endpoint(websocket: WebSocket):
    """
    WebSocket endpoint for the real-time queue developer dashboard.
    Connecting sends an instant state payload down the pipe.
    """
    await manager.connect(websocket)
    try:
        while True:
            # Keep connections alive by listening for potential ping frames
            # or frontend signals.
            data = await websocket.receive_text()
            if data and "simulate" in data.lower():
                await enqueue_request(user_id="DashboardUser", req_type="chat", query=data)
    except WebSocketDisconnect:
        manager.disconnect(websocket)
