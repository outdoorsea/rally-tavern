"""SSO provider configuration using authlib.

Wire this up in main.py after configuring your OAuth credentials.

Usage:
    from app.routes.sso import oauth, google, facebook

    # In your auth callback:
    token = await google.authorize_access_token(request)
    user_info = token.get("userinfo")
"""

from authlib.integrations.starlette_client import OAuth

from app.config import (
    GOOGLE_CLIENT_ID,
    GOOGLE_CLIENT_SECRET,
    FACEBOOK_APP_ID,
    FACEBOOK_APP_SECRET,
)

oauth = OAuth()

# Google OAuth2
if GOOGLE_CLIENT_ID:
    google = oauth.register(
        name="google",
        client_id=GOOGLE_CLIENT_ID,
        client_secret=GOOGLE_CLIENT_SECRET,
        server_metadata_url="https://accounts.google.com/.well-known/openid-configuration",
        client_kwargs={"scope": "openid email profile"},
    )

# Facebook OAuth2
if FACEBOOK_APP_ID:
    facebook = oauth.register(
        name="facebook",
        client_id=FACEBOOK_APP_ID,
        client_secret=FACEBOOK_APP_SECRET,
        access_token_url="https://graph.facebook.com/v18.0/oauth/access_token",
        authorize_url="https://www.facebook.com/v18.0/dialog/oauth",
        api_base_url="https://graph.facebook.com/v18.0/",
        client_kwargs={"scope": "email public_profile"},
    )
