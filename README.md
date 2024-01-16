
# git-batch-bisect

Make it easy to pre-build a range of commits in seperate directories such that
bisection can then be done on them more quickly and easily (without having to
wait for a build between tests or create/change/build in/delete directories
manually).

The built commits persist until their removal is explicitly requested and will
be reused by subsequent bisections.

## Installation

Ensure that you have perl 5.20 or later and GNU Parallel available, then put
the git-batch-bisect script in your PATH.

## Use

It's can be used almost like `git-bisect` without knowing anything more:

```
# Start batch bisection.  This is like git bisect start but it also #
# automatically ensures that directory e.g.
# /home/my_repo/../my_repo.batch_bisect exists and is populated with worktrees
# for all the commits involved in the bisection:

git batch-bisect start bad_commit good_commit

# Tree pruning is supported as in regular `git-bisect` and reduces the number
# of commits to be pre-built accordingly:

git batch-bisect start --first-parent bad_commit good_commit -- some/path

# Run a build command for all the commits (using GNU parallel).  The `stdout`
# and `stderr` of the commands themselves goes in log files (see below):

git batch-bisect runinall 'autoreconf --install && ./configure && make'

# Test.  This will run the given command in the worktree dir for the current
# commit:

git batch-bisect runincurrent ./test_program
git batch-bisect good
git batch-bisect runincurrent ./test_program
git batch-bisect bad
# etc.

# When finished with this bisection, but want to keep commit builds around:

git batch-bisect reset

# To cleanup batch-bisect worktrees and directories and reset bisection:

git batch-bisect cleanupall
```

The other git-bisect subcommands interoperate with git-batch-bisect.  For
clarity there are wrappers for them but all they do is run the underlying git
bisect command:

```
git batch-bisect skip
git batch-bisect visualize
git batch-bisect replay ./logfile
git batch-bisect log
git batch-bisect run ./test_script
```

Note that if the test for the behavior can be automated easily it may be
desirable to simply use `git bisect run` instead (though batch-bisect can still
be used for this and will have the possibly desirable side-effect of producing
a persistant cache of commit builds as usual).

## Making commmand line completion work

Ensure that bash-completion and git-completion.bash are operational (they
usually are) and put the contents of `git-batch-bisect-completion.bash` in your
`~/.bash_completion ` or `source` it from somewhere.

To make completion work for a function (or alias) do something like this:

```
function bb { git batch-bisect $@; }
__git_complete bb git_batch_bisect   # After above-mentioned file is source'd
```

## Using old/new (or other) terms

Unlike `git-bisect`, `git-batch-bisect` requires the bounding bad/good
commits to be provided to the `start` subcommand.  Unfortunately this means
the recipe provided in the bisect man page for using the old/new terms
doesn't work, but simply providing `--term-new=new` and `--term-old=old` to
the `start` command works fine.


## Where output goes

<!-- FIXXME: modify this to cover runinrange if it ever gets added -->

The `runinall` subcommand prints a summary of what it's doing and the exit
status of each of the commands on standard output or standard error as
appropriate, but the stdout and stderr of the commands themselves are
redirected to log files like for example:

```
/home/my_repo/../my_repo.git-batch-bisect.09f4e248000679ebac8e426a40becd1903e548ac.stderr_log
/home/my_repo/../my_repo.git-batch-bisect.09f4e248000679ebac8e426a40becd1903e548ac.stdout_log
```

All the other commands including `runincurrent` leave stdout and stderr
undisturbed.  The logic is that `runinall` is generally used for build commands
which often have voluminous output that's only interesting when there's a build
failure, while `runincurrent` is used for testing where the output of
instrumentation or of the actual program under test often needs to be observed.

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

<!-- FIXME: would be nice to fix the garbage formatting where the first paragraph of a bullet point is not indented but subsequent ones need to be, probably by indending first I guess -->

<!-- FIXXME: modify this to cover runinrange if it ever gets added -->
- For the runinall, and runincurrent commands, `batch-bisect` aims to behave
exactly as if the command *it receives* was run in a script context (i.e.
without aliases etc.) in each of the commit directories.  So this works:

    ```
    git batch-bisect runinall 'WORKTREE_PATH=`pwd` &&' echo hello from \\\`'$WORKTREE_PATH'\\\' ">>/tmp/my_log"
    ```

    Note that the redirection will occur in a subshell before the redirection
    that logs standard output, so the logs described above won't see it.

    Empty strings, strings consisting entirely of whitespace, and null bytes
    are not generally preserved (they wouldn't be in a script context either :)
    `batch-bisect` quotes with this relatively simple strategy:

    ```
    my $qec = ($cmd =~ s/'/'"'"'/gr);   # Quote-Escaped Command
    ```

    So empty strings eventually get lost.  This works:

    ```
    git batch-bisect runinall 'echo a b | cut -d " " -f 1'  ">>/tmp/my_log"
    ```

    But this doesn't:

    ```
    git batch-bisect runinall echo a b | cut -d ' ' -f 1  ">>/tmp/my_log"
    ```

## TODO (maybe)

- Add a --cache-dir or something like that to control where the commit trees
go.  This would be the easist way to support maintaining caches with different
build configurations.  Of course the user can get something like this by putting a copy of the entire repo in a dir with a different name but that's sort of clunky.  This should probably get an env variable also since the command line arg would need to be given to every command.  Usual prio of command_line > env > default.

- Support automagical common ancestor selection like what native git-bisect
does (instead of the suggestion to run `git merge-base` manually to find the
commits to use as we currently do).  This would require taking a look at what
git bisect is really doing to be sure I'm right about it.  I've never
wanted this myself but maybe it's useful on really huge projects where the
graph structure is difficult to decipher even with `gitk`.

- Add --cache-only or something like that to explicitly support setting up
worktrees but not actually starting a bisection.  This would need some checks
relaxed in `runinall`.  I'm not sure it's worth adding wierd states like
this since it's pretty obvious the user can get it with `batch-bisect start`
followed by `batch-bisect reset`.
