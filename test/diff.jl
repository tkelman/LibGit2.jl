@sandboxed_test "attr" begin
    opts = parse_git_diff_options({:context_lines=>1, :interhunk_lines=>1})
    @test opts.context_lines == 1
    @test opts.interhunk_lines == 1
end

@sandboxed_test "attr" begin
  d = diff(test_repo, "605812a", "370fe9ec22", 
           {:context_lines=>1, :interhunk_lines=>1})
  @test isa(d, GitDiff)
  
  ds = deltas(d)
  ps = patches(d)

  hs = DiffHunk[]
  for p in ps
      hks = hunks(p)
      if hks == nothing
          continue
      end
      for h in hks
          push!(hs, h)
      end
  end
  ls = vcat([lines(h) for h in hs]...)
  
  @test length(d) == 5
  @test length(ds) == 5
  @test length(ps) == 5

  @test sum(x -> x.status == :added? 1 : 0, ds) == 2
  @test sum(x -> x.status == :deleted? 1 : 0, ds) == 1
  @test sum(x -> x.status == :modified? 1 : 0, ds) == 2

  @test length(hs) == 5

  @test (7 + 24 + 1 + 6 + 6) == length(ls)
  @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 1
  @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == (24 + 1 + 5 + 5)
  @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == (7 + 1)
end

@sandboxed_test "attr" begin
  d = diff(test_repo, "605812a", nothing,
           {:context_lines=>1, :interhunk_lines=>1})
  @test isa(d, GitDiff)

  ds = deltas(d)
  ps = patches(d)
  
  hs = DiffHunk[]
  for p in ps
      hks = hunks(p)
      if hks == nothing
          continue
      end
      for h in hks
          push!(hs, h)
      end
  end
  ls = vcat([lines(h) for h in hs]...)
  
  @test length(d) == 16
  @test length(ds) == 16
  @test length(ps) == 16

  @test sum(x -> x.status == :added? 1 : 0, ds) == 0
  @test sum(x -> x.status == :deleted? 1 : 0, ds) == 16
  @test sum(x -> x.status == :modified? 1 : 0, ds) == 0

  @test length(hs) == 15

  @test length(ls) == 115
  @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 0
  @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 0
  @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 113
end

@sandboxed_test "attr" begin
  d = diff(test_repo, nothing, "605812a", 
           {:context_lines=>1, :interhunk_lines=>1})
  @test isa(d, GitDiff)
  
  ds = deltas(d)
  ps = patches(d)
  
  hs = DiffHunk[]
  for p in ps
      hks = hunks(p)
      if hks == nothing
          continue
      end
      for h in hks
          push!(hs, h)
      end
  end
  ls = vcat([lines(h) for h in hs]...)
  
  @test length(d) == 16
  @test length(ds) == 16
  @test length(ps) == 16

  @test sum(x -> x.status == :added? 1 : 0, ds) == 16
  @test sum(x -> x.status == :deleted? 1 : 0, ds) == 0
  @test sum(x -> x.status == :modified? 1 : 0, ds) == 0

  @test length(hs) == 15
  
  @test length(ls) == 115
  @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 0
  @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 113
  @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 0
end


@sandboxed_test "status" begin
    d = diff_workdir(
             test_repo, "26a125ee1bf",
             {:context_lines => 3,
              :interhunk_lines => 1,
              :include_ignored => true,
              :include_untracked => true})
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
      
    @test length(ds) == 14 
    @test length(ps) == 14

    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 4
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 4
    @test sum(x -> x.status == :ignored? 1 : 0, ds) == 1
    @test sum(x -> x.status == :untracked? 1 : 0, ds) == 5

    @test length(hs) == 8

    @test length(ls) == 13
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 4
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 5
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 4
end

@sandboxed_test "attr" begin
    c = lookup_commit(test_repo, "605812a")
    @test isa(c, GitCommit)
    
    d = diff(test_repo, c, {:context_lines=>1, :interhunk_lines=>1})
    @test isa(d, GitDiff)

    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
    
    @test length(d)  == 5
    @test length(ds) == 5 
    @test length(ps) == 5

    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 3
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 2

    @test length(hs) == 4

    @test length(ls) == 51
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 2
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 3
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 46
end

