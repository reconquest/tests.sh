## tests:import-namespace()

Make all functions from tests.sh available without 'tests:'
prefix. Prefix can be also user defined, like 't:'.

### Arguments

* **$1** (string): Custom prefix for namespace functions.

## tests:get-tmp-dir()

Returns temporary directory for current test session.
It can be used as a workspace for the testcase.

#### Example

```bash
ls $(tests:get-tmp-dir)
```

### Output on stdout

* Path to temp dir, e.g, /tmp/tests.XXXX

## tests:assert-equals()

Asserts, that first string arg is equals to second.

#### Example

```bash
tests:assert-equals 1 2 # fails
```

### Arguments

* **$1** (string): Expected string.
* **$2** (string): Actual value.

## tests:assert-stdout()

Asserts, that last evaluated command's stdout contains given
string.

#### Example

```bash
tests:eval echo 123
tests:assert-stdout 123
```

### Arguments

* **$1** (string): Expected stdout.

## tests:assert-stderr()

Asserts, that last evaluated command's stderr contains given
string.

#### Example

```bash
tests:eval echo 123 '1>&2' # note quoting
tests:assert-stderr 123
```

### Arguments

* **$1** (string): Expected stderr.

## tests:match-re()

Compares, that last evaluated command output (stdout, stderr) or
file contents matches regexp.

#### Example

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

#### Example

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

#### Example

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

#### Example

```bash
tests:eval echo 123
cat $(tests:get-stdout-file) # will echo 123
```

### Output on stdout

* Filename containing stdout.

## tests:get-stderr-file()

Returns file containing stderr of last command.

#### Example

```bash
tests:eval echo 123 '1>&2' # note quotes
cat $(tests:get-stderr) # will echo 123
```

### Output on stdout

* Filename containing stderr.

## tests:assert-no-diff-blank()

Same as 'tests:assert-diff', but ignore changes whose lines are
all blank.

#### Example

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

#### Example

```bash
tests:assert-test 1 -eq 1
tests:assert-test 1 -eq 2 # test will fail
```

### Arguments

* **...** (Arguments): for 'test' function.

## tests:put-string()

Put specified contents into temporary file with given name.

#### Example

```bash
tests:put-string xxx "lala"
```

### Arguments

* **$1** (filename): Temporary file name.
* **$2** (string): Contents to put.

## tests:put()

Put stdin into temporary file with given name.

#### Example

```bash
tests:put xxx <<EOF
1
2
3
EOF
```

### Arguments

* **$1** (filename): Temporary file name.

## tests:assert-stdout-re()

Asserts that stdout of last evaluated command matches given
regexp.

#### Example

```bash
tests:eval echo 123
```

### Arguments

* **$1** (regexp): Regexp, same as in grep.

## tests:assert-stderr-re()

Asserts as 'tests:assert-stdout-re', but stderr used instead
of stdout.

#### Example

```bash
tests:eval echo 123 '1>&2' # note quotes
```

### Arguments

* **$1** (regexp): Regexp, same as in grep.

## tests:assert-success()

Asserts that last evaluated command exit status is zero.

#### Example

```bash
tests:eval true
tests:assert-success
```

_Function has no arguments._

## tests:assert-fail()

Asserts that last evaluated command exit status is not zero.
Basically, alias for `test:not tests:assert-success`.

#### Example

```bash
tests:eval false
tests:assert-fail
```

_Function has no arguments._

## tests:assert-exitcode()

Asserts that exit code of last evaluated command equals to
specified value.

#### Example

```bash
tests:eval false
tests:assert-exitcode 1
```

### Arguments

* **$1** (int): Expected exit code.

## tests:not()

Negates passed assertion.

#### Example

```bash
tests:eval false
tests:assert-fail
tests:not tests:assert-success
```

### Arguments

* **$1** (int): Expected exit code.

## tests:describe()

Same as tests:debug(), but colorize output
for better vizibility.

### Arguments

* **...** (any): String to output.

## tests:debug()

Print specified string in the debug log.

#### Example

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

#### Example

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

## tests:pipe()

Same, as `tests:eval`, but return stdout and stderr
as expected.

#### Example

```bash
lines=$(tests:eval echo 123 | wc -l)  # note not escaped pipe
tests:assert-equals $lines 1
```

### Arguments

* **...** (string): String to evaluate.

#### See also

* [tests:eval](#tests:eval)

## tests:ensure()

Eval specified command and assert, that it has zero exitcode.

#### Example

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
previously created by 'tests:mkdir'.

### Arguments

* **$1** (string): Directory name.

## tests:run-background()

Runs any command in background, this is very useful if you test
some running service.
Processes which are ran by 'tests:background' will be killed on cleanup
state, and if test failed, stderr and stdout of all background processes will
be printed.

### Arguments

* **...** (string): Command to start.

### Output on stdout

* Unique identifier of running backout process.

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

## tests:background-stderr()

Returns stderr of specified background process.

### Arguments

* **$1** (string): Process ID, returned from 'tests:run-background'.

### Output on stdout

* Stderr from background process.

## tests:stop-background()

Stops background process with 'kill -9'.

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

