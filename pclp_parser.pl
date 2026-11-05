:- use_module(library(dcg/basics)).
:- use_module(library(readutil)).
:- ensure_loaded(pclp_translate).

pclp_parse(Source, AST) :-
    pclp_parse_raw(Source, Program),
    pclp_translate(Program, AST).

pclp_parse_raw(Source, Program) :-
    pclp_parse_source(Source, '<string>', Program).


pclp_parse_file(Path, AST) :-
    read_file_to_string(Path, Source, []),
    pclp_parse_source(Source, Path, Program),
    pclp_translate(Program, AST).

pclp_parse_file_raw(Path, Program) :-
    read_file_to_string(Path, Source, []),
    pclp_parse_source(Source, Path, Program).


pclp([program|Statements]) -->
    layout,
    statements(Statements),
    layout,
    eos.

statements([Statement|Rest]) -->
    statement(Statement),
    !,
    statements(Rest).
statements([]) -->
    [].

statement(AST) --> domain_decl(AST).
statement(AST) --> random_decl(AST).
statement(AST) --> query_decl(AST).
statement(AST) --> rule_decl(AST).

/*
statement  ::= domain-declaration | random-declaration | rule | query
domain     ::= "Dom" "(" name ")" ":" domain-spec "."
domain-spec ::= "Real" | "Pos" | "Neg" | "{" name ("," name)* "}"
random     ::= rv-head "~" Bernoulli "(" probability ")" "."
             | rv-head "~" "{" region ("," region)* "}" "."
             | rv-head "~" "{" alternative ("," alternative)* "}" "."
rv-head    ::= name parameters? | "(" name ("," name)+ ")" parameters?
parameters ::= "(" term ("," term)* ")"
region     ::= probability ":" interval
alternative ::= probability ":" constraint
interval   ::= left-delim bound "," bound right-delim
left-delim ::= "[" | "("
right-delim ::= "]" | ")"
bound :: number | "-inf" | "inf"
rule       ::= atom ":-" goal ("," goal)* "."
query      ::= "query" "(" atom ")" "."
goal       ::= expression relation expression
             | atom
expression ::= expression "+" term | term
term       ::= term "*" factor | factor
factor     ::= number | name | "(" expression ")"

*/

domain_decl(raw_rv_domain(Label, Domain)) -->
    keyword("Dom"),
    symbol("("),
    identifier(Label),
    symbol(")"),
    symbol(":"),
    domain_spec(Domain),
    symbol(".").

domain_spec(real) --> keyword("Real").
domain_spec(pos) --> keyword("Pos").
domain_spec(neg) --> keyword("Neg").
domain_spec(discrete(Values)) -->
    symbol("{"),
    domain_values(Values),
    symbol("}").

domain_values([Value|Rest]) -->
    identifier(Value),
    domain_values_rest(Rest).

domain_values_rest([Value|Rest]) -->
    symbol(","),
    identifier(Value),
    !,
    domain_values_rest(Rest).
domain_values_rest([]) -->
    [].

random_decl(raw_rv_definition(Labels, Parameters, Distribution)) -->
    random_definition_head(Labels, Parameters),
    symbol("~"),
    distribution(Distribution),
    symbol(".").

random_definition_head(Labels, Parameters) -->
    symbol("("),
    rv_labels(Labels),
    symbol(")"),
    definition_parameters(Parameters).
random_definition_head([Label], Parameters) -->
    identifier(Label),
    definition_parameters(Parameters).

rv_labels([Label, Second|Rest]) -->
    identifier(Label),
    symbol(","),
    identifier(Second),
    rv_labels_rest(Rest).

rv_labels_rest([Label|Rest]) -->
    symbol(","),
    identifier(Label),
    !,
    rv_labels_rest(Rest).
rv_labels_rest([]) -->
    [].

definition_parameters(Parameters) -->
    symbol("("),
    definition_arguments(Parameters),
    symbol(")"),
    !.
definition_parameters([]) -->
    [].

definition_arguments([Argument|Rest]) -->
    first_order_term(Argument),
    definition_arguments_rest(Rest).
definition_arguments([]) -->
    [].

definition_arguments_rest([Argument|Rest]) -->
    symbol(","),
    first_order_term(Argument),
    !,
    definition_arguments_rest(Rest).
definition_arguments_rest([]) -->
    [].

first_order_term(AST) --> logical_variable(AST).
first_order_term(raw_number(Number)) --> numeric_literal(Number).
first_order_term(raw_apply(Name, Arguments)) -->
    identifier(Name),
    symbol("("),
    definition_arguments(Arguments),
    symbol(")").
