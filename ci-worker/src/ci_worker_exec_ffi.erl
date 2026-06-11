-module(ci_worker_exec_ffi).
-export([
  temp_dir/0,
  temp_file/0,
  append_line/2,
  read_file/1,
  remove_path/1,
  file_exists/1,
  git_clone/2,
  git_checkout/2,
  start_dagger/5,
  process_alive/1,
  exit_code/1,
  kill_process/1,
  set_dagger_host/1
]).

-define(EXITS, ci_worker_dagger_exits).
-define(PORTS, ci_worker_dagger_ports).

temp_dir() ->
  Path =
    "/tmp/gleamhub-ci-"
    ++ integer_to_list(erlang:unique_integer([positive, monotonic])),
  ok = file:make_dir(Path),
  list_to_binary(Path).

temp_file() ->
  Path =
    "/tmp/gleamhub-ci-log-"
    ++ integer_to_list(erlang:unique_integer([positive, monotonic])),
  ok = file:write_file(Path, <<>>),
  list_to_binary(Path).

append_line(PathBin, LineBin) ->
  Path = as_binary(PathBin),
  Line = as_binary(LineBin),
  ok = file:write_file(Path, <<Line/binary, "\n">>, [append]),
  ok.

as_binary(Bin) when is_binary(Bin) -> Bin;
as_binary(List) when is_list(List) -> list_to_binary(List).

read_file(PathBin) ->
  case file:read_file(PathBin) of
    {ok, Bin} -> Bin;
    {error, _} -> <<>>
  end.

remove_path(PathBin) ->
  Path = binary_to_list(PathBin),
  case filelib:is_dir(Path) of
    true -> del_dir_r(Path);
    false ->
      case filelib:is_regular(Path) of
        true -> ok = file:delete(Path);
        false -> ok
      end
  end,
  ok.

del_dir_r(Dir) ->
  case file:list_dir(Dir) of
    {ok, Entries} ->
      lists:foreach(
        fun(Entry) ->
          Child = filename:join(Dir, Entry),
          case filelib:is_dir(Child) of
            true -> del_dir_r(Child);
            false -> ok = file:delete(Child)
          end
        end,
        Entries
      ),
      ok = file:del_dir(Dir);
    {error, enoent} ->
      ok;
    {error, Reason} ->
      error({remove_path_failed, Dir, Reason})
  end.

file_exists(PathBin) ->
  case file:read_file_info(PathBin) of
    {ok, _} -> true;
    {error, _} -> false
  end.

git_clone(BareBin, DestBin) ->
  Bare = binary_to_list(BareBin),
  Dest = binary_to_list(DestBin),
  case run_executable("git", ["clone", "--quiet", Bare, Dest]) of
    ok -> {ok, nil};
    {error, Msg} -> {error, Msg}
  end.

git_checkout(DirBin, ShaBin) ->
  Dir = binary_to_list(DirBin),
  Sha = binary_to_list(ShaBin),
  case run_executable("git", ["-C", Dir, "checkout", "--quiet", Sha]) of
    ok -> {ok, nil};
    {error, Msg} -> {error, Msg}
  end.

set_dagger_host(HostBin) ->
  os:putenv(
    "_EXPERIMENTAL_DAGGER_RUNNER_HOST",
    binary_to_list(HostBin)
  ),
  ok.

start_dagger(ModuleDirBin, EntryFnBin, SourceBin, LogPathBin, TimeoutSec) ->
  ensure_tables(),
  ModuleDir = binary_to_list(ModuleDirBin),
  EntryFn = binary_to_list(EntryFnBin),
  Source = binary_to_list(SourceBin),
  LogPath = binary_to_list(LogPathBin),
  Pid =
    spawn(fun() ->
      run_dagger_job(ModuleDir, EntryFn, Source, LogPath, TimeoutSec)
    end),
  {ok, Pid}.

