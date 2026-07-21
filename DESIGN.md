# Gruhasthi — Design and Delivery Plan

**Status:** Android pilot release; updated 21 July 2026.

> This document contains both the original delivery plan and the current
> implementation record. Where a planned item conflicts with the release-state
> section below, the release-state section is authoritative.

## Release-state summary

### Implemented in the Android pilot

- Flutter Android app for a single English-speaking user, with local
  persistence through a `HouseholdRepository` backed by SharedPreferences.
- Pastel pink-to-light-yellow visual system, Gruhasthi logo, Home menu, Help,
  and a guided app tour.
- User name and locality settings, including optional Android location-based
  locality suggestion.
- Touch and press-and-hold voice flows for contacts, stores, grocery lists,
  WhatsApp-number updates, and navigation.
- Shared transcript accumulator on Home, Contacts, and Grocery capture
  surfaces. It retains speech across pause-driven recognition restarts and
  replaces partial hypotheses rather than appending them. See
  [voice transcript capture design](docs/voice-transcript-capture-design.md).
- Deterministic command parsing for common commands, followed automatically by
  optional on-device Gemma fallback when a safe action cannot be identified.
- E2B/E4B on-device Gemma model selection, download, integrity validation, and
  activation. The model remains optional and local to the phone.
- Google Places-backed store discovery when the developer supplies a properly
  restricted Android API key.
- WhatsApp message review and handoff, followed by an explicit user choice to
  keep the list or mark it sent and clear it.
- UPI external handoff for a reviewed payment draft. No direct Google Pay API
  payment integration or payment-completion tracking exists.

### Deliberately not implemented

- Encrypted database, full activity history, export/delete data controls,
  contact-picker import, list reordering/check-off, cloud sync, multi-user
  collaboration, delivery/order tracking, and iOS support.
- Verification of WhatsApp delivery/sending or UPI payment completion.

### Active engineering follow-up

The model distribution work and related validation are tracked in
[TECH_DEBT.md](TECH_DEBT.md). Other future scope should be recorded there
before implementation rather than inferred from the original phase checklist.

## 1. Purpose

Household Automation is a voice-first mobile app for recurring household errands. It lets a user maintain a grocery list per neighbourhood store, prepare a WhatsApp message containing that list, and prepare a UPI payment for a saved store or contact.

The first release targets Android in India. It supports English and is designed
for one user per device. It was seeded with Village and Big Basket for the
Kundalahalli, Bengaluru pilot, but location is now user-configurable and is not
limited to Bengaluru. iOS follows from the same product and domain design.

## 2. Product principles

1. **Voice leads; touch remains dependable.** Every voice action has a transcript, an editable draft, and a touch alternative.
2. **Nothing consequential is automatic.** The app never sends a WhatsApp message or approves a payment itself.
3. **Local by default.** Household data lives on the device. External services are used only for a user-requested handoff or store search.
4. **Show the target before action.** Always show the store/contact, phone or UPI ID, content or amount, and the next external app.
5. **Keep routine work brief.** Common actions should take one spoken command followed by one confirmation.

## 3. Scope

### In scope for Android v1

- Voice and touch creation/editing of a grocery list for each saved store.
- Manually adding contacts and stores; optional device-contact picker.
- Searching for nearby stores that indicate delivery, then explicitly saving a result.
- WhatsApp handoff with a prefilled grocery-list message.
- Payment draft for a saved contact or store, followed by a user-confirmed external UPI/Google Pay handoff.
- Local activity history for drafts, message handoffs, and payment handoffs.
- Local export and deletion of user data.
- Seeded pilot stores: Village and Big Basket. Their delivery phone/WhatsApp number and UPI ID must be manually verified before a handoff is enabled.

### Explicitly out of scope for v1

- Automatic WhatsApp sending, automatic payment, UPI-PIN handling, or storage of banking credentials.
- Inventory, price comparison, order tracking, delivery tracking, recurring payments, shared households, cloud sync, and user accounts.
- Declaring a payment successful based only on returning from Google Pay.

## 4. Key feasibility decision: payments

Google Pay's documented India in-app payment integration is merchant-oriented and requires verification and payment-status handling. Before implementing any direct integration, validate whether the intended payment flow is permitted for both stores and personal contacts.

Until this validation is complete, v1 payment is designed as a **transparent external handoff**:

1. Resolve a saved recipient and their UPI ID.
2. Obtain a missing amount by voice or touch.
3. Display the payment summary and require confirmation.
4. Launch the approved external payment route.
5. Record only `handoff_started`, `cancelled`, or an independently verified result.

The payment layer must therefore be behind a `PaymentProvider` interface. The initial implementation may be a provider that opens an approved UPI/Google Pay route; it is not a promise that direct P2P Google Pay integration is available.

References:

- [Google Pay India Android overview](https://developers.google.com/pay/india/api/android/overview)
- [Google Pay India in-app payments](https://developers.google.com/pay/india/api/android/in-app-payments)

## 5. Users and primary jobs

| User | Job | Success outcome |
|---|---|---|
| Household organiser | Maintain a list for each preferred store | Items stay associated with the right store and are easy to send. |
| Shopper | Send an order to a store | The correct WhatsApp chat opens with a readable, editable list. |
| Payer | Pay a trusted store or contact | The correct recipient and amount are visible before Google Pay/UPI opens. |

## 6. User flows

### 6.1 Add grocery items by voice

1. User taps the microphone and says: “Add two milk and bread to Ramesh's list.”
2. App shows the transcript and parsed draft: store, items, quantities, and notes.
3. If the store is ambiguous or missing, app asks a single clarifying question and presents choices.
4. User confirms or edits; the list is saved locally.

### 6.2 Send a grocery list

1. User says: “Send my Ramesh list.”
2. App selects the saved store and shows a message preview.
3. User taps “Send on WhatsApp.”
4. WhatsApp opens with a prefilled message. The user chooses the chat and sends it inside WhatsApp.
5. App records `message_handoff_started`; it does not assume the message was sent.

Suggested message format:

```text
Hello Ramesh General Store,

Please send:
• Milk — 2 packets
• Bread — 1 loaf
• Tomatoes — 500 g

Thank you.
```

### 6.3 Find and save a store

1. User says: “Find grocery stores that deliver near me,” or opens Find Stores.
2. App requests location only for this search or accepts an entered neighbourhood.
3. Search provider results show name, approximate distance/address, delivery indicator/source, and contact details when available.
4. User taps “Add,” reviews prefilled fields, adds WhatsApp number and UPI ID if needed, then saves.

For the Kundalahalli pilot, Village and Big Basket are added as initial store records. The user must verify or enter the operational details needed for WhatsApp and payment; a store name alone never enables those actions.

### 6.4 Prepare a payment

1. User says: “Pay Meera five hundred rupees.”
2. App resolves Meera to a saved recipient and validates the stored UPI ID.
3. If no amount was spoken, app asks “How much would you like to pay?” and provides a keypad fallback.
4. App shows recipient, UPI ID, amount, optional note, and target payment app.
5. User taps “Continue to payment app,” then reviews and authorises there.

## 7. Information architecture and screens

| Screen | Primary content and actions |
|---|---|
| Onboarding | Purpose, local-data statement, language, optional permissions. |
| Voice home | Center microphone; Grocery lists, Pay, Stores, and Contacts in an arc above it. |
| Grocery lists | Store list cards, item count, ready/draft state, create list. |
| List editor | Add by voice/text; item, quantity, note, checked state; send action. |
| Send confirmation | Store, WhatsApp number, exact message preview, edit and Send on WhatsApp. |
| Stores | Saved stores; manual add and Find stores entry points. |
| Find stores | Location/neighbourhood search, results, source, Add action. |
| Store editor | Name, delivery phone/WhatsApp, UPI ID, address, notes. |
| Contacts | Saved contacts and add/edit. |
| Payment draft | Recipient, amount, UPI ID, note, edit actions. |
| Payment confirmation | Final summary, Continue to payment app, safety copy. |
| Activity/settings | Local action history, language, permissions, export/delete data. |

### Visual system

- Primary surfaces: pastel pink (`#FDE4E8`) and pastel light yellow (`#FFF4C8`).
- Background: warm near-white pink (`#FFF4F5`); dark charcoal-pink text for contrast.
- The microphone is the highest-emphasis control on Home.
- Use clear labels with icons; colour must never be the only indicator of action or state.
- Support 320dp width, large text, TalkBack labels, and a non-voice path for every task.

### Launch configuration

| Setting | Launch decision |
|---|---|
| Language | English only. Text and voice commands are designed for future localization. |
| Household model | Single user, local to one device. No sharing, accounts, or cloud sync. |
| Pilot geography | Kundalahalli, Bengaluru, India. |
| Initial stores | Village and Big Basket, manually seeded and verified before external handoffs are available. |

## 8. Voice interaction design

### Command categories

- `add_items`: “Add <items> to <store> list.”
- `send_list`: “Send my <store> list.”
- `find_store`: “Find grocery stores that deliver near me.”
- `add_store`: “Add a store called <name>.”
- `pay`: “Pay <recipient> <amount>.”
- `view_list`: “What's on my <store> list?”

### Rules

- Display the recognized transcript before any external handoff.
- Treat low-confidence store, contact, amount, or UPI-ID matches as unresolved.
- Ask only one clarification at a time; use visible choices.
- Never infer an amount, UPI ID, WhatsApp number, or recipient when more than one trusted match exists.
- Keep the original transcript locally only if the user enables voice history; otherwise discard it after parsing.

## 9. Data model

All IDs are UUIDs. Data is local to the device.

| Entity | Required fields | Notes |
|---|---|---|
| `Contact` | id, displayName, createdAt | Optional: phone, WhatsApp phone, UPI ID, label. |
| `Store` | id, name, createdAt | Optional: address, location, delivery phone, WhatsApp phone, UPI ID, search source, notes. |
| `GroceryList` | id, storeId, status, updatedAt | One active list per store in v1; history is retained when sent/cleared. |
| `ListItem` | id, listId, name, position | Optional: quantity, unit, note, checked. |
| `PaymentDraft` | id, recipientType, recipientId, state, createdAt | Amount and UPI ID required before handoff; stores no PIN or account data. |
| `Activity` | id, type, targetName, state, createdAt | Stores minimal local audit data, not sensitive payment credentials. |
| `SearchResult` | providerId, name, address | Temporary until the user saves it as a Store. |

## 10. Architecture

### Recommended stack

- **App:** Flutter for Android now and iOS later.
- **Native bridges:** Kotlin for Android; Swift for iOS.
- **State:** feature-scoped view models/controllers and immutable UI state.
- **Storage:** encrypted local SQLite database for household data; Android Keystore/iOS Keychain for encryption keys and sensitive settings.
- **Voice:** a `SpeechService` abstraction with Android/iOS implementations; graceful typed input fallback.

### Boundaries

```text
Presentation (Flutter screens)
        │
Application use cases (add items, send list, create payment draft)
        │
Domain models and repositories
        │
Local database     External-hand-off adapters     Search adapter
                    ├ WhatsAppProvider             └ StoreSearchProvider
                    └ PaymentProvider
```

External adapters must return explicit states such as `unavailable`, `handoff_started`, `cancelled`, and `unknown`. They must not fabricate completed outcomes.

## 11. Security, privacy, and reliability

- Ask for microphone, contacts, and location permissions contextually; each is optional.
- Avoid importing the entire device contact book. Use a contact picker and copy only the selected data.
- Encrypt sensitive fields at rest and prevent sensitive screens from appearing in Android's recent-apps preview where appropriate.
- Do not log full UPI IDs, phone numbers, grocery message content, or voice transcripts to analytics/crash reporting.
- Validate phone numbers and UPI IDs before displaying a send/pay action.
- Require explicit confirmation before every WhatsApp or payment handoff.
- Offer local export and permanent deletion with a clear confirmation.
- Provide recovery states for missing WhatsApp, missing payment app, offline search, denied permissions, and ambiguous voice matches.

## 12. Non-functional requirements

- Home screen ready in under 1.5 seconds on a supported mid-range Android device.
- Local list edits persist immediately and work offline.
- Voice parsing feedback appears within 2 seconds after speech recognition returns.
- All business logic is unit-testable without a device or external app.
- Android support baseline and iOS support baseline will be selected during Phase 0.

## 13. Phased implementation tasks

### Phase 0 — Decisions and technical spikes

**Outcome:** validate risky integrations before building dependent product work.

- [ ] Choose Flutter and create an architecture decision record.
- [ ] Confirm payment product model with Google Pay/PSP/bank and compliance counsel: merchant only, personal contact route, allowed intent/deep-link behaviour, and status verification.
- [ ] Prototype WhatsApp prefilled-message handoff on representative Android devices.
- [ ] Select and cost a store-search provider; verify data usage, delivery-signal quality, location requirements, and attribution obligations.
- [ ] Create the Kundalahalli pilot fixture: Village and Big Basket store records, then verify their delivery number/WhatsApp contact and permitted payment details with the stores.
- [ ] Prototype contacts picker, speech recognition, encrypted database, and external-app return handling.
- [ ] Define supported languages and the first release's speech-recognition behaviour.
- [ ] Create a device matrix, including Google Pay/WhatsApp absent or outdated scenarios.

**Exit criteria:** approved payment route, selected store-search provider, and proof-of-concept handoffs work on physical Android devices.

### Phase 1 — App foundation and local data

**Outcome:** usable offline shell with secure local data.

- [ ] Create Flutter project, flavour configuration, linting, formatting, and CI checks.
- [ ] Implement design tokens, responsive layout, accessible components, and the voice-home shell.
- [ ] Create encrypted local database and migrations for contacts, stores, lists, items, drafts, and activity.
- [ ] Implement repository interfaces and fake implementations for tests.
- [ ] Build onboarding, permission education, settings, local export, and local deletion.
- [ ] Add unit tests for models, migrations, repositories, and deletion/export.

**Exit criteria:** a user can create, edit, export, and delete local data offline.

### Phase 2 — Contacts, stores, and grocery lists

**Outcome:** all core household data can be managed by touch.

- [ ] Build contact list, add/edit/delete, UPI-ID validation, and optional contact-picker import.
- [ ] Build store list, manual store editor, delivery/WhatsApp and UPI fields.
- [ ] Integrate store search behind `StoreSearchProvider`; build review-before-save flow.
- [ ] Build grocery list overview, list editor, reorder, check-off, archive/clear, and one-active-list-per-store rule.
- [ ] Add empty, error, duplicate, and missing-contact-detail states.
- [ ] Write widget and integration tests for CRUD flows.

**Exit criteria:** a user can complete every list/store/contact task without voice or external apps.

### Phase 3 — Voice-first interaction

**Outcome:** primary flows are fast and understandable by voice.

- [ ] Implement `SpeechService`, tap-to-speak states, transcript UI, typed fallback, and permission recovery.
- [ ] Implement deterministic command parser for the six v1 command categories.
- [ ] Add contact/store matching, confidence thresholds, ambiguity choices, and missing-amount prompts.
- [ ] Add voice confirmation summaries; route parsed drafts to the existing touch editors.
- [ ] Test noisy input, accents, partial recognition, cancellation, and unsupported commands.

**Exit criteria:** users can create/list/send grocery drafts and create payment drafts from voice commands without unsafe guessing.

### Phase 4 — WhatsApp grocery handoff

**Outcome:** users can safely move a grocery list into WhatsApp.

- [ ] Build message formatter with item quantities/notes and safe text escaping.
- [ ] Implement `WhatsAppProvider` and capability checks.
- [ ] Build send-confirmation screen with recipient, number, full message, edit, and handoff action.
- [ ] Record local activity as `handoff_started`; implement return-to-app behaviour.
- [ ] Test WhatsApp installed/not installed, no number, malformed number, long lists, and user cancellation.

**Exit criteria:** a physical-device test opens WhatsApp with an accurate, user-reviewed draft for every saved store.

### Phase 5 — Payment handoff

**Prerequisite:** Phase 0 payment route approved in writing.

- [ ] Implement the approved `PaymentProvider` behind a feature flag.
- [ ] Implement payment draft, recipient validation, amount capture, UPI-ID confirmation, and payment note.
- [ ] Implement the final confirmation screen and external-app availability/error handling.
- [ ] Generate and persist a unique local reference for each initiated draft where permitted.
- [ ] Implement callback/status handling only when it is supported and independently verifiable; otherwise retain `unknown` after handoff.
- [ ] Security review, physical-device testing, and payment-provider acceptance testing.

**Exit criteria:** all payment handoffs require explicit confirmation, never expose PINs, and never claim false success.

### Phase 6 — Quality, release, and learning

**Outcome:** safe Android pilot release.

- [ ] Complete accessibility audit: TalkBack, large text, contrast, touch target, voice-disabled use.
- [ ] Complete privacy review, retention review, local-data threat model, and permission rationale review.
- [ ] Add crash reporting with field redaction and opt-in product analytics.
- [ ] Run usability tests focused on older and first-time voice users.
- [ ] Prepare Play Store listing, privacy policy, support flows, pilot feedback channel, and rollback plan.
- [ ] Release to a limited Android pilot; measure completion, clarification, cancellation, and handoff-failure rates.

**Exit criteria:** pilot release meets usability, stability, privacy, and payment-safety thresholds.

### Phase 7 — iOS release

**Outcome:** equivalent core experience on iOS.

- [ ] Implement Swift adapters for contacts, speech, secure storage, WhatsApp handoff, and approved payment route.
- [ ] Validate iOS deep-link/return behaviour and payment-provider support on physical devices.
- [ ] Adapt permissions, privacy text, and App Store submission materials.
- [ ] Execute parity test suite for lists, voice fallback, contacts, stores, and external handoffs.

## 14. Delivery sequencing

```text
Phase 0 ──┬── Phase 1 ── Phase 2 ── Phase 3 ── Phase 4 ── Phase 6
          └────────────────────────── Phase 5 ────────────┘
                             (only after payment approval)

Phase 7 begins after Android core flows are stable.
```

## 15. Success measures for the Android pilot

- At least 80% of test users complete a grocery-list WhatsApp handoff without assistance.
- At least 70% of voice commands resolve without a clarification prompt after onboarding.
- Zero confirmed cases of a message/payment being handed off to a recipient other than the one shown in confirmation.
- No raw UPI PIN, bank credential, full voice transcript, or full contact list leaves the device through analytics or logging.

## 16. Open decisions

1. Which store-search provider will serve Kundalahalli, and what delivery data can it reliably provide?
2. What verified WhatsApp contact and permitted payment details should be used for Village and Big Basket?
3. Which payment route is explicitly approved for store and personal-contact use?
4. Is local-only backup sufficient, or is encrypted user-controlled backup required after v1?
