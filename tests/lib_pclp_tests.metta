!(import! &self lib_pclp)

; Seed &pclp with stale state that loading sample.pclp must replace.
!(add-atom &pclp (rule 99 (stale) ()))

; query(saved) has two supports, yielding the normalized disjunction below.
!(test
  (let ((query 0 (saved) $formula))
       (pclp-parse-file "sample.pclp")
       $formula)
  (f_or
   ((f_and
     ((c_eq (e_rv coin ()) (e_lit true))
      (c_lt
       (e_add (e_rv t1 ())
              (e_mul (e_lit 0.25) (e_rv t2 ())))
       (e_lit 1.375))
      (c_lt (e_rv t1 ()) (e_lit 1.25))))
    (f_and
     ((c_eq (e_rv coin ()) (e_lit true))
      (c_lt (e_rv t1 ()) (e_lit 0.75)))))))

!(test
       (pclp-query-bounds "sample.pclp")
       ((query 0 (saved) (bound 0.392 0.704))))

; sample.pclp loads 3 RV definitions, 2 rules, and 1 query.
!(test (length (collapse (match &pclp $expr $expr)))
       6)

; pclp-parse-file clears the stale rule before loading the new program.
!(test (collapse (match &pclp (rule 99 (stale) ()) True))
       ())

; Query dispatch commits with cut, so parsing has exactly one result.
!(test (length (collapse (pclp-parse-file "sample.pclp")))
       1)

; Loading a new program invalidates GWMC tables built from the previous &pclp.
; Both programs compile saved to the same formula and context, but use different
; choice probabilities, so a stale table would return the first bound twice.
!(test
       (let* (($first (pclp-query-bounds "examples/ship.pclp"))
                             ($second (pclp-query-bounds "test_data/ship_reweighted.pclp")))
              ($first $second))
       (((query 0 (saved) (bound 0.49 0.88)))
        ((query 0 (saved) (bound 0.25 0.74)))))
