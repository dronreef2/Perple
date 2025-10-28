#!/usr/bin/env bash
# Script to push feat/scaffold-setup branch and create PR
# This script should be run by someone with push access to the repository

set -euo pipefail

echo "Pushing feat/scaffold-setup branch to origin..."
git push -u origin feat/scaffold-setup

echo "Creating pull request..."
gh pr create \
  --base main \
  --head feat/scaffold-setup \
  --title "feat(scaffold): move scaffold files to branch for review" \
  --body "This PR moves the recently added project scaffold (package structure, Emailnator stub, drivers, CI and docs) into a feature branch for review instead of remaining directly on main. The scaffold commit (10ead07cf9a5e67f00b32b03195c4a2b3879cc4c) contains initial files:
- pyproject.toml
- README.md
- .gitignore
- LICENSE
- requirements-dev.txt
- .github/workflows/ci.yml
- docs/emailnator.md
- docs/cookie_extraction.md
- perplexity/__init__.py
- perplexity/client.py
- perplexity/integrations/emailnator.py
- perplexity/driver.py
- perplexity_async/__init__.py
- perplexity_async/async_client.py
- create_scaffold_and_push.sh

This PR was created to allow review, add tests, and iterate before merging into main.

Checklist for reviewers:
- [ ] Confirm files and licensing metadata
- [ ] Run tests (pytest) in CI
- [ ] Verify Playwright installation step in CI
- [ ] Ensure no credentials or secrets were committed
- [ ] Update pyproject author and LICENSE text if required

Branch created from commit: 10ead07cf9a5e67f00b32b03195c4a2b3879cc4c"

echo "Done!"
