export message, GitNote

type GitNote
    id::Oid
    msg::UTF8String
end

GitNote(ptr::Ptr{Void}) = begin
    @assert ptr != C_NULL
    id  = Oid(ccall((:git_note_id, libgit2), Ptr{UInt8}, (Ptr{Void},), ptr))
    msg = utf8(bytestring(ccall((:git_note_message, libgit2), Ptr{UInt8}, (Ptr{Void},), ptr)))
    return GitNote(id, msg)
end

Oid(n::GitNote) = n.id

message(n::GitNote) = n.msg
notes(obj::GitObject, ref::MaybeString=nothing) = lookup_note(obj, ref)

function lookup_note(obj::GitObject, ref::MaybeString=nothing)
    oid = Oid(obj)
    note_ptr = Ptr{Void}[0]
    repo_ptr = ccall((:git_object_owner, libgit2), Ptr{Void}, (Ptr{Void},), obj)
    err = ccall((:git_note_read, libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{UInt8}, Ptr{Oid}),
                note_ptr, repo_ptr, ref != nothing ? ref : C_NULL, &oid)
    if err == GitErrorConst.ENOTFOUND
        return nothing
    elseif err != GitErrorConst.GIT_OK
        if note_ptr[1] != C_NULL
            ccall((:git_note_free, libgit2), Void, (Ptr{Void},), note_ptr[1])
        end
        throw(LibGitError(err))
    end
    n = GitNote(note_ptr[1])
    ccall((:git_note_free, libgit2), Void, (Ptr{Void},), note_ptr[1])
    return n
end
