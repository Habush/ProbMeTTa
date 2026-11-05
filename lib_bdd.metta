;; Each BDD node is an atom in a dedicated space:
;;   (bdd-node $id $var $lo $hi)

;; Create the BDD space and a counter for unique node IDs
!(bind! &bdd (new-space))
!(bind! &bdd-counter (new-state 0))

;; Register terminal nodes
!(add-atom &bdd (bdd-node bdd-0 terminal False False))
!(add-atom &bdd (bdd-node bdd-1 terminal True True))

(= (new-id)
    (let* (($n (get-state &bdd-counter))
            ($next (+ $n 1))
            ($_ (change-state! &bdd-counter $next)))
        $n))

; mk (make node)
;; Create the BDD space and a counter for unique node IDs
;; mk enforces the two BDD reduction rules:
;;   1. Elimination: if lo == hi, skip this node (variable is irrelevant)
;;   2. Merging: if a node with same (var, lo, hi) exists, reuse it
(= (mk $var $lo $hi)
    (if (== $lo $hi)
        ;;Elimination rule: variable doesn't matter
        $lo
        ;Check if node already exists (merging rule)
        (case (once (match &bdd (bdd-node $existing $var $lo $hi) $existing))
            (($id $id)
             (Empty 
                (let $id (new-id)
                    (let $_ (add-atom &bdd (bdd-node $id $var $lo $hi))
                        $id)))))))

;;;;;;;;;;;;;;;;;;;;
;; Node accessors ;;
;;;;;;;;;;;;;;;;;;;;

(= (bdd-var $id)
    (match &bdd (bdd-node $id $var $_ $_) $var))

(= (bdd-lo $id)
   (match &bdd (bdd-node $id $_ $lo $_) $lo))

(= (bdd-hi $id)
   (match &bdd (bdd-node $id $_ $_ $hi) $hi))

(= (is-terminal $id)
   (if (== $id bdd-0) True
       (if (== $id bdd-1) True
           False)))

;;;;;;;;;;;;;;;;;;;;;;
;; BDD evaluation   ;;
;;;;;;;;;;;;;;;;;;;;;;

;; Environment is a flat list of (var val) pairs:
;;   ((x1 True) (x2 False) (x3 True))

(= (env-lookup-sub $var ($var $val)) $val)
(= (env-lookup $var $env)
    (once (env-lookup-sub $var (superpose $env))))


;; Single clause — handles both terminals and internal nodes
;; (no separate terminal clauses to avoid nondeterministic duplicates)
(= (bdd-eval $id $env)
    (if (is-terminal $id)
        (if (== $id bdd-1) True False)
        (let $var (bdd-var $id)
            (if (== (env-lookup $var $env) True)
                (bdd-eval (bdd-hi $id) $env)
                (bdd-eval (bdd-lo $id) $env)))))

;; Boolean operations on terminal values
(= (bool-op bdd-and True  True)  True)
(= (bool-op bdd-and True  False) False)
(= (bool-op bdd-and False True)  False)
(= (bool-op bdd-and False False) False)

(= (bool-op bdd-or True  True)  True)
(= (bool-op bdd-or True  False) True)
(= (bool-op bdd-or False True)  True)
(= (bool-op bdd-or False False) False)

(= (bool-op bdd-xor True  True)  False)
(= (bool-op bdd-xor True  False) True)
(= (bool-op bdd-xor False True)  True)
(= (bool-op bdd-xor False False) False)

;; Map terminal truth values to terminal node IDs
(= (truth-to-id True)  bdd-1)
(= (truth-to-id False) bdd-0)

;; Terminal value of a terminal node
(= (terminal-val bdd-0) False)
(= (terminal-val bdd-1) True)

;; ROBDDs are canonical: two boolean functions are equal
;; iff their root node IDs are identical.
(= (bdd-eq $f $g) (== $f $g))

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Convenience builders  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;

(= (bdd-var-node $var) (mk $var bdd-0 bdd-1))

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Apply algorithm      ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;
;;h = x̄2 · (f|_{x2=0} op g|_{x2=0})  +  x2 · (f|_{x2=1} op g|_{x2=1})
;;         ─────────────────────────         ─────────────────────────
;;              apply-bdd(op, f.lo, g.lo)            apply-bdd(op, f.hi, g.hi)

;; Apply: combine two BDDs with a boolean operator (Shannon expansion)

;Space to cache apply-bdd computations
!(bind! &apply-cache (new-space))
(= (apply-bdd $op $f $g)
    (case (once (match &apply-cache (cached $op $f $g $result) $result))
        (($hit $hit)
         (Empty 
            ; Cache miss - compute and store
            (let $result (apply-bdd-compute $op $f $g)
                (progn 
                    (add-atom &apply-cache (cached $op $f $g $result))
                    $result))))))

(= (apply-bdd-compute $op $f $g)
    (if (and (is-terminal $f) (is-terminal $g))
        ;Both terminals - compute directly
        (truth-to-id (bool-op $op (terminal-val $f) (terminal-val $g)))
        ; At least one is non-terminal - Shannon expansion
        (if (is-terminal $f)
            (let $var (bdd-var $g)
                (mk $var 
                    (apply-bdd $op $f (bdd-lo $g))
                    (apply-bdd $op $f (bdd-hi $g))))
            (if (is-terminal $g)
                (let $var (bdd-var $f)
                    (mk $var 
                        (apply-bdd $op (bdd-lo $f) $g)
                        (apply-bdd $op (bdd-hi $f) $g)))
                ;; Both non-terminal - compare variables
                (let* (($vf (bdd-var $f))
                       ($vg (bdd-var $g)))
                    (if (== $vf $vg)
                        (mk $vf 
                            (apply-bdd $op (bdd-lo $f) (bdd-lo $g))
                            (apply-bdd $op (bdd-hi $f) (bdd-hi $g)))
                        (if (< $vf $vg)
                            (mk $vf 
                                (apply-bdd $op (bdd-lo $f) $g)
                                (apply-bdd $op (bdd-hi $f) $g))
                            (mk $vg 
                                (apply-bdd $op $f (bdd-lo $g))
                                (apply-bdd $op $f (bdd-hi $g))))))))))

