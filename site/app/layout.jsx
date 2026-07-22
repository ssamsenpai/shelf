export const metadata = {
  title: "Shelf. Your creative library for Mac",
  description:
    "Images, fonts, links, palettes, and dev projects in one native macOS app. Local, fast, and files are never copied.",
};

import "./globals.css";

export default function RootLayout({ children }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              try {
                const saved = localStorage.getItem("shelf-theme");
                const system = matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
                document.documentElement.dataset.theme = saved || system;
              } catch (e) {}
            `,
          }}
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
