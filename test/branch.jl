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

# test_lookup_unicode_branch_name
@with_tmp_repo_access begin
    new_branch = create_branch(test_repo, "Ångström", 
        Oid("5b5b025afb0b4c913b4c338a42934a3863bf3644"))
    @test new_branch != nothing

    retrieved_branch = lookup_branch(test_repo, "Ångström")
    @test new_branch != nothing

    @test new_branch == retrieved_branch
end


# test_delete_branch
@with_tmp_repo_access begin
    b = create_branch(test_repo, "test_branch")
    delete!(b)
    @test lookup_branch(test_repo, "test_branch") == nothing
end

# test_is_head
@with_tmp_repo_access begin
    @test ishead(lookup_branch(test_repo, "master"))
    @test ishead(lookup_branch(test_repo, "origin/master", :remote)) == false
    @test ishead(lookup_branch(test_repo, "origin/packed", :remote)) == false
    @test ishead(create_branch(test_repo, "test_branch")) == false
end

# test_rename_branch
@with_tmp_repo_access begin
    b = create_branch(test_repo, "test_branch")
    rename(b, "other_branch")
    @test lookup_branch(test_repo, "test_branch") == nothing
    @test isa(lookup_branch(test_repo, "other_branch"), GitBranch)
end
