;;; flutter-tools-utils.el --- Utilities functions for flutter-tools -*- lexical-binding: t; -*-

(defun flutter-tools--get-executable ()
  "Return the appropriate flutter executable, handling Windows differences."
  (if (executable-find "flutter.bat") "flutter.bat" "flutter"))

(provide 'flutter-tools-utils)
