# Contributing

This project expects contributions to be technically clean, easy to review, and safe to maintain. The rules in this guide are the default contribution standard for all changes in this repository.

## Core Principles

- Prefer small, focused pull requests over broad mixed changes.
- Preserve a linear Git history. Rebase instead of merging.
- Use conventional commits so history remains searchable and automatable.
- Document code so the next contributor can understand intent, contracts, and tradeoffs.
- Leave the codebase in a better state than you found it.

## Development Setup

1. Install Flutter on the stable channel.
2. Clone the repository.
3. Fetch dependencies in the Flutter app module:

```bash
cd open_wearable
flutter pub get
```

4. Run the app locally when needed:

```bash
flutter run
```

## Branching And Git Workflow

### Branching

- Create a dedicated branch for every change.
- Branch from the latest `main`.
- Use descriptive branch names, for example:
  - `feat/device-reconnect-flow`
  - `fix/audio-playback-timeout`
  - `docs/state-provider-guide`

### Rebase Policy

This repository uses rebases instead of merges to keep history linear and readable.

- Rebase your branch onto `main` regularly.
- Do not merge `main` into your feature branch.
- Before opening or updating a pull request, rebase onto the current `main`.
- When updating your remote branch after a rebase, use `--force-with-lease`, never plain `--force`.

Recommended workflow:

```bash
git checkout main
git pull --rebase origin main
git checkout <your-branch>
git rebase main
```

If you need to update the remote branch after rebasing:

```bash
git push --force-with-lease
```

### Commit Hygiene

- Keep commits focused and logically grouped.
- Do not mix refactors, behavior changes, formatting-only changes, and documentation churn in one commit unless they are inseparable.
- Squash fixup noise before merging unless the intermediate commits are intentionally meaningful.

## Conventional Commits

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```text
<type>(<scope>): <short summary>
```

Examples:

```text
feat(connectors): add websocket reconnect backoff
fix(audio): prevent duplicate playback startup
docs(state): clarify provider ownership rules
refactor(devices): simplify connection status handling
test(sensors): cover merged configuration rendering
chore(ci): run analyze on pull requests
```

### Allowed Types

- `feat`: new user-facing or developer-facing functionality
- `fix`: bug fix
- `refactor`: structural improvement without intended behavior change
- `docs`: documentation-only change
- `test`: test additions or test-only updates
- `chore`: maintenance, tooling, or housekeeping
- `build`: build system or dependency updates
- `ci`: CI workflow changes
- `perf`: measurable performance improvement

### Commit Rules

- Write summaries in the imperative mood.
- Keep the subject line concise and specific.
- Use a scope when it adds clarity.
- Mark breaking changes explicitly in the body or footer when applicable.

## Code Quality Expectations

### Architecture

- Prefer clear separation of responsibilities.
- Avoid tightly coupling UI, state management, device communication, and persistence concerns.
- Extend existing patterns before introducing new abstractions.
- If adding a new abstraction, document why it is needed and what problem it solves.
- Remove dead code, stale branches, and unused indirection when touching a relevant area.

### Documentation

Code must be documented, especially when it defines reusable behavior or non-obvious decisions.

- Add documentation comments to public classes, public functions, extensions, and significant state objects.
- Document inputs, outputs, side effects, invariants, and failure behavior when they are not obvious.
- Add short intent comments for complex logic blocks where structure alone is insufficient.
- Keep documentation synchronized with the implementation.
- Update the relevant Markdown docs in `open_wearable/docs/` when a change affects architecture, app flow, or contributor-facing behavior.

### Style

- Follow the existing project structure and naming conventions.
- Prefer readability over cleverness.
- Avoid broad drive-by reformatting in unrelated files.
- Keep files cohesive. If a file becomes too large or mixes responsibilities, split it deliberately.

## Validation Before Opening A Pull Request

Run validation from `open_wearable/` unless the change clearly does not affect the Flutter module.

```bash
dart format lib test
flutter analyze
flutter test
```

Expectations:

- New behavior should include tests when feasible.
- Bug fixes should include a regression test when practical.
- If a test is not possible, explain why in the pull request.
- Do not open a pull request with knowingly failing analysis or tests.

## Pull Request Guidelines

- Keep pull requests small enough for a focused review.
- Use a clear title consistent with the resulting change.
- Describe the problem, the chosen solution, and any important tradeoffs.
- Call out risky areas, migrations, or follow-up work explicitly.
- Include screenshots or recordings for UI changes when helpful.
- Resolve review comments with follow-up commits or a rebase/squash workflow that preserves clarity.

Before requesting review, confirm that:

- your branch is rebased onto the latest `main`
- commits follow conventional commit rules
- code and public APIs are documented
- formatting, analysis, and tests pass
- documentation is updated where needed

## What To Avoid

- Merging `main` into feature branches
- Force-pushing with `--force`
- Large unrelated cleanup bundled into feature work
- Undocumented public APIs
- Hidden behavior changes without tests or explanation
- Drive-by dependency upgrades without justification

## Questions And Ambiguity

When the correct approach is unclear:

- prefer the simpler design
- document assumptions in the pull request
- ask for clarification before introducing a large or irreversible change

Clean history, well-scoped commits, and documented code are part of the feature, not optional polish.
