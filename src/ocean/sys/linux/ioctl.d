/*******************************************************************************

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.sys.linux.ioctl;

extern (C):

int ioctl(int d, int request, ...);

// This is a compiled list of available request ioctls from ioctl_list(2)
// See the man page for details.

enum
{

       // <include/asm-i386/socket.h>

       FIOSETOWN    = 0x00008901,   // const int *
       SIOCSPGRP    = 0x00008902,   // const int *
       FIOGETOWN    = 0x00008903,   // int *
       SIOCGPGRP    = 0x00008904,   // int *
       SIOCATMAR    = 0x00008905,   // int *
       SIOCGSTAMP   = 0x00008906,   // timeval *

       // <include/asm-i386/termios.h>

       TCGETS            = 0x00005401,   // struct termios *
       TCSETS            = 0x00005402,   // const struct termios *
       TCSETSW           = 0x00005403,   // const struct termios *
       TCSETSF           = 0x00005404,   // const struct termios *
       TCGETA            = 0x00005405,   // struct termio *
       TCSETA            = 0x00005406,   // const struct termio *
       TCSETAW           = 0x00005407,   // const struct termio *

       TCSETAF           = 0x00005408,   // const struct termio *
       TCSBRK            = 0x00005409,   // int
       TCXONC            = 0x0000540A,   // int
       TCFLSH            = 0x0000540B,   // int
       TIOCEXCL          = 0x0000540C,   // void
       TIOCNXCL          = 0x0000540D,   // void
       TIOCSCTTY         = 0x0000540E,   // int
       TIOCGPGRP         = 0x0000540F,   // pid_t *
       TIOCSPGRP         = 0x00005410,   // const pid_t *
       TIOCOUTQ          = 0x00005411,   // int *
       TIOCSTI           = 0x00005412,   // const char *
       TIOCGWINSZ        = 0x00005413,   // struct winsize *
       TIOCSWINSZ        = 0x00005414,   // const struct winsize *
       TIOCMGET          = 0x00005415,   // int *
       TIOCMBIS          = 0x00005416,   // const int *
       TIOCMBIC          = 0x00005417,   // const int *
       TIOCMSET          = 0x00005418,   // const int *
       TIOCGSOFTCAR      = 0x00005419,   // int *
       TIOCSSOFTCAR      = 0x0000541A,   // const int *
       FIONREAD          = 0x0000541B,   // int *
       TIOCINQ           = 0x0000541B,   // int *
       TIOCLINUX         = 0x0000541C,   // const char *                             // MORE
       TIOCCONS          = 0x0000541D,   // void
       TIOCGSERIAL       = 0x0000541E,   // struct serial_struct *
       TIOCSSERIAL       = 0x0000541F,   // const struct serial_struct *
       TIOCPKT           = 0x00005420,   // const int *
       FIONBIO           = 0x00005421,   // const int *
       TIOCNOTTY         = 0x00005422,   // void
       TIOCSETD          = 0x00005423,   // const int *
       TIOCGETD          = 0x00005424,   // int *
       TCSBRKP           = 0x00005425,   // int
       TIOCTTYGSTRUCT    = 0x00005426,   // struct tty_struct *
       FIONCLEX          = 0x00005450,   // void
       FIOCLEX           = 0x00005451,   // void
       FIOASYNC          = 0x00005452,   // const int *
       TIOCSERCONFIG     = 0x00005453,   // void
       TIOCSERGWILD      = 0x00005454,   // int *
       TIOCSERSWILD      = 0x00005455,   // const int *
       TIOCGLCKTRMIOS    = 0x00005456,   // struct termios *
       TIOCSLCKTRMIOS    = 0x00005457,   // const struct termios *
       TIOCSERGSTRUCT    = 0x00005458,   // struct async_struct *
       TIOCSERGETLSR     = 0x00005459,   // int *
       TIOCSERGETMULTI   = 0x0000545A,   // struct serial_multiport_struct *
       TIOCSERSETMULTI   = 0x0000545B,   // const struct serial_multiport_struct *

       // <include/linux/ax25.h>

       SIOCAX25GETUID     = 0x000089E0,   // const struct sockaddr_ax25 *
       SIOCAX25ADDUID     = 0x000089E1,   // const struct sockaddr_ax25 *
       SIOCAX25DELUID     = 0x000089E2,   // const struct sockaddr_ax25 *
       SIOCAX25NOUID      = 0x000089E3,   // const int *
       SIOCAX25DIGCTL     = 0x000089E4,   // const int *
       SIOCAX25GETPARMS   = 0x000089E5,   // struct ax25_parms_struct *         // I-O
       SIOCAX25SETPARMS   = 0x000089E6,   // const struct ax25_parms_struct *

       // <include/linux/cdk.h>

       STL_BINTR    = 0x00007314,   // void
       STL_BSTART   = 0x00007315,   // void
       STL_BSTOP    = 0x00007316,   // void
       STL_BRESET   = 0x00007317,   // void

       // <include/linux/cdrom.h>

       CDROMPAUSE          = 0x00005301,   // void

       CDROMRESUME         = 0x00005302,   // void
       CDROMPLAYMSF        = 0x00005303,   // const struct cdrom_msf *
       CDROMPLAYTRKIND     = 0x00005304,   // const struct cdrom_ti *
       CDROMREADTOCHDR     = 0x00005305,   // struct cdrom_tochdr *
       CDROMREADTOCENTRY   = 0x00005306,   // struct cdrom_tocentry *           // I-O
       CDROMSTOP           = 0x00005307,   // void
       CDROMSTART          = 0x00005308,   // void
       CDROMEJECT          = 0x00005309,   // void
       CDROMVOLCTRL        = 0x0000530A,   // const struct cdrom_volctrl *
       CDROMSUBCHNL        = 0x0000530B,   // struct cdrom_subchnl *            // I-O
       CDROMREADMODE2      = 0x0000530C,   // const struct cdrom_msf *          // MORE
       CDROMREADMODE1      = 0x0000530D,   // const struct cdrom_msf *          // MORE
       CDROMREADAUDIO      = 0x0000530E,   // const struct cdrom_read_audio *   // MORE
       CDROMEJECT_SW       = 0x0000530F,   // int
       CDROMMULTISESSION   = 0x00005310,   // struct cdrom_multisession *       // I-O
       CDROM_GET_UPC       = 0x00005311,   // struct { char [8]; } *
       CDROMRESET          = 0x00005312,   // void
       CDROMVOLREAD        = 0x00005313,   // struct cdrom_volctrl *
       CDROMREADRAW        = 0x00005314,   // const struct cdrom_msf *          // MORE
       CDROMREADCOOKED     = 0x00005315,   // const struct cdrom_msf *          // MORE
       CDROMSEEK           = 0x00005316,   // const struct cdrom_msf *

       // <include/linux/cm206.h>

       CM206CTL_GET_STAT        = 0x00002000,   // int
       CM206CTL_GET_LAST_STAT   = 0x00002001,   // int

       // <include/linux/cyclades.h>

       CYGETMON          = 0x00435901,   // struct cyclades_monitor *
       CYGETTHRESH       = 0x00435902,   // int *
       CYSETTHRESH       = 0x00435903,   // int
       CYGETDEFTHRESH    = 0x00435904,   // int *
       CYSETDEFTHRESH    = 0x00435905,   // int
       CYGETTIMEOUT      = 0x00435906,   // int *
       CYSETTIMEOUT      = 0x00435907,   // int
       CYGETDEFTIMEOUT   = 0x00435908,   // int *
       CYSETDEFTIMEOUT   = 0x00435909,   // int

       // <include/linux/ext2_fs.h>

       EXT2_IOC_GETFLAGS     = 0x80046601,   // int *
       EXT2_IOC_SETFLAGS     = 0x40046602,   // const int *
       EXT2_IOC_GETVERSION   = 0x80047601,   // int *
       EXT2_IOC_SETVERSION   = 0x40047602,   // const int *

       // <include/linux/fd.h>

       FDCLRPRM         = 0x00000000,   // void
       FDSETPRM         = 0x00000001,   // const struct floppy_struct *
       FDDEFPRM         = 0x00000002,   // const struct floppy_struct *
       FDGETPRM         = 0x00000003,   // struct floppy_struct *
       FDMSGON          = 0x00000004,   // void
       FDMSGOFF         = 0x00000005,   // void
       FDFMTBEG         = 0x00000006,   // void
       FDFMTTRK         = 0x00000007,   // const struct format_descr *
       FDFMTEND         = 0x00000008,   // void
       FDSETEMSGTRESH   = 0x0000000A,   // int
       FDFLUSH          = 0x0000000B,   // void
       FDSETMAXERRS     = 0x0000000C,   // const struct floppy_max_errors *
       FDGETMAXERRS     = 0x0000000E,   // struct floppy_max_errors *
       FDGETDRVTYP      = 0x00000010,   // struct { char [16]; } *
       FDSETDRVPRM      = 0x00000014,   // const struct floppy_drive_params *
       FDGETDRVPRM      = 0x00000015,   // struct floppy_drive_params *
       FDGETDRVSTAT     = 0x00000016,   // struct floppy_drive_struct *

       FDPOLLDRVSTAT    = 0x00000017,   // struct floppy_drive_struct *
       FDRESET          = 0x00000018,   // int
       FDGETFDCSTAT     = 0x00000019,   // struct floppy_fdc_state *
       FDWERRORCLR      = 0x0000001B,   // void
       FDWERRORGET      = 0x0000001C,   // struct floppy_write_errors *
       FDRAWCMD         = 0x0000001E,   // struct floppy_raw_cmd *              // MORE // I-O
       FDTWADDLE        = 0x00000028,   // void

       // <include/linux/fs.h>

       BLKROSET     = 0x0000125D,   // const int *
       BLKROGET     = 0x0000125E,   // int *
       BLKRRPART    = 0x0000125F,   // void
       BLKGETSIZE   = 0x00001260,   // unsigned long *
       BLKFLSBUF    = 0x00001261,   // void
       BLKRASET     = 0x00001262,   // int
       BLKRAGET     = 0x00001263,   // int *
       FIBMAP       = 0x00000001,   // int *             // I-O
       FIGETBSZ     = 0x00000002,   // int *

       // <include/linux/hdreg.h>

       HDIO_GETGEO             = 0x00000301,   // struct hd_geometry *
       HDIO_GET_UNMASKINTR     = 0x00000302,   // int *
       HDIO_GET_MULTCOUNT      = 0x00000304,   // int *
       HDIO_GET_IDENTITY       = 0x00000307,   // struct hd_driveid *
       HDIO_GET_KEEPSETTINGS   = 0x00000308,   // int *
       HDIO_GET_CHIPSET        = 0x00000309,   // int *
       HDIO_GET_NOWERR         = 0x0000030A,   // int *
       HDIO_GET_DMA            = 0x0000030B,   // int *
       HDIO_DRIVE_CMD          = 0x0000031F,   // int *                  // I-O
       HDIO_SET_MULTCOUNT      = 0x00000321,   // int
       HDIO_SET_UNMASKINTR     = 0x00000322,   // int
       HDIO_SET_KEEPSETTINGS   = 0x00000323,   // int
       HDIO_SET_CHIPSET        = 0x00000324,   // int
       HDIO_SET_NOWERR         = 0x00000325,   // int
       HDIO_SET_DMA            = 0x00000326,   // int

       // <include/linux/if_eql.h>

       EQL_ENSLAVE       = 0x000089F0,   // struct ifreq *   // MORE // I-O
       EQL_EMANCIPATE    = 0x000089F1,   // struct ifreq *   // MORE // I-O
       EQL_GETSLAVECFG   = 0x000089F2,   // struct ifreq *   // MORE // I-O
       EQL_SETSLAVECFG   = 0x000089F3,   // struct ifreq *   // MORE // I-O
       EQL_GETMASTRCFG   = 0x000089F4,   // struct ifreq *   // MORE // I-O
       EQL_SETMASTRCFG   = 0x000089F5,   // struct ifreq *   // MORE // I-O
       // <include/linux/if_plip.h>

       SIOCDEVPLIP   = 0x000089F0,   // struct ifreq *   // I-O

       // <include/linux/if_ppp.h>

       PPPIOCGFLAGS       = 0x00005490,   // int *
       PPPIOCSFLAGS       = 0x00005491,   // const int *
       PPPIOCGASYNCMAP    = 0x00005492,   // int *
       PPPIOCSASYNCMAP    = 0x00005493,   // const int *
       PPPIOCGUNIT        = 0x00005494,   // int *
       PPPIOCSINPSIG      = 0x00005495,   // const int *
       PPPIOCSDEBUG       = 0x00005497,   // const int *
       PPPIOCGDEBUG       = 0x00005498,   // int *
       PPPIOCGSTAT        = 0x00005499,   // struct ppp_stats *
       PPPIOCGTIME        = 0x0000549A,   // struct ppp_ddinfo *
       PPPIOCGXASYNCMAP   = 0x0000549B,   // struct { int [8]; } *
       PPPIOCSXASYNCMAP   = 0x0000549C,   // const struct { int [8]; } *

       PPPIOCSMRU         = 0x0000549D,   // const int *
       PPPIOCRASYNCMAP    = 0x0000549E,   // const int *
       PPPIOCSMAXCID      = 0x0000549F,   // const int *

       // <include/linux/ipx.h>

       SIOCAIPXITFCRT   = 0x000089E0,   // const char *
       SIOCAIPXPRISLT   = 0x000089E1,   // const char *
       SIOCIPXCFGDATA   = 0x000089E2,   // struct ipx_config_data *

       // <include/linux/kd.h>

       GIO_FONT         = 0x00004B60,   // struct { char [8192]; } *
       PIO_FONT         = 0x00004B61,   // const struct { char [8192]; } *
       GIO_FONTX        = 0x00004B6B,   // struct console_font_desc *            // MORE // I-O
       PIO_FONTX        = 0x00004B6C,   // const struct console_font_desc *      //MORE
       GIO_CMAP         = 0x00004B70,   // struct { char [48]; } *
       PIO_CMAP         = 0x00004B71,   // const struct { char [48]; }
       KIOCSOUND        = 0x00004B2F,   // int
       KDMKTONE         = 0x00004B30,   // int
       KDGETLED         = 0x00004B31,   // char *
       KDSETLED         = 0x00004B32,   // int
       KDGKBTYPE        = 0x00004B33,   // char *
       KDADDIO          = 0x00004B34,   // int                                   // MORE
       KDDELIO          = 0x00004B35,   // int                                   // MORE
       KDENABIO         = 0x00004B36,   // void                                  // MORE
       KDDISABIO        = 0x00004B37,   // void                                  // MORE
       KDSETMODE        = 0x00004B3A,   // int
       KDGETMODE        = 0x00004B3B,   // int *
       KDMAPDISP        = 0x00004B3C,   // void                                  // MORE
       KDUNMAPDISP      = 0x00004B3D,   // void                                  // MORE
       GIO_SCRNMAP      = 0x00004B40,   // struct { char [E_TABSZ]; } *
       PIO_SCRNMAP      = 0x00004B41,   // const struct { char [E_TABSZ]; } *
       GIO_UNISCRNMAP   = 0x00004B69,   // struct { short [E_TABSZ]; } *
       PIO_UNISCRNMAP   = 0x00004B6A,   // const struct { short [E_TABSZ]; } *
       GIO_UNIMAP       = 0x00004B66,   // struct unimapdesc *                   // MORE // I-O
       PIO_UNIMAP       = 0x00004B67,   // const struct unimapdesc *             // MORE
       PIO_UNIMAPCLR    = 0x00004B68,   // const struct unimapinit *
       KDGKBMODE        = 0x00004B44,   // int *
       KDSKBMODE        = 0x00004B45,   // int
       KDGKBMETA        = 0x00004B62,   // int *
       KDSKBMETA        = 0x00004B63,   // int
       KDGKBLED         = 0x00004B64,   // int *
       KDSKBLED         = 0x00004B65,   // int
       KDGKBENT         = 0x00004B46,   // struct kbentry *                      // I-O
       KDSKBENT         = 0x00004B47,   // const struct kbentry *
       KDGKBSENT        = 0x00004B48,   // struct kbsentry *                     // I-O
       KDSKBSENT        = 0x00004B49,   // const struct kbsentry *
       KDGKBDIACR       = 0x00004B4A,   // struct kbdiacrs *
       KDSKBDIACR       = 0x00004B4B,   // const struct kbdiacrs *
       KDGETKEYCODE     = 0x00004B4C,   // struct kbkeycode *                    // I-O
       KDSETKEYCODE     = 0x00004B4D,   // const struct kbkeycode *
       KDSIGACCEPT      = 0x00004B4E,   // int

       // <include/linux/lp.h>

       LPCHAR        = 0x00000601,   // int
       LPTIME        = 0x00000602,   // int
       LPABORT       = 0x00000604,   // int
       LPSETIRQ      = 0x00000605,   // int
       LPGETIRQ      = 0x00000606,   // int *
       LPWAIT        = 0x00000608,   // int
       LPCAREFUL     = 0x00000609,   // int
       LPABORTOPEN   = 0x0000060A,   // int
       LPGETSTATUS   = 0x0000060B,   // int *

       LPRESET       = 0x0000060C,   // void
       LPGETSTATS    = 0x0000060D,   // struct lp_stats *

       // <include/linux/mroute.h>

       SIOCGETVIFCNT   = 0x000089E0,   // struct sioc_vif_req *   // I-O
       SIOCGETSGCNT    = 0x000089E1,   // struct sioc_sg_req *    // I-O

       // <include/linux/mtio.h>

       MTIOCTOP         = 0x40086D01,   // const struct mtop *
       MTIOCGET         = 0x801C6D02,   // struct mtget *
       MTIOCPOS         = 0x80046D03,   // struct mtpos *
       MTIOCGETCONFIG   = 0x80206D04,   // struct mtconfiginfo *
       MTIOCSETCONFIG   = 0x40206D05,   // const struct mtconfiginfo *

       // <include/linux/netrom.h>

       SIOCNRGETPARMS   = 0x000089E0,   // struct nr_parms_struct *         // I-O
       SIOCNRSETPARMS   = 0x000089E1,   // const struct nr_parms_struct *
       SIOCNRDECOBS     = 0x000089E2,   // void
       SIOCNRRTCTL      = 0x000089E3,   // const int *

       // <include/linux/sbpcd.h>

       DDIOCSDBG          = 0x00009000,   // const int *
       CDROMAUDIOBUFSIZ   = 0x00005382,   // int

       // <include/linux/scc.h>

       TIOCSCCINI    = 0x00005470,   // void
       TIOCCHANINI   = 0x00005471,   // const struct scc_modem *
       TIOCGKISS     = 0x00005472,   // struct ioctl_command *         // I-O
       TIOCSKISS     = 0x00005473,   // const struct ioctl_command *
       TIOCSCCSTAT   = 0x00005474,   // struct scc_stat *

       // <include/linux/scsi.h>

       SCSI_IOCTL_GET_IDLUN        = 0x00005382,   // struct { int [2]; } *
       SCSI_IOCTL_TAGGED_ENABLE    = 0x00005383,   // void
       SCSI_IOCTL_TAGGED_DISABLE   = 0x00005384,   // void
       SCSI_IOCTL_PROBE_HOST       = 0x00005385,   // const int *             // MORE

       // <include/linux/smb_fs.h>

       SMB_IOC_GETMOUNTUID   = 0x80027501,   // uid_t *

       // <include/linux/sockios.h>

       SIOCADDRT           = 0x0000890B,   // const struct rtentry *   // MORE
       SIOCDELRT           = 0x0000890C,   // const struct rtentry *   // MORE
       SIOCGIFNAME         = 0x00008910,   // char []
       SIOCSIFLINK         = 0x00008911,   // void
       SIOCGIFCONF         = 0x00008912,   // struct ifconf *          // MORE // I-O
       SIOCGIFFLAGS        = 0x00008913,   // struct ifreq *           // I-O
       SIOCSIFFLAGS        = 0x00008914,   // const struct ifreq *
       SIOCGIFADDR         = 0x00008915,   // struct ifreq *           // I-O
       SIOCSIFADDR         = 0x00008916,   // const struct ifreq *
       SIOCGIFDSTADDR      = 0x00008917,   // struct ifreq *           // I-O
       SIOCSIFDSTADDR      = 0x00008918,   // const struct ifreq *
       SIOCGIFBRDADDR      = 0x00008919,   // struct ifreq *           // I-O
       SIOCSIFBRDADDR      = 0x0000891A,   // const struct ifreq *
       SIOCGIFNETMASK      = 0x0000891B,   // struct ifreq *           // I-O
       SIOCSIFNETMASK      = 0x0000891C,   // const struct ifreq *
       SIOCGIFMETRIC       = 0x0000891D,   // struct ifreq *           // I-O

       SIOCSIFMETRIC       = 0x0000891E,   // const struct ifreq *
       SIOCGIFMEM          = 0x0000891F,   // struct ifreq *           // I-O
       SIOCSIFMEM          = 0x00008920,   // const struct ifreq *
       SIOCGIFMTU          = 0x00008921,   // struct ifreq *           // I-O
       SIOCSIFMTU          = 0x00008922,   // const struct ifreq *
       OLD_SIOCGIFHWADDR   = 0x00008923,   // struct ifreq *           // I-O
       SIOCSIFHWADDR       = 0x00008924,   // const struct ifreq *     // MORE
       SIOCGIFENCAP        = 0x00008925,   // int *
       SIOCSIFENCAP        = 0x00008926,   // const int *
       SIOCGIFHWADDR       = 0x00008927,   // struct ifreq *           // I-O
       SIOCGIFSLAVE        = 0x00008929,   // void
       SIOCSIFSLAVE        = 0x00008930,   // void
       SIOCADDMULTI        = 0x00008931,   // const struct ifreq *
       SIOCDELMULTI        = 0x00008932,   // const struct ifreq *
       SIOCADDRTOLD        = 0x00008940,   // void
       SIOCDELRTOLD        = 0x00008941,   // void
       SIOCDARP            = 0x00008950,   // const struct arpreq *
       SIOCGARP            = 0x00008951,   // struct arpreq *          // I-O
       SIOCSARP            = 0x00008952,   // const struct arpreq *
       SIOCDRARP           = 0x00008960,   // const struct arpreq *
       SIOCGRARP           = 0x00008961,   // struct arpreq *          // I-O
       SIOCSRARP           = 0x00008962,   // const struct arpreq *
       SIOCGIFMAP          = 0x00008970,   // struct ifreq *           // I-O
       SIOCSIFMAP          = 0x00008971,   // const struct ifreq *

       // <include/linux/soundcard.h>

       SNDCTL_SEQ_RESET              = 0x00005100,   // void
       SNDCTL_SEQ_SYNC               = 0x00005101,   // void
       SNDCTL_SYNTH_INFO             = 0xC08C5102,   // struct synth_info *             // I-O
       SNDCTL_SEQ_CTRLRATE           = 0xC0045103,   // int *                           // I-O
       SNDCTL_SEQ_GETOUTCOUNT        = 0x80045104,   // int *
       SNDCTL_SEQ_GETINCOUNT         = 0x80045105,   // int *
       SNDCTL_SEQ_PERCMODE           = 0x40045106,   // void
       SNDCTL_FM_LOAD_INSTR          = 0x40285107,   // const struct sbi_instrument *
       SNDCTL_SEQ_TESTMIDI           = 0x40045108,   // const int *
       SNDCTL_SEQ_RESETSAMPLES       = 0x40045109,   // const int *
       SNDCTL_SEQ_NRSYNTHS           = 0x8004510A,   // int *
       SNDCTL_SEQ_NRMIDIS            = 0x8004510B,   // int *
       SNDCTL_MIDI_INFO              = 0xC074510C,   // struct midi_info *              // I-O
       SNDCTL_SEQ_THRESHOLD          = 0x4004510D,   // const int *
       SNDCTL_SYNTH_MEMAVL           = 0xC004510E,   // int *                           // I-O
       SNDCTL_FM_4OP_ENABLE          = 0x4004510F,   // const int *
       SNDCTL_PMGR_ACCESS            = 0xCFB85110,   // struct patmgr_info *            // I-O
       SNDCTL_SEQ_PANIC              = 0x00005111,   // void
       SNDCTL_SEQ_OUTOFBAND          = 0x40085112,   // const struct seq_event_rec *
       SNDCTL_TMR_TIMEBASE           = 0xC0045401,   // int *                           // I-O
       SNDCTL_TMR_START              = 0x00005402,   // void
       SNDCTL_TMR_STOP               = 0x00005403,   // void
       SNDCTL_TMR_CONTINUE           = 0x00005404,   // void
       SNDCTL_TMR_TEMPO              = 0xC0045405,   // int *                           // I-O
       SNDCTL_TMR_SOURCE             = 0xC0045406,   // int *                           // I-O
       SNDCTL_TMR_METRONOME          = 0x40045407,   // const int *
       SNDCTL_TMR_SELECT             = 0x40045408,   // int *                           // I-O
       SNDCTL_PMGR_IFACE             = 0xCFB85001,   // struct patmgr_info *            // I-O
       SNDCTL_MIDI_PRETIME           = 0xC0046D00,   // int *                           // I-O
       SNDCTL_MIDI_MPUMODE           = 0xC0046D01,   // const int *
       SNDCTL_MIDI_MPUCMD            = 0xC0216D02,   // struct mpu_command_rec *        // I-O
       SNDCTL_DSP_RESET              = 0x00005000,   // void
       SNDCTL_DSP_SYNC               = 0x00005001,   // void
       SNDCTL_DSP_SPEED              = 0xC0045002,   // int *                           // I-O
       SNDCTL_DSP_STEREO             = 0xC0045003,   // int *                           // I-O
       SNDCTL_DSP_GETBLKSIZE         = 0xC0045004,   // int *                           // I-O
       SOUND_PCM_WRITE_CHANNELS      = 0xC0045006,   // int *                           // I-O
       SOUND_PCM_WRITE_FILTER        = 0xC0045007,   // int *                           // I-O

       SNDCTL_DSP_POST               = 0x00005008,   // void
       SNDCTL_DSP_SUBDIVIDE          = 0xC0045009,   // int *                           // I-O
       SNDCTL_DSP_SETFRAGMENT        = 0xC004500A,   // int *                           // I-O
       SNDCTL_DSP_GETFMTS            = 0x8004500B,   // int *
       SNDCTL_DSP_SETFMT             = 0xC0045005,   // int *                           // I-O
       SNDCTL_DSP_GETOSPACE          = 0x800C500C,   // struct audio_buf_info *
       SNDCTL_DSP_GETISPACE          = 0x800C500D,   // struct audio_buf_info *
       SNDCTL_DSP_NONBLOCK           = 0x0000500E,   // void
       SOUND_PCM_READ_RATE           = 0x80045002,   // int *
       SOUND_PCM_READ_CHANNELS       = 0x80045006,   // int *
       SOUND_PCM_READ_BITS           = 0x80045005,   // int *
       SOUND_PCM_READ_FILTER         = 0x80045007,   // int *
       SNDCTL_COPR_RESET             = 0x00004300,   // void
       SNDCTL_COPR_LOAD              = 0xCFB04301,   // const struct copr_buffer *
       SNDCTL_COPR_RDATA             = 0xC0144302,   // struct copr_debug_buf *         // I-O
       SNDCTL_COPR_RCODE             = 0xC0144303,   // struct copr_debug_buf *         // I-O
       SNDCTL_COPR_WDATA             = 0x40144304,   // const struct copr_debug_buf *
       SNDCTL_COPR_WCODE             = 0x40144305,   // const struct copr_debug_buf *
       SNDCTL_COPR_RUN               = 0xC0144306,   // struct copr_debug_buf *         // I-O
       SNDCTL_COPR_HALT              = 0xC0144307,   // struct copr_debug_buf *         // I-O
       SNDCTL_COPR_SENDMSG           = 0x4FA44308,   // const struct copr_msg *
       SNDCTL_COPR_RCVMSG            = 0x8FA44309,   // struct copr_msg *
       SOUND_MIXER_READ_VOLUME       = 0x80044D00,   // int *
       SOUND_MIXER_READ_BASS         = 0x80044D01,   // int *
       SOUND_MIXER_READ_TREBLE       = 0x80044D02,   // int *
       SOUND_MIXER_READ_SYNTH        = 0x80044D03,   // int *
       SOUND_MIXER_READ_PCM          = 0x80044D04,   // int *
       SOUND_MIXER_READ_SPEAKER      = 0x80044D05,   // int *
       SOUND_MIXER_READ_LINE         = 0x80044D06,   // int *
       SOUND_MIXER_READ_MIC          = 0x80044D07,   // int *
       SOUND_MIXER_READ_CD           = 0x80044D08,   // int *
       SOUND_MIXER_READ_IMIX         = 0x80044D09,   // int *
       SOUND_MIXER_READ_ALTPCM       = 0x80044D0A,   // int *
       SOUND_MIXER_READ_RECLEV       = 0x80044D0B,   // int *
       SOUND_MIXER_READ_IGAIN        = 0x80044D0C,   // int *
       SOUND_MIXER_READ_OGAIN        = 0x80044D0D,   // int *
       SOUND_MIXER_READ_LINE1        = 0x80044D0E,   // int *
       SOUND_MIXER_READ_LINE2        = 0x80044D0F,   // int *
       SOUND_MIXER_READ_LINE3        = 0x80044D10,   // int *
       SOUND_MIXER_READ_MUTE         = 0x80044D1C,   // int *
       SOUND_MIXER_READ_ENHANCE      = 0x80044D1D,   // int *
       SOUND_MIXER_READ_LOUD         = 0x80044D1E,   // int *
       SOUND_MIXER_READ_RECSRC       = 0x80044DFF,   // int *
       SOUND_MIXER_READ_DEVMASK      = 0x80044DFE,   // int *
       SOUND_MIXER_READ_RECMASK      = 0x80044DFD,   // int *
       SOUND_MIXER_READ_STEREODEVS   = 0x80044DFB,   // int *
       SOUND_MIXER_READ_CAPS         = 0x80044DFC,   // int *
       SOUND_MIXER_WRITE_VOLUME      = 0xC0044D00,   // int *                           // I-O
       SOUND_MIXER_WRITE_BASS        = 0xC0044D01,   // int *                           // I-O
       SOUND_MIXER_WRITE_TREBLE      = 0xC0044D02,   // int *                           // I-O
       SOUND_MIXER_WRITE_SYNTH       = 0xC0044D03,   // int *                           // I-O
       SOUND_MIXER_WRITE_PCM         = 0xC0044D04,   // int *                           // I-O
       SOUND_MIXER_WRITE_SPEAKER     = 0xC0044D05,   // int *                           // I-O
       SOUND_MIXER_WRITE_LINE        = 0xC0044D06,   // int *                           // I-O
       SOUND_MIXER_WRITE_MIC         = 0xC0044D07,   // int *                           // I-O
       SOUND_MIXER_WRITE_CD          = 0xC0044D08,   // int *                           // I-O
       SOUND_MIXER_WRITE_IMIX        = 0xC0044D09,   // int *                           // I-O
       SOUND_MIXER_WRITE_ALTPCM      = 0xC0044D0A,   // int *                           // I-O
       SOUND_MIXER_WRITE_RECLEV      = 0xC0044D0B,   // int *                           // I-O
       SOUND_MIXER_WRITE_IGAIN       = 0xC0044D0C,   // int *                           // I-O
       SOUND_MIXER_WRITE_OGAIN       = 0xC0044D0D,   // int *                           // I-O
       SOUND_MIXER_WRITE_LINE1       = 0xC0044D0E,   // int *                           // I-O
       SOUND_MIXER_WRITE_LINE2       = 0xC0044D0F,   // int *                           // I-O
       SOUND_MIXER_WRITE_LINE3       = 0xC0044D10,   // int *                           // I-O
       SOUND_MIXER_WRITE_MUTE        = 0xC0044D1C,   // int *                           // I-O

       SOUND_MIXER_WRITE_ENHANCE     = 0xC0044D1D,   // int *                           // I-O
       SOUND_MIXER_WRITE_LOUD        = 0xC0044D1E,   // int *                           // I-O
       SOUND_MIXER_WRITE_RECSRC      = 0xC0044DFF,   // int *                           // I-O

       // <include/linux/umsdos_fs.h>

       UMSDOS_READDIR_DOS   = 0x000004D2,   // struct umsdos_ioctl *         // I-O
       UMSDOS_UNLINK_DOS    = 0x000004D3,   // const struct umsdos_ioctl *
       UMSDOS_RMDIR_DOS     = 0x000004D4,   // const struct umsdos_ioctl *
       UMSDOS_STAT_DOS      = 0x000004D5,   // struct umsdos_ioctl *         // I-O
       UMSDOS_CREAT_EMD     = 0x000004D6,   // const struct umsdos_ioctl *
       UMSDOS_UNLINK_EMD    = 0x000004D7,   // const struct umsdos_ioctl *
       UMSDOS_READDIR_EMD   = 0x000004D8,   // struct umsdos_ioctl *         // I-O
       UMSDOS_GETVERSION    = 0x000004D9,   // struct umsdos_ioctl *
       UMSDOS_INIT_EMD      = 0x000004DA,   // void
       UMSDOS_DOS_SETUP     = 0x000004DB,   // const struct umsdos_ioctl *
       UMSDOS_RENAME_DOS    = 0x000004DC,   // const struct umsdos_ioctl *

       // <include/linux/vt.h>

       VT_OPENQRY       = 0x00005600,   // int *
       VT_GETMODE       = 0x00005601,   // struct vt_mode *
       VT_SETMODE       = 0x00005602,   // const struct vt_mode *
       VT_GETSTATE      = 0x00005603,   // struct vt_stat *
       VT_SENDSIG       = 0x00005604,   // void
       VT_RELDISP       = 0x00005605,   // int
       VT_ACTIVATE      = 0x00005606,   // int
       VT_WAITACTIVE    = 0x00005607,   // int
       VT_DISALLOCATE   = 0x00005608,   // int
       VT_RESIZE        = 0x00005609,   // const struct vt_sizes *
       VT_RESIZEX       = 0x0000560A,   // const struct vt_consize *

}

