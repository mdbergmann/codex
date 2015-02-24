(defsystem codex
  :author "Fernando Borretti <eudoxiahp@gmail.com>"
  :maintainer "Fernando Borretti <eudoxiahp@gmail.com>"
  :license "MIT"
  :version "0.1"
  :homepage "https://github.com/CommonDoc/codex"
  :bug-tracker "https://github.com/CommonDoc/codex/issues"
  :source-control (:git "git@github.com:CommonDoc/codex.git")
  :depends-on (:common-doc
               :quickdocs-parser
               :trivial-types
               :vertex
               :common-html
               :codex-templates)
  :components ((:module "src"
                :serial t
                :components
                ((:file "package")
                 (:file "error")
                 (:file "markup")
                 (:file "macro")
                 (:file "macroexpansion")
                 (:file "index")
                 (:file "parser")
                 (:file "manifest")
                 (:file "build")
                 (:file "codex"))))
  :description "A documentation system for Common Lisp."
  :long-description
  #.(uiop:read-file-string
     (uiop:subpathname *load-pathname* "README.md"))
  :in-order-to ((test-op (test-op codex-test))))