@sandboxed_test "attr" begin
    c = lookup_commit(test_repo, 
                Oid("6bab5c79cd5140d0f800917f550eb2a3dc32b0da"))
    @test isa(c, GitCommit)
    
    d = diff(test_repo, c, 
        {:context_lines => 1, :interhunk_lines => 1, :reverse => true})
    @test isa(d, GitDiff)
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
     
    @test length(d)  == 13
    @test length(ds) == 13
    @test length(ps) == 13
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 13
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 0
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 0

    @test length(hs) == 13

    @test length(ls) == 72
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 0
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 70
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 0
end

@sandboxed_test "status" begin
    c = lookup_commit(test_repo, "26a125ee1bf")
    @test isa(c, GitCommit)
    
    d= diff_workdir(test_repo, c,
     {:context_lines => 3,
      :interhunk_lines => 1,
      :include_ignored => true,
      :include_untracked => true}
    )
    @test isa(d, GitDiff)
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
     
    @test length(ds) == 14
    @test length(ps) == 14
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 4
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 4
    @test sum(x -> x.status == :ignored? 1 : 0, ds) == 1
    @test sum(x -> x.status == :untracked? 1 : 0, ds) == 5

    @test length(hs) == 8

    @test length(ls) == 13
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 4
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 5 
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 4 
end 

@sandboxed_test "status" begin
    c = lookup_commit(test_repo, "26a125ee1bf")
    t = GitTree(c)
    @test isa(t, GitTree)
    
    d = diff_workdir(test_repo, t,
     {:context_lines => 3,
      :interhunk_lines => 1,
      :include_ignored => true,
      :include_untracked => true}
    )
    @test isa(d, GitDiff)
    
    ds = deltas(d)
    ps = patches(d)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
     
    @test length(ds) == 14
    @test length(ps) == 14
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 4
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 4
    @test sum(x -> x.status == :ignored? 1 : 0, ds) == 1
    @test sum(x -> x.status == :untracked? 1 : 0, ds) == 5

    @test length(hs) == 8

    @test length(ls) == 13
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 4
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 5 
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 4 
end 

@sandboxed_test "status" begin 
    idx = repo_index(test_repo)
    c = lookup_commit(test_repo, "26a125ee1bf")
    t = GitTree(c)

    # merge diffs to simulate "git diff 26a125ee1bf"
    diff1 = diff(test_repo, t, idx, 
                {:include_ignored=>true, :include_untracked=>true})
    diff2 = diff(test_repo, idx, 
                {:include_ignored=>true, :include_untracked=>true})
    merge!(diff1, diff2)

    ds = deltas(diff1)
    ps = patches(diff1)
      
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)
     
    @test length(ds) == 15
    @test length(ps) == 15
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 2
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 5
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 4
    @test sum(x -> x.status == :ignored? 1 : 0, ds) == 1
    @test sum(x -> x.status == :untracked? 1 : 0, ds) == 3

    @test length(hs) == 11

    @test length(ls) == 17
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 4
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 8 
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 5 
end

