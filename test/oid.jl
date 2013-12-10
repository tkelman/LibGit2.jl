using Base.Test
using LibGit2

# Test constructor
HEX1 = "15b648aec6ed045b5ca6f57f8b7831a8b4757298"
HEX2 = "15b648aec6ed045b5ca6f57f8b7831a8b4757299"
oid1 = Oid(HEX1)

# Test equality
oid2 = Oid(HEX1)
@test oid1 == oid2
oid2 = Oid(HEX2)
@test oid1 != oid2

# Test comparisons
@test is(oid1 < oid2, true)
@test is(oid1 <= oid2, true)
@test is(oid1 == oid2, false)
@test is(oid1 > oid2, false)
@test is(oid1 >= oid2, false)

# Test hash
oid1 = Oid(HEX1)
oid2 = Oid(HEX1)
s = Set(oid1, oid2)
@test length(s) == 1

push!(s, Oid("0000000000000000000000000000000000000000"))
push!(s, Oid("0000000000000000000000000000000000000001"))
@test length(s) == 3

@show oid1
