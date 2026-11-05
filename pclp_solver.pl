:- use_module(library(clpfd)).
:- use_module(library(clpr)).


% GWMC establishes that ChoiceConstrs /\ Premises is satisfiable once per ctx.
% C is false if the ctx with C is unsatisfiable, and true if the ctx with
% not(C) is unsatisfiable. If both are satisfiable, C is unknown.
pclp_classify(Constr, ChoiceConstrs, Premises, Doms, Result) :-
    (   \+ ctx_constr_sat(
            Constr, ChoiceConstrs, Premises, Doms)
    ->  Result = false
    ;   \+ ctx_neg_constr_sat(
            Constr, ChoiceConstrs, Premises, Doms)
    ->  Result = true
    ;   Result = unk
    ),
    !.

pclp_classify_formula(
    Formula, ChoiceConstrs, Premises, Doms, Result
) :-
    (   \+ ctx_formula_sat(
            Formula, ChoiceConstrs, Premises, Doms)
    ->  Result = false
    ;   \+ ctx_neg_formula_sat(
            Formula, ChoiceConstrs, Premises, Doms)
    ->  Result = true
    ;   Result = unk
    ),
    !.

pclp_consistent(ChoiceConstrs, Premises, Doms, Result) :-
    (   ctx_sat(ChoiceConstrs, Premises, Doms)
    ->  Result = true
    ;   Result = false
    ).

% Compatibility interfaces for callers without formula premises.
pclp_classify(Constr, ChoiceConstrs, Doms, Result) :-
    pclp_classify(Constr, ChoiceConstrs, [], Doms, Result).

pclp_classify_formula(Formula, ChoiceConstrs, Doms, Result) :-
    pclp_classify_formula(
        Formula, ChoiceConstrs, [], Doms, Result).

pclp_consistent(ChoiceConstrs, Doms, Result) :-
    pclp_consistent(ChoiceConstrs, [], Doms, Result).

ctx_sat(ChoiceConstrs, Premises, Doms) :-
    copy_term(
        solver_input(ChoiceConstrs, Premises, Doms),
        solver_input(ChoiceConstrs1, Premises1, Doms1)
    ),
    make_env(Doms1, Env, _),
    post_ctx(Env, ChoiceConstrs1, Premises1).

ctx_constr_sat(Constr, ChoiceConstrs, Premises, Doms) :-
    copy_term(
        solver_input(Constr, ChoiceConstrs, Premises, Doms),
        solver_input(Constr1, ChoiceConstrs1, Premises1, Doms1)
    ),
    make_env(Doms1, Env, _),
    post_ctx(Env, ChoiceConstrs1, Premises1),
    post_constr(Env, Constr1).

ctx_neg_constr_sat(Constr, ChoiceConstrs, Premises, Doms) :-
    copy_term(
        solver_input(Constr, ChoiceConstrs, Premises, Doms),
        solver_input(Constr1, ChoiceConstrs1, Premises1, Doms1)
    ),
    make_env(Doms1, Env, _),
    post_ctx(Env, ChoiceConstrs1, Premises1),
    neg_branch(Constr1, NegConstrs),
    maplist(post_constr(Env), NegConstrs).

ctx_formula_sat(Formula, ChoiceConstrs, Premises, Doms) :-
    copy_term(
        solver_input(Formula, ChoiceConstrs, Premises, Doms),
        solver_input(Formula1, ChoiceConstrs1, Premises1, Doms1)
    ),
    make_env(Doms1, Env, _),
    post_ctx(Env, ChoiceConstrs1, Premises1),
    post_formula(Env, Formula1).

ctx_neg_formula_sat(Formula, ChoiceConstrs, Premises, Doms) :-
    copy_term(
        solver_input(Formula, ChoiceConstrs, Premises, Doms),
        solver_input(Formula1, ChoiceConstrs1, Premises1, Doms1)
    ),
    make_env(Doms1, Env, _),
    post_ctx(Env, ChoiceConstrs1, Premises1),
    post_neg_formula(Env, Formula1).

post_ctx(Env, ChoiceConstrs, Premises) :-
    maplist(post_constr(Env), ChoiceConstrs),
    maplist(post_premise(Env), Premises).

post_premise(Env, [pos, Formula]) :-
    post_formula(Env, Formula).
post_premise(Env, [neg, Formula]) :-
    post_neg_formula(Env, Formula).

sat(ChoiceConstrs, Doms) :-
    ctx_sat(ChoiceConstrs, [], Doms).

post_formula(_, 'True').
post_formula(_, 'False') :-
    fail.
post_formula(Env, [f_and, Constrs]) :-
    maplist(post_constr(Env), Constrs).
post_formula(Env, [f_or, Forms]) :-
    member(Form, Forms),
    post_formula(Env, Form).

post_neg_formula(_, 'True') :-
    fail.
post_neg_formula(_, 'False').
post_neg_formula(Env, [f_and, Constrs]) :-
    member(Constr, Constrs),
    neg_branch(Constr, NegConstrs),
    maplist(post_constr(Env), NegConstrs).
post_neg_formula(Env, [f_or, Forms]) :-
    maplist(post_neg_formula(Env), Forms).


make_env([], [], []).
make_env(
    [[rv_domain, RV, Dom]|Doms],
    [rv_var(RV, Type, Var)|Env],
    FDVars
) :-
    make_var(Dom, Type, Var, HeadVars),
    make_env(Doms, Env, TailVars),
    append(HeadVars, TailVars, FDVars).

make_var([discrete, Values], discrete(Values), Var, [Var]) :-
    Values = [_|_],
    length(Values, Len),
    Max is Len - 1,
    Var in 0..Max.
