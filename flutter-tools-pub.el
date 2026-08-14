;;; flutter-tools-pub.el --- Run flutter pub related commands -*- lexical-binding: t; -*-

(require 'compile)
(require 'flutter-tools-vars)
(require 'flutter-tools-utils)

;;; --- Internal Helpers ---

(defun flutter-tools--pub-buffer-name (_mode)
  "Generate the buffer name for flutter pub compilation."
  "*flutter-pub*")

(defun flutter-tools--run-pub-command (args)
  "Run a flutter pub command with ARGS at the project root."
  (let* ((project-root (or (locate-dominating-file default-directory "pubspec.yaml")
                           default-directory))
         (default-directory project-root)
         (flutter-bin (flutter-tools--get-executable))
         ;; Build the full command: flutter pub <args>
         (cmd-list (append (list flutter-bin "pub") args))
         (cmd-string (mapconcat #'shell-quote-argument cmd-list " "))
         ;; Force the compile buffer to have our custom name
         (compilation-buffer-name-function #'flutter-tools--pub-buffer-name))
    
    (compile cmd-string)))


;;; --- Interactive Commands ---

;;;###autoload
(defun flutter-pub-get ()
  "Run `flutter pub get` to fetch dependencies in the current project."
  (interactive)
  (flutter-tools--run-pub-command '("get")))

;;;###autoload
(defun flutter-pub-upgrade ()
  "Run `flutter pub upgrade` to upgrade dependencies to their latest compatible versions."
  (interactive)
  (flutter-tools--run-pub-command '("upgrade")))

;;;###autoload
(defun flutter-pub-outdated ()
  "Run `flutter pub outdated` to analyze dependencies for newer versions."
  (interactive)
  (flutter-tools--run-pub-command '("outdated")))

;;;###autoload
(defun flutter-pub-add (package)
  "Run `flutter pub add` to add a new PACKAGE dependency.
Prompts for the package name."
  (interactive "sPackage to add (e.g. provider): ")
  (if (string-empty-p package)
      (message "No package provided.")
    (flutter-tools--run-pub-command (list "add" package))))

;;;###autoload
(defun flutter-pub-remove (package)
  "Run `flutter pub remove` to remove an existing PACKAGE dependency.
Prompts for the package name."
  (interactive "sPackage to remove: ")
  (if (string-empty-p package)
      (message "No package provided.")
    (flutter-tools--run-pub-command (list "remove" package))))

;;;###autoload
(defun flutter-pub-cache-clean ()
  "Run `flutter pub cache clean` to clear the global pub cache."
  (interactive)
  (when (y-or-n-p "Are you sure you want to clean the global pub cache? ")
    (flutter-tools--run-pub-command '("cache" "clean"))))

(provide 'flutter-tools-pub)
;;; flutter-tools-pub.el ends here
