"""Argument contracts and source-only inline boundaries; no container or network."""

import json
import os
from pathlib import Path
import shlex
import subprocess
import sys


CASE = sys.argv[1]
ROOT = Path(os.environ["TAFFISH_TEST_TMP_ROOT"]) / ("argument-contract-" + CASE)
ROOT.mkdir()
BIN = ROOT / "bin"
BIN.mkdir()
ENV = os.environ.copy()
ENV.update(
    PATH=str(BIN) + os.pathsep + ENV["PATH"],
    LC_ALL=ENV["TAFFISH_TEST_UTF8_LOCALE"],
    LANG=ENV["TAFFISH_TEST_UTF8_LOCALE"],
    TAF_CONTRACT_VALUE="runtime value",
    TAF_CONTRACT_THREADS="before body",
    TAF_HISTORY_MODE="off",
)
TAFFISH = ENV["TAFFISH_BIN"]
sequence = 0


def write(path, text, executable=False):
    path.write_text(text, encoding="utf-8")
    if executable:
        path.chmod(0o700)
    return path


# Count plus NUL delimiters distinguish spaces/newlines, no args, and empty args.
write(
    BIN / "arg-dump",
    '#!/bin/sh\nprintf "%s\\000" "$#"\n'
    'for arg do printf "%s\\000" "$arg"; done\n',
    executable=True,
)


def invoke(argv, *, input=None, success=True, cwd=ROOT):
    result = subprocess.run(
        list(map(str, argv)), input=input, stdout=subprocess.PIPE,
        stderr=subprocess.PIPE, cwd=cwd, env=ENV, timeout=30,
    )
    if success:
        assert result.returncode == 0, (
            argv, result.returncode, result.stdout, result.stderr
        )
    return result


def compile_source(source, args=(), *, syntax_check=True):
    global sequence
    sequence += 1
    path = write(ROOT / (str(sequence) + ".taf"), source)
    shell = invoke([TAFFISH, path, *args]).stdout
    if syntax_check:
        invoke(["sh", "-n"], input=shell)
    return shell


def check_args(shell, expected):
    actual = invoke(["sh"], input=shell).stdout
    wanted = (str(len(expected)) + "\0" + "".join(x + "\0" for x in expected))
    assert actual == wanted.encode("utf-8"), (shell, expected, actual)


def block(body="arg-dump ::(@:)step::", tag="shell"):
    return "ARGS\n<(@:)step>\nRUN\n<" + tag + ">\n" + body + "\n"


def scalar_text():
    prefix = "ARGS\n<!(--/-i)input>\nRUN\n<shell>\n"
    raw = compile_source(prefix + "arg-dump ::input::\n", ["--input", "sample A.fa"])
    check_args(raw, ["sample", "A.fa"])
    quoted = compile_source(prefix + 'arg-dump "::input::"\n', ["--input", "sample A.fa"])
    check_args(quoted, ["sample A.fa"])
    # Double quotes around substituted text do not disable shell expansion.
    check_args(
        compile_source(prefix + 'arg-dump "::input::"\n', ["--input", "$TAF_CONTRACT_VALUE"]),
        ["runtime value"],
    )


def block_roundtrip():
    values = [
        "--input", "sample A.fa", "a'b", 'say "hello"', 'both \' and "',
        "$HOME", '"$TAF_CONTRACT_THREADS"', "$(printf UNEXPECTED)",
        "a;b*?", "*", "back\\slash", "  ", "a\tb", "line\nbreak", "中文 参数",
        "hello, world! -- '/example/home'",
        "", "sample]].fa", "[[taf: taf-fake hi]]",
    ]
    write(ROOT / "glob-match", "fixture\n")
    check_args(compile_source(block(), ["@step:", *values]), values)
    # Caller expansion happens before TAFFISH; single quotes retain literal $HOME.
    path = write(ROOT / "caller.taf", block())
    shell = invoke([
        "sh", "-c", 'exec "$1" "$2" @step: "$HOME" \'$HOME\'',
        "caller", TAFFISH, path,
    ]).stdout
    check_args(shell, [ENV["HOME"], "$HOME"])


