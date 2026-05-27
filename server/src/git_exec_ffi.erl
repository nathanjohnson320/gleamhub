-module(git_exec_ffi).
-export([init_bare/1, run_git/2]).

init_bare(PathBin) when is_binary(PathBin) ->
  Path = binary_to_list(PathBin),
  Cmd = "git init --bare " ++ quote(Path),
  os:cmd(Cmd),
  nil.

%% os:cmd/1 returns only output text, not the exit code — that forced the old
%% __GLEAMHUB_EXIT marker in stdout (broken when file content contained it).
%% A port with exit_status returns stdout and exit code separately; no temp files.
run_git(GitDirBin, ArgsBin) ->
  GitDir = binary_to_list(GitDirBin),
  Args = lists:map(fun arg_to_list/1, ArgsBin),
  Cmd =
    "git -C "
    ++ quote(GitDir)
    ++ " "
    ++ join_quoted_args(Args)
    ++ " 2>&1",
  Port = open_port({spawn, Cmd}, [exit_status, binary]),
  {Exit, Stdout, Stderr} = collect_port(Port, <<>>, <<>>),
  {Exit, gleam_string(Stdout), gleam_string(Stderr)}.

collect_port(Port, OutAcc, ErrAcc) ->
  receive
    {Port, {data, Data}} ->
      collect_port(Port, <<OutAcc/binary, Data/binary>>, ErrAcc);
    {Port, {exit_status, Status}} ->
      {Status, OutAcc, ErrAcc};
    {'EXIT', Port, _Reason} ->
      {1, OutAcc, ErrAcc}
  after 120_000 ->
    port_close(Port),
    {1, OutAcc, ErrAcc}
  end.

valid_utf8(Bin) when is_binary(Bin) ->
  case unicode:characters_to_binary(Bin, utf8, utf8) of
    Result when is_binary(Result) -> true;
    _ -> false
  end.

gleam_string(Bin) ->
  case valid_utf8(Bin) of
    true -> Bin;
    false -> <<>>
  end.

join_quoted_args([]) ->
  "";
join_quoted_args([H]) ->
  quote(H);
join_quoted_args([H | T]) ->
  quote(H) ++ " " ++ join_quoted_args(T).

arg_to_list(B) when is_binary(B) ->
  binary_to_list(B);
arg_to_list(L) when is_list(L) ->
  L.

quote(Path) ->
  "'" ++ escape_sq(Path) ++ "'".

escape_sq(Path) ->
  re:replace(Path, "'", "'\\\\''", [global, {return, list}]).
