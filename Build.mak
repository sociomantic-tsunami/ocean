# This will make D2 unittests fail if stomping prevention is triggered
export ASSERT_ON_STOMPING_PREVENTION=1

override DFLAGS += -w -version=GLIBC

# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -or course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

# Enable coverage report in CI
ifdef CI
COVFLAG:=-cov
endif

ifeq ($(DVER),1)
override DFLAGS := $(filter-out -di,$(DFLAGS)) -v2 -v2=-static-arr-params -v2=-volatile
else
# Open source Makd uses dmd by default
DC ?= dmd
override DFLAGS += -de
endif

# Remove coverage files
clean += .*.lst

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$C/src/ocean/io/Stdout_tango.d \
	$C/src/ocean/io/FilePath_tango.d \
	$C/src/ocean/core/Runtime.d \
	$C/src/ocean/core/Thread.d \
	$C/src/ocean/core/Traits_tango.d \
	$C/src/ocean/core/Vararg.d \
	$C/src/ocean/core/VersionIdentifiers.d \
	$C/src/ocean/core/Exception_tango.d \
	$C/src/ocean/io/device/SerialPort.d \
	$C/src/ocean/io/device/ProgressFile.d \
	$C/src/ocean/io/stream/Digester.d \
	$C/src/ocean/io/stream/Endian.d \
	$C/src/ocean/io/stream/Greedy.d \
	$C/src/ocean/io/stream/Map.d \
	$C/src/ocean/io/stream/Typed.d \
	$C/src/ocean/io/stream/Utf.d \
	$C/src/ocean/io/vfs/ZipFolder.d \
	$C/src/ocean/math/BigInt.d \
	$C/src/ocean/net/http/ChunkStream.d \
	$C/src/ocean/util/compress/Zip.d \
	$C/src/ocean/util/log/LayoutChainsaw.d \
	$C/src/ocean/util/log/Log.d \
	$C/src/ocean/text/convert/Memory.d \
	$C/src/ocean/text/Text.d \
	$C/src/ocean/stdc/stringz.d \
	$C/src/ocean/io/stream/Snoop.d \
	$C/src/ocean/core/_util/console.d \
	$C/src/ocean/core/_util/string.d \
	$(shell find $C/src/ocean/text/locale -type f)

# integration test which is disabled by default because it depends on Collectd
TEST_FILTER_OUT += \
	$C/test/collectd/main.d

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-selectlistener: override LDFLAGS += -lebtree

$O/test-unixlistener: override LDFLAGS += -lebtree

$O/test-loggerstats: override LDFLAGS += -lebtree

$O/test-signalext: override LDFLAGS += -lebtree

$O/test-sysstats: override LDFLAGS += -lebtree

$O/test-httpserver: override LDFLAGS += -lebtree -lglib-2.0

$O/test-unixsockext: override LDFLAGS += -lebtree

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
# Enable coverage generation from unittests
$O/%unittests: override DFLAGS += $(COVFLAG)
