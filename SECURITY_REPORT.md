# Analytica — Security Audit Report (snapshot)

Generated: 21 Ekim 2025

## Summary
This document summarizes a repository-wide security review of the Analytica Flutter application. The scan focused on information leakage, client-side secret usage, insecure logging, Firebase configuration and rules, dependency versions, and runtime error handling. Several low-to-medium risk issues were found and mitigations applied.

## High-level findings
- Client-side usage of GEMINI_API_KEY read from `.env` (via `flutter_dotenv`) — risk: client key exposure. Recommendation: move AI calls to a backend proxy and use short-lived credentials.
- `lib/firebase_options.dart` contains Firebase client API keys (apiKey/appId). These are expected for client-side Firebase SDKs but should not be treated as secrets. Ensure server-side rules and restricted APIs enforce limits.
- Numerous `print()` debug statements across the codebase that could leak PII or keys in debug builds; replaced with `AppLog` to suppress in release.
- Firestore had permissive rules in the Console; added stricter example rules in `firebase/firestore.rules` and deployed Firestore rules to the Firebase project `analytica-4932f`.
- Firebase Storage is referenced in code but not enabled in the target Firebase project. Uploads will fail; code updated to handle such failures gracefully.
- Third-party dependencies are mostly recent but should be periodically scanned for CVEs and updated via `dart pub upgrade` and `flutter pub upgrade`.

## Changes applied (concrete)
- Added `lib/utils/logging.dart` — centralized logging; debug-only prints in non-release builds.
- Replaced `print()` calls across services and UI with `AppLog` (reduces accidental info leakage).
- Hardened `lib/services/image_extractor.dart` to enforce a small host allowlist and safer URL normalization before fetching images.
- Added `firebase/firestore.rules` and `firebase/storage.rules` with safer default rules; updated `firebase.json` for CLI deploys.
- Deployed Firestore rules to project `analytica-4932f` (Storage left disabled intentionally as requested).
- Updated `lib/services/auth_service.dart` -> `uploadProfilePhoto` to catch `FirebaseException` and return null with friendly logs when Storage isn't available.
- Added `.env.example` to document environment variables and discourage committing secrets.

## Dependency snapshot
(Exact versions from `pubspec.lock`)
- firebase_core 3.15.2
- firebase_auth 5.7.0
- cloud_firestore 5.6.12
- firebase_storage 12.4.10
- flutter_dotenv 6.0.0
- google_generative_ai 0.4.7
- http 1.5.0
- webfeed_plus 1.1.2
- ... (see `pubspec.lock` for full list)

Action: I recommend running an automated dependency scanner (e.g., `dependabot` or `git-secrets` equivalent for Dart) and periodically running `dart pub outdated`.

## Severity & Remediation
- Critical: None found that require immediate outage.
- High: Client-side AI API key exposure — move to backend or use short-lived keys.
- Medium: Public Firebase client API keys are normal but enforce server-side checks and rules.
- Low: Debug printing and permissive rules (now addressed).

## Next recommended steps (prioritized)
1. Move AI calls (Gemini) from client to a small backend/proxy. Use server-side authentication and rate limiting. Store secrets in server-side environment or secret manager.
2. Enable Firebase Storage only if necessary; if enabled, deploy the `firebase/storage.rules` included and test uploads. Alternatively, use Cloud Functions to validate uploads before making them public.
3. Add CI checks:
   - `dart analyze`
   - `dart pub outdated` and automated dependency updates
   - Run unit tests and integration tests
   - Lint rule for forbidding `print()` (already replaced)
4. Add a secrets-check pre-commit hook (e.g., pre-commit with a small script to refuse `.env` commits).
5. Set up monitoring/alerting (Sentry/Crashlytics) for auth/storage errors.
6. Periodic security review of dependencies and re-run this audit after major dependency updates.

## Files added or modified by this audit
- Added: `lib/utils/logging.dart` (logging helper)
- Modified: many `lib/...` files to use `AppLog` instead of `print()`
- Modified: `lib/services/auth_service.dart` — safer `uploadProfilePhoto`
- Added: `firebase/firestore.rules`, `firebase/storage.rules`, `firebase-cli.json`
- Added: `.env.example`
- Added: `SECURITY_REPORT.md` (this file)

## Remaining TODOs
- Move AI key to backend (high priority)
- Implement Storage-aware UI messages and tighter client-side error handling (in-progress)
- Dependency CVE scanning and updates (in-progress)
- Optional: add tests and CI (recommended)

---
If you want, I can:
- Implement a tiny proxy (Node.js or Dart Cloud Function) to forward Gemini calls and keep the key server-side.
- Add a pre-commit hook to block accidental `.env` commits.
- Enable an automated dependency scanner configuration (Dependabot like) and create PRs to update vulnerable packages.

Tell me which of these you'd like next and I'll implement it.
