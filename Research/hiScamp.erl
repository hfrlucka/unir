-module(hiScamp).
-compile(export_all).
-author("Hana Frluckaj <hanafrla@cmu.edu>").
-behavior(partisan_clustering_strategy).

-export([init/1, dist/3, build_pq/2, center_clusters/3, 
         compute_centroid/3, hierarchial_clustering/1]).

%%initialize, distance method, compute distance, build priority queue,
%%compute centroid two clusters, compute centroid, hierarchial clustering,
%%valid heap node, add heap entry, evaluate, load data, loaded dataset,
%%display, main method

%%initialize state
init(Identity) -> 
    Membership = sets:add_element(myself(), sets:new()),
    State = #hiScamp{membership=Membership, actor=Identity},
    MembershipList = membership_list(State),
    {ok, MembershipList, State}.
    

