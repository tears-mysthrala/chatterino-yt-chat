# Codebase Map - Current

- Full commit SHA: `e11668a03c75cf4ed8b3ef8c8d071bd0c2f34592`
- Short SHA: `e11668a`
- Branch: `main`
- Working tree: clean before documentation generation; dirty afterward only due to these new map files
- Generated at: `2026-08-08` (`Europe/Madrid`)
- Repo root: `.`
- Mode: initial
- Overview: [2026-08-08_e11668a_overview.md](2026-08-08_e11668a_overview.md)
- Module index: [2026-08-08_e11668a_module-index.md](2026-08-08_e11668a_module-index.md)
- Risk zones: [2026-08-08_e11668a_risk-zones.md](2026-08-08_e11668a_risk-zones.md)
- Diff map: not applicable (initial snapshot)

## Notes

This map is commit-bound. The generated documentation itself is not present in the referenced commit. Re-run the map workflow after structural or dependency changes.

## Command Log

- `git rev-parse --show-toplevel`
- `git rev-parse HEAD`
- `git rev-parse --short HEAD`
- `git branch --show-current`
- `git status --short`
- `git status --porcelain`
- `git log -1 --pretty=fuller`
- `git ls-files`
- `rg --files` and targeted `rg -n` symbol/dependency inspection
- `bash scripts/test.sh` - passed: 1,301 assertions, 0 failures
- `bash scripts/validate_fixtures.sh` - passed: 40 fixtures, 0 failures
- `lua -v` and `luac -v` - unavailable from PowerShell PATH
- `luacheck .` - unavailable from PowerShell PATH
