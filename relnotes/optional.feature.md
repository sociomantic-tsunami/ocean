* `ocean.core.Optional`

  New module to add boolean flag indicating existence of a value to arbitrary
  type in generic manner:

  ```D
      Optional!(int) foo ( bool x )
      {
          if (x)
              return optional(42);
          else
              return Optional!(int).undefined;
      }

      foo(true).visit(
          ()              { test(false); },
          (ref int value) { test(value == 42); }
      );

      foo(false).visit(
          ()              { },
          (ref int value) { test(false); }
      );
  ```
