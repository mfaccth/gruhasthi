# Gruhasthi — Product Specification

**Status:** Android pilot release (last updated 21 July 2026)

**Tagline:** Automate away your daily grind.

## 1. Product summary

Gruhasthi is a voice-first Android household assistant for one person. It
keeps contacts, stores, grocery lists, and preferences locally on the phone.
The current pilot helps a person prepare grocery orders for neighbourhood
stores, hand a reviewed message to WhatsApp, and prepare a reviewed UPI payment
handoff. An iOS version remains a future objective.

The product is designed for English voice input. It no longer assumes a fixed
city: a person can enter their locality in Settings or allow the app to suggest
one from device location.

## 2. Product principles

1. **Voice first, touch always available.** Every core task can be completed
   manually, and voice results are visible before data changes.
2. **User-confirmed external actions.** Gruhasthi prepares WhatsApp and UPI
   handoffs; it does not send a WhatsApp message, enter a UPI PIN, or claim a
   payment succeeded.
3. **Local by default.** Household data and optional Gemma inference remain on
   the device. A network is used only for explicitly requested store discovery,
   model download, or a handoff to another app.
4. **Safe fallback.** The deterministic voice parser is used first. If it is
   unsure and the optional on-device assistant is installed, Gruhasthi tries it
   automatically and shows that it is working.
5. **Review before commitment.** Parsed contacts, store details, grocery items,
   WhatsApp messages, and payment drafts remain editable before the user saves
   or hands them off.

## 3. Supported Android pilot features

### Home and navigation

- Personalised, time-aware greeting using the saved user name.
- Current locality displayed at the top of Home.
- Press-and-hold microphone for English speech input; the live transcript wraps
  across multiple lines and survives natural recognition pauses.
- Navigation by touch or voice, for example, “Show me contacts” and “Open
  grocery lists.”
- A Help and app-tour entry point with category-specific voice examples.

### Contacts

- Add, edit, and store a contact locally with a name, phone number, and optional
  WhatsApp number.
- Voice-assisted addition from Home and Contacts, for example: “Add contact
  Vasu, phone number is 99801 01541.”
- Voice results open the contact editor with the raw transcription visible for
  review.

### Stores and locality

- Add, edit, and retain stores locally with name, address/area, and WhatsApp
  number.
- Voice-assisted store creation and voice updates to a saved store's WhatsApp
  number.
- Google Maps/Places store search when an Android-restricted Places API key is
  configured; the user reviews a discovered store before saving it.
- Seeded pilot stores: Village and Big Basket. Store numbers remain
  user-maintained and must be verified by the user.

### Grocery lists and WhatsApp ordering

- One active grocery list per saved store.
- Manual and voice addition of items, with units: count, dozen, kg, and litre.
- Flexible supported quantity wording includes `kilo`, `kilogram`, `half`, and
  phrases such as “one and a half kg.”
- Voice addition from Home, Grocery lists, or an individual store list.
- A voice item produces an editable Save/Cancel confirmation; manual entry
  remains available in the list editor.
- “Send Village list on WhatsApp” opens the list's WhatsApp review flow.
- Gruhasthi launches WhatsApp with a pre-filled message. On return, it asks the
  user whether to keep the list or mark it sent and clear it; it cannot observe
  whether WhatsApp's Send button was pressed.

### Payments

- Create a user-reviewed payment draft for a saved contact or store and open a
  compatible UPI application.
- This is a transparent external handoff only. Gruhasthi does not use a direct
  Google Pay merchant integration, handle bank credentials, or determine the
  payment result after the external app opens.

### Optional on-device assistant

- The built-in parser handles common command patterns without a model.
- The optional private on-device Gemma pilot assists with more flexible wording
  after the built-in parser cannot safely identify an action.
- Users can download and install either Gemma 4 E2B (recommended) or Gemma 4
  E4B from Settings. The model is verified before activation.
- The assistant is constrained to safe app commands and never bypasses user
  review.

## 4. Voice commands

Commands are English only for the pilot. A saved store name is needed where a
command names a store; `BigBasket` and `Big Basket` are treated equivalently.

| Intent | Example phrases |
|---|---|
| Navigate | “Show me contacts.” “Open stores.” “Open Village list.” |
| Add a contact | “Add contact Vasu, phone number is 99801 01541.” |
| Add a store | “Add store Daily Fresh.” |
| Update a store number | “Update the WhatsApp number for Big Basket to 99801 01541.” |
| Add grocery item | “Add half litre milk to Village list.” “Add one dozen eggs to Village.” |
| Send prepared order | “Send Village list on WhatsApp.” “Submit Big Basket list.” |

The app retains a raw transcript for review in relevant editors. The detailed
capture and de-duplication design is in
[Voice transcript capture design](docs/voice-transcript-capture-design.md).

## 5. Data and privacy

- Data is stored locally using the app's local preferences repository.
- There are no accounts, cloud sync, shared households, or automatic backups in
  this pilot.
- Contacts, store numbers, grocery lists, user name, locality, app-tour state,
  and selected Gemma model configuration are retained locally.
- A voice transcript is used to construct a proposed action and is displayed
  for review. The app does not send raw transcripts to Gruhasthi services.
- Google Places, WhatsApp, UPI apps, device location, and Gemma model download
  are optional integrations, each used only when the user initiates the related
  action.

## 6. User interface

- Warm pastel pink-to-light-yellow diagonal gradient across screens.
- Gruhasthi logo: a filled pastel-yellow house with a dark-pink microphone.
- Home keeps a centred press-and-hold microphone and four quick actions near
  the lower edge: Stores, Grocery lists, Contacts, and Pay.
- All key actions use visible labels as well as icons, and are designed with
  high-contrast dark-pink primary actions and white text.
- Back navigation uses a chevron plus the word **Back** on primary list and
  management screens.

## 7. Known boundaries and excluded features

- Gruhasthi cannot verify that an order was sent in WhatsApp or that a payment
  completed in a UPI app.
- Direct Google Pay India merchant API integration is not implemented and must
  be validated with an approved provider before any future implementation.
- Store discovery cannot prove that a store delivers. Users must confirm
  delivery availability and contact information.
- The Gemma pilot is optional, needs a separate download, and may be slow on
  lower-memory devices.
- Inventory, pricing, order/delivery tracking, recurring payments, cloud sync,
  multi-user sharing, and iOS delivery are not part of this Android pilot.

## 8. Release and operational notes

- Android package: `com.gruhasthi.gruhasthi`.
- A release APK can be produced with `flutter build apk --release`.
- Build prerequisites, signing instructions, API-key setup, model requirements,
  and direct APK installation instructions are maintained in [README](README.md).
- Follow-up engineering work is tracked in [TECH_DEBT.md](TECH_DEBT.md).
