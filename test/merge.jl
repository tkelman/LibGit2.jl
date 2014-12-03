function add_file_and_commit(repo::GitRepo, filename::AbstractString, content=nothing)
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

#=
for detach_head in (true, false)
    with_standard_test_repo(
    "test can merge repo non-ff : $detach_head") do test_repo, _
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

        status, commit = merge!(test_repo, tip(b1))

        @test status === :nonfastforward
        @test isa(commit, GitCommit)
        #=
        @show Oid(test_repo[head(test_repo)])
        @show parent_count(test_repo[res])
        @show is_head_detached(test_repo) == detach_head

        if !detach_head
            # ensure HEAD is still attached and points to second branch
            @show canonical_name(b2)
            @show symbolic_target(head(test_repo))
        end
        =#
    end
end
=#

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

    status, cmmt = merge!(test_repo, b1)

    @test status === :uptodate
    @test is(cmmt, nothing)
end

for detach_head in (false,) #true XXX: detached head does not work (merge conflict)
    with_standard_test_repo(
     "test can ff repos : $detach_head") do test_repo, _

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

            status, cmmt = merge!(test_repo, tip(b1))

            @test status === :fastforward

            @test tip(b1) == cmmt
            @test tip(b1) == test_repo[head(test_repo)]
            @test is_fully_merged(GitIndex(test_repo))
            @test is_head_detached(test_repo) == detach_head
            if !detach_head
                # ensure HEAD is still attached and points to second branch
                @test name(head(test_repo)) == canonical_name(b2)
            end
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

    status, cmmt = merge!(test_repo, tip(b1))

    @test status == :conflicts
    @test is(cmmt, nothing)

    idx = GitIndex(test_repo)
    @test has_conflicts(idx)
    @test length(conflicts(test_repo, idx)) == 1
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

    checkout!(b2)
    # commit with ONE new file to the second branch
    # b1 and b2 now point to separte commits that both have the same parent commit
    add_file_and_commit(test_repo, b2name)
    add_file_and_commit(test_repo, sbname, "\0The second branches comment\0")

    status, cmmt = merge!(test_repo, tip(b1))

    @test status == :conflicts

    idx = GitIndex(test_repo)
    @test has_conflicts(idx)

    cs = conflicts(test_repo, idx)
    @test length(cs) == 1

    ancestor, ours, theirs = cs[1]

    #TODO: this is not getting picked up as a binary delta
    #@test delta(diff(test_repo, ours.id, theirs.id)).isbinary == true
end

# test can ff commit
for (detach_head, ffstrategy) in [(true, :default),
                                 (true, :fastforwardonly),
                                 (false, :default),
                                 (false, :fastforwardonly)]
    with_merge_test_repo(
        "test can ff merge commit: $detach_head, $ffstrategy") do test_repo, _
            if detach_head
                checkout!(test_repo, test_repo[head(test_repo)])
            end
            commit_to_merge = tip(lookup_branch(test_repo, "fast_forward"))
            status, cmmt = merge!(test_repo, commit_to_merge,
                                  AnyDict(:ffstrategy => ffstrategy))
            @test status === :fastforward
            @test Oid(cmmt) == Oid("4dfaa1500526214ae7b33f9b2c1144ca8b6b1f53")
            @test detach_head == is_head_detached(test_repo)
    end
end

for (detach_head, ffstrategy, estatus) in [(true, :default, :nonfastforward),
                                          (true, :nofastforward, :nonfastforward),
                                          (false, :default, :nonfastforward),
                                          (false, :nofastforward, :nonfastforward)]
    with_merge_test_repo(
        "test can non ff merge commit: $detach_head, $ffstrategy, $estatus") do test_repo, _
            if detach_head
                checkout!(test_repo, test_repo[head(test_repo)])
            end
            commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
            status, cmmt = merge!(test_repo, commit_to_merge, AnyDict(:ffstrategy => ffstrategy))

            @test status === estatus
            @test detach_head == is_head_detached(test_repo)
    end
end

with_merge_test_repo(
"test merge reports checkout progress") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    was_called = false
    opts = AnyDict(:progress => (args...) -> begin
        was_called = true
    end)
    res = merge!(test_repo, commit_to_merge, opts)
    @test was_called
