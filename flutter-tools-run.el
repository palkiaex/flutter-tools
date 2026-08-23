;;; flutter-tools-run.el --- Run and reload flutter apps -*- lexical-binding: t; -*-

(require 'json)
(require 'comint)
(require 'eshell)
(require 'esh-mode)
(require 'compile)
(require 'flutter-tools-vars)
(require 'flutter-tools-utils)

;;; --- Device Management ---

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

(defun flutter-tools--select-device (&optional force-prompt)
  "Prompt the user to select a Flutter device.
If FORCE-PROMPT is nil and `flutter-tools--last-device-id` is set,
returns the last used device."
  (if (and flutter-tools--last-device-id (not force-prompt))
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
          (cdr (assoc choice devices))))))))


;;; --- Process Management ---

(defun flutter-tools--get-process ()
  "Get the current flutter process running in Eshell or Comint."
  (let ((buf (get-buffer "*flutter-run*")))
    (when buf
      ;; Fallback backward compatibility for flutter-tools--process if needed elsewhere
      (setq flutter-tools--process (get-buffer-process buf)))))

(defun flutter-tools--setup-compilation-mode ()
  "Apply compilation shell minor mode and error regexes to the current buffer."
  (setq-local compilation-error-regexp-alist
              (append '(flutter-dart
                        flutter-msbuild-error
                        flutter-msbuild-warning)
                      compilation-error-regexp-alist))
  (compilation-shell-minor-mode 1))

(defun flutter-tools--start-comint (buf-name flutter-bin args)
  "Start the flutter process using comint (used for Windows).
Returns the created buffer."
  (let ((buf (get-buffer-create buf-name)))
    (with-current-buffer buf
      (apply #'make-comint-in-buffer "flutter-run" buf flutter-bin nil args)
      (flutter-tools--setup-compilation-mode))
    buf))

(defun flutter-tools--start-eshell (buf-name flutter-bin args)
  "Start the flutter process using Eshell (used for macOS/Linux).
Returns the created buffer."
  (let* ((eshell-buffer-name buf-name)
         ;; Properly quote arguments in case executable path has spaces
         (cmd-string (mapconcat (lambda (arg)
                                  (if (fboundp 'eshell-quote-argument)
                                      (eshell-quote-argument arg)
                                    (shell-quote-argument arg)))
                                (cons flutter-bin args) " "))
         ;; Start Eshell in the background temporarily
         (buf (save-window-excursion (eshell))))
    (with-current-buffer buf
      (goto-char (point-max))
      (insert cmd-string)
      ;; Simulates pressing "Enter" on the command string inside eshell
      (eshell-send-input)
      (flutter-tools--setup-compilation-mode))
    buf))

(defun flutter-tools--clean-environment (env)
  "Return a copy of ENV without Command Line Tools compiler/linker flags."
  (let ((bad-vars '("CC" "CXX" "LD" "AR" "RANLIB"
                    "LIBRARY_PATH" "DYLD_LIBRARY_PATH"
                    "DYLD_FALLBACK_LIBRARY_PATH")))
    (seq-remove (lambda (entry)
                  (let ((var-name (car (split-string entry "="))))
                    (and (member var-name bad-vars)
                         (string-match-p "CommandLineTools" entry))))
                env)))

;;; --- Interactive Commands ---

(defun flutter-tools--run-internal (device-id &optional extra-args)
  "Internal function to start flutter run.
DEVICE-ID is the target device. EXTRA-ARGS is a list of additional
arguments (e.g., '(\"--release\")) to pass to the flutter command."
  (when device-id
    (setq flutter-tools--last-device-id device-id))

  (let* ((process-environment (if (eq system-type 'darwin)
                                  (flutter-tools--clean-environment process-environment)
                                process-environment))
         (project-root (or (locate-dominating-file default-directory "pubspec.yaml")
                           default-directory))
         (default-directory project-root)
         (flutter-bin (flutter-tools--get-executable))
         (buf-name "*flutter-run*")
         (base-args (if device-id (list "run" "-d" device-id) (list "run")))
         (args (append base-args extra-args))
         (existing-proc (flutter-tools--get-process)))

    ;; Check if process is already running
    (if (and existing-proc (process-live-p existing-proc))
        (progn
          (message "Flutter is already running.")
          (display-buffer (process-buffer existing-proc)))

      ;; Cleanup dead buffer if it exists
      (when (get-buffer buf-name)
        (kill-buffer buf-name))

      ;; Start new process based on OS
      (let ((buf (if (eq system-type 'windows-nt)
                     (flutter-tools--start-comint buf-name flutter-bin args)
                   (flutter-tools--start-eshell buf-name flutter-bin args))))
        (display-buffer buf)))))

;;;###autoload
(defun flutter-run (&optional device-id)
  "Start `flutter run` at the project root.
On Windows, uses comint. On Linux/macOS, uses a dedicated Eshell buffer.
If multiple devices are connected, prompt the user to select one.
Remembers the selected device for future runs. Use a prefix argument
(e.g., C-u M-x flutter-run) to force re-selecting a device."
  (interactive (list (flutter-tools--select-device current-prefix-arg)))
  (flutter-tools--run-internal device-id nil))

;;;###autoload
(defun flutter-run-release (&optional device-id)
  "Start `flutter run --release` at the project root.
Shares the same device selection and process management as `flutter-run`."
  (interactive (list (flutter-tools--select-device current-prefix-arg)))
  (flutter-tools--run-internal device-id '("--release")))

;;;###autoload
(defun flutter-hot-reload ()
  "Send the 'r' character to the active flutter process."
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
