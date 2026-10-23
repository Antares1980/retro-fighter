# Contract Specification: Claude GitHub App Workflows (`claude.yml`, `pr-review.yml`, `prompts/pr-review.md`)

## 1. `.github/workflows/claude.yml` Contract

- **Workflow Name**: `Claude Code`
- **Triggers (`on`)**:
  - `issue_comment`: `types: [created]`
  - `pull_request_review_comment`: `types: [created]`
  - `issues`: `types: [opened, assigned]`
  - `pull_request_review`: `types: [submitted]`
- **Job `claude` Condition (`if`)**:
  - `(github.event_name == 'issue_comment' && contains(github.event.comment.body, '@claude')) ||`
  - `(github.event_name == 'pull_request_review_comment' && contains(github.event.comment.body, '@claude')) ||`
  - `(github.event_name == 'pull_request_review' && contains(github.event.review.body, '@claude')) ||`
  - `(github.event_name == 'issues' && (contains(github.event.issue.body, '@claude') || contains(github.event.issue.title, '@claude')))`
- **Permissions**:
  - `contents: write`, `pull-requests: write`, `issues: write`, `id-token: write`, `actions: read`
- **Steps**:
  1. `actions/checkout@v4` with `fetch-depth: 1`
  2. `anthropics/claude-code-action@v1` with `claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}`, `claude_args: '--model claude-opus-5-5 --effort high'`, and `additional_permissions: actions: read`.

---

## 2. `.github/workflows/pr-review.yml` Contract

- **Workflow Name**: `PR Review`
- **Triggers (`on`)**:
  - `pull_request`: `types: [opened, synchronize, ready_for_review, reopened]`
  - `workflow_dispatch`: `inputs.pr_number` (`required: true`, `type: string`)
- **Concurrency**:
  - `group: pr-review-${{ github.event.pull_request.number || inputs.pr_number }}`
  - `cancel-in-progress: false`
- **Top-Level Environment (`env`)**:
  - `ROUND_CAP: 3`
  - `VERDICT_MARKER: "<!-- pr-review-verdict -->"`
  - `CI_WORKFLOW_NAME: "CI"`
- **Step Contracts**:
  1. `id: meta`: Evaluates PR state/draft, `[skip pr-review]` + `APPROVED` fast-path (`merge_only=true`), and `ROUND_CAP` escalation (`status:needs-po-input`).
  2. `Checkout PR branch` & `Fetch PR context`: Guarded by `if: steps.meta.outputs.skip != 'true' && steps.meta.outputs.merge_only != 'true'`. Writes `pr_meta.json` and `pr_diff.txt`.
  3. `id: claude`: Guarded by `if: steps.meta.outputs.skip != 'true' && steps.meta.outputs.merge_only != 'true'`. Runs `anthropics/claude-code-action@v1` with `--model claude-opus-5-5 --effort high --allowedTools "Read,Write,Edit,MultiEdit,Grep,Glob,Bash"`.
  4. `id: verdict_step`: Guarded by `if: steps.meta.outputs.skip != 'true' && (steps.meta.outputs.merge_only == 'true' || (steps.claude.outcome == 'success' && hashFiles('pr_review_output.json') != ''))`. Handles `merge_only` fast-path or commits/pushes `[skip pr-review]` fixes, posts verdict comment, creates `followup_backlog_issues`, and synchronizes labels via `ensure_label`.
  5. `id: merge_step`: Guarded by `if: steps.meta.outputs.skip != 'true' && steps.verdict_step.outputs.verdict == 'APPROVED'`. Polls `gh run list -R "$REPO" --commit "$CURRENT_SHA" -w "$CI_WORKFLOW_NAME" -L 1` for up to 60 attempts (`10s` sleep), gates `gh pr merge "$PR_NUMBER" -R "$REPO" --squash --delete-branch` on `CI_PASSED == "true"`, and transitions to `review:changes-requested` + `needs-refactor` on CI failure/timeout.
  6. `id: close_story_step`: Guarded by `if: steps.meta.outputs.skip != 'true' && steps.verdict_step.outputs.verdict == 'APPROVED' && steps.merge_step.outcome == 'success'`. Closes parent story with `status:done` and `dev-implemented` when `OPEN_SIBLINGS == 0`.

---

## 3. `.github/workflows/prompts/pr-review.md` Contract

- Must reference context files `pr_meta.json` and `pr_diff.txt`.
- Must instruct Claude Opus 5.5 High to review `retro-fighter` architecture (2D Fighter & 3D Mob Control deterministic `step(delta)` simulation, headless cold-cache safety, `project.godot` viewport/input/audio contracts, and `tests/test_*.gd` + `tests/test_*.py` test parity).
- Must instruct Claude to run `python3 -m unittest discover -s tests` for lightweight in-place verification without installing Godot.
- Must specify the required `pr_review_output.json` output schema (`verdict`, `fixes_applied`, `summary`, `pr_comment_markdown`, `blocking_issues`, `followup_backlog_issues`).
