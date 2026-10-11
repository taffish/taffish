(defpackage :taffish.i18n
  (:use :cl)
  (:export
   :*default-language*
   :normalize-language
   :language-fallback-chain
   :resolve-language
   :resolve-language-details
   :available-languages
   :current-language
   :call-with-resolved-language
   :call-with-language
   :with-language
   :register-message
   :message
   :message-with
   :help-text
   :builtin-message-keys))