def block_display():
    args = ["@step:", "--out", "hello world"]
    check_args(compile_source(block(), args), ["--out", "hello world"])
    counted_display = block('''set -- ::(@:)step::
printf 'argc=%s\\n' "$#"
for arg do
    printf '<%s>\\n' "$arg"
done''')
    shell = compile_source(counted_display, args)
    assert invoke(["sh"], input=shell).stdout == b"argc=2\n<--out>\n<hello world>\n"
    shell = compile_source(counted_display)
    assert invoke(["sh"], input=shell).stdout == b"argc=0\n"
    # This is one display string with encoded quote characters, not two argv items.
    check_args(compile_source(block('arg-dump "::(@:)step::"'), args),
               ["--out 'hello world'"])
    args += ["a'b"]
    check_args(compile_source(block('arg-dump "::(@:)step::"'), args),
               ["--out 'hello world' 'a'\\''b'"])
    check_args(compile_source(block('arg-dump "::(@:)step::"'),
                              ["@step:", "--out", "hello, world! -- '/example/home'"]),
               ["--out 'hello, world! -- '\\''/example/home'\\'''"])
    # A literal dollar in a block is protected only in the unquoted list position.
    check_args(compile_source(block(), ["@step:", "$TAF_CONTRACT_VALUE"]),
               ["$TAF_CONTRACT_VALUE"])
    check_args(compile_source(block('arg-dump "::(@:)step::"'),
                              ["@step:", "$TAF_CONTRACT_VALUE"]),
               ["'runtime value'"])


def argv_text():
    raw = "<shell>\narg-dump ::*ARGV*::\n"
    display = '<shell>\narg-dump "::*ARGV*::"\n'
    check_args(compile_source(raw, ["sample A.fa", "out dir"]),
               ["sample", "A.fa", "out", "dir"])
    check_args(compile_source(display, ["sample A.fa", "out dir"]),
               ["sample A.fa out dir"])
    check_args(compile_source(raw, ["'sample A.fa'", "'out dir'"]),
               ["sample A.fa", "out dir"])
    check_args(compile_source(raw, ['"$TAF_CONTRACT_VALUE"']), ["runtime value"])
    check_args(compile_source(raw, ["'$TAF_CONTRACT_VALUE'"]), ["$TAF_CONTRACT_VALUE"])
    check_args(compile_source(display, ["$TAF_CONTRACT_VALUE"]), ["runtime value"])


def command_text():
    source = "<taf-app:shell>\narg-dump DEFAULT\n"
    shell = compile_source(source, ["arg-dump", "sample A.fa"])
    assert b"DEFAULT" not in shell, shell
    check_args(shell, ["sample", "A.fa"])
    check_args(compile_source(source, ["arg-dump", "'sample A.fa'", "''"]),
               ["sample A.fa", ""])
    check_args(compile_source(source, ["arg-dump", '\'a"b\'', '"$TAF_CONTRACT_VALUE"']),
               ['a"b', "runtime value"])
    check_args(compile_source(source, ["--input", "sample A.fa"]), ["DEFAULT"])
    example = compile_source(source, ["printf", "'<%s>\\n'", "'sample A.fa'"])
    assert invoke(["sh"], input=example).stdout == b"<sample A.fa>\n"


def adapter(name, source):
    path = write(ROOT / (name + ".taf"), source)
    # Only the --compile entry is adapted; compilation and generated-shell
    # execution are real at every level, rather than canned child output.
    write(
        BIN / name,
        '#!/bin/sh\n[ "$1" = --compile ] || exit 64\nshift\n'
        'exec "$TAFFISH_BIN" ' + shlex.quote(str(path)) + ' "$@"\n',
        executable=True,
    )


def nested_blocks():
    adapter("taf-contract-leaf", block())
    adapter("taf-contract-child", block(
        "[[taf: taf-contract-leaf @step: ::(@:)step::]]", "taffish"))
    parent = block("[[taf: taf-contract-child @step: ::(@:)step::]]", "taffish")
    values = ["--input", "sample A.fa", "a'b", 'say "hello"',
              "$HOME", '"$TAF_CONTRACT_THREADS"', "a;b*?", "中文 参数"]
    values += ["", "sample]].fa", "[[taf: taf-fake hi]]", 'both \' and "',
               "a\\]b", "line\nbreak", "trailing\\"]
    check_args(compile_source(parent, ["@step:", *values]), values)
    # A child using raw ARGV instead of a token block changes the contract.
    adapter("taf-contract-text", "<shell>\narg-dump ::*ARGV*::\n")
    text_child = block("[[taf: taf-contract-text ::(@:)step::]]", "taffish")
    check_args(compile_source(text_child, ["@step:", "sample A.fa"]), ["sample", "A.fa"])


