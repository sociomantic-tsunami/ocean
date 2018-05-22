### Changed order of app extensions

Previously several extensions used in DaemonApp had same order as application
itself meaning it was not possible to rely on `processConfig` method being
run after `processConfig` of those extensions. That proved to be an extra
burden, particularly with `TaskExt` and now all extensions are ordered before
the application itself unless it is strictly necessary otherwise.
