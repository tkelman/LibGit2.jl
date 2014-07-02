export Signature, name, email, time, time_offset

#TODO: better date / time integration when this becomes available in Base
type Signature
    name::UTF8String
    email::UTF8String
    time::Int32
    time_offset::Int32
end

Signature(name::String, email::String, time::Integer, offset::Integer) = begin
    sig_ptr = Ptr{SignatureStruct}[0]
    @check ccall((:git_signature_new, :libgit2), Cint, 
                 (Ptr{Ptr{SignatureStruct}}, Ptr{Uint8}, Ptr{Uint8}, Cint, Cint),
                 sig_ptr, name, email, time, offset)
    sig = unsafe_load(sig_ptr[1])::SignatureStruct
    name  = utf8(bytestring(sig.name))
    email = utf8(bytestring(sig.email))
    s = Signature(name, email, time, offset)
    ccall((:git_signature_free, :libgit2), Void, (Ptr{SignatureStruct},), sig_ptr[1])
    return s
end

Signature(name::String, email::String) = begin
    sig_ptr = Ptr{SignatureStruct}[0]
    @check ccall((:git_signature_now, :libgit2), Cint,
                 (Ptr{Ptr{SignatureStruct}}, Ptr{Uint8}, Ptr{Uint8}), sig_ptr, name, email)
    sig = unsafe_load(sig_ptr[1])::SignatureStruct
    name   = utf8(bytestring(sig.name))
    email  = utf8(bytestring(sig.email)) 
    time   = sig.when.time
    offset = sig.when.offset
    s = Signature(name, email, time, offset)
    ccall((:git_signature_free, :libgit2), Void, (Ptr{SignatureStruct},), sig_ptr[1])
    return s
end

Base.show(io::IO, s::Signature) = begin
    fmt = "%Y-%m-%d %H:%M:%S %Z"
    time_str = strftime(fmt, s.time)
    print(io, "Signature(\"$(name(s))\",\"$(email(s))\",\"$time_str\")")
end

# Get signature at time...
#=
function Signature(name::String, email::String, time::Int64, offset::Int)
    bname  = bytestring(name)
    bemail = bytestring(email)
    sig_ptr = Array(Ptr{api.GitSignature}, 1)
    @check api.git_signature_new(sig_ptr, bname, bemail, time, offset)
    gsig = unsafe_load(sig_ptr[1])
    sig = Signature(bytestring(gsig.name),
                    bytestring(gsig.email),
                    gsig.time,
                    gsig.time_offset)
    api.free!(gsig)
    return sig
end

# Get signature now...
function Signature(name::String, email::String)
    bname = bytestring(name)
    bemail = bytestring(email)
    sig_ptr = Array(Ptr{api.GitSignature}, 1)
    @check api.git_signature_now(sig_ptr, bname, bemail)
    gsig = unsafe_load(sig_ptr[1])
    sig = Signature(bytestring(gsig.name),
                    bytestring(gsig.email),
                    gsig.time,
                    gsig.time_offset)
    api.free!(gsig)
    return sig
end
=#

function Signature(sig::SignatureStruct)
    return Signature(bytestring(sig.name),
                     bytestring(sig.email),
                     sig.when,
                     0)
end

#TODO: remove this
function Signature(gsig::api.GitSignature)
    return Signature(bytestring(gsig.name),
                     bytestring(gsig.email),
                     gsig.time,
                     gsig.time_offset)
end

git_signature(sig::Signature) = begin
    #name_copy  = copy(sig.name)
    #email_copy = copy(sig.email) 
    return api.GitSignature(convert(Ptr{Cchar}, pointer(sig.name)),
                            convert(Ptr{Cchar}, pointer(sig.email)),
                            sig.time, sig.time_offset)
end

Base.convert(::Type{SignatureStruct}, sig::Signature) = begin
    sig_ptr = Ptr{SignatureStruct}[0]
    @check ccall((:git_signature_new, :libgit2), Cint,
                 (Ptr{Ptr{SignatureStruct}}, Ptr{Uint8}, Ptr{Uint8}, Cint, Cint),
                 sig_ptr, sig.name, sig.email, sig.time, sig.time_offset)
    return sig_ptr[1]::Ptr{SignatureStruct}
end

name(s::Signature)  = s.name
email(s::Signature) = s.email
time(s::Signature)  = s.time
time_offset(s::Signature) = s.time_offset
