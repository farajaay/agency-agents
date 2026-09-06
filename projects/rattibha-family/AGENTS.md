# Rattibha working agreement

Build an Arabic consumer family planning product. Read STATUS.md first and only files relevant to the current task. User authorization covers implementation, reversible fixes, commits, and deployment of this project. It does not create unavailable credentials or authorize spending without a budget.

## Cost control
- Runtime: zero LLM calls. Planning, calculations, storage, export and printing are deterministic.
- One coordinator, at most one specialist per task. No nested delegation or idle polling.
- Use the smallest available suitable model for bounded content and reviews. Escalate only after a specific failure. Do not invent a model alias or claim cost savings were measured.
- Supply a task brief <=1500 words, relevant paths and acceptance criteria. Ask for a <=300-word result and a diff where relevant. These are guidance budgets, not hard billing caps.
- Run node scripts/check.mjs before asking an LLM to troubleshoot. Stop after two failed repair attempts and record the blocker.
- Do not run background LLM schedules, paid APIs, campaigns, or install all agents from the parent repository.

## Roles
Coordinator: choose next item in STATUS.md, bounded acceptance criteria, final release decision.
Builder: implement one coherent change; no framework dependencies without a demonstrated requirement.
Reviewer: review changed files only, prioritize data loss, broken flows, accessibility and payment security.
Product editor: Arabic product copy and experiment design; never fabricate sales, reviews or demand.

Claude Code project agents are in .claude/agents. Codex may use these same role briefs as task instructions; no claim is made that Codex automatically loads Claude's agent format. Open the project subdirectory as the working directory.

## Product integrity
Do not copy employer or spouse-owned materials or third-party templates. No checkout until merchant account, verified payment events and protected delivery exist. No frontend-only payment unlock. No analytics/customer data collection without an explicit implemented disclosure. Preserve JSON compatibility and import validation. Treat imported strings as text, never HTML.

## Source and release
Work only in this project directory. Do not edit unrelated parent files or workflows. Never commit secrets. Never bypass CLI approvals or reuse subscription credentials as API keys. Remote computer execution is unconnected until a real session is established. Keep runtime deployment and local-agent setup status accurate.
