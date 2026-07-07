# ProbMeTTa

A probabilistic logic programming library for MeTTa implementing ProbLog-style distribution semantics. It compiles probabilistic programs into Binary Decision Diagrams (BDDs) for exact inference via weighted model counting, supporting probabilistic facts, annotated disjunctions, negation-as-failure, and evidence conditioning.

## Requirements

- [PeTTa](https://github.com/patham9/PeTTa) — a MeTTa implementation compiling to SWI-Prolog

## Quick Start

```metta
!(import! &self (library lib_import))
!(git-import! "https://github.com/Habush/ProbMeTTa.git")
!(import &self (library lib_prob))

;; Probabilistic facts
!(:: 0.7 burglary)
!(:: 0.2 earthquake)

;; Probabilistic rules
!(::=> 0.9 alarm (, burglary earthquake))
!(::=> 0.8 alarm (, burglary (naf earthquake)))
!(::=> 0.1 alarm (, (naf burglary) earthquake))

;; Query
!(?prob alarm)         ;; => 0.58
```

You can test the above and other examples [here](https://dev.rejuve.bio/probmetta/)

## Features

- **Probabilistic facts** (`::`) - `(:: 0.3 earthquake)`
- **Deterministic facts** (`fact`) and **rules** (`=>`)
- **Probabilistic rules** (`::=>`) — `(::=> 0.9 alarm (, earthquake))`
- **Annotated disjunctions** (`::`) — multi-valued random variables. `(:: (0.5 (color red)), (0.5 (color green)))`
- **Negation-as-failure** (`naf`) `(::=> 0.2 alarm (, earthquake (naf burglary)))`
- **Marginal queries** (`?prob`) — `(?prob alarm)`
- **Conditional queries** (`?prob-given`) — evidence conditioning `P(A|B) = (?prob-give A (B))`

## Examples

### Bayesian Network

```metta
!(import! &self (library lib_import))
!(git-import! "https://github.com/Habush/ProbMeTTa.git")
!(import &self (library lib_prob))

;; Deterministic facts
!(fact (person john))
!(fact (person mary))

;; Probabilistic facts
!(:: 0.7 burglary)

;; Annotated disjunction — multi-valued random variable
!(:: ((0.01 (earthquake heavy)) (0.19 (earthquake mild)) (0.8 (earthquake none))))

;; Probabilistic rules with negation-as-failure
!(::=> 0.90 alarm (, burglary (earthquake heavy)))
!(::=> 0.85 alarm (, burglary (earthquake mild)))
!(::=> 0.80 alarm (, burglary (earthquake none)))
!(::=> 0.30 alarm (, (naf burglary) (earthquake heavy)))
!(::=> 0.10 alarm (, (naf burglary) (earthquake mild)))

;; Template rule — $x grounds lazily to each person
!(::=> 0.8 (calls $x) (, alarm (person $x)))
!(::=> 0.1 (calls $x) (, (naf alarm) (person $x)))

;; Conditional query — P(burglary | calls(john) ∧ calls(mary))
!(?prob-given burglary ((calls john) (calls mary)))  ;; => 0.98074
```

### Probabilistic Graph Reachability

```metta
!(import! &self (library lib_import))
!(git-import! "https://github.com/Habush/ProbMeTTa.git")
!(import &self (library lib_prob))

!(:: 0.6 (edge 1 2))
!(:: 0.1 (edge 1 3))
!(:: 0.4 (edge 2 5))
!(:: 0.3 (edge 2 6))
!(:: 0.3 (edge 3 4))
!(:: 0.8 (edge 4 5))
!(:: 0.2 (edge 5 6))

;; Recursive path definition with inequality guard
!(=> (, (edge $x $y)) (path $x $y))
!(=> (, (edge $x $z) (neq $y $z) (path $z $y)) (path $x $y))

!(?prob (path 1 5))  ;; => 0.25824
!(?prob (path 1 6))  ;; => 0.21673
```

## Future Work

- **Tabling**: Support for recursive queries on cyclic graphs via tabled evaluation.
- **Variable reordering**: Dynamic BDD variable reordering for improved performance.
- **Continuous distributions**: Extend beyond discrete probabilistic facts to continuous distributions.
- **Approximate inference**: Sampling-based methods (MCMC, likelihood weighting) for large programs where exact BDD-based inference becomes intractable.

## References

- De Raedt, L., Kimmig, A., & Toivonen, H. (2007). ProbLog: A Probabilistic Prolog and its Application in Link Discovery.
- Riguzzi, F., Swift T. (2011). The PITA system: Tabling and answer subsumption for reasoning under uncertainty.
- Riguzzi, F. (2018). Foundations of Probabilistic Logic Programming.
- Bryant, R.E. (1986). Graph-Based Algorithms for Boolean Function Manipulation.

*AI Usage Disclaimer*

*Parts of this codebase have been written with the help of AI Coding tools, particularly the tests have been mainly generated with Claude Code. However, I've manually verified every piece of code before committing. Please open an issue if you find any bugs.*
