-module(git_exec_test_ffi).
-export([
  setup_fixture_repo/0,
  setup_conflict_fixture_repo/0,
  cleanup_fixture_repo/1,
  clone_fixture_to_bare/2,
  rev_parse/2
]).

setup_fixture_repo() ->
  Work =
    filename:join([
      "/tmp",
      "gleamhub_git_test_" ++ integer_to_list(erlang:unique_integer([positive]))
    ]),
  os:cmd("rm -rf " ++ quote(Work) ++ " && mkdir -p " ++ quote(Work) ++ "/src"),
  ok = file:write_file(
    filename:join([Work, "README.md"]),
    <<"# Gleamhub test\n\nHello from fixture.\n">>
  ),
  ok = file:write_file(
    filename:join([Work, "src", "main.gleam"]),
    <<"pub fn main() { Nil }\n">>
  ),
  ok = file:write_file(
    filename:join([Work, "CHANGELOG.md"]),
    <<"# Changelog\n\n## 1.0.0\n- Initial release\n__GLEAMHUB_EXIT:0\n">>
  ),
  _ = os:cmd(
    "cd "
    ++ quote(Work)
    ++ " && git init -q && git add . && git -c user.email=test@test.com -c user.name=Test commit -qm init && git branch -M main"
  ),
  ok = file:write_file(
    filename:join([Work, "feature.txt"]),
    <<"feature branch\n">>
  ),
  _ = os:cmd(
    "cd "
    ++ quote(Work)
    ++ " && git checkout -q -b feature && git add feature.txt && git -c user.email=test@test.com -c user.name=Test commit -qm feature"
  ),
  _ = os:cmd("cd " ++ quote(Work) ++ " && git checkout -q main"),
  list_to_binary(Work).

setup_conflict_fixture_repo() ->
  Work =
    filename:join([
      "/tmp",
      "gleamhub_git_conflict_" ++ integer_to_list(erlang:unique_integer([positive]))
    ]),
  ok = filelib:ensure_dir(filename:join([Work, "src"])),
  ok = file:write_file(filename:join([Work, "conflict.txt"]), <<"base\n">>),
  _ = os:cmd(
    "cd "
    ++ quote(Work)
    ++ " && git init -q && git add . && git -c user.email=test@test.com -c user.name=Test commit -qm init && git branch -M main"
  ),
  ok = file:write_file(filename:join([Work, "conflict.txt"]), <<"feature\n">>),
  _ = os:cmd(
    "cd "
    ++ quote(Work)
    ++ " && git checkout -q -b feature && git add conflict.txt && git -c user.email=test@test.com -c user.name=Test commit -qm feature"
  ),
  _ = os:cmd("cd " ++ quote(Work) ++ " && git checkout -q main"),
  ok = file:write_file(filename:join([Work, "conflict.txt"]), <<"main\n">>),
  _ = os:cmd(
    "cd "
    ++ quote(Work)
    ++ " && git add conflict.txt && git -c user.email=test@test.com -c user.name=Test commit -qm main"
  ),
  list_to_binary(Work).

cleanup_fixture_repo(PathBin) ->
  Path = binary_to_list(PathBin),
  os:cmd("rm -rf " ++ quote(Path)),
  nil.

clone_fixture_to_bare(RootBin, DiskPathBin) ->
  Root = binary_to_list(RootBin),
  DiskPath = binary_to_list(DiskPathBin),
  WorkBin = setup_fixture_repo(),
  Work = binary_to_list(WorkBin),
  Dest = filename:join([Root, DiskPath]),
  ok = filelib:ensure_dir(filename:dirname(Dest)),
  Cmd =
    "git clone --bare "
    ++ quote(Work)
    ++ " "
    ++ quote(Dest)
    ++ " 2>&1",
  case run_cmd(Cmd) of
    {ok, _} -> WorkBin;
    {error, Msg} -> erlang:error(Msg)
  end.

rev_parse(GitDirBin, RefBin) ->
  GitDir = binary_to_list(GitDirBin),
  Ref = binary_to_list(RefBin),
  Cmd =
    "git -C "
    ++ quote(GitDir)
    ++ " rev-parse "
    ++ quote(Ref)
    ++ " 2>&1",
  case run_cmd(Cmd) of
    {ok, Sha} -> list_to_binary(string:trim(Sha, trailing, "\n"));
    {error, Msg} -> erlang:error(Msg)
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
