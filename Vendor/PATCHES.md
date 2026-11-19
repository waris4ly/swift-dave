# Vendored Patches

List of patches applied to upstream sources.

## 0001-cboringssl-module-and-sha2.patch
- Target: `Sources/CBoringSSL`
- Changes:
  - Renames module map module from `CCryptoBoringSSL` to `CBoringSSL`
  - Includes `CCryptoBoringSSL_sha2.h` in `CCryptoBoringSSL.h` to expose `CCryptoBoringSSL_SHA256` to Swift
  - Provides `include/openssl/*.h` shims to redirect standard OpenSSL includes to `CCryptoBoringSSL_*.h`, with `#undef` for the 5 identifiers that clash with C++ types/enums (`SHA256`, `SHA384`, `SHA512`, `HKDF`, `X25519`).

## 0002-cmlspp-namespace.patch
- Target: `Sources/CMLSPP`
- Changes:
  - Adds `include/namespace.h` with `#define MLS_NAMESPACE mlspp` (matching libdave's vcpkg port)
  - Omits `mls_ds` and `mls_vectors` test/benchmark subdirectories (matching libdave's portfile)

## 0003-clibdave-private-headers.patch
- Target: `Sources/CLibDave`
- Changes:
  - Exposes only `dave.h` in `include/` via `module.modulemap`
  - Moves C++ internal headers to `src/dave/` to keep Swift interface pure C

## 0004-clibdave-logger-mutex.patch
- Target: `Sources/CLibDave`
- Changes:
  - Protects fallback `std::cout` stream logging with a `std::mutex` in `logger.cpp` to prevent data races when libdave logs concurrently from multiple threads (TSAN clean)
