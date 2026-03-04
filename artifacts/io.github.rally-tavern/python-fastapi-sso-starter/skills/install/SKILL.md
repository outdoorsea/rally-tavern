# Install: python-fastapi-sso-starter

## Steps

1. Copy all files from `templates/` into your project root
2. Copy `.env.example` to `.env` and fill in your credentials
3. Replace all `{{project_name}}` placeholders with your actual project name
4. Run `pip install -r requirements.txt`
5. Start PostgreSQL: `docker compose up db -d`
6. Initialize the database: `alembic upgrade head` (or let the app create tables on startup)
7. Run the app: `uvicorn app.main:app --reload`
8. Verify: `curl http://localhost:8000/health` should return `{"status": "ok"}`

## Post-Install

- Configure Google OAuth credentials in `.env` for SSO
- Implement the OAuth callback handlers in `app/routes/auth.py`
- Wire up `app/routes/sso.py` OAuth client in the callback endpoints
- Add Alembic migration scripts for schema changes
- Run `pytest` to verify everything works
