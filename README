tests.sh
========

Simple library for creating tests for shell programs.

It consist only of one file and it file acts as library and as test runner.

Usage
=====

1. Create directory `tests/` (name can vary);
2. Place `tests.sh` into `tests/`;
3. Create testcases, named `<test-case-name>.test.sh`, contains test code,
   written in bash, for example:
   ```bash
   #!/bin/bash

   tests_cd $(tests_tmpdir)

   tests_do cat \> a.txt <<EOF
   123
   EOF

   tests_assert_stdout_re \
       '^1 ' \
       wc -l a.txt
   ```
4. Run whole test suite using: `./tests.sh all`;
5. Run one testcase using: `./tests.sh one <test-case-name>.test.sh`;
6. Run last failed testcase using: `./test.sh one`;