def inline_boundaries():
    adapter("taf-contract-child", block())
    unicode_shell = compile_source("<taffish>\nprintf '%s' '中文文本'\n")
    assert invoke(["sh"], input=unicode_shell).stdout == "中文文本".encode()
    parent = block("[[taf: taf-contract-child @step: ::(@:)step::]]", "taffish")
    for value in ['both \' and "', "]]", "[[taf: taf-fake]]", "", "a\\]b"]:
        check_args(compile_source(block(), ["@step:", value]), [value])
        check_args(compile_source(parent, ["@step:", value]), [value])
    # Scalar values remain raw text. Author-written quotes still do the quoting.
    check_args(compile_source(
        "<taffish>\n[[taf: taf-contract-child @step: '::(--/-i)input::' ]]\n",
        ["--input", "sample]].fa"]), ["sample]].fa"])
    quoted = r'''<taffish>
[[taf: taf-contract-child @step: 'x]] [[taf: taf-fake]]' "y]]" a\]]b ]]
'''
    check_args(compile_source(quoted), ["x]] [[taf: taf-fake]]", "y]]", "a]]b"])
    adapter("taf-contract-cat", "<shell>\ncat\n")
    pipeline = '''<taffish>
[[taf: taf-contract-child @step: 'sample]].fa' ]] | [[taf: taf-contract-cat ]] > result
cat result
'''
    check_args(compile_source(pipeline), ["sample]].fa"])
    # Data may not generate a call or repair missing source delimiters.
    shell = compile_source("<taffish>\nprintf '%s' '::(--/-i)input::'\n",
                           ["--input", "[[taf: taf-fake]]"])
    assert b"taffish_step_1=" not in shell, shell
    assert invoke(["sh"], input=shell).stdout == b"[[taf: taf-fake]]"
    path = write(ROOT / "unclosed.taf", "<taffish>\n[[taf: taf-contract-child ::(@:)step::\n")
    result = invoke([TAFFISH, path, "@step:", "]]"], success=False)
    assert result.returncode != 0 and result.stdout == b"", result
    assert b"Missing right match" in result.stderr, result.stderr


def inline_error_message():
    write(BIN / "taf-contract-fail", "#!/bin/sh\nexit 23\n", executable=True)
    # Actual command arguments are safe block tokens; the failure diagnostic must
    # not expand them again or turn them into a second command.
    values = ['both \' and "', "$(touch SHOULD-NOT-EXIST)", "`touch ALSO-NOT`",
              "$HOME", "", "sample]].fa", "a\\b"]
    shell = compile_source(block("[[taf: taf-contract-fail ::(@:)step:: ]]", "taffish"),
                           ["@step:", *values])
    result = invoke(["sh"], input=shell, success=False)
    assert result.returncode == 1 and result.stdout == b"", result
    assert b"[TAFFISH] failed to compile taf step:" in result.stderr, result.stderr
    assert b"$(touch SHOULD-NOT-EXIST)" in result.stderr, result.stderr
    assert b"$HOME" in result.stderr, result.stderr
    assert not (ROOT / "SHOULD-NOT-EXIST").exists()
    assert not (ROOT / "ALSO-NOT").exists()


def inline_probe(name="taf-contract-probe-v0.1.0-r1"):
    """A harmless child with the real wrapper's first-argument compile branch."""
    calls = write(ROOT / "child-calls", "")
    ran = ROOT / "child-run"
    ENV.update(TAF_CONTRACT_CALLS=str(calls), TAF_CONTRACT_RAN=str(ran))
    source = write(ROOT / "child.taf", block())
    write(
        BIN / name,
        '#!/bin/sh\n'
        '{ printf "%s\\000" "$#"; for arg do printf "%s\\000" "$arg"; done; } '
        '>> "$TAF_CONTRACT_CALLS"\n'
        'if [ "${1:-}" = --compile ]; then\n'
        '    shift\n'
        '    exec "$TAFFISH_BIN" ' + shlex.quote(str(source)) + ' "$@"\n'
        'fi\n'
        # A misplaced control argument would run this branch and then interpret
        # its stdout as shell. Neither branch can invoke a real app/container.
        'printf "%s\\n" run > "$TAF_CONTRACT_RAN"\n'
        'printf "%s\\n" "printf RUN_STDOUT_EXECUTED_AS_SHELL"\n',
        executable=True,
    )
    return name, calls, ran


