-module(git_exec_ffi).
-export([init_bare/1]).

init_bare(PathBin) when is_binary(PathBin) ->
  Path = binary_to_list(PathBin),
  Cmd = "git init --bare " ++ quote(Path),
  os:cmd(Cmd),
  nil.

quote(Path) ->
  "'" ++ escape_sq(Path) ++ "'".

escape_sq(Path) ->
  re:replace(Path, "'", "'\\\\''", [global, {return, list}]).
