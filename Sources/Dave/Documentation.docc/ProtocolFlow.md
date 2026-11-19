# Protocol Flow

Lifecycle transitions, MLS group operations, and frame encryption mechanics.

## Overview

DAVE combines Messaging Layer Security (MLS, RFC 9420) with synchronized transition state machines across all channel participants.

## Join and Key Exchange Flow

1. **Gateway Handshake**:
   - The client advertises `max_dave_protocol_version` in its Voice Identify packet.
   - The Discord Voice Gateway returns `dave_protocol_version` in Session Description.
2. **Version Acknowledgment**:
   - The client invokes ``DaveSession/acknowledgeProtocolVersion(_:)``.
   - If version > 0, `DaveSession` emits `.keyPackage(...)` on `outgoing`.
   - The client transmits the key package via Opcode 26.
3. **External Sender**:
   - Discord sends Opcode 25 (External Sender package).
   - Handled via ``DaveSession/setExternalSender(_:)``.
4. **Transition Preparation**:
   - Discord announces proposals (Opcode 27) and/or commits (Opcode 29).
   - Once prepared, ``DaveSession`` yields `.readyForTransition(transitionID:)` (Opcode 23).
5. **Transition Execution**:
   - When all clients are ready, Discord sends Opcode 22 (Execute Transition).
   - The client calls ``DaveSession/executeTransition(transitionID:)``.
   - `DaveSession` activates the new key ratchet on encryptor and decryptors.

## Downgrade and Fallback

If Discord disables E2EE (protocol version 0):
1. `DaveSession.prepareTransition(transitionID:version: .disabled)` switches decryptors to passthrough.
2. `DaveSession.executeTransition` resets MLS state and turns on encryptor passthrough.
3. `isReady` remains `true` to allow unencrypted communication.

## Error Recovery

If a commit or welcome verification fails:
1. `DaveSession` emits `.invalidCommitWelcome(transitionID:)`.
2. The internal MLS session is automatically re-initialized.
3. A fresh `.keyPackage(...)` is emitted on `outgoing` to request a new group welcome.
