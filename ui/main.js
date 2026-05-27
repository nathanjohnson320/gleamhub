import { Clerk } from "@clerk/clerk-js";
import hljs from "highlight.js/lib/common";
import "highlight.js/styles/github-dark.min.css";
import { marked } from "marked";
import { main } from "./src/ui.gleam";

globalThis.hljs = hljs;
globalThis.marked = marked;

marked.setOptions({
  highlight(code, lang) {
    if (lang && hljs.getLanguage(lang)) {
      return hljs.highlight(code, { language: lang }).value;
    }
    return hljs.highlightAuto(code).value;
  },
});

const publishableKey = import.meta.env.VITE_CLERK_PUBLISHABLE_KEY;

const clerk = publishableKey ? new Clerk(publishableKey) : null;

const signInMountProps = () => {
  const url = window.location.href;
  return {
    forceRedirectUrl: url,
    signUpForceRedirectUrl: url,
  };
};

function getInitials(user) {
  if (user.firstName && user.lastName) {
    return `${user.firstName[0]}${user.lastName[0]}`.toUpperCase();
  }
  if (user.firstName) return user.firstName.slice(0, 2).toUpperCase();
  if (user.primaryEmailAddress?.emailAddress) {
    return user.primaryEmailAddress.emailAddress[0].toUpperCase();
  }
  return "?";
}

function userToObject(user) {
  if (!user) return null;
  return {
    id: user.id,
    fullName: user.fullName ?? null,
    firstName: user.firstName ?? null,
    lastName: user.lastName ?? null,
    email: user.primaryEmailAddress?.emailAddress ?? null,
    imageUrl: user.imageUrl ?? null,
    initials: getInitials(user),
  };
}

function mountClerkSignIn(root) {
  root.innerHTML = `
    <div class="min-h-screen flex flex-col items-center justify-center p-4">
      <div class="w-full max-w-md" id="clerk-sign-in" aria-live="polite"></div>
    </div>
  `;
  const el = document.getElementById("clerk-sign-in");
  if (el) {
    clerk.mountSignIn(el, signInMountProps());
  }
}

async function init() {
  const app = document.getElementById("app");
  if (!clerk) {
    throw new Error("VITE_CLERK_PUBLISHABLE_KEY is required");
  }

  await clerk.load();
  const redirectUrl = window.location.origin + window.location.pathname;

  window.__clerkAuth = {
    signIn: () => {
      clerk.redirectToSignIn({
        signInForceRedirectUrl: window.location.href,
        signUpForceRedirectUrl: window.location.href,
      });
    },
    signOut: () => {
      clerk.signOut({ redirectUrl });
    },
    openAccount: () => {
      clerk.redirectToUserProfile();
    },
  };

  function userJsonForGleam(user, token) {
    if (!user) return "null";
    const payload = { ...user, token };
    return JSON.stringify(payload);
  }

  async function render() {
    const user = userToObject(clerk.user);
    if (!clerk.user) {
      if (!app.querySelector("#clerk-sign-in")) {
        mountClerkSignIn(app);
      }
      return;
    }

    const signInEl = app.querySelector("#clerk-sign-in");
    if (signInEl) {
      clerk.unmountSignIn(signInEl);
    }
    const token = await clerk.session.getToken();
    if (!token) {
      return;
    }
    app.innerHTML = `<div id="gleam-root"></div>`;
    const pathname = window.location.pathname || "/";
    main(
      pathname,
      "#gleam-root",
      userJsonForGleam(user, token),
      window.location.origin,
    );
  }

  await render();

  clerk.addListener(async () => {
    if (!clerk.user) {
      return;
    }
    const user = userToObject(clerk.user);
    const token = await clerk.session.getToken();
    if (!token) {
      return;
    }
    if (typeof window.__clerkAuthGleamUpdate === "function") {
      window.__clerkAuthGleamUpdate(userJsonForGleam(user, token));
    }
  });
}

init();
