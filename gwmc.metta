!(import! &self (library lib_import))
!(import! &self (library lib_tabling))
!(import! &self (library chainer))
!(import_prolog_functions_from_file (library pclp_solver.pl)
    (pclp_classify pclp_classify_formula pclp_consistent))

!(import_prolog_functions_from_file (library pclp_util.pl)
    (pclp_clear_gwmc_tables))


!(tabled (gwmc_rec $formula $ctx))

(= (gwmc $formula) 
    (gwmc-ctx $formula (ctx () ())))

(= (gwmc-ctx $formula $ctx)
    (if (ctx-consistent $ctx)
        (let $residual (simplify $formula $ctx)
            (case $residual 
                ((True (bound 1 1))
                 (False (bound 0 0))
                 ($_ (gwmc_rec $residual $ctx)))))

        (bound 0 0)))

(= (gwmc_rec $formula $ctx)
    (case $formula
        (((f_or $disjuncts)
            (case (select-unk-disjunct $disjuncts $ctx)
                (((Result $disjunct)
                    (reduce-selected-disjunct
                        $formula $ctx $disjunct))
                        
                 (None 
                    (case (select-common-unk-conjunct $disjuncts $ctx)
                        (((Result $conjunct)
                            (reduce-common-conjunct $formula $ctx $conjunct))
                        
                         (None (branch-on-next-instance $formula $ctx))))))))
                    
        ((f_and $_) 
            (branch-on-next-instance $formula $ctx)))))

(= (branch-on-next-instance $formula $ctx)
    (let* (($selected-instances (ctx-instances $ctx))
           ($instances
             (unselected-instances
               $formula
               $selected-instances)))
      (if (== $instances ())
          (bound 0 1)
          (let* (($instance
                    (select-next-instance $instances))
                 ($choices
                    (instance-choices $instance)))
            (sum-choice-bounds
              (bound 0 0)
              $formula
              $ctx
              $choices
              $instance)))))


; One example to demonstrate why we should set the upper bound to 1
; Consider the PCLP program
; Dom(x): Real.
; Dom(coin): {True, False}.

; x ~ {1.0: [0, 1]}.
; coin ~ Bernoulli(0.8).

;. q <- x > 0.5 ; A
; q <- coin. ; B

; A \/ B

; Psi  = {x}
;
; After selecting x in [0, 1], the disjunct x > 0.5 is still undetermined:
; values in [0, 0.5] make it false, while values in (0.5, 1] make it true.
; For the upper bound, all mass in the selected region may lie in (0.5, 1],
; so this disjunct makes q true with conditional upper probability 1.
; For the lower bound, add the premise not(x > 0.5), which removes this proof;
; the remaining coin proof contributes 0.8. The resulting bound is [0.8, 1].

(= (reduce-selected-disjunct $formula $ctx $disjunct)
    (let* (; Exclude this possible proof for the lower bound; it makes the upper bound 1.
           ($next-ctx
                (ctx-add-premise $ctx (neg $disjunct))) ; next-ctx = ctx /\ not(disjunct)
            ((bound $lower $_) (gwmc-ctx $formula $next-ctx)))
            
        (bound $lower 1)))

; A common conjunct C factors the DNF as C and (A or B or ...).
; For example:
; x ~ {1.0: [0, 1]}.
; coin ~ Bernoulli(0.8).
; color ~ {0.5: red, 0.5: blue}.
; q <- x > 0.5, coin.
; q <- x > 0.5, color = red.
; After selecting x in [0, 1], the common conjunct x > 0.5 is undetermined.
; For the lower bound, all mass may lie where x <= 0.5, making every proof
; false, so the lower bound is 0. For the upper bound, assume x > 0.5 and
; evaluate coin or color = red, giving 0.8 + 0.2 * 0.5 = 0.9.
; The resulting bound is [0, 0.9].
(= (reduce-common-conjunct $formula $ctx $conjunct)
    (let* (($premise (f_and ($conjunct)))
            ($next-ctx
                (ctx-add-premise $ctx (pos $premise))) ; next-ctx = ctx /\ conjunct
            ((bound $_ $upper) (gwmc-ctx $formula $next-ctx)))
            
        (bound 0 $upper))) 

