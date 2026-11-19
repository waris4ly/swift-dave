# Integrating with a Voice Library

Architecture guide for wiring DaveSession into a Discord gateway and voice connection.

## Overview

A Discord voice client consists of two communication channels:
1. **Voice Gateway (WebSocket)**: Controls signaling, transitions, MLS handshakes, and session descriptions.
2. **Voice UDP (RTP)**: Carries audio and video frames.

`DaveSession` acts as the cryptographic bridge between these two channels.

## Voice Gateway Event Mapping

When the voice gateway receives DAVE opcodes, forward their payloads to `DaveSession`:

| Gateway Opcode | Name | DaveSession API |
| :--- | :--- | :--- |
| `21` | Prepare Transition | ``DaveSession/prepareTransition(transitionID:protocolVersion:)`` |
| `22` | Execute Transition | ``DaveSession/executeTransition(transitionID:)`` |
| `24` | Prepare Epoch | ``DaveSession/prepareEpoch(_:protocolVersion:)`` |
| `25` | MLS External Sender | ``DaveSession/setExternalSender(_:)`` |
| `27` | Proposals | ``DaveSession/processProposals(_:)`` |
| `29` | Announce Commit Transition | ``DaveSession/announceCommitTransition(transitionID:commit:)`` |
| `30` | Welcome | ``DaveSession/processWelcome(transitionID:welcome:)`` |

### Outbound Gateway Messages

`DaveSession.outgoing` streams messages that must be delivered back to Discord:

| `DaveOutgoing` Case | Gateway Opcode | Description |
| :--- | :--- | :--- |
| `.keyPackage(data)` | `26` (Key Package) | Transmits client MLS key package. |
| `.commitAndWelcome(data)` | `28` (Commit and Welcome) | Transmits commit and welcome bundle. |
| `.readyForTransition(id)` | `23` (Ready for Transition) | Signals client is prepared for transition ID. |
| `.invalidCommitWelcome(id)` | `31` (Invalid Commit/Welcome) | Triggers group MLS recovery handshake. |

## User Management

Whenever users join or leave the voice channel:

```swift
// when user joins or is recognized
try await session.addUser(userID: remoteUserID)

// when user leaves the channel
try await session.removeUser(userID: remoteUserID)
```

## The Hold Rule

> Important: Never send plaintext audio or video frames while ``DaveSession/isReady`` is `false`.

While transitions occur (e.g. during initial group setup or when downgrading/upgrading protocols), `isReady` will report `false`. Attempting to call ``DaveSession/encrypt(frame:ssrc:)`` while unready throws ``DaveError/notReady``. Your audio queue must buffer or discard frames rather than emitting unencrypted bytes to UDP.
