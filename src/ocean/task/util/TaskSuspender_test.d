module ocean.task.util.TaskSuspender_test;

import ocean.task.util.TaskSuspender;
import ocean.task.util.StreamProcessor;
import ocean.task.Task;
import ocean.task.Scheduler;

import ocean.core.Test;

class Processor : Task
{
    int x;

    void copyArguments ( int x )
    {
        this.x = x;
    }

    override void run ( )
    {
        if (x == 100)
            theScheduler.shutdown();
        theScheduler.processEvents();
    }
}

class Generator : Task
{
    StreamProcessor!(Processor) sp;
    int i;

    this ( )
    {
        this.sp = new typeof(this.sp)(ThrottlerConfig.init);
    }

    override void run ( )
    {
        while (true)
        {
            this.sp.process(i);
            ++i;
        }
    }
}

unittest
{
    initScheduler(SchedulerConfiguration.init);
    auto generator = new Generator;
    generator.sp.addStream(new TaskSuspender(generator));
    theScheduler.queue(generator);
    theScheduler.eventLoop();
    test!(">=")(generator.i, 100);
    test!("<=")(generator.i, 100 + SchedulerConfiguration.init.task_queue_limit);
}
