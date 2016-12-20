* `ocean.util.cipher.AES`, `ocean.util.cipher.Blowfish`, `ocean.util.cipher.Cipher`,
  `ocean.util.cipher.HMAC`, `ocean.util.cipher.misc.Bitwise`

  The remaining non-gcrypt cipher modules are no longer supported. All code
  which requires encryption or decryption should use the libgcrypt binding in
  `ocean.util.cipher.gcrypt`.
