# Voice Transcript Capture Design

**Status:** Implemented  
**Scope:** Android speech capture on Home, Contacts, and Grocery List screens  
**Last updated:** 21 July 2026

## Purpose

Gruhasthi uses press-and-hold speech input for common household actions. Android speech recognition returns *partial hypotheses* while a person is talking and may stop a recognition session during a natural pause. This design keeps the user’s complete spoken request intact across those events, while avoiding duplicated words and partially repeated phone numbers.

The design supports commands such as:

- “Please add a new contact; phone number is 99801 01541; name is Vasu.”
- “Add half kg potato, to Big Basket list.”
- “Show me contacts.”

## Problem addressed

Speech recognizers commonly send a progression of revisions for the same phrase:

```text
phone number is 99
phone number is 9980
phone number is 99801 01541
```

Appending every callback produces an incorrect transcript such as:

```text
phone number is 99 phone number is 9980 phone number is 99801 01541
```

Natural pauses create a second concern: Android can end one recognition session while the user is still holding the microphone. If the app clears the visible text or starts a new transcript, the first portion of the request is lost.

## Design principles

1. A partial result is a replacement for the current phrase, not a new phrase to append.
2. A completed phrase is retained permanently for the current press-and-hold interaction.
3. A pause while the microphone remains held starts a new recognition session without losing the completed phrase.
4. Repeated final callbacks and overlapping phrases are merged defensively.
5. The raw transcript is retained in the destination editor for user review and correction.
6. Parsed actions remain user-confirmed before saving, sending, or paying.

## State model

Each capture surface maintains three transcript values.

| State | Meaning | Lifetime |
|---|---|---|
| `completedTranscript` | Phrases committed by a final recognizer result, a pause, or microphone release. | Entire press-and-hold request |
| `currentPartialTranscript` | The latest live hypothesis for the phrase currently being recognized. | Current recognizer session only |
| `visibleTranscript` | `merge(completedTranscript, currentPartialTranscript)` shown to the person speaking. | Entire press-and-hold request |

The app also records `lastFinalSegment` to ignore a duplicate final callback for the same phrase.

## Capture lifecycle

```mermaid
sequenceDiagram
    participant U as User
    participant UI as Capture screen
    participant STT as Android speech recognizer

    U->>UI: Press and hold microphone
    UI->>STT: Start listening; clear transcript state
    STT-->>UI: Partial result
    UI->>UI: Replace currentPartialTranscript
    UI->>U: Show completed + current partial
    STT-->>UI: Final result or session pause
    UI->>UI: Commit current phrase to completedTranscript
    alt User still holding after a pause
        UI->>STT: Start another recognition session
    else User releases microphone
        UI->>STT: Stop listening
        UI->>UI: Wait briefly for trailing final callback
        UI->>UI: Parse completed transcript and continue
    end
```

### Detailed rules

1. **Press** — reset completed, partial, and final-segment state; initialise Android speech recognition.
2. **Partial callback** — replace `currentPartialTranscript` with the recognizer’s latest `recognizedWords`. Do not append it.
3. **Final callback** — merge the final phrase into `completedTranscript`, clear `currentPartialTranscript`, and record the final phrase.
4. **Recognizer stops during a pause** — commit any current partial phrase before restarting recognition if the microphone is still held.
5. **Release** — commit the current partial phrase, call `stop()`, and wait briefly for a trailing final callback before interpreting the transcript.
6. **Display** — always show the merged completed and current text; multiline transcript areas scroll to the newest line while capturing.

## Transcript merging and de-duplication

The merge function is conservative and preserves the original words whenever possible.

It handles:

- an unchanged result;
- an incoming phrase already contained in the existing transcript;
- a longer revision that contains the existing phrase;
- word-boundary suffix/prefix overlap between consecutive recognizer sessions; and
- duplicate final-result callbacks.

The result is a single readable request rather than a history of recognizer revisions.

## Phone number handling

Android can split spoken digits across recognizer sessions, for example:

```text
phone number is 99801 0154
phone number is 99801 541
```

The contact parser:

1. normalises spoken digits and number words;
2. searches for 10-digit Indian mobile-number candidates beginning with 6–9;
3. prefers a complete valid candidate; and
4. repairs a nine-digit prefix only when a later related fragment has the same first five digits and supplies the missing final digit.

For the example above, the result is `9980101541`. The person can always edit the number in the Add Contact form before saving.

## Where this is implemented

| Surface | Capture implementation | Result handling |
|---|---|---|
| Home | `lib/features/home/home_screen.dart` | Routes to contacts, grocery, stores, pay, or navigation; invokes on-device assistance when needed. |
| Contacts | `lib/features/contacts/contacts_screen.dart` | Opens Add Contact with parsed values and the raw transcript. |
| Grocery Lists | `lib/features/grocery/grocery_lists_screen.dart` | Interprets an item/store request or opens a store-specific review dialog. |
| Parsing helpers | `lib/features/voice/voice_command_sheet.dart` | Normalises speech, parses contacts and grocery quantities, and extracts phone candidates. |

## Failure and fallback behavior

- The built-in rule-based parser is used first for fast, offline common phrases.
- If a supported request cannot be identified and an on-device model is installed, Gruhasthi can use the selected on-device assistant as a private fallback.
- If neither parser can safely identify an action, the app shows a clear recovery path: retry, add manually, set up the assistant in Settings, or view the relevant category in Help.
- No action that creates a contact, adds an item, sends a list, or starts a payment is completed without a visible review or confirmation point.

## Validation scenarios

The automated test suite covers command parsing, quantity units, flexible store names, navigation, contact-name cleanup, number-word parsing, and repair of a split contact number.

Manual device checks should cover:

1. Speak a contact request with a pause before the name.
2. Speak `99801 01541` with spaces between digit groups.
3. Speak a grocery request with a pause before the store name.
4. Hold through a natural pause and continue speaking; confirm the first phrase remains visible.
5. Release immediately after speaking; confirm the trailing words remain in the review/editor transcript.
6. Confirm that no expanding partial phrases appear as duplicated text.

## Known limitations and future improvements

- Speech-recognition accuracy and pause timing are provided by Android and vary by device, microphone, language pack, and network/recognition service configuration.
- The initial release targets English and Indian mobile-number patterns.
- The short post-release wait is a practical allowance for Android’s trailing final callback; it may later be replaced with a recognizer-completion signal where reliably available.
- A future diagnostic mode could save anonymised recognizer event sequences locally, with explicit user consent, to improve device-specific troubleshooting.

