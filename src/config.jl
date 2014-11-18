export GitConfig, lookup, set!, global_config

type GitConfig
    ptr::Ptr{Void}

    function GitConfig(ptr::Ptr{Void})
        @assert ptr != C_NULL
        cfg = new(ptr)
        finalizer(cfg, free!)
        return cfg
    end
end

GitConfig(path::String) = begin
    cfg_ptr = Ptr{Void}[0]
    @check ccall((:git_config_open_ondisk, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Uint8}), cfg_ptr, path)
    return GitConfig(cfg_ptr[1])
end

GitConfig(r::GitRepo) = begin
    cfg_ptr = Ptr{Void}[0]
    @check ccall((:git_repository_config, libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), cfg_ptr, r)
    return GitConfig(cfg_ptr[1])
end

free!(cfg::GitConfig) = begin
    if cfg.ptr != C_NULL
        ccall((:git_config_free, libgit2), Void, (Ptr{Void},), cfg.ptr)
        cfg.ptr == C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, cfg::GitConfig) = cfg.ptr

typealias GitConfigType Union(Bool,Int32,Int64,String)

Base.getindex(c::GitConfig, key::String) = lookup(String, c, key)
Base.setindex!{T<:GitConfigType}(c::GitConfig, v::T, key::String) = set!(T, c, key, v)

Base.delete!(c::GitConfig, key::String) = begin
    err = ccall((:git_config_delete_entry, libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), c, key)
    return err == GitErrorConst.ENOTFOUND ? false : true
end

function cb_each_key(entry_ptr::Ptr{ConfigEntryStruct}, o::Ptr{Void})
    entry = unsafe_load(entry_ptr)::ConfigEntryStruct
    n = bytestring(entry.name)
    produce(n)
    return GitErrorConst.GIT_OK
end

function cb_each_val(entry_ptr::Ptr{ConfigEntryStruct}, o::Ptr{Void})
    entry = unsafe_load(entry_ptr)
    v = bytestring(entry.value)
    produce(v)
    return GitErrorConst.GIT_OK
end

function cb_each_pair(entry_ptr::Ptr{ConfigEntryStruct}, o::Ptr{Void})
    entry = unsafe_load(entry_ptr)
    n = bytestring(entry.name)
    v = bytestring(entry.value)
    produce((n, v))
    return GitErrorConst.GIT_OK
end

const c_cb_each_key    = cfunction(cb_each_key,  Cint, (Ptr{ConfigEntryStruct}, Ptr{Void}))
const c_cb_each_val    = cfunction(cb_each_val,  Cint, (Ptr{ConfigEntryStruct}, Ptr{Void}))
const c_cb_each_kvpair = cfunction(cb_each_pair, Cint, (Ptr{ConfigEntryStruct}, Ptr{Void}))

Base.keys(c::GitConfig) = begin
    @task ccall((:git_config_foreach, libgit2), Cint,
                (Ptr{Void}, Ptr{Void}, Ptr{Void}), c, c_cb_each_key, C_NULL)
end

Base.values(c::GitConfig) = begin
    @task ccall((:git_config_foreach, libgit2), Cint,
                (Ptr{Void}, Ptr{Void}, Ptr{Void}), c, c_cb_each_val, C_NULL)
end

Base.start(c::GitConfig) = begin
    t = @task ccall((:git_config_foreach, libgit2), Cint,
                    (Ptr{Void}, Ptr{Void}, Ptr{Void}), c, c_cb_each_kvpair, C_NULL)
    (consume(t), t)
end

Base.done(c::GitConfig, state) = istaskdone(state[2])
Base.next(c::GitConfig, state) = begin
    v = consume(last(state))
    (state[1], (v, state[2]))
end

Base.Dict(c::GitConfig) = Dict{ByteString, ByteString}(c)

function global_config()
    cfg_ptr = Ptr{Void}[0]
    @check ccall((:git_config_open_default, libgit2), Cint, (Ptr{Ptr{Void}},), cfg_ptr)
    return GitConfig(cfg_ptr[1])
end

function lookup(::Type{Bool}, c::GitConfig, name::String)
    out = Cint[0]
    @check ccall((:git_config_get_bool, libgit2), Cint,
                 (Ptr{Cint}, Ptr{Void}, Ptr{Uint8}), out, c, name)
    if err == GitErrorConst.GIT_OK
        return bool(out[1])
    elseif err == GitErrorConst.ENOTFOUND
        return nothing
    else
        throw(LibGitError(err))
    end
end

function set!(::Type{Bool}, c::GitConfig, name::String, value::Bool)
    @check ccall((:git_config_set_bool, libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Cint), c, name, value)
    return c
end

function lookup(::Type{Int32}, c::GitConfig, name::String)
    out = Int32[0]
    err = ccall((:git_config_get_int32, libgit2), Cint,
                (Ptr{Int32}, Ptr{Void}, Ptr{Uint8}), out, c, name)
    if err == GitErrorConst.GIT_OK
        return out[1]
    elseif err == ENOTFOUND
        return nothing
    else
        throw(LibGitError(err))
    end
end

function set!(::Type{Int32}, c::GitConfig, name::String, value::Int32)
    @check ccall((:git_config_set_int32, libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Int32), c, name, value)
    return c
end

function lookup(::Type{Int64}, c::GitConfig, name::String)
    out = Int64[0]
    err = ccall((:git_config_get_int64, libgit2), Cint,
                (Ptr{Int64}, Ptr{Void}, Ptr{Uint8}), out, c, name)
    if err == GitErrorConst.GIT_OK
        return out[1]
    elseif err == GitErrorConst.ENOTFOUND
        return nothing
    else
        throw(GitError(err))
    end
end

function set!(::Type{Int64}, c::GitConfig, name::String, value::Int64)
    @check ccall((:git_config_set_int64, libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Int64), c, name, value)
    return c
end

function lookup{T<:String}(::Type{T}, c::GitConfig, name::String)
    out = Ptr{Uint8}[0]
    err = ccall((:git_config_get_string, libgit2), Cint,
                (Ptr{Ptr{Uint8}}, Ptr{Void}, Ptr{Uint8}), out, c, name)
    if err == GitErrorConst.GIT_OK
        return bytestring(out[1])
    elseif err == GitErrorConst.ENOTFOUND
        return nothing
    else
        throw(GitError(err))
    end
end

function set!{T<:String}(::Type{T}, c::GitConfig, name::String, value::String)
    @check ccall((:git_config_set_string, libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), c, name, value)
    return c
end
