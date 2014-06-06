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
