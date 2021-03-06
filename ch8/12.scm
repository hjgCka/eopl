(load-relative "../libs/init.scm")
(load-relative "./base/test.scm")
(load-relative "./base/data-structures.scm")
(load-relative "./base/type-structures.scm")
(load-relative "./base/type-module.scm")
(load-relative "./base/grammar.scm")
(load-relative "./base/renaming.scm")
(load-relative "./base/subtyping.scm")
(load-relative "./base/expand-type.scm")
(load-relative "./base/type-cases.scm")

;; In example8.13,could the definition of "and" and "not" be moved from
;; inside the module to outside it? What about to-bool?

;; "not" and "or" can not be moved from inside the module to outside
;; to-bool can be moved outside.

(run "module mybool
interface
[opaque t
        true : t
        false : t
        and : (t -> (t -> t))
        not : (t -> t)
        to-bool : (t -> bool)]
body
[type t = int
      true = 0
      false = 13
      and = proc (x : t)
      proc (y : t)
      if zero?(x) then y else false
      not = proc (x : t)
      if zero?(x) then false else true
      to-bool = proc (x : t) zero?(x)]
let true = from mybool take true
in let false = from mybool take false in let and = from mybool take and
in ((and true) false)")


;; (run "module mybool
;; interface
;; [opaque t
;;         true : t
;;         false : t
;;         to-bool : (t -> bool)]
;; body
;; [type t = int
;;       true = 0
;;       false = 13
;;       to-bool = proc (x : t) zero?(x)]
;; let true = from mybool take true
;; in let false = from mybool take false in let and = from mybool take and
;; in let and = proc(x : t) proc(y : t) if zero?(x) then y else false
;; in let not = proc(x : t) proc(x : t) if zero?(x) then false else true
;; in ((and true) false)")

;; ==> error

(run "module mybool
interface
[opaque t
        true : t
        false : t
        and : (t -> (t -> t))
        not : (t -> t) ]
body
[type t = int
      true = 0
      false = 13
      and = proc (x : t)
      proc (y : t)
      if zero?(x) then y else false
      not = proc (x : t)
      if zero?(x) then false else true ]
let true = from mybool take true
in let false = from mybool take false in let and = from mybool take and
in let to-bool  = proc(x : t) zero?(x)
in ((and true) false)")
