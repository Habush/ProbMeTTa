pclp_clear_gwmc_tables(true) :-
    (   current_predicate(gwmc_rec/3)
    ->  abolish_table_subgoals(gwmc_rec(_, _, _))
    ;   true
    ).