## Summary

Describe what changed and why.

## Scope

- [ ] TAF language/compiler
- [ ] `taf` CLI/core
- [ ] `taffish-mcp`
- [ ] installer/completion/editor support
- [ ] docs/tests only
- [ ] other

## Compatibility

- [ ] Does not change public CLI behavior.
- [ ] Does not change generated shell contracts.
- [ ] Does not change hub/index metadata contracts.
- [ ] Changes public behavior and documents the migration path below.

## Testing

- [ ] `sbcl --load load-taffish.dev.lisp --eval '(han.test:run-all-tests)' --quit`
- [ ] LispWorks test suite, if this affects portable runtime behavior.
- [ ] Shell syntax checks for touched scripts/completions.
- [ ] Manual smoke test, if this affects install/build/run/publish behavior.

## Notes

Mention any release, supply-chain, or documentation follow-up needed.
