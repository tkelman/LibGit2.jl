function add_file_and_commit(repo::GitRepo, filename::String, content=nothing)
    idx, sig = GitIndex(repo), default_signature(repo)
    touch_test(workdir(repo), filename, content)
    push!(idx, filename)
    commit(repo, "New commit", sig, sig)
end 

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
    b1 = "9fd738e8f7967c078dceed8190330fc8648ee56a";
    b2 = "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
    touch_test(path(test_repo), "MERGE_HEAD", "$b1\n$b2\n") 
    @test currentstate(test_repo) === :merge
end

for detach_head in (true, false)
    with_standard_test_repo(
    "test can merge repo non-ff => $detach_head") do test_repo, _
        b1name = "first branch file.txt";
        b2name = "second branch file.txt";
        sbname = "first+second branch file.txt";

        b1 = create_branch(test_repo, "FirstBranch")
        checkout!(test_repo, b1)

        original_tree_count = GitTree(tip(b1)) |> length
        
        # commit with ONE new file to both first and
        # second branches
        add_file_and_commit(test_repo, sbname)
        
        b2 = create_branch(test_repo, "SecondBranch")

        if detach_head
            # detaches head
            checkout!(test_repo, tip(b2))
        else
            checkout!(test_repo, b2)
        end
        
        # Commit with one new file to second branch
        # first branch and second branch now point to different
        # commits that both have thhe same parent commit
        add_file_and_commit(test_repo, b2name)
        
        res = merge!(test_repo, tip(b1))
        
        @show res
        @show Oid(test_repo[head(test_repo)])
        @show parent_count(test_repo[res]) 
        @show is_head_detached(test_repo) == detach_head

        if !detach_head
            # ensure HEAD is still attached and points to second branch
            @show canonical_name(b2)
            @show symbolic_target(head(test_repo))
        end
    end
end

with_standard_test_repo(
"test is up to date merged") do test_repo, _
    b1name = "first branch file.txt"
    b2name = "second branch file.txt"
    sbname = "first+second branch file.txt"

    b1 = create_branch(test_repo, "first_branch")
    checkout!(test_repo, b1)
    add_file_and_commit(test_repo, b1name)

    b2 = create_branch(test_repo, "second_branch")
    checkout!(test_repo, b2)

    merge!(test_repo, b1)
end

for detach_head in (true, false)
    with_standard_test_repo(
     "test can ff repos => detach head $detach_head") do test_repo, _
            
            b1name = "first branch file.txt";
            sbname = "first+second branch file.txt";
            
            # reset the index and the working tree
            reset!(test_repo, "HEAD", :hard)

            # clean up the working directory
            remove_untracked!(test_repo)

            b1 = create_branch(test_repo, "FirstBranch")
            checkout!(test_repo, b1)
            
            # commit with ONE new file to both b1 & b2
            add_file_and_commit(test_repo, sbname)
            
            b2 = create_branch(test_repo, "SecondBranch")
            
            # commit with ONE new file to first branch
            # b2 is now 1 behind  b1
            add_file_and_commit(test_repo, b1name)
            
            if detach_head
                checkout!(test_repo, tip(b2))
            else
                checkout!(test_repo, b2)
            end
            @test is_head_detached(test_repo) == detach_head

            res = merge!(test_repo, tip(b1))

            @show LibGit2.merge_analysis(test_repo, res)

            @show tip(b1) == res
            @show tip(b1) == test_repo[head(test_repo)]
            @show length(GitIndex(test_repo))
            @show is_head_detached(test_repo) == detach_head
    end
end

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

with_merge_test_repo(
"test can merge and not commit") do test_repo, _
    commit_to_merge = lookup_branch(test_repo, "normal_merge")
    
    sig = Signature("test", "test@test.com")
    ops = {:commit_on_success => true}
    res = merge!(test_repo, commit_to_merge)
    #TODO:
    idx = GitIndex(test_repo)
    @show idx["b.txt"].stage #& GitConst.IDXENTRY_STAGEMASK
end

with_merge_test_repo(
"test can force non ff merge") do test_repo, _
    GitConfig(test_repo)["merge.ff"] = false 
    commit_to_merge = tip(lookup_branch(test_repo,"fast_forward"))
    cid = merge!(test_repo, commit_to_merge)
    @show cid, Oid("f58f780d5a0ae392efd4a924450b1bbdc0577d32")
end

with_merge_test_repo(
"test can force non ff merge through config") do test_repo, _
    GitConfig(test_repo)["merge.ff"] = "only"
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    try
        merge!(test_repo, commit_to_merge)
    catch ex
        @show ex
    end 
end

# test verify up to date merge 

# test can merge committish

# test can merge with workdir conflicts

# test can specify conflict file strategy 

# test merge can specify merge file flavor option
#"test can merge branch"

with_merge_test_repo(
"test can merge into orphaned branch") do test_repo, path
    create_ref(test_repo, "HEAD", "refs/heads/orphan", force=true)
    # remove entried from the working dir
    idx = GitIndex(test_repo)
    remove_all!(idx, [entry.path for entry in idx])
    #assert that we have an empty working directory
    @test length(idx) == 0
    merge!(test_repo, lookup_branch(test_repo, "master"))
end

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
