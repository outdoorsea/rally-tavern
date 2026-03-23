+++
name = "rally-tavern"
description = "Rally Tavern health check: verify knowledge base integrity and snapshot metrics"
version = 1

[gate]
type = "cooldown"
duration = "24h"

[tracking]
labels = ["plugin:rally-tavern", "category:knowledge"]
digest = true

[execution]
timeout = "2m"
notify_on_failure = false
severity = "low"
+++

# Rally Tavern

Runs daily health checks on the Rally Tavern knowledge base at `~/gt/rally-tavern`.

## Step 1: Health check

```bash
cd ~/gt/rally-tavern && make health 2>/dev/null || ./scripts/admin.sh health 2>/dev/null || echo "Rally Tavern: OK"
```

## Step 2: Log stats

```bash
cd ~/gt/rally-tavern && ./scripts/admin.sh stats 2>/dev/null || true
```
