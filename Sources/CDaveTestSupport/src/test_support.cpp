#include "DaveTestSupport.h"

#include <cstdlib>
#include <cstring>
#include <memory>
#include <vector>

#include <dave.h>
#include "external_sender.h"

namespace {

void CopyVectorToOutput(const std::vector<uint8_t>& vec, uint8_t** data, size_t* length)
{
    if (data == nullptr || length == nullptr) {
        return;
    }

    if (vec.empty()) {
        *data = nullptr;
        *length = 0;
        return;
    }

    *data = static_cast<uint8_t*>(malloc(vec.size()));
    if (*data != nullptr) {
        memcpy(*data, vec.data(), vec.size());
        *length = vec.size();
    } else {
        *length = 0;
    }
}

} // anonymous namespace

DAVEExternalSenderHandle daveExternalSenderCreate(uint64_t groupId)
{
    auto protocolVersion = daveMaxSupportedProtocolVersion();
    auto externalSender =
        std::make_unique<discord::dave::test::ExternalSender>(protocolVersion, groupId);
    return reinterpret_cast<DAVEExternalSenderHandle>(externalSender.release());
}

void daveExternalSenderDestroy(DAVEExternalSenderHandle externalSenderHandle)
{
    auto externalSender =
        reinterpret_cast<discord::dave::test::ExternalSender*>(externalSenderHandle);
    delete externalSender;
}

void daveExternalSenderGetMarshalledExternalSender(
    DAVEExternalSenderHandle externalSenderHandle,
    uint8_t** marshalledExternalSender,
    size_t* length)
{
    auto externalSender =
        reinterpret_cast<discord::dave::test::ExternalSender*>(externalSenderHandle);
    if (externalSender == nullptr) return;
    auto vec = externalSender->GetMarshalledExternalSender();
    CopyVectorToOutput(vec, marshalledExternalSender, length);
}

void daveExternalSenderProposeAdd(
    DAVEExternalSenderHandle externalSenderHandle,
    uint32_t epoch,
    const uint8_t* keyPackage,
    size_t keyPackageLength,
    uint8_t** proposal,
    size_t* proposalLength)
{
    auto externalSender =
        reinterpret_cast<discord::dave::test::ExternalSender*>(externalSenderHandle);
    if (externalSender == nullptr || keyPackage == nullptr) return;
    auto keyPackageVec = std::vector<uint8_t>(keyPackage, keyPackage + keyPackageLength);
    auto result = externalSender->ProposeAdd(epoch, keyPackageVec);
    CopyVectorToOutput(result, proposal, proposalLength);
}

void daveExternalSenderSplitCommitWelcome(
    DAVEExternalSenderHandle externalSenderHandle,
    const uint8_t* commitWelcome,
    size_t commitWelcomeLength,
    uint8_t** commit,
    size_t* commitLength,
    uint8_t** welcome,
    size_t* welcomeLength)
{
    auto externalSender =
        reinterpret_cast<discord::dave::test::ExternalSender*>(externalSenderHandle);
    if (externalSender == nullptr || commitWelcome == nullptr) return;
    auto commitWelcomeVec =
        std::vector<uint8_t>(commitWelcome, commitWelcome + commitWelcomeLength);
    auto [commitBytes, welcomeBytes] =
        externalSender->SplitCommitWelcome(commitWelcomeVec);
    CopyVectorToOutput(commitBytes, commit, commitLength);
    CopyVectorToOutput(welcomeBytes, welcome, welcomeLength);
}

void daveTestFree(void* ptr)
{
    free(ptr);
}
