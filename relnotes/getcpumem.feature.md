* `ocean.sys.Stats`

  Method `getCpuMemoryStats` is now added to `ocean.sys.Stats`
  which returns the structure filled with the following information:

  1. Consumed CPU time percentage in user mode
  2. Consumed CPU time percentage in system mode
  3. Consumed total CPU time percentage
  4. Virtual memory size of the process
  5. Resident memory size of the process
  6. Percentage of the total memory available consumed by the process

  This struct is intended to be passed straight to the stats logger.

* `ocean.util.app.DaemonApp`

  DaemonApp is now capable of collecting and reporting CPU & memory usage
  directly to stats.log. To use this feature, call `DaemonApp.reportSystemStats`
  periodically inside `onStatsTimer`.
