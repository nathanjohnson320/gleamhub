-module(db_test_ffi).
-export([start/0, stop/0, database_url/0, reset/1, fail/1, store_pool_name/1, pool_name/0]).

-define(PT_KEY, {gleamhub, db_test}).
-define(POOL_NAME_KEY, {gleamhub, db_test_pool}).

-define(URL,
  "postgres://postgres:postgres@127.0.0.1:5433/gleamhub_test?sslmode=disable"
).

start() ->
  case os:find_executable("docker") of
    false ->
      <<"docker not found in PATH">>;
    _ ->
      start_postgres()
  end.

start_postgres() ->
  Root = project_root(),
  Compose = compose_cmd(Root, "up -d --wait postgres"),
  case run_cmd(Compose) of
    {ok, _} ->
      case run_migrate(Root) of
        ok ->
          ok = persistent_term:put(?PT_KEY, true),
          <<"ok">>;
        {error, Msg} ->
          _ = stop_quiet(Root),
          list_to_binary(Msg)
      end;
    {error, Msg} ->
      list_to_binary(Msg)
  end.

stop() ->
  case persistent_term:get(?PT_KEY, false) of
    true ->
      persistent_term:erase(?PT_KEY),
      Root = project_root(),
      _ = stop_quiet(Root),
      <<"ok">>;
    false ->
      <<"skip">>
  end.

fail(MsgBin) ->
  erlang:error(MsgBin).

store_pool_name(Name) ->
  ok = persistent_term:put(?POOL_NAME_KEY, Name),
  ok.

pool_name() ->
  persistent_term:get(?POOL_NAME_KEY).

database_url() ->
  list_to_binary(?URL).

reset(_DbUrlBin) ->
  Sql =
    "TRUNCATE merge_request_comments, merge_requests, protected_branches, "
    "ssh_public_keys, repositories, organization_members, organizations, users "
    "CASCADE;",
  Root = project_root(),
  Cmd =
    compose_cmd(
      Root,
      "exec -T postgres psql -U postgres -d gleamhub_test -v ON_ERROR_STOP=1 -c "
      ++ quote(Sql)
    ),
  case run_cmd(Cmd) of
    {ok, _} -> <<"ok">>;
    {error, Msg} -> list_to_binary(Msg)
  end.

project_root() ->
  find_compose_root(filename:absname(".")).

find_compose_root(Dir) ->
  Compose = filename:join(Dir, "docker-compose.test.yml"),
  case filelib:is_file(Compose) of
    true ->
      Dir;
    false ->
      Parent = filename:dirname(Dir),
      case Parent =:= Dir of
        true -> filename:absname("..");
        false -> find_compose_root(Parent)
      end
  end.

compose_cmd(Root, Args) ->
  File = filename:join(Root, "docker-compose.test.yml"),
  "docker compose -p gleamhub-test -f "
  ++ quote(File)
  ++ " "
  ++ Args
  ++ " 2>&1".

run_migrate(Root) ->
  ServerDir = filename:join(Root, "server"),
  Cmd =
    "cd "
    ++ quote(ServerDir)
    ++ " && DATABASE_URL="
    ++ quote(?URL)
    ++ " DBMATE_MIGRATIONS_DIR=db/migrations npx --yes dbmate up 2>&1",
  case run_cmd(Cmd) of
    {ok, _} -> ok;
    {error, Msg} -> {error, Msg}
  end.

stop_quiet(Root) ->
  run_cmd(compose_cmd(Root, "down -v --remove-orphans")).

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

quote(S) ->
  "'" ++ escape_sq(S) ++ "'".

escape_sq(S) ->
  re:replace(S, "'", "'\\\\''", [global, {return, list}]).
