@with_tmp_repo_access begin
    begin :test_list_all_names
        @test [
            "master",
            "origin/HEAD",
            "origin/master",
            "origin/packed"
        ] == sort(branch_names(test_repo))
    end

    begin :test_list_only_local_branches
        @test ["master"] == sort(branch_names(test_repo, :local))
    end

   begin :test_list_only_remote_branches
       @test [
           "origin/HEAD",
           "origin/master",
           "origin/packed",
       ] == sort(branch_names(test_repo, :remote))
   end

   begin :test_get_latest_commit_in_branch
       t = lookup_branch(test_repo, "master") |> tip
       @test isa(t, GitCommit)
       @test oid(t) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
   end

   begin :test_lookup_local_branch
       b = lookup_branch(test_repo, "master")
       @test b != nothing 
       @test name(b) == "master"
       @test canonical_name(b) == "refs/heads/master"
       @test oid(tip(b)) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
  end

  begin :test_lookup_remote_branches
       b = lookup_branch(test_repo, "origin/packed", :remote)
       @test b != nothing

       @test name(b) == "origin/packed"
       @test canonical_name(b) == "refs/remotes/origin/packed"
       @test oid(tip(b)) == Oid("41bc8c69075bbdb46c5c6f0566cc8cc5b46e8bd9")
  end
end

@show :test_lookup_unicode_branch_name
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "Ångström", 
        Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test new_branch != nothing

    retrieved_branch = lookup_branch(test_repo, "Ångström")
    @test new_branch != nothing

    @test new_branch == retrieved_branch
end

@show :test_delete_branch
@with_tmp_repo_access begin
    b = create_branch(test_repo, "test_branch")
    delete!(b)
    @test lookup_branch(test_repo, "test_branch") == nothing
end

@show :test_is_head
@with_tmp_repo_access begin
    @test ishead(lookup_branch(test_repo, "master"))
    @test ishead(lookup_branch(test_repo, "origin/master", :remote)) == false
    @test ishead(lookup_branch(test_repo, "origin/packed", :remote)) == false
    @test ishead(create_branch(test_repo, "test_branch")) == false
end

@show :test_rename_branch
@with_tmp_repo_access begin
    b = create_branch(test_repo, "test_branch")
    rename(b, "other_branch")
    @test lookup_branch(test_repo, "test_branch") == nothing
    @test isa(lookup_branch(test_repo, "other_branch"), GitBranch)
end

@show :test_create_new_branch
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "test_branch", 
        Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    
    @test any(b -> name(b) == "test_branch", iter_branches(test_repo))
end

@show :test_create_unicode_branch
@with_tmp_repo_access begin
    branch_name = "A\314\212ngstro\314\210m"
    new_branch = create_branch(test_repo, branch_name,
                        Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))

    @test new_branch != nothing
    @test branch_name == name(new_branch)
    @test canonical_name(new_branch) == "refs/heads/$branch_name"

    @test tip(new_branch) != nothing
    @test oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")

    @test any(b -> name(b) == branch_name, iter_branches(test_repo))
end

@show :test_create_branch_short_sha
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "test_branch", "5b5b025")

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    
    @test any(b -> name(b) == "test_branch", iter_branches(test_repo))
end

@show :test_create_branch_from_tag
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "test_branch", "refs/tags/v0.9")

    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    
    @test any(b -> name(b) == "test_branch", iter_branches(test_repo))
end

@show :test_create_branch_from_head
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "test_branch")
    
    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test oid(tip(new_branch)) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    
    @test any(b -> name(b) == "test_branch", iter_branches(test_repo))
end

@show :test_create_branch_explicit_head
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "test_branch", "HEAD")
    
    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test oid(tip(new_branch)) == Oid("36060c58702ed4c2a40832c51758d5344201d89a")
    
    @test any(b -> name(b) == "test_branch", iter_branches(test_repo))
end

@show :test_create_branch_from_commit
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "test_branch",
      lookup_commit(test_repo, Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")))
    
    @test new_branch != nothing
    @test name(new_branch) ==  "test_branch"
    @test canonical_name(new_branch) == "refs/heads/test_branch"

    @test tip(new_branch) != nothing
    @test oid(tip(new_branch)) == Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")
    
    @test any(b -> name(b) == "test_branch", iter_branches(test_repo))
end

@show :test_create_branch_from_unknown_ref_fails
@with_tmp_repo_access begin
    @test_throws create_branch(test_repo, "test_branch", "i_do_not_exist")
end

@show :test_create_branch_from_unknown_commit_fails
@with_tmp_repo_access begin
 @test_throws create_branch(test_repo, "test_branch",
        Oid("dd15de908706711b51b7acb24faab726d2b3cb16"))
end

@show :test_create_branch_from_non_canonical_fails
@with_tmp_repo_access begin
    @test_throws create_branch(test_repo, "test_branch", "packed")
end

@show :test_branch_remote_remote_branch
@with_tmp_repo_access begin
    @test "origin" == (lookup_branch(test_repo, "origin/master", :remote) 
                       |> remote |> name)
end

@show :test_branch_remote_local_tracking_remote_branch
@with_tmp_repo_access begin
     @test "origin" == (lookup_branch(test_repo, "master", :local)
                        |> remote |> name)
end

@show :test_branch_remote_local_non_tracking_branch
@with_tmp_repo_access begin
        b = create_branch(test_repo, "test_branch",
                Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
        @test remote(b) == nothing 
end

@show :test_branch_upstream
@with_tmp_repo_access begin
    upstream_branch = lookup_branch(test_repo, "master", :local) |> upstream
    @test "origin/master" == name(upstream_branch)
end

@show :test_branch_upstream_remote_branch
@with_tmp_repo_access  begin
    @test nothing == (lookup_branch(test_repo, "origin/master", :remote)
                      |> upstream)
end

@show :test_branch_upstream_no_tracking_branch
@with_tmp_repo_access  begin
    branch = create_branch(test_repo, "test_branch",
                           Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test upstream(branch) == nothing
end

@show :test_branch_set_upstream_with_reference
@with_tmp_repo_access  begin
    b = create_branch(test_repo, "test_branch",
                 Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))

    set_upstream!(b, lookup_ref(test_repo, "refs/heads/master"))
    @test name(upstream(b)) == "master"
end

@show :test_branch_set_upstream_with_tag_reference
@with_tmp_repo_access  begin
    b = create_branch(test_repo, "test_branch", 
            Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test_throws set_upstream!(b, lookup_ref(test_repo, "refs/tags/v1.0"))
end

@show :test_branch_set_upstream_local
@with_tmp_repo_access  begin
    b = create_branch(test_repo, "test_branch",
                Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    
    set_upstream!(b, lookup_branch(test_repo, "master", :local))
    @test (upstream(b) |> name) == "master"
end

@show :test_branch_set_upstream_remote
@with_tmp_repo_access  begin
    b = create_branch(test_repo, "test_branch",
                Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    set_upstream!(b, lookup_branch(test_repo, "origin/master", :remote))
    @test name(upstream(b)) == "origin/master"
end

@show :test_branch_unset_upstream
@with_tmp_repo_access  begin
    b = lookup_branch(test_repo, "master", :local)
    @test upstream(b) != nothing
    set_upstream!(b, nothing)
    @test upstream(b) == nothing
end

@show :test_branch_set_upstream_on_remote_branch
@with_tmp_repo_access  begin
    b = lookup_branch(test_repo, "origin/master", :remote)
    @test_throws set_upstream!(b, 
        create_branch(test_repo, "test_branch",
                      Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644")))
end
