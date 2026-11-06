# ProbMeTTa

A probabilistic logic programming library for MeTTa implementing supporting both **ProbLog-style programs** and *hybrid probabilistic programs* through **Probabilistic Constraint Logic Programming (PCLP)**.

ProbLog-style programs support probabilistic facts, probabilistic rules,
annotated disjunctions, negation-as-failure, and evidence conditioning.
To perform inference, proofs are compiled to Binary Decision Diagrams (BDDs), which are used to compute exact probabilities through weighted model counting.


PCLP supports hybrid probabilistic logic programs by combining discrete and continuous random variables with logical rules and constraints. It also supports imprecise probabilities: a model can assign probability
mass to intervals without specifying how that mass is distributed within those intervals. It returns probabilities of queries as lower and upper probability bounds using generalized weighted model counting (GWMC) and constraint solving, following the generalized distribution semantics introduced in the excellent work Michels et al. (2015).


## Setup

See [SETUP](SETUP.md) docs for local installation, using existing SWI-Prolog and
PeTTa installations, and Docker instructions.

## Quick Start

### PCLP

The program in [examples/sample.pclp](examples/sample.pclp) combines a Boolean
random variable with two positive real-valued random variables:

```text
Dom(coin): {True, False}.
Dom(t1): Pos.
Dom(t2): Pos.

coin ~ Bernoulli(0.8).

t1 ~ {0.7: [0, 1], 0.2: [1, 2], 0.1: [2, 3]}.
t2 ~ {0.7: [0, 1], 0.2: [1, 2], 0.1: [2, 3]}.

saved <- coin, t1 < 0.75. ; commas correspond to conjunction
saved <- coin, t1 < 1.25, t1 + 0.25 * t2 < 1.375.

query(saved).
```

Output:

```text
((query 0 (saved) (bound 0.392 0.704)))
```


### ProbLog-style programs

```metta
!(import! &self (library lib_prob))

;; Probabilistic facts
!(:: 0.7 burglary)
!(:: 0.2 earthquake)

;; Probabilistic rules
!(::=> 0.9 alarm (, burglary earthquake))
!(::=> 0.8 alarm (, burglary (naf earthquake)))
!(::=> 0.1 alarm (, (naf burglary) earthquake))

;; Marginal probability
!(?prob alarm)  ;; => 0.58
```

