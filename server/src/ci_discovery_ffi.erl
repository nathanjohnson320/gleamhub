-module(ci_discovery_ffi).
-export([discover_module/2, branch_head/2]).

-define(CANDIDATES, [
  <<".dagger/dagger.json">>,
  <<"ci/dagger.json">>,
  <<"dagger/dagger.json">>
]).

discover_module(GitDirBin, CommitBin) ->
  GitDir = binary_to_list(GitDirBin),
  Commit = binary_to_list(CommitBin),
  Cmd =
    "git -C "
    ++ quote(GitDir)
    ++ " ls-tree -r --name-only "
    ++ quote(Commit)
    ++ " 2>&1",
  case run_cmd(Cmd) of
    {ok, Out} ->
      Files = string:split(string:trim(Out, trailing, "\n"), "\n", all),
      case first_candidate(Files) of
        undefined -> <<>>;
        Path -> module_dir(Path)
      end;
    {error, _} ->
      <<>>
  end.

first_candidate(Files) ->
  lists:foldl(
    fun(Cand, Acc) ->
      case Acc of
        undefined ->
          CandStr = binary_to_list(Cand),
          case lists:member(CandStr, Files) of
            true -> CandStr;
            false -> undefined
          end;
        _ ->
          Acc
      end
    end,
    undefined,
    ?CANDIDATES
  ).

module_dir("ci/dagger.json") ->
  <<"ci">>;
module_dir(".dagger/dagger.json") ->
  <<".dagger">>;
module_dir("dagger/dagger.json") ->
  <<"dagger">>;
module_dir(Path) ->
  case string:rchr(Path, $/) of
    0 ->
      list_to_binary(Path);
    Pos ->
      list_to_binary(string:substr(Path, 1, Pos - 1))
  end.

branch_head(GitDirBin, BranchBin) ->
  GitDir = binary_to_list(GitDirBin),
  Branch = binary_to_list(BranchBin),
  Ref = "refs/heads/" ++ Branch,
  Cmd =
    "git -C "
    ++ quote(GitDir)
    ++ " rev-parse "
    ++ quote(Ref)
    ++ " 2>&1",
  case run_cmd(Cmd) of
    {ok, Out} ->
      list_to_binary(string:trim(Out, trailing, "\n"));
    {error, _} ->
      <<>>
  end.

run_cmd(Cmd) ->
  Out = lists:flatten(os:cmd("sh -c " ++ quote(Cmd) ++ "; echo __EXIT:$?")),
  case string:split(Out, "__EXIT:", trailing) of
    [Body, ExitStr] ->
      Exit = string:trim(ExitStr, trailing, "\n"),
      case Exit of
        "0" -> {ok, Body};
        _ -> {error, Body}
      end;
    _ ->
      {error, Out}
  end.

quote(Path) ->
  "'" ++ escape_sq(Path) ++ "'".

escape_sq(Path) ->
  re:replace(Path, "'", "'\\\\''", [global, {return, list}]).
