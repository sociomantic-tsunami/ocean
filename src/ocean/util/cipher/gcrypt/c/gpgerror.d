/*******************************************************************************

    D bindings to GPG error functions, used by libgcrypt.

    These are actually in the separate libgpg-error library, but libgcrypt is
    linked with it.

    Requires linking with libgcrypt:

        -L-lgcrypt

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

        Bear in mind this module provides bindings to an external library that
        has its own license, which might be more restrictive. Please check the
        external library license to see which conditions apply for linking.

*******************************************************************************/

module ocean.util.cipher.gcrypt.c.gpgerror;

public import ocean.util.cipher.gcrypt.c.libversion;

import ocean.transition;

extern (C):

/// See original's library documentation for details.
const GPG_ERROR_VERSION_NUMBER = 0x011500;
const GPGRT_VERSION_NUMBER =     0x011500;

/// See original's library documentation for details.
alias uint gpg_error_t;


/// See original's library documentation for details.
enum GPG_ERR_SOURCE
{
    UNKNOWN = 0,
    GCRYPT = 1,
    GPG = 2,
    GPGSM = 3,
    GPGAGENT = 4,
    PINENTRY = 5,
    SCD = 6,
    GPGME = 7,
    KEYBOX = 8,
    KSBA = 9,
    DIRMNGR = 10,
    GSTI = 11,
    GPA = 12,
    KLEO = 13,
    G13 = 14,
    ASSUAN = 15,
    TLS = 17,
    ANY = 31,
    USER_1 = 32,
    USER_2 = 33,
    USER_3 = 34,
    USER_4 = 35,

    MASK = (1 << 7) - 1
}

/// See original's library documentation for details.
const GPG_ERR_SOURCE_DIM = GPG_ERR_SOURCE.max + 1;


