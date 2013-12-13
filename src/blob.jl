type GitBlob <: GitObject
    ptr::Ptr{Void}
end

gi_otype(::Type{GitBlob}) = api.OBJ_BLOB

function sizeof(b::Blob)
end

function is_binary(b::Blob)
end

function data(b::Blob)
end

