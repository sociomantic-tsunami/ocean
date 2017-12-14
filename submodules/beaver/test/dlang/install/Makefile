ifndef DC
    $(error DC variable is not defined)
endif

ifndef DVER
    $(error DVER variable is not defined)
endif

.PHONY: all test d2conv

d2conv:
	test "$(DVER)" = 2
	echo 'We just made "d2conv"' > make-d2conv.stamp

all:
	test -f /BUILT-1-Dockerfile -a -f /BUILT-2-build
	echo 'We just made "all"' > make-all.stamp

unittest integrationtest:
	$(DC) -run hello.d
	dmd --version | grep -q 2.067.1
	echo 'We just made "$@"' > make-$@.stamp
