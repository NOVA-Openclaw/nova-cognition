# Issue #2 Review: Use OS Username for Database Naming Convention

## Issue Summary

Standardize database naming across all nova-* projects using pattern:
```bash
DB_USER="${PGUSER:-$(whoami)}"
DB_NAME="${DB_USER//-/_}_memory"
```

Reference implementation: nova-memory#4 (CLOSED).

---

## Code Audit: Files Requiring Changes

### Already Implemented ✅
- **`agent-install.sh:10-11`** — Already uses the correct pattern (`DB_USER="${PGUSER:-$(whoami)}"`, `DB_NAME="${DB_USER//-/_}_memory"`)

### Needs Update ❌

| File | Line | Current Value | Issue |
|------|------|--------------|-------|
| `bootstrap-context/install.sh` | 11 | `DB_NAME="${DB_NAME:-nova_memory}"` | Hardcoded fallback; should derive from username |
| `human-install.sh` | 7 | `POSTGRES_DB="${POSTGRES_DB:-nova_memory}"` | Hardcoded fallback; uses `POSTGRES_DB` not `DB_NAME` |
| `agent_chat/example-config.yaml` | 15,29,36 | `database: nova_memory` | Hardcoded examples |
| `agent_chat/test-message.sql` | 4 | `nova_memory` in comment | Hardcoded reference |
| `agent_chat/schema.sql` | 4 | `nova_memory` in comment | Hardcoded reference |
| `bootstrap-context/hook/handler.ts` | 113 | `**Database:** nova_memory` | Hardcoded in string |
| `bootstrap-context/sql/migrate-initial-context.sql` | 9,94,96,167 | Multiple `nova_memory` refs | Hardcoded in comments and content |

### Inconsistency Found
- `human-install.sh` uses `POSTGRES_DB` env var; `agent-install.sh` uses `DB_NAME`. These should be unified.
- `bootstrap-context/install.sh` accepts `DB_NAME` env override but doesn't derive from username — it falls back to `nova_memory`.

---

## Issue Review: Completeness & Problems

### What's Good
- Clear pattern with examples
- Handles the most common edge case (hyphens)
- References canonical implementation
- `agent-install.sh` already implements correctly with `--database` override flag

### Missing from Issue
1. **No migration path** for existing installations with `nova_memory` database
2. **No mention of `human-install.sh`** inconsistency (`POSTGRES_DB` vs `DB_NAME`)
3. **No guidance on `agent_chat` plugin config** — the plugin takes `database` as a config field; who derives the name?
4. **PostgreSQL identifier limits** — max 63 bytes; not mentioned
5. **Only hyphens** are addressed; other invalid chars (dots, spaces, `@`) are not

### Potential Problems
1. **Breaking change**: Existing users running as `nova` won't break (still `nova_memory`), but the `bootstrap-context/install.sh` script will change behavior
2. **`whoami` in non-interactive contexts**: cron jobs, systemd services, Docker containers — `whoami` may return unexpected values (`root`, `nobody`)
3. **The pattern only replaces hyphens**: usernames with dots (e.g., `john.doe`) produce `john.doe_memory` which is valid but ugly PostgreSQL identifier requiring quoting

---

## Test Cases

### TC-1: Normal Usernames
| Input (`whoami`) | PGUSER | Expected DB_NAME |
|-----------------|--------|-------------------|
| `nova` | (unset) | `nova_memory` |
| `argus` | (unset) | `argus_memory` |
| `tabby` | (unset) | `tabby_memory` |

### TC-2: Hyphenated Usernames
| Input (`whoami`) | PGUSER | Expected DB_NAME |
|-----------------|--------|-------------------|
| `nova-staging` | (unset) | `nova_staging_memory` |
| `nova-test-01` | (unset) | `nova_test_01_memory` |
| `a-b-c-d` | (unset) | `a_b_c_d_memory` |

### TC-3: PGUSER Override
| Input (`whoami`) | PGUSER | Expected DB_NAME |
|-----------------|--------|-------------------|
| `nova` | `argus` | `argus_memory` |
| `root` | `nova-staging` | `nova_staging_memory` |
| `nova` | `custom-user` | `custom_user_memory` |

