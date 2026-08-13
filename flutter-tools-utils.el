;;; flutter-tools-utils.el --- Utilities for flutter-tools -*- lexical-binding: t; -*-

(defun flutter-tools--get-executable ()
  "Return the flutter executable based on the OS.
Falls back to the string name if not found in `exec-path'."
  (let ((exe-name (if (eq system-type 'windows-nt) 
                      "flutter.bat" 
                    "flutter")))
    exe-name))

(provide 'flutter-tools-utils)
