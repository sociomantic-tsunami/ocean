/********************************************************************************

    Helper class for buffered input using a consumer callback.

    Copyright:
        Copyright (c) 2017 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

/*******************************************************************************/

module ocean.io.select.protocol.task.internal.BufferedReader;

class BufferedReader
{
    /***************************************************************************

        Default input buffer size (16 kB).

    ***************************************************************************/

    public const size_t default_read_buffer_size = 1U << 14;

    /***************************************************************************

        Data buffer

    ***************************************************************************/

    private void[] data;

    /***************************************************************************

        End index of available and consumed data.

        Available data is data received by receive() or read() and not yet
        consumed by the consumer delegate passed to consume() or read().
        Consumed data is data received by receive() or read() and already
        consumed by the consumer delegate passed to consume() or read().

    ***************************************************************************/

    private size_t available = 0,
                   consumed  = 0;

    /***************************************************************************

        Invariant to assure consumed/available are in correct order and range

    ***************************************************************************/

    invariant()
    {
        assert(this.available <= this.data.length);
        assert(this.consumed  <= this.data.length);
        assert(this.consumed  <= available);
    }

    /***************************************************************************

        Constructor.

        Params:
            read_buffer_size = read buffer size

    ***************************************************************************/

    public this ( size_t read_buffer_size = default_read_buffer_size )
    in
    {
        assert(default_read_buffer_size, "zero input buffer size specified");
    }
    body
    {
        this.data = new ubyte[read_buffer_size];
    }

    /***************************************************************************

        Resets the amount of consumed/available data to 0.

    ***************************************************************************/

    public void reset ( )
    {
        this.consumed  = 0;
        this.available = 0;
    }

    /***************************************************************************

        Calls `consume` with data obtained from `io_read`, and calls `io_read`
        to obtain more data if `consume` needs it.

        `ioread` should read `n` bytes (where `0 < n <= dst.length`) of data,
        store them in `dst[0 .. n]` and return `n`.

        If `consume` feels that the amount of `data` passed to it is sufficient
        it should return the number of bytes it consumed, which is a value
        between 0 and `data.length` (inclusive). Otherwise, if `consume`
        consumed all `data` and still needs more data from the I/O device, it
        should return a value greater than `data.`length`; it will then called
        again after more data have been received.

        Params:
            consume = consumer callback delegate
            ioread  = I/O read callback delegate

    ***************************************************************************/

    public void readConsume ( size_t delegate ( void[] data ) consume,
        size_t delegate ( void[] dst ) ioread )
    {
        while (!this.available)
            this.available = ioread(this.data);

        while (true)
        {
            auto available_data = this.data[this.consumed .. this.available];
            auto n = consume(available_data);

            if (n > available_data.length)
            {
                this.consumed = 0;
                this.available = ioread(this.data);
            }
            else
            {
                this.consumed += n;
                break;
            }
        }

        if (this.consumed == this.available)
            this.consumed = this.available = 0;
    }

    /***************************************************************************

        Populates all bytes in `dst` with data obtained from `ioread`, and calls
        `ioread` to obtain more data if needed.

        `ioread` should read `n` bytes (where
        `0 < n <= dst_a.length + dst_b.length`) of data, store them in
          - `dst_a[0 .. n]` if `n <= dst_a.length` or
          - `dst_a` and `dst_b[0 .. n - dst_a.length] if `n > dst_a.length`
        and return `n`.

        Params:
            dst    = destination buffer
            ioread = I/O read callback delegate

    ***************************************************************************/

    public void readRaw ( void[] dst, size_t delegate ( void[] dst_a, void[] dst_b ) ioread )
    {
        auto available_data = this.data[this.consumed .. this.available];

        if (available_data.length >= dst.length)
        {
            dst[] = available_data[0 .. dst.length];
            this.consumed += dst.length;

            if (this.consumed == this.available)
                this.available = this.consumed = 0;
        }
        else
        {
            dst[0 .. available_data.length] = available_data;
            dst = dst[available_data.length .. $];
            this.available = this.consumed = 0;

            size_t n = ioread(dst, this.data);
            while (n < dst.length)
                n += ioread(dst[n .. $], this.data);

            this.available = n - dst.length;
        }
    }
}