/// See original's library documentation for details.
enum GPG_ERR_CODE
{
    NO_ERROR = 0,
    GENERAL = 1,
    UNKNOWN_PACKET = 2,
    UNKNOWN_VERSION = 3,
    PUBKEY_ALGO = 4,
    DIGEST_ALGO = 5,
    BAD_PUBKEY = 6,
    BAD_SECKEY = 7,
    BAD_SIGNATURE = 8,
    NO_PUBKEY = 9,
    CHECKSUM = 10,
    BAD_PASSPHRASE = 11,
    CIPHER_ALGO = 12,
    KEYRING_OPEN = 13,
    INV_PACKET = 14,
    INV_ARMOR = 15,
    NO_USER_ID = 16,
    NO_SECKEY = 17,
    WRONG_SECKEY = 18,
    BAD_KEY = 19,
    COMPR_ALGO = 20,
    NO_PRIME = 21,
    NO_ENCODING_METHOD = 22,
    NO_ENCRYPTION_SCHEME = 23,
    NO_SIGNATURE_SCHEME = 24,
    INV_ATTR = 25,
    NO_VALUE = 26,
    NOT_FOUND = 27,
    VALUE_NOT_FOUND = 28,
    SYNTAX = 29,
    BAD_MPI = 30,
    INV_PASSPHRASE = 31,
    SIG_CLASS = 32,
    RESOURCE_LIMIT = 33,
    INV_KEYRING = 34,
    TRUSTDB = 35,
    BAD_CERT = 36,
    INV_USER_ID = 37,
    UNEXPECTED = 38,
    TIME_CONFLICT = 39,
    KEYSERVER = 40,
    WRONG_PUBKEY_ALGO = 41,
    TRIBUTE_TO_D_A = 42,
    WEAK_KEY = 43,
    INV_KEYLEN = 44,
    INV_ARG = 45,
    BAD_URI = 46,
    INV_URI = 47,
    NETWORK = 48,
    UNKNOWN_HOST = 49,
    SELFTEST_FAILED = 50,
    NOT_ENCRYPTED = 51,
    NOT_PROCESSED = 52,
    UNUSABLE_PUBKEY = 53,
    UNUSABLE_SECKEY = 54,
    INV_VALUE = 55,
    BAD_CERT_CHAIN = 56,
    MISSING_CERT = 57,
    NO_DATA = 58,
    BUG = 59,
    NOT_SUPPORTED = 60,
    INV_OP = 61,
    TIMEOUT = 62,
    INTERNAL = 63,
    EOF_GCRYPT = 64,
    INV_OBJ = 65,
    TOO_SHORT = 66,
    TOO_LARGE = 67,
    NO_OBJ = 68,
    NOT_IMPLEMENTED = 69,
    CONFLICT = 70,
    INV_CIPHER_MODE = 71,
    INV_FLAG = 72,
    INV_HANDLE = 73,
    TRUNCATED = 74,
    INCOMPLETE_LINE = 75,
    INV_RESPONSE = 76,
    NO_AGENT = 77,
    AGENT = 78,
    INV_DATA = 79,
    ASSUAN_SERVER_FAULT = 80,
    ASSUAN = 81,
    INV_SESSION_KEY = 82,
    INV_SEXP = 83,
    UNSUPPORTED_ALGORITHM = 84,
    NO_PIN_ENTRY = 85,
    PIN_ENTRY = 86,
    BAD_PIN = 87,
    INV_NAME = 88,
    BAD_DATA = 89,
    INV_PARAMETER = 90,
    WRONG_CARD = 91,
    NO_DIRMNGR = 92,
    DIRMNGR = 93,
    CERT_REVOKED = 94,
    NO_CRL_KNOWN = 95,
    CRL_TOO_OLD = 96,
    LINE_TOO_LONG = 97,
    NOT_TRUSTED = 98,
    CANCELED = 99,
    BAD_CA_CERT = 100,
    CERT_EXPIRED = 101,
    CERT_TOO_YOUNG = 102,
    UNSUPPORTED_CERT = 103,
    UNKNOWN_SEXP = 104,
    UNSUPPORTED_PROTECTION = 105,
    CORRUPTED_PROTECTION = 106,
    AMBIGUOUS_NAME = 107,
    CARD = 108,
    CARD_RESET = 109,
    CARD_REMOVED = 110,
    INV_CARD = 111,
    CARD_NOT_PRESENT = 112,
    NO_PKCS15_APP = 113,
    NOT_CONFIRMED = 114,
    CONFIGURATION = 115,
    NO_POLICY_MATCH = 116,
    INV_INDEX = 117,
    INV_ID = 118,
    NO_SCDAEMON = 119,
    SCDAEMON = 120,
    UNSUPPORTED_PROTOCOL = 121,
    BAD_PIN_METHOD = 122,
    CARD_NOT_INITIALIZED = 123,
    UNSUPPORTED_OPERATION = 124,
    WRONG_KEY_USAGE = 125,
    NOTHING_FOUND = 126,
    WRONG_BLOB_TYPE = 127,
    MISSING_VALUE = 128,
    HARDWARE = 129,
    PIN_BLOCKED = 130,
    USE_CONDITIONS = 131,
    PIN_NOT_SYNCED = 132,
    INV_CRL = 133,
    BAD_BER = 134,
    INV_BER = 135,
    ELEMENT_NOT_FOUND = 136,
    IDENTIFIER_NOT_FOUND = 137,
    INV_TAG = 138,
    INV_LENGTH = 139,
    INV_KEYINFO = 140,
    UNEXPECTED_TAG = 141,
    NOT_DER_ENCODED = 142,
    NO_CMS_OBJ = 143,
    INV_CMS_OBJ = 144,
    UNKNOWN_CMS_OBJ = 145,
    UNSUPPORTED_CMS_OBJ = 146,
    UNSUPPORTED_ENCODING = 147,
    UNSUPPORTED_CMS_VERSION = 148,
    UNKNOWN_ALGORITHM = 149,
    INV_ENGINE = 150,
    PUBKEY_NOT_TRUSTED = 151,
    DECRYPT_FAILED = 152,
    KEY_EXPIRED = 153,
    SIG_EXPIRED = 154,
    ENCODING_PROBLEM = 155,
    INV_STATE = 156,
    DUP_VALUE = 157,
    MISSING_ACTION = 158,
    MODULE_NOT_FOUND = 159,
    INV_OID_STRING = 160,
    INV_TIME = 161,
    INV_CRL_OBJ = 162,
    UNSUPPORTED_CRL_VERSION = 163,
    INV_CERT_OBJ = 164,
    UNKNOWN_NAME = 165,
    LOCALE_PROBLEM = 166,
    NOT_LOCKED = 167,
    PROTOCOL_VIOLATION = 168,
    INV_MAC = 169,
    INV_REQUEST = 170,
    UNKNOWN_EXTN = 171,
    UNKNOWN_CRIT_EXTN = 172,
    LOCKED = 173,
    UNKNOWN_OPTION = 174,
    UNKNOWN_COMMAND = 175,
    NOT_OPERATIONAL = 176,
    NO_PASSPHRASE = 177,
    NO_PIN = 178,
    NOT_ENABLED = 179,
    NO_ENGINE = 180,
    MISSING_KEY = 181,
    TOO_MANY = 182,
    LIMIT_REACHED = 183,
    NOT_INITIALIZED = 184,
    MISSING_ISSUER_CERT = 185,
    NO_KEYSERVER = 186,
    INV_CURVE = 187,
    UNKNOWN_CURVE = 188,
    DUP_KEY = 189,
    AMBIGUOUS = 190,
    NO_CRYPT_CTX = 191,
    WRONG_CRYPT_CTX = 192,
    BAD_CRYPT_CTX = 193,
    CRYPT_CTX_CONFLICT = 194,
    BROKEN_PUBKEY = 195,
    BROKEN_SECKEY = 196,
    MAC_ALGO = 197,
    FULLY_CANCELED = 198,
    UNFINISHED = 199,
    BUFFER_TOO_SHORT = 200,
    SEXP_INV_LEN_SPEC = 201,
    SEXP_STRING_TOO_LONG = 202,
    SEXP_UNMATCHED_PAREN = 203,
    SEXP_NOT_CANONICAL = 204,
    SEXP_BAD_CHARACTER = 205,
    SEXP_BAD_QUOTATION = 206,
    SEXP_ZERO_PREFIX = 207,
    SEXP_NESTED_DH = 208,
    SEXP_UNMATCHED_DH = 209,
    SEXP_UNEXPECTED_PUNC = 210,
    SEXP_BAD_HEX_CHAR = 211,
    SEXP_ODD_HEX_NUMBERS = 212,
    SEXP_BAD_OCT_CHAR = 213,
    SERVER_FAILED = 219,
    NO_NAME = 220,
    NO_KEY = 221,
    LEGACY_KEY = 222,
    REQUEST_TOO_SHORT = 223,
    REQUEST_TOO_LONG = 224,
    OBJ_TERM_STATE = 225,
    NO_CERT_CHAIN = 226,
    CERT_TOO_LARGE = 227,
    INV_RECORD = 228,
    BAD_MAC = 229,
    UNEXPECTED_MSG = 230,
    COMPR_FAILED = 231,
    WOULD_WRAP = 232,
    FATAL_ALERT = 233,
    NO_CIPHER = 234,
    MISSING_CLIENT_CERT = 235,
    CLOSE_NOTIFY = 236,
    TICKET_EXPIRED = 237,
    BAD_TICKET = 238,
    UNKNOWN_IDENTITY = 239,
    BAD_HS_CERT = 240,
    BAD_HS_CERT_REQ = 241,
    BAD_HS_CERT_VER = 242,
    BAD_HS_CHANGE_CIPHER = 243,
    BAD_HS_CLIENT_HELLO = 244,
    BAD_HS_SERVER_HELLO = 245,
    BAD_HS_SERVER_HELLO_DONE = 246,
    BAD_HS_FINISHED = 247,
    BAD_HS_SERVER_KEX = 248,
    BAD_HS_CLIENT_KEX = 249,
    BOGUS_STRING = 250,
    FORBIDDEN = 251,
    KEY_DISABLED = 252,
    KEY_ON_CARD = 253,
    INV_LOCK_OBJ = 254,
    TRUE = 255,
    FALSE = 256,
    ASS_GENERAL = 257,
    ASS_ACCEPT_FAILED = 258,
    ASS_CONNECT_FAILED = 259,
    ASS_INV_RESPONSE = 260,
    ASS_INV_VALUE = 261,
    ASS_INCOMPLETE_LINE = 262,
    ASS_LINE_TOO_LONG = 263,
    ASS_NESTED_COMMANDS = 264,
    ASS_NO_DATA_CB = 265,
    ASS_NO_INQUIRE_CB = 266,
    ASS_NOT_A_SERVER = 267,
    ASS_NOT_A_CLIENT = 268,
    ASS_SERVER_START = 269,
    ASS_READ_ERROR = 270,
    ASS_WRITE_ERROR = 271,
    ASS_TOO_MUCH_DATA = 273,
    ASS_UNEXPECTED_CMD = 274,
    ASS_UNKNOWN_CMD = 275,
    ASS_SYNTAX = 276,
    ASS_CANCELED = 277,
    ASS_NO_INPUT = 278,
    ASS_NO_OUTPUT = 279,
    ASS_PARAMETER = 280,
    ASS_UNKNOWN_INQUIRE = 281,
    LDAP_GENERAL = 721,
    LDAP_ATTR_GENERAL = 722,
    LDAP_NAME_GENERAL = 723,
    LDAP_SECURITY_GENERAL = 724,
    LDAP_SERVICE_GENERAL = 725,
    LDAP_UPDATE_GENERAL = 726,
    LDAP_E_GENERAL = 727,
    LDAP_X_GENERAL = 728,
    LDAP_OTHER_GENERAL = 729,
    LDAP_X_CONNECTING = 750,
    LDAP_REFERRAL_LIMIT = 751,
    LDAP_CLIENT_LOOP = 752,
    LDAP_NO_RESULTS = 754,
    LDAP_CONTROL_NOT_FOUND = 755,
    LDAP_NOT_SUPPORTED = 756,
    LDAP_CONNECT = 757,
    LDAP_NO_MEMORY = 758,
    LDAP_PARAM = 759,
    LDAP_USER_CANCELLED = 760,
    LDAP_FILTER = 761,
    LDAP_AUTH_UNKNOWN = 762,
    LDAP_TIMEOUT = 763,
    LDAP_DECODING = 764,
    LDAP_ENCODING = 765,
    LDAP_LOCAL = 766,
    LDAP_SERVER_DOWN = 767,
    LDAP_SUCCESS = 768,
    LDAP_OPERATIONS = 769,
    LDAP_PROTOCOL = 770,
    LDAP_TIMELIMIT = 771,
    LDAP_SIZELIMIT = 772,
    LDAP_COMPARE_FALSE = 773,
    LDAP_COMPARE_TRUE = 774,
    LDAP_UNSUPPORTED_AUTH = 775,
    LDAP_STRONG_AUTH_RQRD = 776,
    LDAP_PARTIAL_RESULTS = 777,
    LDAP_REFERRAL = 778,
    LDAP_ADMINLIMIT = 779,
    LDAP_UNAVAIL_CRIT_EXTN = 780,
    LDAP_CONFIDENT_RQRD = 781,
    LDAP_SASL_BIND_INPROG = 782,
    LDAP_NO_SUCH_ATTRIBUTE = 784,
    LDAP_UNDEFINED_TYPE = 785,
    LDAP_BAD_MATCHING = 786,
    LDAP_CONST_VIOLATION = 787,
    LDAP_TYPE_VALUE_EXISTS = 788,
    LDAP_INV_SYNTAX = 789,
    LDAP_NO_SUCH_OBJ = 800,
    LDAP_ALIAS_PROBLEM = 801,
    LDAP_INV_DN_SYNTAX = 802,
    LDAP_IS_LEAF = 803,
    LDAP_ALIAS_DEREF = 804,
    LDAP_X_PROXY_AUTH_FAIL = 815,
    LDAP_BAD_AUTH = 816,
    LDAP_INV_CREDENTIALS = 817,
    LDAP_INSUFFICIENT_ACC = 818,
    LDAP_BUSY = 819,
    LDAP_UNAVAILABLE = 820,
    LDAP_UNWILL_TO_PERFORM = 821,
    LDAP_LOOP_DETECT = 822,
    LDAP_NAMING_VIOLATION = 832,
    LDAP_OBJ_CLS_VIOLATION = 833,
    LDAP_NOT_ALLOW_NONLEAF = 834,
    LDAP_NOT_ALLOW_ON_RDN = 835,
    LDAP_ALREADY_EXISTS = 836,
    LDAP_NO_OBJ_CLASS_MODS = 837,
    LDAP_RESULTS_TOO_LARGE = 838,
    LDAP_AFFECTS_MULT_DSAS = 839,
    LDAP_VLV = 844,
    LDAP_OTHER = 848,
    LDAP_CUP_RESOURCE_LIMIT = 881,
    LDAP_CUP_SEC_VIOLATION = 882,
    LDAP_CUP_INV_DATA = 883,
    LDAP_CUP_UNSUP_SCHEME = 884,
    LDAP_CUP_RELOAD = 885,
    LDAP_CANCELLED = 886,
    LDAP_NO_SUCH_OPERATION = 887,
    LDAP_TOO_LATE = 888,
    LDAP_CANNOT_CANCEL = 889,
    LDAP_ASSERTION_FAILED = 890,
    LDAP_PROX_AUTH_DENIED = 891,
    USER_1 = (1 << 10),
    USER_2,
    USER_3,
    USER_4,
    USER_5,
    USER_6,
    USER_7,
    USER_8,
    USER_9,
    USER_10,
    USER_11,
    USER_12,
    USER_13,
    USER_14,
    USER_15,
    USER_16,
    MISSING_ERRNO = (1 << 14) - 3,
    UNKNOWN_ERRNO = (1 << 14) - 2,
    EOF = (1 << 14) - 1,

