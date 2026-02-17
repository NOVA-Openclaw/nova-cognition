# Changelog

## Unreleased

### Added
- **Prerequisite check in `agent-install.sh`** — installer now verifies that `~/.openclaw/lib/env-loader.sh` (from nova-memory) is present before proceeding; exits with a clear error message and install instructions if missing ([#127](https://github.com/nova-openclaw/nova-cognition/issues/127))
