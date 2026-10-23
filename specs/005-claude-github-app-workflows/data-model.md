# Phase 1 Data Model: Claude GitHub App Workflows & Review Schema

## 1. Workflow State Machine Outputs (`pr-review.yml`)

### `steps.meta` Outputs (`$GITHUB_OUTPUT`)

| Output Key | Type / Values | Description |
| :--- | :--- | :--- |
| `head_ref` | `string` | Source branch name of the Pull Request (`headRefName`). |
| `head_sha` | `string` (40-char hex) | Commit SHA at the head of the PR when `steps.meta` inspected it (`headRefOid`). |
| `skip` | `"true"` \| `"false"` | `"true"` when PR is not `OPEN`, is a draft, is an unapproved `[skip pr-review]` commit, or has reached `ROUND_CAP` (`3`). |
| `merge_only` | `"true"` \| `"false"` | `"true"` when `HEAD_SHA` commit message contains `[skip pr-review]` and the latest `<!-- pr-review-verdict -->` comment contains `APPROVED`. |

### `steps.verdict_step` Outputs (`$GITHUB_OUTPUT`)

| Output Key | Type / Values | Description |
| :--- | :--- | :--- |
| `verdict` | `"APPROVED"` \| `"CHANGES_REQUESTED"` | Final review verdict normalized from `pr_review_output.json` (or `"APPROVED"` on `merge_only=true`). |
| `current_sha` | `string` (40-char hex) | Exact commit SHA to verify in `CI` (either newly pushed `[skip pr-review]` auto-fix commit SHA or `INITIAL_SHA`). |

---

## 2. Claude PR Review Output Schema (`pr_review_output.json`)

Written by Claude Opus 5.5 High to the workspace root during `steps.claude` and consumed by `steps.verdict_step`:

```json
{
  "verdict": "APPROVED | CHANGES_REQUESTED",
  "fixes_applied": false,
  "summary": "Concise 1-2 sentence summary of the review and any auto-fixes applied.",
  "pr_comment_markdown": "Detailed Markdown review summary including files reviewed, any auto-fixes applied, and verification notes.",
  "blocking_issues": [
    {
      "file": "scripts/mob_control/MobControlMain.gd",
      "issue": "Description of unresolvable blocking issue (empty array if APPROVED)",
      "suggested_fix": "Suggested resolution"
    }
  ],
  "followup_backlog_issues": [
    {
      "title": "Optional non-blocking tech-debt issue title",
      "body": "Issue description",
      "labels": ["tech-debt"]
    }
  ]
}
```

### Validation Rules
- `verdict`: Must be `"APPROVED"` or `"CHANGES_REQUESTED"`. Any other value defaults defensively to `"CHANGES_REQUESTED"`.
- `fixes_applied`: Boolean indicating whether Claude edited files in the working tree.
- `blocking_issues`: Array of objects (`file`, `issue`, `suggested_fix`); empty when `verdict == "APPROVED"`.
- `followup_backlog_issues`: Optional array of non-blocking backlog issues (`title`, `body`, `labels`). Each label is idempotently created via `ensure_label()` before `gh issue create`.

---

## 3. Self-Healing Pipeline Label Catalog (`LABEL_META`)

| Label Name | Color Hex | Description | Applied When |
| :--- | :--- | :--- | :--- |
| `review:approved` | `0E8A16` | PR approved by automated Claude Opus review | `verdict == 'APPROVED'` (or `merge_only == 'true'`) |
| `review:changes-requested` | `D93F0B` | PR requires changes or CI remediation | `verdict == 'CHANGES_REQUESTED'` or `CI` fails/times out on `CURRENT_SHA` |
| `needs-refactor` | `D93F0B` | PR requires remediation or CI fixes, returned to DevTest | `verdict == 'CHANGES_REQUESTED'` or `CI` fails/times out on `CURRENT_SHA` |
| `status:needs-po-input` | `B60205` | Escalated to Product Owner after max review rounds | `ROUNDS >= ROUND_CAP` (`3`) |
| `status:ready` | `0E8A16` | Story or subtask ready for Dev & Test implementation | Removed from parent story upon completion |
| `status:done` | `0E8A16` | All subtasks merged and parent story completed | Applied to parent story when `OPEN_SIBLINGS == 0` |
| `dev-implemented` | `C2E0C6` | Implementation completed by DevTest node | Applied to parent story when `OPEN_SIBLINGS == 0` |
| `tech-debt` | `FBCA04` | Technical debt or non-blocking improvement | Default label for `followup_backlog_issues` |
