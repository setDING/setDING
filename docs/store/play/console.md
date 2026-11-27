# Play Console answers

The answers for the forms in the Play Console (*Policy and programs → App
content* and *Grow users → Store presence*) of `app.setding` (ADR-0067, #1142),
derived from the app and the [privacy policy](https://setding.app/en/privacy/).
They describe the app as it is; **update this file and the form together**
when the app starts to collect other data, asks for a new permission or adds
ads, purchases or analytics. Status of 2026-11-27 (version 0.23.1).

## Store settings

| Field | Answer |
|---|---|
| App name | `setDING` |
| Default language | German (`de-DE`); English (`en-US`), French (`fr-FR`), Italian (`it-IT`), Spanish (`es-ES`) and Portuguese (`pt-PT`) as translations, texts in the folders next to this file |
| App or game | App |
| Free or paid | Free |
| Category | Music & Audio |
| Tags | Music, Productivity |
| Contact email | `info@setDING.app` |
| Website | `https://setding.app` |
| Privacy policy | `https://setding.app/en/privacy/` |

Screenshots exist in German and English only; Play shows the default
language's (German) for the other languages. Render them with
`make screenshots ONLY="^store "` ([store README](../README.md#screenshots)).

## App access

Most of the app works without an account (the local library). Bands, sets
shared with a band, invitations and sync need an account, and
`api.setding.app` only accepts sign-ups with an invitation
(`invite_only`, ADR-0024), so the reviewers need an account:

- Choose *All or some functionality is restricted*.
- Create a **review account** on `api.setding.app` with its own organization
  and a band with a few songs and a set (a founder invitation from
  `make server-founder-invite`), and give its email address and password with
  the instructions: *"Sign in under Settings → Account & sync. The
  organization 'Review' has a band with songs and a set; open the set and tap
  Play for the live mode."* Keep the account; the reviewers may come back with
  every update.

## Ads

No, the app contains no ads.

## Content rating (IARC questionnaire)

- Category: **All other app types** (not a game, not social media).
- Violence, sexuality, language, controlled substances, gambling: **No** to all.
- Users interact or exchange content: **Yes**, members of an organization share
  songs, sets, attachments and mistake reports with each other; only people
  who were invited see them, there is no public content and no chat.
- Shares the user's location: **No**.
- Digital purchases: **No**.
- Unrestricted internet access (a web browser): **No**; links open in the
  device's browser.

Expected rating: everyone (PEGI 3, USK 0) with the note *Users interact*.

## Target audience and content

- Target age groups: **18 and over** and **16–17** and **13–15**; not under 13.
  Bands at schools are included, but the app is not designed for children, and
  choosing an age under 13 brings in the Families policy (no account without
  parental consent rules, extra review).
- Appeals to children: **No**.

## Data safety

**Overview**

| Question | Answer |
|---|---|
| Does the app collect or share any of the required user data types? | Yes |
| Is all collected data encrypted in transit? | Yes (HTTPS to `api.setding.app`) |
| Which account creation methods? | Username (email address) and password |
| Can users request that their data is deleted? | Yes; delete account URL `https://setding.app/en/delete-account/` |
| Has the app been independently security reviewed? | No |

Without an account nothing leaves the device; the data below is only
collected after signing in, so every type is **optional** (users can choose).
Nothing is **shared** in Google's sense: hosting (Infomaniak), Cloudflare and
the mail provider (cyon) are service providers that process the data for
setDING. Nothing is processed ephemerally only; it is stored until the account
or the content is deleted.

**Data types** (collected, not shared, optional, purposes: *App
functionality* and *Account management*)

| Category | Type | What |
|---|---|---|
| Personal info | Name | First and last name, nickname; names of people without an account an admin adds to a lineup |
| Personal info | Email address | Of the account; optional email of people without an account |
| Personal info | User IDs | The account's internal ID |
| Files and docs | Files and docs | PDF attachments of songs; the screenshot of a mistake report |
| App activity | Other user-generated content | Songs, sets, arrangements, lineups, personal adjustments, annotations, settings, mistake reports |
| App activity | Other actions | Play history: which songs were played in past sets |

**Not collected:** location, contacts, photos and videos (the QR scanner
reads the camera image only on the device and keeps nothing), audio (no
microphone permission), calendar, messages, health, financial info, web
browsing, installed apps, device or other IDs (no advertising ID), crash logs
and diagnostics (the diagnostic log only leaves the device when the user
copies it), app performance data. The server logs (IP address, time,
request, app version; deleted after 7 days) are used for operation and
security only, not for location or identification, and are not declared as
a data type.

## Other declarations

| Declaration | Answer |
|---|---|
| News app | No |
| COVID-19 contact tracing or status | No |
| Government app | No |
| Financial features | None |
| Health features | None |
| Advertising ID | No, the app does not use it |
| Foreground services, exact alarms, accessibility, special permissions | None |

## App signing

*Test and release → App integrity → App signing*: the app signing key
certificate must be the release key of ADR-0021, SHA-256
`51:C6:E9:A5:0D:8F:3F:0B:51:0E:E0:D0:E5:DC:15:BB:85:85:FF:94:20:66:20:51:67:E5:16:93:15:1E:97:91`,
the fingerprint of the GitHub Release APKs and of `SETDING_ANDROID_CERT_SHA256`
(`https://api.setding.app/.well-known/assetlinks.json`, ADR-0065). If it differs,
Google generated its own key: Play and Obtainium installs would not update each
other and the App Links of Play installs would not verify; contact Play
support before the first production release.
