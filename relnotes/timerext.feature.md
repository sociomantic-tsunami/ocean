* `ocean.util.app.ext.TimerExt`

  `TimerExt` now accounts for the amount of time the user delegate took to
  complete when scheduling the next timer call. If the user delegate takes
  longer to complete than the interval, the next call will occur at an even
  multiple of the specified period. (e.g. if the period is 5s and a call to
  the delegate takes 7s, then the timer will fire 3s later.)