def check_probe_calls(calls, ran, args):
    expected = (str(len(args)) + "\0" + "".join(arg + "\0" for arg in args)).encode()
    assert calls.read_bytes() == expected, (args, calls.read_bytes())
    assert not ran.exists(), "child incorrectly entered its run branch"


def inline_separators():
    child, calls, ran = inline_probe()
    values = ["alpha", "two words", ""]
    arguments = "@step: alpha 'two words' ''"
    commands = [
        ("space", child + " " + arguments),
        ("tab", child + "\t" + arguments),
        ("space-tab", child + " \t" + arguments),
        ("tab-space", child + "\t " + arguments),
        ("explicit-space", child + " --compile " + arguments),
        ("explicit-tab", child + " --compile\t" + arguments),
        ("explicit-mixed", child + "\t --compile \t" + arguments),
    ]
    for label, command in commands:
        print("inline separator:", label, flush=True)
        calls.write_bytes(b"")
        shell = compile_source("<taffish>\n[[taf: " + command + "]]\n")
        assert calls.read_bytes() == b"" and not ran.exists(), "compile executed child"
        # Check argv before stdout so a misplaced --compile has an exact trace.
        result = invoke(["sh"], input=shell)
        check_probe_calls(calls, ran, ["--compile", "@step:", *values])
        assert result.stdout == b"3\0alpha\0two words\0\0", result
    for command in [child, child + "\t--compile"]:
        calls.write_bytes(b"")
        shell = compile_source("<taffish>\n[[taf: " + command + "]]\n")
        assert calls.read_bytes() == b"", "compile executed child"
        check_args(shell, [])
        check_probe_calls(calls, ran, ["--compile"])


def comment_lines(child):
    return [
        "# [[taf: " + child + " ignored]]",
        "  # [[taf: " + child + " ignored]]",
        "\t# [[taf: " + child + " ignored]]",
        " \t # [[taf: " + child + " ignored]]",
        "# [[taf: ]]",
        "# [[taf: " + child + " unclosed",
        "# [[taf: taf-comment-only-v9.9.9-r9 ignored]]",
    ]


def inline_comments():
    child, calls, ran = inline_probe()
    for line in comment_lines(child):
        print("inline comment:", repr(line), flush=True)
        shell = compile_source("<taffish>\n" + line + "\nprintf '%s\\n' DONE\n")
        assert calls.read_bytes() == b"" and not ran.exists(), "compile executed child"
        result = invoke(["sh"], input=shell)
        assert result.stdout == b"DONE\n", result
        assert calls.read_bytes() == b"" and not ran.exists(), (
            "comment invoked child", line, calls.read_bytes()
        )


def inline_projects():
    child, calls, ran = inline_probe()
    taf = ENV["TAF_BIN"]
    ENV["TAFFISH_USER_HOME"] = str(ROOT / "user-home")
    ENV["TAFFISH_SYSTEM_HOME"] = str(ROOT / "system-home")
    os.symlink(TAFFISH, BIN / "taffish")
    os.symlink(taf, BIN / "taf")
    invoke([taf, "new", "inline-regression", "--flow"])
    project = ROOT / "inline-regression"
    source = "<taffish>\n" + "\n".join(comment_lines(child))
    source += "\n[[taf: " + child + "\t@step: alpha 'two words' '' ]]\n"
    write(project / "src/main.taf", source)
    invoke([taf, "build"], cwd=project)
    invoke([taf, "check"], cwd=project)
    toml = (project / "taffish.toml").read_text()
    assert 'taf-contract-probe = "0.1.0-r1"' in toml, toml
    assert "taf-comment-only" not in toml, toml
    live = invoke([taf, "compile"], cwd=project).stdout
    assert calls.read_bytes() == b"" and not ran.exists(), "project preparation ran child"
    check_args(live, ["alpha", "two words", ""])
    check_probe_calls(calls, ran, ["--compile", "@step:", "alpha", "two words", ""])
    # The generated wrapper must compile its frozen source, including comments,
    # even when the working source has subsequently changed.
    write(project / "src/main.taf", "<shell>\nprintf LIVE_SOURCE_CHANGED\n")
    wrapper = project / "target/taf-inline-regression-v0.1.0-r1"
    calls.write_bytes(b"")
    frozen = invoke([wrapper, "--compile"]).stdout
    assert calls.read_bytes() == b"" and not ran.exists(), "wrapper compile ran child"
    invoke(["sh", "-n"], input=frozen)
    check_args(frozen, ["alpha", "two words", ""])
    check_probe_calls(calls, ran, ["--compile", "@step:", "alpha", "two words", ""])
    calls.write_bytes(b"")
    assert invoke([wrapper]).stdout == b"3\0alpha\0two words\0\0"
    check_probe_calls(calls, ran, ["--compile", "@step:", "alpha", "two words", ""])


