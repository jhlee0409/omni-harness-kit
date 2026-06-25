# Security Policy

## Supported versions

Harness Kit is pre-1.0; only the latest released version receives fixes.

## Reporting a vulnerability

**Do not open a public issue for a security vulnerability.**

Report privately via GitHub's [private vulnerability reporting](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
(the "Report a vulnerability" button under the repo's Security tab), or email the
maintainer at `jhlee0409@gmail.com`.

Please include: the affected component (skill / agent / hook / detection script),
reproduction steps, and the impact.

## What to expect

- Acknowledgement within a few days.
- Coordinated disclosure: we'll agree on a fix timeline before any public detail.

## Scope notes

This plugin ships shell hooks and a detection script that run on the user's
machine. The detection engine reads project config files **statically and never
executes them** — a deviation from that (executing target code) is a security
bug worth reporting.
