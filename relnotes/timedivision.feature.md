### Round relative time interval arguments

`ocean.text.arguments.TimeIntervalArgs`

Handler for time interval CLI arguments.

Relative values (eg. 1m, 4h) and 'now' can be rounded by [m]inutes, [h]ours and [d]ays.
The new relative format is [time_start][time unit]/[floor_to_time_unit] or now/[floor_to_time_unit].

      eg. -t 1h/h 1h = if the command is executed at 15:23:23 then
                        begin = 14:00:00, end = 14:59:59

          -t now/d = will select the range between 00:00:00 and `now`