You can test the above and other examples [here](https://dev.rejuve.bio/probmetta/)

## Features

### PCLP

- **Hybrid domains** (`Dom`): Declare Boolean, categorical (`{red, blue}`), and
  continuous (`Real`, `Pos`, `Neg`) random variables.
- **Imprecise probabilities**: Assign probability mass to intervals
  (`0.7: [0, 1]`) or constraint regions and compute exact lower and upper
  probability bounds.
- **Discrete distributions**: `Bernoulli(p)` and categorical mass assignments.
  Incomplete categorical assignments leave the remaining mass unconstrained over
  the declared domain.
- **Joint and parameterized definitions**: Group random variables over shared
  constraint regions (`(temperature, humidity)($city) ~ { ... }`), instantiated
  per parameter tuple.
- **Constraint-based inference**: Combine SLD proof search with CLP(FD) and
  CLP(R) constraint classification and tabled generalized weighted model
  counting.

### ProbLog-style programs

- **Probabilistic facts** (`::`): `(:: 0.3 earthquake)`
- **Deterministic facts** (`fact`) and **rules** (`=>`): `(fact (person john))`
- **Probabilistic rules** (`::=>`): `(::=> 0.9 alarm (, burglary earthquake))`
- **Annotated disjunctions** (`::`): Mutually exclusive multi-valued choices
  such as `(:: ((0.5 (color red)) (0.5 (color green))))`
- **Negation-as-failure** (`naf`): `(::=> 0.8 alarm (, burglary (naf earthquake)))`
- **Marginal and conditional queries** (`?prob`, `?prob-given`): Exact inference
  and evidence conditioning `(?prob-given query (ev1 ev2))` via BDD-based
  weighted model counting.

## Examples

### Drawing from an Partially Specified Urn

This program ([examples/urn_color_weight.pclp](examples/urn_color_weight.pclp))
models drawing a ball from an urn of red, blue, and green balls when only part
of the color distribution is known and ball weights are given only by ranges:

```text
Dom(color): {red, blue, green}.
Dom(weight): Pos.

color ~ {0.5: red, 0.2: blue}. // 0.3 ~ {red, blue, green}

weight ~ {
    0.6: [4, 8],
    0.3: (8, 12],
    0.1: (12, inf)
}.

light-draw($color) <- color = $color, weight <= 5.
heavy-draw($color) <- color = $color, weight > 5.
very-heavy-draw($color) <- color = $color, weight > 10.

query(light-draw(red)). // (0, 0.48)
query(heavy-draw(red)). // (0.2, 0.8)
query(heavy-draw(blue)). // (0.08, 0.5)
query(heavy-draw(green)). // (0, 0.3)
query(heavy-draw(yellow)). // (0, 0)

query(very-heavy-draw(red)). // (0.05, 0.32)
```

Run it with:

```bash
./run.sh lib_pclp.metta examples/urn_color_weight.pclp --silent
```

Output:

```text
((query 0 (light-draw red) (bound 0 0.48))
 (query 1 (heavy-draw red) (bound 0.2 0.8))
 (query 2 (heavy-draw blue) (bound 0.08 0.5))
 (query 3 (heavy-draw green) (bound 0 0.3))
 (query 4 (heavy-draw yellow) (bound 0 0))
 (query 5 (very-heavy-draw red) (bound 0.05 0.32)))
```

### Bayesian Network

This program ([examples/bn.metta](examples/bn.metta)) models an alarm triggered
by a burglary or an earthquake and queries the posterior probability of a
burglary given that both John and Mary called:

```metta
!(import! &self (library lib_prob))

;; Deterministic facts
!(fact (person john))
!(fact (person mary))

;; Probabilistic fact and annotated disjunction
!(:: 0.7 burglary)
!(:: ((0.01 (earthquake heavy))
      (0.19 (earthquake mild))
      (0.8 (earthquake none))))

;; Probabilistic rules with negation-as-failure
!(::=> 0.90 alarm (, burglary (earthquake heavy)))
!(::=> 0.85 alarm (, burglary (earthquake mild)))
!(::=> 0.80 alarm (, burglary (earthquake none)))
!(::=> 0.30 alarm (, (naf burglary) (earthquake heavy)))
!(::=> 0.10 alarm (, (naf burglary) (earthquake mild)))

;; Template rules — $x grounds lazily to each person
!(::=> 0.8 (calls $x) (, alarm (person $x)))
!(::=> 0.1 (calls $x) (, (naf alarm) (person $x)))

;; Conditional query — P(burglary | calls(john) ∧ calls(mary))
!(?prob-given burglary ((calls john) (calls mary)))  ;; => 0.98074
```



## Future Work

### PCLP

- **Continuous distributions**: Built-in syntax for common continuous
  distributions (e.g., Normal, Uniform, Exponential) with automatic interval
  discretization.
- **Selection heuristics**: Additional heuristics for choosing which random
  variables and constraints to expand next during GWMC search.
- **Inference performance**: Independent subproblem decomposition and more
  selective caching to scale exact bound computation to larger programs.


### ProbLog-style programs

- **Tabling**: Support for recursive queries on cyclic graphs via tabled
  evaluation.
- **Variable reordering**: Dynamic BDD variable ordering to reduce diagram size.
- **Approximate inference**: Sampling-based methods (MCMC, likelihood
  weighting) when exact BDD inference becomes intractable.


## References

- Michels, S., Hommersom, A., Lucas, P. J. F., & Velikova, M. (2015). A New Probabilistic Constraint Logic Programming Language based on a Generalised Distribution Semantics. *Artificial Intelligence*, 228, 1–44.
- De Raedt, L., Kimmig, A., & Toivonen, H. (2007). ProbLog: A Probabilistic Prolog and its Application in Link Discovery.
- Riguzzi, F., Swift T. (2011). The PITA system: Tabling and answer subsumption for reasoning under uncertainty.
- Riguzzi, F. (2018). Foundations of Probabilistic Logic Programming.
- Bryant, R.E. (1986). Graph-Based Algorithms for Boolean Function Manipulation.

*AI Usage Disclaimer*

*Parts of this codebase have been written with the help of AI Coding tools, particularly the tests have been mainly generated with Claude Code. However, I've manually verified every piece of code before committing. Please open an issue if you find any bugs.*
