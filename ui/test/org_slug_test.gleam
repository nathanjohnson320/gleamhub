import gleeunit
import gleeunit/should
import pages/org_slug

pub fn main() {
  gleeunit.main()
}

pub fn slugify_display_name_test() {
  org_slug.slugify_display_name("Test Org") |> should.equal("test-org")
  org_slug.slugify_display_name("  My   Team!!  ") |> should.equal("my-team")
  org_slug.slugify_display_name("ACME_Corp") |> should.equal("acme_corp")
}

pub fn slugify_strips_invalid_test() {
  org_slug.slugify_display_name("foo@bar") |> should.equal("foobar")
}

pub fn sanitize_slug_input_test() {
  org_slug.sanitize_slug_input("Test Org") |> should.equal("testorg")
  org_slug.sanitize_slug_input("bad!!slug") |> should.equal("badslug")
  org_slug.sanitize_slug_input("ok-name_1") |> should.equal("ok-name_1")
}
