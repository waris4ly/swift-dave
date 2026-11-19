#pragma once
#include "../CCryptoBoringSSL_nid.h"

#if defined(__cplusplus)
#ifdef SHA256
#undef SHA256
#endif
#ifdef SHA384
#undef SHA384
#endif
#ifdef SHA512
#undef SHA512
#endif
#ifdef HKDF
#undef HKDF
#endif
#ifdef X25519
#undef X25519
#endif
#endif

