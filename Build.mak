# This will make D2 unittests fail if stomping prevention is triggered
export ASSERT_ON_STOMPING_PREVENTION=1

override DFLAGS += -w -version=GLIBC

# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -or course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

ifeq ($(DVER),1)
override DFLAGS := $(filter-out -di,$(DFLAGS)) -v2 -v2=-static-arr-params -v2=-volatile
else
# Open source Makd uses dmd by default
DC ?= dmd
override DFLAGS += -de
endif

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$C/src/ocean/text/util/c/iconv.d \
	$C/src/ocean/core/Array_tango.d \
	$C/src/ocean/net/device/Datagram.d \
	$C/src/ocean/net/device/Multicast.d \
	$C/src/ocean/net/http/HttpClient.d \
	$C/src/ocean/net/http/HttpGet.d \
	$C/src/ocean/net/http/HttpPost.d \
	$C/src/ocean/util/log/AppendMail.d \
	$C/src/ocean/util/log/AppendSocket.d \
	$C/src/ocean/util/config/ClassFiller.d \
	$C/src/ocean/util/container/HashMap.d \
	$C/src/ocean/util/container/more/CacheMap.d \
	$C/src/ocean/util/container/more/StackMap.d \
	$C/src/ocean/util/cipher/AES.d \
	$C/src/ocean/util/cipher/Blowfish.d \
	$C/src/ocean/util/cipher/Cipher.d \
	$C/src/ocean/util/cipher/HMAC.d \
	$C/src/ocean/util/cipher/misc/Bitwise.d \
	$C/src/ocean/util/cipher/TEA.d \
	$C/src/ocean/util/cipher/XTEA.d \
	$C/src/ocean/util/cipher/RC4.d \
	$C/src/ocean/util/cipher/Salsa20.d \
	$C/src/ocean/util/cipher/ChaCha.d \
	$C/src/ocean/text/util/StringReplace.d \
	$C/src/ocean/text/xml/Xslt.d \
	$C/src/ocean/text/xml/c/LibXslt.d \
	$C/src/ocean/text/xml/c/LibXml2.d \
	$C/src/ocean/io/serialize/XmlStructSerializer.d \
	$C/src/ocean/util/container/HashMap.d \
	$C/src/ocean/util/container/more/CacheMap.d \
	$C/src/ocean/util/container/more/StackMap.d

# This is an integration test that depends on Collectd -- Don't run it
TEST_FILTER_OUT += $C/test/collectd/main.d

# integration test which is temporarily disabled due to flakiness
# to be fixed and re-enabled
TEST_FILTER_OUT += \
	$C/test/signalfd/main.d 

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-selectlistener: override LDFLAGS += -lebtree

$O/test-unixlistener: override LDFLAGS += -lebtree

$O/test-loggerstats: override LDFLAGS += -lebtree

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
