# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
context("test Signature constructor") do
    test_name   = "test test"
    test_email  = "test@test.com"
    test_time   = 0
    test_offset = 0

    # throw on bad name
    @test_throws LibGitError{:Invalid,:Error} Signature("", "")

    let sig = Signature(test_name, test_email, test_time, test_offset)
        @test sig.time == time(sig)
        @test sig.time_offset == time_offset(sig)
        @test time(sig) == test_time
        @test time_offset(sig) == test_offset
    end

    let now = floor(Int, time()), sig = Signature(test_name, test_email)
        @test time(sig) == now
    end
end

# TODO: Win32 Failure
context("test round-trip") do
    sig1 = Signature("test1", "test1@test.com")
    sig1_ptr = convert(Ptr{LibGit2.SignatureStruct}, sig1)
    sig2 = Signature(sig1_ptr)
    @test sig1 == sig2
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------

