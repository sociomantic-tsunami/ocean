module ocean.task.util.QuickRun_test;

import ocean.task.util.QuickRun;
import ocean.task.Scheduler;
import ocean.core.Test;

unittest
{
    initScheduler(SchedulerConfiguration.init);

    auto ret = quickRun({
        theScheduler.processEvents();
        return 42;
    });

    test!("==")(ret, 42);
}
