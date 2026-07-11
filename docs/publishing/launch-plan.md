# Kalinka Player — user-acquisition launch plan

Drafted 2026-07-10 (day of app v0.3.0 / server v3.3.0). Goal: go from 1
external tester to a real early-user base. Nothing in this plan is
committed/published automatically — every step is executed by the
maintainer.

## Positioning (use everywhere)

- **Name:** always "Kalinka Player" (+ qualifier) in titles and copy —
  bare "Kalinka" loses every search to the Russian folk song. The
  domain `kalinkaplayer.com` is the search token to push.
- **One-liner:** *Open-source hi-fi system for Raspberry Pi —
  bit-perfect playback of the music you own, with fully local
  natural-language search.*
- **Lead with local/no-cloud, AI second.** The self-hosted community in
  2026 has acute AI fatigue (DB Tech's April 2026 "trust" article,
  awesome-selfhosted's LLM-PR ban, Lemmy's AI-tagging rules). "Fully
  local, ~285 MB model on your own server, works offline" is the
  credible frame; "AI-powered music app" is the kiss of death. The
  authenticity statement already drafted in `izzyondroid-request.md`
  (2+ years of pre-AI development, transparent AI-assisted commits) is
  the right template — reuse it whenever the question comes up.
- **Have answers ready for the three questions every hi-fi audience
  asks:** gapless playback (yes), bit-perfect output (yes, ALSA), and
  big-library behavior (get a real number: scan + embed time for a
  50–100k-track library on a Pi 4 before launch).
- **"How is this different from X":** prepare a short honest
  comparison vs Volumio, moOde, Navidrome, Lyrion/LMS, Roon
  (roughly: Volumio/moOde = Pi audio OS images, web UI, no semantic
  search; Navidrome = streaming server for remote listening, not a
  hi-fi endpoint; Roon = the closest UX benchmark but proprietary and
  $$$; Kalinka = headless player + native app remote + local AI
  search). Post it in the README and paste-ready for comments.
- **Honest limitations list** in every announcement (single maintainer,
  alpha, Android+Linux only for now, iOS/multi-room not yet, Qobuz
  plugin unofficial). Meelo's Show HN (156 pts) showed candor about
  gaps generates goodwill, not takedowns.

## Phase 0 — pre-launch fixes (this week)

Launch-blocking (P0):
1. **Root LICENSE files** — KalinkaPlayer (GPL-3.0-or-later) and
   kalinka-plugin-qobuz currently show "no license" on GitHub (the only
   LICENSE is nested in packages/). One-file fix, scares off exactly
   the FOSS crowd otherwise; aggregators key off GitHub's detected
   license.
2. **Screenshots** — 5 of 9 manual images + 3 of 6 fastlane images show
   the pre-0.3.0 UI; there is NO screenshot of the Discover screen
   (the flagship feature) anywhere. Retake: main-screen, queue,
   search-ai, search-ai-selected, server-sheet + add a Discover shot.
   Add real screenshots to the KalinkaAI README (currently none) and
   to kalinkaplayer.com (currently CSS mockups only).
3. **Community channel** — KalinkaAI Discussions is a 404;
   KalinkaPlayer's is enabled but empty. Pick ONE home (suggest
   KalinkaPlayer Discussions), seed a welcome/0.3.0 announcement post,
   link it from both READMEs and the site footer. Optionally a
   Discord/Matrix for interactive "no sound from my DAC" debugging.
4. **Videos** — see video plan below.
5. **Clean-machine install test** — fresh Raspberry Pi OS (trixie)
   flash + clean Ubuntu 24.04 VM, run the one-liner, time it, note
   every wart. Broken installs during the launch spike are the #1
   documented killer of small OSS launches. (The test run doubles as
   b-roll for the videos.)
6. **Commit the doc fixes** made 2026-07-10 (app-manual, initial-setup,
   README, fastlane full_description — currently uncommitted in the
   working tree).

Strongly recommended (P1):
7. KalinkaPlayer repo description → "Open-source music server for
   Linux/Raspberry Pi — bit-perfect playback, library indexing, AI mood
   search"; add topics `music-server`, `self-hosted`, `ai-search`.
   Also helps overwrite the stale Google snippet (old C++/Qobuz README).
8. Minimal CONTRIBUTING.md + SECURITY.md on both repos.
9. A canonical "What's new in 0.3.0" / changelog page on the site — the
   campaign needs one linkable URL that isn't a GitHub release.