@sandboxed_test "status" begin 
    idx = repo_index(test_repo)
    c = lookup_commit(test_repo, "26a125ee1bf")
    t = GitTree(c)

    # merge diffs to simulate "git diff 26a125ee1bf"
    diff1 = diff(test_repo, t, idx, 
                {:include_ignored=>true, :include_untracked=>true})
    diff2 = diff(test_repo, idx, 
                {:include_ignored=>true, :include_untracked=>true})
    merge!(diff1, diff2)
    diff_stat = stat(diff1)
    
    @test diff_stat.files == 11 
    @test diff_stat.adds  == 8
    @test diff_stat.dels  == 5

    expected_patch_stat = [
      [ 0, 1, 1 ], [ 1, 0, 2 ], [ 1, 0, 2 ], [ 0, 1, 1 ], [ 2, 0, 3 ],
      [ 0, 1, 1 ], [ 0, 1, 1 ], [ 1, 0, 1 ], [ 2, 0, 2 ], [ 0, 1, 1 ],
      [ 1, 0, 2 ]
    ]

    i = 1 
    for patch in patches(diff1)
        s = delta(patch).status 
        if s == :unmodified || s == :ignored || s == :untracked
            continue
        end

        @test isa(patch, GitPatch)
        expected_adds  = expected_patch_stat[(i-1) * 3 + 1]
        expected_dels  = expected_patch_stat[(i-1) * 3 + 2]
        expected_lines = expected_patch_stat[(i-1) * 3 + 3]

        patch_stat = stat(patch)
       
        @test expected_adds == patch_stat.adds
        @test expected_dels == patch_stat.dels
        @test nchanges(patch) == patch_stat.adds + patch_stat.dels
        @test expected_lines == nlines(patch) 
        i += 1
    end
end

@sandboxed_test "attr" begin 
    a = GitTree(lookup_commit(test_repo, "605812a"))
    b = GitTree(lookup_commit(test_repo, "370fe9ec22"))
    c = GitTree(lookup_commit(test_repo, "f5b0af1fb4f5c"))

    d = diff(test_repo, a, b, {:context_lines => 1, :interhunk_lines => 1})
    ds = deltas(d)
    ps = patches(d)
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)

    @test length(d) == 5
    @test length(ds) == 5
    @test length(ps) == 5
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 2
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 1
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 2
    
    @test length(hs) == 5 

    @test length(ls) == (7 + 24 + 1 + 6 + 6)
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 1
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == (24 + 1 + 5 + 5)
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == (7 + 1) 

    d = diff(test_repo, c, b, {:context_lines => 1, :interhunk_lines => 1})
    ds = deltas(d)
    ps = patches(d)
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)

    @test length(ds) == 2
    @test length(ps) == 2
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 0
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 2
    
    @test length(hs) == 2

    @test length(ls) == (8 + 15)
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 1
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 1
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == (7 + 14) 
end

@sandboxed_test "attr" begin
    a = GitTree(lookup_commit(test_repo, "605812a"))
    d = diff(test_repo, a, nothing, {:context_lines => 1, :interhunk_lines => 1})
    ds = deltas(d)
    ps = patches(d)
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)

    @test length(d) == 16
    @test length(ds) == 16
    @test length(ps) == 16
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 16
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 0
    
    @test length(hs) == 15

    @test length(ls) == 115
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 0
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 0
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 113 
end

@sandboxed_test "attr" begin 
    a = GitTree(lookup_commit(test_repo, "605812a"))
    d = diff(test_repo, a, "370fe9ec22", 
                {:context_lines => 1, :interhunk_lines => 1})
    @test isa(d, GitDiff)
    ds = deltas(d)
    ps = patches(d)
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)

    @test length(d) == 5
    @test length(ds) == 5
    @test length(ps) == 5
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 2
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 1
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 2
    
    @test length(hs) == 5

    @test length(ls) == (7 + 24 + 1 + 6 + 6)
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 1
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == (24 + 1 + 5 + 5)
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == (7 + 1) 
end

@sandboxed_test "attr" begin
    a = GitTree(lookup_commit(test_repo, "605812a"))
    b = GitTree(lookup_commit(test_repo, "370fe9ec22"))
    c = GitTree(lookup_commit(test_repo, "f5b0af1fb4f5c"))

    ab = diff(test_repo, a, b)
    cb = diff(test_repo, c, b)
    d  = merge!(ab, cb)
    
    ds = deltas(d)
    ps = patches(d)
    hs = DiffHunk[]
    for p in ps
        hks = hunks(p)
        if hks == nothing
            continue
        end
        for h in hks
            push!(hs, h)
        end
    end
    ls = vcat([lines(h) for h in hs]...)

    @test length(d) == 6
    @test length(ds) == 6
    @test length(ps) == 6
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 2
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 1
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 3
    
    @test length(hs) == 6

    @test length(ls) == 59
    @test sum(x -> x.line_origin == :context? 1 : 0, ls) == 1
    @test sum(x -> x.line_origin == :addition? 1 : 0, ls) == 36
    @test sum(x -> x.line_origin == :deletion? 1 : 0, ls) == 22