    SYSTEM_ERROR = (1 << 15),
    E2BIG = SYSTEM_ERROR | 0,
    EACCES = SYSTEM_ERROR | 1,
    EADDRINUSE = SYSTEM_ERROR | 2,
    EADDRNOTAVAIL = SYSTEM_ERROR | 3,
    EADV = SYSTEM_ERROR | 4,
    EAFNOSUPPORT = SYSTEM_ERROR | 5,
    EAGAIN = SYSTEM_ERROR | 6,
    EALREADY = SYSTEM_ERROR | 7,
    EAUTH = SYSTEM_ERROR | 8,
    EBACKGROUND = SYSTEM_ERROR | 9,
    EBADE = SYSTEM_ERROR | 10,
    EBADF = SYSTEM_ERROR | 11,
    EBADFD = SYSTEM_ERROR | 12,
    EBADMSG = SYSTEM_ERROR | 13,
    EBADR = SYSTEM_ERROR | 14,
    EBADRPC = SYSTEM_ERROR | 15,
    EBADRQC = SYSTEM_ERROR | 16,
    EBADSLT = SYSTEM_ERROR | 17,
    EBFONT = SYSTEM_ERROR | 18,
    EBUSY = SYSTEM_ERROR | 19,
    ECANCELED = SYSTEM_ERROR | 20,
    ECHILD = SYSTEM_ERROR | 21,
    ECHRNG = SYSTEM_ERROR | 22,
    ECOMM = SYSTEM_ERROR | 23,
    ECONNABORTED = SYSTEM_ERROR | 24,
    ECONNREFUSED = SYSTEM_ERROR | 25,
    ECONNRESET = SYSTEM_ERROR | 26,
    ED = SYSTEM_ERROR | 27,
    EDEADLK = SYSTEM_ERROR | 28,
    EDEADLOCK = SYSTEM_ERROR | 29,
    EDESTADDRREQ = SYSTEM_ERROR | 30,
    EDIED = SYSTEM_ERROR | 31,
    EDOM = SYSTEM_ERROR | 32,
    EDOTDOT = SYSTEM_ERROR | 33,
    EDQUOT = SYSTEM_ERROR | 34,
    EEXIST = SYSTEM_ERROR | 35,
    EFAULT = SYSTEM_ERROR | 36,
    EFBIG = SYSTEM_ERROR | 37,
    EFTYPE = SYSTEM_ERROR | 38,
    EGRATUITOUS = SYSTEM_ERROR | 39,
    EGREGIOUS = SYSTEM_ERROR | 40,
    EHOSTDOWN = SYSTEM_ERROR | 41,
    EHOSTUNREACH = SYSTEM_ERROR | 42,
    EIDRM = SYSTEM_ERROR | 43,
    EIEIO = SYSTEM_ERROR | 44,
    EILSEQ = SYSTEM_ERROR | 45,
    EINPROGRESS = SYSTEM_ERROR | 46,
    EINTR = SYSTEM_ERROR | 47,
    EINVAL = SYSTEM_ERROR | 48,
    EIO = SYSTEM_ERROR | 49,
    EISCONN = SYSTEM_ERROR | 50,
    EISDIR = SYSTEM_ERROR | 51,
    EISNAM = SYSTEM_ERROR | 52,
    EL2HLT = SYSTEM_ERROR | 53,
    EL2NSYNC = SYSTEM_ERROR | 54,
    EL3HLT = SYSTEM_ERROR | 55,
    EL3RST = SYSTEM_ERROR | 56,
    ELIBACC = SYSTEM_ERROR | 57,
    ELIBBAD = SYSTEM_ERROR | 58,
    ELIBEXEC = SYSTEM_ERROR | 59,
    ELIBMAX = SYSTEM_ERROR | 60,
    ELIBSCN = SYSTEM_ERROR | 61,
    ELNRNG = SYSTEM_ERROR | 62,
    ELOOP = SYSTEM_ERROR | 63,
    EMEDIUMTYPE = SYSTEM_ERROR | 64,
    EMFILE = SYSTEM_ERROR | 65,
    EMLINK = SYSTEM_ERROR | 66,
    EMSGSIZE = SYSTEM_ERROR | 67,
    EMULTIHOP = SYSTEM_ERROR | 68,
    ENAMETOOLONG = SYSTEM_ERROR | 69,
    ENAVAIL = SYSTEM_ERROR | 70,
    ENEEDAUTH = SYSTEM_ERROR | 71,
    ENETDOWN = SYSTEM_ERROR | 72,
    ENETRESET = SYSTEM_ERROR | 73,
    ENETUNREACH = SYSTEM_ERROR | 74,
    ENFILE = SYSTEM_ERROR | 75,
    ENOANO = SYSTEM_ERROR | 76,
    ENOBUFS = SYSTEM_ERROR | 77,
    ENOCSI = SYSTEM_ERROR | 78,
    ENODATA = SYSTEM_ERROR | 79,
    ENODEV = SYSTEM_ERROR | 80,
    ENOENT = SYSTEM_ERROR | 81,
    ENOEXEC = SYSTEM_ERROR | 82,
    ENOLCK = SYSTEM_ERROR | 83,
    ENOLINK = SYSTEM_ERROR | 84,
    ENOMEDIUM = SYSTEM_ERROR | 85,
    ENOMEM = SYSTEM_ERROR | 86,
    ENOMSG = SYSTEM_ERROR | 87,
    ENONET = SYSTEM_ERROR | 88,
    ENOPKG = SYSTEM_ERROR | 89,
    ENOPROTOOPT = SYSTEM_ERROR | 90,
    ENOSPC = SYSTEM_ERROR | 91,
    ENOSR = SYSTEM_ERROR | 92,
    ENOSTR = SYSTEM_ERROR | 93,
    ENOSYS = SYSTEM_ERROR | 94,
    ENOTBLK = SYSTEM_ERROR | 95,
    ENOTCONN = SYSTEM_ERROR | 96,
    ENOTDIR = SYSTEM_ERROR | 97,
    ENOTEMPTY = SYSTEM_ERROR | 98,
    ENOTNAM = SYSTEM_ERROR | 99,
    ENOTSOCK = SYSTEM_ERROR | 100,
    ENOTSUP = SYSTEM_ERROR | 101,
    ENOTTY = SYSTEM_ERROR | 102,
    ENOTUNIQ = SYSTEM_ERROR | 103,
    ENXIO = SYSTEM_ERROR | 104,
    EOPNOTSUPP = SYSTEM_ERROR | 105,
    EOVERFLOW = SYSTEM_ERROR | 106,
    EPERM = SYSTEM_ERROR | 107,
    EPFNOSUPPORT = SYSTEM_ERROR | 108,
    EPIPE = SYSTEM_ERROR | 109,
    EPROCLIM = SYSTEM_ERROR | 110,
    EPROCUNAVAIL = SYSTEM_ERROR | 111,
    EPROGMISMATCH = SYSTEM_ERROR | 112,
    EPROGUNAVAIL = SYSTEM_ERROR | 113,
    EPROTO = SYSTEM_ERROR | 114,
    EPROTONOSUPPORT = SYSTEM_ERROR | 115,
    EPROTOTYPE = SYSTEM_ERROR | 116,
    ERANGE = SYSTEM_ERROR | 117,
    EREMCHG = SYSTEM_ERROR | 118,
    EREMOTE = SYSTEM_ERROR | 119,
    EREMOTEIO = SYSTEM_ERROR | 120,
    ERESTART = SYSTEM_ERROR | 121,
    EROFS = SYSTEM_ERROR | 122,
    ERPCMISMATCH = SYSTEM_ERROR | 123,
    ESHUTDOWN = SYSTEM_ERROR | 124,
    ESOCKTNOSUPPORT = SYSTEM_ERROR | 125,
    ESPIPE = SYSTEM_ERROR | 126,
    ESRCH = SYSTEM_ERROR | 127,
    ESRMNT = SYSTEM_ERROR | 128,
    ESTALE = SYSTEM_ERROR | 129,
    ESTRPIPE = SYSTEM_ERROR | 130,
    ETIME = SYSTEM_ERROR | 131,
    ETIMEDOUT = SYSTEM_ERROR | 132,
    ETOOMANYREFS = SYSTEM_ERROR | 133,
    ETXTBSY = SYSTEM_ERROR | 134,
    EUCLEAN = SYSTEM_ERROR | 135,
    EUNATCH = SYSTEM_ERROR | 136,
    EUSERS = SYSTEM_ERROR | 137,
    EWOULDBLOCK = SYSTEM_ERROR | 138,
    EXDEV = SYSTEM_ERROR | 139,
    EXFULL = SYSTEM_ERROR | 140,

