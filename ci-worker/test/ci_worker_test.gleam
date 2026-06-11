import ci_worker/job
import gleeunit

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn job_decode_test() {
  let body =
    "{
      \"id\": \"run-1\",
      \"org_slug\": \"acme\",
      \"repo_name\": \"demo\",
      \"disk_path\": \"acme/demo.git\",
      \"commit_sha\": \"abc1234567890\",
      \"module_path\": \"ci\",
      \"entry_function\": \"ci\",
      \"merge_request_id\": \"mr-1\"
    }"

  let assert Ok(decoded) = job.decode(body)
  let assert "run-1" = decoded.id
  let assert "acme" = decoded.org_slug
  let assert "ci" = decoded.module_path
  let assert "abc1234" = job.short_sha(decoded.commit_sha)
}
