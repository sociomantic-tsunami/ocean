* `ocean.util.app.ext.TimerExt`

  `TimerExt` is now swallowing all the unhandled exceptions, keeping the timers
  registered by default. If you need to unregister the timer on the thrown exception,
  catch the exception yourself and manually return `false` from your handler.
