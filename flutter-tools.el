;;; flutter-tools.el --- Flutter development tools -*- lexical-binding: t; -*-

(require 'flutter-tools-vars)
(require 'flutter-tools-compile)
(require 'flutter-tools-run)
(require 'flutter-tools-create)

(add-hook 'after-save-hook #'flutter-reload-on-save)

(provide 'flutter-tools)
