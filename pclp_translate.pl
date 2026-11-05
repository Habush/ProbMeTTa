pclp_translate(Prog, AST) :-
    collect_domains(Prog, Domains),
    collect_rv_defs(Prog, Domains, Env),
    validate_domain_definitions(Domains, Env),
    validate_program_types(Prog, Env),
    translate_prog(Prog, Env, AST).


collect_domains([program|Stmts], Domains) :-
    collect_domains(Stmts, [], RevDomains),
    reverse(RevDomains, Domains).

collect_domains([], Domains, Domains).
collect_domains([raw_rv_domain(Lbl, RawDomain)|Rest], Domains0, Domains) :-
    !,
    (   memberchk(rv_domain(Lbl, _), Domains0)
    ->  throw(error(duplicate_random_variable_domain(Lbl), _))
    ;   normalize_domain(Lbl, RawDomain, Domain),
        collect_domains(Rest, [rv_domain(Lbl, Domain)|Domains0], Domains)
    ).
collect_domains([_|Rest], Domains0, Domains) :-
    collect_domains(Rest, Domains0, Domains).

normalize_domain(_, real, real).
normalize_domain(_, pos, pos).
normalize_domain(_, neg, neg).
normalize_domain(Lbl, discrete(RawValues), discrete(Values)) :-
    maplist(normalize_domain_value, RawValues, Values),
    (   Values == []
    ->  throw(error(empty_discrete_domain(Lbl), _))
    ;   sort(Values, Unique),
        length(Values, Count),
        length(Unique, UniqueCount),
        (   Count =:= UniqueCount
        ->  true
        ;   throw(error(duplicate_domain_value(Lbl), _))
        )
    ).

normalize_domain_value('True', true) :- !.
normalize_domain_value('False', false) :- !.
normalize_domain_value(Value, Value).


collect_rv_defs([program|Stmts], Domains, rv_env(Defs, LblIdx, Domains)) :-
    collect_defs(Stmts, Domains, 0, [], RevDefs, [], RevLblIdx),
    reverse(RevDefs, Defs),
    reverse(RevLblIdx, LblIdx).

collect_defs([], _, _, Defs, Defs, LblIdx, LblIdx).
collect_defs(
    [raw_rv_definition(Lbls, Params, Dist)|Rest],
    Domains, DefId, Defs0, Defs, LblIdx0, LblIdx
) :-
    !,
    require_label_domains(Lbls, Domains),
    validate_def_head(Lbls, Params, LblIdx0, LblIdx1),
    validate_param_scope(Lbls, Params, Dist),
    validate_dist(Lbls, Dist),
    NxtDefId is DefId + 1,
    collect_defs(
        Rest, Domains,
        NxtDefId,
        [rv_def(DefId, Lbls, Params, Dist)|Defs0],
        Defs,
        LblIdx1,
        LblIdx
    ).
collect_defs([_|Rest], Domains, DefId, Defs0, Defs, LblIdx0, LblIdx) :-
    collect_defs(Rest, Domains, DefId, Defs0, Defs, LblIdx0, LblIdx).

require_label_domains([], _).
require_label_domains([Lbl|Rest], Domains) :-
    (   memberchk(rv_domain(Lbl, _), Domains)
    ->  require_label_domains(Rest, Domains)
    ;   throw(error(missing_random_variable_domain(Lbl), _))
    ).

validate_domain_definitions([], _).
validate_domain_definitions([rv_domain(Lbl, _)|Rest], Env) :-
    (   rv_lbl_arity(Env, Lbl, _)
    ->  validate_domain_definitions(Rest, Env)
    ;   throw(error(domain_without_random_variable_definition(Lbl), _))
    ).

validate_def_head(Lbls, Params, LblIdx0, LblIdx) :-
    validate_distinct_lbls(Lbls),
    length(Params, Arity),
    validate_lbl_group(Lbls, Lbls, Arity, LblIdx0, LblIdx).

validate_distinct_lbls([]) :-
    throw(error(empty_random_variable_label_group, _)).
validate_distinct_lbls(Lbls) :-
    sort(Lbls, UniqLbls),
    length(Lbls, LblCount),
    length(UniqLbls, UniqCount),
    (   LblCount =:= UniqCount
    ->  true
    ;   throw(error(duplicate_random_variable_labels(Lbls), _))
    ).

