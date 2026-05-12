# TAF Language Contract

This page records core contracts the TAF language should keep inside `taffish-core`. For a more detailed description, see [TAF Language Specification Draft](taf-language-spec.md). This page is kept as a high-level invariant checklist for compiler maintenance.

## File Role

A TAF file describes a compilable tool or workflow. It must express user parameters, execution blocks, and tag-selected execution models.

## Basic Structure

The current TAF compiler recognizes:

1. Blank lines.
2. Comments.
3. Tags.
4. Plain code.
5. `ARGS` blocks.
6. `RUN` blocks.
7. Subtags.

The parser may normalize some bare code into a default run block to make simple TAF files easier to write. This convenience should not undermine structural clarity.

## ARGS Contract

`ARGS` describes user input parameters. It is eventually converted into `han.args` argument specifications.

Maintain these boundaries:

1. Parser converts ARGS into argument specifications.
2. Binder binds real input to those specifications.
3. Compiler does not directly read raw CLI arguments.

## RUN Contract

`RUN` describes execution logic. Tags dispatch it to emitters.

Maintain these boundaries:

1. Parser determines RUN block structure.
2. Emitters determine RUN block semantic emission.
3. Compiler orchestrates the flow and should not hard-code specific tag behavior.

## Location And Errors

The lexer should preserve enough source-location information for parser, binder, or compiler errors to trace back to source positions. TAFFISH targets reproducible tools and workflows; good error locations are part of the language experience.

## Unstable Areas

Changes in the following areas should first be documented in a more complete specification:

1. Subtag composition rules.
2. Inline `taffish` composition syntax.
3. `taf-app` command mode details.
4. Full container tag argument syntax.
