/** Generate a UUID according to version 5 of RFC 4122.
  *
  * These UUIDs are generated in a consistent, repeatable fashion. If you
  * generate a version 5 UUID once, it will be the same as the next time you
  * generate it.
  *
  * To create a version 5 UUID, you need a namespace UUID, generated in some
  * reasonable fashion. This is hashed with a name that you provide to generate
  * the UUID. So while you can easily map names to UUIDs, the reverse mapping
  * will require a lookup of some sort.
  *
  * This module publicly imports Uuid, so you don't have to import both if you
  * are generating version 5 UUIDs. Also, this module is just provided for
  * convenience -- you can use the method Uuid.byName if you already have an
  * appropriate digest.
  *
  * Version 5 UUIDs use SHA-1 as the hash function. You may prefer to use
  * version 3 UUIDs instead, which use MD5, if you require compatibility with
  * another application.
  *
  * To use this module:
  * ---
  * import ocean.util.uuid.NamespaceGenV5;
  * auto dnsNamespace = Uuid.parse("6ba7b810-9dad-11d1-80b4-00c04fd430c8");
  * auto uuid = newUuid(namespace, "rainbow.flotilla.example.org");
  * ---
  *
  * Copyright:
  *     Copyright (c) 2009-2016 Sociomantic Labs GmbH.
  *     All rights reserved.
  *
  * License:
  *     Boost Software License Version 1.0. See LICENSE_BOOST.txt for details.
  *     Alternatively, this file may be distributed under the terms of the Tango
  *     3-Clause BSD License (see LICENSE_BSD.txt for details).
  *
  */
module ocean.util.uuid.NamespaceGenV5;

public import ocean.util.uuid.Uuid;
import ocean.util.digest.Sha1;

/** Generates a UUID as described above. */
Uuid newUuid(Uuid namespace, char[] name)
{
        return Uuid.byName(namespace, name, new Sha1, 5);
}
