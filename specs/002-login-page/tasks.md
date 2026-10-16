# 002 Login Page — Tasks

**Specification:** [spec.md](./spec.md) · **Plan:** [plan.md](./plan.md)

| ID | Task | Repository | Files | Status |
|---|---|---|---|---|
| L01 | Integrate Tailwind CSS v4 | Frontend | `vite.config.ts`, `src/index.css` | Done (build, 48 unit tests pass) |
| L02 | Build `LoginPage` from Figma frame | Frontend | `src/pages/LoginPage.tsx` | Done; visual comparison with Figma not yet performed |
| L03 | Add `/login` route and protected-route redirect | Frontend | `src/app/App.tsx`, `src/components/Layout.tsx` | Done |
| L04 | Unit and accessibility tests | Frontend | `src/pages/LoginPage.test.tsx`, `src/app/App.test.tsx` | Done (48 passed) |
| L05 | Update end-to-end test | Frontend | `e2e/assistant-and-documents.spec.ts` | Done (1 passed) |
| L06 | Enable SSO button | Frontend | `LoginPage.tsx` | Blocked on OI-1 (OIDC decision) |
| L07 | Visual review against Figma in a browser | Frontend | — | Not started |
