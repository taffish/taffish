(in-package :taffish.core)

;;;; ============================================================
;;;; model.lisp
;;;; ============================================================

(defstruct taf-token
  raw-string  ;; 原始文本，例如 "--threads=8"、"::name::"、"<docker:...>"
  value       ;; 规范化后的值，第一版可先和 raw-string 一致，后续再按 kind 分化
  kind        ;; 第一版仅接受 :text | :arg
  line        ;; token 起始行号，从 1 开始
  column)     ;; token 起始列号，从 1 开始

(defstruct taf-line
  raw-string   ;; 该行原始文本
  tokens       ;; taf-token 列表
  kind         ;; :empty | :comment | :tag | :code
  subkind      ;; nil | :args | :run | :subtag
  line-number) ;; 行号，从 1 开始

(defstruct taf-context
  user
  homedir
  workdir    ;; 运行上下文，不属于用户 args，而属于宿主/调用环境
  loaddir
  argv
  cmd
  cpus       ;; 未来留扩展口，支持更多上下文键值
  container  ;; config 之 container
  extras)

(defstruct taf-program
  source-string  ;; 原始 taf 源码字符串
  lines          ;; taf-line 列表，保留行级语义
  args-spec      ;; 从脚本中抽取出的统一参数规范
  body           ;; 程序主体的静态语义表示，第一版可以先放 taf-line 列表、节点列表，后续再细化
  metadata)      ;; 预留元信息，例如脚本级 tag、注释提取结果、版本等

(defstruct taf-result
  program       ;; 绑定前的静态程序
  args-result   ;; han.args:bind-args + builtin-bindings(taf-context) 的结果
  context       ;; 本次运行上下文
  body          ;; 绑定后的程序主体，第一版可以先和 program.body 同构，后续逐步变成更实例化的表示
  diagnostics)  ;; 诊断信息，先允许自由列表，后续可统一结构

(define-condition taffish-error (error)
  ((message
    :initarg :message
    :reader taffish-error-message)
   (line
    :initarg :line
    :initform nil
    :reader taffish-error-line)
   (column
    :initarg :column
    :initform nil
    :reader taffish-error-column)
   (source-string
    :initarg :source-string
    :initform nil
    :reader taffish-error-source-string))
  (:report
   (lambda (condition stream)
     (format stream "~A" (taffish-error-message condition)))))

(defun signal-taffish-error (message &key line column source-string)
  (error 'taffish-error
         :message message
         :line line
         :column column
         :source-string source-string))
