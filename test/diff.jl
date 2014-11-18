sandboxed_test("attr", "test parse diff options") do test_repo, path
    opts = parse_git_diff_options(AnyDict(:context_lines=>1, :interhunk_lines=>1))
    @test opts.context_lines == 1
    @test opts.interhunk_lines == 1
end

sandboxed_test("attr", "test with oid string") do test_repo, path
  d = diff(test_repo, "605812a", "370fe9ec22",
           AnyDict(:context_lines=>1, :interhunk_lines=>1))
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
  @test  sum(x -> x.line_origin == :context? 1 : 0, ls) == 1
  @test  sum(x -> x.line_origin == :addition? 1 : 0, ls) == (24 + 1 + 5 + 5)
  @test  sum(x -> x.line_origin == :deletion? 1 : 0, ls) == (7 + 1)
end

#= TODO:
sandboxed_test("attr", "test delta status char") do test_repo, path
    d  = diff(test_repo, "605812a", "370fe9ec22", AnyDict(:context_lines=>1, :interhunk_lines=>1))
    ds = deltas(d)
    @test "D" == ds[1].status_char
    @test "A" == ds[2].status_char
    @test "A" == ds[3].status_char
    @test "M" == ds[4].status_char
    @test "M" == ds[5].status_char
end
=#

sandboxed_test("attr", "test with nothing on right side") do test_repo, path
  d = diff(test_repo, "605812a", nothing, AnyDict(:context_lines=>1, :interhunk_lines=>1))
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

sandboxed_test("attr", "test with nothing on left side") do test_repo, path
  d = diff(test_repo, nothing, "605812a", AnyDict(:context_lines=>1, :interhunk_lines=>1))
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

sandboxed_test("status", "test basic diff") do test_repo, path
    d = diff_workdir(
             test_repo, "26a125ee1bf",
             AnyDict(:context_lines => 3,
                  :interhunk_lines => 1,
                  :include_ignored => true,
                  :include_untracked => true))
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

sandboxed_test("attr", "test diff with parent") do test_repo, path
    c = lookup_commit(test_repo, "605812a")
    @test isa(c, GitCommit)

    d = diff(test_repo, c, AnyDict(:context_lines=>1, :interhunk_lines=>1))
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

sandboxed_test("attr", "test diff with parent for init commit") do test_repo, path
    c = lookup_commit(test_repo,
                Oid("6bab5c79cd5140d0f800917f550eb2a3dc32b0da"))
    @test isa(c, GitCommit)

    d = diff(test_repo, c,
        AnyDict(:context_lines => 1, :interhunk_lines => 1, :reverse => true))
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

sandboxed_test("status", "test commit to workdir basic diff") do test_repo, path
    c = lookup_commit(test_repo, "26a125ee1bf")
    @test isa(c, GitCommit)

    d= diff_workdir(test_repo, c,
     AnyDict(:context_lines => 3,
          :interhunk_lines => 1,
          :include_ignored => true,
          :include_untracked => true))

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

sandboxed_test("status", "test tree to workdir basic diff") do test_repo, path
    c = lookup_commit(test_repo, "26a125ee1bf")
    t = GitTree(c)
    @test isa(t, GitTree)

    d = diff_workdir(test_repo, t,
     AnyDict(:context_lines => 3,
             :interhunk_lines => 1,
             :include_ignored => true,
             :include_untracked => true))
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

sandboxed_test("status", "test tree to workdir diff merge") do test_repo, path
    idx = GitIndex(test_repo)
    c = lookup_commit(test_repo, "26a125ee1bf")
    t = GitTree(c)

    # merge diffs to simulate "git diff 26a125ee1bf"
    diff1 = diff(test_repo, t, idx,
                AnyDict(:include_ignored=>true, :include_untracked=>true))
    diff2 = diff(test_repo, idx,
                AnyDict(:include_ignored=>true, :include_untracked=>true))
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

