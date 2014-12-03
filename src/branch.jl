export tip, resolve, owner, name, canonical_name, ishead, move,
       remote_name, remote, isremote, upstream, set_upstream!

Base.delete!(b::GitBranch) = begin
    @check ccall((:git_branch_delete, libgit2), Cint, (Ptr{Void},), b)
    return nothing
end

Base.(:(==))(b1::GitBranch, b2::GitBranch) = canonical_name(b1) == canonical_name(b2)
Base.isequal(b1::GitBranch, b2::GitBranch) = b1 == b2

tip(b::GitBranch) = lookup(owner(b), target(resolve(b)))

function owner(b::GitBranch)
    repo_ptr = ccall((:git_reference_owner, libgit2), Ptr{Void}, (Ptr{Void},), b)
    # do not free repository handle, pointer to repo is not owned by julia runtime
    return GitRepo(repo_ptr, false)
end

function resolve(b::GitBranch)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_resolve, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), ref_ptr, b)
    return GitReference(ref_ptr[1])
end

function name(b::GitBranch)
    name_ptr = Ptr{UInt8}[0]
    @check ccall((:git_branch_name, libgit2), Cint,
                 (Ptr{Ptr{UInt8}}, Ptr{Void}), name_ptr, b)
    return utf8(bytestring(name_ptr[1]))
end

ishead(b::GitBranch)  =
    bool(ccall((:git_branch_is_head, libgit2), Cint, (Ptr{Void},), b))

isremote(b::GitBranch) =
    bool(ccall((:git_reference_is_remote, libgit2), Cint, (Ptr{Void},), b))

canonical_name(b::GitBranch) =
    utf8(bytestring(ccall((:git_reference_name, libgit2), Ptr{UInt8}, (Ptr{Void},), b)))

function move(b::GitBranch, newname::AbstractString;
              force::Bool=false,
              sig::MaybeSignature=nothing,
              logmsg::MaybeString=nothing)
    branch_ptr = Ptr{Void}[0]
    if sig != nothing
        @check ccall((:git_branch_move, libgit2), Cint,
                      (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{UInt8},
                       Cint, Ptr{SignatureStruct}, Ptr{UInt8}),
                       branch_ptr, b, newname, force, sig,
                       logmsg != nothing ? logmsg : C_NULL)
    else
        @check ccall((:git_branch_move, libgit2), Cint,
                      (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{UInt8},
                       Cint, Ptr{SignatureStruct}, Ptr{UInt8}),
                       branch_ptr, b, newname, force, C_NULL,
                       logmsg != nothing ? logmsg : C_NULL)
    end
    return GitBranch(branch_ptr[1])
end

function remote_name(b::GitBranch)
    ref_ptr = Ptr{Void}[0]
    if isremote(b)
        ref_ptr[1] = b.ptr
    else
        err = ccall((:git_branch_upstream, libgit2), Cint,
                    (Ptr{Ptr{Void}}, Ptr{Void}), ref_ptr, b)
        if err == GitErrorConst.ENOTFOUND
            return nothing
        elseif err != GitErrorConst.GIT_OK
            if ref_ptr[1] != C_NULL
                ccall((:git_reference_free, libgit2), Void, (Ptr{Void},), ref_ptr[1])
            end
            throw(GitError(err))
        end
    end
    repo_ptr = ccall((:git_reference_owner, libgit2), Ptr{Void}, (Ptr{Void},), b)
    refname_ptr = ccall((:git_reference_name,  libgit2), Ptr{UInt8}, (Ptr{Void},), ref_ptr[1])
    buf_ptr = [BufferStruct()]
    err = ccall((:git_branch_remote_name, libgit2), Cint,
                (Ptr{BufferStruct}, Ptr{Void}, Ptr{UInt8}),
                buf_ptr, repo_ptr, refname_ptr)
    buf = buf_ptr[1]
    if err == GitErrorConst.GIT_OK
        str = utf8(bytestring(buf))
        ccall((:git_buf_free, libgit2), Void, (Ptr{BufferStruct},), buf_ptr)
    elseif err != GitErrorConst.GIT_OK
        if buf.ptr != C_NULL
            ccall((:git_buf_free, libgit2), Void, (Ptr{BufferStruct},), buf_ptr)
        end
        throw(GitError(err))
    end
    return str
end

function remote(b::GitBranch)
    if remote_name(b) != nothing
        return lookup_remote(owner(b), "origin")
    end
    return nothing
end

function upstream(b::GitBranch)
    isremote = ccall((:git_reference_is_remote, libgit2), Cint, (Ptr{Void},), b)
    if bool(isremote)
        return nothing
    end
    ubranch_ptr = Ptr{Void}[0]
    err = ccall((:git_branch_upstream, libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}), ubranch_ptr, b)
    if err == GitErrorConst.ENOTFOUND
        return nothing
    elseif err != GitErrorConst.GIT_OK
        throw(GitError(err))
    end
    return GitBranch(ubranch_ptr[1])
end

function set_upstream!(b::GitBranch, target::Void)
    @check ccall((:git_branch_set_upstream, libgit2), Cint,
                 (Ptr{Void}, Ptr{UInt8}), b, C_NULL)
    return b
end

function set_upstream!(b::GitBranch, target::Union(GitBranch, GitReference))
    name_ptr = Ptr{UInt8}[0]
    @check ccall((:git_branch_name, libgit2), Cint,
                 (Ptr{Ptr{UInt8}}, Ptr{Void}), name_ptr, target)
    @check ccall((:git_branch_set_upstream, libgit2), Cint,
                 (Ptr{Void}, Ptr{UInt8}), b, name_ptr[1])
    return b
end

function rename(b::GitBranch, new_name::AbstractString;
                force::Bool=false, sig::MaybeSignature=nothing, logmsg::MaybeString=nothing)
    return move(b, new_name, force=force, sig=sig, logmsg=logmsg)
end
