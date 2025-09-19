from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
from dotenv import load_dotenv
import os

from app.routers import auth, profiles, habits, hives, activity, contacts, devices
from app.core.config import settings

load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    print(f"🐝 HabitHive API starting on port {settings.PORT}")
    print(f"📱 Test mode: {settings.TEST_MODE}")
    yield
    print("🛑 HabitHive API shutting down")

app = FastAPI(
    title="HabitHive API",
    description="Backend API for HabitHive habit tracking app with social features",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "message": "🐝 Welcome to HabitHive API",
        "status": "buzzing",
        "test_mode": settings.TEST_MODE
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "habithive-api"}

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(profiles.router, prefix="/api/profiles", tags=["profiles"])
app.include_router(habits.router, prefix="/api/habits", tags=["habits"])
app.include_router(hives.router, prefix="/api/hives", tags=["hives"])
app.include_router(activity.router, prefix="/api/activity", tags=["activity"])
app.include_router(contacts.router, prefix="/api/contacts", tags=["contacts"])
app.include_router(devices.router, prefix="/api/devices", tags=["devices"])

if __name__ == "__main__":
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8002,
        reload=True
    )
