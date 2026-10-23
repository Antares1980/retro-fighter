# Phase 0 Research: Claude GitHub App Integration (`claude.yml` & `pr-review.yml`)

## Decision 1: Dual-Workflow Architecture (`claude.yml` + `pr-review.yml` + `prompts/pr-review.md`)

- **Decision**: Integrate `.github/workflows/claude.yml` (interactive `@claude` mentions) and `.github/workflows/pr-review.yml` + `.github/workflows/prompts/pr-review.md` (automated PR review, in-place auto-fix, exact-SHA CI gating, squash-merge, and parent-story closure).
- **Rationale**: Matches `AntaresAndBharani/crosstrainingapp` and `AntaresAndBharani/darwin-trader`. Consolidating review, auto-fix, label governance, CI polling, squash-merge, and parent-story closure into a single `pr-review.yml` workflow eliminates race conditions between separate review and merge workflows.
- **Alternatives Considered**:
  - Separate `pr-review.yml` and `merge.yml` workflows: Rejected because applying `review:approved` with `ORCHESTRATION_PAT` spawns a competing merge workflow run (Forensic Defect 4 from `darwin-trader` PR #138).

## Decision 2: Non-Self-Cancelling Concurrency & Zero-Token `merge_only` Recovery Fast-Path

- **Decision**: Configure `concurrency: { group: pr-review-${{ github.event.pull_request.number || inputs.pr_number }}, cancel-in-progress: false }` and detect approved `[skip pr-review]` commits in `steps.meta` to set `merge_only=true`.
- **Rationale**: When `pr-review.yml` commits and pushes an in-place auto-fix (`[skip pr-review]`) using `ORCHESTRATION_PAT`, GitHub fires a `pull_request: [synchronize]` event within seconds. Setting `cancel-in-progress: false` ensures the active run finishes polling CI and merging rather than being killed mid-flight. If a run is re-dispatched or queued on an already-approved `[skip pr-review]` commit, `merge_only=true` skips checkout and Claude invocation (consuming `0` LLM tokens) and proceeds directly to CI polling and squash-merging.
- **Alternatives Considered**:
  - `cancel-in-progress: true`: Rejected because it cancels the active review run as soon as it pushes its own `[skip pr-review]` commit.

## Decision 3: Lightweight Review Runner Environment & Exact-SHA `CI` Polling

- **Decision**: Keep `pr-review.yml` lightweight without installing the Godot 4.3 engine binary inside the review job; instruct Claude Opus 5.5 High to run `python3 -m unittest discover -s tests` (`< 1s` on `ubuntu-latest`) during review, and poll the existing `CI` workflow (`CI_WORKFLOW_NAME: "CI"`) with `--commit "$CURRENT_SHA"` before squash-merging.
- **Rationale**: `ubuntu-latest` already provides Python 3, so `python3 -m unittest discover -s tests` runs with zero setup overhead. Meanwhile, `.github/workflows/ci.yml` (`name: CI`) runs both `test-python` and `test-godot` (Godot 4.3 headless) in parallel on every PR and `feat/**` push. Polling `gh run list -R "$REPO" --commit "$CURRENT_SHA" -w "CI" -L 1` guarantees both Python and Godot headless suites pass on the exact target commit SHA before merging.
- **Alternatives Considered**:
  - Downloading and extracting Godot 4.3 inside `pr-review.yml`: Rejected per operator preference during `/grill-me` to keep `pr-review.yml` lightweight and avoid duplicating the `CI` workflow's Godot installation step.

## Decision 4: Self-Healing Label Provisioning (`ensure_label`)

- **Decision**: Provision all required pipeline labels (`review:approved`, `review:changes-requested`, `needs-refactor`, `status:needs-po-input`, `status:ready`, `status:done`, `dev-implemented`, `tech-debt`) idempotently using `gh label create <name> -R "$REPO" --color <hex> --description <desc> --force` before any `gh pr edit` or `gh issue create` call.
- **Rationale**: Prevents `gh pr edit --add-label` from failing when a label does not yet exist in the repository (`darwin-trader` Forensic Defect 1) while maintaining full label compatibility with local and cloud orchestrators (`crosstrainingapp` pattern).
- **Alternatives Considered**:
  - Assuming labels are pre-created manually in GitHub UI: Rejected because missing labels caused workflow crashes in `darwin-trader` PR #138.