validate_lbl_group([], _, _, LblIdx, LblIdx).
validate_lbl_group([Lbl|Rest], Group, Arity, LblIdx0, LblIdx) :-
    (   memberchk(rv_label(Lbl, PrevGroup, PrevArity), LblIdx0)
    ->  require_same_lbl_group(Lbl, PrevGroup, Group),
        require_same_arity(Lbl, PrevArity, Arity),
        LblIdx1 = LblIdx0
    ;   LblIdx1 = [rv_label(Lbl, Group, Arity)|LblIdx0]
    ),
    validate_lbl_group(Rest, Group, Arity, LblIdx1, LblIdx).

require_same_lbl_group(Lbl, PrevGroup, Group) :-
    (   PrevGroup == Group
    ->  true
    ;   throw(error(inconsistent_random_variable_group(
                    Lbl, PrevGroup, Group), _))
    ).

require_same_arity(Lbl, PrevArity, Arity) :-
    (   PrevArity =:= Arity
    ->  true
    ;   throw(error(inconsistent_random_variable_arity(
                    Lbl, PrevArity, Arity), _))
    ).

validate_param_scope(Lbls, Params, Dist) :-
    raw_vars(Params, ParamVars0),
    sort(ParamVars0, ParamVars),
    raw_vars(Dist, UsedVars0),
    sort(UsedVars0, UsedVars),
    require_scoped_vars(UsedVars, ParamVars, Lbls).

raw_vars(raw_var(Name), [Name]) :-
    !.
raw_vars(Term, Vars) :-
    compound(Term),
    !,
    Term =.. [_|Args],
    raw_vars_list(Args, Vars).
raw_vars(_, []).

raw_vars_list([], []).
raw_vars_list([Term|Rest], Vars) :-
    raw_vars(Term, TermVars),
    raw_vars_list(Rest, RestVars),
    append(TermVars, RestVars, Vars).

make_vars(Raw, Vars) :-
    raw_vars(Raw, Names0),
    sort(Names0, Names),
    init_vars(Names, Vars).

init_vars([], []).
init_vars([Name|Rest], [Name-_|Vars]) :-
    init_vars(Rest, Vars).

lookup_var(Name, Vars, Var) :-
    memberchk(Name-Var, Vars).

require_scoped_vars([], _, _).
require_scoped_vars([Var|Rest], Scope, Lbls) :-
    (   memberchk(Var, Scope)
    ->  require_scoped_vars(Rest, Scope, Lbls)
    ;   throw(error(undeclared_definition_variable(Lbls, Var), _))
    ).

validate_dist(Lbls, bernoulli(Prob)) :-
    validate_prob(Lbls, Prob).
validate_dist(Lbls, categorical(Entries)) :-
    category_probs(Entries, Probs),
    validate_prob_sum_(Probs, Lbls, 0, _).
validate_dist(Lbls, regions(Regs)) :-
    validate_regs(Lbls, Regs, Probs),
    validate_prob_sum(Lbls, Probs).
validate_dist(Lbls, constraints(RawChoices)) :-
    choice_probs(RawChoices, Probs),
    validate_prob_sum(Lbls, Probs).

validate_regs(_, [], []).
validate_regs(Lbls, [raw_region(Prob, Intvl)|Rest], [Prob|Probs]) :-
    validate_prob(Lbls, Prob),
    validate_intvl(Lbls, Intvl),
    validate_regs(Lbls, Rest, Probs).


category_probs([], []).
category_probs([raw_category(Prob, _)|Rest], [Prob|Probs]) :-
    category_probs(Rest, Probs).

category_values([], []).
category_values(
    [raw_category(_, Value)|Rest],
    [Value|Values]
) :-
    category_values(Rest, Values).

choice_probs([], []).
choice_probs([raw_alternative(Prob, _)|Rest], [Prob|Probs]) :-
    choice_probs(Rest, Probs).

validate_prob(Ctx, Prob) :-
    (   number(Prob),
        Prob >= 0,
        Prob =< 1
    ->  true
    ;   throw(error(invalid_probability(Ctx, Prob), _))
    ).