def inline_mcp():
    child, calls, ran = inline_probe()
    comments = "<taffish>\n" + "\n".join(comment_lines(child)) + "\nprintf '%s\\n' DONE\n"
    tab = "<taffish>\n[[taf: " + child + "\t--compile\t@step: alpha 'two words' '' ]]\n"
    path = write(ROOT / "mcp-inline.taf", comments)
    requests = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {
            "protocolVersion": "2025-06-18", "capabilities": {},
            "clientInfo": {"name": "inline-contract", "version": "0"}}},
        {"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}},
    ]
    for request_id, name, arguments in [
        (2, "taffish_compile_source", {"source": comments}),
        (3, "taffish_compile_source", {"source": tab}),
        (4, "taffish_compile_file", {"path": str(path)}),
    ]:
        requests.append({"jsonrpc": "2.0", "id": request_id, "method": "tools/call",
                         "params": {"name": name, "arguments": arguments}})
    result = invoke([ENV["TAFFISH_MCP_BIN"]], input=(
        "\n".join(json.dumps(request) for request in requests) + "\n").encode())
    write(ROOT / "mcp-responses.jsonl", result.stdout.decode())
    assert result.stderr == b"", result.stderr
    responses = {response["id"]: response for response in
                 (json.loads(line) for line in result.stdout.splitlines())}
    assert set(responses) == {1, 2, 3, 4}, responses
    assert calls.read_bytes() == b"" and not ran.exists(), "MCP compile ran child"
    for request_id in [2, 3, 4]:
        answer = responses[request_id]["result"]
        assert not answer.get("isError"), answer
        data = answer["structuredContent"]
        assert data["ok"] is True, data
        shell = data["shell"].encode()
        invoke(["sh", "-n"], input=shell)
        calls.write_bytes(b"")
        # Only the test harness executes the returned script; MCP returns text.
        if request_id == 3:
            check_args(shell, ["alpha", "two words", ""])
            check_probe_calls(calls, ran, ["--compile", "@step:", "alpha", "two words", ""])
        else:
            assert invoke(["sh"], input=shell).stdout == b"DONE\n"
            assert calls.read_bytes() == b"" and not ran.exists(), "comment ran child"


def delayed_expression():
    adapter("taf-contract-command", "<taf-app:shell>\narg-dump DEFAULT\n")
    source = '''<taffish>
TAF_CONTRACT_THREADS='after body'
export TAF_CONTRACT_THREADS
[[taf: taf-contract-command arg-dump '"$TAF_CONTRACT_THREADS"' ]]
'''
    shell = compile_source(source)
    assert shell.index(b"--compile") < shell.index(b"TAF_CONTRACT_THREADS='after body'"), shell
    check_args(shell, ["after body"])
    # Removing the literal quote layer instead expands during child compilation.
    early = source.replace("'\"$TAF_CONTRACT_THREADS\"'", '"$TAF_CONTRACT_THREADS"')
    check_args(compile_source(early), ["before", "body"])


