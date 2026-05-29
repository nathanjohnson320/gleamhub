import db_test_support
import gleeunit

pub fn main() {
  db_test_support.require_db()
  gleeunit.main()
  db_test_support.stop()
}
