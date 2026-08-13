;;; flutter-tools-run.el --- Run and reload flutter apps -*- lexical-binding: t; -*-

(require 'json)
(require 'eshell)
(require 'esh-mode)
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

(defun flutter-tools--get-process ()
  "Get the current flutter process running in Eshell."
  (let ((buf (get-buffer "*flutter-run*")))
    (when buf
      ;; Fallback backward compatibility for flutter-tools--process if needed elsewhere
      (setq flutter-tools--process (get-buffer-process buf)))))

;;;###autoload
(defun flutter-run (&optional device-id)
  "Start `flutter run' in a dedicated Eshell buffer at the project root.
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
         (args (if device-id (list "run" "-d" device-id) (list "run")))
         ;; Properly quote arguments in case executable path has spaces
         (cmd-string (mapconcat (lambda (arg)
                                  (if (fboundp 'eshell-quote-argument)
                                      (eshell-quote-argument arg)
                                    (shell-quote-argument arg)))
                                (cons flutter-bin args) " ")))

    ;; If the process is already running, just focus it
    (let ((existing-proc (flutter-tools--get-process)))
      (if (and existing-proc (process-live-p existing-proc))
          (progn
            (message "Flutter is already running.")
            (display-buffer (process-buffer existing-proc)))

        ;; Kill existing dead buffer to prevent creating *flutter-run*<2> or messing up Eshell state
        (when (get-buffer buf-name)
          (kill-buffer buf-name))

        ;; SPAWN ESHELL PROCESS
        (let* ((eshell-buffer-name buf-name)
               ;; Start Eshell in the background temporarily to avoid auto window layout changes
               (buf (save-window-excursion (eshell))))
          
          (with-current-buffer buf
            (goto-char (point-max))
            (insert cmd-string)
            ;; Simulates pressing "Enter" on the command string inside eshell
            (eshell-send-input)

            ;; Apply compilation mode for clickable errors in the Eshell buffer
            (setq-local compilation-error-regexp-alist
                        (append '(flutter-dart
                                  flutter-msbuild-error
                                  flutter-msbuild-warning)
                                compilation-error-regexp-alist))
            (compilation-shell-minor-mode 1))

          (display-buffer buf))))))

;;;###autoload
(defun flutter-hot-reload ()
  "Send the 'r' character to the active flutter process in Eshell."
  (interactive)
  (let ((proc (flutter-tools--get-process)))
    (if (and proc (process-live-p proc))
        (progn
          (process-send-string proc "r")
          (message "Sent hot reload to flutter..."))
      (message "Flutter is not currently running."))))

;;;###autoload
(defun flutter-reload-on-save ()
  "Trigger hot reload automatically when saving a dart file.
Add this to `after-save-hook'."
  (let ((proc (flutter-tools--get-process)))
    (when (and (eq major-mode 'dart-mode)
               proc
               (process-live-p proc))
      (flutter-hot-reload))))

(provide 'flutter-tools-run)
