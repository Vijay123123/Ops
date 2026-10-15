#!/usr/bin/env bash
# Removes the secret and restores the secure image/dependencies.
set -e
git rm -f app/config.py
sed -i 's#^FROM .*#FROM python:3.12-slim#' Dockerfile
cat > requirements.txt <<REQ
Flask==3.0.3
requests==2.32.3
gunicorn==22.0.0
REQ
git add -A
git commit -m "fix: remove secret, upgrade base image and dependencies"
echo "NOTE: the secret still exists in git history of this branch."
echo "For a clean pass, squash it away: git reset --soft main && git commit -m 'Add feature (clean)'"