first_order_term(raw_const(Name)) --> identifier(Name).

distribution(bernoulli(Probability)) -->
    keyword("Bernoulli"),
    symbol("("),
    probability(Probability),
    symbol(")").

distribution(categorical(Entries)) -->
    symbol("{"),
    categorical_entries(Entries),
    symbol("}").

distribution(regions(Regions)) -->
    symbol("{"),
    regions(Regions),
    symbol("}").

distribution(constraints(Alternatives)) -->
    symbol("{"),
    constraint_alternatives(Alternatives),
    symbol("}").

categorical_entries([Entry|Rest]) -->
    categorical_entry(Entry),
    categorical_entries_rest(Rest).

categorical_entries_rest([Entry|Rest]) -->
    symbol(","),
    categorical_entry(Entry),
    !,
    categorical_entries_rest(Rest).

categorical_entries_rest([]) --> [].

categorical_entry(raw_category(Prob, Value)) -->
    probability(Prob),
    symbol(":"),
    identifier(Value).

constraint_alternatives([Alternative|Rest]) -->
    constraint_alternative(Alternative),
    constraint_alternatives_rest(Rest).

constraint_alternatives_rest([Alternative|Rest]) -->
    symbol(","),
    constraint_alternative(Alternative),
    !,
    constraint_alternatives_rest(Rest).
constraint_alternatives_rest([]) -->
    [].

constraint_alternative(raw_alternative(Probability, Constraint)) -->
    probability(Probability),
    symbol(":"),
    constraint(Constraint).

constraint(raw_constraint_and([First, Second|Rest])) -->
    constraint_primary(First),
    keyword("and"),
    constraint_primary(Second),
    constraint_and_rest(Rest).
constraint(Constraint) -->
    constraint_primary(Constraint).

constraint_and_rest([Constraint|Rest]) -->
    keyword("and"),
    constraint_primary(Constraint),
    !,
    constraint_and_rest(Rest).
constraint_and_rest([]) -->
    [].

constraint_primary(Constraint) -->
    symbol("("),
    constraint(Constraint),
    symbol(")").
constraint_primary(Relation) -->
    relation(Relation).

regions([Region|Rest]) -->
    region(Region),
    regions_rest(Rest).

regions_rest([Region|Rest]) -->
    symbol(","),
    region(Region),
    !,
    regions_rest(Rest).
regions_rest([]) -->
    [].

region(raw_region(Probability, Interval)) -->
    probability(Probability),
    symbol(":"),
    interval(Interval).

interval(raw_interval(LeftType, Lower, Upper, RightType)) -->
    left_delimiter(LeftType),
    bound(Lower),
    symbol(","),
    bound(Upper),
    right_delimiter(RightType).

left_delimiter(closed) --> symbol("[").
left_delimiter(open)   --> symbol("(").

right_delimiter(closed) --> symbol("]").
right_delimiter(open)   --> symbol(")").

bound(neg_inf) --> keyword("-inf").
bound(pos_inf) --> keyword("inf").
bound(Number)  --> numeric_literal(Number).

rule_decl(raw_rule(Head, Goals)) -->
    logical_atom(Head),
    symbol("<-"),
    goals(Goals),
    symbol(".").

rule_decl(raw_rule(Head, [])) -->
    logical_atom(Head),
    symbol(".").

goals([Goal|Rest]) -->
    goal(Goal),
    goals_rest(Rest).

goals_rest([Goal|Rest]) -->
    symbol(","),
    goal(Goal),
    !,
    goals_rest(Rest).
goals_rest([]) -->
    [].

% Try a constraint before a logical atom
goal(raw_goal_constraint(Relation)) -->
    relation(Relation),
    !.

goal(raw_goal_atom(Atom)) -->
    logical_atom(Atom).

relation(raw_relation(Op, Left, Right)) -->
    expression(Left),
    relation_operator(Op),
    expression(Right).

relation_operator(le) --> symbol("<=").
relation_operator(ge) --> symbol(">=").
relation_operator(ne) --> symbol("!=").
relation_operator(eq) --> symbol("=").
relation_operator(lt) --> symbol("<").
relation_operator(gt) --> symbol(">").

expression(AST) -->
    term(First),
    expression_rest(First, AST).

expression_rest(Left, AST) -->
    add_operator(Op),
    term(Right),
    !,
    { Combined =.. [Op, Left, Right] },
    expression_rest(Combined, AST).
