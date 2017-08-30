# This will make D2 unittests fail if stomping prevention is triggered
export ASSERT_ON_STOMPING_PREVENTION=1

override DFLAGS += -w -version=GLIBC

# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -or course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

# Do we want coverage report?
ifeq ($(AFTER_SCRIPT),1)
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

# integration test which is disabled by default because it depends on Collectd
TEST_FILTER_OUT += \
	$C/test/collectd/main.d

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-selectlistener: override LDFLAGS += -lebtree

$O/test-unixlistener: override LDFLAGS += -lebtree

$O/test-loggerstats: override LDFLAGS += -lebtree

$O/test-signalext: override LDFLAGS += -lebtree

$O/test-sysstats: override LDFLAGS += -lebtree

$O/test-timerext: override LDFLAGS += -lebtree

$O/test-httpserver: override LDFLAGS += -lebtree -lglib-2.0

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
# Enable coverage generation from unittests
$O/%unittests: override DFLAGS += $(COVFLAG)
