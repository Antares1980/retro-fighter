# Quickstart & Validation Guide: Claude GitHub App Workflows

## Prerequisites

- Python 3.11+ installed locally (`python --version`)
- Godot Engine 4.3 (optional locally if running headless runtime suite; automatically executed in GitHub Actions `CI`)

## 1. Run Python Static & Workflow Contract Tests

From the repository root (`c:\Users\rogal\workspaces\ws-games\retro-fighter`):

```powershell
python -m unittest discover -s tests -v
```

**Expected Outcome**:
- `tests/test_claude_workflows.py` verifies:
  - `.github/workflows/claude.yml` exists and enforces `@claude` mention filters, permissions, and `anthropics/claude-code-action@v1` with `--model claude-opus-5-5 --effort high`.
  - `.github/workflows/pr-review.yml` exists and enforces `cancel-in-progress: false`, `CI_WORKFLOW_NAME: "CI"`, `[skip pr-review]` + `merge_only=true` fast-path guards, `ensure_label` self-healing label catalog, exact-SHA CI polling (`--commit "$CURRENT_SHA"`), squash-merge (`gh pr merge ... --squash --delete-branch`), and `close_story_step`.
  - `.github/workflows/prompts/pr-review.md` exists and specifies `pr_meta.json`, `pr_diff.txt`, `pr_review_output.json`, `"verdict": "APPROVED"`, `"CHANGES_REQUESTED"`, `"followup_backlog_issues"`, and `python3 -m unittest discover -s tests`.
- All existing Python contract tests (`test_ai_controller.py`, `test_audio_pipeline.py`, `test_camera.py`, `test_fighter.py`, `test_hitbox_hurtbox.py`, `test_menu.py`, `test_mob_control.py`, `test_project_godot.py`, `test_stage_hud_orchestrator.py`) pass 100%.

## 2. Verify Interactive `@claude` Mentions on GitHub

1. Comment `@claude summarize the architecture of MobControlMain.gd` on any Issue or Pull Request in `AntaresAndBharani/retro-fighter`.
2. Confirm the `Claude Code` workflow (`.github/workflows/claude.yml`) triggers and replies on the thread.

## 3. Verify Automated PR Review & Auto-Merge on GitHub

1. Open a non-draft Pull Request targeting `main`.
2. Confirm both `CI` (`.github/workflows/ci.yml`) and `PR Review` (`.github/workflows/pr-review.yml`) trigger automatically.
3. Confirm `PR Review` posts a `<!-- pr-review-verdict -->` comment, applies `review:approved`, waits for `CI` to complete on `CURRENT_SHA`, and squash-merges when green.