    MASK = (1 << 16) - 1
}

/// See original's library documentation for details.
const GPG_ERR_CODE_DIM = GPG_ERR_CODE.max + 1;

/// See original's library documentation for details.
const GPG_ERR_SOURCE_SHIFT  = 24;

/// See original's library documentation for details.
uint gpg_err_init();

static this ( )
{
    gpg_err_init();
}

/// See original's library documentation for details.
void gpg_err_deinit (int mode);

/// See original's library documentation for details.
void gpgrt_set_syscall_clamp (void function() pre, void function() post);

/// See original's library documentation for details.
void gpgrt_set_alloc_func  (void* function(void *a, size_t n) f);


/// See original's library documentation for details.
uint gpg_err_make(GPG_ERR_SOURCE source, GPG_ERR_CODE code)
{
    return code? (((source & source.MASK) << GPG_ERR_SOURCE_SHIFT) | (code & code.MASK))
               : code;
}


/// See original's library documentation for details.
gpg_error_t gpg_error (GPG_ERR_CODE code)
{
  return gpg_err_make(GPG_ERR_SOURCE.init, code);
}


/// See original's library documentation for details.
GPG_ERR_CODE gpg_err_code (gpg_error_t err)
{
  return cast(GPG_ERR_CODE)(err & GPG_ERR_CODE.MASK);
}


