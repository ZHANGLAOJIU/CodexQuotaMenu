# Security

## Trust model

Codex Quota Menu needs authenticated Codex usage and banked reset data. It reads the existing Codex credentials from `~/.codex/auth.json` and sends the access token only to the `usage` and `rate-limit-reset-credits` endpoints under `https://chatgpt.com/backend-api/wham/` over HTTPS.

The app does not persist, print, or log the access token, refresh token, ID token, or account ID. It uses an ephemeral `URLSession`, has no analytics, and makes no requests to project-owned infrastructure.

When the official request fails, the app invokes the system `/usr/bin/sqlite3` binary to read the latest relevant response headers from Codex's local log database. It does not modify the database.

## Reporting a vulnerability

Please open a GitHub security advisory for vulnerabilities that could expose credentials or execute unintended code. Do not include real tokens, account IDs, `auth.json`, or unredacted Codex logs in a public issue.

For ordinary bugs that do not involve sensitive data, use the repository issue tracker.
