-module(git_cmd).
-export([run/1, run_in/2, run_in_wt/2, gleam_string/1]).

-define(TIMEOUT_MS, 120_000).

%% Run git with explicit args (no -C). Example: run(["init", "--bare", Path]).
run(Args) when is_list(Args) ->
  case git_executable() of
    {ok, Git} ->
      StrArgs = lists:map(fun to_list/1, Args),
      exec(Git, StrArgs);
    {error, Reason} ->
      {127, Reason, <<>>}
  end.

%% Run git -C <dir> <args...>
run_in(GitDir, Args) when is_list(GitDir), is_list(Args) ->
  run(["-C", GitDir | Args]).

run_in_wt(WtDir, Args) ->
  run_in(WtDir, Args).

git_executable() ->
  case os:find_executable("git") of
    false -> {error, <<"git not found">>};
    Path -> {ok, Path}
  end.

exec(Git, Args) ->
  Port =
    open_port(
      {spawn_executable, Git},
      [exit_status, binary, stderr_to_stdout, {args, Args}]
    ),
  collect_port(Port, <<>>, <<>>).

collect_port(Port, OutAcc, _ErrAcc) ->
  receive
    {Port, {data, Data}} ->
      collect_port(Port, <<OutAcc/binary, Data/binary>>, <<>>);
    {Port, {exit_status, Status}} ->
      {Status, OutAcc, <<>>};
    {'EXIT', Port, _Reason} ->
      {1, OutAcc, <<>>}
  after ?TIMEOUT_MS ->
    port_close(Port),
    {1, OutAcc, <<>>}
  end.

gleam_string(Bin) ->
  case valid_utf8(Bin) of
    true -> Bin;
    false -> <<>>
  end.

valid_utf8(Bin) when is_binary(Bin) ->
  case unicode:characters_to_binary(Bin, utf8, utf8) of
    Result when is_binary(Result) -> true;
    _ -> false
  end.

to_list(B) when is_binary(B) ->
  binary_to_list(B);
to_list(L) when is_list(L) ->
  L.
