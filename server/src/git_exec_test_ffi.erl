-module(git_exec_test_ffi).
-export([setup_fixture_repo/0, cleanup_fixture_repo/1]).

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
  list_to_binary(Work).

cleanup_fixture_repo(PathBin) ->
  Path = binary_to_list(PathBin),
  os:cmd("rm -rf " ++ quote(Path)),
  nil.

quote(Path) ->
  "'" ++ escape_sq(Path) ++ "'".

escape_sq(Path) ->
  re:replace(Path, "'", "'\\\\''", [global, {return, list}]).
