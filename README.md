tests.sh
========

tests.sh --- simple test library for testing commands.

tests.sh expected to find files named `*.test.sh` in current directory, and
they are treated as testcases.

## Synopsis
```
Usage:
    tests.sh -h | ---help
    tests.sh [-v] -A
    tests.sh -O <name>

Options:
    -h | --help  Show this help.
    -A           Run all testcases in current directory.
    -O <name>    Run specified testcase only.
    -v           Verbosity. Flag can be specified several times.
```

### Usage example

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
4. Run whole test suite using: `./tests.sh -A`;
5. Run one testcase using: `./tests.sh -O <test-case-name>.test.sh`;
6. Run last failed testcase using: `./test.sh -O`;
