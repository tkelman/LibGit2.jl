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
        checkout!(b1)

        original_tree_count = GitTree(tip(b1)) |> length
        
        # commit with ONE new file to both first and
        # second branches
        add_file_and_commit(test_repo, sbname)
        
        b2 = create_branch(test_repo, "SecondBranch")

        if detach_head
            # detaches head
            checkout!(test_repo, tip(b2))
        else
            checkout!(b2)
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
    checkout!(b1)
    add_file_and_commit(test_repo, b1name)

    b2 = create_branch(test_repo, "second_branch")
    checkout!(b2)

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
            checkout!(b1)
            
            # commit with ONE new file to both b1 & b2
            add_file_and_commit(test_repo, sbname)
            
            b2 = create_branch(test_repo, "SecondBranch")
            
            # commit with ONE new file to first branch
            # b2 is now 1 behind  b1
            add_file_and_commit(test_repo, b1name)
            
            if detach_head
                checkout!(test_repo, tip(b2))
            else
                checkout!(b2)
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

with_standard_test_repo(
"test conflicting merge repos") do test_repo, _
    b1name = "first branch file.txt"
    b2name = "second branch file.txt"
    sbname = "first+second branch file.txt"

    b1 = create_branch(test_repo, "FirstBranch")
    checkout!(b1)
    
    # Commit with ONE new file to both first and second branch
    add_file_and_commit(test_repo, sbname)
    
    b2 = create_branch(test_repo, "SecondBranch")
    
    # Commit with ONE new file to first branch
    # first branch moves  forward as it is checked out
    # second branch stays back one
    add_file_and_commit(test_repo, b1name)
    add_file_and_commit(test_repo, sbname, "The first branches comment")

    checkout!(b2)

    # Commit with ONE new file to second branch
    # first branch and second branch now point to separate commits
    # that both have the same parent commit
    add_file_and_commit(test_repo, b2name)
    add_file_and_commit(test_repo, sbname, "The second branches comment")

    res = merge!(test_repo, tip(b1))
    
    idx = GitIndex(test_repo)
    @show res
    @show LibGit2.merge_analysis(test_repo, res)
    @show length(idx) 
    @show has_conflicts(idx)
end

with_standard_test_repo(
"test conflicting merge repos binary") do test_repo, _
    b1name = "first branch file.txt"
    b2name = "second branch file.txt"
    sbname = "first+second branch file.txt"

    b1 = create_branch(test_repo, "FirstBranch")
    checkout!(b1)

    # commit with ONE new file to both first and second branch
    add_file_and_commit(test_repo, sbname)

    b2 = create_branch(test_repo, "SecondBranch")

    # commit with ONE new file to first branch
    # first branch moves forward as it is checked out,
    # second branch stays back one
    add_file_and_commit(test_repo, b1name)

    # change file in first branch 
    add_file_and_commit(test_repo, sbname, "\0The first branches comment\0")
    
    res = merge!(test_repo, tip(lookup_branch(test_repo, "FirstBranch")))

    idx = GitIndex(test_repo)
    @show LibGit2.merge_analysis(test_repo, res)
    @show has_conflicts(idx)
end

# test can ff commit
for (detach_head,ffstrategy) in [(true, :default),
                                 (true, :fastforwardonly),
                                 (false, :default), 
                                 (false, :fastforwardonly)]
    with_merge_test_repo(
        "test can ff merge commit") do test_repo, _
            if detach_head
                checkout!(test_repo, test_repo[head(test_repo)])
            end
            commit_to_merge = tip(lookup_branch(test_repo, "fast_forward"))
            res = merge!(test_repo, commit_to_merge, 
                         {:strategy => ffstrategy})
            @show LibGit2.merge_analysis(test_repo, res)
    end
end 

for (detach_head, ffstrategy, status) in [(true, :default, :nonfastforward),
                                          (true, :nofastforward, :nonfastforward),
                                          (false, :default, :nonfastforward),
                                          (false, :nofastforward, :nonfastforward)]
    with_merge_test_repo(
        "test can non ff merge commit") do test_repo, _
            if detach_head
                checkout!(test_repo, test_repo[head(test_repo)])
            end
            commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
            res = merge!(test_repo, commit_to_merge, {:strategy => ffstrategy})
            @show LibGit2.merge_analysis(test_repo, res)
    end
end

with_merge_test_repo(
"test merge reports checkout progress") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    was_called = false
    opts = {:checkout_progress => (args...) -> begin
        was_called = true
    end}
    res = merge!(test_repo, commit_to_merge, opts)
    @show was_called
end

with_merge_test_repo(
"test merge reports checkout notifications") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    was_called = false
    checkout_notify = :none
    opts = {:on_checkout => (path, notify) -> begin
        was_called = true
        checkout_notify = notify
    end}
    res = merge!(test_repo, commit_to_merge, opts)
    @show was_called, checkout_notify
