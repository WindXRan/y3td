# Lua Trace Issues

## 2026-04-25 - Local function called before lexical declaration

- Symptom: `attempt to call a nil value (global 'configure_archive_grid_views')`.
- Cause: a function defined later with `local function name()` is not visible to earlier function bodies in Lua lexical scope, so the earlier call resolves as a global.
- Fix: declare `local name` before the caller and define it later with `name = function(...) ... end`.
