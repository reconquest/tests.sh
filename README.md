tests.sh [![Build Status](https://travis-ci.org/reconquest/tests.sh.svg?branch=master)](https://travis-ci.org/reconquest/tests.sh)
========

![tests-sh](https://cloud.githubusercontent.com/assets/674812/14815361/c029d328-0bcc-11e6-91b6-4f27c872d060.gif)

tests.sh — simple test library for testing commands.

tests.sh expected to find files named `*.test.sh` in the directory, provided by
`-d` flag, and they are treated as testcases.

# Reference

See reference at [REFERENCE.md](REFERENCE.md).

# Synopsis

```
tests.sh --- simple test library for testing commands.

tests.sh expected to find files named *.test.sh in current directory, and
they are treated as testcases.

Usage:
    tests.sh -h
    tests.sh [-v] [-d <dir>] [-s <path>] -A [-a]
    tests.sh [-v] [-d <dir>] [-s <path>] -O [<name>]

Options:
    -h | --help  Show this help.
    -A           Run all testcases in current directory.
    -a           Run all testcases in subdirectories of current directory.
    -O <name>    Run specified testcase only. If no testcase specified, last
                 failed testcase will be ran.
    -s <path>    Run specified setup file before running every testcase.
    -d <dir>     Change directory to specified before running testcases.
                 [default: current working directory].
    -v           Verbosity. Flag can be specified several times.
                  -v      Simple debug:
                           - only evaluated commands via tests:eval or
                             tests:pipe will be printed
                  -vv     Output debug:
                           - stdout and stderr of evaluated commands will be
                             printed.
                           - also, sourced files will be printed.
                  -vvv    Extended debug:
                           - notes about namespace and sourced files will be
                             expanded.
                           - file contents put via tests:put will be printed.
                  -vvvv   Extreme debug:
                           - evaluated commands will be printed in form they
                             will be evaluated.
                           - stdin input for tests:eval and tests:put will be
                             printed.
                           - default debug level for `-O` mode.
                  -vvvvv  Insane debug:
                           - output of background tasks will be printed in
                             realtime (no proper use without highlighting).
                  -vvvvvv Debug debug (oh, well).
                           - produce messages for debuggin library for itself.
```

## Usage example

1. Create directory `tests/` (name can vary);
2. Create testcases, named `<test-case-name>.test.sh`, contains test code,
   written in bash, for example:
   ```bash
   tests:put a.txt <<EOF
   123
   EOF

   tests:ensure wc -l a.txt

   tests:assert-stdout-re '^1 '
   ```
4. Run whole test suite using: `./tests.sh -d tests/ -A`;
5. Run one testcase using: `./tests.sh -d tests/ -O <test-case-name>`;
6. Run last failed testcase using: `./test.sh -d tests -O`;

## Set ups

Local set up script should be specified via `-s` flag. `local.setup.sh`. It
will be sources every time before each testcase.
