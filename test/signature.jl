const test_name   = "test test"
const test_email  = "test@test.com"
const test_time   = 0
const test_offset = 0

# throw on bad name
@test_throws Signature("", "")

# throw error on bad time
@test_throws Signature(test_name, test_email, -1, -1)

let sig = Signature(test_name, test_email, test_time, test_offset)
    @test time(sig) = test_time
    @test time_offset(sig) = test_offset
end

let now = current_secs(), sig = Signature(test_name, test_email)
    @test time(sig) == now
end