validate_prob_sum(Ctx, Probs) :-
    validate_prob_sum_(Probs, Ctx, 0, Sum),
    (   prob_equal(Sum, 1)
    ->  true
    ;   throw(error(probabilities_do_not_sum_to_one(Ctx, Sum), _))
    ).

validate_prob_sum_([], _, Sum, Sum).
validate_prob_sum_([Prob|Rest], Ctx, Acc, Sum) :-
    validate_prob(Ctx, Prob),
    Nxt is Acc + Prob,
    (   Nxt =< 1 + 1.0e-12
    ->  validate_prob_sum_(Rest, Ctx, Nxt, Sum)
    ;   throw(error(probability_sum_exceeds_one(Ctx, Nxt), _))
    ).

prob_equal(Lhs, Rhs) :-
    abs(Lhs - Rhs) =< 1.0e-12.

validate_intvl(Ctx, Intvl) :-
    (   valid_intvl(Intvl)
    ->  true
    ;   throw(error(invalid_interval(Ctx, Intvl), _))
    ).

valid_intvl(raw_interval(LType, Lo, Hi, RType)) :-
    Lo \== pos_inf,
    Hi \== neg_inf,
    valid_inf_delim(Lo, LType),
    valid_inf_delim(Hi, RType),
    ordered_bounds(Lo, Hi).

valid_inf_delim(neg_inf, open) :-
    !.
valid_inf_delim(pos_inf, open) :-
    !.
valid_inf_delim(Bound, _) :-
    number(Bound).

ordered_bounds(neg_inf, Hi) :-
    (number(Hi); Hi == pos_inf).
ordered_bounds(Lo, pos_inf) :-
    number(Lo).
ordered_bounds(Lo, Hi) :-
    number(Lo),
    number(Hi),
    Lo < Hi.


validate_program_types([program|Stmts], Env) :-
    validate_statement_types(Stmts, Env).

validate_statement_types([], _).
validate_statement_types([raw_rv_domain(_, _)|Rest], Env) :-
    !,
    validate_statement_types(Rest, Env).
validate_statement_types(
    [raw_rv_definition(Lbls, _, Dist)|Rest], Env
) :-
    !,
    validate_distribution_type(Lbls, Dist, Env),
    validate_statement_types(Rest, Env).
validate_statement_types([raw_rule(_, Goals)|Rest], Env) :-
    !,
    validate_goal_types(Goals, Env),
    validate_statement_types(Rest, Env).
validate_statement_types([raw_query(_)|Rest], Env) :-
    !,
    validate_statement_types(Rest, Env).

validate_distribution_type([Lbl], bernoulli(_), Env) :-
    !,
    rv_lbl_domain(Env, Lbl, Domain),
    (   boolean_domain(Domain)
    ->  true
    ;   throw(error(invalid_bernoulli_domain(Lbl, Domain), _))
    ).
validate_distribution_type(Lbls, bernoulli(_), _) :-
    throw(error(bernoulli_requires_single_label(Lbls), _)).

validate_distribution_type([Lbl], categorical(Entries), Env) :-
    !,
    rv_lbl_domain(Env, Lbl, Domain),
    ( Domain = discrete(Values)
        -> validate_category_entries(Lbl, Entries, Values)
        ; throw(error(discrete_domain_required(Lbl, Domain), _))
    ).
validate_distribution_type(Lbls, categorical(_), _) :-
    throw(error(categorical_requires_single_label(Lbls), _)).

validate_distribution_type([Lbl], regions(_), Env) :-
    !,
    require_continuous_domain(Lbl, Env).
validate_distribution_type(Lbls, regions(_), _) :-
    throw(error(interval_distribution_requires_single_label(Lbls), _)).
validate_distribution_type(Lbls, constraints(Choices), Env) :-
    validate_choice_types(Choices, Env, definition_scope(Lbls)).

validate_category_entries(Lbl, Entries, DomainValues) :-
    category_values(Entries, RawValues),
    maplist(normalize_domain_value, RawValues, Values),
    validate_category_values(Lbl, Values, DomainValues),
    sort(Values, UniqueValues),
    length(Values, ValueCount),
    length(UniqueValues, UniqueCount),
    (   ValueCount =:= UniqueCount
    ->  true
    ;   throw(error(duplicate_categorical_value(Lbl), _))
    ).

