.PHONY: test validate security health clean help snapshot snapshot-check snapshot-cache

help:
	@echo "Rally Tavern Commands"
	@echo "====================="
	@echo "make test      - Run tests"
	@echo "make validate  - Validate structure"
	@echo "make security  - Security scan"
	@echo "make health    - Health check"
	@echo "make hooks     - Enable git hooks"
	@echo "make snapshot  - Regenerate knowledge snapshot"
	@echo "make clean     - Clean temp files"

test:
	@./scripts/test.sh

validate:
	@./scripts/validate.sh

security:
	@./scripts/security-scan.sh .

health:
	@./scripts/health.sh

hooks:
	@git config core.hooksPath .githooks
	@echo "✓ Git hooks enabled"

snapshot:
	@./scripts/knowledge-snapshot.sh --output knowledge/snapshot.json

snapshot-check:
	@./scripts/knowledge-snapshot.sh --check

snapshot-cache:
	@./scripts/knowledge-snapshot.sh --cache

clean:
	@find . -name "*.tmp" -delete
	@find . -name ".DS_Store" -delete
	@echo "✓ Cleaned"
