;;; flutter-tools-run.el --- Run and reload flutter apps -*- lexical-binding: t; -*-

(require 'json)
(require 'term)
(require 'comint)
(require 'compile)
(require 'flutter-tools-vars)
(require 'flutter-tools-utils)

(defun flutter-tools--get-devices ()
  "Get a list of connected Flutter devices as (Name . ID) pairs."
  (let* ((flutter-bin (flutter-tools--get-executable))
         (cmd (format "%s devices --machine" flutter-bin))
         (output (shell-command-to-string cmd))
         (json-array (json-read-from-string output)))
    (mapcar (lambda (device)
              (cons (alist-get 'name device)
                    (alist-get 'id device)))
            json-array)))

;;;###autoload
(defun flutter-run (&optional device-id)
  "Start `flutter run' in a dedicated buffer at the project root.
If multiple devices are connected, prompt the user to select one.
Remembers the selected device for future runs. Use a prefix argument
(e.g., C-u M-x flutter-run) to force re-selecting a device."
  (interactive
   (list
    (if (and flutter-tools--last-device-id (not current-prefix-arg))
        flutter-tools--last-device-id
      (let ((devices (flutter-tools--get-devices)))
        (cond
         ((null devices)
          (message "No Flutter devices found.")
          nil)
         ((= (length devices) 1)
          (cdar devices))
         (t
          (let ((choice (completing-read "Select device: " devices nil t)))
            (cdr (assoc choice devices)))))))))

  (when device-id
    (setq flutter-tools--last-device-id device-id))

  (let* ((project-root (or (locate-dominating-file default-directory "pubspec.yaml")
                           default-directory))
         (default-directory project-root)
         (flutter-bin (flutter-tools--get-executable))
         (buf-name "*flutter-run*")
         (args (if device-id (list "run" "-d" device-id) (list "run"))))

    ;; If the process is already running, just focus it
    (if (and flutter-tools--process (process-live-p flutter-tools--process))
        (progn
          (message "Flutter is already running.")
          (display-buffer (process-buffer flutter-tools--process)))

      ;; Kill existing dead buffer to prevent creating *flutter-run*<2>
      (when (get-buffer buf-name)
        (kill-buffer buf-name))

      ;; OS-AWARE PROCESS SPAWNING
      (let ((buf
             (if (eq system-type 'windows-nt)
                 ;; WINDOWS: Fallback to comint (Native Windows lacks PTY support)
                 (let ((b (get-buffer-create buf-name)))
                   (apply #'make-comint-in-buffer "flutter-run" b flutter-bin nil args)
                   (with-current-buffer b
                     (ansi-color-for-comint-mode-on))
                   b)
               ;; LINUX/macOS: Use term for true terminal emulation
               (let ((b (apply #'make-term "flutter-run" flutter-bin nil args)))
                 (with-current-buffer b
                   (term-mode)
                   (term-char-mode))
                 b))))

        (setq flutter-tools--process (get-buffer-process buf))

        ;; Apply compilation mode for clickable errors in both term & comint
        (with-current-buffer buf
          (setq-local compilation-error-regexp-alist
                      (append '(flutter-dart
                                flutter-msbuild-error
                                flutter-msbuild-warning)
                              compilation-error-regexp-alist))
          (compilation-shell-minor-mode 1))

        (display-buffer buf)))))

;;;###autoload
(defun flutter-hot-reload ()
  "Send the 'r' character to the active flutter process."
  (interactive)
  (if (and flutter-tools--process (process-live-p flutter-tools--process))
      (progn
        (process-send-string flutter-tools--process "r")
        (message "Sent hot reload to flutter..."))
    (message "Flutter is not currently running.")))

;;;###autoload
(defun flutter-reload-on-save ()
  "Trigger hot reload automatically when saving a dart file.
Add this to `after-save-hook'."
  (when (and (eq major-mode 'dart-mode)
             flutter-tools--process
             (process-live-p flutter-tools--process))
    (flutter-hot-reload)))

(provide 'flutter-tools-run)
