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

# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -or course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

# Remove coverage files
clean += .*.lst

# integration test which is disabled by default because it depends on Collectd
TEST_FILTER_OUT += \
	$C/test/collectd/main.d

$O/test-%: override LDFLAGS += -lebtree

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-httpserver: override LDFLAGS += -lglib-2.0

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
# Enable coverage generation from unittests
$O/%unittests: override DFLAGS += $(COVFLAG)
