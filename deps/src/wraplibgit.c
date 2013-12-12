#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <git2.h>


git_repository* open_repo(const char *repo_path, int *error_code) {
	git_repository *repo;
	*error_code = git_repository_open(&repo, repo_path);
	return repo;
}

int libgit_version(int *major, int *minor, int *patch) {
	*major = (int) LIBGIT2_VER_MAJOR;
	*minor = (int) LIBGIT2_VER_MINOR;
	*patch = (int) LIBGIT2_VER_REVISION;
	return 1;
}
