export tip, resolve, owner, name, canonical_name, ishead, move,
       remote_name, remote, isremote, upstream, set_upstream!

Base.delete!(b::GitBranch) = begin
    @check ccall((:git_branch_delete, :libgit2), Cint, (Ptr{Void},), b)
    return nothing
end

Base.(:(==))(b1::GitBranch, b2::GitBranch) = canonical_name(b1) == canonical_name(b2)
Base.isequal(b1::GitBranch, b2::GitBranch) = b1 == b2 

#! branch iteration 
Base.start(b::GitBranch) = begin
    @assert b.ptr != C_NULL
end

Base.done(b::GitBranch, state) = begin
end

Base.next(b::GitBranch, state) = begin
end

tip(b::GitBranch) = lookup(owner(b), target(resolve(b)))

function owner(b::GitBranch)
    repo_ptr = ccall((:git_reference_owner, :libgit2), Ptr{Void}, (Ptr{Void},), b)
    #! do not free repository handle
    return GitRepo(repo_ptr, false)
end

function resolve(b::GitBranch)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_resolve, :libgit2), Cint, (Ptr{Ptr{Void}}, Ptr{Void}), ref_ptr, b)
    return GitReference(ref_ptr[1])
end

function name(b::GitBranch)
    name_ptr = Ptr{Uint8}[0]
    @check ccall((:git_branch_name, :libgit2), Cint, (Ptr{Ptr{Uint8}}, Ptr{Void}), name_ptr, b)
    return bytestring(name_ptr[1])
end

#! this is redundant with git_reference
ishead(b::GitBranch) = bool(ccall((:git_branch_is_head, :libgit2), Cint, (Ptr{Void},), b))
isremote(b::GitBranch) = bool(ccall((:git_reference_is_remote, :libgit2), Cint, (Ptr{Void},), b))
canonical_name(b::GitBranch) = bytestring(ccall((:git_reference_name, :libgit2), Ptr{Uint8}, (Ptr{Void},), b))

function move(b::GitBranch, new_name::String; force::Bool=false, sig=nothing, logmsg=nothing)
    branch_ptr = Ptr{Void}[0]
    bname = bytestring(new_name)
    bmsg  = logmsg != nothing ? bytestring(logmsg) : C_NULL
    if sig != nothing
        @assert isa(sig, Signature)
        gsig = git_signature(sig)
        @check ccall((:git_branch_move, api.libgit2), Cint,
                      (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Cint,
                       Ptr{api.GitSignature}, Ptr{Uint8}),
                       branch_ptr, b, bname, force? 1:0, &gsig, bmsg)
    else
        @check ccall((:git_branch_move, api.libgit2), Cint,
                      (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Cint,
                       Ptr{api.GitSignature}, Ptr{Uint8}),
                       branch_ptr, b, bname, force? 1:0, C_NULL, bmsg)
    end
    return GitBranch(branch_ptr[1])
end

function remote_name(b::GitBranch)
    return_ref = nothing
    ref_ptr = Ptr{Void}[0]
    if isremote(b)
        ref_ptr[1] = b.ptr 
    else
        err = ccall((:git_branch_upstream, :libgit2), Cint, (Ptr{Ptr{Void}}, Ptr{Void}), ref_ptr, b)
        if err == api.ENOTFOUND
            return nothing
        elseif err != api.GIT_OK
            #! free ref ptr??
            throw(GitError(err))
        end
    end
    refname = bytestring(ccall((:git_reference_name, :libgit2), Ptr{Uint8}, (Ptr{Void},), ref_ptr[1]))
    repo_ptr = ccall((:git_reference_owner, :libgit2), Ptr{Void}, (Ptr{Void},), b)
    buf = api.GitBuffer()
    err = ccall((:git_branch_remote_name, api.libgit2), Cint,
                (Ptr{api.GitBuffer}, Ptr{Void}, Ptr{Uint8}),
                &buf, repo_ptr, refname)
    if err == api.GIT_OK
        return bytestring(buf.ptr)
    elseif err != api.GIT_OK
        throw(GitError(err))
    end
end

function remote(b::GitBranch)
    rname = remote_name(b)
    if rname != nothing
        return lookup_remote(owner(b), "origin")
    end
end

function upstream(b::GitBranch) 
    isremote = ccall((:git_reference_is_remote, :libgit2), Cint, (Ptr{Void},), b)
    if bool(isremote)
        return nothing
    end
    ubranch_ptr = Ptr{Void}[0]
    err = ccall((:git_branch_upstream, :libgit2), Cint, (Ptr{Ptr{Void}}, Ptr{Void}), ubranch_ptr, b)
    if err == api.ENOTFOUND
        return nothing
    elseif err != api.GIT_OK
        throw(GitError(err))
    end
    return GitBranch(ubranch_ptr[1])
end

function set_upstream!(b::GitBranch, target::Nothing)
    @check ccall((:git_branch_set_upstream, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), b, C_NULL)
    return b
end

function set_upstream!(b::GitBranch, target::Union(GitBranch, GitReference))
    name_ptr = Ptr{Uint8}[0]
    @check ccall((:git_branch_name, :libgit2), Cint, (Ptr{Ptr{Uint8}}, Ptr{Void}), name_ptr, target)
    @check ccall((:git_branch_set_upstream, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), b, name_ptr[1])
    return b
end 

function set_upstream(b::GitBranch, ustream::GitReference)
    @assert b.ptr != C_NULL && ustream.ptr != C_NULL
    @check api.git_branch_set_upstream(b.ptr, C_NULL)
end

function rename(b::GitBranch, new_name::String; 
                force::Bool=false, sig=nothing, logmsg=nothing)
    return move(b, new_name, force=force, sig=sig, logmsg=logmsg)
end 
