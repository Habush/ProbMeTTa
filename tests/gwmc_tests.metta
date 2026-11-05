!(import! &self gwmc)

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

; G₁(day): χ₀ [0.5] 0 ≤ temperature(day) ≤ 1
;          χ₁ [0.5] 1 < temperature(day) ≤ 2
!(add-atom &pclp
  (rv_definition
    1
    (rv_labels (temperature))
    (parameters ($day))
    (domains ((temperature real)))
    (choices
      ((choice 0 0.5
         (c_interval closed
                     (e_lit 0)
                     (e_rv temperature ($day))
                     (e_lit 1)
                     closed))
       (choice 1 0.5
         (c_interval open
                     (e_lit 1)
                     (e_rv temperature ($day))
                     (e_lit 2)
                     closed))))))

; G₂(day): χ₀ [1.0] 0 ≤ offset(day) ≤ 1
!(add-atom &pclp
  (rv_definition
    2
    (rv_labels (offset))
    (parameters ($day))
    (domains ((offset real)))
    (choices
      ((choice 0 1.0
         (c_interval closed
                     (e_lit 0)
; Δ = ∅ leaves coin unconstrained, so coin = true is unresolved.
                     (e_rv offset ($day))
                     (e_lit 1)
                     closed))))))

; G₃(day): χ₀ [0.6] pressure(day) > 10 ∧ humidity(day) < 70
;          χ₁ [0.4] pressure(day) ≤ 10 ∧ humidity(day) ≥ 70
!(add-atom &pclp
  (rv_definition
    3
    (rv_labels (pressure humidity))
    (parameters ($day))
    (domains ((pressure real)
          (humidity real)))
    (choices
      ((choice 0 0.6
         (c_and
           ((c_gt (e_rv pressure ($day)) (e_lit 10))
            (c_lt (e_rv humidity ($day)) (e_lit 70)))))
       (choice 1 0.4
         (c_and
           ((c_le (e_rv pressure ($day)) (e_lit 10))
            (c_ge (e_rv humidity ($day)) (e_lit 70)))))))))

; G₄(): χ₀ [1.0] temperature(monday) > 2
!(add-atom &pclp
  (rv_definition
    4
    (rv_labels (gate))
    (parameters ())
    (domains ((gate real)))
    (choices
      ((choice 0 1.0
         (c_gt (e_rv temperature (monday)) (e_lit 2)))))))

; G₅(): gain is positive by domain.
!(add-atom &pclp
  (rv_definition
    5
    (rv_labels (gain))
    (parameters ())
    (domains ((gain pos)))
    (choices
      ((choice 0 1.0
         (c_gt (e_rv gain ()) (e_lit 0)))))))

; G₆(): m({red}) = 0.5, m({blue}) = 0.2,
;       m({red, blue, green}) = 0.3
!(add-atom &pclp
  (rv_definition
    6
    (rv_labels (color))
    (parameters ())
    (domains ((color (discrete (red blue green)))))
    (choices
      ((choice 0 0.5
         (c_eq (e_rv color ()) (e_lit red)))
       (choice 1 0.2
         (c_eq (e_rv color ()) (e_lit blue)))
       (choice 2 0.3
         (c_in (e_rv color ()) (red blue green)))))))

!(test
  (classify-constraint
    (c_eq (e_rv coin ()) (e_lit true))
    (ctx () ()))
  unk)

; Δ = {G₀() ↦ χ₀} entails coin = true.
!(test
  (classify-constraint
    (c_eq (e_rv coin ()) (e_lit true))
    (ctx ((selected (rv-instance 0 ()) 0)) ()))
  True)

; Δ = {G₀() ↦ χ₀} contradicts coin = false.
!(test
  (classify-constraint
    (c_eq (e_rv coin ()) (e_lit false))
    (ctx ((selected (rv-instance 0 ()) 0)) ()))
  False)

; Δ = {G₀() ↦ χ₀} entails coin ≠ false.
!(test
  (classify-constraint
    (c_ne (e_rv coin ()) (e_lit false))
    (ctx ((selected (rv-instance 0 ()) 0)) ()))
  True)

