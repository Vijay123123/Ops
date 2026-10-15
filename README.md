<<<<<<< HEAD
# GuardRail: A DevSecOps Pipeline for Automated Secrets and Vulnerability Scanning

GuardRail adds automated security checks to a CI/CD pipeline ("shifting security left").
On every push and pull request, GitHub Actions runs:

- **Gitleaks**: detects hard-coded secrets (API keys, passwords, tokens), including in git history.
- **Trivy**: scans the Docker image and the project dependencies for known CVEs.

If a serious issue is found (a secret, or a fixable CRITICAL/HIGH CVE), the pipeline **fails** and a
branch ruleset **blocks the merge**. Otherwise the build passes and a scan report is saved.
Everything uses free, open-source tools and needs no dedicated infrastructure.

## Repository layout

| Path | Purpose |
|---|---|
| `app.py`, `config.py`, `requirements.txt`, `Dockerfile` | Small containerized Flask app (the clean, secure version) |
| `.github/workflows/guardrail.yml` | The pipeline definition |
| `.gitleaks.toml` | Gitleaks config: ignores the intentionally insecure `demo/` folder |
| `demo/vulnerable/` | Deliberately insecure `config.py`, `requirements.txt`, `Dockerfile` used to demonstrate a failing build |

## How the pipeline works

**Job 1: Gitleaks (secrets detection).** Checks out the full history (`fetch-depth: 0`) and scans every commit.

**Job 2: Trivy (image and dependency CVEs).**
1. Builds the Docker image.
2. *Report steps* (never fail): write image and dependency reports to `reports/`, uploaded as the
   `guardrail-scan-reports` artifact (uploaded even when the build fails).
3. *Gate steps*: fail the build on **CRITICAL or HIGH** CVEs that have a fix available (`--ignore-unfixed`).

Trivy runs from its official Docker image (`aquasec/trivy`) rather than the `trivy-action` GitHub Action
(see Troubleshooting for why).

Because the workflow triggers on both `push` and `pull_request`, each pull request shows each job
**twice** (once per trigger). This is normal: 2 jobs x 2 triggers = 4 checks.

## Setup

1. Create a GitHub repository and push this project to `main`.
2. Make sure `.github/workflows/guardrail.yml` and `.gitleaks.toml` are at the **repository root**
   (not inside an extra folder).
3. Open the **Actions** tab. Both jobs should be green: this is the PASS baseline.

### Important: exclude the demo folder from scanning
The `demo/` folder intentionally contains a fake secret and vulnerable packages, so without an
exclusion the scanners fail the baseline run. This is handled by:

`.gitleaks.toml`
```toml
[extend]
useDefault = true

[allowlist]
description = "Intentionally insecure demo files"
paths = ['''demo/''']
```
and by `--skip-dirs demo` on the Trivy filesystem scans in the workflow.

## Require checks before merging (branch ruleset)

Without a rule, GitHub lets you merge even when checks fail.

1. **Settings -> Rules -> Rulesets -> New branch ruleset**.
2. Set **Enforcement status** to **Active** (a "Disabled" ruleset does nothing).
3. **Target branches**: include the default branch (`main`).
4. Tick **Require status checks to pass** and add both checks by name:
   - `Gitleaks - secrets detection`
   - `Trivy - image and dependency CVEs`
   (they only appear in the search after they have run at least once).
5. Leave the **bypass list** empty, otherwise the repo owner can still merge.
6. Save, then **refresh** the pull request page (Ctrl+F5).

A blocked pull request shows a disabled merge button, or the message
"Merging was blocked due to rule violation errors."

## Demo: fail, then pass

Commands are for **Windows PowerShell**; Linux/macOS equivalents are noted.

### 1. PASS baseline
Push the clean project to `main` and screenshot the green run in the Actions tab.

### 2. Make it FAIL on purpose
```powershell
git checkout -b demo-fail
Copy-Item demo\vulnerable\config.py config.py -Force
Copy-Item demo\vulnerable\requirements.txt requirements.txt -Force
Copy-Item demo\vulnerable\Dockerfile Dockerfile -Force
git add .
git commit -m "demo: introduce fake secret and vulnerable base image"
git push -u origin demo-fail
```
(Linux/macOS/Git Bash: use `cp demo/vulnerable/config.py config.py`, and the same for the other two files.
In PowerShell, `copy /Y` does **not** work; use `Copy-Item ... -Force`.)

