!(import! &self (library lib_prob))

; person(john).
; person(mary).

; 0.7::burglary.
; 0.2::earthquake.

; 0.9::alarm :- burglary, earthquake.
; 0.8::alarm :- burglary, \+earthquake.
; 0.1::alarm :- \+burglary, earthquake.

; 0.8::calls(X) :- alarm, person(X).
; 0.1::calls(X) :- \+alarm, person(X).

; evidence(calls(john),true).
; evidence(calls(mary),true).

; query(burglary).
; query(earthquake(_)).

!(fact (person john))
!(fact (person mary))

!(:: 0.7 burglary)
!(:: 0.2 earthquake)

!(::=> 0.9 alarm (, burglary earthquake))
!(::=> 0.8 alarm (, burglary (naf earthquake)))
!(::=> 0.1 alarm (, (naf burglary) earthquake))

!(::=> 0.8 (calls $x) (, alarm (person $x)))
!(::=> 0.1 (calls $x) (, (naf alarm) (person $x)))

!(test-prob (?prob-given earthquake ((calls john) (naf (calls mary)))) 0.2268)
!(test-prob (?prob-given burglary ((calls john) (naf (calls mary)))) 0.98194)

!(clear-prob!)

!(fact (person john))
!(fact (person mary))

!(:: 0.7 burglary)
!(:: ((0.01 (earthquake heavy)) (0.19 (earthquake mild)) (0.8 (earthquake none))))

!(::=> 0.90 alarm (, burglary (earthquake heavy)))
!(::=> 0.85 alarm (, burglary (earthquake mild)))
!(::=> 0.80 alarm (, burglary (earthquake none)))
!(::=> 0.30 alarm (, (naf burglary) (earthquake heavy)))
!(::=> 0.10 alarm (, (naf burglary) (earthquake mild)))

!(::=> 0.8 (calls $x) (, alarm (person $x)))
!(::=> 0.1 (calls $x) (, (naf alarm) (person $x)))

!(test-prob (?prob-given burglary ((calls john) (calls mary))) 0.98074)
!(test-prob (?prob-given (earthquake heavy) ((calls john) (calls mary))) 0.01248)
!(test-prob (?prob-given (earthquake mild) ((calls john) (calls mary))) 0.20644)
!(test-prob (?prob-given (earthquake none) ((calls john) (calls mary))) 0.78108)
