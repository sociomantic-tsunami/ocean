## IConnectionHandler.unregisterSocket made abstract

* `ocean.net.server.connection.IConnectionHandler`

  `IConnectionHandler.unregisterSocket` method, previously implemented with an
  empty body is now made abstract, forcing all ConnectionHandlers to unregister
  registered socket in a meaningful way before closing them inside the finalizer.
  In turn, `TaskConnectionHandler` now unregisters its `transceiver` before
  closing it.

  Example usage:

  ```
  protected override void unregisterSocket ()
  {
      if ( has_registered_client )
          this.registered_client.unregister();
  }
  ```
