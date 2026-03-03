# FastAPI Backend Project

## Overview
This is a FastAPI backend service with PostgreSQL.

## Code Style
- Use type hints everywhere
- Pydantic models for all request/response schemas
- Dependency injection for database sessions
- Async endpoints where possible

## Testing
- Run tests with: `pytest -v`
- Minimum 80% coverage required
- Use fixtures for database setup

## Common Commands
```bash
uvicorn app.main:app --reload  # Development
alembic upgrade head           # Migrations
pytest --cov=app              # Tests with coverage
```

## Key Files
- `app/main.py` - FastAPI app entry
- `app/api/` - Route handlers
- `app/models/` - SQLAlchemy models
- `app/schemas/` - Pydantic schemas
