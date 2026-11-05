!(import! &self (library lib_prob))

;; Negation as failure
;; 0.1::burglary.
;; 0.2::earthquake.
;; 0.7::hears_alarm(X).
;;
;; alarm :- burglary.
;; alarm :- earthquake.
;; calls(X) :- alarm, hears_alarm(X), \+ earthquake.
;;
;; query(calls(mary)).
;; Expected: P(calls(mary)) = P(burglary) * P(hears_alarm(mary)) * (1 - P(earthquake))
;;         = 0.1 * 0.7 * 0.8 = 0.056

;; MeTTa version:
!(:: 0.1 burglary)
!(:: 0.2 earthquake)
!(:: 0.7 (hears_alarm $x))

!(=> (, burglary) alarm)
!(=> (, earthquake) alarm)
!(=> (, alarm (hears_alarm mary) (naf earthquake)) (calls mary))

!(test (?prob (calls mary)) 0.056)