# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -of course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

# This will make D2 unittests fail if stomping prevention is triggered
# (only with dmd-transitional, no effect on other compilers)
export ASSERT_ON_STOMPING_PREVENTION=1

# Common D compiler flags
override DFLAGS += -I$C/submodules/openssl/source/ -w -version=GLIBC

# Treat deprecations as errors to ensure ocean doesn't use own deprecated
# symbols internally. Disable it on explicit flag to make possible regression
# testing in D upstream.
ifneq ($(ALLOW_DEPRECATIONS),1)
	override DFLAGS += -de
endif

# Enables https://github.com/sociomantic-tsunami/ocean/blob/v6.x.x/src/ocean/net/ssl/openssl/OpenSsl.d#L529
 ifeq ($(OPENSSL_V3),1)
     override DFLAGS += -version=DeimosOpenSSL_3_0
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
# TODO: Remove the specific version of libssl and libcrypto once the bindings
# for libssl have been updated to v1.1.x
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt \
		-lssl -lcrypto

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$C/src/ocean/stdc/string.d \
	$C/src/ocean/util/log/LayoutDate.d
