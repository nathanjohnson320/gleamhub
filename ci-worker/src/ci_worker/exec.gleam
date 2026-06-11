import gleam/erlang/process

@external(erlang, "ci_worker_exec_ffi", "temp_dir")
pub fn temp_dir() -> String

@external(erlang, "ci_worker_exec_ffi", "temp_file")
pub fn temp_file() -> String

@external(erlang, "ci_worker_exec_ffi", "append_line")
pub fn append_line(path: String, line: String) -> Nil

@external(erlang, "ci_worker_exec_ffi", "read_file")
pub fn read_file(path: String) -> String

@external(erlang, "ci_worker_exec_ffi", "remove_path")
pub fn remove_path(path: String) -> Nil

@external(erlang, "ci_worker_exec_ffi", "file_exists")
pub fn file_exists(path: String) -> Bool

@external(erlang, "ci_worker_exec_ffi", "git_clone")
pub fn git_clone(bare_repo: String, dest: String) -> Result(Nil, String)

@external(erlang, "ci_worker_exec_ffi", "git_checkout")
pub fn git_checkout(dir: String, sha: String) -> Result(Nil, String)

@external(erlang, "ci_worker_exec_ffi", "set_dagger_host")
pub fn set_dagger_host(host: String) -> Nil

@external(erlang, "ci_worker_exec_ffi", "start_dagger")
pub fn start_dagger(
  module_dir: String,
  entry_fn: String,
  source: String,
  log_path: String,
  timeout_sec: Int,
) -> Result(process.Pid, String)

@external(erlang, "ci_worker_exec_ffi", "process_alive")
pub fn process_alive(pid: process.Pid) -> Bool

@external(erlang, "ci_worker_exec_ffi", "exit_code")
pub fn exit_code(pid: process.Pid) -> Result(Int, NotReady)

@external(erlang, "ci_worker_exec_ffi", "kill_process")
pub fn kill_process(pid: process.Pid) -> Nil

pub type NotReady {
  NotReady
}
