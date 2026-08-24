;;; flutter-tools.el --- Flutter development tools -*- lexical-binding: t; -*-

(require 'flutter-tools-vars)
(require 'flutter-tools-compile)
(require 'flutter-tools-run)
(require 'flutter-tools-create)
(require 'flutter-tools-pub)

(add-hook 'after-save-hook #'flutter-reload-on-save)

(use-package dart-mode
  :ensure t)

(provide 'flutter-tools)
