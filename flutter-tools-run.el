;;; flutter-tools-run.el --- Run and reload flutter apps -*- lexical-binding: t; -*-

(require 'json)
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
          (cdar devices)) ;; `cdar` gets the ID of the first (and only) pair
         (t 
          (let ((choice (completing-read "Select device: " devices nil t)))
            (cdr (assoc choice devices)))))))))
             
  (when device-id
    (setq flutter-tools--last-device-id device-id))
    
  (let* ((project-root (or (locate-dominating-file default-directory "pubspec.yaml")
                           default-directory))
         ;; Temporarily set default-directory so the comint buffer inherits it correctly
         (default-directory project-root)
         (flutter-bin (flutter-tools--get-executable))
         (buf (get-buffer-create "*flutter run*"))
         (args (if device-id (list "run" "-d" device-id) (list "run"))))
    
    ;; Create the process using the cross-platform executable
    (apply #'make-comint-in-buffer "flutter-run" buf flutter-bin nil args)
    (setq flutter-tools--process (get-buffer-process buf))
    
    (with-current-buffer buf
      ;; setq-local is the modern, idiomatic replacement for make-local-variable + setq
      (setq-local compilation-error-regexp-alist
                  (append '(flutter-dart 
                            flutter-msbuild-error 
                            flutter-msbuild-warning)
                          compilation-error-regexp-alist))
      
      (compilation-shell-minor-mode 1)
      (ansi-color-for-comint-mode-on))
    
    (display-buffer buf)))

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
