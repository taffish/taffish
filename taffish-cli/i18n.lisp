(in-package :taffish.cli)

;;;; ============================================================
;;;; i18n.lisp
;;;; ============================================================

(defparameter *taffish-help-zh*
  "将 TAF 源码编译为 POSIX shell，输出到标准输出，不执行。

用法：
  taffish <FILE.TAF> [ARGS...]
  taffish [ARGS...]
  taffish -- [ARGS...]
  taffish [-h | --help]
  taffish [-v | --version]

输入：
  编译时，首参数为已存在的普通文件，则从该文件读取源码。
  否则从标准输入读取源码，全部参数交给 TAF 程序。
  注意：文件名不存在时也会读取标准输入，可能等待输入。
  开头的 -- 强制从标准输入读取，并转交后续参数。

容器设置：
  TAFFISH_CONTAINER_BACKEND
    可选：apptainer、podman、docker；未设置时自动选择可用后端。
    仅影响 <container:...>，不覆盖显式指定后端的标签。

  TAFFISH_DOCKER_RUN_ARGS        追加 Docker 运行参数
  TAFFISH_PODMAN_RUN_ARGS        追加 Podman 运行参数
  TAFFISH_APPTAINER_RUN_ARGS     追加 Apptainer 运行参数

示例：
  taffish example.taf > example.sh
  taffish -- < example.taf > example.sh
  TAFFISH_CONTAINER_BACKEND=podman taffish example.taf > example.sh

语言：
  taf config language         查看当前语言及可用语言
  taf config language zh      切换中文；en 为英文，auto 跟随系统 [默认]

更多信息：
  官网：https://taffish.com
  Hub：https://taffish.github.io/
  支持：support@taffish.com")

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
