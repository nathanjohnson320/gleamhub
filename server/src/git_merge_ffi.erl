-module(git_merge_ffi).
-export([merge_branches/7]).

%% Concurrent merge_branches or merge-during-push can race on update-ref;
%% per-git_dir locking is deferred (see git_exec.gleam).

merge_branches(
  GitDirBin,
  TargetBin,
  SourceBin,
  MethodBin,
  MessageBin,
  AuthorNameBin,
  AuthorEmailBin
) ->
  GitDir = binary_to_list(GitDirBin),
  Target = binary_to_list(TargetBin),
  Source = binary_to_list(SourceBin),
  Method = binary_to_list(MethodBin),
  Message = binary_to_list(MessageBin),
  AuthorArgs = author_git_config(AuthorNameBin, AuthorEmailBin),
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
  try
    do_merge(GitDir, Target, Source, Method, Message, Wt, MsgFile, AuthorArgs)
  after
    _ = git_cmd:run_in(GitDir, ["worktree", "remove", "-f", Wt]),
    _ = file:delete(MsgFile)
  end.

author_git_config(NameBin, EmailBin) ->
  Name = binary_to_list(NameBin),
  Email = binary_to_list(EmailBin),
  ["-c", "user.name=" ++ Name, "-c", "user.email=" ++ Email].

do_merge(GitDir, Target, Source, Method, Message, Wt, MsgFile, AuthorArgs) ->
  TargetRef = "refs/heads/" ++ Target,
  SourceRef = "refs/heads/" ++ Source,
  case
    git_cmd:run_in(GitDir, ["worktree", "add", "--detach", Wt, TargetRef])
  of
    {0, _, _} ->
      case
        do_merge_in_wt(GitDir, Wt, TargetRef, SourceRef, Method, Message, MsgFile, AuthorArgs)
      of
        {ok, Sha} ->
          case git_cmd:run_in(GitDir, ["update-ref", TargetRef, Sha]) of
            {0, _, _} -> {<<"ok">>, list_to_binary(Sha)};
            {_, Out, _} -> {<<"error">>, git_cmd:gleam_string(Out)}
          end;
        {conflict, Out} ->
          {<<"conflict">>, git_cmd:gleam_string(Out)};
        {error, Out} ->
          {<<"error">>, git_cmd:gleam_string(Out)}
      end;
    {_, Out, _} ->
      {<<"error">>, git_cmd:gleam_string(Out)}
  end.

do_merge_in_wt(GitDir, Wt, TargetRef, SourceRef, Method, Message, MsgFile, AuthorArgs) ->
  case Method of
    "rebase" ->
      rebase_merge(GitDir, Wt, TargetRef, SourceRef);
    "squash" ->
      ok = file:write_file(MsgFile, Message),
      case git_cmd:run_in_wt(Wt, ["merge", "--squash", SourceRef]) of
        {0, _, _} ->
          case git_cmd:run_in_wt(Wt, AuthorArgs ++ ["commit", "-F", MsgFile]) of
            {0, _, _} -> rev_parse_head(Wt);
            {1, Out, _} -> {conflict, Out};
            {_, Out, _} -> {error, Out}
          end;
        {1, Out, _} -> {conflict, Out};
        {_, Out, _} -> {error, Out}
      end;
    _ ->
      case git_cmd:run_in_wt(Wt, AuthorArgs ++ ["merge", "--no-edit", SourceRef]) of
        {0, _, _} -> rev_parse_head(Wt);
        {1, Out, _} -> {conflict, Out};
        {_, Out, _} -> {error, Out}
      end
  end.

rev_parse_head(Wt) ->
  case git_cmd:run_in_wt(Wt, ["rev-parse", "HEAD"]) of
    {0, Out, _} ->
      Sha = string:trim(binary_to_list(Out), trailing, "\n"),
      {ok, Sha};
    {_, Out, _} ->
      {error, Out}
  end.

%% Rebase merge replays source commits onto the target tip inside a worktree.
%% Git refuses `git rebase` in a bare repository ("must be run in a work tree").
rebase_merge(GitDir, Wt, TargetRef, SourceRef) ->
  case git_cmd:run_in(GitDir, ["merge-base", TargetRef, SourceRef]) of
    {0, BaseOut, _} ->
      MergeBase = string:trim(binary_to_list(BaseOut), trailing, "\n"),
      case
        git_cmd:run_in_wt(Wt, ["rebase", "--onto", "HEAD", MergeBase, SourceRef])
      of
        {0, _, _} ->
          rev_parse_head(Wt);
        {1, Out, _} ->
          _ = git_cmd:run_in_wt(Wt, ["rebase", "--abort"]),
          {conflict, Out};
        {_, Out, _} ->
          _ = git_cmd:run_in_wt(Wt, ["rebase", "--abort"]),
          {error, Out}
      end;
    {_, Out, _} ->
      {error, Out}
  end.
