import ci/log as ci_log
import gleeunit

pub fn main() {
  gleeunit.main()
}

pub fn carriage_return_keeps_final_segment_test() {
  let input = "old\rnew\rlatest"
  assert ci_log.ansi_to_html(input) == "latest"
}

pub fn carriage_return_per_line_test() {
  let input = "line1\rA\nprogress\rB done\nplain"
  assert ci_log.ansi_to_html(input) == "A\nB done\nplain"
}
