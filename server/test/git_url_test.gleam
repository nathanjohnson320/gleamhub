import git/url as git_url

pub fn clone_ssh_url_includes_non_default_port_test() {
  let assert "ssh://git@git.test.local:2222/acme/demo.git" =
    git_url.clone_ssh_url("git.test.local", 2222, "acme", "demo")
}

pub fn clone_ssh_url_omits_port_22_test() {
  let assert "ssh://git@git.example.com/acme/demo.git" =
    git_url.clone_ssh_url("git.example.com", 22, "acme", "demo")
}
