import os
import unittest


class TestClaudeWorkflows(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
        cls.claude_yml_path = os.path.join(repo_root, ".github", "workflows", "claude.yml")
        cls.pr_review_yml_path = os.path.join(repo_root, ".github", "workflows", "pr-review.yml")
        cls.pr_review_prompt_path = os.path.join(
            repo_root, ".github", "workflows", "prompts", "pr-review.md"
        )

    def test_claude_yml_exists_and_enforces_interactive_mention_contract(self):
        self.assertTrue(os.path.isfile(self.claude_yml_path), "Missing .github/workflows/claude.yml")
        with open(self.claude_yml_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("name: Claude Code", content)
        for trigger in (
            "issue_comment:",
            "pull_request_review_comment:",
            "issues:",
            "pull_request_review:",
        ):
            self.assertIn(trigger, content)

        self.assertIn("contains(github.event.comment.body, '@claude')", content)
        self.assertIn("contains(github.event.review.body, '@claude')", content)
        self.assertIn("contains(github.event.issue.body, '@claude')", content)
        self.assertIn("contains(github.event.issue.title, '@claude')", content)

        for perm in (
            "contents: write",
            "pull-requests: write",
            "issues: write",
            "id-token: write",
            "actions: read",
        ):
            self.assertIn(perm, content)

        self.assertIn("uses: anthropics/claude-code-action@v1", content)
        self.assertIn("claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}", content)
        self.assertIn("claude_args: '--model claude-opus-5-5 --effort high'", content)

    def test_pr_review_yml_exists_and_enforces_autofix_fastpath_labels_and_exact_sha_ci_gate(self):
        self.assertTrue(
            os.path.isfile(self.pr_review_yml_path), "Missing .github/workflows/pr-review.yml"
        )
        with open(self.pr_review_yml_path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("name: PR Review", content)
        self.assertIn("branches: [ main ]", content)
        self.assertIn("types: [opened, synchronize, ready_for_review, reopened]", content)
        self.assertIn("workflow_dispatch:", content)
        self.assertIn("pr_number:", content)

        # Concurrency must not self-cancel when [skip pr-review] commit is pushed
        self.assertIn(
            "group: pr-review-${{ github.event.pull_request.number || inputs.pr_number }}",
            content,
        )
        self.assertIn("cancel-in-progress: false", content)

        # Environment constants
        self.assertIn("ROUND_CAP: 3", content)
        self.assertIn('VERDICT_MARKER: "<!-- pr-review-verdict -->"', content)
        self.assertIn('CI_WORKFLOW_NAME: "CI"', content)

        # Zero-token merge_only fast-path & [skip pr-review] handling
        self.assertIn('"[skip pr-review]"', content)
        self.assertIn('if [[ "$LAST_VERDICT_BODY" == *"PR Review Verdict: **APPROVED**"* ]]; then', content)
        self.assertIn('echo "merge_only=true" >> "$GITHUB_OUTPUT"', content)
        self.assertIn('ALREADY_ESCALATED=', content)
        self.assertIn(
            "if: steps.meta.outputs.skip != 'true' && steps.meta.outputs.merge_only != 'true'",
            content,
        )
        self.assertIn('if [ "$MERGE_ONLY" = "true" ]; then', content)

        # Lightweight runner: no Godot download inside pr-review.yml
        self.assertNotIn("Godot_v4.3-stable_linux", content)

        # Claude Opus 5.5 High review & auto-fix action
        self.assertIn("uses: anthropics/claude-code-action@v1", content)
        self.assertIn(
            'claude_args: \'--model claude-opus-5-5 --effort high --allowedTools "Read,Write,Edit,MultiEdit,Grep,Glob,Bash"\'',
            content,
        )
        self.assertIn(
            'git commit -m "fix(pr-review): apply Claude Opus 5.5 auto-fixes [skip pr-review]"',
            content,
        )

        # Self-healing label catalog
        self.assertIn("def ensure_label(repo: str, name: str) -> None:", content)
        for label_name in (
            '"review:approved"',
            '"review:changes-requested"',
            '"needs-refactor"',
            '"status:needs-po-input"',
            '"status:ready"',
            '"status:done"',
            '"dev-implemented"',
            '"tech-debt"',
        ):
            self.assertIn(label_name, content)

        # Exact-SHA CI polling & squash-merge
        self.assertIn('for i in $(seq 1 60); do', content)
        self.assertIn(
            'gh run list -R "$REPO" --commit "$CURRENT_SHA" -w "$CI_WORKFLOW_NAME" -L 1',
            content,
        )
        self.assertIn('elif [[ "$BUILD_STATUS" == completed:* ]]; then', content)
        self.assertIn('CI_PASSED="true"', content)
        self.assertIn('if [ "$CI_PASSED" != "true" ]; then', content)
        self.assertIn('gh pr merge "$PR_NUMBER" -R "$REPO" --squash --delete-branch', content)
        self.assertIn("id: close_story_step", content)
        self.assertIn("sub_issues?per_page=100", content)

    def test_pr_review_prompt_exists_and_defines_schema_and_verification_rules(self):
        self.assertTrue(
            os.path.isfile(self.pr_review_prompt_path),
            "Missing .github/workflows/prompts/pr-review.md",
        )
        with open(self.pr_review_prompt_path, "r", encoding="utf-8") as f:
            content = f.read()

        for required_token in (
            "pr_meta.json",
            "pr_diff.txt",
            "pr_review_output.json",
            '"verdict": "APPROVED"',
            '"CHANGES_REQUESTED"',
            '"fixes_applied"',
            '"blocking_issues"',
            '"followup_backlog_issues"',
            "python3 -m unittest discover -s tests",
        ):
            self.assertIn(required_token, content)


if __name__ == "__main__":
    unittest.main()