def empty_arguments():
    check_args(compile_source("<shell>\narg-dump ::*ARGV*::\n"), [])
    check_args(compile_source('<shell>\narg-dump "::*ARGV*::"\n'), [""])
    check_args(compile_source("<shell>\narg-dump ::*ARGV*::\n", ["''"]), [""])
    check_args(compile_source(block(), ["@step:", "''"]), ["''"])
    check_args(compile_source("<shell>\narg-dump ::(@:)step=NULL::\n"), ["NULL"])
    paths = [
        ("<shell>\narg-dump ::*ARGV*::\n", [""], []),
        ('<shell>\narg-dump "::*ARGV*::"\n', [""], [""]),
        ("<shell>\narg-dump ::(--/-i)input::\n", ["--input", ""], []),
        ('<shell>\narg-dump "::(--/-i)input::"\n', ["--input", ""], [""]),
        (block(), ["@step:", ""], [""]),
        (block(), ["@step:", "", "x", ""], ["", "x", ""]),
        ("<taf-app:shell>\narg-dump DEFAULT\n", ["arg-dump", ""], []),
    ]
    for source, args, expected in paths:
        check_args(compile_source(source, args), expected)
    source = 'ARGS\n<!(--/-i)input>\nRUN\n<shell>\narg-dump "::input::"\n'
    check_args(compile_source(source, ["--input", ""]), [""])
    path = write(ROOT / "missing.taf", source)
    result = invoke([TAFFISH, path, "--input"], success=False)
    assert result.returncode != 0 and b"[TAFFISH-ERROR]" in result.stderr, result


def project_boundaries():
    taf = ENV["TAF_BIN"]
    ENV["TAFFISH_USER_HOME"] = str(ROOT / "user-home")
    ENV["TAFFISH_SYSTEM_HOME"] = str(ROOT / "system-home")
    # Wrappers find the actual candidate compiler, never an installed release.
    os.symlink(TAFFISH, BIN / "taffish")
    os.symlink(taf, BIN / "taf")
    invoke([taf, "new", "inline-leaf", "--flow"])
    leaf = ROOT / "inline-leaf"
    write(leaf / "src/main.taf", block())
    invoke([taf, "build"], cwd=leaf)
    ENV["PATH"] = str(leaf / "target") + os.pathsep + ENV["PATH"]
    invoke([taf, "new", "inline-parent", "--flow"])
    parent = ROOT / "inline-parent"
    write(parent / "src/main.taf", block(
        '[[taf: taf-inline-leaf-v0.1.0-r1 @step: "literal]]" ::(@:)step:: ]]', "taffish"))
    invoke([taf, "build"], cwd=parent)
    toml = (parent / "taffish.toml").read_text()
    assert 'taf-inline-leaf = "0.1.0-r1"' in toml, toml
    assert "taf-fake" not in toml, toml
    invoke([taf, "check"], cwd=parent)
    values = ["", "sample]].fa", "[[taf: taf-fake]]", 'both \' and "', "$HOME"]
    args = ["@step:", *values]
    live = invoke([taf, "compile", "--", *args], cwd=parent).stdout
    invoke(["sh", "-n"], input=live)
    check_args(live, ["literal]]", *values])
    wrapper = parent / "target/taf-inline-parent-v0.1.0-r1"
    frozen = invoke([wrapper, "--compile", *args]).stdout
    check_args(frozen, ["literal]]", *values])
    expected = (str(len(values) + 1) + "\0literal]]\0" + "".join(x + "\0" for x in values)).encode()
    assert invoke([wrapper, *args]).stdout == expected
    # Only real source calls belong to the dependency set; a default may contain
    # a quoted fake call, and build must not add it to taffish.toml.
    write(parent / "src/main.taf", '''<taffish>
[[taf: taf-inline-leaf-v0.1.0-r1 @step: 'x]] [[taf: taf-fake]]' ]]
echo ::(--/-i)input='[[taf: taf-default-fake]]'::
''')
    invoke([taf, "check"], cwd=parent)
    invoke([taf, "build"], cwd=parent)
    toml = (parent / "taffish.toml").read_text()
    assert "taf-fake" not in toml and "taf-default-fake" not in toml, toml


CASES = {
    "scalar-text": scalar_text,
    "block-roundtrip": block_roundtrip,
    "block-display": block_display,
    "argv-text": argv_text,
    "command-text": command_text,
    "nested-blocks": nested_blocks,
    "inline-boundaries": inline_boundaries,
    "inline-error-message": inline_error_message,
    "inline-separators": inline_separators,
    "inline-comments": inline_comments,
    "inline-projects": inline_projects,
    "inline-mcp": inline_mcp,
    "delayed-expression": delayed_expression,
    "empty-arguments": empty_arguments,
    "project-boundaries": project_boundaries,
}
CASES[CASE]()
