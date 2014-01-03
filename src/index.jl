export GitIndex, add_bypath!, write_tree!

type GitIndex
    ptr::Ptr{Void}

    function GitIndex(ptr::Ptr{Void})
        @assert ptr != C_NULL
        i = new(ptr)
        finalizer(i, free!)
        return i
    end
end

free!(i::GitIndex) = begin
    if i.ptr != C_NULL
        api.git_index_free(i.ptr)
        i.ptr = C_NULL
    end
end

function add_bypath!(i::GitIndex, path::String)
    @assert i.ptr != C_NULL
    bpath = bytestring(path)
    @check api.git_index_add_bypath(i.ptr, bpath)
    return nothing
end

function write_tree!(i::GitIndex)
    @assert i.ptr != C_NULL
    oid = Oid()
    @check api.git_index_write_tree(oid.oid, i.ptr)
    return oid
end
