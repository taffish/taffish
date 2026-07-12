# Specification Positioning And Version Policy

This page defines the role of TAFFISH specification documents. The current
documents should be understood as `TAFFISH Specification Draft v0.2`.

## Why A Specification Draft

TAFFISH is still centered on one reference implementation. The language, project format, Hub index, install metadata, and container runtime rules all have clear shapes, but the ecosystem has not reached the point where multiple implementations need external arbitration.

Therefore, TAFFISH should not currently claim to be an external formal standard. A better position is:

1. The reference implementation defines current factual behavior.
2. The specification draft lifts those facts into discussable, maintainable, compatibility-aware contracts.
3. The current external conformance suite verifies core compiler, project, and
   Hub workflows; future checks can cover more of the written contracts.
4. Formal standardization, governance committees, or a TEP process can be considered after the ecosystem matures.

## Difference From A Formal Standard

Formal standards usually require multiple implementations, external stakeholders, stable proposal processes, and compatibility arbitration. TAFFISH currently needs fast iteration and self-correction.

A specification draft does not freeze all design. It requires every change to answer:

1. Will this break existing `.taf` files?
2. Will this break existing taf-app projects?
3. Will this break published Hub index records?
4. Will this break commands users have already installed?
5. If so, what is the migration path?

## Specification Versions

Specification documents use draft versions:

| Version | Meaning |
| --- | --- |
| `Draft v0.1` | Historical draft aligned with the TAFFISH 0.3.x reference implementation. |
| `Draft v0.2` | Current draft aligned with the TAFFISH 0.10.x reference implementation and an operational public Hub/index ecosystem. |
| `v1.0` | Consider after language, project format, Hub index, and install format are validated by real ecosystem usage. |

Schema fields use independent versions such as `taffish.index/v1`, `taffish.install/v1`, and `taffish.config/v1`. Schema versions do not need to match the TAFFISH program version exactly.

## Normative Keywords

Keywords used in these documents:

| Keyword | Meaning |
| --- | --- |
| MUST | Reference and compatible implementations should follow this. |
| SHOULD | Strongly recommended unless there is a clear compatibility reason. |
| MAY | Allowed but not required. |
| Current implementation | Describes existing code behavior and may not yet be promised long-term. |
| Reserved | External ecosystem should not depend on it; future design may change or complete it. |

## Normative And Explanatory Text

Specification docs contain two kinds of text:

| Type | Purpose | Examples |
| --- | --- | --- |
| Normative text | Defines behavior compatible implementations MUST or SHOULD follow. | schema names, field types, naming rules, parse priority. |
| Explanatory text | Explains design reasons or current implementation details. | Common Lisp function names, current internal data structures. |

If a second TAFFISH implementation appears later, it must follow normative text but does not need to copy the internal structure of the Common Lisp implementation.

## Maturity Labels

Specification topics can use these labels:

| Label | Meaning |
| --- | --- |
| Draft | Written into the draft, but still adjustable based on implementation/ecosystem feedback. |
| Stable | Validated repeatedly by reference implementation and real taf-apps; breaking changes need migration plans. |
| Experimental | Usable for experiments; ecosystem dependencies are discouraged. |
| Deprecated | Still readable or runnable, but should not be generated. |
| Reserved | Reserved for future design; should not be depended on now. |

The current documents use `Draft v0.2`. Stable labels are applied per topic
when behavior is exercised by the reference implementation, external
conformance tests, and published taf-apps. Draft v0.2 does not make TAFFISH a
formal external standard.

## Reference Implementation

The current reference implementation is the Common Lisp implementation in this repository:

1. `taffish-core`: TAF-to-shell compiler core.
2. `taf-core`: project, Hub, install, config, history, and diagnostic tools.
3. `taffish-cli` and `taf-cli`: command-line entry points.
4. `vendor/han`: base library used by TAFFISH.

When the draft conflicts with code, short-term factual behavior is the current code. Long-term, either docs or code should be corrected so they match again.

## Unstable Areas

The following remain actively evolving:

1. Inline `taffish` flow reference syntax.
2. Details of `taf-app` command mode.
3. Evolution of Hub trust reports and index-side validation metadata.
4. Gitee mirror strategy and multi-source sync.
5. Container image cache, SIF naming, and advanced backend parameters.
6. Complete machine-readable coverage of the written conformance checklist.

These areas can record current behavior, but should not be frozen too early.