expression_rest(AST, AST) -->
    [].

add_operator(e_add) --> symbol("+").
add_operator(e_sub) --> symbol("-").

term(AST) -->
    factor(First),
    term_rest(First, AST).

term_rest(Left, AST) -->
    multiply_operator(Op),
    factor(Right),
    !,
    { Combined =.. [Op, Left, Right] },
    term_rest(Combined, AST).
term_rest(AST, AST) -->
    [].

multiply_operator(e_mul) --> symbol("*").
multiply_operator(e_div) --> symbol("/").

factor(raw_number(Number)) -->
    numeric_literal(Number).

factor(AST) -->
    logical_variable(AST).

factor(raw_apply(Name, Arguments)) -->
    identifier(Name),
    symbol("("),
    atom_arguments(Arguments),
    symbol(")").

factor(raw_const(Name)) -->
    identifier(Name).

factor(AST) -->
    symbol("("),
    expression(AST),
    symbol(")").

logical_atom(raw_atom(Name, Arguments)) -->
    identifier(Name),
    symbol("("),
    atom_arguments(Arguments),
    symbol(")").

logical_atom(raw_atom(Name, [])) -->
    identifier(Name).

atom_arguments([Argument|Rest]) -->
    expression(Argument),
    atom_arguments_rest(Rest).
atom_arguments([]) -->
    [].

atom_arguments_rest([Argument|Rest]) -->
    symbol(","),
    expression(Argument),
    !,
    atom_arguments_rest(Rest).
atom_arguments_rest([]) -->
    [].

query_decl(raw_query(Query)) -->
    keyword("query"),
    symbol("("),
    logical_atom(Query),
    symbol(")"),
    symbol(".").


probability(Probability) -->
    numeric_literal(Probability).

numeric_literal(Number) -->
    layout,
    number(Number),
    layout.

logical_variable(raw_var(Name)) -->
    layout,
    "$",
    identifier_token(Name),
    layout.

symbol(Symbol) -->
    layout,
    { string_codes(Symbol, Codes) },
    Codes,
    layout.

keyword(Keyword) -->
    layout,
    { string_codes(Keyword, Codes) },
    Codes,
    identifier_boundary,
    layout.

layout -->
    blanks,
    (   line_comment,
        !,
        layout
    ;   []
    ).

line_comment -->
    "//",
    string_without("\r\n", _),
    (   eol
    ;   eos
    ).

identifier(Name) -->
    layout,
    identifier_token(Name),
    layout.

identifier_token(Name) -->
    identifier_start(First),
    identifier_rest(Rest),
    {
        atom_codes(Name, [First|Rest])
    }.

identifier_start(Code) -->
    [Code],
    {
        code_type(Code, alpha)
        ;
        Code =:= 0'_
    }.

identifier_rest([Code|Rest]) -->
    [Code],
    {
        code_type(Code, alnum)
        ;
        memberchk(Code, [0'_, 0'-])
    },
    !,
    identifier_rest(Rest).
    
identifier_rest([]) -->
    [].

identifier_boundary -->
    peek_code(Next),
    {
        \+ code_type(Next, alnum),
        \+ memberchk(Next, [0'_, 0'-])
    },
    !.
identifier_boundary -->
    eos.

peek_code(Code, Input, Input) :-
    Input = [Code|_].


pclp_parse_source(Source, SourceName, Program) :-
    string_codes(Source, Codes),
    (   phrase(pclp(Program), Codes)
    ->  true
    ;   pclp_syntax_error(SourceName, Codes)
    ).

pclp_syntax_error(SourceName, Codes) :-
    phrase(pclp_prefix, Codes, Rest),
    length(Codes, SourceLength),
    length(Rest, RestLength),
    Offset is SourceLength - RestLength,
    length(Prefix, Offset),
    append(Prefix, Rest, Codes),
    pclp_line_column(Prefix, 1, 1, Line, Column),
    throw(error(
        syntax_error(invalid_pclp_source),
        file(SourceName, Line, Column, Offset))).

pclp_prefix -->
    layout,
    statements(_),
    layout.

pclp_line_column([], Line, Column, Line, Column).
pclp_line_column([0'\n|Codes], Line0, _, Line, Column) :-
    !,
    Line1 is Line0 + 1,
    pclp_line_column(Codes, Line1, 1, Line, Column).
pclp_line_column([_|Codes], Line0, Column0, Line, Column) :-
    Column1 is Column0 + 1,
    pclp_line_column(Codes, Line0, Column1, Line, Column).