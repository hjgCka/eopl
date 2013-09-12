(load-relative "../libs/init.scm")
(load-relative "./39-translator.scm")

;; exercise 3.39, add unpack, and also list

  ;;;;;;;;;;;;;;;; grammatical specification ;;;;;;;;;;;;;;;;
(define the-lexical-spec
  '((whitespace (whitespace) skip)
    (comment ("%" (arbno (not #\newline))) skip)
    (identifier
     (letter (arbno (or letter digit "_" "-" "?")))
     symbol)
    (number (digit (arbno digit)) number)
    (number ("-" digit (arbno digit)) number)
    ))

(define the-grammar
  '((program (expression) a-program)

    (expression (number) const-exp)
    (expression
     ("-" "(" expression "," expression ")")
     diff-exp)

    (expression
     ("zero?" "(" expression ")")
     zero?-exp)

    (expression
     ("if" expression "then" expression "else" expression)
     if-exp)

    (expression (identifier) var-exp)

    (expression
     ("let" identifier "=" expression "in" expression)
     let-exp)

    (expression
     ("proc" "(" identifier ")" expression)
     proc-exp)

    (expression
     ("(" expression expression ")")
     call-exp)
    
    ;;new stuff
    (expression ("cons" "(" expression "," expression ")") cons-exp)
    (expression ("car" "(" expression ")") car-exp)
    (expression ("cdr" "(" expression ")") cdr-exp)
    (expression ("emptylist") emptylist-exp)
    (expression ("null?" "(" expression ")") null?-exp)
    (expression ("list" "(" (separated-list expression ",") ")" ) list-exp)
    (expression ("unpack" (arbno identifier) "=" expression "in" expression) unpack-exp)

    (expression ("%nameless-var" number) nameless-var-exp)

    (expression
     ("%let" expression "in" expression)
     nameless-let-exp)
    
    (expression
     ("%lexproc" expression)
     nameless-proc-exp)

    ;;new stuff
    (expression
     ("%unpack" expression "in" expression)
     nameless-unpack-exp)
    ))


(sllgen:make-define-datatypes the-lexical-spec the-grammar)

(define show-the-datatypes
  (lambda () (sllgen:list-define-datatypes the-lexical-spec the-grammar)))

(define scan&parse
  (sllgen:make-string-parser the-lexical-spec the-grammar))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
(define-datatype expval expval?
  (num-val
   (value number?))
  (bool-val
   (boolean boolean?))
  (pair-val 
   (car-val expval?)
   (cdr-val expval?))
  (emptylist-val)
  (proc-val
   (proc proc?)))

;; expval->num : ExpVal -> Int
(define expval->num
  (lambda (v)
    (cases expval v
	   (num-val (num) num)
	   (else (expval-extractor-error 'num v)))))

;; expval->bool : ExpVal -> Bool
(define expval->bool
  (lambda (v)
    (cases expval v
	   (bool-val (bool) bool)
	   (else (expval-extractor-error 'bool v)))))

;; expval->proc : ExpVal -> Proc
(define expval->proc
  (lambda (v)
    (cases expval v
	   (proc-val (proc) proc)
	   (else (expval-extractor-error 'proc v)))))

(define expval->pair 
  (lambda (val)
    (cases expval val
	   (emptylist-val () '())
	   (pair-val (car cdr) (cons car (expval->pair cdr)))
	   (else (error 'expval->pair "Invalid pair: ~s" val)))))

(define expval-car
  (lambda (v)
    (cases expval v
           (pair-val (car cdr) car)
           (else (expval-extractor-error 'car v)))))

(define expval-cdr
  (lambda (v)
    (cases expval v
           (pair-val (car cdr) cdr)
           (else (expval-extractor-error 'cdr v)))))

(define expval-null?
  (lambda (v)
    (cases expval v
           (emptylist-val () (bool-val #t))
           (else (bool-val #f)))))


(define list-val
  (lambda (args)
    (if (null? args)
        (emptylist-val)
        (pair-val (car args)
                  (list-val (cdr args))))))

(define expval-extractor-error
  (lambda (variant value)
    (error 'expval-extractors "Looking for a ~s, found ~s"
		variant value)))


;; procedure : Exp * Nameless-env -> Proc
(define-datatype proc proc?
  (procedure
   ;; in LEXADDR, bound variables are replaced by %nameless-vars, so
   ;; there is no need to declare bound variables.
   ;; (bvar symbol?)
   (body expression?)
   ;; and the closure contains a nameless environment
   (env nameless-environment?)))


;; nameless-environment? : SchemeVal -> Bool
(define nameless-environment?
  (lambda (x)
    ((list-of expval?) x)))

;; empty-nameless-env : () -> Nameless-env
(define empty-nameless-env
  (lambda ()
    '()))

;; empty-nameless-env? : Nameless-env -> Bool
(define empty-nameless-env?
  (lambda (x)
    (null? x)))

;; extend-nameless-env : ExpVal * Nameless-env -> Nameless-env
(define extend-nameless-env
  (lambda (val nameless-env)
    (cons val nameless-env)))

(define extend-nameless-env*
  (lambda (vals nameless-env)
    (if (null? vals)
	'()
	(cons (car vals)
	      (extend-nameless-env* (cdr vals) nameless-env)))))

;; apply-nameless-env : Nameless-env * Lexaddr -> ExpVal
(define apply-nameless-env
  (lambda (nameless-env n)
    (list-ref nameless-env n)))


(define init-nameless-env
  (lambda ()
    (empty-nameless-env)))

(define value-of-translation
  (lambda (pgm)
    (cases program pgm
	   (a-program (exp1)
		      (value-of exp1 (init-nameless-env))))))

;; used as map for the list
(define apply-elm
  (lambda (env)
    (lambda (elem)
      (value-of elem env))))


;; value-of-translation : Nameless-program -> ExpVal
;; Page: 100
(define value-of-program
  (lambda (pgm)
    (cases program pgm
	   (a-program (exp1)
		      (value-of exp1 (init-nameless-env))))))

(define value-of
  (lambda (exp nameless-env)
    (cases expression exp
	   (const-exp (num) (num-val num))

	   (diff-exp (exp1 exp2)
		     (let ((val1
			    (expval->num
			     (value-of exp1 nameless-env)))
			   (val2
			    (expval->num
			     (value-of exp2 nameless-env))))
		       (num-val
			(- val1 val2))))
	   
	   (cons-exp (exp1 exp2)
		     (pair-val 
		      (value-of exp1 nameless-env)
		      (value-of exp2 nameless-env)))

	   (zero?-exp (exp1)
		      (let ((val1 (expval->num (value-of exp1 nameless-env))))
			(if (zero? val1)
			    (bool-val #t)
			    (bool-val #f))))
	   
	   ;;new stuff
	   (emptylist-exp ()
                          (emptylist-val))

           (car-exp (body)
                    (expval-car (value-of body nameless-env)))
           (cdr-exp (body)
                    (expval-cdr (value-of body nameless-env)))
           (null?-exp (exp)
                      (expval-null? (value-of exp nameless-env)))
           (list-exp (args)
                     (list-val (map (apply-elm nameless-env) args)))

	   (if-exp (exp0 exp1 exp2)
		   (if (expval->bool (value-of exp0 nameless-env))
		       (value-of exp1 nameless-env)
		       (value-of exp2 nameless-env)))

	   (call-exp (rator rand)
		     (let ((proc (expval->proc (value-of rator nameless-env)))
			   (arg (value-of rand nameless-env)))
		       (apply-procedure proc arg)))

	   (nameless-var-exp (n)
			     (apply-nameless-env nameless-env n))

	   (nameless-let-exp (exp1 body)
			     (let ((val (value-of exp1 nameless-env)))
			       (value-of body
					 (extend-nameless-env val nameless-env))))

	   (nameless-proc-exp (body)
			      (proc-val
			       (procedure body nameless-env)))

	   (nameless-unpack-exp (vals body)
				(let ((_vals (expval->pair (value-of vals nameless-env))))
				  (value-of body
					    (extend-nameless-env* _vals nameless-env))))
	   (else
	    (error 'value-of
			"Illegal expression in translated code: ~s" exp))

	   )))


;; apply-procedure : Proc * ExpVal -> ExpVal
(define apply-procedure
  (lambda (proc1 arg)
    (cases proc proc1
	   (procedure (body saved-env)
		      (value-of body (extend-nameless-env arg saved-env))))))

(define run
  (lambda (string)
    (value-of-translation
     (translation-of-program
      (scan&parse string)))))


(scan&parse "-(1, 2)")
(run "-(1, 2)")

(run "let f = proc(x) proc (y) -(x,y) in ((f -(10,5)) 6)")

(run "let fix =  proc (f)
            let d = proc (x) proc (z) ((f (x x)) z)
            in proc (n) ((f (d d)) n)
            in let
            t4m = proc (f) proc(x) if zero?(x) then 0 else -((f -(x,1)),-4)
             in let times4 = (fix t4m)
         in (times4 3)")

(run "cons(1, 2)")
(run "cons(1, emptylist)")
;; (run "cons(1, cons(3, emptylist))")

;; new testcase
(run "let u = 7
      in unpack x y = cons(u, cons(3, emptylist))
      in -(x,y)")