end

@sandboxed_test "unsymlinked.git" begin
    a = GitTree(lookup_commit(test_repo, "7fccd7"))
    b = GitTree(lookup_commit(test_repo, "806999"))

    d = diff(test_repo, a, b)

    ds = deltas(d)
    ps = patches(d)

    @test length(d) == 3
    @test length(ds) == 3
    @test length(ps) == 3
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 1
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 2
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 0
    @test sum(x -> x.status == :typechange? 1 : 0, ds) == 0
end

@sandboxed_test "unsymlinked.git" begin
    a = GitTree(lookup_commit(test_repo, "7fccd7"))
    b = GitTree(lookup_commit(test_repo, "806999"))

    d = diff(test_repo, a, b, {:include_typechange => true})

    ds = deltas(d)
    ps = patches(d)

    @test length(d) == 2
    @test length(ds) == 2
    @test length(ps) == 2
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 1
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 0
    @test sum(x -> x.status == :typechange? 1 : 0, ds) == 1
end 


@sandboxed_test "unsymlinked.git" begin
    a = GitTree(lookup_commit(test_repo, "806999"))
    b = GitTree(lookup_commit(test_repo, "a8595c"))

    d = diff(test_repo, a, b)

    ds = deltas(d)
    ps = patches(d)

    @test length(d) == 1
    @test length(ds) == 1
    @test length(ps) == 1
    
    @test sum(x -> x.status == :added? 1 : 0, ds) == 0
    @test sum(x -> x.status == :deleted? 1 : 0, ds) == 0
    @test sum(x -> x.status == :modified? 1 : 0, ds) == 1
    @test sum(x -> x.status == :typechange? 1 : 0, ds) == 0
end 

@sandboxed_test "diff" begin
    a = lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69"))
    b = lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10"))

    d = diff(test_repo, GitTree(a), GitTree(b))
    @test length(d) == 2
end

@sandboxed_test "diff" begin
    a = lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69"))
    b = lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10"))

    d = diff(test_repo, GitTree(a), GitTree(b))
    ds = deltas(d)

    @test length(d) == 2 
    
    @test ds[1].old_file.path == "another.txt"
    @test ds[1].new_file.path == "another.txt"

    @test ds[1].isbinary == false

    @test ds[2].old_file.path == "readme.txt"
    @test ds[2].new_file.path == "readme.txt"

    @test ds[2].isbinary == false
end

@sandboxed_test "diff" begin
    a = lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69"))
    b = lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10"))
    d = diff(test_repo, GitTree(a), GitTree(b), {:max_size=>10})
    @test length(patches(d)) == 2 
    @test patch(d) == "diff --git a/another.txt b/another.txt
index 3e5bcba..546c735 100644
Binary files a/another.txt and b/another.txt differ
diff --git a/readme.txt b/readme.txt
index 7b808f7..29ab705 100644
Binary files a/readme.txt and b/readme.txt differ
"
end

@sandboxed_test "diff" begin
    a = GitTree(lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")))
    b = GitTree(lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")))
    
    d = diff(test_repo, a, b, {:paths => ["readme.txt"]})
    @test "M\treadme.txt\n" == patch(d, compact=true)

    d = diff(test_repo, a, b, {:paths => ["r*.txt"]})
    @test "M\treadme.txt\n" == patch(d, compact=true)

    d = diff(test_repo, a, b, {:paths => ["*.txt"]})
    @test "M\tanother.txt\nM\treadme.txt\n" == patch(d, compact=true)

    d = diff(test_repo, a, b, {:paths => ["*.txt"], :disable_pathspec_match => true})
    @test "" == patch(d, compact=true)

    d = diff(test_repo, a, b, {:paths => ["readme.txt"], :disable_pathspec_match => true})
    @test "M\treadme.txt\n" == patch(d, compact=true)
end
