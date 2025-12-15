(defun my-sh-colon-function-font-lock ()
  "Font-lock Bash function names containing colons."
  (font-lock-add-keywords
   nil
   '(("^[ \t]*\\(?:function[ \t]+\\)?\\([[:alpha:]_][[:alnum:]_:-]*\\)[ \t]*()"
      1 font-lock-function-name-face))
   'append)
  (font-lock-flush))

(add-hook 'sh-mode-hook #'my-sh-colon-function-font-lock)
