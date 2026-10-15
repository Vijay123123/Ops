#!/usr/bin/env bash
# Introduces a FAKE secret + a vulnerable base image/dependencies on a new branch.
set -e
git checkout -b demo/insecure

# 1) Fake secret (built in pieces so this script itself isn't flagged)
PREFIX="ghp_"
BODY="R7xK2mP9qLw4Zt8NvB3cYd6HfJ1sAe5UgXoQ"
cat > app/config.py <<PY
# FAKE credential for demo purposes only
GITHUB_TOKEN = "${PREFIX}${BODY}"
PY

# 2) Vulnerable base image (end-of-life Debian) and old, vulnerable dependencies
sed -i 's#^FROM .*#FROM python:3.8-slim-buster#' Dockerfile
cat > requirements.txt <<REQ
Flask==0.12.2
requests==2.19.0
gunicorn==19.4.5
REQ

git add -A
git commit -m "demo: introduce fake secret and vulnerable image/deps"
echo "Now run: git push -u origin demo/insecure  -> open a Pull Request -> pipeline should FAIL"
