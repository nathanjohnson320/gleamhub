-module(ci_worker_spawn_ffi).
-export([spawn_job/2]).

%% Spawn an unlinked worker process. If Job/0 throws, Cleanup/1 is invoked with
%% a crash reason string so Gleam can mark the pipeline failed.
spawn_job(Job, Cleanup) ->
  spawn(fun() ->
    try
      Job()
    catch
      Class:Reason:Stack ->
        Message =
          iolist_to_binary(
            io_lib:format("~p:~p~n~s", [Class, Reason, stack_to_string(Stack)])
          ),
        Cleanup(Message)
    end
  end),
  ok.

stack_to_string(Stack) ->
  lists:flatten(
    [
      io_lib:format("  ~s:~p~n", [File, Line])
      || {_, File, Line, _} <- Stack
    ]
  ).
