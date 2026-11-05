!(import! &self (library lib_import))
!(import_prolog_functions_from_file (library pclp_parser.pl) (pclp_parse_file))
!(import! &self (library gwmc))


(= (pclp-query-bounds $path)
   (pclp-bounds (pclp-parse-file $path)))

(= (pclp-bounds ()) ())

(= (pclp-bounds (cons (query $id $goal $formula) $queries))
   (let $bound (gwmc $formula)
      (cons (query $id $goal (round-bound $bound 12))
            (pclp-bounds $queries))))

(= (pclp-parse-file $path)
   (let $program (cdr-atom (pclp_parse_file $path))
      (progn
         (clear-gwmc-cache)
         (pclp-clear!)
         (pclp-load! $program)
         (compile-queries $program))))

(= (pclp-load! ()) ())

(= (pclp-load! (cons $expr $program))
   (progn
      (add-atom &pclp $expr)
      (pclp-load! $program)))

(= (compile-queries ()) ())

(= (compile-queries (cons (query $id $goal) $program))
   (progn (cut)
      (cons (query $id $goal
                (normalize-formula
                 (build-solution-formula (collapse (bc $goal)))))
           (compile-queries $program))))

(= (compile-queries (cons $_ $program))
   (compile-queries $program))

(= (round-bound (bound $lo $hi) $digits)
   (bound (round-decimal $lo $digits)
          (round-decimal $hi $digits)))

(= (round-decimal $value $digits)
   (let $factor (pow-math 10 $digits)
      (/ (round-math (* $value $factor)) $factor)))

!(if (== (argv 0) lib_pclp.metta)
     (pclp-query-bounds (argv 1))
     ())