;;;;;;;;;;;;;;;;;
;; BDD negation ;;
;;;;;;;;;;;;;;;;;
;; NOT is just XOR with the True terminal
(= (bdd-not $f) (apply-bdd bdd-xor $f bdd-1))

;;;;;;;;;;;;;;;;;
;; Cofactor ;;
;;;;;;;;;;;;;;;;;
;; Cofactor: fix variable $xi to $val (True/False), producing a simpler BDD.
(= (bdd-restrict $f $xi $val)
    (if (is-terminal $f)
        $f 
        (let $v (bdd-var $f)
            (if (== $v $xi)
                ; This is the var we're restricting
                (if (== $val True)
                    (bdd-restrict (bdd-hi $f) $xi $val)
                    (bdd-restrict (bdd-lo $f) $xi $val))
                (if (< $v $xi)
                    ; Current var is above xi — recurse into both children
                    (mk $v 
                        (bdd-restrict (bdd-lo $f) $xi $val)
                        (bdd-restrict (bdd-hi $f) $xi $val))
                    ; Else - var is below xi - not relevant here - nothing to restrict
                    $f)))))

;;;;;;;;;;;;;;;;;
;; Statcount ;;
;;;;;;;;;;;;;;;;;
;; Count satisfying assignments for a BDD over $nvars total variables.
;; Each skipped variable level doubles the count.
;; Count satisfying assignments for a BDD over $nvars total variables.
;; Variables are numbered 1..$nvars; $level tracks which variable we expect next.
(= (bdd-satcount-aux $f $nvars $level)
    (if (is-terminal $f)
        (if (== $f bdd-1)
            ;; All vars from $level onward are free (unconstrained).
            ;; We've decided ($level - 1) vars so far, leaving (nvars - level + 1).
            (pow-math 2 (- $nvars (- $level 1)))
            0)
        (let* (($v (bdd-var $f))
                ;; Vars between $level and $v were eliminated (irrelevant on this path).
                ;; Each can be T/F independently, so multiply by 2^skip.
                ($skip (- $v $level))
                ($lo-count (bdd-satcount-aux (bdd-lo $f) $nvars (+ $v 1)))
                ($hi-count (bdd-satcount-aux (bdd-hi $f) $nvars (+ $v 1))))
            (* (pow-math 2 $skip) (+ $lo-count $hi-count)))))

(= (bdd-satcount $f $nvars)
    (bdd-satcount-aux $f $nvars 1))

(= (bdd-max-var $f)
    (if (is-terminal $f)
        0
        (max (bdd-var $f)
             (max (bdd-max-var (bdd-lo $f))
                  (bdd-max-var (bdd-hi $f))))))
; Count the number of vars in f (not always works if we use two d/t BDDs)
(= (bdd-satcount $f)
    (bdd-satcount $f (bdd-max-var $f)))

;; A → B  ≡  ¬A ∨ B
(= (bdd-implies $a $b) (apply-bdd bdd-or (bdd-not $a) $b))
;; A ↔ B  ≡  ¬(A ⊕ B)
(= (bdd-iff $a $b) (bdd-not (apply-bdd bdd-xor $a $b)))

;; Build a conjunction (AND) of variable BDDs from a list of var IDs
;; (bdd-conjunction (1 2 3)) = BDD for x1 ∧ x2 ∧ x3
(= (bdd-conjunction $bdds)
    (if (== $bdds ())
        bdd-1
        (apply-bdd bdd-and (car-atom $bdds) (bdd-conjunction (cdr-atom $bdds)))))
;; Build a disjunction (OR) of BDDs from a list of BDDs
(= (bdd-disjunction $bdds)
    (if (== $bdds ())
        bdd-0
        (apply-bdd bdd-or (car-atom $bdds) (bdd-disjunction (cdr-atom $bdds)))))

;; Convert DNF (list of clauses) to a single BDD
;; Each clause is a list of variable IDs to AND together
;; The clauses are OR'd together
;; Example: ((1 2) (3)) represents (x1 ∧ x2) ∨ x3
(= (bdd-from-dnf $clauses)
    (if (== $clauses ())
        bdd-0
        (let* (($clause (car-atom $clauses))
               ($rest (cdr-atom $clauses))
             ($bdd-clause (collapse (bdd-var-node (superpose $clause)))))
            (apply-bdd bdd-or (bdd-conjunction $bdd-clause) (bdd-from-dnf $rest)))))
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Weighted Model Counting (WMC) ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Weighted Model Counting (WMC)
;; Computes the probability of a boolean function represented as a BDD.
;; $env maps each variable to its probability of being True:
;;   ((1 0.3) (2 0.7) (3 0.5))
;; At each node: WMC(f) = (1 - p_v) * WMC(f_lo) + p_v * WMC(f_hi)
;; Skipped variables need no correction since p + (1-p) = 1.
(= (bdd-wmc $f $env)
    (if (is-terminal $f)
        (if (== $f bdd-1)
            1.0
            0.0)
        (let* (($var (bdd-var $f))
               ($val (env-lookup $var $env))
               ($lo-w (* (- 1 $val) (bdd-wmc (bdd-lo $f) $env)))
               ($hi-w (* $val (bdd-wmc (bdd-hi $f) $env))))
            
            (+ $lo-w $hi-w))))

