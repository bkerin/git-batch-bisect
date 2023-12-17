
# batch-bisect

Make it easy to pre-build a range of commits in seperate directories such that
bisection can then be done on them more quickly and easily (without having to
wait for a build between tests or change directories manually).

The built commits persist until their removal is explicitly requested and will
be re-used by subsequent bisections.

## Installation

Ensure that you have perl 5.20 or later and GNU Parallel available, then put
the batch-bisect script in your PATH.

## Use

It's used almost like normal git bisect:

```
# Start batch bisection.  This is like git bisect start but it also #
# automatically ensures that directory e.g.
# /home/my_repo/../my_repo.batch_bisect exists and is populated with worktrees
# for all the commits involved in the bisection:

batch-bisect start bad_commit good_commit

# Tree pruning is supported as in native `git-bisect` (and reduces the number of
# commits to be pre-built accordingly):

batch-bisect start --first-parent bad_commit good_commit -- some/path

# Run a build command for all the commits (using GNU parallel).  The `stdout`
# and `stderr` of the commands themselves goes in log files (see below):

batch-bisect runinall 'autoreconf --install && ./configure && make'

# Test.  This will run the given command in the worktree dir for the current
# commit:

batch-bisect runincurrent ./test_program
batch-bisect good
batch-bisect runincurrent ./test_program
batch-bisect bad
# etc.

# When finished with this bisection, but want to keep commit builds around:

batch-bisect reset

# To cleanup batch-bisect worktrees and directories and reset bisection:

batch-bisect cleanupall

```

The other git bisect subcommands interoperate with batch-bisect.  For clarity
there are wrappers for them but all they do is run the underlying git bisect
command:

```
batch-bisect skip
batch-bisect visualize
batch-bisect replay ./logfile
batch-bisect log
batch-bisect run ./test_script
```

Note that if the test for the behavior can be automated easily it may be
desirable to simply use `git bisect run` instead (though batch-bisect can still
be used for this and will have the possibly desirable side-effect of producing
a persistant cache of commit builds as usual).

## Where output goes

<!-- FIXXME: modify this to cover runinrange if it ever gets added -->

Log files are used for a lot of output.  Log files are clobbered when you would
expect (e.g. the master_log by `batch-bisect start`, runinall logs for when a
new logged command is executed, etc.).

### Output of `runinall`

The runinall command prints a summary of what it's doing and the exit status of
each of the commands on standard output and standard error, and also logs this
information in a master log file called for example:

```
/home/my_repo/../my_repo.batch_bisect/master_log
```

The output of the individual commands run by `ruininall` is not printed, but
redirected to log files like for example:

```
/home/my_repo/../my_repo.batch_bisect.09f4e248000679ebac8e426a40becd1903e548ac.stderr_log
/home/my_repo/../my_repo.batch_bisect.09f4e248000679ebac8e426a40becd1903e548ac.stdout_log
```

The logic here is `runinall` is generally used for build commands, the output
of which is probably voluminous and uninteresting except in the case of build
failure (in which case it's probably most convenient to have the output of the
individual command isolated).

### Output of `runincurrent`

The `runincurrent` command logs only a summary of what it's going to do to the
master_log, and leaves the standard output and standard error undisturbed.  The
logic here is that `runincurrent` is generally used for testing, where the
output of instrumentation or the actual program under test will likely need to
be observerd.

### Output of everything else

All the other commands cause a log entry in the `master_log` but the output of
the underlying `git bisect` commands is undisturbed.

## Options

The options for the underlying git bisect subcommands are supported.  Some of
them have obvious additional meanings or interactions with batch-bisect:

- `--no-checkout`

    This is convenient with `batch-bisect` because it lets you bisect without
    bothering to commit or stash changes in your working tree.

- `--first-parent`

    In addition to its normal meaning this limits the build cache to only the
    required commits.  If you have a lot of merged branches it can make for a
    much more managable number of commits to build to first `batch-bisect` for
    the guilty merge, the `batch-bisect` again on its branch.

## How to use old/new terms

Unlike normal git bisect, batch-bisect requires the bounding bad/good
commits to be provided to `batch-bisect start`.  Unfortunately this means
the recipe provided in the bisect man page for using the old/new terms
doesn't work, but simply providing `--term-new=new` and `--term-old=old` to
`batch-bisect start` works fine.

## How command quoting and invocation is done

### Simple version

If your runinall or runincurrent commands don't need single quote characters
themselves then enclosing the command in single quotes will generally do what
you want.  If they do it's easiest to just put them in a small script and run
that.

Commands are run in the usual script context: exported variables and functions
are active, but aliases, non-exported functions, shell settings (as set with
the `set` command) etc. for your current shell are not.

### Stubborn masochistic version:

Because this shell quoting insanity is a weakness of mine.

<!-- FIXXME: modify this to cover runinrange if it ever gets added -->
- For all commands except runinall and runincurrent the arguments
`batch-bisect` ends up seeing are passed on to the corresponding git commands
without any additional quoting.  If your rev names are sane this will generally
work fine, but if you have pathologically un-unixy path or file names with
spaces or quotes in them you're in for some fun escaping them so they make it
into `batch-bisect`, and due to the way `git bisect logs` quotes the stuff
it remembers (which `batch-bisect` uses) things still might fail later (I
haven't tried it :)

<!-- FIXXME: modify this to cover runinrange if it ever gets added -->
- For the runinall, and runincurrent commands, `batch-bisect` aims to behave
exactly as if the command *it receives* was run in a script context (i.e.
without aliases etc.) in each of the commit directories.  So this works:

    ```
    batch-bisect runinall 'WORKTREE_PATH=`pwd` &&' echo hello from \\\`'WORKTREE_PATH'\\\' ">>/tmp/my_log"
    ```

    Note that the redirection will occur in a subshell before the redirection
    that logs standard output, so the logs described above won't see it.

    Empty strings, strings consisting entirely of whitespace, and null bytes
    are not generally preserved (they wouldn't generally be in a script context
    either :).  `batch-bisect` quotes with this relatively simple strategy:

    ```
    my $qec = ($cmd =~ s/'/'"'"'/gr);   # Quote-escaped Command
    ```

    So empty strings eventually get lost.  This works:

    ```
    batch-bisect runinall 'echo a b | cut -d " " -f 1'  ">>/tmp/my_log"
    ```

    But this doesn't:

    ```
    runinall echo a b | cut -d ' ' -f 1  ">>/tmp/my_log"
    ```

## TODO

- Maybe add a --cache-dir option (or something like that not sure about name) to
control where the commit trees go.
