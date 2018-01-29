%% -------------------------------------------------------------------
%%
%% Copyright (c) 2017 Christopher S. Meiklejohn.  All Rights Reserved.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
%%

-module(throughput_SUITE).
-author("Christopher S. Meiklejohn <christopher.meiklejohn@gmail.com>").

%% common_test callbacks
-export([suite/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_testcase/2,
         end_per_testcase/2,
         all/0,
         groups/0,
         init_per_group/2]).

%% tests
-compile([export_all]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/inet.hrl").

-define(SUPPORT, support).

%% ===================================================================
%% common_test callbacks
%% ===================================================================

suite() ->
    [{timetrap, {hours, 10}}].

init_per_suite(_Config) ->
    _Config.

end_per_suite(_Config) ->
    _Config.

init_per_testcase(Case, Config) ->
    ct:pal("Beginning test case ~p", [Case]),
    [{hash, erlang:phash2({Case, Config})}|Config].

end_per_testcase(Case, Config) ->
    ct:pal("Ending test case ~p", [Case]),
    Config.

init_per_group(disterl, Config) ->
    Config;

init_per_group(partisan, Config) ->
    [{partisan_dispatch, true}] ++ Config;

init_per_group(partisan_with_parallelism, Config) ->
    [{parallelism, 5}] ++ init_per_group(partisan, Config);
init_per_group(partisan_with_binary_padding, Config) ->
    [{binary_padding, true}] ++ init_per_group(partisan, Config);
init_per_group(partisan_with_vnode_partitioning, Config) ->
    [{vnode_partitioning, true}] ++ init_per_group(partisan, Config);

init_per_group(bench, Config) ->
    ?SUPPORT:bench_config() ++ Config;

init_per_group(_, Config) ->
    Config.

end_per_group(_, _Config) ->
    ok.

all() ->
    [
     {group, default, []}
    ].

groups() ->
    [
     {bench, [],
      [bench_test]},

     {default, [],
      [{group, bench}] },

     {disterl, [],
      [{group, bench}] },
     
     {partisan, [],
      [{group, bench}]},

     {partisan_with_parallelism, [],
      [{group, bench}]},

     {partisan_with_binary_padding, [],
      [{group, bench}]},

     {partisan_with_vnode_partitioning, [],
      [{group, bench}]}
    ].

%% ===================================================================
%% Tests.
%% ===================================================================

bench_test(Config0) ->
    RootDir = ?SUPPORT:root_dir(Config0),

    ct:pal("Configuration was: ~p", [Config0]),

    Config = case file:consult(RootDir ++ "config/test.config") of
        {ok, Terms} ->
            ct:pal("Read terms configuration: ~p", [Terms]),
            Terms ++ Config0;
        {error, Reason} ->
            ct:fail("Could not open the terms configuration: ~p", [Reason]),
            ok
    end,

    ct:pal("Configuration is now: ~p", [Config]),

    Nodes = ?SUPPORT:start(bench_test,
                           Config,
                           [{num_nodes, 3},
                           {partisan_peer_service_manager,
                               partisan_default_peer_service_manager}]),

    ct:pal("Configuration: ~p", [Config]),

    RootDir = ?SUPPORT:root_dir(Config),

    %% Configure parameters.
    ResultsParameters = case proplists:get_value(partisan_dispatch, Config, false) of
        true ->
            BinaryPadding = case proplists:get_value(binary_padding, Config, false) of
                true ->
                    "binary-padding";
                false ->
                    "no-binary-padding"
            end,

            VnodePartitioning = case proplists:get_value(vnode_partitioning, Config, false) of
                true ->
                    "vnode-partitioning";
                false ->
                    "no-vnode-partitioning"
            end,

            Parallelism = case proplists:get_value(parallelism, Config, 1) of
                1 ->
                    "parallelism-" ++ integer_to_list(1);
                P ->
                    "parallelism-" ++ integer_to_list(P)
            end,

            "partisan-" ++ BinaryPadding ++ "-" ++ VnodePartitioning ++ "-" ++ Parallelism;
        false ->
            "disterl"
    end,

    %% Select the node configuration.
    SortedNodes = lists:usort([Node || {_Name, Node} <- Nodes]),

    %% Verify partisan connection is configured with the correct
    %% membership information.
    ct:pal("Waiting for partisan membership..."),
    ?assertEqual(ok, ?SUPPORT:wait_until_partisan_membership(SortedNodes)),

    %% Ensure we have the right number of connections.
    %% Verify appropriate number of connections.
    ct:pal("Waiting for partisan connections..."),
    ?assertEqual(ok, ?SUPPORT:wait_until_all_connections(SortedNodes)),

    %% Configure bench paths.
    BenchDir = RootDir ++ "_build/default/lib/lasp_bench/",

    %% Build bench.
    ct:pal("Building benchmarking suite..."),
    BuildCommand = "cd " ++ BenchDir ++ "; make all",
    _BuildOutput = os:cmd(BuildCommand),
    % ct:pal("~p => ~p", [BuildCommand, BuildOutput]),

    %% Get benchmark configuration.
    BenchConfig = ?config(bench_config, Config),

    %% Run bench.
    ct:pal("Executing benchmark..."),
    SortedNodesString = lists:flatten(lists:join(",", lists:map(fun(N) -> atom_to_list(N) end, SortedNodes))),
    BenchCommand = "cd " ++ BenchDir ++ "; NODES=\"" ++ SortedNodesString ++ "\" _build/default/bin/lasp_bench " ++ RootDir ++ "examples/" ++ BenchConfig,
    _BenchOutput = os:cmd(BenchCommand),
    % ct:pal("~p => ~p", [BenchCommand, BenchOutput]),

    %% Generate results.
    ct:pal("Generating results..."),
    ResultsCommand = "cd " ++ BenchDir ++ "; make results",
    _ResultsOutput = os:cmd(ResultsCommand),
    % ct:pal("~p => ~p", [ResultsCommand, ResultsOutput]),

    case os:getenv("TRAVIS") of
        false ->
            %% Make results dir.
            ct:pal("Making results output directory..."),
            DirCommand = "mkdir " ++ RootDir ++ "results/",
            _DirOutput = os:cmd(DirCommand),
            % ct:pal("~p => ~p", [DirCommand, DirOutput]),

            %% Get full path to the results.
            ReadLinkCommand = "readlink " ++ BenchDir ++ "tests/current",
            ReadLinkOutput = os:cmd(ReadLinkCommand),
            FullResultsPath = string:substr(ReadLinkOutput, 1, length(ReadLinkOutput) - 1),
            ct:pal("~p => ~p", [ReadLinkCommand, ReadLinkOutput]),

            %% Get directory name.
            Directory = string:substr(FullResultsPath, string:rstr(FullResultsPath, "/") + 1, length(FullResultsPath)),
            ResultsDirectory = Directory ++ "-" ++ BenchConfig ++ "-" ++ ResultsParameters,

            %% Copy results.
            ct:pal("Copying results into output directory: ~p", [ResultsDirectory]),
            CopyCommand = "cp -rpv " ++ FullResultsPath ++ " " ++ RootDir ++ "results/" ++ ResultsDirectory,
            _CopyOutput = os:cmd(CopyCommand);
            % ct:pal("~p => ~p", [CopyCommand, CopyOutput]);
        _ ->
            ok
    end,

    ?SUPPORT:stop(Nodes),

    ok.