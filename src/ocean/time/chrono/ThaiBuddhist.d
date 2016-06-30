/*******************************************************************************

        Copyright:
            Copyright (c) 2005 John Chapman.
            Some parts copyright (c) 2009-2016 Sociomantic Labs GmbH.
            All rights reserved.

        License:
            Tango Dual License: 3-Clause BSD License / Academic Free License v3.0.
            See LICENSE_TANGO.txt for details.

        Version:
            Mid 2005: Initial release
            Apr 2007: reshaped

        Authors: John Chapman, Kris

******************************************************************************/

module ocean.time.chrono.ThaiBuddhist;

import ocean.time.chrono.GregorianBased;


/**
 * $(ANCHOR _ThaiBuddhist)
 * Represents the Thai Buddhist calendar.
 */
public class ThaiBuddhist : GregorianBased {
  /**
   * $(I Property.) Overridden. Retrieves the identifier associated with the current calendar.
   * Returns: An integer representing the identifier of the current calendar.
   */
  public override uint id() {
    return THAI;
  }

}
