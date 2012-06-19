;;; jira2org.el --- Convert JIRA project management issues to Org-Mode format.
;;
;; Copyright (C) 2012 Sasha Kovar
;;
;; Author: Sasha Kovar <sasha-emacs at arcocene dot org>
;; URL: https://github.com/abend/jira2org
;; Created: 2012-06-15
;; Version: 0.5
;; Keywords: jira, org-mode

;; This file is not part of GNU Emacs.

;;; License:
;;
;; GNU Emacs is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; GNU Emacs is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; Convert a user's current open JIRA issues to Org-Mode format.
;; Calls the JIRA REST API.

;;; Installation:
;;
;;  Add the directory jira2org.el is in to your load-path.
;;  It's set in your .emacs, like this:
;;    (add-to-list 'load-path "~/.emacs.d/lisp/jira2org/")
;;
;;  Add the following to your .emacs startup file:
;;    (require 'jira2org)
;;
;;  or add the autoloads for the public command functions:
;;    (autoload 'j2o-export "jira2org" "Convert current JIRA issues" t)

;;; Configuration:
;;
;;  Configure the JIRA settings for your installation.  You'll need to
;;  set at least the API root, username and password:
;;    M-x customize-group RET jira2org RET

;;; Running:
;;
;;    M-x j2o-export
;;  Will make the web request, convert, and dump the results in `j2o-output-file`.

(require 'json)


(defgroup jira2org nil
  "Import JIRA tasks to Org-Mode."
  :link '(emacs-library-link :tag "Source Lisp File" "jira2org.el")
  :group 'outlines)

(defcustom j2o-api-root nil
  "Base url for making API calls.  Paths like \"/rest/api/2/...\"
  will be appended to this.  Examples: http://localhost:8090,
https://mycompany.atlassian.net"
  :type 'string
  :group 'jira2org)

(defcustom j2o-auth-username nil
  "Username for basic authentication with the JIRA REST API."
  :type 'string
  :group 'jira2org)

(defcustom j2o-auth-password nil
  "Password for basic authentication with the JIRA REST API."
  :type 'string
  :group 'jira2org)

(defcustom j2o-output-file (expand-file-name "~/org/jira.org")
  "File to export to."
  :type 'file
  :group 'jira2org)

(defcustom j2o-output-preamble nil
  "Text to be included at the top of the exported file."
  :type 'string
  :group 'jira2org)

(defcustom j2o-issue-format
  ;; TODO project name and key, assignee displayName, issuetype name, description, priority name
  "* TODO {PROJECT-NAME}: {SUMMARY}
  {PRIORITY} {ISSUE-TYPE} for {ASSIGNEE}
  {DUE-DATE}
  {DESCRIPTION}
  {URL}"
  "String used to format an issue.
Syntax is {FIELD}.  Valid values for FIELD are: 
PRIORITY, ISSUE-TYPE, PROJECT-NAME, PROJECT-KEY, SUMMARY, ASSIGNEE,
DUE-DATE, URL, DESCRIPTION."
  :type 'string
  :group 'jira2org)


(defun j2o-export ()
  "Get the user's current list of issues from JIRA and convert to Org-Mode format."
  (interactive)
  (let ((issues (j2o-get-my-issues)))
    ;; NOTE if we need to fix coding system issues, see ical2org/convert-url
    (unwind-protect
         (save-current-buffer
           (find-file j2o-output-file)
           (erase-buffer)
           (when j2o-output-preamble
             (insert j2o-output-preamble)
             (newline 2))
           (dolist (i issues)
             (insert (j2o-format-issue i))
             (newline 2))
           (save-buffer)))))


(defun j2o-get-my-issues ()
  (mapcar 'j2o-simplify-issue (cdar (j2o-get-my-issues-data))))

(defun j2o-get-my-issues-data ()
  "Make a REST API request to get the user's open issues."
  (j2o-api-get "/rest/api/2/search" 
               `(("jql" . "assignee = currentUser() AND resolution = unresolved ORDER BY priority DESC, created ASC")
                 ("fields" . "summary,assignee,duedate,project,priority,description,issuetype")
                 ;;("maxResults" . ,(int-to-string max-results))
                 )))

(defun j2o-simplify-issue (issue)
  "Convert the structure of a raw JIRA issue to something we prefer."
  ;; TODO generalize based on what we get in the issue fields
  (let* ((key (j2o-cdas 'key issue))
         (fields (j2o-cdas 'fields issue))
         (summary (j2o-cdas 'summary fields))
         (description (j2o-cdas 'description fields))
         (project-name (j2o-cdas '(project name) fields))
         (project-key (j2o-cdas '(project key) fields))
         (summary (j2o-cdas 'summary fields))
         (assignee (j2o-cdas '(assignee displayName) fields))
         (priority (j2o-cdas '(priority name) fields))
         (issue-type (j2o-cdas '(issuetype name) fields))
         (due-date (j2o-cdas 'duedate fields)))
    (list (cons 'url (j2o-issue-url key))
          (cons 'key key)
          (cons 'summary summary)
          (cons 'description description)
          (cons 'project-name project-name)
          (cons 'project-key project-key)
          (cons 'assignee assignee)
          (cons 'priority priority)
          (cons 'issue-type issue-type)
          (cons 'due-date due-date))))

(defun j2o-format-issue (issue)
  "Stringify a simplified issue into Org-Mode format."
  (replace-regexp-in-string "\s-*[\r\n]+" "" ;; strip empty lines
     (replace-regexp-in-string "{.*?}"
                               (lambda (z) (let ((key (j2o-fix-key z)))
                                        (or (j2o-format-field key (j2o-cdas key issue)) "")))
                               j2o-issue-format
                               t t)
     nil t))

(defun j2o-fix-key (k)
  "Convert from \"{URL)\" to \"url\"."
  (intern (replace-regexp-in-string "[{}]" "" (downcase k))))

(defun j2o-format-field (key value)
  "Do any custom formatting of given issue fields."
  (when value
    (cond ((eq 'due-date key)
           (concat "<" value ">"))
          ((eq 'description key)
           (with-temp-buffer
             (erase-buffer)
             ;; (decode-coding-string
             ;;  (with-current-buffer buf
             ;;    (buffer-substring (1+ pos) (point-max)))
             ;;  'utf-8 nil dbuf)
             (insert value)
             ;;(fill-region (point-min) (- (point-max) 50) nil t)
             (set-text-properties (point-min) (point-max) nil)
             (buffer-string)))
          (t value))))

(defun j2o-issue-url (key)
  "Return a URL string for the issue's web page."
  (concat j2o-api-root "/browse/" key))

(defun j2o-api-get (path args)
  (let* ((url-request-method "GET")
         (url-request-extra-headers (list (cons "Authorization"
                                                (concat "Basic "
                                                        (base64-encode-string
                                                         (concat j2o-auth-username ":" j2o-auth-password))))))
         (query-parts (when args (append '("?") (mapcar (lambda (a) (concat (car a) "=" (url-hexify-string (cdr a)) "&")) args))))
         (url (apply 'concat (append (list j2o-api-root path) query-parts)))
         (url-cookie-untrusted-urls (list j2o-api-root)) ;; problem with cookies - but we don't need them
         header
         data
         status)
    (with-current-buffer
        (url-retrieve-synchronously url)
      (setq status url-http-response-status)
      (goto-char (point-min))
      (if (search-forward-regexp "^$" nil t)
          (setq header (buffer-substring (point-min) (point))
                data   (buffer-substring (1+ (point)) (point-max)))
          (setq data (buffer-string))))
    (values data header status)
    (json-read-from-string data)))

(defun j2o-cdas (keys list)
  (let ((keylist (if (listp keys) keys (list keys)))
        (value list))
    (dolist (key keylist value)
      (setq value (cdr (assoc key value))))))

(provide 'jira2org)
