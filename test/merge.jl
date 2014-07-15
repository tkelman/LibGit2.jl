with_new_repo("test a new repo is fully merged") do test_repo, path
    @test is_fully_merged(GitIndex(test_repo))
end

with_standard_test_repo(
"test that a fully merged repo only contains staged idx entries") do test_repo, path
    idx = GitIndex(test_repo)
    @test is_fully_merged(idx)
    for entry in idx
        @test entry.stage == 0 # is staged
    end
end

with_merged_test_repo(
"test soft reset a repo wth unmerged entries throws") do test_repo, path
    idx = GitIndex(test_repo)
    @test is_fully_merged(idx) == false
    # head commit
    hc  = lookup(GitReference, test_repo, head(test_repo))
    fcp = parents(hc)[1]
    @test_throws LibGitError{:Object,:Unmerged} reset!(test_repo, fcp, :soft)
end

with_merged_test_repo( 
"test commit against a repo with unmerged entries throws") do test_repo, path
    idx = GitIndex(test_repo)
    @test is_fully_merged(idx) == false
    author = Signature("test", "test@test.com")
    @test_throws LibGitError{:Index,:Unmerged} commit(test_repo, 
        "try commit unmerged entries", author, author)
end

with_standard_test_repo(
"test can retrieve the branch begin merged") do test_repo, _
    first_branch = "9fd738e8f7967c078dceed8190330fc8648ee56a";
    second_branch = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    touch_test(path(test_repo), "MERGE_HEAD", "$first_branch\n$second_branch\n") 
    @test currentstate(test_repo) === :merge
end

# test can merge repo non-ff

# test is up to date merged

# test can ff repos

# test conflicting merge repos

# test conflicting merge repos binary

# test can ff commit

# test can ff merge commit 

# test merge reports checkout progress

# test merge reports checkout notifications

# test ff merge reports checkout progress

# test ff merge reports checkout notifications

# test merge can detect renames

# test ff non ff merge throws

# test can force ff merge through config 

# test can merge and not commit

# test can force non ff merge

# test can force non ff merge through config

# test verify up to date merge 

# test can merge committish

# test can merge with workdir conflicts

# test can specify conflict file strategy 

# test merge can specify merge file flavor option

# test can merge branch

# test can merge into orphaned branch

# test add file commit to repo

sandboxed_test("merge-resolve", "test merge no conflict") do test_repo, path
    ours   = revparse(test_repo, "trivial-2alt")
    theirs = revparse(test_repo, "trivial-2alt-branch")
    base   = revparse(test_repo, merge_base(test_repo, ours, theirs))
    idx = merge!(test_repo, GitTree(ours), GitTree(theirs), GitTree(base))
    @test has_conflicts(idx) == false
end

sandboxed_test("merge-resolve", "test merge has conflicts") do test_repo, path
    ours   = revparse(test_repo, "trivial-4")
    theirs = revparse(test_repo, "trivial-4-branch")
    base   = revparse(test_repo, merge_base(test_repo, ours, theirs))
    idx = merge!(test_repo, GitTree(ours), GitTree(theirs), GitTree(base))
    @test has_conflicts(idx) 
    @test sum(entry -> entry.stage > 0, idx) == 2
    @test idx["new-and-different.txt", 2] != nothing 
    @test idx["new-and-different.txt", 3] != nothing
end
