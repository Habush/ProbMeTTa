:- ensure_loaded(pclp_parser).

:- begin_tests(pclp_parser).

parse_raw(Source, AST) :-
    pclp_parse_raw(Source, AST).


test(domain_declarations) :-
    parse_raw(
        "Dom(coin): {True, False}. Dom(t1): Real. Dom(gain): Pos. Dom(loss): Neg.",
        [program,
         raw_rv_domain(coin, discrete(['True', 'False'])),
         raw_rv_domain(t1, real),
         raw_rv_domain(gain, pos),
         raw_rv_domain(loss, neg)]).

test(inline_comment) :-
    parse_raw(
        "Dom(coin): {True, False}. // Boolean state\nDom(t1): Real.",
        [program,
         raw_rv_domain(coin, discrete(['True', 'False'])),
         raw_rv_domain(t1, real)]).

test(comment_at_eof) :-
    parse_raw(
        "query(saved). // Run the saved query",
        [program, raw_query(raw_atom(saved, []))]).

test(rejects_missing_statement_terminator,
     [throws(error(
         syntax_error(invalid_pclp_source),
         file('<string>', 2, 1, _)))]) :-
    parse_raw(
        "Dom(coin): {True, False}.\nquery(saved)",
        _).


test(joint_parameterized_definition) :-
    parse_raw(
        "(temperature, humidity)($day) ~ {0.7: temperature > 20 and humidity < 70, 0.3: temperature = 15 and humidity >= 70}.",
        [program,
         raw_rv_definition(
             [temperature, humidity],
             [raw_var(day)],
             constraints([
                 raw_alternative(
                     0.7,
                     raw_constraint_and([
                         raw_relation(gt, raw_const(temperature),
                                      raw_number(20)),
                         raw_relation(lt, raw_const(humidity),
                                      raw_number(70))
                     ])),
                 raw_alternative(
                     0.3,
                     raw_constraint_and([
                         raw_relation(eq, raw_const(temperature),
                                      raw_number(15)),
                         raw_relation(ge, raw_const(humidity),
                                      raw_number(70))
                     ]))
             ]))]).

test(parameterized_definition) :-
    parse_raw(
        "temperature($day) ~ {1.0: temperature >= $day / 1000}.",
        [program,
         raw_rv_definition(
             [temperature],
             [raw_var(day)],
             constraints([
                 raw_alternative(
                     1.0,
                     raw_relation(
                         ge,
                         raw_const(temperature),
                         e_div(raw_var(day), raw_number(1000))))
             ]))]).

test(metta_variables_constants_and_applications) :-
    parse_raw(
        "comfortable($day) <- day($day), temperature($day) > 20. query(comfortable(monday)).",
        [program,
         raw_rule(
             raw_atom(comfortable, [raw_var(day)]),
             [raw_goal_atom(raw_atom(day, [raw_var(day)])),
              raw_goal_constraint(
                  raw_relation(
                      gt,
                      raw_apply(temperature, [raw_var(day)]),
                      raw_number(20)))]),
         raw_query(raw_atom(comfortable, [raw_const(monday)]))]).

test(joint_definition_without_parameters) :-
    parse_raw(
        "(time-comp1, energy-comp1) ~ {1.0: time-comp1 > 0 and energy-comp1 > 0}.",
        [program,
         raw_rv_definition(
             ['time-comp1', 'energy-comp1'],
             [],
             constraints([
                 raw_alternative(
                     1.0,
                     raw_constraint_and([
                         raw_relation(gt, raw_const('time-comp1'),
                                      raw_number(0)),
                         raw_relation(gt, raw_const('energy-comp1'),
                                      raw_number(0))
                     ]))
             ]))]).

test(structured_definition_parameter) :-
    parse_raw(
        "temperature(next($day)) ~ {1.0: temperature > 0}.",
        [program,
         raw_rv_definition(
             [temperature],
             [raw_apply(next, [raw_var(day)])],
             constraints([
                 raw_alternative(
                     1.0,
                     raw_relation(gt, raw_const(temperature), raw_number(0)))
             ]))]).

:- end_tests(pclp_parser).