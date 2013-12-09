#lang racket
(require "parser.rkt")
(require "racket-datatypes.rkt")

(require ragg/support)
(require parser-tools/lex)
(require (prefix-in : parser-tools/lex-sre))


(define (tokenize ip)
  (port-count-lines! ip)
  (define ml-lexer
    (lexer-src-pos
     [(:: (:? #\-) (:+ (char-range #\0 #\9))) (token 'INT (string->number lexeme))]
     [(:seq #\V#\O#\I#\D) (token 'VOID)]
     [#\( (token 'LEFT-PAREN)]
     [#\) (token 'RIGHT-PAREN)]
     [(:seq #\f#\u#\n) (token 'FUN)]
     [(:seq #\-#\>) (token 'RIGHT-ARROW)]
     [(:seq #\l#\e#\t) (token 'LET)]
	 [#\= (token 'EQ)]
     [(:seq #\i#\n) (token 'IN)]
     [(:seq #\i#\f) (token 'IF)]
     [(:seq #\t#\h#\e#\n) (token 'THEN)]
     [(:seq #\e#\l#\s#\e) (token 'ELSE)]
     [#\[ (token 'LEFT-SQUARE-BRACKET)]
     [#\] (token 'RIGHT-SQUARE-BRACKET)]
     [#\< (token 'LEFT-ANGLE-BRACKET)]
     [#\> (token 'RIGHT-ANGLE-BRACKET)]
     [#\| (token 'PIPE)]
     [#\, (token 'COMMA)]
     [(:+ (:or #\_ #\- (char-range #\a #\z) (char-range #\A #\Z))) (token 'IDENTIFIER lexeme)]
     [whitespace
      (token 'WHITESPACE lexeme #:skip? #t)]
     [(eof)
      (void)]))

  (define (next-token) (ml-lexer ip))
  next-token)

(define (qtest s) (syntax->datum (parse (tokenize (open-input-string s)))))

#|
(qtest "0,2")
(qtest "<0|2>")
(qtest "fun x -> 0")
(qtest "VOID")
(qtest "()")
|#

(define (to-datastructure p)
  (match p
    [(list 'value false (list 'id a) false b) 
	 (let ((c (to-datastructure b)))
	 (Fix (string->symbol a) c))]
	[(list 'value (list 'num a)) (Integer a)]
	[(list 'value (list 'id a)) (Identifier (string->symbol a))]
	[(list 'program (cons 'value rst))
	 (Value (to-datastructure (cons 'value rst)))]
	[(list 'program a) (to-datastructure a)]
	[(list 'value #f a #f) (to-datastructure a)]
	[(list 'value false a false b false) 
	 (Value_Evaluation_Pair (to-datastructure a) (to-datastructure b))]
	[(list 'value a false b) 
	 (Tuple (to-datastructure a) (to-datastructure b)) ]
	[(list 'value false) (Void)]
	[(list 'value false false) (Unit)]
	[(list 'expression a b) 
	 (Application (to-datastructure a) (to-datastructure b))]
	[(list 'expression false (list 'id a) false b false c)
	 (Let-Bind (string->symbol a) (to-datastructure b) (to-datastructure c))]
	[(list 'expression false a false b false c)
	 (Ite (to-datastructure a) (to-datastructure b) (to-datastructure c))]
	[(list 'expression false a false b false) 
	 (Expression_Evaluation_Pair (to-datastructure a) (to-datastructure b))]
	[(list 'expression a false (list 'num b) false)
	 (cond
	  [(= b 0) (Project-left (to-datastructure a))]
	  [(= b 1) (Project-right (to-datastructure a))])]
	[(list 'value a) (to-datastructure a)]
	[(list 'expression (cons 'value a)) 
	 (Value (to-datastructure (cons 'value a)))]
	[(list 'expression false a false) (to-datastructure a)]
))
	


(define (translate-string s) (to-datastructure (syntax->datum (parse (tokenize (open-input-string s))))))

(define (coq-string s) (to-coq-expr (translate-string s)))

(define (parse-and-print s)
  (let ((ast (coq-string s)))
	(begin
	  (display 
	   "Module CoreMLSyntax.

  Inductive variable_name : Type := ")
	  (map (lambda (x) (display (string-append 
						"
  | " (string-append x " : variable_name"))))
		   (get-symbols))
	  (display ".

  Inductive value : Type :=
  | Identifier : variable_name -> value
  | Unit :  value
  | Integer : nat -> value
  | Fix : variable_name -> expression -> value 
  | Tuple : value -> value -> value
  | Void : value
  | Value_Evaluation_Pair : value -> value -> value

  with 
  expression : Type :=
  | Value : value -> expression 
  | Application : value -> value -> expression
  | Let_Bind : variable_name -> value -> expression -> expression
  | If : expression -> expression -> expression -> expression
  |Expression_Evaluation_Pair : expression -> expression -> expression
  | Project1 : value -> expression
  | Project2 : value -> expression.

Check ")
	  (display ast)
	  (display ".

End CoreMLSyntax.
"))))

#|(translate-string "a")
(translate-string "(a)")
(translate-string "()")
(translate-string "3")
(translate-string "(3)")
(translate-string "fun x -> ()")
(translate-string "0,2")
(translate-string "VOID")
(translate-string "<1|2>")
(translate-string "a 0")
(translate-string "let a = 0 in 1")
(translate-string "if 0 then 1 else 2")
(translate-string "<a a | b b>")
(translate-string "a[0]")
(qtest "a[1]")
(qtest "a[0]")
(translate-string "a[1]")

|# 
(let 
	((test-string "let x = 3 in (fun y -> x)"))
  
  ;(qtest test-string)
  ;(translate-string test-string)
  ;(display (coq-string test-string))
  (parse-and-print test-string))
