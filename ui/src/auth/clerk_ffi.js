export function clerk_sign_out() {
  if (typeof window !== "undefined" && window.__clerkAuth?.signOut) {
    window.__clerkAuth.signOut();
  }
}

export function clerk_mount_user_profile(element_id) {
  if (typeof window === "undefined" || !window.__clerkAuth?.mountUserProfile) {
    return;
  }
  requestAnimationFrame(() => {
    const el = document.getElementById(element_id);
    if (el) {
      window.__clerkAuth.mountUserProfile(el);
    }
  });
}

export function clerk_unmount_user_profile(element_id) {
  if (typeof window === "undefined" || !window.__clerkAuth?.unmountUserProfile) {
    return;
  }
  const el = document.getElementById(element_id);
  if (el) {
    window.__clerkAuth.unmountUserProfile(el);
  }
}

export function clerk_set_auth_update_handler(callback) {
  if (typeof window !== "undefined") {
    window.__clerkAuthGleamUpdate = callback;
  }
}
