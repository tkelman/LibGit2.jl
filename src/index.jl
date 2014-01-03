export GitIndex, GitIndexEntry, add_bypath!, write_tree!

type GitIndex
    ptr::Ptr{Void}

    function GitIndex(ptr::Ptr{Void})
        @assert ptr != C_NULL
        i = new(ptr)
        finalizer(i, free!)
        return i
    end
end

function GitIndex(path::String)
    index_ptr = Array(Ptr{Void}, 1)
    @check api.git_index_open(index_ptr, bytestring(path))
    return GitIndex(index_ptr[1])
end

free!(i::GitIndex) = begin
    if i.ptr != C_NULL
        api.git_index_free(i.ptr)
        i.ptr = C_NULL
    end
end

function clear!(i::GitIndex)
    @assert i.ptr != C_NULL
    api.git_index_clear(i.ptr)
    return i
end

function reload!(i::GitIndex)
    @assert i.ptr != C_NUL
    @check api.git_index_read(i.ptr, 0)
    return i
end

function write!(i::GitIndex)
    @assert i.ptr != C_NULL
    @check api.git_index_write(i.ptr)
    return i
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

type GitIndexEntry
    path::String
    oid::Oid
    mtime::Int
    ctime::Int
    file_size::Int
    dev::Int
    ino::Int
    mode::Int
    uid::Int
    gid::Int
    stage::Int
end
