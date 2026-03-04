"""Auth routes: register, login, Google OAuth, Facebook OAuth."""

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, EmailStr
from sqlalchemy.orm import Session

from app.auth import hash_password, verify_password, create_access_token
from app.database import get_db
from app.models import User

router = APIRouter()


# --- Schemas ---


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str | None = None


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


# --- Email/Password ---


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(req: RegisterRequest, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.email == req.email).first()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    user = User(
        email=req.email,
        hashed_password=hash_password(req.password),
        full_name=req.full_name,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    token = create_access_token({"sub": str(user.id)})
    return TokenResponse(access_token=token)


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == req.email).first()
    if not user or not user.hashed_password:
        raise HTTPException(status_code=401, detail="Invalid credentials")
    if not verify_password(req.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    token = create_access_token({"sub": str(user.id)})
    return TokenResponse(access_token=token)


# --- Google OAuth ---


@router.get("/google/login")
def google_login():
    """Redirect to Google OAuth consent screen.

    In production, use authlib's OAuth client to generate the redirect URL.
    This stub shows the endpoint structure.
    """
    # TODO: Implement with authlib OAuth client
    # oauth = OAuth()
    # google = oauth.register("google", ...)
    # return await google.authorize_redirect(request, redirect_uri)
    return {"message": "Configure GOOGLE_CLIENT_ID and implement OAuth flow"}


@router.get("/google/callback")
def google_callback(db: Session = Depends(get_db)):
    """Handle Google OAuth callback.

    Exchange code for token, extract user info, create or link account.
    """
    # TODO: Implement callback handler
    return {"message": "Google OAuth callback — implement with authlib"}


# --- Facebook OAuth ---


@router.get("/facebook/login")
def facebook_login():
    """Redirect to Facebook OAuth consent screen."""
    return {"message": "Configure FACEBOOK_APP_ID and implement OAuth flow"}


@router.get("/facebook/callback")
def facebook_callback(db: Session = Depends(get_db)):
    """Handle Facebook OAuth callback."""
    return {"message": "Facebook OAuth callback — implement with authlib"}
