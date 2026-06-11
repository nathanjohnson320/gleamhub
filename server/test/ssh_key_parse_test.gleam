import git/ssh_key_parse
import gleam/string
import gleeunit

pub fn main() {
  gleeunit.main()
}

const ed25519_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKL2abstV7VnH5rElnPMPNO1F test@example.com"

const rsa_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC7 test@example.com"

pub fn parse_ed25519_test() {
  let assert Ok(parsed) = ssh_key_parse.parse(ed25519_key)
  let assert True = string.contains(parsed.public_key, "ssh-ed25519")
  let assert True = string.starts_with(parsed.fingerprint, "sha256:")
  let assert True = parsed.key_blob != ""
}

pub fn parse_rsa_test() {
  let assert Ok(parsed) = ssh_key_parse.parse(rsa_key)
  let assert True = string.contains(parsed.public_key, "ssh-rsa")
}

pub fn parse_trims_whitespace_test() {
  let assert Ok(parsed) = ssh_key_parse.parse("  " <> ed25519_key <> "  ")
  let assert False = string.starts_with(parsed.public_key, " ")
}

pub fn parse_rejects_unknown_kind_test() {
  let assert Error(Nil) = ssh_key_parse.parse("ssh-dss AAAA comment")
}

pub fn parse_rejects_missing_blob_test() {
  let assert Error(Nil) = ssh_key_parse.parse("ssh-ed25519")
  let assert Error(Nil) = ssh_key_parse.parse("")
}

pub fn parse_ecdsa_test() {
  let assert Ok(_) = ssh_key_parse.parse("ecdsa-sha2-nistp256 AAAA comment")
}

pub fn parse_ecdsa_custom_curve_test() {
  let assert Ok(parsed) = ssh_key_parse.parse("ecdsa-sha2-custom AAAA comment")
  let assert True = string.contains(parsed.public_key, "ecdsa-sha2-custom")
}

pub fn parse_ecdsa_nistp384_test() {
  let assert Ok(_) = ssh_key_parse.parse("ecdsa-sha2-nistp384 AAAA comment")
}
