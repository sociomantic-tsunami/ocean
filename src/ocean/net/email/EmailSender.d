/*******************************************************************************

    Class containing a single function which sends a email by spawning a child
    process that executes the command sendmail.

    Copyright:
        Copyright (c) 2009-2016 Sociomantic Labs GmbH.
        All rights reserved.

    License:
        Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
        Alternatively, this file may be distributed under the terms of the Tango
        3-Clause BSD License (see LICENSE_BSD.txt for details).

*******************************************************************************/

module ocean.net.email.EmailSender;


/*******************************************************************************

    Imports

*******************************************************************************/

import ocean.core.Array : append;

import ocean.transition;
import ocean.io.Stdout;
import ocean.sys.Process;
import ocean.core.Exception_tango : ProcessException;


class EmailSender
{
    /***************************************************************************

        Spawned process

    ***************************************************************************/

    private Process process;


    /***************************************************************************

        Temporary buffers used for formatting multiple email addresses into a
        single buffer containing comma-separated entries

    ***************************************************************************/

    private mstring recipients_buf;
    private mstring cc_buf;
    private mstring bcc_buf;


    /***************************************************************************

        Constructor that creates the reusable process

    ***************************************************************************/

    public this ( )
    {
        this.process = new Process("sendmail -t", null);
    }


    /***************************************************************************

        Spawns a child process that sends an email using sendmail.

        Accepts 2D arrays for the recipient list, cc list, and bcc list,
        automatically comma-separates them, and passes them to the other
        overload of this method. Use this method if it is more convenient for
        you to pass the required lists in 2D buffers, rather than in
        comma-separated 1D buffers as required by sendmail.

        Params:
            sender = the sender of the email
            recipients = the recipient(s) of the email
            subject = the email subject
            msg_body = the email body
            reply_to = an optional Reply To. default empty
            mail_id = an optional mail id/In-Reply-To. default empty
            cc = an optional cc. default empty
            bcc = an optional bcc. default empty

        Returns:
            true if the mail was sent without any errors, otherwise false

    ***************************************************************************/

    public bool sendEmail ( cstring sender, cstring[] recipients,
        cstring subject, cstring msg_body, cstring reply_to = null,
        cstring mail_id = null, cstring[] cc = null, cstring[] bcc = null )
    {
        void format_entries_buf ( cstring[] param_to_format,
                                  ref mstring buf )
        {
            auto first_entry = true;

            buf.length = 0;
            enableStomping(buf);

            foreach ( entry; param_to_format )
            {
                if ( !first_entry )
                {
                    buf ~= ", ";
                }
                else
                {
                    first_entry = false;
                }

                buf ~= entry;
            }
        }

        format_entries_buf(recipients, this.recipients_buf);

        format_entries_buf(cc, this.cc_buf);

        format_entries_buf(bcc, this.bcc_buf);

        return this.sendEmail(sender, this.recipients_buf, subject, msg_body,
            reply_to, mail_id, this.cc_buf, this.bcc_buf);
    }


    /***************************************************************************

        Spawns a child process that sends an email using sendmail.

        If multiple entries need to be passed in the recipient list, cc list,
        or bcc list, then the entries need to be comma separated. There exists
        an overloaded version of this function which takes these lists as 2D
        arrays instead of regular arrays (with each entry being passed in a
        different index), and automatically performs the comma separation.

        Params:
            sender = the sender of the email
            recipients = the recipient(s) of the email, multiple entries need to
                be comma separated
            subject = the email subject
            msg_body = the email body
            reply_to = an optional Reply To. default empty
            mail_id = an optional mail id/In-Reply-To. default empty
            cc = an optional cc, multiple entries need to be comma separated
                (defaults to null)
            bcc = an optional bcc, multiple entries need to be comma separated
                (defaults to null)

        Returns:
            true if the mail was sent without any errors, otherwise false

    ***************************************************************************/

    public bool sendEmail ( cstring sender, cstring recipients,
        cstring subject, cstring msg_body, cstring reply_to = null,
        cstring mail_id = null, cstring cc = null, cstring bcc = null )
    {
        Process.Result result;

        with (this.process)
        {
            try
            {
                execute;
                stdin.write("From: ");
                stdin.write(sender);
                stdin.write("\nTo: ");
                stdin.write(recipients);
                if ( cc != null )
                {
                    stdin.write("\nCc: ");
                    stdin.write(cc);
                }
                if ( bcc != null )
                {
                    stdin.write("\nBcc: ");
                    stdin.write(bcc);
                }
                stdin.write("\nSubject: ");
                stdin.write(subject);
                if ( reply_to != null)
                {
                    stdin.write("\nReply-To: ");
                    stdin.write(reply_to);
                }
                if ( mail_id != null)
                {
                    stdin.write("\nIn-Reply-To: ");
                    stdin.write(mail_id);

                }
                stdin.write("\nMime-Version: 1.0");
                stdin.write("\nContent-Type: text/html; charset=UTF-8\n");
                stdin.write(msg_body);
                stdin.close();
                result = process.wait;
            }
            catch ( ProcessException e )
            {
                Stderr.formatln("Process '{}' ({}) exited with reason {}, "
                  ~ "status {}", programName, pid, cast(int) result.reason,
                    result.status);
                return false;
            }
        }
        return true;
    }
}

version (UnitTest)
{
    import ocean.core.Tuple: Tuple;
}

/// EmailSender simple usage
unittest
{
    void sendReport ()
    {
        auto reporter = new EmailSender();

        reporter.sendEmail("notification@example.com", "test@example.com",
                           "Notification test report", "This is a test report",
                           "noreply@example.com");
    }
}

// Ensure D2 const correctness
unittest
{
    void sendReport ()
    {
        auto reporter = new EmailSender();

        alias Tuple!(cstring, istring, mstring) ArgTypes;

        foreach (ArgType; ArgTypes)
        {
            ArgType email_from = "notification@example.com".dup;
            ArgType email_to = "test@example.com".dup;
            ArgType email_subject = "Notification test report".dup;
            ArgType email_body = "This is a test report".dup;
            ArgType email_reply_to = "noreply@example.com".dup;

            reporter.sendEmail(email_from, email_to, email_subject, email_body,
                               email_reply_to);
        }
    }
}
