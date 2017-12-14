# This will make D2 unittests fail if stomping prevention is triggered
# (only with dmd-transitional, no effect on other compilers)
export ASSERT_ON_STOMPING_PREVENTION=1

# Common D compiler flags
override DFLAGS += -w -version=GLIBC -debug=ISelectClient

# Enable coverage report in CI
ifdef CI
COVFLAG := -cov
endif
