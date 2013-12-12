#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <git2.h>

git_repository* open_repo(const char *repo_path, int *err_code) {
	git_repository *repo;
	*err_code = git_repository_open(&repo, repo_path);
	return repo;
}

git_repository* init_repo(const char *repo_path, int is_bare, int *err_code) {
	git_repository *repo;
	*err_code = git_repository_init(&repo, repo_path, is_bare);
	return repo;
}

int libgit_version(int *major, int *minor, int *patch) {
	*major = (int) LIBGIT2_VER_MAJOR;
	*minor = (int) LIBGIT2_VER_MINOR;
	*patch = (int) LIBGIT2_VER_REVISION;
	return 1;
}
