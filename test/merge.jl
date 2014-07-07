sandboxed_test("merge-resolve", "test merge no conflict") do test_repo, path
    ours   = rev_parse(test_repo, "trivial-2alt")
    theirs = rev_parse(test_repo, "trivial-2alt-branch")
    base   = rev_parse(test_repo, merge_base(test_repo, ours, theirs))
    
    #TODO: merge should not have to take the repo as a parameter
    idx = merge!(test_repo, GitTree(ours), GitTree(theirs), GitTree(base))
    @test has_conflicts(idx) == false
end

sandboxed_test("merge-resolve", "test merge has conflicts") do test_repo, path
    ours   = rev_parse(test_repo, "trivial-4")
    theirs = rev_parse(test_repo, "trivial-4-branch")
    base   = rev_parse(test_repo, merge_base(test_repo, ours, theirs))
    idx = merge!(test_repo, GitTree(ours), GitTree(theirs), GitTree(base))
    @test has_conflicts(idx) 
    @test sum(entry -> entry.stage > 0, idx) == 2
    @test idx["new-and-different.txt", 2] != nothing 
    @test idx["new-and-different.txt", 3] != nothing
end
