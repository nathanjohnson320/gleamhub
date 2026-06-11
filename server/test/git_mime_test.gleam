import git/mime

pub fn content_type_for_path_test() {
  let assert "text/plain; charset=utf-8" =
    mime.content_type_for_path("src/main.gleam")
  let assert "text/markdown; charset=utf-8" =
    mime.content_type_for_path("README.md")
  let assert "image/png" = mime.content_type_for_path("assets/logo.PNG")
  let assert "application/octet-stream" = mime.content_type_for_path("data.bin")
  let assert "text/plain; charset=utf-8" =
    mime.content_type_for_path(".dockerignore")
  let assert "text/plain; charset=utf-8" =
    mime.content_type_for_path("Dockerfile")
}

pub fn basename_test() {
  let assert "main.gleam" = mime.basename("src/main.gleam")
  let assert "README.md" = mime.basename("README.md")
}
