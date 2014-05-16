# ------------------------------------
# Tests adapted from Git2Go Library
# ------------------------------------
const test_name   = "test test"
const test_email  = "test@test.com"
const test_time   = 0
const test_offset = 0

# throw on bad name
@test_throws LibGitError{:Invalid,:Error} Signature("", "")

# throw error on bad time
# this fails with recent builds of julia that
# introduced automatic conversion for type fields
#@test_throws Signature(test_name, test_email, 0.0, 0.0)

let sig = Signature(test_name, test_email, test_time, test_offset)
    @test sig.time == time(sig)
    @test sig.time_offset == time_offset(sig)
    @test time(sig) == test_time
    @test time_offset(sig) == test_offset
end

let now = ifloor(time()), sig = Signature(test_name, test_email)
    @test time(sig) == now
end

# -----------------------------------------
# Tests adapted from Ruby's Rugged Library
# -----------------------------------------