; 0 ≤ Tₘ ≤ 1 entails Tₘ ≥ 0.
!(test
  (classify-constraint
    (c_ge (e_rv temperature (monday)) (e_lit 0))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  True)

; 0 ≤ Tₘ ≤ 1 permits both Tₘ = 0 and Tₘ > 0.
!(test
  (classify-constraint
    (c_gt (e_rv temperature (monday)) (e_lit 0))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  unk)

; 0 ≤ Tₘ ≤ 1 contradicts Tₘ < 0.
!(test
  (classify-constraint
    (c_lt (e_rv temperature (monday)) (e_lit 0))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  False)

; 1 < Tₘ ≤ 2 entails Tₘ > 1; the open endpoint matters.
!(test
  (classify-constraint
    (c_gt (e_rv temperature (monday)) (e_lit 1))
    (ctx ((selected (rv-instance 1 (monday)) 1)) ()))
  True)

; 0 ≤ Tₘ,Oₘ ≤ 1 entails Tₘ + 0.25Oₘ ≤ 1.25 < 1.375.
!(test
  (classify-constraint
    (c_lt
      (e_add
        (e_rv temperature (monday))
        (e_mul (e_lit 0.25) (e_rv offset (monday))))
      (e_lit 1.375))
    (ctx
      ((selected (rv-instance 1 (monday)) 0)
       (selected (rv-instance 2 (monday)) 0))
      ()))
  True)

; 0 ≤ Tₘ,Oₘ ≤ 1 permits both Tₘ + Oₘ < 1 and Tₘ + Oₘ ≥ 1.
!(test
  (classify-constraint
    (c_lt
      (e_add
        (e_rv temperature (monday))
        (e_rv offset (monday)))
      (e_lit 1))
    (ctx
      ((selected (rv-instance 1 (monday)) 0)
       (selected (rv-instance 2 (monday)) 0))
      ()))
  unk)

; 0 ≤ Tₘ ≤ 1 entails (Tₘ + 1) / 2 ≤ 1.
!(test
  (classify-constraint
    (c_le
      (e_div
        (e_add (e_rv temperature (monday)) (e_lit 1))
        (e_lit 2))
      (e_lit 1))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  True)

; 0 ≤ Tₘ ≤ 1 entails Tₘ - 1 ≤ 0.
!(test
  (classify-constraint
    (c_le
      (e_sub (e_rv temperature (monday)) (e_lit 1))
      (e_lit 0))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  True)

; Δ = {G₃(monday) ↦ χ₀} entails Hₘ < 70, hence Hₘ < 80.
!(test
  (classify-constraint
    (c_lt (e_rv humidity (monday)) (e_lit 80))
    (ctx ((selected (rv-instance 3 (monday)) 0)) ()))
  True)

; Δ = {G₃(monday) ↦ χ₀} entails Pₘ > 10, contradicting Pₘ ≤ 10.
!(test
  (classify-constraint
    (c_le (e_rv pressure (monday)) (e_lit 10))
    (ctx ((selected (rv-instance 3 (monday)) 0)) ()))
  False)

; Dom(gain) = Pos entails gain > 0 even when Δ = ∅.
!(test
  (classify-constraint
    (c_gt (e_rv gain ()) (e_lit 0))
    (ctx () ()))
  True)

; Δ = ∅ is satisfiable.
!(test
  (delta-consistent ())
  True)

; Δ entails 0 ≤ Tₘ ≤ 1 ∧ 0 ≤ Oₘ ≤ 1, which is satisfiable.
!(test
  (delta-consistent
    ((selected (rv-instance 1 (monday)) 0)
     (selected (rv-instance 2 (monday)) 0)))
  True)

; Δ entails 0 ≤ Tₘ ≤ 1 ∧ Tₘ > 2, which is unsatisfiable.
!(test
  (delta-consistent
    ((selected (rv-instance 1 (monday)) 0)
     (selected (rv-instance 4 ()) 0)))
  False)

; Simplification assumes Δ is consistent.
!(test (simplify True (ctx () ()))
       True)

!(test (simplify False (ctx () ()))
       False)

; 0 ≤ Tₘ ≤ 1 entails Tₘ ≥ 0 and leaves Tₘ > 0 unresolved.
!(test
  (simplify
    (f_and
      ((c_ge (e_rv temperature (monday)) (e_lit 0))
       (c_gt (e_rv temperature (monday)) (e_lit 0))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  (f_and
    ((c_gt (e_rv temperature (monday)) (e_lit 0)))))

; A contradicted constraint rejects the whole conjunction.
!(test
  (simplify
    (f_and
      ((c_lt (e_rv temperature (monday)) (e_lit 0))
       (c_gt (e_rv temperature (monday)) (e_lit 0))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  False)

; A false branch is removed while an unresolved branch is retained.
!(test
  (simplify
    (f_or
      ((f_and
         ((c_lt (e_rv temperature (monday)) (e_lit 0))))
       (f_and
         ((c_gt (e_rv temperature (monday)) (e_lit 0))))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  (f_or
    ((f_and
       ((c_gt (e_rv temperature (monday)) (e_lit 0)))))))

; An entailed branch makes the whole disjunction true.
!(test
  (simplify
    (f_or
      ((f_and
         ((c_ge (e_rv temperature (monday)) (e_lit 0))))
       (f_and
         ((c_gt (e_rv temperature (monday)) (e_lit 0))))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  True)

; Positive and negative formula premises participate in classification.
!(test
  (classify-constraint
    (c_eq (e_rv coin ()) (e_lit true))
    (ctx ()
      ((pos
        (f_and
          ((c_eq (e_rv coin ()) (e_lit true))))))))
  True)

!(test
  (classify-constraint
    (c_eq (e_rv coin ()) (e_lit true))
    (ctx ()
      ((neg
        (f_and
          ((c_eq (e_rv coin ()) (e_lit true))))))))
  False)

; Contradictory signed premises make the context inconsistent.
!(test
  (ctx-consistent
    (ctx ()
      ((pos
        (f_and
          ((c_eq (e_rv coin ()) (e_lit true)))))
       (neg
        (f_and
          ((c_eq (e_rv coin ()) (e_lit true))))))))
  False)

; Negating a conjunction means at least one conjunct is false, not both.
!(test
  (classify-constraint
    (c_ne (e_rv coin ()) (e_lit true))
    (ctx ()
      ((neg
        (f_and
          ((c_eq (e_rv coin ()) (e_lit true))
           (c_eq (e_rv color ()) (e_lit red))))))))
  unk)

; Premise insertion is canonical and idempotent.
!(test
  (ctx-add-premise
    (ctx () ((pos (f_and ((c_eq (e_rv coin ()) (e_lit true)))))))
    (pos (f_and ((c_eq (e_rv coin ()) (e_lit true))))))
  (ctx () ((pos (f_and ((c_eq (e_rv coin ()) (e_lit true))))))))

!(test (gwmc True)
       (bound 1 1))

!(test (gwmc False)
       (bound 0 0))

!(test
  (gwmc
    (f_and
      ((c_eq (e_rv coin ()) (e_lit true)))))
  (bound 0.8 0.8))

!(test
  (gwmc
    (f_and
      ((c_gt (e_rv temperature (monday)) (e_lit 0)))))
  (bound 0.5 1.0))

!(test
  (gwmc
    (f_and
      ((c_eq (e_rv color ()) (e_lit red)))))
  (bound 0.5 0.8))

!(test
  (gwmc
    (f_or
      ((f_and ((c_eq (e_rv color ()) (e_lit red))))
       (f_and ((c_eq (e_rv color ()) (e_lit blue))))
       (f_and ((c_eq (e_rv color ()) (e_lit green)))))))
  (bound 1 1))

; A fully selected, undetermined disjunct is selected for the first reduction.
!(test
  (select-unk-disjunct
    ((f_and
       ((c_gt (e_rv temperature (monday)) (e_lit 0))))
     (f_and
       ((c_eq (e_rv coin ()) (e_lit true)))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  (Result
    (f_and
      ((c_gt (e_rv temperature (monday)) (e_lit 0))))))

; Under 0 <= T_m <= 1, the selected disjunct gives upper bound 1; excluding
; it for the lower bound leaves the coin proof with probability 0.8.
!(test
  (gwmc_rec
    (f_or
      ((f_and
         ((c_gt (e_rv temperature (monday)) (e_lit 0))))
       (f_and
         ((c_eq (e_rv coin ()) (e_lit true))))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  (bound 0.8 1))

; No complete disjunct is fully selected, but T_m > 0 is a fully selected,
; undetermined conjunct shared by every disjunct.
!(test
  (select-unk-disjunct
    ((f_and
       ((c_gt (e_rv temperature (monday)) (e_lit 0))
        (c_eq (e_rv coin ()) (e_lit true))))
     (f_and
       ((c_gt (e_rv temperature (monday)) (e_lit 0))
        (c_gt (e_rv temperature (tuesday)) (e_lit 1)))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  None)

!(test
  (select-common-unk-conjunct
    ((f_and
       ((c_gt (e_rv temperature (monday)) (e_lit 0))
        (c_eq (e_rv coin ()) (e_lit true))))
     (f_and
       ((c_gt (e_rv temperature (monday)) (e_lit 0))
        (c_gt (e_rv temperature (tuesday)) (e_lit 1)))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  (Result
    (c_gt (e_rv temperature (monday)) (e_lit 0))))

; The common conjunct gives lower bound 0. Assuming it for the upper bound
; leaves coin or T_t > 1: 0.8 + (1 - 0.8) * 0.5 = 0.9.
!(test
  (gwmc_rec
    (f_or
      ((f_and
         ((c_gt (e_rv temperature (monday)) (e_lit 0))
          (c_eq (e_rv coin ()) (e_lit true))))
       (f_and
         ((c_gt (e_rv temperature (monday)) (e_lit 0))
          (c_gt (e_rv temperature (tuesday)) (e_lit 1))))))
    (ctx ((selected (rv-instance 1 (monday)) 0)) ()))
  (bound 0 0.9))
