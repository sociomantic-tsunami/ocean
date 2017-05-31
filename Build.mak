# This will make D2 unittests fail if stomping prevention is triggered
export ASSERT_ON_STOMPING_PREVENTION=1

override DFLAGS += -w -version=GLIBC

# Makd auto-detects if Ocean's test runner should be used based on submodules,
# but we -or course- don't have Ocean as a submodule, so we set it explicitly.
TEST_RUNNER_MODULE := ocean.core.UnitTestRunner

ifeq ($(DVER),1)
override DFLAGS := $(filter-out -di,$(DFLAGS)) -v2 -v2=-static-arr-params -v2=-volatile
COVFLAG:=-cov
else
# Open source Makd uses dmd by default
DC ?= dmd
override DFLAGS += -de
COVFLAG:=
endif

# Remove coverage files
clean += *.lst

# Remove deprecated modules from testing:
TEST_FILTER_OUT += \
	$C/src/ocean/text/util/c/iconv.d \
	$C/src/ocean/core/Array_tango.d \
	$C/src/ocean/net/device/Datagram.d \
	$C/src/ocean/net/device/Multicast.d \
	$C/src/ocean/net/http/HttpClient.d \
	$C/src/ocean/net/http/HttpGet.d \
	$C/src/ocean/net/http/HttpPost.d \
	$C/src/ocean/text/xml/DocTester.d \
	$C/src/ocean/util/log/AppendMail.d \
	$C/src/ocean/util/log/AppendSocket.d \
	$C/src/ocean/util/log/ConfigProps.d \
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
	$C/src/ocean/io/device/ProgressFile.d \
	$C/src/ocean/io/device/SerialPort.d \
	$C/src/ocean/io/serialize/XmlStructSerializer.d \
	$C/src/ocean/util/container/HashMap.d \
	$C/src/ocean/util/container/more/CacheMap.d \
	$C/src/ocean/util/container/more/StackMap.d \
	$C/src/ocean/sys/linux/epoll.d \
	$C/src/ocean/sys/linux/ifaddrs.d \
	$C/src/ocean/sys/linux/inotify.d \
	$C/src/ocean/sys/linux/ioctl.d \
	$C/src/ocean/sys/linux/sched.d \
	$C/src/ocean/sys/linux/signalfd.d \
	$C/src/ocean/sys/linux/tcp.d \
	$C/src/ocean/sys/linux/termios.d \
	$C/src/ocean/sys/linux/timerfd.d \
	$C/src/ocean/sys/linux/tipc.d \
	$C/src/ocean/sys/linux/consts/errno.d \
	$C/src/ocean/sys/linux/consts/fcntl.d \
	$C/src/ocean/sys/linux/consts/socket.d \
	$C/src/ocean/sys/linux/consts/sysctl.d \
	$C/src/ocean/sys/linux/consts/unistd.d \
	$C/src/ocean/sys/consts/sysctl.d \
	$C/src/ocean/sys/consts/errno.d \
	$C/src/ocean/sys/consts/unistd.d \
	$C/src/ocean/stdc/complex.d \
	$C/src/ocean/stdc/config.d \
	$C/src/ocean/stdc/ctype.d \
	$C/src/ocean/stdc/errno.d \
	$C/src/ocean/stdc/fenv.d \
	$C/src/ocean/stdc/gnu/string.d \
	$C/src/ocean/stdc/inttypes.d \
	$C/src/ocean/stdc/limits.d \
	$C/src/ocean/stdc/locale.d \
	$C/src/ocean/stdc/math.d \
	$C/src/ocean/stdc/signal.d \
	$C/src/ocean/stdc/stdarg.d \
	$C/src/ocean/stdc/stddef.d \
	$C/src/ocean/stdc/stdint.d \
	$C/src/ocean/stdc/stdio.d \
	$C/src/ocean/stdc/stdlib.d \
	$C/src/ocean/stdc/tgmath.d \
	$C/src/ocean/stdc/time.d \
	$C/src/ocean/stdc/wctype.d \
	$C/src/ocean/stdc/posix/config.d \
	$C/src/ocean/stdc/posix/dirent.d \
	$C/src/ocean/stdc/posix/dlfcn.d \
	$C/src/ocean/stdc/posix/grp.d \
	$C/src/ocean/stdc/posix/inttypes.d \
	$C/src/ocean/stdc/posix/libgen.d \
	$C/src/ocean/stdc/posix/poll.d \
	$C/src/ocean/stdc/posix/pthread.d \
	$C/src/ocean/stdc/posix/pwd.d \
	$C/src/ocean/stdc/posix/sched.d \
	$C/src/ocean/stdc/posix/semaphore.d \
	$C/src/ocean/stdc/posix/setjmp.d \
	$C/src/ocean/stdc/posix/signal.d \
	$C/src/ocean/stdc/posix/stdio.d \
	$C/src/ocean/stdc/posix/termios.d \
	$C/src/ocean/stdc/posix/time.d \
	$C/src/ocean/stdc/posix/ucontext.d \
	$C/src/ocean/stdc/posix/unistd.d \
	$C/src/ocean/stdc/posix/utime.d \
	$C/src/ocean/io/stream/Zlib.d


# This is an integration test that depends on Collectd -- Don't run it
TEST_FILTER_OUT += $C/test/collectd/main.d

$O/test-filesystemevent: override LDFLAGS += -lrt

$O/test-selectlistener: override LDFLAGS += -lebtree

$O/test-unixlistener: override LDFLAGS += -lebtree

$O/test-loggerstats: override LDFLAGS += -lebtree

$O/test-sysstats: override LDFLAGS += -lebtree

# Link unittests to all used libraries
$O/%unittests: override LDFLAGS += -lglib-2.0 -lpcre -lxml2 -lxslt -lebtree \
		-lreadline -lhistory -llzo2 -lbz2 -lz -ldl -lgcrypt -lgpg-error -lrt
# Enable coverage generation from unittests
$O/%unittests: override DFLAGS += $(COVFLAG)
