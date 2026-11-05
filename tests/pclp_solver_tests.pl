:- ensure_loaded(pclp_solver).

:- begin_tests(pclp_solver).


coin_doms([
    [rv_domain, [e_rv, coin, []], [discrete, [true, false]]]
]).

color_doms([
    [rv_domain, [e_rv, color, []],
     [discrete, [red, blue, green]]]
]).

temp_doms([
    [rv_domain, [e_rv, temperature, [monday]], real]
]).

unit_interval(
    [c_interval, closed, [e_lit, 0],
     [e_rv, temperature, [monday]], [e_lit, 1], closed]
).


test(unselected_discrete_constraint_is_unknown) :-
    coin_doms(Doms),
    pclp_classify(
        [c_eq, [e_rv, coin, []], [e_lit, true]],
        [], Doms, unk).

test(discrete_equality_is_entailed) :-
    coin_doms(Doms),
    pclp_classify(
        [c_eq, [e_rv, coin, []], [e_lit, true]],
        [[c_eq, [e_rv, coin, []], [e_lit, true]]],
        Doms, true).

test(discrete_equality_is_contradicted) :-
    coin_doms(Doms),
    pclp_classify(
        [c_eq, [e_rv, coin, []], [e_lit, false]],
        [[c_eq, [e_rv, coin, []], [e_lit, true]]],
        Doms, false).

test(discrete_disequality_is_entailed) :-
    coin_doms(Doms),
    pclp_classify(
        [c_ne, [e_rv, coin, []], [e_lit, false]],
        [[c_eq, [e_rv, coin, []], [e_lit, true]]],
        Doms, true).

test(full_domain_residual_is_unknown) :-
    color_doms(Doms),
    pclp_classify(
        [c_eq, [e_rv, color, []], [e_lit, red]],
        [[c_in, [e_rv, color, []], [red, blue, green]]],
        Doms, unk).

test(subset_residual_excludes_value) :-
    color_doms(Doms),
    pclp_classify(
        [c_eq, [e_rv, color, []], [e_lit, green]],
        [[c_in, [e_rv, color, []], [red, blue]]],
        Doms, false).

test(membership_is_entailed) :-
    color_doms(Doms),
    pclp_classify(
        [c_in, [e_rv, color, []], [red, blue]],
        [[c_eq, [e_rv, color, []], [e_lit, red]]],
        Doms, true).

test(exhaustive_categorical_disjunction_is_entailed) :-
    color_doms(Doms),
    Formula = [
        f_or,
        [[f_and, [[c_eq, [e_rv, color, []], [e_lit, red]]]],
         [f_and, [[c_eq, [e_rv, color, []], [e_lit, blue]]]],
         [f_and, [[c_eq, [e_rv, color, []], [e_lit, green]]]]]
    ],
    pclp_classify_formula(Formula, [], Doms, true).

test(non_exhaustive_categorical_disjunction_is_unknown) :-
    color_doms(Doms),
    Formula = [
        f_or,
        [[f_and, [[c_eq, [e_rv, color, []], [e_lit, red]]]],
         [f_and, [[c_eq, [e_rv, color, []], [e_lit, blue]]]]]
    ],
    pclp_classify_formula(Formula, [], Doms, unk).

test(exhaustive_continuous_disjunction_is_entailed) :-
    temp_doms(Doms),
    RV = [e_rv, temperature, [monday]],
    Formula = [
        f_or,
        [[f_and, [[c_le, RV, [e_lit, 0]]]],
         [f_and, [[c_gt, RV, [e_lit, 0]]]]]
    ],
    pclp_classify_formula(Formula, [], Doms, true).

test(closed_lower_bound_is_entailed) :-
    temp_doms(Doms),
    unit_interval(Interval),
    pclp_classify(
        [c_ge, [e_rv, temperature, [monday]], [e_lit, 0]],
        [Interval], Doms, true).

test(open_lower_bound_is_unknown) :-
    temp_doms(Doms),
    unit_interval(Interval),
    pclp_classify(
        [c_gt, [e_rv, temperature, [monday]], [e_lit, 0]],
        [Interval], Doms, unk).

test(strict_interval_endpoint_is_entailed) :-
    temp_doms(Doms),
    pclp_classify(
        [c_gt, [e_rv, temperature, [monday]], [e_lit, 1]],
        [[c_interval, open, [e_lit, 1],
          [e_rv, temperature, [monday]], [e_lit, 2], closed]],
        Doms, true).

test(joint_linear_constraint_is_entailed) :-
    Doms = [
        [rv_domain, [e_rv, temperature, [monday]], real],
        [rv_domain, [e_rv, offset, [monday]], real]
    ],
    Assumps = [
        [c_interval, closed, [e_lit, 0],
         [e_rv, temperature, [monday]], [e_lit, 1], closed],
        [c_interval, closed, [e_lit, 0],
         [e_rv, offset, [monday]], [e_lit, 1], closed]
    ],
    Constr = [
        c_lt,
        [e_add,
         [e_rv, temperature, [monday]],
         [e_mul, [e_lit, 0.25], [e_rv, offset, [monday]]]],
        [e_lit, 1.375]
    ],
    pclp_classify(Constr, Assumps, Doms, true).

test(joint_linear_constraint_is_unknown) :-
    Doms = [
        [rv_domain, [e_rv, temperature, [monday]], real],
        [rv_domain, [e_rv, offset, [monday]], real]
    ],
    Assumps = [
        [c_interval, closed, [e_lit, 0],
         [e_rv, temperature, [monday]], [e_lit, 1], closed],
        [c_interval, closed, [e_lit, 0],
         [e_rv, offset, [monday]], [e_lit, 1], closed]
    ],
    Constr = [
        c_lt,
        [e_add,
         [e_rv, temperature, [monday]],
         [e_rv, offset, [monday]]],
        [e_lit, 1]
    ],
    pclp_classify(Constr, Assumps, Doms, unk).

test(consistent_delta) :-
    temp_doms(Doms),
    unit_interval(Interval),
    pclp_consistent([Interval], Doms, true).

test(empty_delta_is_consistent) :-
    pclp_consistent([], [], true).

test(inconsistent_delta) :-
    temp_doms(Doms),
    unit_interval(Interval),
    pclp_consistent(
        [Interval,
         [c_gt, [e_rv, temperature, [monday]], [e_lit, 2]]],
        Doms, false).

test(pos_domain_entails_strict_positivity) :-
    Doms = [[rv_domain, [e_rv, gain, []], pos]],
    pclp_classify(
        [c_gt, [e_rv, gain, []], [e_lit, 0]],
        [], Doms, true).

test(neg_domain_entails_strict_negativity) :-
    Doms = [[rv_domain, [e_rv, loss, []], neg]],
    pclp_classify(
        [c_lt, [e_rv, loss, []], [e_lit, 0]],
        [], Doms, true).


:- end_tests(pclp_solver).