10. "SOON" platforms (iOS/macOS/Windows): add a notify mechanism
    (watch-releases hint or newsletter) — "when iOS?" will be the top
    question everywhere.
13. **Android install path** — add an "Install with Obtainium" section to
    the README and stand up a self-hosted F-Droid repo (see Android
    distribution section). Replaces the now-dead IzzyOnDroid/F-Droid
    plan.
11. Privacy-friendly analytics on the site (Plausible/GoatCounter) +
    weekly snapshot of GitHub stars & release download counts
    (`gh api repos/.../releases`) so channel effects are measurable.
12. **Start account aging NOW:** Lemmy requires accounts ≥30 days old
    for promo posts (no exemptions); Reddit favors seasoned accounts —
    participate genuinely in r/selfhosted etc. for weeks before
    posting. Create a Fosstodon project account (selfh.st, F-Droid/Izzy
    maintainers all live there).

## Video plan

Two videos, different jobs:

**A. 60–90 s trailer (the campaign asset).** No talking head; captions +
music (Jamendo, attributed). Shot list: install one-liner in a terminal
(sped up) → app setup wizard (3–4 s per step) → Discover screen → type
"melancholic evening piano" → results appear → Add All → queue playing →
3-second phone-camera pan of the real Pi + DAC + amp rack. Host on
YouTube, embed on kalinkaplayer.com, link in README and every post. Also
export the 10-second search moment as a <10 MB GIF/webm loop for the
README and inline Reddit posts.

**B. 5–10 min setup tutorial (the educational video).** Mirrors
docs/initial-setup.md exactly: flash Pi OS → SSH in → run installer →
copy music over SFTP → app wizard → first AI search → server-settings
tour. Chaptered with timestamps. This is also the pitch asset for
YouTubers — it shows them the story arc for their own video.

Production (all free, Linux):
- Phone screen: `scrcpy --record` over USB — crisp, real device.
- Terminal: OBS Studio, or `vhs`/asciinema for scripted, reproducible
  terminal segments (re-recordable when the installer changes).
- Hardware b-roll: phone camera is fine.
- Edit: Kdenlive.
- **Voiceover: record your own voice for the tutorial.** With this
  audience in the current climate, an AI voiceover is a negative trust
  signal. Accent is a feature, not a bug — it reads as "real
  maintainer". The trailer needs no voice at all.

## Android distribution (revised — Izzy/F-Droid rejected)

IzzyOnDroid rejected Kalinka over the amount of AI-assisted development;
F-Droid.org is expected to reject on the same grounds (shared
philosophy/reviewers). Both are off the table. Google Play does **not**
have an anti-AI-development policy — but Kalinka's core audience
(self-hosters, privacy-minded) largely avoids Play anyway. So the plan
is to lean into the channels this audience actually uses, none of which
need store review or Play's tester requirement:

