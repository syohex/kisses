;;; kisses.el --- Keep It Simple Stupid Emacs Splash screen -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2021 Justin Silverman
;;
;; Author: Justin Silverman <https://github.com/jsilve24>
;; Maintainer: Justin Silverman <jsilve24@gmail.com>
;; Created: 2021-11-26
;; Modified: 2021-11-26
;; Version: 0.0.1
;; Keywords: 
;; Homepage: https://github.com/jsilve24/kisses
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;; 
;; This is a simple library that creates a splash buffer with `kisses-banner'
;; centered vertically and horizontally. See git readme for more details. 
;;
;;; Code:

(require 'dash)

;; Calculate dimensions of largest monitor
;; hack -- for the moment just specify some large value
(defvar kisses--max-rows 300
  "Maximum number of rows a window can have")

(defvar kisses--max-columns 500
  "Maximum number of columns a window can have")


(defvar kisses-banner
  "@@@@@@@@  @@@@@@@@@@    @@@@@@    @@@@@@@   @@@@@@   
@@@@@@@@  @@@@@@@@@@@  @@@@@@@@  @@@@@@@@  @@@@@@@   
@@!       @@! @@! @@!  @@!  @@@  !@@       !@@       
!@!       !@! !@! !@!  !@!  @!@  !@!       !@!       
@!!!:!    @!! !!@ @!@  @!@!@!@!  !@!       !!@@!!    
!!!!!:    !@!   ! !@!  !!!@!!!!  !!!        !!@!!!   
!!:       !!:     !!:  !!:  !!!  :!!            !:!  
:!:       :!:     :!:  :!:  !:!  :!:           !:!   
:: ::::   :::     ::   ::   :::   ::: :::  :::: ::   
: :: ::    :      :     :   : :   :: :: :  :: : :    
"
  "Banner to display on startup.")

(defvar kisses--box-dimensions nil
  "Variable used to store dimensions (rows columns) of banner text.")

;; calculate width of input text
(defun kisses--banner-box-dimenions ()
  "Returns list (row col) giving dimensions of bounding box of
  kisses-banner."
  (let* ((strings (split-string kisses-banner "\n"))
	 (string-lengths (-map 'length strings))
	 (ncol (apply 'max string-lengths))
	 (nrow (length strings)))
    (setq kisses--box-dimensions (list nrow ncol))))

(defvar kisses--insertion-point nil
  "Variable used to store insertion point of upper left point of banner.")

(defun kisses--set-local-vars ()
  "Internal function used to set all the local variables for the mode."
  (display-line-numbers-mode 0)
  (if truncate-lines
      (toggle-truncate-lines 1))
  (visual-line-mode -1)
  (setq-local auto-hscroll-mode nil)
  (setq-local hscroll-margin 0)
  (setq left-fringe-width 0)
  (setq right-fringe-width 0)
  (set-display-table-slot standard-display-table 'truncation 32)
  (set-window-buffer (selected-window) (get-buffer "*splash*"))
  (setq cursor-type nil)
  (face-remap-add-relative 'region '(:inherit default))
  (if (fboundp 'evil-mode)
      (setq-local evil-normal-state-cursor nil)
      (setq-local evil-emacs-state-cursor nil)
    (setq-local cursor-type nil)))

(define-derived-mode kisses-mode
  fundamental-mode "KISSES"
  "Major mode for showing custom splash screen."
  ;; bit of setup to make display nice
  (kisses--set-local-vars))

;; make buffer of size equal to largest monitor store center of text coordinates 
(defun kisses--make-splash-buffer ()
  "Creates buffer of dimension `kisses--max-columns' and `kisses--max-rows' and places the
banner at the center. Also checks to see if buffer named *splash* already exists and if so overwrites it"
  (unless kisses--box-dimensions
    (kisses--banner-box-dimenions))
  (let* ((splash-buffer (get-buffer-create "*splash*"))
	 (height (/ kisses--max-rows 2))
	 (width (/ kisses--max-columns 2))
	 (box-top (/ (car kisses--box-dimensions) 2))
	 (box-left (/ (nth 1 kisses--box-dimensions) 2))
	 (padding-top (- height box-top))
	 (padding-left (- width box-left))
	 (top-pad-string (concat (make-string kisses--max-columns ?\s) "\n")))
    (switch-to-buffer splash-buffer)
    (read-only-mode -1)
    (kisses--set-local-vars)
    (if (string= major-mode "kisses-mode")
	(erase-buffer)
      nil)
    (dotimes (_ padding-top) (insert top-pad-string))
    (let ((tmp-point (point))
	  (indent-tabs-mode nil))
      (insert kisses-banner)
      (mark-paragraph)
      (indent-region (point) (mark) padding-left)
      (goto-char (point))
      (re-search-forward "[^\s\n]")
      (backward-char)
      (setq kisses--insertion-point (point))
      (deactivate-mark)
      (read-only-mode 1)
      (kisses-mode)
      (get-buffer "*splash*"))))


(defun kisses--set-window-start (window)
  "Set window start to center banner in `window'."
  ;; look at set-window-start function
  (let* ((height (window-body-height nil))
	 (width (window-total-width nil))
	 (box-top (/ (nth 0 kisses--box-dimensions) 2))
	 (box-left (/ (nth 1 kisses--box-dimensions) 2))
	 (calling-window (selected-window)))
    (select-window window)
    (kisses--set-local-vars)
    ;; now acctually set window start
    (goto-char kisses--insertion-point)
    (set-window-start (selected-window) (point) nil)
    (scroll-left (- (current-column) (window-hscroll)))
    (scroll-down (+ 1 (- (/ height 2) box-top)))
    (scroll-right (- (/ width 2) box-left))
    (select-window calling-window)))


(defun kisses-redraw ()
  (interactive)
  "Fix up buffer and recenter."
  (kisses--make-splash-buffer)
  (kisses--set-window-start (selected-window)))


(defun kisses-recenter ()
  (interactive)
  "Fix up buffer and recenter."
  (kisses--set-window-start (selected-window)))

(defun kisses-initial-buffer ()
  "Function designed to be called by initial buffer."
  (kisses-redraw)
  (get-buffer "*splash*"))

(defun kisses-window-size-change-function (arg)
  "Funtion to run on window size change."
  ;; get list of windows displaying "*splash*"
  (when (get-buffer "*splash*")
    ;; (if (string= major-mode "kisses-mode")
    ;; 	(kisses--set-window-start (selected-window)))
    (let ((w-to-update (get-buffer-window-list "*splash*" nil (selected-frame))))
      (-map 'kisses--set-window-start w-to-update))
    ))

;; bit of setup to make redisplay nice
(add-hook 'window-size-change-functions 'kisses-window-size-change-function)

;; (add-hook 'window-size-change-functions (lambda (arg) (message "size change detected")))
;; (add-hook 'window-startup-hook 'kisses-window-size-change-function)

(provide 'kisses)