### TC-4: Underscores Already in Name
| Input | Expected DB_NAME | Notes |
|-------|-------------------|-------|
| `nova_staging` | `nova_staging_memory` | No transformation needed |
| `my_app_user` | `my_app_user_memory` | Multiple underscores OK |
| `_leading` | `_leading_memory` | Valid but unusual |

### TC-5: Edge Cases — Special Characters
| Input | Expected DB_NAME | Concern |
|-------|-------------------|---------|
| `john.doe` | `john.doe_memory` | Dot not replaced — needs quoting in SQL |
| `user@host` | `user@host_memory` | `@` invalid in unquoted PG identifier |
| `user name` | `user name_memory` | Space — will break without quoting |
| `user;drop` | `user;drop_memory` | **SQL injection risk** if not sanitized |
| `user'name` | `user'name_memory` | Quote — SQL injection risk |

**Recommendation**: Add sanitization step that strips or rejects characters outside `[a-z0-9_-]`.

### TC-6: Length Edge Cases
| Input | Expected | Concern |
|-------|----------|---------|
| `a` | `a_memory` | Minimal — works fine |
| (63-char username) | `{63chars}_memory` = 70 chars | **Exceeds PG 63-byte identifier limit** |
| `abcdefghij` × 6 (60 chars) | Truncated? | Need policy: error or truncate? |

**Recommendation**: Validate `${#DB_NAME} <= 63` and fail with clear error.

### TC-7: Numeric-Only Usernames
| Input | Expected DB_NAME | Concern |
|-------|-------------------|---------|
| `1234` | `1234_memory` | Starts with digit — valid PG identifier but needs quoting |
| `0` | `0_memory` | Same |

### TC-8: Root / System Users
| Input | Expected DB_NAME | Concern |
|-------|-------------------|---------|
| `root` | `root_memory` | Works but unexpected in production |
| `nobody` | `nobody_memory` | Common in containers |
| `www-data` | `www_data_memory` | Web server user |
| `postgres` | `postgres_memory` | PG superuser — privilege confusion |

### TC-9: `--database` Override Flag (agent-install.sh)
| Command | Expected DB_NAME |
|---------|-------------------|
| `./agent-install.sh` | `${USER}_memory` (derived) |
| `./agent-install.sh --database nova_memory` | `nova_memory` (override) |
| `./agent-install.sh -d custom_db` | `custom_db` (override) |

### TC-10: Backward Compatibility
| Scenario | Expected Behavior |
|----------|-------------------|
| Existing `nova_memory` DB, user is `nova` | No change — `nova_memory` matches |
| Existing `nova_memory` DB, user is `argus` | **Breaking** — now expects `argus_memory` |
| Migrate from hardcoded to dynamic | Need migration docs or symlink guidance |

### TC-11: Documentation Accuracy
| File | Check |
|------|-------|
| `example-config.yaml` | Should show `${USER}_memory` pattern or note it's user-specific |
| `README.md` | Should document naming convention |
| `SETUP.md` | Should reference dynamic naming |
| `bootstrap-context/README.md` | Should update install instructions |
| SQL file comments | Should not hardcode `nova_memory` |

### TC-12: Script Consistency
| Check | Status |
|-------|--------|
| `agent-install.sh` uses `DB_USER="${PGUSER:-$(whoami)}"` | ✅ |
| `bootstrap-context/install.sh` uses same pattern | ❌ Uses `DB_NAME="${DB_NAME:-nova_memory}"` |
| `human-install.sh` uses same pattern | ❌ Uses `POSTGRES_DB` env var |
| All scripts agree on env var names | ❌ Mixed: `DB_NAME`, `POSTGRES_DB`, `DB_NAME_OVERRIDE` |

---

## Recommendations

1. **Sanitize usernames**: Strip or reject chars outside `[a-zA-Z0-9_-]` before deriving DB name
2. **Validate length**: Ensure `DB_NAME` ≤ 63 characters
3. **Unify env var names**: Pick one (`DB_NAME`) and use it everywhere
4. **Add migration note**: For users upgrading from hardcoded `nova_memory`
5. **Update `bootstrap-context/install.sh`** to derive from username (not just accept override)
6. **Update `human-install.sh`** to use the same pattern as `agent-install.sh`
7. **Document the convention** in the repo README

---

*Generated: 2026-02-12 | Reviewer: subagent (automated)*
