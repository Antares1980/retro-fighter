# Feature Specification: Claude GitHub App Integration (`claude.yml` & Automated `pr-review.yml` Auto-Fix & Squash-Merge Pipeline)

**Feature Branch**: `feat/claude-github-app-workflows`

**Created**: 2026-10-23

**Status**: Approved

**Input**: User description: "Integrate the Claude GitHub App in the project modeled on AntaresAndBharani/darwin-trader and AntaresAndBharani/crosstrainingapp (`claude.yml` for interactive `@claude` mentions and `pr-review.yml` + `prompts/pr-review.md` for automated PR review, in-place auto-fix, self-healing label governance, exact-SHA CI verification, squash-merge, and parent-story closure)."

## Clarifications

### Session 2026-10-23

- Q: Which Claude GitHub App workflows should we include in the requirement for `retro-fighter`? → A: Integrate only the dual Claude workflows (`claude.yml` for `@claude` mentions + `pr-review.yml` and `prompts/pr-review.md` for automated PR review, auto-fix, CI gating, and squash-merge), matching `crosstrainingapp`.
- Q: How should test verification be configured inside the `pr-review.yml` runner environment for `retro-fighter`? → A: Keep `pr-review.yml` lightweight without installing Godot 4.3 (run only `python3 -m unittest discover -s tests` in-place, and rely on polling the `CI` workflow on `CURRENT_SHA` for Godot headless test verification).
- Q: How should we configure label governance, CI workflow polling, and static workflow tests for `retro-fighter`? → A: Use `CI_WORKFLOW_NAME: "CI"` (matching `.github/workflows/ci.yml`), include the full self-healing label set from `crosstrainingapp` (`review:*`, `status:*`, `needs-refactor`, `dev-implemented`, `tech-debt`), and add `tests/test_claude_workflows.py` (auto-discovered by `python -m unittest discover -s tests`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Interactive `@claude` Mentions on Issues and Pull Requests (Priority: P1)

Project maintainers and contributors can mention `@claude` in GitHub Issue titles/bodies, Issue Comments, Pull Request Reviews, or Pull Request Review Comments to invoke an interactive Claude Opus 5.5 High session directly on the repository.

**Why this priority**: Enables on-demand interactive assistance, architectural Q&A, and targeted code changes directly from GitHub Issues and Pull Requests.

**Independent Test**: Can be verified independently by validating `.github/workflows/claude.yml` triggers (`issue_comment`, `pull_request_review_comment`, `issues`, `pull_request_review`), `@claude` body/title filters, permissions (`contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`, `actions: read`), and `anthropics/claude-code-action@v1` invocation with `--model claude-opus-5-5 --effort high`.

**Acceptance Scenarios**:

1. **Given** `.github/workflows/claude.yml` is configured in the repository, **When** a user creates an issue, issue comment, pull request review, or pull request review comment containing `@claude`, **Then** the `claude` job runs with write permissions for contents, pull requests, and issues and invokes `anthropics/claude-code-action@v1` with `CLAUDE_CODE_OAUTH_TOKEN` and `--model claude-opus-5-5 --effort high`.
2. **Given** `.github/workflows/claude.yml` is configured in the repository, **When** an issue comment or review is posted that does not contain `@claude`, **Then** the `claude` job is skipped without consuming runner minutes or LLM tokens.

---

### User Story 2 - Automated PR Review, In-Place Auto-Fix, Self-Healing Labels, & Exact-SHA Squash-Merge (Priority: P1)

Whenever a non-draft Pull Request is opened, synchronized, reopened, marked ready for review, or manually dispatched, the automated PR review workflow reviews the diff against `retro-fighter` architectural and testing standards, applies any necessary fixes directly in the working tree, runs the lightweight Python static/configuration test suite (`python3 -m unittest discover -s tests`), commits and pushes auto-fixes with `[skip pr-review]`, idempotently ensures and applies pipeline labels (`review:approved` or `review:changes-requested` + `needs-refactor`), creates any non-blocking `followup_backlog_issues`, waits for the `CI` workflow to pass on the exact target commit SHA (`--commit "$CURRENT_SHA"`), squash-merges the PR, and closes the parent story once all sibling subtasks are complete.

**Why this priority**: Automates end-to-end PR quality verification, in-place defect remediation, CI gating, and branch merging without self-cancellation races or missing-label crashes.

**Independent Test**: Can be verified independently by inspecting `.github/workflows/pr-review.yml` and `.github/workflows/prompts/pr-review.md` via `tests/test_claude_workflows.py` and executing a live Pull Request run on GitHub Actions.

**Acceptance Scenarios**:

1. **Given** an open non-draft Pull Request triggers `.github/workflows/pr-review.yml`, **When** Claude Opus 5.5 High reviews `pr_meta.json` and `pr_diff.txt`, optionally edits files in-place, runs `python3 -m unittest discover -s tests`, and writes `"verdict": "APPROVED"` to `pr_review_output.json`, **Then** any working-tree auto-fixes are committed and pushed with `[skip pr-review]`, the resulting `synchronize` event does not cancel the active run (`cancel-in-progress: false`), `review:approved` is idempotently created and applied, the workflow waits for the `CI` workflow matching `--commit "$CURRENT_SHA"` to reach `completed:success`, and the PR is squash-merged with `--delete-branch`.
2. **Given** an approved Pull Request at `CURRENT_SHA`, **When** the `CI` workflow run for `--commit "$CURRENT_SHA"` fails, is cancelled, or times out after 60 polling attempts (10 minutes), **Then** the workflow aborts the merge, removes `review:approved`, idempotently creates and applies `review:changes-requested` and `needs-refactor`, posts a diagnostic comment referencing `CURRENT_SHA`, and exits with code `1`.
3. **Given** a Pull Request that merges and references `Closes #<SUBTASK>` in its body, **When** the parent story of `#<SUBTASK>` has `0` remaining open sibling sub-issues, **Then** the workflow idempotently creates and applies `status:done` and `dev-implemented` (removing `status:ready` and `ready-for-dev`), posts a completion comment, and closes the parent story.

---

### User Story 3 - Zero-Token `merge_only` Recovery Fast-Path & 3-Round Loop Escalation (Priority: P2)

When a `synchronize` or `workflow_dispatch` event runs on a Pull Request whose `HEAD` commit message contains `[skip pr-review]` and whose latest `<!-- pr-review-verdict -->` comment is `APPROVED`, the workflow enters the `merge_only=true` fast-path—skipping branch checkout, diff fetch, and Claude Code execution (consuming 0 LLM tokens)—and proceeds directly to ensuring `review:approved`, polling `CI` on `HEAD_SHA`, squash-merging, and checking parent-story closure. Conversely, if a Pull Request reaches 3 automated review rounds (`ROUND_CAP: 3`) without approval, the workflow escalates to the Product Owner with `status:needs-po-input`.

**Why this priority**: Prevents infinite review loops and guarantees zero-token recovery for approved auto-fix commits.

**Independent Test**: Can be verified independently via static contract assertions on `steps.meta` and `if:` guards across checkout, diff fetch, Claude review, verdict, and merge steps in `tests/test_claude_workflows.py`.

**Acceptance Scenarios**:

1. **Given** an open Pull Request whose `HEAD` commit message contains `[skip pr-review]` and whose latest `<!-- pr-review-verdict -->` comment contains `APPROVED`, **When** `pr-review.yml` runs, **Then** `steps.meta` outputs `merge_only=true` and `skip=false`, skips checkout and Claude Code steps, ensures `review:approved`, waits for `CI` on `HEAD_SHA`, and squash-merges.
2. **Given** an open Pull Request that already has `3` `<!-- pr-review-verdict -->` comments (`ROUNDS >= 3`), **When** a new non-skip commit triggers `pr-review.yml`, **Then** `steps.meta` idempotently creates and applies `status:needs-po-input`, posts an escalation comment, sets `skip=true`, and exits cleanly (`0`).

---

### Edge Cases

- **Missing Repository Labels on First Run**: Every label (`review:approved`, `review:changes-requested`, `needs-refactor`, `status:needs-po-input`, `status:ready`, `status:done`, `dev-implemented`, `tech-debt`, and any custom label in `followup_backlog_issues`) is idempotently created via `gh label create <name> -R "$REPO" --force` before `gh pr edit` or `gh issue create` is called.
- **Self-Cancellation on Auto-Fix Push**: Pushing an `[skip pr-review]` commit with `ORCHESTRATION_PAT` triggers a `pull_request: [synchronize]` event; because `concurrency.cancel-in-progress` is `false`, the active run is never cancelled mid-execution.
- **Stale Previous-Commit CI Run Match**: Polling `gh run list` uses `--commit "$CURRENT_SHA"` rather than `--branch`, preventing an auto-fix commit from falsely matching the previous commit's completed CI run.
- **Draft or Closed Pull Requests**: `steps.meta` checks `STATE != "OPEN"` or `IS_DRAFT == "true"` and exits cleanly (`skip=true`) without invoking Claude or modifying labels.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The repository MUST define `.github/workflows/claude.yml` triggered on `issue_comment` (`created`), `pull_request_review_comment` (`created`), `issues` (`opened`, `assigned`), and `pull_request_review` (`submitted`), guarded by `@claude` presence in the comment, review, or issue title/body, invoking `anthropics/claude-code-action@v1` with `secrets.CLAUDE_CODE_OAUTH_TOKEN` and `--model claude-opus-5-5 --effort high`.
- **FR-002**: The repository MUST define `.github/workflows/pr-review.yml` triggered on `pull_request` (`opened`, `synchronize`, `ready_for_review`, `reopened`) and `workflow_dispatch` (`pr_number`), configured with concurrency group `pr-review-${{ github.event.pull_request.number || inputs.pr_number }}` and `cancel-in-progress: false`.
- **FR-003**: `pr-review.yml` MUST define `ROUND_CAP: 3`, `VERDICT_MARKER: "<!-- pr-review-verdict -->"`, and `CI_WORKFLOW_NAME: "CI"` (matching `.github/workflows/ci.yml`).
- **FR-004**: In `steps.meta` of `pr-review.yml`, if the `HEAD` commit message contains `[skip pr-review]` and the latest comment containing `<!-- pr-review-verdict -->` includes `APPROVED`, the step MUST output `skip=false` and `merge_only=true` so branch checkout, context fetch, and Claude review steps are skipped (`0` LLM tokens) while label verification, exact-SHA CI polling, squash-merge, and parent-story closure still execute.
- **FR-005**: `pr-review.yml` MUST keep the runner lightweight without downloading or installing the Godot 4.3 engine binary inside the review job; `.github/workflows/prompts/pr-review.md` MUST instruct Claude Opus 5.5 High to run `python3 -m unittest discover -s tests` in-place to verify static and configuration contracts while relying on the `CI` workflow for full Godot 4.3 headless verification.
- **FR-006**: `pr-review.yml` MUST idempotently provision all pipeline labels (`review:approved`, `review:changes-requested`, `needs-refactor`, `status:needs-po-input`, `status:ready`, `status:done`, `dev-implemented`, `tech-debt`, and any `followup_backlog_issues` labels) via `gh label create ... --force` before applying them.
- **FR-007**: In `steps.merge_step` of `pr-review.yml`, when `verdict == 'APPROVED'`, the workflow MUST poll `gh run list -R "$REPO" --commit "$CURRENT_SHA" -w "$CI_WORKFLOW_NAME" -L 1` up to `60` iterations (10s interval), require `CI_PASSED="true"` (`completed:success`) before running `gh pr merge "$PR_NUMBER" -R "$REPO" --squash --delete-branch`, and transition the PR to `review:changes-requested` + `needs-refactor` with a diagnostic comment and non-zero exit if CI fails or times out.
- **FR-008**: In `steps.close_story_step` of `pr-review.yml`, after a successful merge, if the PR body links a subtask (`Closes #<N>`) whose parent story has `0` open sibling sub-issues, the workflow MUST apply `status:done` and `dev-implemented` (removing `status:ready` and `ready-for-dev`), post a completion comment, and close the parent story.
- **FR-009**: The repository MUST define `.github/workflows/prompts/pr-review.md` specifying the review criteria for `retro-fighter` (2D Fighter and 3D Mob Control deterministic `step(delta)` architecture, `project.godot` viewport/input/audio contracts, `tests/test_*.gd` and `tests/test_*.py` parity, in-place auto-fix rules, and the `pr_review_output.json` output schema).
- **FR-010**: The repository MUST include `tests/test_claude_workflows.py` validating all structural and behavioral contracts of `.github/workflows/claude.yml`, `.github/workflows/pr-review.yml`, and `.github/workflows/prompts/pr-review.md` during `python -m unittest discover -s tests`.

### Key Entities

- **Interactive Claude Workflow (`.github/workflows/claude.yml`)**: GitHub Actions workflow responding to `@claude` mentions across issues and pull requests.
- **Automated PR Review & Auto-Merge Workflow (`.github/workflows/pr-review.yml`)**: 7-step state machine orchestrating pre-flight checks, zero-token `merge_only` recovery, Claude Opus 5.5 High review & in-place auto-fix, `[skip pr-review]` commit/push, self-healing label governance, exact-SHA `CI` polling, squash-merge, and parent-story closure.
- **PR Review Prompt (`.github/workflows/prompts/pr-review.md`)**: Domain-specific instructions and JSON schema contract (`pr_review_output.json`) guiding Claude Opus 5.5 High during automated PR review.
- **Static Workflow Contract Test Suite (`tests/test_claude_workflows.py`)**: Python `unittest` suite verifying workflow triggers, concurrency settings, fast-path guards, label definitions, exact-SHA CI polling, and prompt schema requirements.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of `@claude` mentions in issues, issue comments, PR reviews, and PR review comments trigger the `Claude Code` workflow with `--model claude-opus-5-5 --effort high`, while non-mention comments consume `0` workflow runs.
- **SC-002**: 100% of open, non-draft Pull Requests undergo automated review, commit any working-tree auto-fixes with `[skip pr-review]` without self-cancellation (`cancel-in-progress: false`), wait for the exact `CURRENT_SHA` `CI` workflow run (`up to 600s`), and automatically squash-merge upon `completed:success`.
- **SC-003**: Re-dispatching or synchronizing an already-approved `[skip pr-review]` commit executes the `merge_only=true` fast-path in `0` LLM tokens.
- **SC-004**: 100% of automated test suites (`python -m unittest discover -s tests`, including `tests/test_claude_workflows.py`, and `godot --headless -s res://tests/test_runner.gd`) pass with `0` failures.

## Assumptions

- Repository secrets `CLAUDE_CODE_OAUTH_TOKEN` and `ORCHESTRATION_PAT` (with fallback to `GITHUB_TOKEN`) are configured in the `AntaresAndBharani/retro-fighter` GitHub repository settings/organization secrets, matching `darwin-trader` and `crosstrainingapp`.
- The existing `.github/workflows/ci.yml` workflow retains `name: CI` so `CI_WORKFLOW_NAME: "CI"` matches its workflow runs directly.
