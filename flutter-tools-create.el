;;; flutter-tools-create.el --- Create flutter projects -*- lexical-binding: t; -*-

(require 'dired)
(require 'flutter-tools-utils)

(defun flutter-tools--open-project (name dir template)
  "Navigate to the newly created flutter project at DIR.
Opens dired and attempts to open the main dart file based on the TEMPLATE and NAME."
  (when (y-or-n-p (format "Project '%s' created! Navigate to it? " name))
    (dired dir)
    (let* ((filename (if (string= template "app") 
                         "main.dart" 
                       (format "%s.dart" name)))
           (main-file (expand-file-name (concat "lib/" filename) dir)))
      (when (file-exists-p main-file)
        (find-file main-file)))))

(defun flutter-tools--create-sentinel (process event)
  "Callback executed when the flutter create PROCESS changes state (EVENT)."
  (let ((name     (process-get process 'fc-name))
        (dir      (process-get process 'fc-dir))
        (template (process-get process 'fc-template)))
    
    (if (string-match-p "finished" event)
        (progn
          (message "Flutter project '%s' created successfully." name)
          (flutter-tools--open-project name dir template))
      (message "Flutter create exited with: %s" (string-trim event)))))

;;;###autoload
(defun flutter-create (type-choice parent-dir name)
  "Create a new Flutter application or library.
Prompts for project type, directory, and name, runs `flutter create` asynchronously,
and optionally navigates to the newly created project directory."
  ;; Gather user input using the interactive spec
  (interactive
   (list
    (completing-read "Project type: " '("application" "library") nil t)
    (read-directory-name "Select parent directory: ")
    (read-string "Project name (e.g. my_cool_app): ")))

  (let* ((template (if (string= type-choice "application") "app" "package"))
         (project-dir (expand-file-name name parent-dir))
         (flutter-bin (flutter-tools--get-executable))
         (buf-name (format "*flutter create %s*" name))
         (output-buf (get-buffer-create buf-name)))

    ;; UI Feedback
    (message "Creating %s '%s' in %s..." type-choice name project-dir)
    (display-buffer output-buf)

    ;; Start the async process
    (let ((proc (make-process
                 :name "flutter-create-process"
                 :buffer output-buf
                 :command (list flutter-bin "create" "--template" template project-dir)
                 :sentinel #'flutter-tools--create-sentinel)))
      
      ;; Store metadata on the process object for the sentinel to use
      (process-put proc 'fc-name name)
      (process-put proc 'fc-dir project-dir)
      (process-put proc 'fc-template template))))

(provide 'flutter-tools-create)
