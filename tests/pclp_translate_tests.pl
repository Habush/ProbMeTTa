:- ensure_loaded(pclp_parser).

:- begin_tests(pclp_translate).

has_raw_node(Term) :-
    sub_term(Sub, Term),
    compound(Sub),
    functor(Sub, Name, _),
    atom_concat(raw_, _, Name).


test(joint_definition_is_canonical) :-
    pclp_parse(
                "Dom(temperature): Real. Dom(humidity): Real. (temperature, humidity)($day) ~ {0.7: temperature > 20 and humidity < 70, 0.3: temperature <= 15 and humidity >= 70}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [temperature, humidity]],
          [parameters, [Day]],
                    [domains, [[temperature, real], [humidity, real]]],
          [choices,
                     [[choice, 0, 0.7,
             [c_and,
              [[c_gt, [e_rv, temperature, [Day]], [e_lit, 20]],
               [c_lt, [e_rv, humidity, [Day]], [e_lit, 70]]]]],
                        [choice, 1, 0.3,
             [c_and,
              [[c_le, [e_rv, temperature, [Day]], [e_lit, 15]],
               [c_ge, [e_rv, humidity, [Day]], [e_lit, 70]]]]]]]]]),
    var(Day).

test(parameter_and_arithmetic_are_canonical) :-
    pclp_parse(
                "Dom(temperature): Real. temperature($day) ~ {1.0: temperature >= $day / 1000}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [temperature]],
                    [parameters, [Day]],
                    [domains, [[temperature, real]]],
          [choices,
                     [[choice, 0, 1.0,
             [c_ge,
                            [e_rv, temperature, [Day]],
                            [e_div, Day, [e_lit, 1000]]]]]]]]),
        var(Day).

test(existing_syntax_is_canonical_sugar) :-
    pclp_parse(
                "Dom(coin): {True, False}. Dom(t1): Real. coin ~ Bernoulli(0.8). t1 ~ {0.7: [0, 1], 0.2: [1, 2], 0.1: [2, 3]}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [coin]],
          [parameters, []],
                    [domains, [[coin, [discrete, [true, false]]]]],
                    [choices, CoinChoices]],
         [rv_definition, 1,
          [rv_labels, [t1]],
          [parameters, []],
                    [domains, [[t1, real]]],
                    [choices, IntvlChoices]]]),
                CoinChoices = [[choice, 0, _, _],
                                             [choice, 1, _, _]],
                IntvlChoices = [[choice, 0, _, _],
                                                [choice, 1, _, _],
                                                [choice, 2, _, _]].

test(definition_ids_preserve_source_order) :-
    pclp_parse(
                "Dom(temperature): Real. temperature(monday) ~ {1.0: temperature > 10}. temperature($day) ~ {1.0: temperature > 0}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [temperature]],
                    [parameters, [monday]],
                    [domains, [[temperature, real]]],
          [choices, _]],
         [rv_definition, 1,
          [rv_labels, [temperature]],
                    [parameters, [Day]],
                    [domains, [[temperature, real]]],
            [choices, _]]]),
        var(Day).

test(structured_parameters_are_canonical) :-
    pclp_parse(
                "Dom(temperature): Real. temperature(next($day)) ~ {1.0: temperature > 0}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [temperature]],
                    [parameters, [[next, Day]]],
                    [domains, [[temperature, real]]],
            [choices, _]]]),
        var(Day).

test(explicit_random_reference_is_canonical) :-
    pclp_parse(
                "Dom(temperature): Real. Dom(humidity): Real. temperature($day) ~ {1.0: temperature > 0}. humidity($day) ~ {1.0: humidity > temperature($day)}.",
        [program, _,
         [rv_definition, 1,
          [rv_labels, [humidity]],
          [parameters, [Day]],
                    [domains, [[humidity, real]]],
          [choices,
                     [[choice, 0, 1.0,
             [c_gt,
              [e_rv, humidity, [Day]],
              [e_rv, temperature, [Day]]]]]]]]),
        var(Day).

test(definitions_contain_no_raw_nodes) :-
    pclp_parse(
        "Dom(temperature): Real. temperature(next($day)) ~ {1.0: temperature > $day / 1000}.",
        [program, Def]),
    \+ has_raw_node(Def).

test(rule_and_query_use_native_distinct_variables) :-
    pclp_parse(
        "comfortable($day) <- day($day). query(comfortable($day)).",
        [program,
         [rule, 0, [comfortable, RuleDay], [[day, RuleDay]]],
         [query, 0, [comfortable, QryDay]]]),
    var(RuleDay),
    var(QryDay),
    RuleDay \== QryDay.

