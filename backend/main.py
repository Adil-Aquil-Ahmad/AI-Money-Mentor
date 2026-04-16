"""
# Chrysos — FastAPI Backend (v2 — Auth + Memory)
Main application entry point with CORS, routers, and DB initialization.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from database import init_db
from routers import chat, profile, health_score, fire, whatif, auth, memory, investments, intelligence
from routers import greeting as greeting_router
from routers import alerts as alerts_router
from routers import dev
from worker import start_scheduler
from queue_manager import queue_processor_loop
import asyncio

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Initialize database on startup."""
    await init_db()
    start_scheduler()
    asyncio.create_task(queue_processor_loop())
    yield


app = FastAPI(title="Chrysos", version="2.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register API routers
app.include_router(auth.router, prefix="/api", tags=["Auth"])
app.include_router(chat.router, prefix="/api", tags=["Chat"])
app.include_router(profile.router, prefix="/api", tags=["Profile"])
app.include_router(memory.router, prefix="/api", tags=["Memory"])
app.include_router(investments.router, prefix="/api", tags=["Investments"])
app.include_router(health_score.router, prefix="/api", tags=["Health Score"])
app.include_router(fire.router, prefix="/api", tags=["FIRE Calculator"])
app.include_router(whatif.router, prefix="/api", tags=["What-If Simulator"])
app.include_router(intelligence.router, prefix="/api/intelligence", tags=["Finance Intelligence"])
app.include_router(alerts_router.router, prefix="/api/alerts", tags=["Alerts"])
app.include_router(dev.router, prefix="/api/dev", tags=["Dev Dashboard"])
app.include_router(greeting_router.router, prefix="", tags=["Greeting"])



@app.get("/api/ping")
async def ping():
    return {"status": "ok", "app": "Chrysos", "version": "2.0.0"}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=False)
