# Discord Voice Integration Guide

This guide describes how to integrate `swift-dave` into a Swift Discord voice client or library, from voice gateway signaling to the media UDP pipeline.

---

## 1. Gateway Signaling Integration (WebSocket)

Discord Voice Gateway (v8) uses JSON for general voice signaling and binary frames for DAVE protocol payloads.

### Identify & Protocol Negotiation

1. **Voice Identify**:
   When sending opcode 0 (`Identify`), include your maximum supported DAVE protocol version:
   ```json
   {
     "op": 0,
     "d": {
       "server_id": "987654321098765432",
       "user_id": "123456789012345678",
       "session_id": "your_session_id",
       "token": "your_token",
       "max_dave_protocol_version": 1
     }
   }
   ```
   Always query `DaveSession.maxSupportedProtocolVersion.rawValue` to supply this value.

2. **Session Description**:
   Discord returns opcode 4 (`Session Description`), which contains `dave_protocol_version`.
   - Pass this version to `await session.acknowledgeProtocolVersion(version)`.
   - If version is `0`, DAVE is disabled for this channel; `DaveSession` automatically switches to unencrypted passthrough mode.
   - If version is `> 0`, `DaveSession` initializes the MLS session and yields `.keyPackage(...)` on `session.outgoing`.

### Binary Frame Protocol Format

For DAVE binary opcodes:
- **Server $\to$ Client frames**:
  `[sequence_number: UInt16 (big-endian)] [opcode: UInt8] [payload: bytes...]`
  *(Strip the 2-byte sequence number and 1-byte opcode before passing the payload to `DaveSession`).*
- **Client $\to$ Server frames**:
  `[opcode: UInt8] [payload: bytes...]`
  *(Prepend the 1-byte opcode to the data emitted by `session.outgoing`).*

### Opcode Mapping Table

| Opcode | Name | Direction | Payload Handling |
| :---: | :--- | :---: | :--- |
| **`21`** | Prepare Transition | Server $\to$ Client | `try await session.prepareTransition(transitionID: id, protocolVersion: version)` |
| **`22`** | Execute Transition | Server $\to$ Client | `try await session.executeTransition(transitionID: id)` |
| **`23`** | Ready for Transition | Client $\to$ Server | Emitted on `outgoing` as `.readyForTransition(transitionID: id)`. Send as opcode 23. |
| **`24`** | Prepare Epoch | Server $\to$ Client | `try await session.prepareEpoch(epoch, protocolVersion: version)` |
| **`25`** | MLS External Sender | Server $\to$ Client | `try await session.setExternalSender(payloadBytes)` |
| **`26`** | Key Package | Client $\to$ Server | Emitted on `outgoing` as `.keyPackage(data)`. Send as opcode 26. |
| **`27`** | Proposals | Server $\to$ Client | `try await session.processProposals(payloadBytes)` |
| **`28`** | Commit and Welcome | Client $\to$ Server | Emitted on `outgoing` as `.commitAndWelcome(data)`. Send as opcode 28. |
| **`29`** | Announce Commit Transition | Server $\to$ Client | `try await session.announceCommitTransition(transitionID: id, commit: payloadBytes)` |
| **`30`** | Welcome | Server $\to$ Client | `try await session.processWelcome(transitionID: id, welcome: payloadBytes)` |
| **`31`** | Invalid Commit/Welcome | Client $\to$ Server | Emitted on `outgoing` as `.invalidCommitWelcome(transitionID: id)`. Send as opcode 31. |

---

## 2. Media UDP Pipeline (RTP)

DAVE frame encryption operates **inside** the standard Discord RTP transport layer. It encrypts the codec payload before RTP packetization and transport AEAD.

### Exact Outbound Send Path

```
                    ┌─────────────────────────┐
                    │      Raw PCM Audio      │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │      Opus Encoder       │
                    └────────────┬────────────┘
                                 │ Opus Payload
                                 ▼
                    ┌─────────────────────────┐
                    │   DaveSession.encrypt   │ ◄── Enforces Hold Rule
                    └────────────┬────────────┘
                                 │ DAVE Encrypted Frame
                                 ▼
                    ┌─────────────────────────┐
                    │     RTP Packetizer      │ ◄── Adds 12-byte RTP Header (SSRC, Seq, Timestamp)
                    └────────────┬────────────┘
                                 │ RTP Packet
                                 ▼
                    ┌─────────────────────────┐
                    │ Transport AEAD Encrypt  │ ◄── Discord Voice Encryption (e.g. aead_aes256_gcm_rtpsize)
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │       UDP Socket        │
                    └─────────────────────────┘
```

1. **Encode**: Produce Opus compressed frame.
2. **DAVE Encrypt**: Call `try await session.encrypt(frame: opusBytes, ssrc: outboundSSRC)`.
3. **RTP Header**: Prepend the standard 12-byte RTP header.
4. **Transport Encryption**: Encrypt the RTP packet using the negotiated Discord UDP encryption mode.
5. **Send**: Emit to voice UDP socket.

