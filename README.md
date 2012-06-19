jira2org
========

Convert a user's current open JIRA issues to Org-Mode format.
Calls the JIRA REST API.

Installation
------------

Add the directory jira2org.el is in to your load-path.
It's set in your .emacs, like this:

    (add-to-list 'load-path "~/.emacs.d/lisp/jira2org/")

Add the following to your .emacs startup file:

    (require 'jira2org)

or add the autoloads for the public command functions:

    (autoload 'j2o-export "jira2org" "Convert current JIRA issues" t)

Configuration
-------------

Configure the JIRA settings for your installation.  You'll need to
set at least the API root, username and password:

    M-x customize-group RET jira2org RET


Running
-------

    M-x j2o-export

Will make the web request, convert, and dump the results in `j2o-output-file`.
