* `ocean.util.log.LayoutChainsaw`

  This module, and the eponymous class it contains, were using private details
  of the old logger implementation, and were not used in any project,
  and thus have been deprecated.
  As a result, it is not configurable by the `LogExt` anymore.
  If really needed, this self contained module can trivially be copied,
  and configuration is possible via the `makeLayout` parameter in
  `configure{Old,New}Loggers`.