boolean_domain(discrete(Values)) :-
    sort(Values, [false, true]).

require_continuous_domain(Lbl, Env) :-
    rv_lbl_domain(Env, Lbl, Domain),
    (   continuous_domain(Domain)
    ->  true
    ;   throw(error(continuous_domain_required(Lbl, Domain), _))
    ).

continuous_domain(real).
continuous_domain(pos).
continuous_domain(neg).


validate_category_values(_, [], _).
validate_category_values(Lbl, [Value|Rest], DomainValues) :-
    (memberchk(Value, DomainValues)
    -> validate_category_values(Lbl, Rest, DomainValues)
    ; throw(error(value_outside_domain(Lbl, Value), _))
    ).

validate_choice_types([], _, _).
validate_choice_types([raw_alternative(_, Cstr)|Rest], Env, Scope) :-
    validate_constraint_type(Cstr, Env, Scope),
    validate_choice_types(Rest, Env, Scope).

validate_goal_types([], _).
validate_goal_types([raw_goal_constraint(Cstr)|Rest], Env) :-
    !,
    validate_constraint_type(Cstr, Env, rule_scope),
    validate_goal_types(Rest, Env).
validate_goal_types([raw_goal_atom(raw_atom(Name, Args))|Rest], Env) :-
    (   rv_lbl_arity(Env, Name, Arity)
    ->  length(Args, Arity),
        require_ref_arity(Name, Arity, Arity),
        rv_lbl_domain(Env, Name, Domain),
        (   boolean_domain(Domain)
        ->  true
        ;   throw(error(non_boolean_random_variable_goal(Name, Domain), _))
        )
    ;   true
    ),
    validate_goal_types(Rest, Env).

validate_constraint_type(raw_constraint_and(Cstrs), Env, Scope) :-
    !,
    validate_constraint_types(Cstrs, Env, Scope).
validate_constraint_type(raw_relation(Op, Lhs, Rhs), Env, Scope) :-
    relation_operand_types(Lhs, Rhs, Env, Scope, LhsType, RhsType),
    validate_relation_type(Op, LhsType, RhsType).

relation_operand_types(
    Lhs, raw_var(_), Env, rule_scope,
    discrete(Lbl, Values), categorical_var
) :-
    expression_type(Lhs, Env, rule_scope, discrete(Lbl, Values)),
    !.
relation_operand_types(
    raw_var(_), Rhs, Env, rule_scope,
    categorical_var, discrete(Lbl, Values)
) :-
    expression_type(Rhs, Env, rule_scope, discrete(Lbl, Values)),
    !.
relation_operand_types(Lhs, Rhs, Env, Scope, LhsType, RhsType) :-
    expression_type(Lhs, Env, Scope, LhsType),
    expression_type(Rhs, Env, Scope, RhsType).

validate_constraint_types([], _, _).
validate_constraint_types([Cstr|Rest], Env, Scope) :-
    validate_constraint_type(Cstr, Env, Scope),
    validate_constraint_types(Rest, Env, Scope).

validate_relation_type(Op, discrete(Lbl, Values), literal(Value)) :-
    !,
    validate_discrete_relation(Op, Lbl, Values, Value).
validate_relation_type(Op, literal(Value), discrete(Lbl, Values)) :-
    !,
    validate_discrete_relation(Op, Lbl, Values, Value).
validate_relation_type(Op, discrete(Lbl, _), categorical_var) :-
    !,
    validate_categorical_variable_relation(Op, Lbl).
validate_relation_type(Op, categorical_var, discrete(Lbl, _)) :-
    !,
    validate_categorical_variable_relation(Op, Lbl).
validate_relation_type(Op, discrete(Lhs, _), discrete(Rhs, _)) :-
    !,
    throw(error(categorical_variable_comparison_not_supported(Op, Lhs, Rhs), _)).
validate_relation_type(Op, continuous, continuous) :-
    !,
    (   memberchk(Op, [lt, le, gt, ge])
    ->  true
    ;   throw(error(invalid_continuous_relation(Op), _))
    ).