end

#TODO: progress works, notify does not
with_merge_test_repo(
"test merge reports checkout notifications") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    was_called = false
    checkout_notify = :none
    opts = AnyDict(:notify => (why, path, diffs...) -> begin
        was_called = true
        checkout_notify = why
    end)
    res = merge!(test_repo, commit_to_merge, opts)
    #@show was_called, checkout_notify
end

with_merge_test_repo(
"test ff merge reports checkout progress") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "fast_forward"))
    was_called = false
    opts = AnyDict(:progress => (args...) -> begin
        was_called = true
    end)
    res = merge!(test_repo, commit_to_merge, opts)
    @test was_called
end

#TODO: progress works, notify does not
with_merge_test_repo(
"test ff merge reports checkout notifications") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "fast_forward"))
    was_called = false
    checkout_notify = :none
    opts = AnyDict(:notify => (path, notify) -> begin
        was_called = true
        checkout_notify = notify
    end)
    res = merge!(test_repo, commit_to_merge, opts)
    #@show was_called, checkout_notify
end

#TODO: this does not work
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
    @test current_branch != nothing

    #run(`git --git-dir=$(path(test_repo)) branch`)

    branch_to_merge = lookup_branch(test_repo, "rename")
    @test branch_to_merge != nothing

    status, _ = merge!(test_repo, branch_to_merge)
    #@show status
end

with_merge_test_repo(
"test ff non ff merge throws") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    #TODO: better errors
    @test_throws ErrorException merge!(test_repo, commit_to_merge,
                                       AnyDict(:ffstrategy => :fastforwardonly))
end

with_merge_test_repo(
"test can force ff merge through config") do test_repo, _
    GitConfig(test_repo)["merge.ff"] = "only"
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    #TODO: better errors
    @test_throws ErrorException merge!(test_repo, commit_to_merge)
end

with_merge_test_repo(
"test can merge and not commit") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))

    status, cmmt = merge!(test_repo, commit_to_merge)

    @test status === :nonfastforward
    @test is(cmmt, nothing)

    idx = GitIndex(test_repo)
    @test count(entry -> entry.stage == 0, idx) == 2
    @test idx["b.txt"].stage  == 0 # is taged entry
end

with_merge_test_repo(
"test can force non ff merge") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo,"fast_forward"))
    opts = AnyDict(:ffstrategy => :nofastforward)
    status, cmmt = merge!(test_repo, commit_to_merge, opts)
    @test status === :nonfastforward
    #TODO: I don't see how we can ever get a non null commit here
    #@test cmmt == Oid("f58f780d5a0ae392efd4a924450b1bbdc0577d32")
    @test is_fully_merged(test_repo)
end

with_merge_test_repo(
"test can force non ff merge through config") do test_repo, _
    GitConfig(test_repo)["merge.ff"] = "false"
    commit_to_merge = tip(lookup_branch(test_repo, "normal_merge"))
    status, cmmt = merge!(test_repo, commit_to_merge)
    @test status === :nonfastforward
    #@show cmmt
    @test is_fully_merged(test_repo)
end

with_merge_test_repo(
"test verify up to date merge") do test_repo, _
    commit_to_merge = tip(lookup_branch(test_repo, "master"))
    status, cmmt = merge!(test_repo, commit_to_merge, AnyDict(:strategy => :nofastforward))
    @test status === :uptodate
    @test is(cmmt, nothing)
    @test is_fully_merged(test_repo)
end

for (committish, strategy, estatus) in [
    ("refs/heads/normal_merge", :default, :nonfastforward),
    ("normal_merge", :default, :nonfastforward),
    (Oid("625186280ed2a6ec9b65d250ed90cf2e4acef957"), :default, :nonfastforward),
    ("fast_forward", :default, :fastforward)]

    with_merge_test_repo(
    "test can merge committish: $committish, $strategy, $estatus") do test_repo, _
        status, cmmt  = merge!(test_repo, committish, AnyDict(:ffstrategy => strategy))
        @test status === estatus
        @test is_fully_merged(test_repo)
    end
end

