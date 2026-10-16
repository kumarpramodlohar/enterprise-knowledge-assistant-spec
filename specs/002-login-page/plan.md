# 002 Login Page — Plan

**Specification:** [spec.md](./spec.md)

## Architecture
Frontend only; no API changes. Reuses `AuthProvider.signInWithBasic` and `GET /me` validation per the existing API contract.

## Components
- `src/pages/LoginPage.tsx`: Tailwind implementation of the Figma frame.
- `src/components/Layout.tsx`: redirects non-authenticated states (`anonymous`, `expired`) to `/login`; keeps navigation and sign-out.
- `src/app/App.tsx`: adds the `/login` route outside the protected layout.

## Dependencies
Tailwind CSS v4 (`@tailwindcss/vite`).

## Security considerations
Server-side authorization unchanged; in-memory credentials only; fixed error messages; local sign-in presented as development-only.

## Testing strategy
- Vitest and Testing Library: render and axe, password validation, failure message, redirect and post-sign-in navigation.
- Playwright: the existing end-to-end flow signs in through the login page.
