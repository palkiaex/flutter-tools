;;; flutter-tools-run.el --- Run and reload flutter apps -*- lexical-binding: t; -*-

(require 'json)
(require 'comint)
(require 'compile)
(require 'flutter-tools-vars)

(defun flutter-get-devices ()
  "Get a list of connected Flutter devices as (Name . ID) pairs."
  (let* ((output (shell-command-to-string "flutter devices --machine"))
         (json-array (json-read-from-string output)))
    (mapcar (lambda (device)
              (cons (alist-get 'name device)
                    (alist-get 'id device)))
            json-array)))

(defun flutter-run (&optional device-id)
  "Start `flutter run' in a dedicated buffer at the project root.
If multiple devices are connected, prompt the user to select one.
Remembers the selected device for future runs. Use a prefix argument 
(e.g., C-u M-x flutter-run) to force re-selecting a device."
  (interactive
   (list 
    ;; Check if we already have a saved device AND user didn't press C-u
    (if (and flutter-tools--last-device-id (not current-prefix-arg))
        flutter-tools--last-device-id
      ;; Otherwise, fetch devices and prompt if necessary
      (let ((devices (flutter-get-devices)))
        (cond
         ((= (length devices) 0) nil) ;; No devices
         ((= (length devices) 1)      ;; Exactly 1 device, just use it
          (cdr (car devices)))
         (t                           ;; > 1 device, prompt user
          (let ((choice (completing-read "Select device: " devices)))
            (cdr (assoc choice devices)))))))))
             
  ;; Save the chosen device for next time
  (when device-id
    (setq flutter-tools--last-device-id device-id))
    
  (let* ((buf-name "*flutter run*")
         (buf (get-buffer-create buf-name))
         (project-root (locate-dominating-file default-directory "pubspec.yaml"))
         ;; Fallback to current directory if not in a flutter project
         (root-dir (if project-root project-root default-directory)) 
         (default-directory root-dir)
         (args (if device-id 
                   (list "run" "-d" device-id) 
                 (list "run"))))
    
    (apply #'make-comint-in-buffer "flutter-run" buf "flutter.bat" nil args)

    (setq flutter-tools--process (get-buffer-process buf))
    
    (with-current-buffer buf
      ;; This ensures Emacs knows where `lib/main.dart` is relative to.
      (setq default-directory root-dir) 

      ;; Make the regex list local to THIS specific buffer
      (make-local-variable 'compilation-error-regexp-alist)
      ;; Put our custom rules at the very front of the local list
      (setq compilation-error-regexp-alist
            (append '(flutter-dart 
                      flutter-msbuild-error 
                      flutter-msbuild-warning)
                    compilation-error-regexp-alist))
      
      (compilation-shell-minor-mode 1)
      (ansi-color-for-comint-mode-on))
    
    (display-buffer buf)))

(defun flutter-hot-reload ()
  "send the 'r' character to the active flutter process."
  (interactive)
  (if (and flutter-tools--process (process-live-p flutter-tools--process))
      (progn
        (process-send-string flutter-tools--process "r")
        (message "sent hot reload to flutter..."))
    (message "flutter is not running.")))

(defun flutter-reload-on-save ()
  "trigger hot reload automatically when saving a dart file."
  (when (and (eq major-mode 'dart-mode)
             flutter-tools--process
             (process-live-p flutter-tools--process))
    (flutter-hot-reload)))

(provide 'flutter-tools-run)
