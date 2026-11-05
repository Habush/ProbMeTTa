!(bind! &pclp (new-space))
!(bind! &rules (new-space))

(= (=> $head $goals)
	(add-atom &rules (rule $head $goals)))

(= (pclp-clear!)
	(collapse
	 (match &pclp $atom
			  (remove-atom &pclp $atom))))

(= (rules-clear!)
	(collapse
	 (match &rules $atom
			  (remove-atom &rules $atom))))

(= (bc-goals ()) ())

(= (bc (c_in $lhs $rhs))
	((c_in $lhs $rhs)))
(= (bc (c_eq $lhs $rhs))
	((c_eq $lhs $rhs)))

(= (bc (c_ne $lhs $rhs))
	((c_ne $lhs $rhs)))

(= (bc (c_lt $lhs $rhs))
	((c_lt $lhs $rhs)))

(= (bc (c_le $lhs $rhs))
	((c_le $lhs $rhs)))

(= (bc (c_gt $lhs $rhs))
	((c_gt $lhs $rhs)))

(= (bc (c_ge $lhs $rhs))
	((c_ge $lhs $rhs)))

(= (bc (c_interval $ltype $lo $expr $hi $rtype))
	((c_interval $ltype $lo $expr $hi $rtype)))

(= (bc $goal)
	(let $goals
		  (match &pclp
					(rule $_ $goal $goals)
					$goals)
		  (bc-goals $goals)))

(= (bc $goal)
	(let $goals
		  (match &rules
					(rule $goal $goals)
					$goals)
		  (bc-goals $goals)))

(= (bc-goals (cons $goal $goals))
	(let* (($support (bc $goal))
			 ($rest (bc-goals $goals)))
			(append $support $rest)))


(= (build-solution-formula $supports)
	(f_or (supports-to-disjuncts $supports)))

(= (supports-to-disjuncts ()) ())

(= (supports-to-disjuncts (cons $support $supports))
	(cons (f_and $support)
			(supports-to-disjuncts $supports)))

(= (normalize-formula (f_or $disjuncts))
	(normalize-disjunction (sort (normalize-disjuncts $disjuncts))))

; This is possible if the chainer found NO proofs.
(= (normalize-disjunction ()) False) 

(= (normalize-disjunction (cons $disjunct $disjuncts))
	(let $normalized (cons $disjunct $disjuncts)
		 (if (is-member (f_and ()) $normalized) ; successful logical proof w/o prob constraints
			 True
			 (f_or $normalized))))

(= (normalize-disjuncts ()) ())

(= (normalize-disjuncts (cons (f_and $support) $disjuncts))
	(cons (f_and (sort $support))
			(normalize-disjuncts $disjuncts)))

; (= (formula-rv-instances True) ())
; (= (formula-rv-instances False) ())

(= (formula-rv-instances $formula)
	(case $formula
		((True ())
		(False ())
		($_ (sort (rv-to-instances (formula-rvs $formula)))))))

(= (rv-to-instances ()) ())

(= (rv-to-instances (cons $rv $rvs))
	(let* (($instance (rv-to-instance $rv))
			($instances (rv-to-instances $rvs)))
		(cons $instance $instances)))

(= (formula-rvs $formula)
	(unique-atom (collect-rvs $formula)))

(= (collect-rvs ()) ())

(= (collect-rvs $expr)
	(if (is-expr $expr)
		 (if (== (car-atom $expr) e_rv)
			  (cons $expr ())
			  (collect-rv-list $expr))
		 ()))

(= (collect-rv-list ()) ())

(= (collect-rv-list (cons $head $tail))
	(append (collect-rvs $head)
			  (collect-rv-list $tail)))

(= (rv-to-instance (e_rv $name $args))
	(let $choices
		  (match &pclp
					(rv_definition
						$def-id
						(rv_labels $labels)
						(parameters $args)
						(domains $_)
						(choices $choices))
					$choices)
		  (if (is-member $name $labels)
			  (rv-instance $def-id $args)
			  (empty))))

(= (instance-choices (rv-instance $def-id $args))
	(let $choices
		  (match &pclp
					(rv_definition
					 $def-id
					 (rv_labels $labels)
					 (parameters $args)
					 (domains $_)
					 (choices $choices))
					$choices)
		  (collapse
		  		(let (choice $choice-id $prob $constr) (superpose $choices)
					(choice $choice-id $prob $constr)))))

(= (instance-choice $instance $choice-id)
	(index-atom (instance-choices $instance) $choice-id))

(= (rv-domain-entry $name ($name $domain))
	$domain)

(= (rv-domain (e_rv $name $args))
	(let $domains
		 (match &pclp
				(rv_definition
				 $_
				 (rv_labels $labels)
				 (parameters $args)
				 (domains $domains)
				 (choices $_))
				$domains)
		 (if (is-member $name $labels)
			 (once (rv-domain-entry $name (superpose $domains)))
			 (empty))))

(= (rv-choices (e_rv $name $args))
	(let $choices
		  (match &pclp
					(rv_definition
					 $_
					 (rv_labels $labels)
					 (parameters $args)
						 (domains $_)
					 (choices $choices))
					$choices)
		  (if (is-member $name $labels)
			  $choices
			  (empty))))

(= (delta-choice-id-entry $instance (selected $instance $choice-id))
	$choice-id)

(= (delta-choice-id $instance $delta)
	(once (delta-choice-id-entry $instance (superpose $delta))))

(= (delta-instances ()) ())

(= (delta-instances (cons (selected $instance $_) $delta))
	(cons $instance (delta-instances $delta)))

(= (delta-select $instance $choice-id $delta)
	(let (choice $choice-id $_ $_)
		 (instance-choice $instance $choice-id)
		 (if (is-member (selected $instance $choice-id) $delta)
			 (sort $delta)
			 (if (is-member $instance (delta-instances $delta))
				 (empty)
				 (sort (cons (selected $instance $choice-id) $delta))))))

(= (delta-constraints ()) ())

(= (delta-constraints (cons (selected $instance $choice-id) $delta))
	(let (choice $choice-id $_ $constr)
		 (instance-choice $instance $choice-id)
		 (cons $constr (delta-constraints $delta))))
