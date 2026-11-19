import CLibDave

func checkEncryptorResult(_ code: DAVEEncryptorResultCode) throws(DaveError) {
    switch code {
    case DAVE_ENCRYPTOR_RESULT_CODE_SUCCESS:
        return
    case DAVE_ENCRYPTOR_RESULT_CODE_ENCRYPTION_FAILURE:
        throw .encryptionFailure
    case DAVE_ENCRYPTOR_RESULT_CODE_MISSING_KEY_RATCHET:
        throw .missingKeyRatchet
    case DAVE_ENCRYPTOR_RESULT_CODE_MISSING_CRYPTOR:
        throw .missingCryptor
    case DAVE_ENCRYPTOR_RESULT_CODE_TOO_MANY_ATTEMPTS:
        throw .tooManyAttempts
    default:
        throw .unknownResultCode(Int(code.rawValue))
    }
}

func checkDecryptorResult(_ code: DAVEDecryptorResultCode) throws(DaveError) {
    switch code {
    case DAVE_DECRYPTOR_RESULT_CODE_SUCCESS:
        return
    case DAVE_DECRYPTOR_RESULT_CODE_DECRYPTION_FAILURE:
        throw .decryptionFailure
    case DAVE_DECRYPTOR_RESULT_CODE_MISSING_KEY_RATCHET:
        throw .missingKeyRatchet
    case DAVE_DECRYPTOR_RESULT_CODE_INVALID_NONCE:
        throw .invalidNonce
    case DAVE_DECRYPTOR_RESULT_CODE_MISSING_CRYPTOR:
        throw .missingCryptor
    default:
        throw .unknownResultCode(Int(code.rawValue))
    }
}
