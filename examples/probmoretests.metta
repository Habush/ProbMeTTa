!(import! &self (library lib_prob))

;; Test: Overlapping rules (multiple derivation paths)
;; P(d) = 1 - (1-0.3*0.5)*(1-0.4) = 0.49
!(clear-prob!)
!(:: 0.3 a)
!(:: 0.5 b)
!(:: 0.4 c)
!(=> (, a b) d)
!(=> (, c) d)
!(test-prob (?prob d) 0.49)

;; Test: Chain of length 3
;; P(z) = 0.5 * 0.8 * 0.6 = 0.24
!(clear-prob!)
!(:: 0.5 x)
!(::=> 0.8 y (, x))
!(::=> 0.6 z (, y))
!(test-prob (?prob z) 0.24)

;; Test: Annotated disj with body + negation query
;; P(h1) = 0.9*0.6 = 0.54, P(not h1) = 0.46
!(clear-prob!)
!(:: 0.9 trigger)
!(::=> 0.6 h1 (, trigger))
!(::=> 0.4 h2 (, trigger (naf h1)))
!(=> (, (naf h1)) not-h1)
!(test-prob (?prob h1) 0.54)
!(test-prob (?prob not-h1) 0.46)

;; Test: Deterministic facts in rule bodies
;; P(close alice bob) = 0.8
!(clear-prob!)
!(fact (parent alice bob))
!(fact (parent bob charlie))
!(:: 0.8 (likes $x $y))
!(=> (, (parent $x $y) (likes $x $y)) (close $x $y))
!(test-prob (?prob (close alice bob)) 0.8)

;; Test: Multiple independent AD groups
;; P(red-big) = 0.6 * 0.7 = 0.42
!(clear-prob!)
!(:: ((0.6 (color red)) (0.4 (color blue))))
!(:: ((0.7 (size big)) (0.3 (size small))))
!(=> (, (color red) (size big)) red-big)
!(test-prob (?prob red-big) 0.42)

;; Test: Evidence conditioning with AD
;; P(red | not blue) = 0.6/0.9 = 0.66667
!(clear-prob!)
!(:: ((0.6 (color red)) (0.3 (color green)) (0.1 (color blue))))
!(=> (, (naf (color blue))) not-blue)
!(test-prob (?prob-given (color red) (not-blue)) 0.66667)

!(clear-prob!)

!(:: 0.6 (edge 1 2))
!(:: 0.1 (edge 1 3))
!(:: 0.4 (edge 2 5))
!(:: 0.3 (edge 2 6))
!(:: 0.3 (edge 3 4))
!(:: 0.8 (edge 4 5))
!(:: 0.2 (edge 5 6))

!(=> (, (edge $x $y)) (path $x $y))
!(=> (, (edge $x $z) (neq $y $z) (path $z $y)) (path $x $y))

;; ProbLog expected:
;; path(1,5) = 0.25824
;; path(1,6) = 0.21
!(test-prob (?prob (path 1 5)) 0.25824)
!(test-prob (?prob (path 1 6)) 	0.21673)