(= (sum-choice-bounds $res0 $_ $_ () $_) $res0)
(= (sum-choice-bounds $res0 $formula $ctx (cons $head $rest) $instance)
    (let* (((choice $choice-id $prob $constr) $head)
            ($next-ctx
                (ctx-select $ctx $instance $choice-id))
            ($branch 
                (gwmc-ctx $formula $next-ctx))
            ($res (add-bounds $res0 (scale-bound $prob $branch))))

            (sum-choice-bounds $res $formula $ctx 
                    $rest $instance)))

; cache mgmt
(= (clear-gwmc-cache)
    (pclp_clear_gwmc_tables))

; first selection heuristics (TODO Explore other heuristics)
(= (select-next-instance ()) ())
(= (select-next-instance (cons $head $_)) $head)

(= (classify-residual $formula $ctx)
        (case $formula
            ((True True)
             (False False)
             ($_
                 (case (classify-formula $formula $ctx)
                     ((true True)
                        (false False)
                        (unk $formula)))))))

(= (classify-constraint $constr $ctx)
    (let* (($choice-constrs 
                (delta-constraints (ctx-delta $ctx)))
            ($premises
                (ctx-premises $ctx))
            ($ctx-terms 
                (append $choice-constrs $premises)))           
        (pclp_classify
            $constr
            $choice-constrs
            $premises
            (constr-domains
                (cons $constr $ctx-terms)))))

(= (classify-formula $formula $ctx)
    (let* (($choice-constrs 
                (delta-constraints (ctx-delta $ctx)))
            ($premises
                (ctx-premises $ctx))
            ($ctx-terms
                (append $choice-constrs $premises)))
                
        (pclp_classify_formula
            $formula
            $choice-constrs
            $premises
            (constr-domains
                (cons $formula $ctx-terms)))))

; Formula Simplification
; The GWMC recursive state must establish that Δ is consistent before simplify.
(= (simplify True $_) True)

(= (simplify False $_) False)

(= (simplify (f_and $conjuncts) $ctx)
        (classify-residual
            (simplify-conjuncts $conjuncts $ctx)
            $ctx))

(= (simplify (f_or $disjuncts) $ctx)
        (classify-residual
            (simplify-disjuncts $disjuncts $ctx)
            $ctx))


(= (simplify-disjuncts () $_) False)

(= (simplify-disjuncts (cons (f_and $conjuncts) $disjuncts) $ctx)
    (handle-disjunct
      (simplify-conjuncts $conjuncts $ctx)
        $disjuncts
        $ctx))

(= (simplify-conjuncts () $_) True)

(= (simplify-conjuncts (cons $conjunct $conjuncts) $ctx)
    (case (classify-constraint $conjunct $ctx)
      ((true (simplify-conjuncts $conjuncts $ctx))
       (false False)
       (unk
            (prepend-conjunct
                $conjunct
                (simplify-conjuncts $conjuncts $ctx))))))

(= (select-unk-disjunct () $_) None)

; Algorithm 2 Optimization
; Get a disjunct whose RV instances are all selected but still undetermined.
(= (select-unk-disjunct (cons $disjunct $disjuncts) $ctx)
    (if (and (is-fully-selected $disjunct $ctx)
                (== (classify-formula $disjunct $ctx) unk))
        (Result $disjunct)       
        (select-unk-disjunct $disjuncts $ctx)))

; Get a conjunct that's common to all disjuncts and still undetermined
(= (select-common-unk-conjunct () $_) None)

(= (select-common-unk-conjunct (cons (f_and $conjuncts) $disjuncts) $ctx)
    (select-common-from $conjuncts $disjuncts $ctx))

(= (select-common-from () $_ $_) None)

