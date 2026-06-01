-module(git_exec_ffi).
-include_lib("kernel/include/file.hrl").
-export([init_bare/1, run_git/2, install_hook/2, install_pre_receive_hook/2, is_ancestor/3]).

init_bare(PathBin) when is_binary(PathBin) ->
  Path = binary_to_list(PathBin),
  case git_cmd:run(["init", "--bare", Path]) of
    {0, _, _} -> <<"ok">>;
    {_, Out, _} -> {<<"error">>, git_cmd:gleam_string(Out)}
  end.

install_hook(SrcBin, DestBin) ->
  install_pre_receive_hook(SrcBin, DestBin).

install_pre_receive_hook(SrcBin, DestBin) ->
  Src = binary_to_list(SrcBin),
  Dest = binary_to_list(DestBin),
  ok = filelib:ensure_dir(Dest),
  case file:copy(Src, Dest) of
    {ok, _} ->
      ok = file:write_file_info(Dest, #file_info{mode = 8#755}),
      <<"ok">>;
    {error, Reason} ->
      {<<"error">>, list_to_binary(io_lib:format("~p", [Reason]))}
  end.

is_ancestor(GitDirBin, OldBin, NewBin) ->
  GitDir = binary_to_list(GitDirBin),
  Old = binary_to_list(OldBin),
  New = binary_to_list(NewBin),
  case git_cmd:run_in(GitDir, ["merge-base", "--is-ancestor", Old, New]) of
    {0, _, _} -> <<"true">>;
    {1, _, _} -> <<"false">>;
    {_, _, _} -> <<"error">>
  end.

run_git(GitDirBin, ArgsBin) ->
  GitDir = binary_to_list(GitDirBin),
  Args = lists:map(fun arg_to_list/1, ArgsBin),
  case git_cmd:run_in(GitDir, Args) of
    {Exit, Stdout, _} ->
      {Exit, git_cmd:gleam_string(Stdout), <<>>}
  end.

arg_to_list(B) when is_binary(B) ->
  binary_to_list(B);
arg_to_list(L) when is_list(L) ->
  L.
