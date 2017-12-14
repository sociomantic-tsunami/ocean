ifndef DC
    $(error DC variable is not defined)
endif

ifndef DVER
    $(error DVER variable is not defined)
endif

ifndef D2_ONLY
    $(error D2_ONLY variable is not defined)
endif

.PHONY: all test d2conv

all:
	echo 'We just made "all"' > make-all.stamp

unittest integrationtest:
	echo 'We just made "$@"' > make-$@.stamp

d2conv:
	echo 'We just made "d2conv"' > make-d2conv.stamp
