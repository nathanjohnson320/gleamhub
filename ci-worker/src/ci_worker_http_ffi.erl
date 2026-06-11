-module(ci_worker_http_ffi).
-export([http_try/1]).

%% Gleam httpc maps some Erlang httpc failures via normalise_error/1, which throws
%% {unexpected_httpc_error, Reason} (e.g. socket_closed_remotely on long-poll).
%% Wrap dispatch so the coordinator can backoff instead of crashing.
http_try(Run) ->
  try
    case Run() of
      {ok, Ok} -> {ok, {ok, Ok}};
      {error, Err} -> {ok, {error, Err}}
    end
  catch
    error:{unexpected_httpc_error, Reason} ->
      {error, format_reason(Reason)};
    Class:Reason ->
      {error, format_crash(Class, Reason)}
  end.

format_reason(Reason) when is_atom(Reason) ->
  erlang:atom_to_binary(Reason);
format_reason(Reason) ->
  iolist_to_binary(io_lib:format("~p", [Reason])).

format_crash(Class, Reason) ->
  iolist_to_binary(io_lib:format("~p:~p", [Class, Reason])).