run_dagger_job(ModuleDir, EntryFn, Source, LogPath, TimeoutSec) ->
  Self = self(),
  try
    case executable_path("dagger") of
      {error, Msg} ->
        record_exit(Self, undefined, 1),
        ok = file:write_file(LogPath, <<Msg/binary, "\n">>, [append]);
      {ok, Exe} ->
        Args = [
          "call",
          "--progress=plain",
          "-m",
          ModuleDir,
          EntryFn,
          "--source=" ++ Source
        ],
        Port = open_port({spawn_executable, Exe}, port_opts(Args)),
        true = ets:insert(?PORTS, {Self, Port}),
        {ok, LogFd} = file:open(LogPath, [write, append, raw, binary]),
        Code =
          collect_port_output(
            Port,
            LogFd,
            TimeoutSec * 1000
          ),
        ok = file:close(LogFd),
        record_exit(Self, Port, Code)
    end
  catch
    Class:Reason:Stack ->
      ErrorMsg =
        iolist_to_binary(
          io_lib:format(
            "CI worker internal error: ~p:~p~n~s",
            [Class, Reason, stack_to_string(Stack)]
          )
        ),
      ok = file:write_file(LogPath, ErrorMsg, [append]),
      record_exit(Self, undefined, 1)
  end.

record_exit(Self, Port, Code) ->
  case Port of
    undefined -> ok;
    _ -> catch port_close(Port)
  end,
  ets:delete(?PORTS, Self),
  true = ets:insert(?EXITS, {Self, Code}),
  ok.

process_alive(Pid) when is_pid(Pid) ->
  erlang:is_process_alive(Pid).

exit_code(Pid) when is_pid(Pid) ->
  case ets:lookup(?EXITS, Pid) of
    [{Pid, Code}] -> {ok, Code};
    [] -> {error, not_ready}
  end.

kill_process(Pid) when is_pid(Pid) ->
  case ets:lookup(?PORTS, Pid) of
    [{Pid, Port}] ->
      catch port_close(Port),
      ets:delete(?PORTS, Pid);
    [] ->
      ok
  end,
  case erlang:is_process_alive(Pid) of
    true -> exit(Pid, kill);
    false -> ok
  end,
  ok.

ensure_tables() ->
  ensure_table(?EXITS),
  ensure_table(?PORTS).

ensure_table(Name) ->
  case ets:info(Name) of
    undefined ->
      ets:new(Name, [set, public, named_table, {read_concurrency, true}]);
    _ ->
      ok
  end.

%% Default port wiring: stdin/stdout/stderr connected to this process.
port_opts(Args) ->
  [
    {args, Args},
    stderr_to_stdout,
    exit_status,
    binary,
    hide
  ].

run_executable(Name, Args) ->
  case executable_path(Name) of
    {error, Msg} ->
      {error, Msg};
    {ok, Exe} ->
      Port = open_port({spawn_executable, Exe}, port_opts(Args)),
      collect_output(Port, <<>>)
  end.

executable_path(Name) ->
  case os:find_executable(Name) of
    false ->
      {error,
        list_to_binary("executable not found: " ++ Name)};
    Path ->
      {ok, Path}
  end.

collect_output(Port, Acc) ->
  receive
    {Port, {data, Data}} ->
      collect_output(Port, <<Acc/binary, Data/binary>>);
    {Port, {exit_status, 0}} ->
      ok;
    {Port, {exit_status, _Code}} ->
      {error, Acc}
  end.

collect_port_output(Port, LogFd, TimeoutMs) ->
  receive
    {Port, {data, Data}} ->
      ok = file:write(LogFd, Data),
      collect_port_output(Port, LogFd, TimeoutMs);
    {Port, {exit_status, Code}} ->
      Code
  after TimeoutMs ->
    catch port_close(Port),
    124
  end.

stack_to_string(Stack) ->
  lists:flatten(
    [
      io_lib:format("  ~s:~p~n", [File, Line])
      || {_, File, Line, _} <- Stack
    ]
  ).
