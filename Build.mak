# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -of course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

# This will make D2 unittests fail if stomping prevention is triggered
# (only with dmd-transitional, no effect on other compilers)
export ASSERT_ON_STOMPING_PREVENTION=1

# Common D compiler flags
override DFLAGS += -w -version=GLIBC -dip25

# Treat deprecations as errors to ensure ocean doesn't use own deprecated
# symbols internally. Disable it on explicit flag to make possible regression
# testing in D upstream.
ifneq ($(ALLOW_DEPRECATIONS),1)
	ifeq ($(DVER),2)
	override DFLAGS += -de
	else
	override DFLAGS := $(filter-out -di,$(DFLAGS))
	endif
endif

# Remove coverage files
clean += .*.lst

$O/test-%: override LDFLAGS += -lebtree

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-httpserver: override LDFLAGS += -lglib-2.0
$O/test-asyncio: override LDFLAGS += -lglib-2.0
$O/test-signalext: override LDFLAGS += -lglib-2.0
$O/test-prometheusstats: override LDFLAGS += -lglib-2.0
$O/test-reopenfiles: override LDFLAGS += -lglib-2.0
$O/test-sysstats: override LDFLAGS += -lglib-2.0
$O/test-taskext_daemon: override LDFLAGS += -lglib-2.0
$O/test-unixsockext: override LDFLAGS += -lglib-2.0

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt \
		-lssl -lcrypto

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$C/src/ocean/core/Time.d \
	$C/src/ocean/core/Traits.d \
	$C/src/ocean/stdc/posix/arpa/inet.d \
	$C/src/ocean/stdc/posix/net/if_.d \
	$C/src/ocean/stdc/posix/netinet/in_.d \
	$C/src/ocean/stdc/posix/netinet/tcp.d \
	$C/src/ocean/stdc/posix/stdlib.d \
	$C/src/ocean/stdc/posix/sys/ipc.d \
	$C/src/ocean/stdc/posix/sys/mman.d \
	$C/src/ocean/stdc/posix/sys/select.d \
	$C/src/ocean/stdc/posix/sys/shm.d \
	$C/src/ocean/stdc/posix/sys/stat.d \
	$C/src/ocean/stdc/posix/sys/statvfs.d \
	$C/src/ocean/stdc/posix/sys/types.d \
	$C/src/ocean/stdc/posix/sys/uio.d \
	$C/src/ocean/stdc/posix/sys/utsname.d \
	$C/src/ocean/stdc/posix/sys/wait.d \
	$C/src/ocean/time/chrono/Hebrew.d \
	$C/src/ocean/time/chrono/Hijri.d \
	$C/src/ocean/time/chrono/Japanese.d \
	$C/src/ocean/time/chrono/Korean.d \
	$C/src/ocean/time/chrono/Taiwan.d \
	$C/src/ocean/time/chrono/ThaiBuddhist.d \
	$C/src/ocean/util/log/model/ILogger.d
