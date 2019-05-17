### Add a cli arguments parser for date intervals

`ocean.text.arguments.TimeIntervalArgs`

TimeIntervalArgs is an utility for the apps that get a time interval for the
cli arguments. the contained functions can be used to handle
timestamps, iso1806 dates and relative time intervals.

## example of usage with CliApp class

```d
    import ocean.text.arguments.DateIntervalArgs;

    ...

    TimestampInterval interval;

    override protected void setupArgs ( IApplication app,  Arguments args )
    {
        setupTimeRangeArgs(args, false);
    }

    override protected cstring validateArgs ( IApplication app,
        Arguments args )
    {
        return validateTimeIntervalArgs(args);
    }

    override protected void processArgs ( IApplication app, Arguments args )
    {
        this.interval = processTimeRangeArgs(args);
    }

    ...

```

and then you can call the app with the `time-interval` argument:

    my_app --time-interval 2014-03-09 now
    my_app --time-interval now 1m
    my_app --time-interval 1h --round

