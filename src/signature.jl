type Signature
    name::Ptr{Cchar}
    email::Ptr{Cchar}
    time::Int64
    time_offset::Cint

    function Signature()
        s = new(C_NULL, C_NULL, 0, cint(0))
        finalizer(s, x -> free!(x))
        return s
    end
end

free!(s::Signature) = begin
    @check ccall((:git_signature_free, :libgit2), Cint,
                  (Ptr{Signature},), &s)
end

# Get signature at time...
function Signature(name::String, email::String, time::Int64, offset::Int)
    bname  = bytestring(name)
    bemail = bytestring(email)
    boxsig = [Signature()]
    err_code  = ccall((:git_signature_new, :libgit2), Cint,
                      (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}, Int64, Cint),
                      &boxsig, bname, bemail, time, cint(offset))
    if err_code < 0
        throw(GitError(err_code))
    end
    return boxsig[1]
end

# Get signature now...
function Signature(name::String, email::String)
    bname  = bytestring(name)
    bemail = bytestring(email)
    boxsig = [Signature()]
    err_code = ccall((:git_signature_now, :libgit2), Cint,
                     (Ptr{Ptr{Signature}}, Ptr{Cchar}, Ptr{Cchar}),
                     &boxsig, bname, bemail)
    if err_code < 0
        throw(GitError(err_code))
    end
    return boxsig[1]
end