test(random_variable_goal_is_a_constraint) :-
    pclp_parse(
        "Dom(coin): {True, False}. coin ~ Bernoulli(0.8). saved <- coin.",
        [program, _,
         [rule, 0, [saved],
          [[c_eq, [e_rv, coin, []], [e_lit, true]]]]]).

test(categorical_rule_variable_is_a_literal) :-
    pclp_parse(
        "Dom(color): {red, blue, green}. color ~ {1.0: red}. draw($color) <- color = $color. query(draw(red)).",
        [program, _,
         [rule, 0, [draw, Color],
          [[c_eq, [e_rv, color, []], [e_lit, Color]]]],
         [query, 0, [draw, red]]]),
    var(Color).



test(rejects_scalar_to_joint_regrouping,
     [throws(error(inconsistent_random_variable_group(
                       temperature, [temperature],
                       [temperature, humidity]), _))]) :-
    pclp_parse(
        "Dom(temperature): Real. Dom(humidity): Real. temperature($day) ~ {1.0: temperature > 0}. (temperature, humidity)($day) ~ {1.0: temperature > 0 and humidity > 0}.",
        _).

test(rejects_reordered_joint_labels,
     [throws(error(inconsistent_random_variable_group(
                       humidity, [temperature, humidity],
                       [humidity, temperature]), _))]) :-
    pclp_parse(
        "Dom(temperature): Real. Dom(humidity): Real. (temperature, humidity)($day) ~ {1.0: temperature > 0 and humidity > 0}. (humidity, temperature)($day) ~ {1.0: temperature > 0 and humidity > 0}.",
        _).

test(rejects_duplicate_labels,
     [throws(error(duplicate_random_variable_labels(
                   [temperature, temperature]), _))]) :-
    pclp_parse(
        "Dom(temperature): Real. (temperature, temperature)($day) ~ {1.0: temperature > 0}.",
        _).

test(rejects_inconsistent_arity,
     [throws(error(inconsistent_random_variable_arity(
                       temperature, 0, 1), _))]) :-
    pclp_parse(
        "Dom(temperature): Real. temperature ~ {1.0: temperature > 0}. temperature($day) ~ {1.0: temperature > 0}.",
        _).

test(rejects_out_of_scope_definition_variable,
     [throws(error(undeclared_definition_variable(
                       [temperature], threshold), _))]) :-
    pclp_parse(
        "Dom(temperature): Real. temperature($day) ~ {1.0: temperature > $threshold}.",
        _).

test(rejects_general_probabilities_below_one,
     [throws(error(probabilities_do_not_sum_to_one(
                       [temperature], 0.8), _))]) :-
    pclp_parse(
        "Dom(temperature): Real. temperature ~ {0.8: temperature > 0}.",
        _).

test(accepts_open_unbounded_interval) :-
    pclp_parse(
        "Dom(temperature): Real. temperature ~ {1.0: (-inf, inf)}.",
        [program, [rv_definition, 0, _, _, _, _]]).

test(rejects_closed_infinite_endpoint,
     [throws(error(invalid_interval([temperature],
                                   raw_interval(closed, neg_inf, 0, closed)),
                   _))]) :-
    pclp_parse(
        "Dom(temperature): Real. temperature ~ {1.0: [-inf, 0]}.",
        _).

test(rejects_missing_domain,
     [throws(error(missing_random_variable_domain(color), _))]) :-
    pclp_parse(
        "color ~ {1.0: color = red}.",
        _).

test(rejects_duplicate_domain,
     [throws(error(duplicate_random_variable_domain(color), _))]) :-
    pclp_parse(
        "Dom(color): {red, blue}. Dom(color): {red, green}. color ~ {1.0: color = red}.",
        _).

test(rejects_domain_without_definition,
     [throws(error(domain_without_random_variable_definition(color), _))]) :-
    pclp_parse(
        "Dom(color): {red, blue}.",
        _).

test(rejects_duplicate_normalized_domain_value,
     [throws(error(duplicate_domain_value(coin), _))]) :-
    pclp_parse(
        "Dom(coin): {True, true}. coin ~ Bernoulli(0.5).",
        _).

test(categorical_domain_and_literal_are_canonical) :-
    pclp_parse(
        "Dom(color): {red, blue, green}. color ~ {1.0: color = red}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [color]],
          [parameters, []],
          [domains, [[color, [discrete, [red, blue, green]]]]],
          [choices,
           [[choice, 0, 1.0,
             [c_eq, [e_rv, color, []], [e_lit, red]]]]]]]).