Open a pull request from `demo-fail` into `main`. Expected:
- **Gitleaks fails**: a GitHub token is detected in `config.py`.
- **Trivy fails**: HIGH/CRITICAL CVEs from the `python:3.7` base image and the old packages.
- With the ruleset active, **merging is blocked**.

Do **not** merge this pull request; close it.

### 3. Show the fix and PASS
Do not fix on `demo-fail`: Gitleaks scans history and would keep flagging the earlier commit.
Start a fresh branch from `main`, which holds the clean files, and make a small change so a pull request is possible:
```powershell
git checkout main
git checkout -b demo-pass
Add-Content README.md "`nFixed: no hard-coded secrets, patched base image and dependencies."
git add .
git commit -m "fix: clean code, no secrets, patched dependencies"
git push -u origin demo-pass
```
Open a pull request into `main`. Both jobs go green and the merge button is enabled.

## What the demo files contain
| File | Insecure version | Clean version |
|---|---|---|
| `config.py` | Hard-coded (fake) GitHub token | Reads `API_TOKEN` from the environment |
| `Dockerfile` | `python:3.7` (end-of-life, many CVEs), runs as root | `python:3.12-slim`, non-root user |
| `requirements.txt` | `flask==0.12.2`, `requests==2.19.0`, `gunicorn==19.9.0` | `flask==3.0.3`, `requests==2.32.3`, `gunicorn==22.0.0` |

The token in `demo/vulnerable/config.py` is **fake**.

## Evidence checklist (for the report)
1. PASS baseline on `main` (both jobs green)
2. FAIL on `demo-fail` (both jobs red)
3. Gitleaks log showing the detected secret and file
4. Trivy log showing the CRITICAL/HIGH CVE table
5. `guardrail-scan-reports` artifact (downloaded from the run summary page)
6. Merge blocked by the ruleset
7. PASS on `demo-pass` (checks green, merge enabled)

## Troubleshooting (problems we hit)

| Symptom | Cause | Fix |
|---|---|---|
| Baseline run fails right after the first push | Scanners flag the intentionally insecure `demo/` folder | Add `.gitleaks.toml` allowlist and `--skip-dirs demo` for Trivy |
| Trivy job fails in ~3s at "Set up job": `Unable to resolve action aquasecurity/trivy-action@...` | The pinned action versions (0.28.0 / 0.36.0) could not be resolved | Run Trivy from its Docker image (`aquasec/trivy:0.57.1`) as in the current workflow; if the image tag fails to pull, use `aquasec/trivy:latest` |
| `copy /Y ... Copy-Item : A positional parameter cannot be found` | PowerShell's `copy` is `Copy-Item`, which does not take `/Y` | Use `Copy-Item <src> <dest> -Force` |
| No workflow appears in the Actions tab | Workflow file is not at `.github/workflows/` in the repo root | Move it to the root of the repo |
| Merge button still enabled with failing checks | No ruleset, ruleset not Active, wrong target branch, checks not added, or owner bypass | Follow the ruleset section above, then refresh the page |
| `demo-pass` pull request cannot be created ("nothing to compare") | Branch is identical to `main` | Commit a small change (e.g. a README line) first |
| Gitleaks still fails after removing a secret | Gitleaks scans the full history, so the old commit is still flagged | Use a fresh branch from clean `main`, or add a `.gitleaksignore` entry. In real life, **rotate the leaked secret** |
| Required check stays "Expected" and blocks merging | Check name in the ruleset does not match the job name | Use the exact job names listed above |

## Notes
- Different scanners use different rules: in our run, GitGuardian reported "No secrets detected" on a token that Gitleaks caught. This is a reason to layer tools.
- Gitleaks Action is free for personal repositories; organization repositories need a free license key.
- Pin tool versions and review them periodically.
- Local checks: `gitleaks detect -v` and `trivy image guardrail-app:scan`.
=======
# devOps
>>>>>>> 052da963c0dfc743293cccd68a66c20db5e4c247
