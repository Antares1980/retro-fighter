# Implementation Plan: Claude GitHub App Integration (`claude.yml` & Automated `pr-review.yml` Auto-Fix & Squash-Merge Pipeline)

**Branch**: `feat/claude-github-app-workflows` | **Date**: 2026-10-23 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-claude-github-app-workflows/spec.md`

## Summary

Integrate the Claude GitHub App into `AntaresAndBharani/retro-fighter` modeled on `AntaresAndBharani/darwin-trader` and `AntaresAndBharani/crosstrainingapp`:
1. Create `.github/workflows/claude.yml` to handle interactive `@claude` mentions across issues, issue comments, pull request reviews, and pull request review comments using `anthropics/claude-code-action@v1` (`--model claude-opus-5-5 --effort high`).
2. Create `.github/workflows/pr-review.yml` and `.github/workflows/prompts/pr-review.md` to execute automated Pull Request reviews, in-place working-tree auto-fixes (`[skip pr-review]`), zero-token `merge_only=true` recovery fast-path, idempotent self-healing label management (`review:approved`, `review:changes-requested`, `needs-refactor`, `status:needs-po-input`, `status:ready`, `status:done`, `dev-implemented`, `tech-debt`), exact-SHA CI gating against the `CI` workflow (`--commit "$CURRENT_SHA"`), squash-merge (`gh pr merge --squash --delete-branch`), and parent-story closure (`close_story_step`).
3. Create `tests/test_claude_workflows.py` (auto-discovered by `python -m unittest discover -s tests` in `.github/workflows/ci.yml`) to validate all workflow, concurrency, fast-path, self-healing label, exact-SHA CI polling, and prompt schema contracts.

## Technical Context

**Language/Version**: YAML (GitHub Actions Workflows), Bash + Python 3.11 (inline workflow orchestration & `unittest` static contract suite), Markdown (Claude Opus 5.5 prompt specification)

**Primary Dependencies**: `actions/checkout@v4`, `anthropics/claude-code-action@v1`, GitHub CLI (`gh`), `jq`, Python 3 standard library (`unittest`, `json`, `os`, `subprocess`)

**Storage**: N/A (stateless GitHub Actions workflow execution + GitHub PR comments/labels)

**Testing**: `python -m unittest discover -s tests` (including `tests/test_claude_workflows.py`) and `godot --headless -s res://tests/test_runner.gd`

**Target Platform**: GitHub Actions (`ubuntu-latest`) & cross-platform local test runner

**Project Type**: 2D/3D Arcade Game Hub (Godot 4.3 project) with automated CI/CD & Claude GitHub App workflows

**Performance Goals**: `0` LLM tokens on `merge_only=true` fast-path runs; lightweight review runner (no Godot binary download inside `pr-review.yml`, running `python3 -m unittest discover -s tests` in $< 1\text{s}$); up to `600s` (`60 x 10s`) exact-SHA CI polling window

**Constraints**: `cancel-in-progress: false` on `pr-review-${{ github.event.pull_request.number || inputs.pr_number }}` to prevent self-cancellation on auto-fix push; idempotent `gh label create ... --force` before any label operation; strict `--commit "$CURRENT_SHA"` filtering on `CI` workflow runs

**Scale/Scope**: 5 files (`.github/workflows/claude.yml`, `.github/workflows/pr-review.yml`, `.github/workflows/prompts/pr-review.md`, `tests/test_claude_workflows.py`, `CHANGELOG.md`) + `.specify/memory/constitution.md`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Deterministic Step-Driven Simulation**: **PASS** — `.github/workflows/prompts/pr-review.md` explicitly enforces deterministic `step(delta)` simulation invariants across 2D Fighter and 3D Mob Control scripts during automated PR reviews.
- **II. Cross-Game Viewport & Input Isolation**: **PASS** — `.github/workflows/prompts/pr-review.md` enforces `project.godot` (`384x224` base viewport, `1152x672` window override, physics layers, input mappings) and dynamic 3D viewport isolation rules.
- **III. Dual-Layer Automated Verification (NON-NEGOTIABLE)**: **PASS** — `tests/test_claude_workflows.py` adds static contract tests to `python -m unittest discover -s tests`, and `pr-review.yml` gates squash-merging on the `CI` workflow (`test-python` + `test-godot`) passing on `--commit "$CURRENT_SHA"`.
- **IV. Headless & Cold-Cache Execution Safety**: **PASS** — `.github/workflows/prompts/pr-review.md` checks for cold-cache headless safety (`preload(...)` constants, `Variant` deletion boundary parameters, `is_inside_tree()` guards).
- **V. Bounded Entity Caps, Power Scaling, & Spatial Clarity**: **PASS** — Preserved and enforced via review checklist in `.github/workflows/prompts/pr-review.md`.
- **VI. Articulated 3D Visuals & Zero-HP Destruction Lifecycle**: **PASS** — Preserved and enforced via review checklist in `.github/workflows/prompts/pr-review.md`.
- **VII. Dynamic Highway Motion, Auto-Fire Cannons, & Endless Survival Escalation**: **PASS** — Preserved and enforced via review checklist in `.github/workflows/prompts/pr-review.md`.
- **VIII. Automated Claude GitHub App Governance & Exact-SHA CI Gating**: **PASS** — Directly implements `.github/workflows/claude.yml`, `.github/workflows/pr-review.yml`, `.github/workflows/prompts/pr-review.md`, and `tests/test_claude_workflows.py` with `cancel-in-progress: false`, `merge_only=true` fast-path, self-healing labels, and `--commit "$CURRENT_SHA"` `CI` polling.

## Project Structure

### Documentation (this feature)

```text
specs/005-claude-github-app-workflows/
├── plan.md                                      # This file (/speckit-plan output)
├── research.md                                  # Phase 0 output (/speckit-plan)
├── data-model.md                                # Phase 1 output (/speckit-plan)
├── quickstart.md                                # Phase 1 output (/speckit-plan)
├── contracts/
│   └── claude-workflows-contract.md             # Phase 1 output (/speckit-plan)
├── checklists/
│   └── requirements.md                          # Spec quality checklist (/speckit-specify)
└── tasks.md                                     # Phase 2 output (/speckit-tasks)
```

### Source Code (repository root)

```text
.github/
└── workflows/
    ├── ci.yml                                   # Existing: "CI" workflow (test-python + test-godot)
    ├── claude.yml                               # Created: Interactive @claude mention workflow
    ├── pr-review.yml                            # Created: Automated PR review, auto-fix, CI gate & squash-merge workflow
    └── prompts/
        └── pr-review.md                         # Created: Retro Fighter review & auto-fix prompt for Claude Opus 5.5 High

tests/
├── test_claude_workflows.py                     # Created: Static contract tests for claude.yml, pr-review.yml, and prompts/pr-review.md
└── ...                                          # Existing Python & Godot test suites

CHANGELOG.md                                     # Modified: Document Claude GitHub App integration under [Unreleased]
```

**Structure Decision**: Matches the exact `.github/workflows/` layout of `AntaresAndBharani/crosstrainingapp` and `AntaresAndBharani/darwin-trader` while integrating native Python `unittest` verification in `tests/test_claude_workflows.py`.

## Complexity Tracking

No Constitution violations. All 8 core principles pass without exception.