validate_relation_type(Op, LhsType, RhsType) :-
    throw(error(incompatible_constraint_operands(Op, LhsType, RhsType), _)).

validate_discrete_relation(Op, Lbl, Values, Value) :-
    (   memberchk(Op, [eq, ne])
    ->  true
    ;   throw(error(invalid_discrete_relation(Lbl, Op), _))
    ),
    (   memberchk(Value, Values)
    ->  true
    ;   throw(error(value_outside_domain(Lbl, Value), _))
    ).

validate_categorical_variable_relation(Op, Lbl) :-
    (   memberchk(Op, [eq, ne])
    ->  true
    ;   throw(error(invalid_discrete_relation(Lbl, Op), _))
    ).

expression_type(raw_number(_), _, _, continuous) :- !.
expression_type(raw_var(_), _, _, continuous) :- !.
expression_type(raw_const(Name), Env, Scope, Type) :-
    !,
    (   scope_rv_label(Scope, Name)
    ->  rv_expression_type(Name, Env, Type)
    ;   rv_lbl_arity(Env, Name, Arity)
    ->  require_ref_arity(Name, Arity, 0),
        rv_expression_type(Name, Env, Type)
    ;   normalize_domain_value(Name, Value),
        Type = literal(Value)
    ).
expression_type(raw_apply(Name, Args), Env, _, Type) :-
    !,
    (   rv_lbl_arity(Env, Name, Arity)
    ->  length(Args, GotArity),
        require_ref_arity(Name, Arity, GotArity),
        rv_expression_type(Name, Env, Type)
    ;   throw(error(unsupported_constraint_function(Name), _))
    ).
expression_type(e_add(Lhs, Rhs), Env, Scope, continuous) :-
    !,
    require_continuous_expression(Lhs, Env, Scope),
    require_continuous_expression(Rhs, Env, Scope).
expression_type(e_sub(Lhs, Rhs), Env, Scope, continuous) :-
    !,
    require_continuous_expression(Lhs, Env, Scope),
    require_continuous_expression(Rhs, Env, Scope).
expression_type(e_mul(Lhs, Rhs), Env, Scope, continuous) :-
    !,
    (   Lhs = raw_number(_)
    ->  require_continuous_expression(Rhs, Env, Scope)
    ;   Rhs = raw_number(_)
    ->  require_continuous_expression(Lhs, Env, Scope)
    ;   throw(error(nonlinear_multiplication(Lhs, Rhs), _))
    ).
expression_type(e_div(Lhs, raw_number(Divisor)), Env, Scope, continuous) :-
    !,
    (   Divisor =:= 0
    ->  throw(error(division_by_zero, _))
    ;   require_continuous_expression(Lhs, Env, Scope)
    ).
expression_type(e_div(_, Rhs), _, _, _) :-
    !,
    throw(error(nonliteral_divisor(Rhs), _)).
expression_type(Expr, _, _, _) :-
    throw(error(unsupported_expression(Expr), _)).

require_continuous_expression(Expr, Env, Scope) :-
    expression_type(Expr, Env, Scope, Type),
    (   Type == continuous
    ->  true
    ;   throw(error(continuous_expression_required(Expr, Type), _))
    ).

scope_rv_label(definition_scope(Lbls), Name) :-
    memberchk(Name, Lbls).

rv_expression_type(Name, Env, Type) :-
    rv_lbl_domain(Env, Name, Domain),
    (   continuous_domain(Domain)
    ->  Type = continuous
    ;   Domain = discrete(Values),
        Type = discrete(Name, Values)
    ).


translate_prog([program|Stmts], Env, [program|Out]) :-
    translate_stmts(Stmts, Env, 0, 0, 0, Out).

translate_stmts([], _, _, _, _, []).
translate_stmts(
    [raw_rv_domain(_, _)|Rest],
    Env, DefId, RuleId, QryId, Out
) :-
    !,
    translate_stmts(Rest, Env, DefId, RuleId, QryId, Out).
