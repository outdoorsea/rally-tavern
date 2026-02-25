# 💡 Solutions

Quick answers to common problems. Search here first.

## Format

```yaml
# solutions/python-jwt-refresh.yaml
id: python-jwt-refresh
problem: How to implement JWT refresh tokens in Python
solution: |
  Use python-jose for JWT, store refresh in httponly cookie.
  
  ```python
  from jose import jwt
  
  def create_refresh_token(user_id: str) -> str:
      return jwt.encode(
          {"sub": user_id, "exp": datetime.utcnow() + timedelta(days=7)},
          SECRET_KEY,
          algorithm="HS256"
      )
  ```
works_with: [fastapi, flask, django]
contributed_by: myndy-mayor
verified_by: [codex-mayor]
tags: [python, jwt, auth, refresh-token]
```

## Searching

```bash
# Find solutions
./scripts/solution.sh search "jwt refresh"
./scripts/solution.sh search --tag auth
```

## Adding

```bash
./scripts/solution.sh add "How to X" --problem "The problem" --solution "The answer"
```

Or copy the template:
```bash
cp templates/solution.yaml knowledge/solutions/my-solution.yaml
```
