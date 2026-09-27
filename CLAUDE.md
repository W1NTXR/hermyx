# Project Rules

@Architecture.md
@Roadmap.md
@CONTEXT.md

## 1. Scope (hard limit)
- Architecture.md and Roadmap.md are the source of truth. Do not work outside them.
- If a request conflicts with them or isn't covered, STOP and ask. Do not improvise new modules, libraries, or patterns.
- Never edit Architecture.md or Roadmap.md unless I explicitly ask.

## 2. Code style
- Write the simplest code that works. Short functions, clear names, no clever tricks.
- No unnecessary abstractions, wrappers, generics, or design patterns.
- No new dependencies without asking.
- Comments only where the "why" isn't obvious. No filler comments.
- Match the existing style of the file you're editing.

## 3. Changes: surgical only
- Touch only the function/lines I asked about. Do not refactor, rename, reformat, or "improve" anything else.
- Before editing, find every caller of the function (grep). Keep its signature and behavior for callers unless I asked to change it.
- If a change must ripple to other files, list them and ask first.
- After editing, run the relevant tests/build/lint if available and report the result.
- Keep diffs small. Show what changed and why in 1–3 lines.

## 4–5. End of every task that changed code: delegate docs
- Do NOT update docs yourself. Call the `doc-keeper` subagent (runs on Haiku) with:
  - a 1–2 line summary of the task
  - the functions added / changed / deleted (file::name)
  - the next step, if known
- doc-keeper updates docs/FUNCTIONS.md and CONTEXT.md.

## 6. Communication
- Be direct. No jargon, no hype, no long explanations unless asked.
- If unsure, ask one clear question instead of guessing.