### Exact Inbound Receive Path

```
                    ┌─────────────────────────┐
                    │       UDP Socket        │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │ Transport AEAD Decrypt  │ ◄── Discord Voice Decryption
                    └────────────┬────────────┘
                                 │ RTP Packet
                                 ▼
                    ┌─────────────────────────┐
                    │    RTP Depacketizer     │ ◄── Read SSRC -> Lookup remote User ID
                    └────────────┬────────────┘
                                 │ DAVE Encrypted Frame
                                 ▼
                    ┌─────────────────────────┐
                    │   DaveSession.decrypt   │ ◄── UserID-based AES-128-GCM Decryption
                    └────────────┬────────────┘
                                 │ Opus Payload
                                 ▼
                    ┌─────────────────────────┐
                    │      Opus Decoder       │
                    └────────────┬────────────┘
                                 │
                                 ▼
                    ┌─────────────────────────┐
                    │      Raw PCM Audio      │
                    └─────────────────────────┘
```

1. **Receive**: Read packet from UDP socket.
2. **Transport Decryption**: Decrypt transport layer using Discord voice encryption key.
3. **RTP Depacketize**: Extract SSRC, sequence number, and timestamp. Look up the sender's Discord `userID` using your gateway SSRC mapping.
4. **DAVE Decrypt**: Call `try await session.decrypt(frame: payloadBytes, userID: remoteUserID)`.
5. **Decode**: Pass decrypted Opus frame to decoder.

---

## 3. The Hold Rule

> **Critical**: Never emit unencrypted audio or video frames over UDP while `isReady` is `false`.

While transitions occur (e.g. initial group negotiation or key ratchet rotation), `session.isReady` returns `false`. Calling `session.encrypt(frame:ssrc:)` while unready throws `DaveError.notReady`.

### Recommended Queue Strategy

```swift
guard await session.isReady else {
    // hold audio frames in a small ring buffer or discard silence
    // do NOT send unencrypted packets to the socket
    return
}
let ciphertext = try await session.encrypt(frame: pcmOpus, ssrc: mySSRC)
```

---

## 4. User Lifecycle & SSRC Mapping

1. **SSRC Registration**:
   Before sending audio, associate your SSRC with the Opus codec:
   ```swift
   try await session.assignSSRC(mySSRC, codec: .opus)
   ```
2. **User Joins (`Speaking` or `Client Connect`)**:
   When Discord notifies you that a user has joined or is speaking:
   ```swift
   try await session.addUser(userID: remoteUserID)
   ```
3. **User Leaves**:
   ```swift
   try await session.removeUser(userID: remoteUserID)
   ```

---

## 5. Channel Moves & Reconnections

- **Channel Move**:
  When the bot moves to a new channel:
  1. `await oldSession.close()`
  2. Create a new `DaveSession(userID: selfUserID, channelID: newChannelID)`
  3. Start a new outgoing consumer task and proceed through gateway negotiation.
- **Reconnecting / Resuming**:
  If the voice gateway connection drops and resumes without channel change, continue using the existing session. If Discord sends opcode 4 with a fresh session description, re-initialize or create a fresh `DaveSession`.

---

## 6. Verification Checklist for Real Voice Testing

Run this manual checklist against a live Discord voice channel:

- [ ] **1. Two-party Join**: Bot connects to voice channel alongside a second Discord client (Discord Desktop or Mobile). Both report encrypted voice connection.
- [ ] **2. Bidirectional Audio**:
  - Bot transmits audio; client receives and hears clear playback.
  - Client speaks; bot receives, decrypts, and successfully decodes Opus frames.
- [ ] **3. User Joins Mid-call**: A third participant joins the channel. Verify commit/welcome transitions execute without audio interruption.
- [ ] **4. User Leaves Mid-call**: Third participant leaves. Verify removal transition completes cleanly.
- [ ] **5. Channel Move**: Move bot to another voice channel. Confirm old session closes and new session initializes without leaks.
- [ ] **6. Passthrough Fallback**: Connect to a channel where Discord sets `dave_protocol_version = 0`. Verify audio transmits in passthrough mode.
- [ ] **7. Verification Codes**: Compare `pairwiseFingerprint(version:userID:)` with Discord's End-to-End Encryption verification UI.

---

## 7. Known Limits

1. **Ciphersuites**: Discord currently mandates MLS ciphersuite 2 (`MLS_128_DHKEMP256_AES128GCM_SHA256_P256`).
2. **Opus Silence Frames**: By protocol specification, Opus silence frames (`0xF8, 0xFF, 0xFE`) pass through undecrypted to conserve compute during silence suppression.
3. **External Sender Requirement**: Group additions require external sender credentials issued by Discord over the voice gateway (Opcode 25).