/// See original's library documentation for details.
GPG_ERR_SOURCE gpg_err_source (gpg_error_t err)
{
  return cast(GPG_ERR_SOURCE)((err >> GPG_ERR_SOURCE_SHIFT) & GPG_ERR_SOURCE.MASK);
}

/// See original's library documentation for details.
Const!(char)* gpg_strerror(gpg_error_t err);

/// See original's library documentation for details.
int gpg_strerror_r(gpg_error_t err, char* buf, size_t buflen);

import ocean.stdc.string;

extern (D) int gpg_strerror_r(uint err, ref char[] msg)
in
{
    assert(msg.length);
}
body
{
    scope (exit)
        msg = msg[0 .. strlen(msg.ptr)];

    return gpg_strerror_r(err, msg.ptr, msg.length);
}

/// See original's library documentation for details.
Const!(char)* gpg_strsource (uint err);

/// See original's library documentation for details.
GPG_ERR_CODE gpg_err_code_from_errno(int err);


/// See original's library documentation for details.
int gpg_err_code_to_errno(GPG_ERR_CODE code);


/// See original's library documentation for details.
GPG_ERR_CODE gpg_err_code_from_syserror();


/// See original's library documentation for details.
void gpg_err_set_errno(int err);

/// See original's library documentation for details.
Const!(char)* gpgrt_check_version (Const!(char)* req_version);
Const!(char)* gpg_error_check_version(Const!(char)* req_version);
