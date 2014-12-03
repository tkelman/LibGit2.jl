export GitCredential, PlainTextCred, SSHKeyCred, SSHAgentCred, DefaultCred

abstract GitCredential

type PlainTextCred <: GitCredential
    ptr::Ptr{Void}

    PlainTextCred(ptr::Ptr{Void}) = begin
        @assert ptr != C_NULL
        cred = new(ptr)
        return cred
    end
end

PlainTextCred(;username::MaybeString=nothing,
               password::MaybeString=nothing) = begin
    is(username, nothing) && throw(ArgumentError("username must be defined"))
    cred_ptr = Ptr{Void}[0]
    @check ccall((:git_cred_userpass_plaintext_new, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{UInt8}, Ptr{UInt8}),
                 cred_ptr, username, password != nothing ? password : C_NULL)
    return PlainTextCred(cred_ptr[1])
end

type SSHKeyCred <: GitCredential
    ptr::Ptr{Void}

    SSHKeyCred(ptr::Ptr{Void}) = begin
        @assert ptr != C_NULL
        cred = new(ptr)
        return cred
    end
end

SSHKeyCred(;username::MaybeString=nothing,
            publickey::MaybeString=nothing,
            privatekey::MaybeString=nothing,
            passphrase::MaybeString=nothing) = begin
    is(username, nothing) && throw(ArgumentError("username must be defined"))
    is(privatekey, nothing) && throw(ArgumentError("privatekey must be defined"))
    cred_ptr = Ptr{Void}[0]
    @check ccall((:git_cred_ssh_key_new, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}, Ptr{UInt8}),
                 cred,
                 username,
                 publickey != nothing ? publickey : C_NULL,
                 privatekey,
                 passphrase != nothing ? passphrase : C_NULL)
    return SSHKeyCred(cred_ptr[1])
end

type SSHAgentCred <: GitCredential
    ptr::Ptr{Void}

    SSHAgentCred(ptr::Ptr{Void}) = begin
        @assert ptr != C_NULL
    end
end

SSHAgentCred(username::AbstractString) = begin
    cred_ptr = Ptr{Void}[0]
    @check ccall((:git_cred_ssh_key_from_agent, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{UInt8}), cred_ptr, username)
    return SSHAgentCred(cred_ptr[1])
end

type DefaultCred <: GitCredential
    ptr::Ptr{Void}

    DefaultCred(ptr::Ptr{Void}) = begin
        @assert ptr != C_NULL
        cred = new(ptr)
        return cred
    end
end

DefaultCred() = begin
    cred_ptr = Ptr{Void}[0]
    @check ccall((:git_cred_default_new, libgit2), Cint, (Ptr{Ptr{Void}},), cred_ptr)
    return DefaultCred(cred_ptr[1])
end
