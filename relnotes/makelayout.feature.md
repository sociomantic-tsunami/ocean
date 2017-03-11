* `ocean.util.log.Config`

    An extra overload of the `configureLogger` and `configureOldLoggers` functions
    were introduced, with an additional `makeLayout` parameter.
    This parameter is used to instantiate a `Layout` from a name, allowing
    users to have custom layouts usable from their config files.
    For example, a config entry would be:
    ```
    [LOG.myapp.supermodule]
    level = info
    file  = log/supermodule.log
    file_layout = aquatic
    console_layout = submarine
    ```
    And calling `configureOldLoggers` should be done as such:
    ```
    void myConfigureLoggers (
        ClassIterator!(Config, ConfigParser) config,
        MetaConfig m_config,
        Appender delegate ( istring file, Layout layout ) file_appender,
        bool use_insert_appender = false)
    {
        Layout makeLayout (cstring name)
        {
            if (name == "aquatic")
                return new AquaticLayout;
            if (name == "submarine")
                return new SubmarineLayout;
            return ocean.util.log.Config.newLayout(name);
        }
        ocean.util.log.Config.configureOldLoggers(config, m_config,
            file_appender, &makeLayout, use_insert_appender);
    }
    ```
    Note that the previous example is kept short for simplicity. `makeLayout` gets the raw name,
    and as such may make the comparison as loose as wanted
    (by lowercasing, removing `"layout"` prefix/suffix, etc...).
