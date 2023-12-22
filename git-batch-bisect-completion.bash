
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

    # This magically named function will get pulled in by git-completion.bash
    # function
    _git_batch_bisect ()
    {
        __git_has_doubledash && return

    	local subcommands="start runinall runincurrent bad good new old terms skip reset visualize replay log run cleanupall help"
    	local subcommand="$(__git_find_on_cmdline "$subcommands")"
    	if [ -z "$subcommand" ]; then
    		__git_find_repo_path
    		if [ -f "$__git_repo_path"/BISECT_START ]; then
    			__gitcomp "$subcommands"
    		else
    			__gitcomp "replay start cleanupall help"
    		fi
    		return
    	fi

            case "$subcommand" in
            start)
              case "$cur" in
              --*)
                local _git_bisect_start_options="--first-parent --no-checkout"
                __gitcomp "$_git_bisect_start_options"
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
            esac

    	case "$subcommand" in
    	bad|good|new|old|reset|skip|start)
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
