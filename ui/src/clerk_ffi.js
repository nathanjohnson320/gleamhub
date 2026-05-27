export function clerk_sign_out() {
  if (typeof window !== "undefined" && window.__clerkAuth?.signOut) {
    window.__clerkAuth.signOut();
  }
}

export function clerk_open_account() {
  if (typeof window !== "undefined" && window.__clerkAuth?.openAccount) {
    window.__clerkAuth.openAccount();
  }
}

export function clerk_set_auth_update_handler(callback) {
  if (typeof window === "undefined") {
    return;
  }
  window.__clerkAuthGleamUpdate = callback;
}
