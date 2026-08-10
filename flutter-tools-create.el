;;; flutter-tools-create.el --- Create flutter projects -*- lexical-binding: t; -*-

(require 'dired)

(defun flutter-create ()
  "Create a new Flutter application or library.
Prompts for project type, directory, and name, runs `flutter create` asynchronously,
and optionally navigates to the newly created project directory."
  (interactive)
  (let* ((type-choice (completing-read "Project type: " '("application" "library") nil t))
         (template (if (string= type-choice "application") "app" "package"))
         (parent-dir (read-directory-name "Select parent directory: "))
         (name (read-string "Project name (e.g. my_cool_app): "))
         (project-dir (expand-file-name name parent-dir))
         (flutter-bin (if (executable-find "flutter.bat") "flutter.bat" "flutter"))
         (buf-name (format "*flutter create %s*" name))
         
         (proc (make-process
                :name "flutter-create-process"
                :buffer buf-name
                :command (list flutter-bin "create" "--template" template project-dir)
                :sentinel
                (lambda (process event)
                  (let ((p-name (process-get process 'fc-name))
                        (p-dir (process-get process 'fc-dir))
                        (p-template (process-get process 'fc-template)))
                    
                    (if (string-match-p "finished" event)
                        (progn
                          (message "Flutter project created successfully.")
                          (when (y-or-n-p (format "Project '%s' created! Navigate to it? " p-name))
                            (dired p-dir)
                            (let ((main-file (expand-file-name 
                                              (if (string= p-template "app") 
                                                  "lib/main.dart" 
                                                (format "lib/%s.dart" p-name)) 
                                              p-dir)))
                              (when (file-exists-p main-file)
                                (find-file main-file)))))
                      (message "Flutter create exited with: %s" event)))))))

    (process-put proc 'fc-name name)
    (process-put proc 'fc-dir project-dir)
    (process-put proc 'fc-template template)

    (display-buffer (get-buffer-create buf-name))
    (message "Creating %s '%s' in %s..." type-choice name project-dir)))

(provide 'flutter-tools-create)
