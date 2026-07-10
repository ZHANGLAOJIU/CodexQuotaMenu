# Contributing

Thanks for helping keep Codex Quota Menu compatible with Codex and macOS.

## Before opening an issue

- Confirm you are using the latest commit.
- Run `./scripts/build.sh` and note any compiler error.
- Check `~/Library/Logs/CodexQuotaMenu.debug.log` for the selected data source.
- Remove tokens, account IDs, cookies, request IDs, and unrelated prompt content from all logs and screenshots.

## Pull requests

Keep changes focused. The project intentionally uses native AppKit and Foundation without package dependencies. A pull request should:

1. Explain the user-visible problem.
2. Describe how the change was verified.
3. Keep credentials out of fixtures and logs.
4. Pass `./scripts/build.sh` on macOS.

Please avoid broad formatting or architecture changes alongside a behavioral fix.