translate_stmts(
    [raw_rv_definition(Lbls, Params, Dist)|Rest],
    Env, DefId, RuleId, QryId, [Def|Out]
) :-
    !,
    make_vars([Params, Dist], Vars),
    translate_def(DefId, Lbls, Params, Dist, Env, Vars, Def),
    NxtDefId is DefId + 1,
    translate_stmts(Rest, Env, NxtDefId, RuleId, QryId, Out).
translate_stmts(
    [raw_rule(RawHead, RawGoals)|Rest],
    Env, DefId, RuleId, QryId, [Rule|Out]
) :-
    !,
    make_vars([RawHead, RawGoals], Vars),
    translate_rule(RuleId, RawHead, RawGoals, Env, Vars, Rule),
    NxtRuleId is RuleId + 1,
    translate_stmts(Rest, Env, DefId, NxtRuleId, QryId, Out).
translate_stmts(
    [raw_query(RawAtom)|Rest],
    Env, DefId, RuleId, QryId, [Qry|Out]
) :-
    !,
    make_vars(RawAtom, Vars),
    translate_query(QryId, RawAtom, Vars, Qry),
    NxtQryId is QryId + 1,
    translate_stmts(Rest, Env, DefId, RuleId, NxtQryId, Out).
translate_stmts([Stmt|_], _, _, _, _, _) :-
    throw(error(unsupported_statement(Stmt), _)).

translate_rule(RuleId, RawHead, RawGoals, Env, Vars,
               [rule, RuleId, Head, Goals]) :-
    translate_atom(RawHead, Vars, Head),
    translate_goals(RawGoals, Env, Vars, Goals).

translate_query(QryId, RawAtom, Vars, [query, QryId, Atom]) :-
    translate_atom(RawAtom, Vars, Atom).

translate_atom(raw_atom(Name, RawArgs), Vars, [Name|Args]) :-
    translate_terms(RawArgs, Vars, Args).

translate_goals([], _, _, []).
translate_goals([RawGoal|Rest], Env, Vars, [Goal|Goals]) :-
    translate_goal(RawGoal, Env, Vars, Goal),
    translate_goals(Rest, Env, Vars, Goals).

translate_goal(raw_goal_constraint(RawCstr), Env, Vars, Cstr) :-
    !,
    translate_cstr(RawCstr, Env, scope_context(Vars), Cstr).
translate_goal(raw_goal_atom(raw_atom(Name, RawArgs)), Env, Vars, Goal) :-
    (   rv_lbl_arity(Env, Name, Arity)
    ->  length(RawArgs, GotArity),
        require_ref_arity(Name, Arity, GotArity),
        translate_terms(RawArgs, Vars, Args),
        Goal = [c_eq, [e_rv, Name, Args], [e_lit, true]]
    ;   translate_atom(raw_atom(Name, RawArgs), Vars, Goal)
    ).

translate_def(DefId, Lbls, RawParams, Dist, Env, Vars,
              [rv_definition, DefId,
               [rv_labels, Lbls],
               [parameters, Params],
               [domains, Domains],
               [choices, Choices]]) :-
    translate_terms(RawParams, Vars, Params),
    definition_domains(Lbls, Env, Domains),
    Ctx = definition_context(Vars, Lbls, Params),
    translate_dist(Dist, Env, Ctx, Choices).

definition_domains([], _, []).
definition_domains([Lbl|Rest], Env, [[Lbl, CanonDomain]|Domains]) :-
    rv_lbl_domain(Env, Lbl, Domain),
    canonical_domain(Domain, CanonDomain),
    definition_domains(Rest, Env, Domains).

canonical_domain(discrete(Values), [discrete, Values]).
canonical_domain(real, real).
canonical_domain(pos, pos).
canonical_domain(neg, neg).

translate_dist(bernoulli(Prob), _, definition_context(_, [Name], Params),
                             [[choice, 0, Prob,
                 [c_eq, [e_rv, Name, Params], [e_lit, true]]],
                                [choice, 1, Comp,
                 [c_eq, [e_rv, Name, Params], [e_lit, false]]]]) :-
    Comp is 1 - Prob.

