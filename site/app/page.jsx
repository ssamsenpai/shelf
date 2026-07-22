"use client";

function toggleTheme() {
  const root = document.documentElement;
  const next = root.dataset.theme === "dark" ? "light" : "dark";
  root.dataset.theme = next;
  try {
    localStorage.setItem("shelf-theme", next);
  } catch (e) {}
}

export default function Home() {
  return (
    <div className="page">
      <header className="header">
        <a className="wordmark" href="/">
          <img src="/icon.png" alt="" />
          Shelf
        </a>

        <nav className="nav">
          <a
            href="https://x.com/YOUR_HANDLE"
            aria-label="X"
            target="_blank"
            rel="noreferrer"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z" />
            </svg>
          </a>
          <a
            href="https://www.linkedin.com/in/YOUR_HANDLE"
            aria-label="LinkedIn"
            target="_blank"
            rel="noreferrer"
          >
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M20.45 20.45h-3.55v-5.57c0-1.33-.03-3.04-1.85-3.04-1.86 0-2.14 1.45-2.14 2.94v5.67H9.35V9h3.41v1.56h.05c.47-.9 1.63-1.85 3.36-1.85 3.6 0 4.27 2.37 4.27 5.46zM5.34 7.43a2.06 2.06 0 1 1 0-4.12 2.06 2.06 0 0 1 0 4.12M7.12 20.45H3.56V9h3.56zM22.22 0H1.77C.79 0 0 .77 0 1.72v20.55C0 23.23.79 24 1.77 24h20.45c.98 0 1.78-.77 1.78-1.73V1.72C24 .77 23.2 0 22.22 0" />
            </svg>
          </a>
          <button onClick={toggleTheme} aria-label="Switch appearance">
            <svg viewBox="0 0 24 24" aria-hidden="true">
              <path d="M12 3a9 9 0 1 0 9 9 7 7 0 0 1-9-9" />
            </svg>
          </button>
        </nav>
      </header>

      <main className="hero">
        <div className="stage">
          <div className="frame">
            <video src="/demo.mp4" poster="/poster.png" autoPlay muted loop playsInline />
          </div>
          <img className="appicon" src="/icon-large.png" alt="" />
        </div>

        <div className="copy">
          <h1 className="title">Shelf</h1>
          <p className="tagline">Your creative library, on your Mac.</p>
          <p className="sub">
            Images <img className="mini" src="/photos.png" alt="" />, fonts,
            links <img className="mini" src="/rainbow.png" alt="" />, palettes,
            and dev projects in one place. Everything stays on your
            machine <img className="mini" src="/device.png" alt="" />, and your
            files <img className="mini" src="/folder.png" alt="" /> are never
            copied.
          </p>
          <div className="actions">
            <a
              className="button"
              href="https://github.com/YOUR_HANDLE/shelf/releases"
            >
              Download for macOS
            </a>
          </div>
        </div>
      </main>
    </div>
  );
}
