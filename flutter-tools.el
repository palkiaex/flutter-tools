(defvar my-flutter-process nil
  "The active flutter run process.")

(defun my-flutter-run ()
  "Start `flutter run' in a dedicated, colored, clickable buffer."
  (interactive)
  (let* ((buf-name "*Flutter Run*")
         (buf (get-buffer-create buf-name)))

    (with-current-buffer buf
      (comint-mode)
      (compilation-shell-minor-mode 1)

      ;; Make sure comint's own carriage-return handling is active.
      ;; This is what makes a bare \r overwrite the current line
      ;; instead of appending to it -- it's what collapses Flutter's
      ;; spinner frames down to one visible frame, the same way a
      ;; real terminal would. It's nil (on) by default, but setting
      ;; it explicitly guards against something else having flipped it.
      (setq-local comint-inhibit-carriage-motion nil)

      ;; Strip ALL terminal movement/clearing codes, but LEAVE colors (m)
      ;; This matches ESC [ followed by numbers/semicolons, ending in any letter EXCEPT 'm'
      (add-hook 'comint-preoutput-filter-functions
                (lambda (string)
                  (replace-regexp-in-string "\033\\[[0-9;]*[a-ln-zA-Z]" "" string))
                nil t)

      ;; Explicitly force Emacs to parse the remaining color/bold codes (like [1m and [31m)
      (require 'ansi-color)
      (add-hook 'comint-output-filter-functions 'ansi-color-process-output nil t)

      ;; Clean up carriage returns (\r)
      (add-hook 'comint-output-filter-functions 'comint-strip-ctrl-m nil t)

      (erase-buffer))
    ;; Set environment variables to FORCE colors
    (let ((process-environment (copy-sequence process-environment)))
      (setenv "FORCE_COLOR" "1")
      (setenv "TERM" "xterm-256color")

      (when (and my-flutter-process (process-live-p my-flutter-process))
        (kill-process my-flutter-process))
      (setq my-flutter-process
            (make-process
             :name "flutter-run"
             :buffer buf
             ;; Start the process
             :command '("flutter" "run")
             :connection-type 'pty
             ;; Without this, Emacs uses its plain default
             ;; filter, which just inserts raw bytes and never runs
             ;; any of the comint-*-filter-functions hooks above.
             :filter #'comint-output-filter)))

    (display-buffer buf)))

(defun my-flutter-hot-reload ()
  "Send the 'r' character to the active flutter process."
  (interactive)
  (if (and my-flutter-process (process-live-p my-flutter-process))
      (progn
        ;; Send the raw 'r' character (no Enter key needed)
        (process-send-string my-flutter-process "r")
        (message "Sent Hot Reload to Flutter..."))
    (message "Flutter is not running.")))

;; The auto-save hook
(defun my-flutter-reload-on-save ()
  "Trigger hot reload automatically when saving a Dart file."
  ;; Only trigger if we are in dart-mode AND the process is actually running
  (when (and (eq major-mode 'dart-mode)
             my-flutter-process
             (process-live-p my-flutter-process))
    (my-flutter-hot-reload)))

;; Attach the hook globally (it filters itself based on major-mode)
(add-hook 'after-save-hook #'my-flutter-reload-on-save)

(provide 'flutter-tools)
