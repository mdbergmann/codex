(in-package :codex.macro)

;;; Variables

(defparameter *current-package* "common-lisp"
  "A string with the name of the current package being parsed. This is
 'common-lisp' by default.")

;;; Utilities

(defun make-class-metadata (class-name)
  "Create metadata for HTML classes."
  (make-meta
   (list
    (cons "class" (concatenate 'string
                               "codex-"
                               class-name)))))

;;; Macros in user input (Docstrings, files, etc.)

(define-node cl-ref (macro-node)
  ()
  (:tag-name "clref")
  (:documentation "A reference to a Common Lisp symbol."))

(define-node cl-doc (macro-node)
  ()
  (:tag-name "cldoc")
  (:documentation "Insert parsed documentation."))

(define-node param (macro-node)
  ()
  (:tag-name "param")
  (:documentation "An argument of an operator."))

;;; Macros generated by parsing the documentation

(define-node symbol-node ()
  ((symbol-node-package :reader symbol-node-package
                        :initarg :package
                        :type string
                        :documentation "A symbol's package.")
   (symbol-node-name :reader symbol-node-name
                     :initarg :name
                     :type string
                     :documentation "A symbol's name.")
   (externalp :reader externalp
              :initarg :externalp
              :type boolean
              :documentation "Whether the symbol is external.")
   (setfp :reader setfp
          :initarg :setfp
          :type boolean
          :documentation "Whether the symbol is a setf method."))
  (:documentation "A symbol."))

(defmethod render-full-symbol ((symbol symbol-node))
  (concatenate 'string
               (symbol-node-package symbol)
               ":"
               (symbol-node-name symbol)))

(defmethod render-humanize ((symbol symbol-node))
  (string-downcase (symbol-node-name symbol)))

(define-node documentation-node (common-doc.macro:macro-node)
  ((documentation-symbol :reader doc-symbol
                         :initarg :symbol
                         :type symbol-node
                         :documentation "The symbol name of the operator, variable, or class.")
   (documentation-desc :reader doc-description
                       :initarg :doc
                       :type (or null document-node)
                       :documentation "The node's documentation."))
  (:documentation "Superclass for all documentation nodes."))

(define-node operator-node (documentation-node)
 ((l-list :reader operator-lambda-list
          :initarg :lambda-list
          :type (proper-list string)
          :documentation "The operator's lambda list."))
  (:documentation "The base class of functions and macros."))

(define-node function-node (operator-node)
  ()
  (:documentation "A function."))

(define-node macro-node (operator-node)
  ()
  (:documentation "A macro."))

(define-node generic-function-node (operator-node)
  ()
  (:documentation "A generic function."))

(define-node method-node (operator-node)
  ()
  (:documentation "A method."))

(define-node variable-node (documentation-node)
  ()
  (:documentation "A variable."))

(define-node slot-node (documentation-node)
  ((accessors :reader slot-accessors
              :initarg :accessors
              :initform nil
              :type (proper-list string))
   (readers :reader slot-readers
            :initarg :readers
            :initform nil
            :type (proper-list string))
   (writers :reader slot-writers
            :initarg :writers
            :initform nil
            :type (proper-list string)))
  (:documentation "A class or structure slot."))

(define-node record-node (documentation-node)
  ((slots :reader record-slots
          :initarg :slots
          :type (proper-list slot-node)
          :documentation "A list of slots.")))

(define-node struct-node (record-node)
  ()
  (:documentation "A structure."))

(define-node class-node (record-node)
  ()
  (:documentation "A class."))

;;; Macroexpansions

(defun parse-symbol-string (string)
  (let* ((colon-pos (position #\: string))
         (package-name (subseq string 0 colon-pos))
         (symbol-name (subseq string (1+ colon-pos))))
    (list package-name symbol-name)))

(defmethod expand-macro ((ref cl-ref))
  (let ((text-node (elt (children ref) 0)))
    (assert (typep text-node 'text-node))
    (destructuring-bind (package-name symbol-name)
        (parse-symbol-string (text text-node))
      (make-instance 'document-link
                     :section-reference (concatenate 'string
                                                     "symbol-"
                                                     package-name
                                                     ":"
                                                     symbol-name)))))

(defmethod expand-macro ((cl-doc cl-doc))
  (let ((text-node (elt (children ref) 0)))
    (assert (typep text-node 'text-node))
    (let ((symbol-string (text text-node)))
      ;; Extract the node from the index
      (let ((node (codex.index:get-from-current-index symbol-string)))
        (if node
            node
            ;; No node with that name, report an error
            (make-text (format nil "Error: No node with name ~A." symbol-string)))))))

(defmethod expand-macro ((param param))
  (make-instance 'content-node
                 :metadata (make-class-metadata "param")
                 :children (children param)))

(defun expand-operator-macro (instance class-name)
  (make-instance 'content-node
                 :metadata (make-class-metadata class-name)
                 :children
                 (list (make-text (render-humanize (doc-symbol instance))
                                  (make-class-metadata "name"))
                       (doc-description instance))))

(defmethod expand-macro ((function function-node))
  (expand-operator-macro function "function"))

(defmethod expand-macro ((macro macro-node))
  (expand-operator-macro macro "macro"))

(defmethod expand-macro ((generic-function generic-function-node))
  (expand-operator-macro generic-function "generic-function"))

(defmethod expand-macro ((method method-node))
  (expand-operator-macro method "method"))

(defmethod expand-macro ((variable variable-node))
  (make-instance 'content-node
                 :metadata (make-class-metadata "variable")
                 :children
                 (list (make-text (render-humanize (doc-symbol variable))
                                  (make-class-metadata "name"))
                       (doc-description variable))))

(defmethod expand-macro ((slot slot-node))
  (labels ((list-of-strings-to-list (strings)
             (make-instance 'unordered-list
                            :children
                            (loop for string in strings collecting
                              (make-instance 'list-item
                                             :children
                                             (list (make-text string))))))
           (make-definition (slot-name text)
             (when (slot-value slot slot-name)
               (make-instance 'definition
                              :term (make-text text)
                              :definition (list-of-strings-to-list
                                           (slot-value slot slot-name))))))
    (let* ((accessors-definition (make-definition 'accessors "Accessors"))
           (readers-definition (make-definition 'readers "Readers"))
           (writers-definition (make-definition 'writers "Writers"))
           (slot-methods (remove-if #'null (list accessors-definition
                                                 readers-definition
                                                 writers-definition)))
           (slot-methods-node (make-instance 'definition-list
                                             :metadata (make-class-metadata "slot-methods")
                                             :children slot-methods)))
      (make-instance 'content-node
                     :metadata (make-class-metadata "slot")
                     :children
                     (list (doc-description slot)
                           slot-methods-node)))))

(defun expand-record-macro (instance class-metadata)
  (make-instance 'content-node
                 :metadata (make-class-metadata class-metadata)
                 :children
                 (list (make-text (render-humanize (doc-symbol instance))
                                  (make-class-metadata "name"))
                       (doc-description instance)
                       (record-slots instance))))

(defmethod expand-macro ((struct struct-node))
  (expand-record-macro struct "struct"))

(defmethod expand-macro ((class class-node))
  (expand-record-macro class "class"))
