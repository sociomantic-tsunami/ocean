### Allow removing the client from the selected set in EpollSelectDispatcher.unregister

`ocean.io.select.EpollSelectDispatcher`

`EpollSelectDispatcher.unregister` now accepts an optional flag
(`remove_from_selected_set`) which will remove the client from the selected set
if it's in there. This guarantees that the unregistered client's handle method
will not be subsequently called by the selector. The client may thus be safely
destroyed after unregistering.
