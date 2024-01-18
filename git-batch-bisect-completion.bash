
# vim:filetype=bash

_batch-bisect_check_for_func ()
{
  # Check that $1 is a function, and print `$1' not a function$2 and return
  # faluse if it isn't, or return true otherwise

  if [[ `type -t "$1"` != 'function' ]]; then
    echo '`'"$1""'"' not a function'"$2" 1>&2
    return 1
  else
    return 0
  fi
}

_batch-bisect_check_for_funcs ()
{
  # Check that $2.. are functions, print messages like e.g. `$2' is not a
  # function$1 for any of $2.. that aren't functions, and return true iff all
  # of $2.. were functions or false otherwise

  local _batch_bisect_mfms="$1"   # Missing Funcion Message Suffix
  shift

  local _batch_bisect_mf='false'   # Missing Function(s)?

  for func in "$@"; do
    _batch-bisect_check_for_func "$func" "$_batch_bisect_mfms" \
      || _batch_bisect_mf='true'
  done

  [[ "$_batch_bisect_mf" = "false" ]]
  return
}

if _batch-bisect_check_for_func                               \
     __load_completion                                        \
     ' (maybe the bash-completion package is not installed?)'
then

  # FIXXME: the faster more sociable way to do things would be to figure out
  # how to hook into the dynamic loading setup that bash-completion provides
  # like git-completion.bash
  # (https://github.com/git/git/blob/master/contrib/completion/git-completion.bash)
  # itself does.  But it's (probably less than) 1 ms on my system and this
  # isn't a case where everyone is doing it this way so I'm not worrying about
  # it right now.
  __load_completion git

  # Check that the git-completion.bash _funcs we use are at least still around
  if _batch-bisect_check_for_funcs                                         \
       ', maybe something has changed/been renamed in git-completion.bash' \
       __git_has_doubledash                                                \
       __git_find_repo_path                                                \
       __gitcomp                                                           \
       __git_complete_refs                                                 \
       __git_complete
  then

    # FIXXME: If the version of this I submitted to git gets merged this copy
    # can be removed from here.
    #
    # Check for only porcelain (i.e. not git-rev-list) option (not argument)
    # and selected option argument completions for git-log options and if any
    # are found put them in COMPREPLY.  COMPREPLY must be empty at the start,
    # and will be empty on return if no candidates are found.
    __git_complete_log_opts ()
    {
    	[ -z "$COMPREPLY" ] || return 1   # Precondition

    	local merge=""
    	if [ -f "$__git_repo_path/MERGE_HEAD" ]; then
    		merge="--merge"
    	fi
    	case "$prev,$cur" in
    	-L,:*:*)
    		return	# fall back to Bash filename completion
    		;;
    	-L,:*)
    		__git_complete_symbol --cur="${cur#:}" --sfx=":"
    		return
    		;;
    	-G,*|-S,*)
    		__git_complete_symbol
    		return
    		;;
    	esac
    	case "$cur" in
    	--pretty=*|--format=*)
    		__gitcomp "$__git_log_pretty_formats $(__git_pretty_aliases)
    			" "" "${cur#*=}"
    		return
    		;;
    	--date=*)
    		__gitcomp "$__git_log_date_formats" "" "${cur##--date=}"
    		return
    		;;
    	--decorate=*)
    		__gitcomp "full short no" "" "${cur##--decorate=}"
    		return
    		;;
    	--diff-algorithm=*)
    		__gitcomp "$__git_diff_algorithms" "" "${cur##--diff-algorithm=}"
    		return
    		;;
    	--submodule=*)
    		__gitcomp "$__git_diff_submodule_formats" "" "${cur##--submodule=}"
    		return
    		;;
    	--ws-error-highlight=*)
    		__gitcomp "$__git_ws_error_highlight_opts" "" "${cur##--ws-error-highlight=}"
    		return
    		;;
    	--no-walk=*)
    		__gitcomp "sorted unsorted" "" "${cur##--no-walk=}"
    		return
    		;;
    	--diff-merges=*)
                    __gitcomp "$__git_diff_merges_opts" "" "${cur##--diff-merges=}"
                    return
                    ;;
    	--*)
    		__gitcomp "
    			$__git_log_common_options
    			$__git_log_shortlog_options
    			$__git_log_gitk_options
    			$__git_log_show_options
    			--root --topo-order --date-order --reverse
    			--follow --full-diff
    			--abbrev-commit --no-abbrev-commit --abbrev=
    			--relative-date --date=
    			--pretty= --format= --oneline
    			--show-signature
    			--cherry-mark
    			--cherry-pick
    			--graph
    			--decorate --decorate= --no-decorate
    			--walk-reflogs
    			--no-walk --no-walk= --do-walk
    			--parents --children
    			--expand-tabs --expand-tabs= --no-expand-tabs
    			$merge
    			$__git_diff_common_options
    			"
    		return
    		;;
    	-L:*:*)
    		return	# fall back to Bash filename completion
    		;;
    	-L:*)
    		__git_complete_symbol --cur="${cur#-L:}" --sfx=":"
    		return
    		;;
    	-G*)
    		__git_complete_symbol --pfx="-G" --cur="${cur#-G}"
    		return
    		;;
    	-S*)
    		__git_complete_symbol --pfx="-S" --cur="${cur#-S}"
    		return
    		;;
    	esac
    }

    # This magically named function will get pulled in by git-completion.bash
    # function
    _git_batch_bisect ()
    {
    	__git_has_doubledash && return

    	__git_find_repo_path

    	local term_bad term_good
    	if [ -f "$__git_repo_path"/BISECT_START ]; then
    		term_bad=`__git bisect terms --term-bad`
    		term_good=`__git bisect terms --term-good`
    	fi

    	# We will complete any custom terms, but still always complete the
    	# more usual bad/new/good/old because git bisect gives a good error
    	# message if these are given when not in use and that's better than
    	# silent refusal to complete if the user is confused.
    	#
    	# We want to recognize 'view' but not complete it, because it overlaps
    	# with 'visualize' too much and is just an alias for it.
    	#
    	local completable_subcommands="start runinall runincurrent bad new $term_bad good old $term_good terms skip reset visualize replay log run cleanupall help"
    	local all_subcommands="$completable_subcommands view"

    	local subcommand="$(__git_find_on_cmdline "$all_subcommands")"

    	if [ -z "$subcommand" ]; then
    		if [ -f "$__git_repo_path"/BISECT_START ]; then
    			__gitcomp "$completable_subcommands"
    		else
    			__gitcomp "replay start cleanupall help"
    		fi
    		return
    	fi

    	case "$subcommand" in
    	start)
    		case "$cur" in
    		--*)
    			__gitcomp "--term-new --term-bad --term-old --term-good --first-parent --no-checkout"
    			return
    			;;
    		*)
    			;;
    		esac
    		;;
    	cleanupall)
    		case "$cur" in
    		--*)
    			__gitcomp "--force"
    			return
    			;;
    		esac
    		;;
    	terms)
    		case "$cur" in
    		--*)
    			__gitcomp "--term-good --term-old --term-bad --term-new"
    			return
    			;;
    		*)
    			;;
    		esac
    		;;
    	visualize|view)
    		case "$cur" in
    		-*)
    			__git_complete_log_opts
    			return
    			;;
    		*)
    			;;
    		esac
    		;;
    	esac

    	case "$subcommand" in
    	bad|new|"$term_bad"|good|old|"$term_good"|reset|skip|start)
    		__git_complete_refs
    		;;
    	*)
    		;;
    	esac
    }

    # FIXXME: this is probably inefficient and presumably there's some other
    # way to hook in a single additional subcommand
    ___git_complete git __git_main

  fi

fi
