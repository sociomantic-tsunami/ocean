override DFLAGS += -w -version=GLIBC

# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -or course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

ifeq ($(DVER),1)
override DFLAGS := $(filter-out -di,$(DFLAGS)) -v2 -v2=-static-arr-params -v2=-volatile
else
# Open source Makd uses dmd by default
DC = dmd
override DFLAGS += -de
endif

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$C/src/ocean/core/Array_tango.d \
	$C/src/ocean/text/xml/Xslt.d \
	$C/src/ocean/text/xml/c/LibXslt.d \
	$C/src/ocean/text/xml/c/LibXml2.d \
	$C/src/ocean/io/serialize/XmlStructSerializer.d

# This is an integration test that depends on Collectd -- Don't run it
TEST_FILTER_OUT += $C/test/collectd/main.d

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-selectlistener: override LDFLAGS += -lebtree

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