test(categorical_residual_uses_full_domain) :-
    pclp_parse(
        "Dom(color): {red, blue, green}. color ~ {0.5: red, 0.25: blue}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [color]],
          [parameters, []],
          [domains, [[color, [discrete, [red, blue, green]]]]],
          [choices,
           [[choice, 0, 0.5,
             [c_eq, [e_rv, color, []], [e_lit, red]]],
            [choice, 1, 0.25,
             [c_eq, [e_rv, color, []], [e_lit, blue]]],
            [choice, 2, 0.25,
             [c_in, [e_rv, color, []], [red, blue, green]]]]]]]).

test(categorical_exact_mass_has_no_residual) :-
    pclp_parse(
        "Dom(color): {red, blue, green}. color ~ {0.5: red, 0.3: blue, 0.2: green}.",
        [program,
         [rv_definition, 0, _, _, _,
          [choices,
           [[choice, 0, 0.5, _],
            [choice, 1, 0.3, _],
            [choice, 2, 0.2, _]]]]]).

test(rejects_categorical_value_outside_domain,
     [throws(error(value_outside_domain(color, yellow), _))]) :-
    pclp_parse(
        "Dom(color): {red, blue, green}. color ~ {0.7: yellow}.",
        _).

test(categorical_disequality_is_canonical) :-
        pclp_parse(
                "Dom(color): {red, blue}. color ~ {1.0: color != red}.",
                [program,
                 [rv_definition, 0, _, _, _,
                    [choices,
                     [[choice, 0, 1.0,
                         [c_ne, [e_rv, color, []], [e_lit, red]]]]]]]).

test(rejects_value_outside_discrete_domain,
     [throws(error(value_outside_domain(color, yellow), _))]) :-
    pclp_parse(
        "Dom(color): {red, blue, green}. color ~ {1.0: color = yellow}.",
        _).

test(rejects_discrete_ordering,
     [throws(error(invalid_discrete_relation(color, lt), _))]) :-
    pclp_parse(
        "Dom(color): {red, blue}. color ~ {1.0: color < blue}.",
        _).

test(rejects_continuous_equality,
    [throws(error(invalid_continuous_relation(eq), _))]) :-
    pclp_parse(
       "Dom(x): Real. x ~ {1.0: x = 0}.",
       _).

test(rejects_continuous_disequality,
    [throws(error(invalid_continuous_relation(ne), _))]) :-
    pclp_parse(
       "Dom(x): Real. x ~ {1.0: x != 0}.",
       _).

test(rejects_discrete_arithmetic,
     [throws(error(continuous_expression_required(_, _), _))]) :-
    pclp_parse(
        "Dom(color): {red, blue}. color ~ {1.0: color + 1 = 2}.",
        _).

test(rejects_categorical_rv_equality,
     [throws(error(categorical_variable_comparison_not_supported(
                       eq, primary, status), _))]) :-
    pclp_parse(
        "Dom(primary): {red, blue}. Dom(status): {open, closed}. (primary, status) ~ {1.0: primary = status}.",
        _).

test(rejects_nonlinear_real_multiplication,
     [throws(error(nonlinear_multiplication(_, _), _))]) :-
    pclp_parse(
        "Dom(x): Real. Dom(y): Real. (x, y) ~ {1.0: x * y < 1}.",
        _).

test(rejects_nonliteral_divisor,
     [throws(error(nonliteral_divisor(_), _))]) :-
    pclp_parse(
        "Dom(x): Real. Dom(y): Real. (x, y) ~ {1.0: x / y < 1}.",
        _).

test(linear_real_arithmetic_is_canonical) :-
    pclp_parse(
        "Dom(x): Real. Dom(y): Real. (x, y) ~ {1.0: 2 * x + y / 2 >= x - 1}.",
        [program, [rv_definition, 0, _, _, _, [choices, [_]]]]).

test(pos_and_neg_domains_are_canonical) :-
    pclp_parse(
        "Dom(gain): Pos. Dom(loss): Neg. (gain, loss) ~ {1.0: gain + loss >= 0}.",
        [program,
         [rv_definition, 0,
          [rv_labels, [gain, loss]],
          [parameters, []],
          [domains, [[gain, pos], [loss, neg]]],
          [choices, [_]]]]).

test(rejects_bernoulli_on_non_boolean_domain,
     [throws(error(invalid_bernoulli_domain(
                       coin, discrete([heads, tails])), _))]) :-
    pclp_parse(
        "Dom(coin): {heads, tails}. coin ~ Bernoulli(0.5).",
        _).

test(rejects_intervals_on_discrete_domain,
     [throws(error(continuous_domain_required(
                       level, discrete([low, high])), _))]) :-
    pclp_parse(
        "Dom(level): {low, high}. level ~ {1.0: [0, 1]}.",
        _).

:- end_tests(pclp_translate).