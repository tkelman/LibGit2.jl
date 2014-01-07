export GitIndex, IndexEntry, add_bypath!, write_tree!, write!, reload!, clear!,
       remove!, remove_dir!

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

function remove!(i::GitIndex, path::String, stage::Integer=0)
    @assert i.ptr != C_NULL
    @check api.git_index_remove(i.ptr, bytestring(path), stage)
    return i
end

function remove_dir!(i::GitIndex, path::String, stage::Integer=0)
    @assert i.ptr != C_NULL
    @check api.git_index_remove_directory(i.ptr, bytestring(path), stage)
    return i
end

Base.length(i::GitIndex) = begin
    @assert i.ptr != C_NULL
    return int(api.git_index_entrycount(i.ptr))
end

Base.getindex(i::GitIndex, idx::Int) = begin
    @assert i.ptr != C_NULL
    @assert idx > 0
    entry_ptr = api.git_index_get_byindex(i.ptr, idx-1)
    if entry_ptr == C_NULL
        return nothing
    end
    return IndexEntry(entry_ptr)
end

function write_tree!(i::GitIndex)
    @assert i.ptr != C_NULL
    oid = Oid()
    @check api.git_index_write_tree(oid.oid, i.ptr)
    return oid
end

type IndexEntry
    path::String
    oid::Oid
    ctime::Float64
    mtime::Float64
    file_size::Int
    dev::Int
    ino::Int
    mode::Int
    uid::Int
    gid::Int
    valid::Bool
    stage::Int
end

function IndexEntry(ptr::Ptr{api.GitIndexEntry})
    @assert ptr != C_NULL
    gentry = unsafe_load(ptr)
    path  = bytestring(gentry.path)
    ctime = gentry.ctime_seconds + (gentry.ctime_nanoseconds / 1e3)
    mtime = gentry.mtime_seconds + (gentry.mtime_nanoseconds / 1e3)
    dev   = int(gentry.dev)
    ino   = int(gentry.ino)
    mode  = int(gentry.mode)
    uid   = int(gentry.uid)
    gid   = int(gentry.gid)
    valid = bool(gentry.flags & api.IDXENTRY_VALID)
    stage = int((gentry.flags & api.IDXENTRY_STAGEMASK) >> api.IDXENTRY_STAGESHIFT)
    file_size = int(gentry.file_size)
    
    #TODO: refactor 
    arr = Array(Uint8, api.OID_RAWSZ)
    arr[1] = gentry.oid1 
    arr[2] = gentry.oid2 
    arr[3] = gentry.oid3 
    arr[4] = gentry.oid4 
    arr[5] = gentry.oid5 
    arr[6] = gentry.oid6 
    arr[7] = gentry.oid7 
    arr[8] = gentry.oid8 
    arr[9] = gentry.oid9 
    arr[10] = gentry.oid10 
    arr[11] = gentry.oid11 
    arr[12] = gentry.oid12 
    arr[13] = gentry.oid13 
    arr[14] = gentry.oid14 
    arr[15] = gentry.oid15 
    arr[16] = gentry.oid16 
    arr[17] = gentry.oid17 
    arr[18] = gentry.oid18 
    arr[19] = gentry.oid19 
    arr[20] = gentry.oid20 
    oid = Oid(arr)

    return IndexEntry(path, oid, ctime, mtime, file_size,
                      dev, ino, mode, uid, gid, valid, stage)
end