end

with_merge_test_repo(
"test ff merge reports checkout progress") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "fast_forward")) 
    was_called = false
    opts = {:checkout_progress => (args...) -> begin
        was_called = true
    end}
    res = merge!(test_repo, commit_to_merge, opts)
    @show was_called
end

with_merge_test_repo(
"test ff merge reports checkout notifications") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "fast_forward"))
    was_called = false
    checkout_notify = :none
    opts = {:on_checkout => (path, notify) -> begin
        was_called = true
        checkout_notify = notify
    end}
    res = merge!(test_repo, commit_to_merge, opts)
    @show was_called, checkout_notify
end

with_merge_test_repo(
"test merge can detect renames") do test_repo, _
    #= 
    The environment is set up such that:
    file b.txt is edited in the "rename" branch and
    edited and renamed in the "rename_source" branch.
    The edits are automergable.
    We can rename "rename_source" into "rename"
    if rename detection is enabled,
    but the merge will fail with conflicts if this
    change is not detected as a rename.
    =#
    current_branch = checkout!(test_repo, "rename_source")
    branch_to_merge = lookup_branch(test_repo, "rename")
    res = merge!(test_repo, branch_to_merge)
    @show LibGit2.merge_analysis(test_repo, res)
end

with_merge_test_repo(
"test ff non ff merge throws") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    try
        merge!(test_repo, commit_to_merge, {:strategy => :fastforwardonly})
    catch ex
        @show ex
    end 
end 

with_merge_test_repo(
"test can force ff merge through config") do test_repo, _
    GitConfig(test_repo)["merge.ff"] = "only"
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    try
        merge!(test_repo, commit_to_merge)
    catch ex
        @show ex
    end 
end 

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

with_merge_test_repo(
"test verify up to date merge") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "master"))
    res = merge!(test_repo, commit_to_merge, {:strategy => :nofastforward})
    @show LibGit2.merge_analysis(test_repo, res)
end

for (commitish, strategy, status) in [
    ("refs/heads/normal_merge", :default, :nonfastforward),
    ("normal_merge", :default, :nonfastforward),
    (Oid("625186280ed2a6ec9b65d250ed90cf2e4acef957"), :default, :nonfastforward),
    ("fast_forward", :default, :fastforward)]

    with_merge_test_repo(
    "test can merge committish") do test_repo, _
        res = merge!(test_repo, commitish, {:strategy => strategy})
        @show LibGit2.merge_analysis(test_repo, res)
    end 
end 

for (should_stage, strategy) in [(true, :fastforwardonly),
                                 (false, :fastforwardonly), 
                                 (true, :nofastforward), 
                                 (false, :nofastforward)]
    with_merge_test_repo(
    "test can merge with workdir conflicts throws") do test_repo, _
        #=
        Merging the fast_forward branch results in a change to file
        b.txt. In this test we modify the file in the working directory
        and then attempt to perform a merge. We expect the merge to fail
        due to merge conflicts.
        =#
        committish_to_merge = "fast_forward" 
        touch_test(workdir(test_repo), "b.txt", "this is an alternate change")
        if should_stage
            idx = GitIndex(test_repo)
            #TODO: the libgit2 stage concept is much cleaner, we should steal that
            push!(idx, "b.txt")
            write!(idx)
        end
        try
            merge!(test_repo, committish_to_merge, {:strategy => strategy})
        catch ex
            @show ex
        end 
    end 
end

for strategy in (:ours, :theirs)
    with_merge_test_repo(
        "test can specify conflict file strategy") do test_repo, _
        conflict_file  = "a.txt"
        conflict_branchname = "conflicts"
        branch = lookup_branch(test_repo, conflict_branchname)
        @test branch != nothing
        opts = {:strategy => strategy}
        res = merge!(test_repo, branch, opts)

        @show LibGit2.merge_analysis(test_repo, res)
        #TODO:
    end 
end

for flavor in (:ours, :theirs) 
    with_merge_test_repo(
        "test merge can specify merge file flavor option") do test_repo, _
        conflict_file  = "a.txt"
        conflict_branchname = "conflicts"
        branch = lookup_branch(test_repo, conflict_branchname)
        @test branch != nothing
        opts = {:merge_file_flavor => flavor}
            
        res = merge!(test_repo, branch, opts)
        @show LibGit2.merge_analysis(test_repo, res)
        #TODO:
    end
end

for (branchname, strategy, status) in [
    ("refs/heads/normal_merge", :default, :nonfastforward),
    ("fast_forward", :default, :fastforward)]
    
    with_merge_test_repo(
    "test can merge branch") do test_repo, _
        #branch = lookup_ref(test_repo, branchname)
        #@assert branch != nothing
        res = merge!(test_repo, branchname, {:strategy => strategy})
        @show LibGit2.merge_analysis(test_repo, res)
    end 
end 

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
