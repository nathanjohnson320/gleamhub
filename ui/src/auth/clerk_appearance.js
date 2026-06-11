import { neobrutalism } from "@clerk/ui/themes";

/** Mirrors gh-* tokens from ui/style.css @theme block. */
export const gleamhubTokens = {
  colorPrimary: "#78be20",
  colorPrimaryForeground: "#00205b",
  colorForeground: "#00205b",
  colorMutedForeground: "#3d5a80",
  colorBackground: "#ffffff",
  colorInput: "#ffffff",
  colorBorder: "#00205b",
  colorShadow: "#00205b",
  colorDanger: "#dc2626",
  borderRadius: "0",
};

export const clerkAppearance = {
  theme: neobrutalism,
  variables: gleamhubTokens,
  signIn: { variables: gleamhubTokens },
  userProfile: { variables: gleamhubTokens },
  elements: {
    rootBox: "w-full",
    card: "comic-panel shadow-none",
    formButtonPrimary:
      "comic-pop bg-gh-accent font-black uppercase tracking-wide text-gh-ink",
    formFieldInput: "comic-input",
    headerTitle: "font-black uppercase tracking-wide",
    socialButtonsBlockButton: "comic-pop",
    footerActionLink: "font-bold text-gh-muted hover:text-gh-ink",
  },
};
