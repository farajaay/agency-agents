# رتّبها — أسبوع العائلة

Arabic RTL family-week planner, intended as the free trial surface for a proposed 29 SAR one-time digital planning bundle. Price is an experiment, not validated demand. Current release is an owner review prototype, not a payment-enabled business.

## Run
Serve `dist/` with any static web server. For example, `python -m http.server 8000 --directory dist`. No dependencies, API keys or LLM calls are required by the web app.

## Features
Sunday-first week; tasks with owner/time/completion; meals; shopping checklist; editable daily routines; family priority; browser-local persistence; JSON backup/import; print or save PDF using browser printing. Changing week changes the current plan's dates and retains its tasks; this version is a single-plan editor, not a week archive. Nothing syncs between devices automatically.

## Verification
`node scripts/check.mjs` checks JavaScript syntax, HTML asset references, default state, date normalization and import validation. Browser interaction/visual testing is not yet performed.

## Agent setup
Open this directory in the installed Codex or Claude Code application. `AGENTS.md` contains portable task-routing guidance. Claude Code uses the three project definitions in `.claude/agents/`. These files configure future sessions; uploading them does not start a process on the owner's computer. Model aliases are Claude-specific, not Codex model settings. This session has no connected remote-PC control, no installed local Codex/Claude CLI, no billing-meter evidence and no always-on agent runner.

Use this continuation brief: “Read AGENTS.md and STATUS.md. Complete the first unblocked task, run the deterministic checks, keep all writes inside this project and report the next external dependency. Use at most one appropriate specialist.”

The operating app has zero token usage. Authoring has token usage. Short role briefs, narrow contexts and bounded turns aim to reduce authoring usage; they are not a financial spending cap.

## Market evidence, checked 2026-09-06
- https://sorted.sa/products/grocery-list — free Arabic/English grocery and meal-planning resource.
- https://thediaryofnoor.com/QdNqVzr — Arabic printable meal planner; page displayed USD 8.
- https://thebusyclub.co.uk/products/family-meal-planner-printable-digital-download — printable family meal planner.

Differentiation hypothesis: one school-week workflow with clear owner per task, morning/evening routines and a ten-minute family planning ritual. Competition exists; willingness to pay for Rattibha is unknown.

## Sales activation
Next release needs a completed premium deliverable, merchant verification and payout account, a selected supported payment provider, protected fulfillment, delivery/refund/support policy, test purchases and a verified public deployment. Do not put premium files inside publicly served assets. Do not claim that the proposed bundle is already available. No paid marketing has been started.
