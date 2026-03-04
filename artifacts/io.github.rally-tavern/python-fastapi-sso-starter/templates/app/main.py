"""{{project_name}} — FastAPI application with SSO authentication."""

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.database import engine, Base
from app.routes import auth, health


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="{{project_name}}", lifespan=lifespan)

app.include_router(health.router)
app.include_router(auth.router, prefix="/auth", tags=["auth"])
