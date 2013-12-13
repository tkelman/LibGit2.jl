export Index

type Index
    ptr::Ptr{Void}
end

free!(i::Index) = begin
    if i.ptr != C_NULL
        @check api.git_index_free(i.ptr)
        i.ptr = C_NULL
    end
end

function add_bypath!(i::Index, path::String)
    bpath = bytestring(path)
    @check api.git_index_add_bypath(i.ptr, bpath)
    return nothing
end

function write_tree!(i::Index)
    oid = Oid()
    @check api.git_index_write_tree(oid.oid, i.ptr)
    return oid
end
