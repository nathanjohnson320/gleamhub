import lustre/effect

@external(javascript, "./clerk_ffi.js", "clerk_sign_out")
pub fn clerk_sign_out() -> Nil

@external(javascript, "./clerk_ffi.js", "clerk_mount_user_profile")
pub fn clerk_mount_user_profile(element_id: String) -> Nil

@external(javascript, "./clerk_ffi.js", "clerk_unmount_user_profile")
pub fn clerk_unmount_user_profile(element_id: String) -> Nil

@external(javascript, "./clerk_ffi.js", "clerk_set_auth_update_handler")
pub fn set_clerk_auth_update_handler(callback: fn(String) -> Nil) -> Nil

pub fn sign_out_effect() -> effect.Effect(msg) {
  effect.from(fn(_dispatch) {
    clerk_sign_out()
    Nil
  })
}

pub fn mount_user_profile_effect(element_id: String) -> effect.Effect(msg) {
  effect.from(fn(_dispatch) {
    clerk_mount_user_profile(element_id)
    Nil
  })
}

pub fn unmount_user_profile_effect(element_id: String) -> effect.Effect(msg) {
  effect.from(fn(_dispatch) {
    clerk_unmount_user_profile(element_id)
    Nil
  })
}
