!(import! &self chainer)

!(pclp-clear!)
!(rules-clear!)
; day(monday). day(tuesday).
!(add-atom &pclp (rule 0 (day monday) ()))
!(add-atom &pclp (rule 1 (day tuesday) ()))
; comfortable(D) ← day(D) ∧ temperature(D) > 20.
!(add-atom &pclp
            (rule 2
                  (comfortable $day)
                  ((day $day)
                   (c_gt (e_rv temperature ($day)) (e_lit 20)))))

              ; day(friday) has no SLD derivation.
!(test (collapse (bc (day friday)))
       ())

              ; Querying day(D) enumerates both substitutions with empty supports.
!(test (msort
         (collapse
          (let $support (bc (day $day))
               ($day $support))))
       ((monday ())
        (tuesday ())))

; same(X, X).
!(add-atom &pclp (rule 3 (same $value $value) ()))

; Native unification rejects monday = tuesday.
!(test (collapse (bc (same monday tuesday)))
  ())

; next(monday, tuesday). next(tuesday, wednesday).
!(add-atom &pclp (rule 4 (next monday tuesday) ()))
!(add-atom &pclp (rule 5 (next tuesday wednesday) ()))
; two-days(A, C) ← next(A, B) ∧ next(B, C).
!(add-atom &pclp
       (rule 6
        (two-days $start $end)
        ((next $start $middle)
         (next $middle $end))))

; The shared variable B propagates through both body goals.
!(test (collapse (bc (two-days monday wednesday)))
  (()))

; dry(D) ← day(D), stored in &rules rather than &pclp.
!(=> (dry $day)
  ((day $day)))

; picnic(D) ← dry(D), crossing from &pclp into &rules.
!(add-atom &pclp
      (rule 7
         (picnic $day)
         ((dry $day))))

; Mixed-space chaining preserves both day substitutions.
!(test (msort
      (collapse
    (let $support (bc (picnic $day))
      ($day $support))))
    ((monday ())
     (tuesday ())))

  ; Each derivation accumulates only its probabilistic constraint.
!(test (msort
         (collapse
          (let $support (bc (comfortable $day))
               ($day $support))))
       ((monday
          ((c_gt (e_rv temperature (monday)) (e_lit 20))))
        (tuesday
          ((c_gt (e_rv temperature (tuesday)) (e_lit 20))))))

; comfortable(monday) ← temperature(monday) < 30.
!(add-atom &pclp
    (rule 8
          (comfortable monday)
          ((c_lt (e_rv temperature (monday)) (e_lit 30)))))

; The two proofs become (Tₘ > 20) ∨ (Tₘ < 30).
!(test
  (build-solution-formula
   (collapse (bc (comfortable monday))))
  (f_or
   ((f_and
     ((c_gt (e_rv temperature (monday)) (e_lit 20))))
    (f_and
     ((c_lt (e_rv temperature (monday)) (e_lit 30)))))))

  ; ⋁∅ = False.
!(test (normalize-formula (f_or ()))
       False)

  ; A deterministic empty support contributes True, so A ∨ True = True.
!(test
  (normalize-formula
   (f_or
    ((f_and ((c_eq (e_rv coin ()) (e_lit true))))
     (f_and ()))))
  True)

; Canonicalization removes duplicate constraints and duplicate conjunctions.
!(test
  (normalize-formula
   (f_or
    ((f_and
      ((c_lt (e_rv temperature ()) (e_lit 20))
       (c_eq (e_rv coin ()) (e_lit true))
       (c_lt (e_rv temperature ()) (e_lit 20))))
     (f_and
      ((c_eq (e_rv coin ()) (e_lit true))
       (c_lt (e_rv temperature ()) (e_lit 20)))))))
  (f_or
   ((f_and
     ((c_eq (e_rv coin ()) (e_lit true))
      (c_lt (e_rv temperature ()) (e_lit 20)))))))

    ; Repeated Tₘ occurrences are deduplicated; coin remains distinct.
!(test
  (formula-rvs
   (f_or
    ((f_and
      ((c_gt (e_rv temperature (monday)) (e_lit 20))
       (c_eq (e_rv coin ()) (e_lit true))))
     (f_and
      ((c_lt (e_rv temperature (monday)) (e_lit 30)))))))
  ((e_rv temperature (monday))
   (e_rv coin ())))

; G₀(day): χ₀ [0.7] temperature(day) > 20
;          χ₁ [0.3] temperature(day) ≤ 20
!(add-atom &pclp
            (rv_definition
             0
             (rv_labels (temperature))
             (parameters ($day))
             (domains ((temperature real)))
             (choices
                  ((choice 0 0.7
                       (c_gt (e_rv temperature ($day)) (e_lit 20)))
                   (choice 1 0.3
                       (c_le (e_rv temperature ($day)) (e_lit 20)))))))

; Resolving choices for temperature(monday) instantiates day = monday.
!(test
  (rv-choices (e_rv temperature (monday)))
            ((choice 0 0.7
           (c_gt (e_rv temperature (monday)) (e_lit 20)))
             (choice 1 0.3
     (c_le (e_rv temperature (monday)) (e_lit 20)))))

  ; No RV definition contains the label humidity.
!(test (collapse (rv-choices (e_rv humidity (monday))))
       ())

!(pclp-clear!)

