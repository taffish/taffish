(in-package :taffish.cli)

;;;; ============================================================
;;;; i18n.lisp
;;;; ============================================================

(defparameter *taffish-help-zh*
  "用法：
  taffish [-h | --help]           输出帮助并退出
  taffish [-v | --version]        输出版本并退出
  taffish [ARGS...]               从 STDIN 编译 TAFFISH 代码
  taffish <FILE.TAF> [ARGS...]    将 FILE.TAF 编译为 shell
  taffish -- [ARGS...]            从 STDIN 编译 TAFFISH 代码

细节：
  - 如果第一个参数是已有文件，TAFFISH 将读取该文件。
  - 否则 TAFFISH 从 STDIN 读取源码，并把参数作为 .taf 程序参数。
  - 生成的 shell 代码输出到 STDOUT。
  - TAFFISH_CONTAINER_BACKEND=apptainer|podman|docker 可强制通用
    <container:...> tag 使用指定后端，但不会覆盖显式后端 tag。
  - TAFFISH_DOCKER_RUN_ARGS、TAFFISH_PODMAN_RUN_ARGS 和
    TAFFISH_APPTAINER_RUN_ARGS 追加本地后端专用运行参数。
  - 运行 `taf config language` 查看语言，或用
    `taf config language zh` 选择内置中文。")

(declaim (ftype (function () string) %get-taffish-help-string-english))

(defun %get-taffish-help-string ()
  (taffish.i18n:help-text
   "taffish" nil
   (%get-taffish-help-string-english)
   *taffish-help-zh*))

(taffish.i18n:register-message
 "taffish.cli.command-missing"
 "Command missing!"
 "缺少命令！")

(defun %taffish-command-missing-message ()
  (taffish.i18n:message "taffish.cli.command-missing"))
