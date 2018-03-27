### Print the application's version string to the control socket

`ocean.util.app.DaemonApp`

`DaemonApp`'s will now print the application's `--version` output to the control
unix socket when `show_version` command is received:

```
$ echo 'show_version' | nc -U /srv/dlsnode/dlsnode.socket dlsnode
version v1.9.0-28-gcbc6-dirty (compiled by 'Nemanja Boric' on 2018-03-27
13:00:30 UTC with DMD64 D Compiler v1.081.2 using beaver:v0.2.2
dlsproto:v13.2.0 makd:v2.2.0 ocean:v3.7.1-41-gdd24 swarm:v4.6.2 turtle:v8.4.0)
[dflags='-di -g -debug
-I/home/nemanjaboric/work/tsunami/dlsnode-1/build/devel/include -I./src
-I./submodules/swarm/src  -I./submodules/ocean/src  -I./submodules/dlsproto/src
-I./submodules/makd/src  -I./submodules/turtle/src  -I./submodules/beaver/src
-w -v2 -v2=-static-arr-params', flavour='devel',
ver_D_InlineAsm_X86_64='D_InlineAsm_X86_64', ver_D_LP64='D_LP64',
ver_DigitalMars='DigitalMars', ver_LittleEndian='LittleEndian',
ver_Posix='Posix', ver_X86_64='X86_64', ver_linux='linux']
```
