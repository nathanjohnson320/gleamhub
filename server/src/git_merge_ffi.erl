-module(git_merge_ffi).
-export([merge_branches/5]).

merge_branches(GitDirBin, TargetBin, SourceBin, MethodBin, MessageBin) ->
  GitDir = binary_to_list(GitDirBin),
  Target = binary_to_list(TargetBin),
  Source = binary_to_list(SourceBin),
  Method = binary_to_list(MethodBin),
  Message = binary_to_list(MessageBin),
  Wt =
    filename:join([
      os:getenv("TMPDIR", "/tmp"),
      "gleamhub_wt_" ++ integer_to_list(erlang:unique_integer([positive]))
    ]),
  MsgFile =
    filename:join([
      os:getenv("TMPDIR", "/tmp"),
      "gleamhub_msg_" ++ integer_to_list(erlang:unique_integer([positive]))
    ]),
  AddCmd =
    "git -C "
    ++ quote(GitDir)
    ++ " worktree add --detach "
    ++ quote(Wt)
    ++ " refs/heads/"
    ++ Target
    ++ " 2>&1",
  case os:cmd("sh -c " ++ quote(AddCmd)) of
    AddOut when is_list(AddOut) ->
      AddStr = lists:flatten(AddOut),
      case string:find(AddStr, "fatal:", trailing) of
        nomatch ->
          MergeCmd =
            case Method of
              "squash" ->
                ok = file:write_file(MsgFile, Message),
                "cd "
                ++ quote(Wt)
                ++ " && git merge --squash refs/heads/"
                ++ Source
                ++ " 2>&1 && cd "
                ++ quote(Wt)
                ++ " && git -c user.email=gleamhub@gleamhub.local -c user.name=Gleamhub commit -F "
                ++ quote(MsgFile)
                ++ " 2>&1";
              _ ->
                "cd "
                ++ quote(Wt)
                ++ " && git merge --no-edit refs/heads/"
                ++ Source
                ++ " 2>&1"
            end,
          MergeOut = os:cmd("sh -c " ++ quote(MergeCmd)),
          MergeStr = lists:flatten(MergeOut),
          _ = file:delete(MsgFile),
          case string:find(MergeStr, "CONFLICT", trailing) of
            nomatch ->
              ShaCmd = "cd " ++ quote(Wt) ++ " && git rev-parse HEAD 2>/dev/null",
              Sha = string:trim(os:cmd("sh -c " ++ quote(ShaCmd)), trailing, "\n"),
              _ = os:cmd(
                "git -C "
                ++ quote(GitDir)
                ++ " worktree remove -f "
                ++ quote(Wt)
                ++ " 2>/dev/null"
              ),
              UpdateCmd =
                "git -C "
                ++ quote(GitDir)
                ++ " update-ref refs/heads/"
                ++ Target
                ++ " "
                ++ Sha
                ++ " 2>&1",
              case os:cmd("sh -c " ++ quote(UpdateCmd)) of
                "" -> {<<"ok">>, list_to_binary(Sha)};
                Err -> {<<"error">>, list_to_binary(lists:flatten(Err))}
              end;
            _ ->
              _ = os:cmd(
                "git -C "
                ++ quote(GitDir)
                ++ " worktree remove -f "
                ++ quote(Wt)
                ++ " 2>/dev/null"
              ),
              {<<"conflict">>, list_to_binary(MergeStr)}
          end;
        _ -> {<<"error">>, list_to_binary(AddStr)}
      end
  end.

quote(Path) ->
  "'" ++ escape_sq(Path) ++ "'".

escape_sq(Path) ->
  re:replace(Path, "'", "'\\\\''", [global, {return, list}]).
