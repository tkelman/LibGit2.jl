export message, GitNote 

type GitNote
    msg::ByteString
    id::Oid
end

let
    function git_note_message(nptr::Ptr{Void})
        msgptr = ccall((:git_note_message, api.libgit2), Ptr{Uint8}, (Ptr{Void},), nptr)
        return bytestring(msgptr)
    end

    function git_note_oid(nptr::Ptr{Void})
        idptr = ccall((:git_note_id, api.libgit2), Ptr{Uint8}, (Ptr{Void},), nptr)
        return Oid(idptr)
    end

    function GitNote(ptr::Ptr{Void})
        @assert ptr !=  C_NULL
        return GitNote(git_note_message(ptr),
                       git_note_oid(ptr))
    end
end

Oid(n::GitNote) = n.id
message(n::GitNote) = n.msg

notes(obj::GitObject, ref::Union(Nothing, String)=nothing) = lookup_note(obj, ref)

function lookup_note(obj::GitObject, ref::Union(Nothing, String)=nothing)
    oid = Oid(obj)
    note_ptr = Ptr{Void}[0]
    repo_ptr = ccall((:git_object_owner, :libgit2), Ptr{Void}, (Ptr{Void},), obj)
    err = ccall((:git_note_read, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Oid}),
                note_ptr, repo_ptr, ref != nothing ? ref : C_NULL, &oid)
    if err == api.ENOTFOUND
        return nothing
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    n = GitNote(note_ptr[1])
    #api.git_note_free(note_ptr[1])
    return n
end


