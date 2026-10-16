# 003 Ask Page — Plan

**Specification:** [spec.md](./spec.md)

## Architecture
Frontend only; no API changes. Uses the existing `api.queryChat` and `api.getDocument` client calls per the 001 API contract.

## Components
- `src/pages/AssistantPage.tsx`: Ask page with a main column (collection selector, question, answer card, input) and an "Extracted source" side panel.
- `src/components/Layout.tsx`: sidebar shell (navigation, role, sign-out) that redirects unauthenticated users to `/login`.

## Data flow
Question and filters go to `POST /chat/query`. The response drives the answer or insufficient-evidence state. Selecting a citation calls `GET /documents/{id}`; only an `INDEXED` document reveals the returned snippet.

## Security considerations
All content is rendered as text. No stored history. Server authorization is unchanged and authoritative.

## Testing strategy
- Vitest and Testing Library: inert rendering, filters, insufficient evidence, pending guard, inaccessible source, shell axe check.
- Playwright: sign in, upload, ask and see the insufficient-evidence result.
