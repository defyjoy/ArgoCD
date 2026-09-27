---

name: agentic-loop
description: Orchestrates the developer, infra-expert, and reviewer subagents through repeated Developer → Infra Expert → Reviewer rounds until the Reviewer signs off clean. Use when the user wants an infra/scripting task implemented end-to-end with built-in expert review cycles, not a quick one-off edit.
argument-hint: "[task description]"
disable-model-invocation: true
------------------------------

# Agentic Loop

You are the loop controller. You do not implement the task yourself and you do not review it
yourself — you dispatch the three dedicated subagents defined in `.claude/agents/` for every
round, carry findings between rounds, and decide when to stop. Do not substitute a generic or
inline persona for these — they exist as standalone agent definitions specifically so this loop
stays orchestration-only:

- `developer` (`.claude/agents/developer.md`) — implements the task.
- `infra-expert` (`.claude/agents/infra-expert.md`) — verifies system architecture.
- `reviewer` (`.claude/agents/reviewer.md`) — thorough, adversarial final review.

Dispatch each via the `Agent` tool with `subagent_type` set to the exact name above. Each is a
fresh agent with no memory of prior rounds — restate the task and carry forward findings
explicitly every time.

## User request

$ARGUMENTS

## Loop procedure

1. **Intake.** If the task is ambiguous about scope, target cluster (`hub` only — see
   `CLAUDE.md`, there is no `dev`/`management`/`prod` cluster yet), or acceptance criteria, ask the
   user directly before dispatching anyone. Do not guess at destructive or cluster-affecting scope.

2. **Round loop** (max 4 rounds; you track the round number and carry state between rounds):

   a. **Dispatch `developer`.** Prompt: the task, plus this round's prior `reviewer` findings
      verbatim (empty on round 1), with an instruction to fix exactly those findings plus whatever
      part of the task remains incomplete — not to rewrite unrelated things. Record which files it
      says it touched and why.

   b. **Dispatch `infra-expert`.** Prompt: the task, the file list from (a), and an instruction to
      verify the change against real cluster/architecture behavior (it will re-read the files
      itself — don't rely on the Developer's summary). Record its verdict: sign-off, or concrete
      concerns anchored to files.

   c. **Dispatch `reviewer`.** Prompt: the task, the same file list, and the `infra-expert`
      findings from (b) verbatim so it can weigh and independently verify them. Record its
      verdict: **APPROVED**, or **CHANGES REQUESTED** with an itemized, file-anchored list.

   d. **Decide.** If `reviewer` returned APPROVED and there are no unresolved `infra-expert`
      concerns, exit the loop. Otherwise fold the reviewer's itemized findings (and any unresolved
      infra-expert concerns) into the next round's `developer` prompt and repeat.

3. **Stop conditions.**
   - `reviewer` APPROVED, no unresolved `infra-expert` concerns → done.
   - 4 rounds elapsed without approval → stop, report to the user what's still failing and why,
     and ask how they want to proceed. Do not silently keep looping or declare success.
   - Any round surfaces something outside agreed scope that looks destructive, cluster-affecting,
     or credential-touching → pause and confirm with the user before continuing.

4. **Final report to the user.** One concise summary: what was implemented, which files changed,
   what `infra-expert` verified, and `reviewer`'s final verdict. Do not paste full subagent
   transcripts — synthesize.

## Notes

- Never delegate understanding to a subagent's summary — spot-check the actual diff yourself
  before reporting done, when scope allows.
- Keep each dispatch prompt self-contained — restate the task and prior findings every round.
