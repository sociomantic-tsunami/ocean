/*******************************************************************************

        Copyright:
            Copyright (c) 2008 Robin Kreis.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Authors: Robin Kreis

*******************************************************************************/

module ocean.io.device.SerialPort;

import ocean.transition;

import ocean.core.Array : sort;

import ocean.core.Exception_tango,
                ocean.io.device.Device,
                ocean.stdc.stringz,
                ocean.sys.Common;

import ocean.io.FilePath_tango;
import ocean.sys.linux.termios;

/*******************************************************************************

    B57600 baud rate value.

*******************************************************************************/

private const B57600 = Octal!("001001");

/*******************************************************************************

        Enables applications to use a serial port (aka COM-port, ttyS).
        Usage is similar to that of File:
        ---
        auto serCond = new SerialPort("ttyS0");
        serCond.speed = 38400;
        serCond.write("Hello world!");
        serCond.close();
        ----

*******************************************************************************/

class SerialPort : Device
{
    private istring              str;
    private static istring[]     _ports;

    /***************************************************************************

            Create a new SerialPort instance. The port will be opened and
            set to raw mode with 9600-8N1.

            Params:
            port = A string identifying the port. On Posix, this must be a
                   device file like /dev/ttyS0. If the input doesn't begin
                   with "/", "/dev/" is automatically prepended, so "ttyS0"
                   is sufficent. On Windows, this must be a device name like
                   COM1.

    ***************************************************************************/

    this (istring port)
    {
        create (port);
    }

    /***************************************************************************

            Returns a string describing this serial port.
            For example: "ttyS0", "COM1", "cuad0".

    ***************************************************************************/

    override istring toString ()
    {
        return str;
    }

    /***************************************************************************

            Sets the baud rate of this port. Usually, the baud rate can
            only be set to fixed values (common values are 1200 * 2^n).

            Note that for Posix, the specification only mandates speeds up
            to 38400, excluding speeds such as 7200, 14400 and 28800.
            Most Posix systems have chosen to support at least higher speeds
            though.

            See_also: maxSpeed

            Throws: IOException if speed is unsupported.

    ***************************************************************************/

    SerialPort speed (uint speed)
    {
        version(Posix) {
            speed_t *baud = speed in baudRates;
            if(baud is null) {
                throw new IOException("Invalid baud rate.");
            }

            termios options;
            tcgetattr(handle, &options);
            cfsetospeed(&options, *baud);
            tcsetattr(handle, TCSANOW, &options);
        }
        return this;
    }

    /***************************************************************************

            Tries to enumerate all serial ports. While this usually works on
            Windows, it's more problematic on other OS. Posix provides no way
            to list serial ports, and the only option is searching through
            "/dev".

            Because there's no naming standard for the device files, this method
            must be ported for each OS. This method is also unreliable because
            the user could have created invalid device files, or deleted them.

            Returns:
            A string array of all the serial ports that could be found, in
            alphabetical order. Every string is formatted as a valid argument
            to the constructor, but the port may not be accessible.

    ***************************************************************************/

    static istring[] ports ()
    {
        if(_ports !is null) {
            return _ports;
        }
        version(Posix) {
            auto dev = FilePath("/dev");
            FilePath[] serPorts = dev.toList((FilePath path, bool isFolder) {
                if(isFolder) return false;
                version(linux) {
                    auto r = rest(idup(path.name), "ttyUSB");
                    if(r is null) r = rest(idup(path.name), "ttyS");
                    if(r.length == 0) return false;
                    return isInRange(r, '0', '9');
                } else version (darwin) { // untested
                    auto r = rest(path.name, "cu");
                    if(r.length == 0) return false;
                    return true;
                } else version(freebsd) { // untested
                    auto r = rest(path.name, "cuaa");
                    if(r is null) r = rest(path.name, "cuad");
                    if(r.length == 0) return false;
                    return isInRange(r, '0', '9');
                } else version(openbsd) { // untested
                    auto r = rest(path.name, "tty");
                    if(r.length != 2) return false;
                    return isInRange(r, '0', '9');
                } else version(solaris) { // untested
                    auto r = rest(path.name, "tty");
                    if(r.length != 1) return false;
                    return isInRange(r, 'a', 'z');
                } else {
                    return false;
                }
            });
            _ports.length = serPorts.length;
            foreach(i, path; serPorts) {
                _ports[i] = idup(path.name);
            }
        }
        sort(_ports);
        return _ports;
    }

