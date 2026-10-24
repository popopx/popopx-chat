#ifdef __APPLE__
#include <CommonCrypto/CommonDigest.h>
#include "sha512.h"

void crypto_hash_sha512 (unsigned char *out,
                         const unsigned char *in,
                         unsigned long long inlen)
{
  CC_SHA512(in, (CC_LONG)inlen, out);
}
#else
#include <openssl/sha.h>
#include "sha512.h"

void crypto_hash_sha512 (unsigned char *out,
                         const unsigned char *in,
                         unsigned long long inlen)
{
  SHA512(in, inlen, out);
}
#endif
