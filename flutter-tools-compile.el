;;; flutter-tools-compile.el --- Compilation rules for flutter -*- lexical-binding: t; -*-

(require 'compile)
(require 'rx)

(eval-after-load 'compile
  '(progn
     ;; Dart Error (lib/main.dart:36:32: Error)
     (add-to-list 'compilation-error-regexp-alist-alist
		  `(flutter-dart
		    ,(rx line-start (zero-or-more space)
			 ;; Grp 1 (Link) & Grp 2 (File)
			 (group (group (+ (not (any ":\n"))) ".dart")
				":" (group (+ digit))  ; Grp 3 (Line)
				":" (group (+ digit))) ; Grp 4 (Col)
			 ":")
		    2 3 4 2 1))

     ;; Windows MSBuild/C++ Errors (file.targets(254,5): error)
     (add-to-list 'compilation-error-regexp-alist-alist
		  `(flutter-msbuild-error
		    ,(rx line-start (zero-or-more space)
			 ;; Grp 1 (Link) & Grp 2 (File)
			 (group (group (+? nonl)) 
				"(" (group (+ digit))  ; Grp 3 (Line)
				"," (group (+ digit))  ; Grp 4 (Col)
				")")
			 ":" (zero-or-more space) (regex "[Ee]rror"))
		    2 3 4 2 1))

     ;; Windows MSBuild/C++ Warnings (file.targets(254,5): warning)
     (add-to-list 'compilation-error-regexp-alist-alist
		  `(flutter-msbuild-warning
		    ,(rx line-start (zero-or-more space)
			 (group (group (+? nonl)) 
				"(" (group (+ digit)) 
				"," (group (+ digit)) ")")
			 ":" (zero-or-more space) (regex "[Ww]arning"))
		    2 3 4 1 1))))

(provide 'flutter-tools-compile)
