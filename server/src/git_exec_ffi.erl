-module(git_exec_ffi).
-export([init_bare/1, run_git/2]).

init_bare(PathBin) when is_binary(PathBin) ->
  Path = binary_to_list(PathBin),
  Cmd = "git init --bare " ++ quote(Path),
  os:cmd(Cmd),
  nil.

run_git(GitDirBin, ArgsBin) ->
  GitDir = binary_to_list(GitDirBin),
  Args = lists:map(fun arg_to_list/1, ArgsBin),
  Inner =
    "git -C "
    ++ quote(GitDir)
    ++ " "
    ++ join_quoted_args(Args)
    ++ " 2>&1; echo __GLEAMHUB_EXIT:$?",
  Cmd = "sh -c " ++ quote(Inner),
  Output = string:trim(os:cmd(Cmd), trailing, "\n"),
  {Exit, Stdout, Stderr} = parse_output(Output),
  {Exit, list_to_binary(Stdout), list_to_binary(Stderr)}.

parse_output(Output) ->
  case string:split(Output, "__GLEAMHUB_EXIT:", trailing) of
    [Body, ExitStr] ->
      Exit =
        case string:to_integer(string:trim(ExitStr, trailing, "\n")) of
          {N, _} when is_integer(N) -> N;
          error -> 1
        end,
      {Exit, Body, ""};
    _ ->
      {1, Output, ""}
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