; G₀(): χ₀ [0.8] coin = true; χ₁ [0.2] coin = false
!(add-atom &pclp
  (rv_definition
    0
    (rv_labels (coin))
    (parameters ())
    (domains ((coin (discrete (true false)))))
    (choices
      ((choice 0 0.8
         (c_eq (e_rv coin ()) (e_lit true)))
       (choice 1 0.2
         (c_eq (e_rv coin ()) (e_lit false)))))))

; G₁(day): χ₀ [0.7] temperature(day) > 20 ∧ humidity(day) < 70
;          χ₁ [0.3] temperature(day) ≤ 20 ∧ humidity(day) ≥ 70
!(add-atom &pclp
  (rv_definition
    1
    (rv_labels (temperature humidity))
    (parameters ($day))
    (domains ((temperature real)
          (humidity real)))
    (choices
      ((choice 0 0.7
         (c_and
           ((c_gt (e_rv temperature ($day)) (e_lit 20))
            (c_lt (e_rv humidity ($day)) (e_lit 70)))))
       (choice 1 0.3
         (c_and
           ((c_le (e_rv temperature ($day)) (e_lit 20))
            (c_ge (e_rv humidity ($day)) (e_lit 70)))))))))

             ; coin belongs to RV instance G₀().
        !(test (rv-to-instance (e_rv coin ()))
          (rv-instance 0 ()))

          ; Domains are resolved by label from the instantiated definition table.
          !(test (rv-domain (e_rv coin ()))
            (discrete (true false)))

          !(test (rv-domain (e_rv humidity (monday)))
            real)

             ; Both joint labels at monday belong to the same RV instance G₁(monday).
        !(test (rv-to-instance (e_rv temperature (monday)))
          (rv-instance 1 (monday)))

        !(test (rv-to-instance (e_rv humidity (monday)))
          (rv-instance 1 (monday)))

        ; pressure has no defining RV instance.
        !(test (collapse (rv-to-instance (e_rv pressure (monday))))
       ())

; Joint labels coalesce, repeated occurrences deduplicate, and days stay distinct.
!(test
  (formula-rv-instances
    (f_or
      ((f_and
         ((c_gt (e_rv temperature (monday)) (e_lit 20))
          (c_lt (e_rv humidity (monday)) (e_lit 70))
          (c_eq (e_rv coin ()) (e_lit true))))
       (f_and
         ((c_lt (e_rv temperature (monday)) (e_lit 30))
          (c_gt (e_rv temperature (tuesday)) (e_lit 10)))))))
    ((rv-instance 0 ())
     (rv-instance 1 (monday))
     (rv-instance 1 (tuesday))))

  ; Terminal formulas contain no unresolved RV instances.
  !(test (formula-rv-instances True)
       ())

  !(test (formula-rv-instances False)
       ())

; χ₁ of G₀() is the false coin alternative.
  !(test (instance-choice (rv-instance 0 ()) 1)
       (choice 1 0.2
         (c_eq (e_rv coin ()) (e_lit false))))

; Resolving G₁(monday) instantiates every joint constraint with monday.
!(test
    (instance-choices (rv-instance 1 (monday)))
  ((choice 0 0.7
     (c_and
       ((c_gt (e_rv temperature (monday)) (e_lit 20))
        (c_lt (e_rv humidity (monday)) (e_lit 70)))))
   (choice 1 0.3
     (c_and
       ((c_le (e_rv temperature (monday)) (e_lit 20))
        (c_ge (e_rv humidity (monday)) (e_lit 70)))))))

      ; Δ = {G₀() ↦ χ₁, G₁(monday) ↦ χ₀}; lookup returns χ₀.
!(test
  (delta-choice-id
    (rv-instance 1 (monday))
    ((selected (rv-instance 0 ()) 1)
     (selected (rv-instance 1 (monday)) 0)))
  0)

; G₁(tuesday) is not selected by Δ = {G₁(monday) ↦ χ₀}.
!(test
  (collapse
    (delta-choice-id
      (rv-instance 1 (tuesday))
      ((selected (rv-instance 1 (monday)) 0))))
  ())

; Selection preserves canonical RV-instance ordering.
!(test
  (delta-select
    (rv-instance 0 ())
    1
    ((selected (rv-instance 1 (monday)) 0)))
  ((selected (rv-instance 0 ()) 1)
   (selected (rv-instance 1 (monday)) 0)))

; Re-selecting the same RV instance and choice is idempotent.
!(test
  (delta-select
    (rv-instance 1 (monday))
    0
    ((selected (rv-instance 1 (monday)) 0)))
  ((selected (rv-instance 1 (monday)) 0)))

; G₁(monday) cannot be reassigned from χ₀ to χ₁.
!(test
  (collapse
    (delta-select
      (rv-instance 1 (monday))
      1
      ((selected (rv-instance 1 (monday)) 0))))
  ())

; G₀() has no χ₂.
!(test
  (collapse
    (delta-select
      (rv-instance 0 ())
      2
      ()))
  ())

; CΔ is the conjunction of the constraints selected by Δ.
!(test
  (delta-constraints
    ((selected (rv-instance 0 ()) 1)
     (selected (rv-instance 1 (monday)) 0)))
  ((c_eq (e_rv coin ()) (e_lit false))
   (c_and
     ((c_gt (e_rv temperature (monday)) (e_lit 20))
      (c_lt (e_rv humidity (monday)) (e_lit 70))))))

    ; Definition 99 does not identify an RV instance.
  !(test (collapse (instance-choices (rv-instance 99 ())))
       ())
