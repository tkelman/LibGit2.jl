# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
context("test Signature constructor") do
    const test_name   = "test test"
    const test_email  = "test@test.com"
    const test_time   = 0
    const test_offset = 0

    # throw on bad name
    @test_throws LibGitError{:Invalid,:Error} Signature("", "")
    
    let sig = Signature(test_name, test_email, test_time, test_offset)
        @test sig.time == time(sig)
        @test sig.time_offset == time_offset(sig)
        @test time(sig) == test_time
        @test time_offset(sig) == test_offset
    end
    
    let now = ifloor(time()), sig = Signature(test_name, test_email)
        @test time(sig) == now
    end
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
