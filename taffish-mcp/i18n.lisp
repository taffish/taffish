(in-package :taffish.mcp)

;;;; ============================================================
;;;; taffish-mcp / i18n.lisp
;;;; ============================================================

(defparameter *taffish-mcp-cli-help-en*
  "{version}

Usage:
  taffish-mcp
  taffish-mcp (-h | --help | help)
  taffish-mcp (-v | --version | version)

Purpose:
  Start the conservative TAFFISH MCP stdio server for AI clients.

Transport:
  stdio JSON-RPC. stdout is reserved for MCP messages; logs go to stderr.

Language:
  This human CLI help follows `taf config language` and TAFFISH_LANGUAGE.
  MCP tools, resources, prompts, schemas, and structured results stay English.

Safety:
  The server does not expose run, publish, container image build, or arbitrary
  shell execution. Compile tools return shell code without executing it.
")

(defparameter *taffish-mcp-cli-help-zh*
  "{version}

用法：
  taffish-mcp
  taffish-mcp (-h | --help | help)
  taffish-mcp (-v | --version | version)

用途：
  为 AI 客户端启动保守的 TAFFISH MCP stdio server。

传输：
  使用 stdio JSON-RPC。stdout 仅用于 MCP 消息，日志输出到 stderr。

语言：
  此人类 CLI help 遵循 `taf config language` 和 TAFFISH_LANGUAGE。
  MCP tools、resources、prompts、schema 和结构化结果始终保持英文。

安全：
  server 不暴露 run、publish、容器镜像构建或任意 shell 执行能力。
  compile tools 只返回 shell code，不会执行它。
")

(defun %get-taffish-mcp-cli-help-string ()
  (taffish.i18n:help-text
   "taffish-mcp" nil
   *taffish-mcp-cli-help-en*
   *taffish-mcp-cli-help-zh*
   (list (cons "version" *taffish-mcp-version*))))