    version(Posix) {
        private static speed_t[uint] baudRates;

        static this()
        {
            baudRates[50] = B50;
            baudRates[75] = B75;
            baudRates[110] = B110;
            baudRates[134] = B134;
            baudRates[150] = B150;
            baudRates[200] = B200;
            baudRates[300] = B300;
            baudRates[600] = B600;
            baudRates[1200] = B1200;
            baudRates[1800] = B1800;
            baudRates[2400] = B2400;
            baudRates[9600] = B9600;
            baudRates[4800] = B4800;
            baudRates[19200] = B19200;
            baudRates[38400] = B38400;

            version( linux )
            {
                baudRates[57600] = B57600;
                baudRates[115200] = B115200;
                baudRates[230400] = B230400;
                baudRates[460800] = B460800;
                baudRates[500000] = B500000;
                baudRates[576000] = B576000;
                baudRates[921600] = B921600;
                baudRates[1000000] = B1000000;
                baudRates[1152000] = B1152000;
                baudRates[1500000] = B1500000;
                baudRates[2000000] = B2000000;
                baudRates[2500000] = B2500000;
                baudRates[3000000] = B3000000;
                baudRates[3500000] = B3500000;
                baudRates[4000000] = B4000000;
            }
            else version( freebsd )
            {
                baudRates[7200] = B7200;
                baudRates[14400] = B14400;
                baudRates[28800] = B28800;
                baudRates[57600] = B57600;
                baudRates[76800] = B76800;
                baudRates[115200] = B115200;
                baudRates[230400] = B230400;
                baudRates[460800] = B460800;
                baudRates[921600] = B921600;
            }
            else version( solaris )
            {
                baudRates[57600] = B57600;
                baudRates[76800] = B76800;
                baudRates[115200] = B115200;
                baudRates[153600] = B153600;
                baudRates[230400] = B230400;
                baudRates[307200] = B307200;
                baudRates[460800] = B460800;
            }
            else version ( darwin )
            {
                baudRates[7200] = B7200;
                baudRates[14400] = B14400;
                baudRates[28800] = B28800;
                baudRates[57600] = B57600;
                baudRates[76800] = B76800;
                baudRates[115200] = B115200;
                baudRates[230400] = B230400;
            }
        }

        private void create (istring file)
        {
            if(file.length == 0) throw new IOException("Empty port name");
            if(file[0] != '/') file = "/dev/" ~ file;

            if(file.length > 5 && file[0..5] == "/dev/")
                str = file[5..$];
            else
                str = "SerialPort@" ~ file;

            handle = posix.open(file.toStringz(), O_RDWR | O_NOCTTY | O_NONBLOCK);
            if(handle == -1) {
                error();
            }
            if(posix.fcntl(handle, F_SETFL, 0) == -1) { // disable O_NONBLOCK
                error();
            }

            termios options;
            if(tcgetattr(handle, &options) == -1) {
                error();
            }
            cfsetispeed(&options, B0); // same as output baud rate
            cfsetospeed(&options, B9600);
            makeRaw(&options); // disable echo and special characters
            tcsetattr(handle, TCSANOW, &options);
        }

        private void makeRaw (termios *options)
        {
            options.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP
                    | INLCR | IGNCR | ICRNL | IXON);
            options.c_oflag &= ~OPOST;
            options.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
            options.c_cflag &= ~(CSIZE | PARENB);
            options.c_cflag |= CS8;
        }


        private static istring rest (istring str, istring prefix) {
            if(str.length < prefix.length) return null;
            if(str[0..prefix.length] != prefix) return null;
            return str[prefix.length..$];
        }

        private static bool isInRange (istring str, char lower, char upper) {
            foreach(c; str) {
                if(c < lower || c > upper) return false;
            }
            return true;
        }
    }
}

