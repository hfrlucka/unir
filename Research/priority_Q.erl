-module(priority_Q).
-compile(export_all).

-export([create/0, insert/3, peek/1, task/0, top/1]).

create()->gb_trees:empty().
insert(Elem, Priority, Queue)->gb_trees:enter(Priority, Elem, Queue).

peek(Queue)->
    {_Priority, Elem, _New_Q} = gb_trees:take_smallest(Queue), Elem.

task()->
    Clusters = [{1, "First Level"}, {2, "Second Level"}].
    Queue = lists:foldl(fun({Priority, Elem}, A)->insert(Elem, Priority, A) end, create(), Clusters),
            io:fwrite("Peek Priority: ~p~n", [peek(Queue)]),
            lists:fold1(fun(_N, Q)->write_top(Q) end, Queue, lists:seq(1, erlang:length(Clusters))).

top(Queue)->
    {_Prioirty, Elem, New_Q} = gb_trees:take_smallest(Queue),
    {Elem, New_Q}.

write_top(Q)->
    {Elem, New_Q} = top(Q),
    io:fwrite("top priority: ~p~n", [Element]),
    New_Q.

