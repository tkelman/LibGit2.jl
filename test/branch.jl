with_tmp_repo_access() do test_repo, path
    context("test list all names") do
        @test [
            "master",
            "origin/HEAD",
            "origin/master",
            "origin/packed"
        ] == sort(branch_names(test_repo))
    end

    context("test list only local branches") do
        @test ["master"] == sort(branch_names(test_repo, :local))
    end

    context("test list only remote branches") do
       @test [
           "origin/HEAD",
           "origin/master",
           "origin/packed",
       ] == sort(branch_names(test_repo, :remote))
    end

    context("test get latest commit in branch") do
       t = lookup_branch(test_repo, "master") |> tip
       @test isa(t, GitCommit)
       @test Oid(t) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    end

    context("test lookup local branch") do
       b = lookup_branch(test_repo, "master")
       @test b != nothing
       @test name(b) == "master"
       @test canonical_name(b) == "refs/heads/master"
       @test Oid(tip(b)) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    end

    context("test lookup remote branches") do
       b = lookup_branch(test_repo, "origin/packed", :remote)
       @test b != nothing

       @test name(b) == "origin/packed"
       @test canonical_name(b) == "refs/remotes/origin/packed"
       @test Oid(tip(b)) == Oid("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9")
    end

    context("test branch equality") do
        b1 = lookup_branch(test_repo, "master")
        b2 = lookup_branch(test_repo, "master")
        @test b1 == b2

        b1 = lookup_branch(test_repo, "master")
        b2 = lookup_branch(test_repo, "origin/packed", :remote)
        @test b1 != b2
    end
end

