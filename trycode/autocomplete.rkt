#lang racket/base

(require racket/list)
(provide namespace-completion)

;;------------------------------------------------------------------
;; Auto-completion
;;------------------------------------------------------------------

;; efficiently convert symbols to byte strings
(define symbol->bstring
  (let ([t (make-weak-hash)])
    (lambda (sym)
      (or (hash-ref t sym #f)
          (let ([bstr (string->bytes/utf-8 (symbol->string sym))])
            (hash-set! t sym bstr)
            bstr)))))

;; get a list of byte strings for current bindings, cache last result
(define get-namespace-bstrings
  (let ([last-syms #f] [last-bstrs #f])
    (lambda ()
      (define syms (namespace-mapped-symbols))
      (unless (equal? syms last-syms)
        (set! last-syms syms)
        (set! last-bstrs (sort (map symbol->bstring syms) bytes<?)))
      last-bstrs)))

(define (namespace-completion pat)
  (define r (regexp-match #px"(\\w|[-])*$" pat))
  (and r
       (let* ([pat (first r)]
              [pat (if (string? pat) (string->bytes/utf-8 pat) pat)]
              [pat (regexp-quote pat)]
              [pat (regexp-replace* #px#"(\\w)\\b" pat #"\\1\\\\w*")]
              [pat (byte-pregexp (bytes-append #"^" pat))])
         (map bytes->string/utf-8 (filter (lambda (bstr) 
                                            (regexp-match pat bstr))
                                          (get-namespace-bstrings))))))