translate_dist(categorical(Entries), Env, definition_context(_, [Name], Params), 
    Choices) :-
    rv_lbl_domain(Env, Name, discrete(DomainValues)),
    translate_categories(Entries, Name, Params, 0, ExplicitChoices),
    category_probs(Entries, Probs),
    validate_prob_sum_(Probs, [Name], 0, Sum),
    add_category_residual(
        Sum,
        DomainValues,
        Name,
        Params,
        ExplicitChoices,
        Choices
    ).
translate_dist(regions(Regs), _, definition_context(_, [Name], Params),
               Choices) :-
    translate_regs(Regs, Name, Params, Choices).
translate_dist(constraints(RawChoices), Env, Ctx, Choices) :-
    translate_choices(RawChoices, Env, Ctx, Choices).

translate_categories([], _, _, _, []).
translate_categories(
    [raw_category(Prob, RawValue)|Rest],
    Name,
    Params,
    ChoiceId,
    [[choice, ChoiceId, Prob,
      [c_eq,
       [e_rv, Name, Params],
       [e_lit, Value]]]|Choices]) :-
    normalize_domain_value(RawValue, Value),
    NxtChoiceId is ChoiceId + 1,
    translate_categories(
        Rest,
        Name,
        Params,
        NxtChoiceId,
        Choices
    ).

translate_regs(Regs, Name, Params, Choices) :-
    translate_regs(Regs, Name, Params, 0, Choices).

translate_regs([], _, _, _, []).
translate_regs(
    [raw_region(Prob, raw_interval(LType, Lo, Hi, RType))|Rest],
    Name, Params, ChoiceId,
    [[choice, ChoiceId, Prob,
      [c_interval, LType, [e_lit, Lo],
       [e_rv, Name, Params], [e_lit, Hi], RType]]|Choices]
) :-
    NextChoiceId is ChoiceId + 1,
    translate_regs(Rest, Name, Params, NextChoiceId, Choices).

translate_choices(RawChoices, Env, Ctx, Choices) :-
    translate_choices(RawChoices, Env, Ctx, 0, Choices).

translate_choices([], _, _, _, []).
translate_choices([raw_alternative(Prob, RawCstr)|Rest], Env, Ctx, ChoiceId,
                  [[choice, ChoiceId, Prob, Cstr]|Choices]) :-
    translate_cstr(RawCstr, Env, Ctx, Cstr),
    NextChoiceId is ChoiceId + 1,
    translate_choices(Rest, Env, Ctx, NextChoiceId, Choices).

translate_cstr(raw_constraint_and(RawCstrs), Env, Ctx, [c_and, Cstrs]) :-
    !,
    translate_cstrs(RawCstrs, Env, Ctx, Cstrs).
translate_cstr(
    raw_relation(Op, RawLhs, raw_var(Name)),
    Env,
    scope_context(Vars),
    [CanonOp, Lhs, [e_lit, Var]]
) :-
    expression_type(RawLhs, Env, rule_scope, discrete(_, _)),
    !,
    cstr_op(Op, CanonOp),
    translate_expr(RawLhs, Env, scope_context(Vars), Lhs),
    lookup_var(Name, Vars, Var).
translate_cstr(
    raw_relation(Op, raw_var(Name), RawRhs),
    Env,
    scope_context(Vars),
    [CanonOp, [e_lit, Var], Rhs]
) :-
    expression_type(RawRhs, Env, rule_scope, discrete(_, _)),
    !,
    cstr_op(Op, CanonOp),
    lookup_var(Name, Vars, Var),
    translate_expr(RawRhs, Env, scope_context(Vars), Rhs).
translate_cstr(raw_relation(Op, RawLhs, RawRhs), Env, Ctx,
               [CanonOp, Lhs, Rhs]) :-
    cstr_op(Op, CanonOp),
    translate_expr(RawLhs, Env, Ctx, Lhs),
    translate_expr(RawRhs, Env, Ctx, Rhs).

translate_cstrs([], _, _, []).
translate_cstrs([RawCstr|Rest], Env, Ctx, [Cstr|Cstrs]) :-
    translate_cstr(RawCstr, Env, Ctx, Cstr),
    translate_cstrs(Rest, Env, Ctx, Cstrs).

add_category_residual(
    Sum, _, _, _, Choices, Choices
) :-
    prob_equal(Sum, 1),
    !.