for (should_stage, strategy) in [(true, :fastforwardonly),
                                 (false, :fastforwardonly),
                                 (true, :nofastforward),
                                 (false, :nofastforward)]
    with_merge_test_repo(
    "test can merge with workdir conflicts throws: $should_stage, $strategy") do test_repo, _
        #=
        Merging the fast_forward branch results in a change to file
        b.txt. In this test we modify the file in the working directory
        and then attempt to perform a merge. We expect the merge to fail
        due to merge conflicts.
        =#
        committish_to_merge = "fast_forward"
        touch_test(workdir(test_repo), "b.txt", "this is an alternate change")
        #TODO: the libgit2 sharp stage concept is much cleaner, we should steal that
        if should_stage
            idx = GitIndex(test_repo)
            push!(idx, "b.txt")
            write!(idx)
        end
        if strategy === :fastforwardonly
            @test_throws LibGitError{:Checkout,:MergeConflict} merge!(test_repo,
                committish_to_merge, AnyDict(:ffstrategy => strategy))
        else
            @test_throws LibGitError{:Merge,:MergeConflict} merge!(test_repo,
                committish_to_merge, AnyDict(:ffstrategy => strategy))
        end
    end
end

for strategy in (:use_ours, :use_theirs)
    with_merge_test_repo(
        "test can specify conflict file strategy: $strategy") do test_repo, _

        conflict_file  = "a.txt"
        conflict_branchname = "conflicts"

        branch = lookup_branch(test_repo, conflict_branchname)
        @test branch != nothing

        opts = AnyDict(:strategy => strategy)
        status, cmmt = merge!(test_repo, branch, opts)

        @test status === :conflicts

        idx = GitIndex(test_repo)
        cs = conflicts(test_repo, idx)

        @test !isempty(cs)
        ancestor, ours, theirs= cs[1]
        blob = nothing
        if strategy === :use_theirs
            blob = lookup_blob(test_repo, theirs.id)
        elseif strategy === :use_ours
            blob = lookup_blob(test_repo, ours.id)
        else
            error("unexpected strategy")
        end
        @test blob != nothing
        @test bytestring(blob) == open(readall, joinpath(workdir(test_repo), conflict_file))
    end
end

for favor in (:favor_ours, :favor_theirs)
    with_merge_test_repo(
        "test merge can specify merge file flavor option") do test_repo, _

        conflict_file  = "a.txt"
        conflict_branchname = "conflicts"

        branch = lookup_branch(test_repo, conflict_branchname)

        @test branch != nothing

        opts = AnyDict(:automerge => favor)
        status, _ = merge!(test_repo, branch, opts)
        reload!(test_repo)

        @test status === :nonfastforward
        @test is_fully_merged(test_repo)

        idx = GitIndex(test_repo)

        blob = nothing
        if favor == :favor_theirs
            blob = lookup(test_repo, Oid("3dd9738af654bbf1c363f6c3bbc323bacdefa179"))
        elseif favor == :favor_ours
            blob = lookup(test_repo, Oid("610b16886ca829cebd2767d9196f3c4378fe60b5"))
        else
            error("unexpeted merge file test error")
        end
        @test blob != nothing

        entry = idx[conflict_file]
        @test entry != nothing

        @test Oid(blob) == Oid(entry)
        #@test bytestring(blob) == open(readall, joinpath(workdir(test_repo), conflict_file))
    end
end

for (branchname, strategy, estatus) in [
    ("refs/heads/normal_merge", :default, :nonfastforward),
    ("fast_forward", :default, :fastforward)]

    with_merge_test_repo(
    "test can merge branch: $branchname, $strategy, $estatus") do test_repo, _
        status, cmmt= merge!(test_repo, branchname, AnyDict(:ffstrategy => strategy))
        @test status === estatus
        @test is_fully_merged(test_repo)
    end
end

#=
with_merge_test_repo(
"test can merge into orphaned branch") do test_repo, _
    create_ref(test_repo, "HEAD", "refs/heads/orphan", force=true)
    # remove entried from the working dir
    idx = GitIndex(test_repo)
    remove_all!(idx, [entry.path for entry in idx])
    write!(idx)
    #assert that we have an empty working directory
    @test length(idx) == 0
    #run(`git --git-dir=$(path(test_repo)) status`)
    #merge!(test_repo, "master")
end
=#

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