(= (select-common-from (cons $conjunct $conjuncts) $disjuncts $ctx)
    (if (and (is-common-conjunct $conjunct $disjuncts)
            (and (is-fully-selected $conjunct $ctx)
                (== (classify-constraint $conjunct $ctx) unk)))
                
        (Result $conjunct)
        (select-common-from $conjuncts $disjuncts $ctx)))



; RVInstances(T) ⊆ SelectedInstances(ctx)
(= (is-fully-selected $formula $ctx)
    (== (unselected-instances 
            $formula
            (ctx-instances $ctx)) ()))

; Simplification utils
(= (handle-disjunct True $_ $_) True)

(= (handle-disjunct False $disjuncts $ctx)
    (simplify-disjuncts $disjuncts $ctx))

(= (handle-disjunct (f_and $conjuncts) $disjuncts $ctx)
    (prepend-disjunct
      (f_and $conjuncts)
      (simplify-disjuncts $disjuncts $ctx)))

(= (prepend-disjunct $disjunct False)
    (f_or ($disjunct)))

(= (prepend-disjunct $_ True) True)

(= (prepend-disjunct $disjunct (f_or $disjuncts))
    (f_or (cons $disjunct $disjuncts)))

(= (prepend-conjunct $conjunct True)
    (f_and ($conjunct)))

(= (prepend-conjunct $_ False) False)

(= (prepend-conjunct $conjunct (f_and $conjuncts))
    (f_and (cons $conjunct $conjuncts)))

; Bound Arithmetic
(= (add-bounds (bound $lo1 $hi1) (bound $lo2 $hi2))
    (bound (+ $lo1 $lo2) (+ $hi1 $hi2)))

(= (scale-bound $prob (bound $lo $hi))
    (bound (* $prob $lo) (* $prob $hi)))

(= (multiply-bounds (bound $lo1 $hi1) (bound $lo2 $hi2))
    (bound (* $lo1 $lo2) (* $hi1 $hi2)))

(= (unselected-instances $formula $selected-instances)
    (remove-selected-instances
        (formula-rv-instances $formula)
        $selected-instances))

(= (remove-selected-instances () $_) ())
(= (remove-selected-instances (cons $head $tail) $selected-instances)
        (if (is-member $head $selected-instances)
                (remove-selected-instances $tail $selected-instances)
                (cons $head
                    (remove-selected-instances $tail $selected-instances))))

(= (is-common-conjunct $_ ()) True)

(= (is-common-conjunct $conjunct (cons (f_and $conjuncts) $disjuncts))
    (if (is-member $conjunct $conjuncts)
        (is-common-conjunct $conjunct $disjuncts)
        False))

(= (rvs-domains ()) ())

(= (rvs-domains (cons $rv $rvs))
    (let $dom (rv-domain $rv)
         (cons (rv_domain $rv $dom)
               (rvs-domains $rvs))))

(= (constr-domains ()) ())

(= (constr-domains (cons $constr $constrs))
    (rvs-domains (formula-rvs (cons $constr $constrs))))

; State/Context to use for caching
(= (ctx-delta (ctx $delta $_))
    $delta)


(= (ctx-premises (ctx $_ $premises)) 
    $premises)

(= (ctx-instances (ctx $delta $_))
    (delta-instances $delta))

(= (ctx-select (ctx $delta $premises) $instance $choice-id)
    (ctx 
       (delta-select $instance $choice-id $delta)
       $premises))
    
(= (ctx-add-premise (ctx $delta $premises) $premise)
    (ctx 
        $delta
        (sort (cons $premise $premises))))

(= (ctx-consistent $ctx)
    (let* (($choice-constrs
             (delta-constraints (ctx-delta $ctx)))
           ($premises
             (ctx-premises $ctx))
           ($ctx-terms
             (append $choice-constrs $premises)))
             
        (pclp_consistent
            $choice-constrs
            $premises
            (constr-domains $ctx-terms))))

(= (delta-consistent $delta)
    (let $constrs (delta-constraints $delta)
         (pclp_consistent
            $constrs
            (constr-domains $constrs))))

