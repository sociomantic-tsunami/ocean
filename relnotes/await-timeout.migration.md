## Using `Scheduler` requires linking ebtree

Any app using the scheduler is now required to add `-L-lebtree` to its linker
flags. Previously it was only the case if timer util module was imported.