add_category_residual(Sum, DomainValues, Name, Params, ExplicitChoices, Choices) :-
    Residual is 1 - Sum,
    length(ExplicitChoices, ChoiceId),
    ResidualChoice = [choice, ChoiceId, Residual,
         [c_in,
          [e_rv, Name, Params],
          DomainValues]],
    append(ExplicitChoices, [ResidualChoice], Choices).

cstr_op(eq, c_eq).
cstr_op(ne, c_ne).
cstr_op(lt, c_lt).
cstr_op(le, c_le).
cstr_op(gt, c_gt).
cstr_op(ge, c_ge).

translate_expr(raw_number(Num), _, _, [e_lit, Num]) :-
    !.
translate_expr(raw_var(Name), _, Ctx, Var) :-
    !,
    ctx_vars(Ctx, Vars),
    lookup_var(Name, Vars, Var).
translate_expr(raw_const(Name), Env, Ctx, Expr) :-
    !,
    translate_const_expr(Name, Env, Ctx, Expr).
translate_expr(raw_apply(Name, RawArgs), Env, Ctx, Expr) :-
    !,
    translate_apply_expr(Name, RawArgs, Env, Ctx, Expr).
translate_expr(RawExpr, Env, Ctx, [Op, Lhs, Rhs]) :-
    RawExpr =.. [Op, RawLhs, RawRhs],
    memberchk(Op, [e_add, e_sub, e_mul, e_div]),
    !,
    translate_expr(RawLhs, Env, Ctx, Lhs),
    translate_expr(RawRhs, Env, Ctx, Rhs).
translate_expr(RawExpr, _, _, _) :-
    throw(error(unsupported_expression(RawExpr), _)).

translate_const_expr(
    Name, _, definition_context(_, Lbls, Params),
    [e_rv, Name, Params]
) :-
    memberchk(Name, Lbls),
    !.
translate_const_expr(Name, Env, _, [e_rv, Name, []]) :-
    rv_lbl_arity(Env, Name, 0),
    !.
translate_const_expr(Name, Env, _, _) :-
    rv_lbl_arity(Env, Name, Arity),
    !,
    throw(error(random_variable_requires_arguments(Name, Arity), _)).
translate_const_expr(Name, _, _, [e_lit, Value]) :-
    normalize_domain_value(Name, Value).

translate_apply_expr(Name, RawArgs, Env, Ctx, Expr) :-
    ctx_vars(Ctx, Vars),
    (   rv_lbl_arity(Env, Name, Arity)
    ->  length(RawArgs, GotArity),
        require_ref_arity(Name, Arity, GotArity),
        translate_terms(RawArgs, Vars, Args),
        Expr = [e_rv, Name, Args]
    ;   translate_terms(RawArgs, Vars, Args),
        Expr = [t_fun, Name, Args]
    ).

ctx_vars(definition_context(Vars, _, _), Vars).
ctx_vars(scope_context(Vars), Vars).

rv_lbl_arity(rv_env(_, LblIdx, _), Name, Arity) :-
    memberchk(rv_label(Name, _, Arity), LblIdx).

rv_lbl_domain(rv_env(_, _, Domains), Name, Domain) :-
    memberchk(rv_domain(Name, Domain), Domains).

require_ref_arity(Name, Arity, GotArity) :-
    (   Arity =:= GotArity
    ->  true
    ;   throw(error(random_variable_arity_mismatch(
                    Name, Arity, GotArity), _))
    ).

translate_terms([], _, []).
translate_terms([RawTerm|Rest], Vars, [Term|Terms]) :-
    translate_term(RawTerm, Vars, Term),
    translate_terms(Rest, Vars, Terms).

translate_term(raw_var(Name), Vars, Var) :-
    !,
    lookup_var(Name, Vars, Var).
translate_term(raw_const(Name), _, Name) :-
    !.
translate_term(raw_number(Num), _, Num) :-
    !.
translate_term(raw_apply(Name, RawArgs), Vars, [Name|Args]) :-
    !,
    translate_terms(RawArgs, Vars, Args).
translate_term(RawTerm, _, _) :-
    throw(error(invalid_first_order_term(RawTerm), _)).