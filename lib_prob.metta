; !(import! &self (library lib_import))
; !(git-import! "https://github.com/Habush/ProbMeTTa.git")

!(import! &self (library lib_bdd))

; ; Space for probabilistic facts
; !(bind! &prob-facts (new-space))
; ;; Templates: just probability + pattern
; !(bind! &prob-templates (new-space))

;; Get-or-create a BDD variable for a ground instance
(= (prob-id $atom)
    (if (is-ground $atom)
        (case (once (match &prob-facts (prob-fact $id $_ $atom) $id))
            (($id $id)
             (Empty
                (let* (($prob (once (match &prob-templates (prob-template $p $atom) $p)))
                       ($id (new-id)))
                    (progn 
                        (add-atom &prob-facts (prob-fact $id $prob $atom))
                        $id)))))
        (error! (NonGroundProbabilisticClause: $atom))))

;; "Use" a probabilistic fact in a proof
(= (prob-assume $atom $trace)
    (let $id (prob-id $atom)
        (apply-bdd bdd-and (bdd-var-node $id)  $trace)))


(= (=> $body $head)
    (let $goals (cdr-atom $body)
        (add-atom &self (rule $head $goals))))

;; Execute a probabilistic goal
(= (prob-goal $goal $trace)
    (let $body (match &self (rule $goal $b) $b)
        (case $body
            (((pf $atom) (prob-assume $atom $trace))
            ($goals (exec-conj $goals $trace))))))

;; Negation as a failure Negation of a goal
;; 1. Take a goal
;; 2. Find all its proofs
;; 3. Take a disjunction of the proofs
;; 4. Negate the result
(= (prob-not $goal $bdd-in)
    (let* (($proofs (collapse (prob-goal $goal bdd-1)))
           ($disj (bdd-disjunction $proofs))
           ($neg (bdd-not $disj)))
        (apply-bdd bdd-and $neg $bdd-in)))

(= (prob-goal (naf $goal) $trace)
    (prob-not $goal $trace))

; Inequality constraint in rules
(= (prob-goal (neq $a $b) $trace)
    (if (== $a $b) (empty) $trace))

;; Execute a conjunction of goals, threading the trace
(= (exec-conj $goals $trace)
    (if (== $goals ())
        $trace
        (let $t1 (prob-goal (car-atom $goals) $trace)
            (exec-conj (cdr-atom $goals) $t1))))
;; Build the WMC environment from all registered probabilistic facts
(= (prob-wmc-env)
    (collapse (match &prob-facts (prob-fact $id $prob $_) ($id $prob))))

(= (build-ad-helper ($prob $head) $gid $idx $cm $neg-prefix $body)
    (let* (($cond-prob (/ $prob (- 1 $cm)))
               ($aux (aux $gid $idx $head))
               ($rule-body (append (cons $aux $neg-prefix) $body))
               ($new-neg (cons (naf $aux) $neg-prefix))
               ($new-cm (+ $cm $prob))
               ($new-idx (+ $idx 1)))
            (progn 
                (add-atom &prob-templates (prob-template $cond-prob $aux))
                (add-atom &self (rule $aux (pf $aux)))
                (add-atom &self (rule $head $rule-body))
                ($new-idx $new-cm $new-neg))))

(= (build-ad-rules $alts $gid $idx $cm $neg-prefix $body)
    (let* (($alt (car-atom $alts))
           ($prob (car-atom $alt))
           ($head (car-atom (cdr-atom $alt)))
           ($rest (cdr-atom $alts)))
        (if (== $rest ())
            ;; Last element
            (if (< (+ $cm $prob) 1) ;add implicit null
                (let $_ (build-ad-helper ($prob $head) $gid $idx $cm $neg-prefix $body) (empty))
                (let $body-final (append $neg-prefix $body)
                    (add-atom &self (rule $head $body-final))))
            ;; Not last — process and recurse
            (let ($new-idx $new-cm $new-neg) (build-ad-helper ($prob $head) $gid $idx $cm $neg-prefix $body)
                (build-ad-rules $rest $gid $new-idx $new-cm $new-neg $body)))))

(= (:: $alts)
    (let $gid (new-id)
        (build-ad-rules $alts $gid 1 0 () ())))

;; :: stores template + rule. No BDD variable yet.
(= (:: $prob $goal)
    (progn
        (add-atom &prob-templates (prob-template $prob $goal))
        (add-atom &self (rule $goal (pf $goal)))))

(= (::adr $alts $body)
    (let $gid (new-id)
        (build-ad-rules $alts $gid 1 0 () $body)))

(= (::=> $prob $head $body-expr)
    (let $body (cdr-atom $body-expr)
        (::adr (($prob $head)) $body)))

(= (::=> $heads $body-expr)
    (let $body (cdr-atom $body-expr)
        (::adr $heads $body)))

(= (fact $f) (add-atom &self (rule $f ())))

;; Helper function
(= (remove-all $space)
    (collapse (match $space $x (remove-atom $space $x))))

(= (round-to $x $digits)
    (let $f (pow-math 10 $digits)
        (/ (round-math (* $x $f)) $f)))

;; Clear all probabilistic program state
(= (clear-prob!)
    (progn
        (collapse (match &self (rule $h $b) (remove-atom &self (rule $h $b))))
        (remove-all &prob-facts)
        (remove-all &prob-templates)
        (remove-all &apply-cache)))

(= (?prob-bdd $goal)
    (let $proofs (collapse (prob-goal $goal bdd-1))
        (bdd-disjunction $proofs)))
(= (?prob-bdd-ev $evidence)
        (let $ev-bdds (collapse (?prob-bdd (superpose $evidence)))
            (bdd-conjunction $ev-bdds)))

;; Top-level: query the probability of a goal
(= (?prob $goal)
    (if (is-ground $goal)
        (let* (($final-bdd (?prob-bdd $goal))
           ($env (prob-wmc-env)))
            (round-to (bdd-wmc $final-bdd $env) 5))
        (let $g (match &self (rule $goal $_) $goal)
            (?prob $g))))

;; Top-level: probability of P(Query | Evidence)
(= (?prob-given $query $evidence)
    (if (is-ground $query)
        (let* (($query-bdd (?prob-bdd $query))
                ($evid-bdd (?prob-bdd-ev $evidence))
                ($conj-bdd (apply-bdd bdd-and $query-bdd $evid-bdd))
                ($env (prob-wmc-env))
                ($conj-prob (bdd-wmc $conj-bdd $env))
                ($evid-prob (bdd-wmc $evid-bdd $env)))
            (round-to (/ $conj-prob $evid-prob) 5))
        (let $q (match &self (rule $query $_) $query)
            (?prob-given $q $evidence))))

;; Helper Test function that takes into account decimal points
(= (test-prob $actual $expected)
    (if (< (abs-math (- $actual $expected)) 1e-4)
        (println! ("is " $actual ", should "  $expected ". ✅"))
        (println! ("is " $actual ", should "  $expected ". ❌"))))