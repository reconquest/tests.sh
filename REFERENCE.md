* [tests:import-namespace()](#testsimport-namespace)
* [tests:get-tmp-dir()](#testsget-tmp-dir)
* [tests:wait-file-matches()](#testswait-file-matches)
* [tests:assert-equals()](#testsassert-equals)
* [tests:assert-stdout()](#testsassert-stdout)
* [tests:assert-stderr()](#testsassert-stderr)
* [tests:match-re()](#testsmatch-re)
* [tests:assert-re()](#testsassert-re)
* [tests:assert-no-diff()](#testsassert-no-diff)
* [tests:get-stdout-file()](#testsget-stdout-file)
* [tests:get-stderr-file()](#testsget-stderr-file)
* [tests:get-stdout()](#testsget-stdout)
* [tests:get-stderr()](#testsget-stderr)
* [tests:get-exitcode-file()](#testsget-exitcode-file)
* [tests:get-exitcode()](#testsget-exitcode)
* [tests:assert-no-diff-blank()](#testsassert-no-diff-blank)
* [tests:assert-test()](#testsassert-test)
* [tests:put-string()](#testsput-string)
* [tests:put()](#testsput)
* [tests:assert-stdout-empty()](#testsassert-stdout-empty)
* [tests:assert-stderr-empty()](#testsassert-stderr-empty)
* [tests:assert-empty()](#testsassert-empty)
* [tests:assert-stdout-re()](#testsassert-stdout-re)
* [tests:assert-stderr-re()](#testsassert-stderr-re)
* [tests:assert-success()](#testsassert-success)
* [tests:assert-fail()](#testsassert-fail)
* [tests:assert-exitcode()](#testsassert-exitcode)
* [tests:not()](#testsnot)
* [tests:silence()](#testssilence)
* [tests:fail()](#testsfail)
* [tests:describe()](#testsdescribe)
* [tests:debug()](#testsdebug)
* [tests:cd()](#testscd)
* [tests:eval()](#testseval)
* [tests:runtime()](#testsruntime)
* [tests:pipe()](#testspipe)
* [tests:value()](#testsvalue)
* [tests:ensure()](#testsensure)
* [tests:make-tmp-dir()](#testsmake-tmp-dir)
* [tests:cd-tmp-dir()](#testscd-tmp-dir)
* [tests:run-background()](#testsrun-background)
* [tests:get-background-pid()](#testsget-background-pid)
* [tests:get-background-stdout()](#testsget-background-stdout)
* [tests:get-background-stderr()](#testsget-background-stderr)
* [tests:stop-background()](#testsstop-background)
* [tests:wait-file-changes()](#testswait-file-changes)
* [tests:set-verbose()](#testsset-verbose)
* [tests:get-verbose()](#testsget-verbose)
* [tests:clone()](#testsclone)
* [tests:involve()](#testsinvolve)
* [tests:require()](#testsrequire)

## tests:import-namespace()

Make all functions from tests.sh available without 'tests:'
prefix. Prefix can be also user defined, like 't:'.

### Arguments

* **$1** (string): Custom prefix for namespace functions.

## tests:get-tmp-dir()

Returns temporary directory for current test session.

It can be used as a workspace for the testcase.

### Example

```bash
ls $(tests:get-tmp-dir)
```

### Output on stdout

* Path to temp dir, e.g., /tmp/tests.XXXX

## tests:wait-file-matches()

Suspends testcase execution until file contents matches
pattern or timeout is reached.

Can be used to check if background-executed command output do not contains
any error messages.

### Example

```bash
stderr=$(tests:get-background-stderr $command_id)
tests:wait-file-not-matches "$stderr" "ERROR" 1 2
```

### Arguments

* **$1** (string): Path to file.
* **$2** (regexp): Regexp, same as in `grep -E`.
* **$3** (int): Interval of time to check changes after.
* **$4** (int): Timeout in seconds.

## tests:assert-equals()

Asserts, that first string arg is equals to second.

### Example

```bash
tests:assert-equals 1 2 # fails
```

### Arguments

* **$1** (string): Expected string.
* **$2** (string): Actual value.

## tests:assert-stdout()

Asserts, that last evaluated command's stdout contains given
string.

### Example

```bash
tests:eval echo 123
tests:assert-stdout 123
```

### Arguments

* **$1** (string): Expected stdout.

## tests:assert-stderr()

Asserts, that last evaluated command's stderr contains given
string.

### Example

```bash
tests:eval echo 123 '1>&2' # note quoting
tests:assert-stderr 123
```

### Arguments

* **$1** (string): Expected stderr.

## tests:match-re()

Compares, that last evaluated command output (stdout, stderr) or
file contents matches regexp.

### Example

```bash
tests:eval echo aaa
tests:match-re stdout a.a
echo $? # 0
tests:match-re stdout a.b
echo $? # 1
```

### Arguments

* **$1** ('stdout'|'stderr'|filename): If 'stdout' or 'stderr' is used, use
* **$2** (regexp): Regexp to match, same as in grep.

## tests:assert-re()

Same as 'tests:match-re', but abort testing if comparison
failed.

### Example

```bash
tests:eval echo aaa
tests:assert-re stdout a.a
tests:assert-re stdout a.b # test fails there
```

#### See also

* [tests:match-re](#tests:match-re)

## tests:assert-no-diff()

Asserts, that there are no diff on the last command output
(stderr or stdout), or on string or on specified file with specified string
or file.

### Example

```bash
tests:eval echo -e '1\n2'
tests:assert-no-diff stdout "$(echo -e '1\n2')" # note quotes
tests:assert-no-diff stdout "$(echo -e '1\n3')" # test will fail
```

### Arguments

* **$1** (string|filename): Expected value.
* **$2** ('stdout'|'stderr'|string|filename): Actual value.
* **...** (any): Additional arguments for diff.

## tests:get-stdout-file()

Returns file containing stdout of last command.

### Example

```bash
tests:eval echo 123
cat $(tests:get-stdout-file) # will echo 123
```

### Output on stdout

* Filename containing stdout.

## tests:get-stderr-file()

Returns file containing stderr of last command.

### Example

```bash
tests:eval echo 123 '1>&2' # note quotes
cat $(tests:get-stderr) # will echo 123
```

### Output on stdout

* Filename containing stderr.

## tests:get-stdout()

Returns contents of the stdout of last command.

### Example

```bash
tests:eval echo 123
tests:get-stdout # will echo 123
```

### Output on stdout

* Stdout for last command.

## tests:get-stderr()

Returns contents of the stderr of last command.

### Example

```bash
tests:eval echo 123 '>&2'
tests:get-stderr # will echo 123
```

### Output on stdout

* Stderr for last command.

## tests:get-exitcode-file()

Returns file containing exitcode of last command.

### Example

```bash
tests:eval exit 220
cat $(tests:get-exitcode-file) # will echo 220
```

### Output on stdout

* Filename containing exitcode.

## tests:get-exitcode()

Returns exitcode of last command.

### Example

```bash
tests:eval exit 220
tests:get-exitcode # will echo 220
```

### Output on stdout

* Filename containing exitcode.

## tests:assert-no-diff-blank()

Same as 'tests:assert-diff', but ignore changes whose lines are
all blank.

### Example

```bash
tests:eval echo -e '1\n2'
tests:assert-no-diff-blank stdout "$(echo -e '1\n2')" # note quotes
tests:assert-no-diff-blank stdout "$(echo -e '1\n\n2')" # test will pass
```

#### See also

* [tests:diff](#tests:diff)

## tests:assert-test()

Same as shell 'test' function, but asserts, that exit code is
zero.

### Example

```bash
tests:assert-test 1 -eq 1
tests:assert-test 1 -eq 2 # test will fail
```

### Arguments

* **...** (Arguments): for 'test' function.

## tests:put-string()

Put specified contents into temporary file with given name.

### Example

```bash
tests:put-string xxx "lala"
```

### Arguments

* **$1** (filename): Temporary file name.
* **$2** (string): Contents to put.

## tests:put()

Put stdin into temporary file with given name.

### Example

```bash
tests:put xxx <<EOF
1
2
3
EOF
```

### Arguments

* **$1** (filename): Temporary file name.

## tests:assert-stdout-empty()

Asserts that stdout is empty.

### Example

```bash
tests:eval echo ""
```

_Function has no arguments._

## tests:assert-stderr-empty()

Asserts that stderr is empty.

### Example

```bash
tests:eval echo "" '1>&2'
```

_Function has no arguments._

## tests:assert-empty()

Asserts that target is empty.

### Example

```bash
tests:eval echo ""
```

_Function has no arguments._

## tests:assert-stdout-re()

Asserts that stdout of last evaluated command matches given
regexp.

### Example

```bash
tests:eval echo 123
```

### Arguments

* **$1** (regexp): Regexp, same as in grep.

## tests:assert-stderr-re()

Asserts as 'tests:assert-stdout-re', but stderr used instead
of stdout.

### Example

```bash
tests:eval echo 123 '1>&2' # note quotes
```

### Arguments

* **$1** (regexp): Regexp, same as in grep.

## tests:assert-success()

Asserts that last evaluated command exit status is zero.

### Example

```bash
tests:eval true
tests:assert-success
```

_Function has no arguments._

## tests:assert-fail()

Asserts that last evaluated command exit status is not zero.
Basically, alias for `test:not tests:assert-success`.

### Example

```bash
tests:eval false
tests:assert-fail
```

_Function has no arguments._

## tests:assert-exitcode()

Asserts that exit code of last evaluated command equals to
specified value.

### Example

```bash
tests:eval false
tests:assert-exitcode 1
```

### Arguments

* **$1** (int): Expected exit code.

## tests:not()

Negates passed assertion.

### Example

```bash
tests:eval false
tests:assert-fail
tests:not tests:assert-success
```

### Arguments

* **...** (any): Command to evaluate.

## tests:silence()

Prevets eval command to print stdout/stderr.

### Example

```bash
tests:silence tests:eval rm -r blah
```

### Arguments

* **...** (any): Command to evaluate.

## tests:fail()

Output message and fail current testcase immideately.

### Arguments

* **...** (any): String to output.

## tests:describe()

Same as tests:debug(), but colorize output
for better vizibility.

### Arguments

* **...** (any): String to output.

## tests:debug()

Print specified string in the debug log.

### Example

```bash
tests:debug "hello from debug" # will shown only in verbose mode
```

### Arguments

* **...** (any): String to echo.

## tests:cd()

Changes working directory to specified directory.

### Arguments

* **$1** (directory): Directory to change to.

## tests:eval()

Evaluates specified string via shell 'eval'.

Redirection syntax differs from what can be found in bash.

Redirection operators will be used as redirection only if they are
passed as separate argumentm, like this: `tests:eval echo 1 '>' 2`.

List of redirection operators:
* `>`
* `<`
* `>&`
* `<&`
* `>&n`, where `n` is a number
* `<&n`, where `n` is a number
* `>>`
* `<<<`
* `<>`
* `|`

To redirect output to file use: `> filename` (note space).

Also, if only one argument is passed to `tests:eval`, the it will
be evaled as is. So, `tests:eval "echo 1 > 2"` will create file `2`,
but `tests:eval echo "1 > 2"` will only output `1 > 2` to the stdout.

*NOTE*: you will not get any stdout or stderr from evaluated command.
To obtain stdout or stderr see `tests:pipe`.

*NOTE*: output will be buffered! If you want unbuffered output, use
`tests:runtime`.

*NOTE*: use of that function will not produce any output to stdout
nor stderr. If you want to pipe your result to something, use
`tests:pipe`.

### Example

```bash
tests:eval echo 123 "# i'm comment"
tests:eval echo 123 \# i\'m comment
tests:eval echo 567 '1>&2' # redirect to stderr
tests:eval echo 567 1\>\&2' # same
```

### Arguments

* **...** (string): String to evaluate.

#### See also

* [tests:pipe](#tests:pipe)

#### See also

* [tests:runtime](#tests:runtime)

## tests:runtime()

Same, as `tests:pipe`, but produce unbuffered result.

### Example

```bash
tests:runtime 'echo 1; sleep 10; echo 2'  # see 1 immediately
```

### Arguments

* **...** (string): String to evaluate.

#### See also

* [tests:eval](#tests:eval)

## tests:pipe()

Same, as `tests:eval`, but return stdout and stderr
as expected.

### Example

```bash
lines=$(tests:eval echo 123 | wc -l)  # note not escaped pipe
tests:assert-equals $lines 1
```

### Arguments

* **...** (string): String to evaluate.

#### See also

* [tests:eval](#tests:eval)

## tests:value()

Same, as `tests:eval`, but writes stdout into given variable and
return stderr as expected.

### Example

```bash
_x() {
    echo "y [$@]"
}
tests:value response _x a b c
tests:assert-equals "$response" "y [a b c]"
```

### Arguments

* **$1** (string): Variable name.
* **...** (string): String to evaluate.

#### See also

* [tests:eval](#tests:eval)

## tests:ensure()

Eval specified command and assert, that it has zero exitcode.

### Example

```bash
tests:esnure true # will pass
tests:esnure false # will fail
```

### Arguments

* **...** (any): Command to evaluate.

## tests:make-tmp-dir()

Creates temporary directory.

### Arguments

* **...** (any): Same as for mkdir command.

## tests:cd-tmp-dir()

Changes working directory to the specified temporary directory,
previously created by 'tests:make-tmp-dir'.

### Arguments

* **$1** (string): Directory name.

## tests:run-background()

Runs any command in background, this is very useful if you test
some running service.

Processes which are ran by 'tests:background' will be killed on cleanup
state, and if test failed, stderr and stdout of all background processes will
be printed.

### Arguments

* **$1** (variable): Name of variable to store BG process ID.
* **...** (string): Command to start.

## tests:get-background-pid()

Returns pid of specified background process.

### Arguments

* **$1** (string): Process ID, returned from 'tests:run-background'.

### Output on stdout

* Pid of background process.

## tests:get-background-stdout()

Returns stdout of specified background process.

### Arguments

* **$1** (string): Process ID, returned from 'tests:run-background'.

### Output on stdout

* Stdout from background process.

## tests:get-background-stderr()

Returns stderr of specified background process.

### Arguments

* **$1** (string): Process ID, returned from 'tests:run-background'.

### Output on stdout

* Stderr from background process.

## tests:stop-background()

Stops background process with 'kill -TERM'.

### Arguments

* **$1** (string): Process ID, returned from 'tests:run-background'.

## tests:wait-file-changes()

Waits, until specified file will be changed or timeout passed
after executing specified command.

### Arguments

* **$1** (string): Command to evaluate.
* **$2** (filename): Filename to wait changes in.
* **$3** (int): Interval of time to check changes after.
* **$4** (int): Timeout in seconds.

## tests:set-verbose()

Sets verbosity of testcase output.

### Arguments

* **$1** (int): Verbosity.

## tests:get-verbose()

Gets current verbosity level.

_Function has no arguments._

### Output on stdout

* Current verbosity.

## tests:clone()

Copy specified file or directory from the testcases
dir to the temporary test directory.

### Arguments

* **...** (any): Same args, as for cp commmand.

## tests:involve()

Copy specified file from testcases to the temporary test
directory and then source it.

### Arguments

* **$1** (filename): Filename to copy and source.
* **$2** (filename): Destination under test dir (not required).

## tests:require()

Source file with debug.

### Arguments

* **$1** (filename): Filename to source.

