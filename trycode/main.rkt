#lang racket/base
(require  web-server/servlet
          web-server/servlet-env
          web-server/templates
          web-server/dispatch
          web-server/http
          racket/sandbox
          json
          racket/format
          racket/dict
          racket/match
          racket/local
          racket/runtime-path
          web-server/managers/lru
          web-server/managers/manager
          file/convertible
          net/base64
          setup/dirs
          "autocomplete.rkt"
          )

(define APPLICATION/JSON-MIME-TYPE #"application/json;charset=utf-8")

(module+ test (require rackunit))

;; Force a check for the DLL dirs; work around for Windows and Mac compatibility
(find-dll-dir)

;; Paths
(define-runtime-path trycode ".")
(define autocomplete
  (build-path trycode "autocomplete.rkt"))

;;------------------------------------------------------------------
;; sandbox
;;------------------------------------------------------------------
;; make-ev : -> evaluator
(define (make-ev)
  (parameterize ([sandbox-output 'string]
                 [sandbox-error-output 'string]
                 [sandbox-propagate-exceptions #f]
                 [sandbox-memory-limit 30]
                 [sandbox-eval-limits (list 5 30)]
                 [sandbox-namespace-specs
                  (append (sandbox-namespace-specs)
                          `(file/convertible
                            json
                            setup/dirs))]
                 [sandbox-path-permissions '((read #rx#"racket-prefs.rktd"))])
    ((lambda ()
       (make-evaluator 'racket/base
                       #:requires `(pict
                                    pict/flash
                                    pict/code
                                    file/convertible
                                    json
                                    ,autocomplete
                                    (planet schematics/random:1:0/random)))))))


(define (run-code ev str)
  (define reses ; Gather results into a list
    (call-with-values (λ () (ev str)) (λ xs xs)))
  (define out (get-output ev))
  (define err (get-error-output ev))
  (for/list ([res reses])
    (cond [(convertible? res)
           (define res-convert (ev `(convert ',res 'png-bytes)))
           ;; run 'convert' in the sandbox for safety reasons
           (list (~v (bytes-append #"data:image/png;base64,"
                                   (base64-encode res-convert #"")))
                 #f #f)]
          [else      (list (if (void? res) "" (format "~v" res))
                           (and (not (equal? out "")) out)
                           (and (not (equal? err "")) err))])))

(define (complete-code ev str)
  (define res (ev  `(jsexpr->string (namespace-completion ,str))))
  (define out (get-output ev))
  (define err (get-error-output ev))
  (list (list (if (void? res) "" res)
              (and (not (equal? out "")) out)
              (and (not (equal? err "")) err))))

;;------------------------------------------------------------------
;; Routes
;;------------------------------------------------------------------
(define-values (dispatch urls)
    (dispatch-rules
     [("") index]
     [("index") index]
     [("tutorial") #:method "post" tutorial]))

;;------------------------------------------------------------------
;; Responses
;;------------------------------------------------------------------
;; make-response : ... string -> response
(define (make-response
         #:code [code 200]
         #:message [message #"OK"]
         #:seconds [seconds (current-seconds)]
         #:mime-type [mime-type TEXT/HTML-MIME-TYPE]
         #:headers [headers (list (make-header #"Cache-Control" #"no-cache"))]
         content)
  (response/full code message seconds mime-type headers
                 (list (string->bytes/utf-8 content))))

;;------------------------------------------------------------------
;; Request Handlers
;;------------------------------------------------------------------
;; Tutorial pages
(define (tutorial request)
  (define page (dict-ref (request-bindings request) 'page #f))
  (make-response
   (match page
     ("0001" (include-template "../templates/tutorial/0001.html"))
     ("0002" (include-template "../templates/tutorial/0002.html"))
     ("0003" (include-template "../templates/tutorial/0003.html"))
     ("0004" (include-template "../templates/tutorial/0004.html"))
     ("0005" (include-template "../templates/tutorial/0005.html"))
     ("0006" (include-template "../templates/tutorial/0006.html"))
     ("0007" (include-template "../templates/tutorial/0007.html"))
     ("0008" (include-template "../templates/tutorial/0008.html"))
     ("0009" (include-template "../templates/tutorial/0009.html"))
     ("0010" (include-template "../templates/tutorial/0010.html"))
     ("0011" (include-template "../templates/tutorial/0011.html"))
     ("0012" (include-template "../templates/tutorial/0012.html")))))

;; Home page
(define (index request)
    (index-with (make-ev) request))

(define (index-with ev request)
  (local [(define (response-generator embed/url)
            (let ([url (embed/url next-eval)]
                  ;[complete-url (embed/url next-complete)]
                  )
              (make-response
               (include-template "../templates/index.html"))))
            (define (next-eval request)
              (eval-with ev request))
            ;(define (next-complete request)(complete-with ev request))
            ]
      (send/suspend/dispatch response-generator)))

;; string string -> jsexpr
(define (json-error expr msg)
  (hasheq 'expr expr 'error #true 'message msg))

;; string string -> jsexpr
(define (json-result expr res)
  (hasheq 'expr expr 'result res))

;; string (listof eval-result) -> (listof jsexpr)
(define (result-json expr lsts)
  (for/list ([lst lsts])
    (match lst
      [(list res #f #f)
       (json-result expr res)]
      [(list res out #f)
       (json-result expr (string-append out res))]
      [(list _ _ err)
       (json-error expr err)])))


(module+ test
 (define ev (make-ev))
 ;; String -> (Listof String)
 ;; e.g. (values (+ 1 2) 4) ~> '("3" "4"), (modulo quotes)
 (define (eval-result-to-json expr)
   (for/list ([res (result-json "" (run-code ev expr))])
     (jsexpr->string (hash-ref res 'result))))
 ;; String -> String
 (define (eval-error-to-json expr)
   (match-define (list res) (result-json "" (run-code ev expr)))
   (jsexpr->string (hash-ref res 'message)))

 (check-equal?
  (eval-result-to-json "(+ 3 3)") (list "\"6\""))
 (check-equal?
  (eval-result-to-json "(display \"6\")") (list "\"6\""))
 (check-equal?
  (eval-result-to-json "(write \"6\")") (list "\"\\\"6\\\"\""))
 (check-equal?
  (eval-result-to-json "(begin (display \"6 + \") \"6\")") (list "\"6 + \\\"6\\\"\""))
)

;; Eval handler
(define (eval-with ev request)
  (define bindings (request-bindings request))
  (cond [(exists-binding? 'expr bindings)
         (let ([expr (extract-binding/single 'expr bindings)])
           (make-response
            #:mime-type APPLICATION/JSON-MIME-TYPE
            (jsexpr->string (result-json expr (run-code ev expr)))))]
         [(exists-binding? 'complete bindings)
          (let ([str (extract-binding/single 'complete bindings)])
            (make-response
             #:mime-type APPLICATION/JSON-MIME-TYPE
             (jsexpr->string
              (car (result-json "" (complete-code ev str))))))]
        [else (make-response #:code 400 #:message #"Bad Request" "")]))



;;------------------------------------------------------------------
;; Server
;;------------------------------------------------------------------
(define (ajax? req)
  (string=? (dict-ref (request-headers req) 'x-requested-with "")
            "XMLHttpRequest"))

(define (expiration-handler req)
  (if (ajax? req)
      (make-response
       #:mime-type APPLICATION/JSON-MIME-TYPE
       (jsexpr->string
        (json-error "" "Sorry, your session has expired. Please reload the page.")))
      (response/xexpr
      `(html (head (title "Page Has Expired."))
             (body (p "Sorry, this page has expired. Please reload the page."))))))


(define-runtime-path static "../static")

(define mgr
  (make-threshold-LRU-manager expiration-handler (* 256 1024 1024)))

(module+ main
  (serve/servlet
   dispatch
   #:stateless? #f
   #:launch-browser? #f
   #:connection-close? #t
   #:quit? #f
   #:listen-ip #f
   #:port 8080
   #:servlet-regexp #rx""
   #:extra-files-paths (list static)
   #:servlet-path "/"
   #:manager mgr
   #:log-file "/var/log/trycode.io/trycode_srv.log"
   #:log-format 'extended))
