#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct DAVEExternalSenderOpaque* DAVEExternalSenderHandle;

DAVEExternalSenderHandle daveExternalSenderCreate(uint64_t groupId);
void daveExternalSenderDestroy(DAVEExternalSenderHandle externalSender);

void daveExternalSenderGetMarshalledExternalSender(
    DAVEExternalSenderHandle externalSender,
    uint8_t** marshalledExternalSender,
    size_t* length
);

void daveExternalSenderProposeAdd(
    DAVEExternalSenderHandle externalSender,
    uint32_t epoch,
    const uint8_t* keyPackage,
    size_t keyPackageLength,
    uint8_t** proposal,
    size_t* proposalLength
);

void daveExternalSenderSplitCommitWelcome(
    DAVEExternalSenderHandle externalSender,
    const uint8_t* commitWelcome,
    size_t commitWelcomeLength,
    uint8_t** commit,
    size_t* commitLength,
    uint8_t** welcome,
    size_t* welcomeLength
);

void daveTestFree(void* ptr);

#ifdef __cplusplus
}
#endif
