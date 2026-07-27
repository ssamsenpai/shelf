# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.0.x   | Yes       |

## Reporting a Vulnerability

If you find a security issue in Shelf, please report it privately rather than
opening a public issue.

- Use GitHub's private vulnerability reporting on this repository
  (Security tab, "Report a vulnerability"), or
- Email moussaabcloud@gmail.com with the details.

Please include what you found, how to reproduce it, and what impact you think
it has. You will get a response within a few days. Once a fix ships, the issue
and the fix are disclosed in the release notes.

## Scope

Shelf is a sandboxed macOS app with no backend and no accounts. The areas most
worth scrutiny are the browser extension message handling, the shelf:// URL
scheme, link preview fetching, and the security scoped bookmark handling.
