import gleam/string

pub type ParsedKey {
  ParsedKey(public_key: String, key_blob: String, fingerprint: String)
}

fn valid_kind(kind: String) -> Bool {
  case kind {
    "ssh-ed25519" -> True
    "ssh-rsa" -> True
    "ecdsa-sha2-nistp256" -> True
    "ecdsa-sha2-nistp384" -> True
    "ecdsa-sha2-nistp521" -> True
    _ -> string.starts_with(kind, "ecdsa-sha2-")
  }
}

pub fn parse(public_key: String) -> Result(ParsedKey, Nil) {
  let trimmed = string.trim(public_key)
  case string.split(trimmed, on: " ") {
    [kind, blob, ..] -> {
      case valid_kind(kind) {
        True ->
          Ok(ParsedKey(
            public_key: trimmed,
            key_blob: blob,
            fingerprint: "sha256:" <> blob,
          ))
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}
