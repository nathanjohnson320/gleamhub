import lustre/effect

@external(javascript, "./clerk_ffi.js", "clerk_sign_out")
pub fn clerk_sign_out() -> Nil

@external(javascript, "./clerk_ffi.js", "clerk_open_account")
pub fn clerk_open_account() -> Nil

@external(javascript, "./clerk_ffi.js", "clerk_set_auth_update_handler")
pub fn set_clerk_auth_update_handler(callback: fn(String) -> Nil) -> Nil

pub fn sign_out_effect() -> effect.Effect(msg) {
  effect.from(fn(_dispatch) {
    clerk_sign_out()
    Nil
  })
}

pub fn open_account_effect() -> effect.Effect(msg) {
  effect.from(fn(_dispatch) {
    clerk_open_account()
    Nil
  })
}