make_var(real, real, _, []).
make_var(pos, real, Var, []) :-
    {Var > 0}.
make_var(neg, real, Var, []) :-
    {Var < 0}.

lookup_rv(RV, Env, Type, Var) :-
    member(rv_var(Key, Type, Var), Env),
    Key == RV,
    !.


post_constr(Env, [c_and, Constrs]) :-
    !,
    maplist(post_constr(Env), Constrs).

post_constr(Env, [Op, RV, AllowedValues]) :-
    memberchk(Op, [c_in, c_not_in]),
    !,
    lookup_rv(RV, Env, discrete(DomainValues), Var),
    category_indices(AllowedValues, DomainValues, Indices),
    post_categorical(Op, Var, Indices).

post_constr(
    Env, [c_interval, LType, Lo, Expr, Hi, RType]
) :-
    !,
    interval_constrs(LType, Lo, Expr, Hi, RType, Constrs),
    maplist(post_constr(Env), Constrs).
    
post_constr(Env, [Op, Lhs, Rhs]) :-
    (   discrete_args(Lhs, Rhs, Env, Var, Value, Values)
    ->  post_discrete(Op, Var, Value, Values)
    ;   linear_expr(Lhs, Env, Lhs1),
        linear_expr(Rhs, Env, Rhs1),
        post_real(Op, Lhs1, Rhs1)
    ).

discrete_args(
    RV, [e_lit, Value], Env, Var, Value, Values
) :-
    lookup_rv(RV, Env, discrete(Values), Var),
    !.
discrete_args(
    [e_lit, Value], RV, Env, Var, Value, Values
) :-
    lookup_rv(RV, Env, discrete(Values), Var).

post_discrete(c_eq, Var, Value, Values) :-
    nth0(Index, Values, Value),
    Var #= Index.
post_discrete(c_ne, Var, Value, Values) :-
    nth0(Index, Values, Value),
    Var #\= Index.

post_categorical(c_in, Var, Indices) :-
    list_to_fdset(Indices, Set),
    Var in_set Set.

post_categorical(c_not_in, Var, Indices) :-
    maplist(exclude_index(Var), Indices).

exclude_index(Var, Index) :-
    Var #\= Index.

post_real(c_lt, Lhs, Rhs) :- {Lhs < Rhs}.
post_real(c_le, Lhs, Rhs) :- {Lhs =< Rhs}.
post_real(c_gt, Lhs, Rhs) :- {Lhs > Rhs}.
post_real(c_ge, Lhs, Rhs) :- {Lhs >= Rhs}.


linear_expr([e_lit, Num], _, Num) :-
    number(Num),
    !.
linear_expr(RV, Env, Var) :-
    lookup_rv(RV, Env, real, Var),
    !.
linear_expr([e_add, Lhs, Rhs], Env, Lhs1+Rhs1) :-
    !,
    linear_expr(Lhs, Env, Lhs1),
    linear_expr(Rhs, Env, Rhs1).
linear_expr([e_sub, Lhs, Rhs], Env, Lhs1-Rhs1) :-
    !,
    linear_expr(Lhs, Env, Lhs1),
    linear_expr(Rhs, Env, Rhs1).
linear_expr([e_mul, [e_lit, Scalar], Expr], Env, Scalar*Expr1) :-
    number(Scalar),
    !,
    linear_expr(Expr, Env, Expr1).
linear_expr([e_mul, Expr, [e_lit, Scalar]], Env, Expr1*Scalar) :-
    number(Scalar),
    !,
    linear_expr(Expr, Env, Expr1).
linear_expr([e_div, Expr, [e_lit, Divisor]], Env, Expr1/Divisor) :-
    number(Divisor),
    Divisor =\= 0,
    linear_expr(Expr, Env, Expr1).

category_indices(Values, DomainValues, Indices) :-
    maplist(category_index(DomainValues), Values, Indices0),
    sort(Indices0, Indices).

category_index(DomainValues, Value, Index) :-
    nth0(Index, DomainValues, Value).

interval_constrs(LType, Lo, Expr, Hi, RType, Constrs) :-
    lower_constr(LType, Lo, Expr, Lower),
    upper_constr(RType, Expr, Hi, Upper),
    append(Lower, Upper, Constrs).

lower_constr(_, [e_lit, neg_inf], _, []) :- !.
lower_constr(closed, Lo, Expr, [[c_le, Lo, Expr]]).
lower_constr(open, Lo, Expr, [[c_lt, Lo, Expr]]).

upper_constr(_, _, [e_lit, pos_inf], []) :- !.
upper_constr(closed, Expr, Hi, [[c_le, Expr, Hi]]).
upper_constr(open, Expr, Hi, [[c_lt, Expr, Hi]]).


neg_branch([c_and, Constrs], NegConstrs) :-
    member(Constr, Constrs),
    neg_branch(Constr, NegConstrs).
neg_branch([c_interval, LType, Lo, Expr, Hi, RType], NegConstrs) :-
    interval_constrs(LType, Lo, Expr, Hi, RType, Constrs),
    member(Constr, Constrs),
    neg_branch(Constr, NegConstrs).
neg_branch([Op, Lhs, Rhs], [[NegOp, Lhs, Rhs]]) :-
    neg_op(Op, NegOp).

neg_op(c_eq, c_ne).
neg_op(c_ne, c_eq).
neg_op(c_in, c_not_in).
neg_op(c_not_in, c_in).
neg_op(c_lt, c_ge).
neg_op(c_le, c_gt).
neg_op(c_gt, c_le).
neg_op(c_ge, c_lt).