with_tmp_repo_access("test lookup unicode branch name") do test_repo, path
    new_branch = create_branch(test_repo, "Ångström",
        Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test new_branch != nothing

    retrieved_branch = lookup_branch(test_repo, "Ångström")
    @test new_branch != nothing

    @test new_branch == retrieved_branch
end

with_tmp_repo_access("test delete branch") do test_repo, path
    b = create_branch(test_repo, "test_branch")
    delete!(b)
    @test lookup_branch(test_repo, "test_branch") == nothing
end

with_tmp_repo_access("test is head") do test_repo, path
    @test ishead(lookup_branch(test_repo, "master"))
    @test ishead(lookup_branch(test_repo, "origin/master", :remote)) == false
    @test ishead(lookup_branch(test_repo, "origin/packed", :remote)) == false
    @test ishead(create_branch(test_repo, "test_branch")) == false
end

with_tmp_repo_access("test rename branch") do test_repo, path
    b = create_branch(test_repo, "test_branch")
    rename(b, "other_branch")
    @test lookup_branch(test_repo, "test_branch") == nothing
    @test isa(lookup_branch(test_repo, "other_branch"), GitBranch)
end

with_tmp_repo_access("test create new branch") do test_repo, path
    new_branch = create_branch(test_repo, "test_branch",
        Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test Oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    @test any(b -> name(b) == "test_branch", foreach(GitBranch, test_repo))
end

with_tmp_repo_access("test create unicode branch") do test_repo, path
    branch_name = "A\314\212ngstro\314\210m"
    new_branch = create_branch(test_repo, branch_name,
                        Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))

    @test new_branch != nothing
    @test normalize_string(branch_name, :NFC) == normalize_string(name(new_branch), :NFC)
    @test normalize_string(canonical_name(new_branch), :NFC) == normalize_string("refs/heads/$branch_name", :NFC)

    @test tip(new_branch) != nothing
    @test Oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")

    @test any(b -> normalize_string(name(b), :NFC) == normalize_string(branch_name, :NFC),
              foreach(GitBranch, test_repo))
end

with_tmp_repo_access("test create branch short sha") do test_repo, path
    new_branch = create_branch(test_repo, "test_branch", "5b5b025")

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test Oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")

    @test any(b -> name(b) == "test_branch", foreach(GitBranch, test_repo))
end

with_tmp_repo_access("test create branch from tag") do test_repo, path
    new_branch = create_branch(test_repo, "test_branch", "refs/tags/v0.9")

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test Oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")

    @test any(b -> name(b) == "test_branch", foreach(GitBranch, test_repo))
end

with_tmp_repo_access("test create branch from head") do test_repo, path
    new_branch = create_branch(test_repo, "test_branch")

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test Oid(tip(new_branch)) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")

    @test any(b -> name(b) == "test_branch", foreach(GitBranch, test_repo))
end

with_tmp_repo_access("test create branch explicit head") do test_repo, path
    new_branch = create_branch(test_repo, "test_branch", "HEAD")

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test Oid(tip(new_branch)) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")

    @test any(b -> name(b) == "test_branch", foreach(GitBranch, test_repo))
end

with_tmp_repo_access("test create branch from commit") do test_repo, path
    new_branch = create_branch(test_repo, "test_branch",
      lookup_commit(test_repo, Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")))

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test Oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")

    @test any(b -> name(b) == "test_branch", foreach(GitBranch, test_repo))
end

with_tmp_repo_access("test create branch from unknown ref fails") do test_repo, path
    @test_throws LibGitError{:Ref,:NotFound} create_branch(test_repo,
                                                    "test_branch", "i_do_not_exist")
end

with_tmp_repo_access("test create branch from unknown commit fails") do test_repo, path
 @test_throws LibGitError{:Odb,:NotFound} create_branch(test_repo, "test_branch",
        Oid("dd15de908706711b51b7acb24faab726d2b3cb16"))
end

with_tmp_repo_access("test create branch from non canonical fails") do test_repo, path
    @test_throws LibGitError{:Ref,:NotFound} create_branch(test_repo,
                                                           "test_branch", "packed")
end

with_tmp_repo_access("test remote branch") do test_repo, path
    @test "origin" == (lookup_branch(test_repo, "origin/master", :remote)
                       |> remote |> name)
end

with_tmp_repo_access("test branch remote local tracking remote") do test_repo, path
     @test "origin" == (lookup_branch(test_repo, "master", :local)
                        |> remote |> name)
end

with_tmp_repo_access("test branch remote local non-tracking") do test_repo, path
        b = create_branch(test_repo, "test_branch",
                Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
        @test remote(b) == nothing
end

with_tmp_repo_access("test branch upstream") do test_repo, path
    upstream_branch = lookup_branch(test_repo, "master", :local) |> upstream
    @test "origin/master" == name(upstream_branch)
end

with_tmp_repo_access("test upstream remote branch") do test_repo, path
    @test nothing == (lookup_branch(test_repo, "origin/master", :remote)
                      |> upstream)
end

with_tmp_repo_access("test branch upstream no tracking branch") do test_repo, path
    branch = create_branch(test_repo, "test_branch",
                           Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test upstream(branch) == nothing
end

with_tmp_repo_access("test branch set upstream with reference") do test_repo, path
    b = create_branch(test_repo, "test_branch",
                 Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))

    set_upstream!(b, lookup_ref(test_repo, "refs/heads/master"))
    @test name(upstream(b)) == "master"
end

with_tmp_repo_access("test branch set upstream with tag reference") do test_repo, path
    b = create_branch(test_repo, "test_branch",
            Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    r = lookup_ref(test_repo, "refs/tags/v1.0")
    @test_throws LibGitError{:Invalid,:Error} set_upstream!(b, r)
end

with_tmp_repo_access("test branch set upstream local") do test_repo, path
    b = create_branch(test_repo, "test_branch",
                Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))

    set_upstream!(b, lookup_branch(test_repo, "master", :local))
    @test (upstream(b) |> name) == "master"
end

with_tmp_repo_access("test branch set upstream remote") do test_repo, path
    b = create_branch(test_repo, "test_branch",
                Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    set_upstream!(b, lookup_branch(test_repo, "origin/master", :remote))
    @test name(upstream(b)) == "origin/master"
end

with_tmp_repo_access("test branch unset upstream") do test_repo, path
    b = lookup_branch(test_repo, "master", :local)
    @test upstream(b) != nothing
    set_upstream!(b, nothing)
    @test upstream(b) == nothing
end

with_tmp_repo_access("test branch set upstream on remote branch") do test_repo, path
    b1 = lookup_branch(test_repo, "origin/master", :remote)
    b2 = create_branch(test_repo, "test_branch",
                      Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test_throws LibGitError{:Invalid,:Error} set_upstream!(b1, b2)
end
