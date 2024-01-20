
SHELL = /bin/bash

# The only annoying thing with this is it pulls the browser window onto the
# current desktop.  But it can just be moved back, then updates itself when
# more changes are done.  FIXXME: grip --export would just produce HTML and
# let us do the viewing our own way...
.PHONY: view_readme_locally
view_readme_locally:
	(                                                                   \
          (grip -b &>>/tmp/grip_log)                                        \
          ||                                                                \
          (echo grip failed, maybe a running copy needs to be killed? 1>&2) \
        )                                                                   \
        &

# Because there's no reason to complicate matters with a repo-within-repo
test_repos.unpacked_stamp: test_repos.tar.xz
	tar xJvf $<
	touch $@

.PHONY: clean
clean:
	rm test_repos.unpacked_stamp