sandboxed_test("status", "test tree to workdir diff stats") do test_repo, path
    idx = GitIndex(test_repo)
    c = lookup_commit(test_repo, "26a125ee1bf")
    t = GitTree(c)

    # merge diffs to simulate "git diff 26a125ee1bf"
    diff1 = diff(test_repo, t, idx,
                AnyDict(:include_ignored=>true, :include_untracked=>true))
    diff2 = diff(test_repo, idx,
                AnyDict(:include_ignored=>true, :include_untracked=>true))
    merge!(diff1, diff2)
    diff_stat = stat(diff1)

    @test diff_stat.files == 11
    @test diff_stat.adds  == 8
    @test diff_stat.dels  == 5

    expected_patch_stat = Any[
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
        expected_adds  = expected_patch_stat[i][1]
        expected_dels  = expected_patch_stat[i][2]
        expected_lines = expected_patch_stat[i][3]

        patch_stat = stat(patch)

        @test expected_adds == patch_stat.adds
        @test expected_dels == patch_stat.dels
        @test nchanges(patch) == patch_stat.adds + patch_stat.dels
        #@test expected_lines == nlines(patch)
        i += 1
    end
end

sandboxed_test("attr", "test tree to tree basic diff") do test_repo, path
    a = GitTree(lookup_commit(test_repo, "605812a"))
    b = GitTree(lookup_commit(test_repo, "370fe9ec22"))
    c = GitTree(lookup_commit(test_repo, "f5b0af1fb4f5c"))

    d = diff(test_repo, a, b, AnyDict(:context_lines => 1, :interhunk_lines => 1))
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

    d = diff(test_repo, c, b, AnyDict(:context_lines => 1, :interhunk_lines => 1))
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

sandboxed_test("attr", "test tree to tree with empty tree") do test_repo, path
    a = GitTree(lookup_commit(test_repo, "605812a"))
    d = diff(test_repo, a, nothing, AnyDict(:context_lines => 1, :interhunk_lines => 1))
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

sandboxed_test("attr", "test tree to tree with rev string") do test_repo, path
    a = GitTree(lookup_commit(test_repo, "605812a"))
    d = diff(test_repo, a, "370fe9ec22",
                AnyDict(:context_lines => 1, :interhunk_lines => 1))
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

sandboxed_test("attr", "test tree to tree with diff merge") do test_repo, path
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

sandboxed_test("unsymlinked.git", "test symlink blob mode changed to reg file") do test_repo, path
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

sandboxed_test("unsymlinked.git", "test symlink blob mode changed to reg file as typechange") do test_repo, path
    a = GitTree(lookup_commit(test_repo, "7fccd7"))
    b = GitTree(lookup_commit(test_repo, "806999"))

    d = diff(test_repo, a, b, AnyDict(:include_typechange => true))

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


sandboxed_test("unsymlinked.git", "test regular blob mode change to exe file") do test_repo, path
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

sandboxed_test("diff", "test size") do test_repo, path
    a = lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69"))
    b = lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10"))

    d = diff(test_repo, GitTree(a), GitTree(b))
    @test length(d) == 2
end

sandboxed_test("diff", "test each delta") do test_repo, path
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

sandboxed_test("diff", "test diff treats files bigger than max size as binary") do test_repo, path
    a = lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69"))
    b = lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10"))
    d = diff(test_repo, GitTree(a), GitTree(b), AnyDict(:max_size=>10))
    @test length(patches(d)) == 2
    @test patch(d) == replace("diff --git a/another.txt b/another.txt
index 3e5bcba..546c735 100644
Binary files a/another.txt and b/another.txt differ
diff --git a/readme.txt b/readme.txt
index 7b808f7..29ab705 100644
Binary files a/readme.txt and b/readme.txt differ
", "\r\n", "\n")
end

sandboxed_test("diff", "test constraining paths") do test_repo, path
    a = GitTree(lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")))
    b = GitTree(lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")))

    d = diff(test_repo, a, b, AnyDict(:paths => ["readme.txt"]))
    @test "M\treadme.txt\n" == patch(d, format=:name_status)

    d = diff(test_repo, a, b, AnyDict(:paths => ["r*.txt"]))
    @test "M\treadme.txt\n" == patch(d, format=:name_status)

    d = diff(test_repo, a, b, AnyDict(:paths => ["*.txt"]))
    @test "M\tanother.txt\nM\treadme.txt\n" == patch(d, format=:name_status)

    d = diff(test_repo, a, b, AnyDict(:paths => ["*.txt"], :disable_pathspec_match => true))
    @test "" == patch(d, format=:name_status)

    d = diff(test_repo, a, b, AnyDict(:paths => ["readme.txt"], :disable_pathspec_match => true))
    @test "M\treadme.txt\n" == patch(d, format=:name_status)
end

sandboxed_test("diff", "test patch") do test_repo, path
    a = GitTree(lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")))
    b = GitTree(lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")))
    d = diff(test_repo, a, b, AnyDict(:context_lines => 0))

    @test patch(d) == replace("diff --git a/another.txt b/another.txt
index 3e5bcba..546c735 100644
--- a/another.txt
+++ b/another.txt
@@ -2 +2 @@ Git is fast. With Git, nearly all operations are performed locally, giving
-it a huge speed advantage on centralized systems that constantly have to
+it an huge speed advantage on centralized systems that constantly have to
@@ -11,4 +10,0 @@ from the start.
-Let's see how common operations stack up against Subversion, a common
-centralized version control system that is similar to CVS or
-Perforce. Smaller is faster.
-
@@ -34,0 +31,4 @@ SVN.
+Let's see how common operations stack up against Subversion, a common
+centralized version control system that is similar to CVS or
+Perforce. Smaller is faster.
+
diff --git a/readme.txt b/readme.txt
index 7b808f7..29ab705 100644
--- a/readme.txt
+++ b/readme.txt
@@ -1 +1 @@
-The Git feature that really makes it stand apart from nearly every other SCM
+The Git feature that r3ally mak3s it stand apart from n3arly 3v3ry other SCM
@@ -10,4 +9,0 @@ This means that you can do things like:
-Frictionless Context Switching. Create a branch to try out an idea, commit a
-few times, switch back to where you branched from, apply a patch, switch
-back to where you are experimenting, and merge it in.
-
@@ -27,3 +22,0 @@ Notably, when you push to a remote repository, you do not have to push all
-of your branches. You can choose to share just one of your branches, a few
-of them, or all of them. This tends to free people to try new ideas without
-worrying about having to plan how and when they are going to merge it in or
@@ -35 +28 @@ incredibly easy and it changes the way most developers work when they learn
-it.
+it.!
\\ No newline at end of file
", "\r\n", "\n")
end

sandboxed_test("diff", "test iteration") do test_repo, path
    a = GitTree(lookup(test_repo, Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")))
    b = GitTree(lookup(test_repo, Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")))
    d = diff(test_repo, a, b)

    ps = patches(d)
    @test length(ps) == 2

    @test "another.txt" == delta(ps[1]).old_file.path
    @test "another.txt" == delta(ps[1]).new_file.path

    @test delta(ps[1]).isbinary == false

    hs = hunks(ps[1])
    @test length(hs) == 3

    @test beginswith(hs[1].header, "@@ -1,5 +1,5 @@")
    @test beginswith(hs[2].header, "@@ -8,10 +8,6 @@")
    @test beginswith(hs[3].header, "@@ -32,6 +28,10 @@")

    @test "readme.txt" == delta(ps[2]).old_file.path
    @test "readme.txt" == delta(ps[2]).new_file.path

    @test delta(ps[2]).isbinary == false

    hs = hunks(ps[2])
    @test length(hs) == 3

    @test beginswith(hs[1].header, "@@ -1,4 +1,4 @@")
    @test beginswith(hs[2].header, "@@ -7,10 +7,6 @@")
    @test beginswith(hs[3].header, "@@ -24,12 +20,9 @@")

    ls = lines(hs[1])
    @test length(ls) == 5

    @test :deletion == ls[1].line_origin
    @test "The Git feature that really makes it stand apart from nearly every other SCM\n" == ls[1].content
    @test 0 == ls[1].content_offset

    @test :addition == ls[2].line_origin
    @test "The Git feature that r3ally mak3s it stand apart from n3arly 3v3ry other SCM\n" == ls[2].content
    @test 0 == ls[2].content_offset

    @test :context == ls[3].line_origin
    @test "out there is its branching model.\n" == ls[3].content
    @test ls[3].content_offset == nothing

    @test :context == ls[4].line_origin
    @test "\n" == ls[4].content

    @test :context == ls[5].line_origin
    @test "Git allows and encourages you to have multiple local branches that can be\n" == ls[5].content

    ls = lines(hs[3])

    @test length(ls) == 14

    @test :deletion == ls[4].line_origin
    @test "of your branches. You can choose to share just one of your branches, a few\n" == ls[4].content
    @test 1248 == ls[4].content_offset

    @test :deletion == ls[5].line_origin
    @test "of them, or all of them. This tends to free people to try new ideas without\n" == ls[5].content
    @test 1323 == ls[5].content_offset

    @test :deletion == ls[12].line_origin
    @test "it.\n" == ls[12].content
    @test 1721 == ls[12].content_offset

    @test :addition == ls[13].line_origin
    @test "it.!" == ls[13].content
    @test 1289 == ls[13].content_offset
end

sandboxed_test("diff", "test patch compact") do test_repo, path
    a = GitTree(test_repo[Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")])
    b = GitTree(test_repo[Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")])
    d = diff(test_repo, a, b)
    @test patch(d, format=:name_status) == replace("M\tanother.txt
M\treadme.txt
", "\r\n", "\n")
end

sandboxed_test("diff", "test stats") do test_repo, path
    a = GitTree(test_repo[Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")])
    b = GitTree(test_repo[Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")])
    d = diff(test_repo, a, b)

    diff_stat = stat(d)
    @test diff_stat.files == 2
    @test diff_stat.adds  == 7
    @test diff_stat.dels  == 14

    expected_patch_stat = Any[[ 5, 5, 26 ], [ 2, 9, 28 ]]

    for (patch, expected) in zip(patches(d), expected_patch_stat)
        patch_stat = stat(patch)
        @test expected[1] == patch_stat.adds
        @test expected[2] == patch_stat.dels
        @test expected[3] == nlines(patch)
    end
end