1. **Obtainium (primary).** Users install the maintainer's own signed
   APK straight from GitHub releases and get auto-update notifications —
   no store, no review, no AI policy, no testers. This is the standard
   FOSS/self-hosted distribution path in 2026. Action: add an
   "Install with Obtainium" section to the README with the repo URL
   (and an `apps.obtainium.imranr.dev/redirect?r=obtainium://...` config
   link / QR so it's one tap). Keep per-ABI release assets so Obtainium
   picks the right APK.
2. **Self-hosted F-Droid repo (secondary).** Run your own F-Droid
   repository (fdroidserver / repomaker); users add the URL to their
   F-Droid client and get auto-updates. This is exactly how IzzyOnDroid
   itself works — it sidesteps F-Droid.org/Izzy inclusion *and their AI
   policy* entirely, because nobody reviews your own repo. More setup
   than Obtainium, but gives the F-Droid-client crowd a native path and
   a credible "F-Droid repo" line for the README.
3. **Direct APK (baseline).** Already shipped on GitHub releases + the
   site. Keep it.
4. **Accrescent** — newer security-focused store; has a review step and
   is invite/curated. Optional, lower priority; check whether their
   policy objects before investing.

**Google Play — only if you specifically want mainstream reach.** The
closed-testing requirement is now **12 testers for 14 continuous days**
(reduced from 20 on 2024-12-11), and it applies only to *personal*
accounts created after 2023-11-13. **Organization accounts are exempt.**
So the legitimate way to skip the tester grind is an org Play account,
which needs a registered legal entity + a free DUNS number. See the
company analysis below. Play does not care about AI-assisted dev, so
it's actually open to Kalinka where Izzy/F-Droid are not — but it's a
lot of overhead to reach an audience that isn't there.

**Watch: Android Developer Verification.** Google is phasing in a rule
that even *sideloaded* apps on certified devices must come from a
verified developer — live in Brazil/Indonesia/Singapore/Thailand from
2026-09-30, expanding globally through 2027. Mitigations that keep
direct/Obtainium distribution alive: a **free hobbyist developer tier**
(limited devices, no government ID), an **"advanced flow"** letting users
install unverified apps at their own risk, and **ADB** always working.
Action: register as a verified developer (likely the free tier suffices)
before the rule reaches your users' regions — this is about developer
identity, not a paid Play account or a company.

### Company question — is it worth it?

**UK Ltd — worth it only for the Google Play org exemption, and only if
Play matters to you.** Incorporation is cheap (~£12–50 at Companies
House) but the ongoing load is real: annual confirmation statement,
annual accounts, a corporation-tax return even when nil, a business bank
account, and director's duties — realistically £0 DIY to a few hundred
£/yr with an accountant, plus your time. A DUNS number (free, up to ~30
days) is required for the org Play account regardless. Verdict: don't
form a company just to dodge 12 testers when the whole campaign is a
tester-recruitment exercise anyway. Form one only if you've decided you
want a permanent, credible Google Play presence for mainstream reach —
then the org account is the clean route and the exemption is a genuine
perk. For the self-hosted audience, Obtainium + own repo need no company
at all.

**Tax-free / offshore jurisdiction — no.** It solves a problem you don't
have and creates several you would:
- There is no revenue on a free app, so there is nothing to shelter.
- As a UK resident you remain personally UK-taxable, and a company you
  direct from the UK is UK-tax-resident anyway (central management &
  control), on top of Controlled-Foreign-Company rules — the structure
  doesn't legally avoid UK tax.
- Offshore incorporation costs far more (registered agent + annual fees,
  ~$1–2k+/yr), banking is hard, and compliance is heavier.
- Reputationally it's poison for a privacy/FOSS project — an offshore
  shell behind a "no cloud, no lock-in" app reads as exactly the kind of
  thing this audience distrusts.
- It buys nothing extra with Google (a UK Ltd already gets the org
  exemption); some jurisdictions add verification friction.
If real revenue ever appears (donations, a paid tier), revisit with a UK
accountant — a UK sole trader or Ltd is almost certainly the simplest
answer for a UK resident. Not now.

## Launch sequence

**Phase 1 — soft launch (T-2 weeks).** Friendly, low-traffic venues to
shake out install bugs before the big waves:
- **ASR: update the existing 2024 thread** ("Opening up DIY streaming
  solution", DIY Audio Forum) with a "two years later — here's what it
  became" post: 0.3.0, the app, local AI search, and a callback to
  phofman's S24_LE format point → the S32_LE fallback issue/fix.
  Thread continuity beats a cold post; ASR users own measurement-grade
  DACs and file excellent bugs.
- **diyAudio: start a long-lived dev thread** in PC Based Audio — the
  CamillaDSP model (190+ page dev thread) is the proven pattern for
  growing an audio-software user base on a forum. This becomes the
  permanent announcement/support channel for the audiophile side.
- **Raspberry Pi Forums** "Other projects" board: build-style post.
- **Lemmy !selfhosted@lemmy.world** (account must be 30 days old by
  now; comply with their AI-tagging rule visibly; FOSS projects are
  exempt from the 10% self-promo cap).
- **Android distribution — see the dedicated section below.** Ship an
  Obtainium install path + a self-hosted F-Droid repo. (IzzyOnDroid
  rejected the app over AI-assistance; F-Droid.org is expected to
  reject on the same grounds — both are off the table.)
- **awesome-selfhosted PR** — the server's first release (Sept 2024) is
  already past their 4-month bar; category "Media Streaming — Audio
  Streaming". Merge takes ≥1 week; LibHunt auto-syndicates from it.
  (Note: awesome-selfhosted bans LLM-generated *contributions* to the
  list; the project's own AI-assisted development is a separate matter,
  but keep the PR itself hand-written and the pitch honest.)
- **AlternativeTo + OpenAlternative listings** — register as
  alternative to Roon, Volumio, moOde, Plexamp, Navidrome. "open source
  Roon alternative" is the high-intent search to own.

**Phase 2 — main launch week.**
- **r/selfhosted post, Tue–Thu morning US:** "I built an open-source
  hi-fi system for Raspberry Pi — headless FLAC server + phone remote,
  with fully local natural-language search. No cloud, no accounts."
  2–4 screenshots + GIF, architecture line, honest limitations,
  comparison list, exact install command, author disclosure. Answer
  every comment for 24–48 h; hot-fix install issues same day.
- **selfh.st submission** (selfh.st/submit) same week for the Friday
  newsletter — the niche's paper of record; arguably worth more than a
  mid Reddit post.
- **Fosstodon announcement** (#selfhosted #foss #raspberrypi).
- r/opensource one-time post (cheap, license link required).

**Phase 3 — Show HN (1–2 weeks after Reddit, with its lessons fixed).**
- Title: `Show HN: Kalinka Player – open-source hi-fi system for
  Raspberry Pi with local AI music search`.
- Your prepared first comment: why you built it, architecture (server →
  ALSA/DAC; Flutter remote; CLAP embeddings computed on-server,
  offline), model size + Pi 4 latency numbers, what it doesn't do yet,
  demo video link, one-command install + direct APK (no signup).
- Timing: Tue–Thu 14:00–17:00 UTC, or Sunday (documented
  low-competition window that favors hobby projects). If it flops, the
  second-chance pool exists: email hn@ycombinator.com.
- Calibration: comparable music-server Show HNs — Meelo 156 pts, MStream
  162 pts, Snapcast+Pi write-up 215 pts, but the median is single
  digits. Front page ≈ 5k–30k visits + hundreds of stars; base case is
  5–30 points.

**Phase 4 — T+1 month, second wave:**
- r/raspberry_pi build write-up (hardware photos of Pi+DAC stack, not
  app screenshots — that's what the sub upvotes).
- r/musichoarder + r/DataHoarder ("for 1 TB+ FLAC libraries…" with real
  scan/embedding numbers).
- Audiophile Style: answer existing threads like "RPi Volumio
  alternatives for large libraries", then a project thread in the
  Software forum.
- r/flutterdev engineering-story post (recruits contributors).
- r/Qobuz (check sidebar; emphasize official streaming, not ripping).
- r/audiophile only via modmail pre-approval OR an organic setup-photo
  post where Kalinka appears in your rack.
- **Creator outreach, 8–10 pitches** (expect mostly silence; one hit ≈
  100+ stars): DB Tech (pitch transparency + commit history), Awesome
  Open Source / Brian McGonagill (takes suggestions; tutorial format),
  VirtualizationHowto (a single write-up drove Logtide's biggest spike),
  Techno Tim, TechHut, Hardware Haven, Christian Lempa, Jim's Garage.
  Offer a preconfigured Pi image / flashed SD card. Jeff Geerling:
  don't pitch; make the community bring it to him.

**Ongoing cadence:** announce major versions only (not point releases)
on Reddit/Lemmy; monthly update posts in the diyAudio/ASR/Audiophile
Style threads; selfh.st news submission whenever something genuinely
newsworthy ships; monthly Fosstodon updates.

## 90-day success metrics

- 150–300 GitHub stars across KalinkaAI + KalinkaPlayer (baseline: 2).
- 30–50 real installs (proxy: release download counts + install-script
  hits + Discussions activity).
- 5–10 recurring issue reporters / testers.
- 1 third-party video or blog write-up.
- Listed: awesome-selfhosted, AlternativeTo, selfh.st directory;
  Obtainium + self-hosted F-Droid repo live as install paths.

## Failure modes to avoid (documented in comparable launches)

- All channels on the same day — no time to fix bugs between waves.
- Install that breaks on a clean machine during the traffic spike.
- "AI" leading the headline for an AI-fatigued audience.
- Arguing with critics; unanswered "vs Navidrome/Volumio" questions.
- Posting every point release as if it were a launch.
- README/posts that smell LLM-generated (awesome-selfhosted bans them;
  DB Tech's audience is primed to look).

## Calibration data (what "good" looks like)

- Logtide (Jan 2026): 2 months → 223 stars, ~500 deployments; single
  best driver was one third-party blog write-up (120+ stars/day).
- Usertour: 1,200 stars in 3 months; progress posts on Reddit *before*
  Show HN made the HN post land.
- A good r/selfhosted post: 200–800 upvotes possible, 50–300 stars,
  dozens of testers.
