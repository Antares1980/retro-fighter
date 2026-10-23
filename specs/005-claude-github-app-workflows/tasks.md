---

description: "Task list for Claude GitHub App Integration (claude.yml & Automated pr-review.yml Auto-Fix & Squash-Merge Pipeline)"
---

# Tasks: Claude GitHub App Integration (`claude.yml` & Automated `pr-review.yml` Auto-Fix & Squash-Merge Pipeline)

**Input**: Design documents from `/specs/005-claude-github-app-workflows/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Automated Python static contract tests (`tests/test_claude_workflows.py`) and Godot 4.3 headless runtime tests (`tests/test_runner.gd`) are REQUIRED per Constitution Principle III & Principle VIII.

**Organization**: Tasks are grouped by user story (`US1`–`US3`) to enable structured implementation and independent verification of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`)
- Exact file paths are included in every task description

---

## Phase 1: Setup (Workflow Directory Structure)

**Purpose**: Ensure `.github/workflows/prompts/` directory exists for the Claude PR review prompt specification.

- [X] T001 Create `.github/workflows/prompts/` directory structure for the Claude PR review prompt in `.github/workflows/prompts/`

---

## Phase 2: Foundational (PR Review Prompt Specification)

**Purpose**: Define the domain-specific review and auto-fix prompt (`.github/workflows/prompts/pr-review.md`) required by `pr-review.yml`.

- [X] T002 Create `.github/workflows/prompts/pr-review.md` specifying the **PR Review & Auto-Fix Engineer (Claude Opus 5.5, High Effort)** role for **Retro Fighter**, `pr_meta.json` and `pr_diff.txt` context files, Godot 4.3 2D/3D deterministic `step(delta)` & cold-cache headless review criteria, lightweight `python3 -m unittest discover -s tests` execution (without installing Godot), in-place auto-fix rules, and the `pr_review_output.json` schema (`verdict`, `fixes_applied`, `summary`, `pr_comment_markdown`, `blocking_issues`, `followup_backlog_issues`)

---

## Phase 3: User Story 1 - Interactive `@claude` Mentions on Issues and Pull Requests (Priority: P1) 🎯 MVP

**Goal**: Enable project maintainers to mention `@claude` in GitHub Issues, Issue Comments, Pull Request Reviews, and PR Review Comments to trigger interactive Claude Opus 5.5 High sessions.

**Independent Test**: Validate `.github/workflows/claude.yml` triggers, `@claude` filter expressions, permissions, and `anthropics/claude-code-action@v1` configuration via `tests/test_claude_workflows.py`.

### Implementation for User Story 1

- [X] T003 [P] [US1] Create `.github/workflows/claude.yml` with `issue_comment` (`created`), `pull_request_review_comment` (`created`), `issues` (`opened`, `assigned`), and `pull_request_review` (`submitted`) triggers, `@claude` filter guards, `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`, and `actions: read` permissions, `actions/checkout@v4` (`fetch-depth: 1`), and `anthropics/claude-code-action@v1` (`claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}`, `claude_args: '--model claude-opus-5-5 --effort high'`)

**Checkpoint**: Interactive `@claude` mentions are ready and independently verifiable.

---

## Phase 4: User Story 2 - Automated PR Review, In-Place Auto-Fix, Self-Healing Labels, & Exact-SHA Squash-Merge (Priority: P1)

**Goal**: Implement the automated PR review, in-place working-tree auto-fix (`[skip pr-review]`), idempotent self-healing label synchronization (`ensure_label`), exact-SHA `CI` polling (`--commit "$CURRENT_SHA"`), squash-merge (`gh pr merge --squash --delete-branch`), and parent-story closure (`close_story_step`) in `.github/workflows/pr-review.yml`.

**Independent Test**: Validate `.github/workflows/pr-review.yml` step definitions, label catalog (`LABEL_META`), exact-SHA CI polling loop, squash-merge command, and parent-story closure logic via `tests/test_claude_workflows.py`.

### Implementation for User Story 2

- [X] T004 [US2] Create `.github/workflows/pr-review.yml` with `pull_request` (`opened`, `synchronize`, `ready_for_review`, `reopened`) and `workflow_dispatch` (`pr_number`) triggers, `concurrency` (`group: pr-review-${{ github.event.pull_request.number || inputs.pr_number }}`, `cancel-in-progress: false`), `ROUND_CAP: 3`, `VERDICT_MARKER: "<!-- pr-review-verdict -->"`, `CI_WORKFLOW_NAME: "CI"`, checkout (`fetch-depth: 0`), `pr_meta.json`/`pr_diff.txt` context fetch, `anthropics/claude-code-action@v1` review step (`--model claude-opus-5-5 --effort high --allowedTools "Read,Write,Edit,MultiEdit,Grep,Glob,Bash"`), `verdict_step` (`claude[bot]` auto-fix commit/push with `[skip pr-review]`, `LABEL_META` + `ensure_label` for `review:approved`, `review:changes-requested`, `needs-refactor`, `status:needs-po-input`, `status:ready`, `status:done`, `dev-implemented`, and `tech-debt`, and `followup_backlog_issues` creation), `merge_step` (`60 x 10s` polling of `$CI_WORKFLOW_NAME` with `--commit "$CURRENT_SHA"`, `CI_PASSED="true"` gate, `gh pr merge --squash --delete-branch`, and `review:changes-requested` + `needs-refactor` fallback on CI failure/timeout), and `close_story_step`

