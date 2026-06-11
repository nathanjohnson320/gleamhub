import gleam/list
import gleeunit
import http/clerk_jwks
import ywt/verify_key

pub fn main() {
  gleeunit.main()
}

const sample_jwks = "{\"keys\":[{\"use\":\"sig\",\"kty\":\"RSA\",\"kid\":\"ins_3EJGbyfrpXRj7rlnENFJxWiR492\",\"alg\":\"RS256\",\"n\":\"y_U-YsT_SIBcFaOKJ8ndjPt4An-oqZwfvMB9iNljkifr9x6Fkt2hyVer9t9nP3Ew4ku-sOIcyWnkB2jh0ppaO2tK-ctHBzYWUOf3xholPBMLj82V4Pw6oSbjzVwcfppygFGh6z-fg_C9HC_vLVHQAExcQF8HjIvqYwT0GO_akWKfeWp-KJcEAwrxJtlpANVkgGGXtth6Fw2ocz3zWkm2JBVqTuNgaB9E9NlLybP0yeoOMjXWtksKMH2qDywAlT68diZT4iOPsRHleQ7Cku8vnTvkgbgUHeB8IdEggINaRCUteLKGOgriRLHvNTU3WeNThOMUfGDVkY819W2lGSxxpQ\",\"e\":\"AQAB\"}]}"

pub fn decode_clerk_jwks_test() {
  let assert Ok(keys) = clerk_jwks.decode_jwks(sample_jwks)
  let assert 1 = list.length(keys)
  let assert Ok(key) = list.first(keys)
  let assert Ok("ins_3EJGbyfrpXRj7rlnENFJxWiR492") = verify_key.id(key)
}

pub fn decode_clerk_jwks_rejects_empty_key_set_test() {
  let assert Error(clerk_jwks.EmptyKeySet) =
    clerk_jwks.decode_jwks("{\"keys\":[]}")
}