**Checkpoint**: Automated PR review, auto-fix, exact-SHA CI polling, squash-merge, and parent-story closure are configured in `.github/workflows/pr-review.yml`.

---

## Phase 5: User Story 3 - Zero-Token `merge_only` Recovery Fast-Path & 3-Round Loop Escalation (Priority: P2)

**Goal**: Ensure `steps.meta` and downstream step guards in `.github/workflows/pr-review.yml` implement the zero-token `merge_only=true` fast-path for approved `[skip pr-review]` commits and the 3-round loop cap escalation (`status:needs-po-input`).

**Independent Test**: Verify `steps.meta` `[skip pr-review]` + `APPROVED` fast-path outputs (`merge_only=true`, `skip=false`), `if:` guards on checkout/fetch/claude/verdict_step, and `ROUNDS >= ROUND_CAP` escalation in `tests/test_claude_workflows.py`.

### Implementation for User Story 3

- [X] T005 [US3] Verify and enforce in `.github/workflows/pr-review.yml` that `steps.meta` inspects `LAST_MSG` for `[skip pr-review]` and `LAST_VERDICT_BODY` for `APPROVED` to emit `merge_only=true`, guards `Checkout PR branch`, `Fetch PR context`, and `Run PR Review & Auto-Fix` with `steps.meta.outputs.skip != 'true' && steps.meta.outputs.merge_only != 'true'`, handles `MERGE_ONLY == "true"` in `verdict_step` with zero LLM tokens, and escalates `ROUNDS >= ROUND_CAP` by idempotently creating and applying `status:needs-po-input`

**Checkpoint**: Zero-token `merge_only` recovery and 3-round escalation are active in `.github/workflows/pr-review.yml`.

---

## Phase 6: Polish, Automated Verification, & Cross-Cutting Concerns

**Purpose**: Create the Python static workflow contract test suite (`tests/test_claude_workflows.py`), update `CHANGELOG.md`, remove the temporary Sync Impact Report comment from `.specify/memory/constitution.md`, and run all verification suites.

- [X] T006 [P] Create `tests/test_claude_workflows.py` verifying all structural and behavioral contracts of `.github/workflows/claude.yml`, `.github/workflows/pr-review.yml`, and `.github/workflows/prompts/pr-review.md` (`US1`, `US2`, `US3`)
- [X] T007 [P] Update `CHANGELOG.md` under `## [Unreleased]` to document the Claude GitHub App integration (`.github/workflows/claude.yml`, `.github/workflows/pr-review.yml`, `.github/workflows/prompts/pr-review.md`, and `tests/test_claude_workflows.py`)
- [X] T008 Remove the temporary Sync Impact Report HTML comment from `.specify/memory/constitution.md` and run `python -m unittest discover -s tests -v` to confirm 100% pass rate

---

## Dependencies & Execution Order

- **Phase 1 (T001)** $\rightarrow$ **Phase 2 (T002)** $\rightarrow$ **Phase 3..5 (T003–T005)** $\rightarrow$ **Phase 6 (T006–T008)**.
- Parallel tasks `[P]` (`T003`, `T006`, `T007`) operate on independent files (`.github/workflows/claude.yml`, `tests/test_claude_workflows.py`, `CHANGELOG.md`).

## Parallel Example: User Story 1 & Polish

```bash
Task: "T003 [P] [US1] Create .github/workflows/claude.yml"
Task: "T006 [P] Create tests/test_claude_workflows.py"
Task: "T007 [P] Update CHANGELOG.md under [Unreleased]"
```

## Implementation Strategy

1. Complete Phase 1 & Phase 2 (`T001`–`T002`) to establish `.github/workflows/prompts/pr-review.md`.
2. Complete Phase 3 (`T003`) for User Story 1 (`.github/workflows/claude.yml`).
3. Complete Phase 4 & Phase 5 (`T004`–`T005`) for User Stories 2 & 3 (`.github/workflows/pr-review.yml`).
4. Complete Phase 6 (`T006`–`T008`) to validate 100% pass across `python -m unittest discover -s tests -v`, update `CHANGELOG.md`, and clean up the constitution Sync Impact Report comment before committing and opening the PR.
