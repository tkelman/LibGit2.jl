type GitConfig 
    ptr::Ptr{Void}

    function GitConfig(ptr::Ptr{Void})
        @assert ptr != C_NULL
        c = new(c)
        finalizer(c, free!)
        return c
    end
end

free!(c::GitConfig) = begin
    if c.ptr != C_NULL
        
        c.ptr == C_NULL
    end
end

#TODO: getindex, setindex...
typealias GitConfigType Union(Bool,Int32,Int64,String)

function lookup(::Type{Bool}, c::Config, name::String)
    #TODO:
end

function lookup(::Type{Int32}, c::Config, name::String)
    @assert c.ptr != C_NULL
    out = Int32[0]
    bname = bytestring(n)
    @check api.git_config_get_int32(out, c.ptr, bname)
    return out[1]
end

function lookup(::Type{Int64}, c::Config, name::String)
    @assert c.ptr != C_NULL
    out = Int64[0]
    bname = bytestring(name)
    @check api.git_config_get_int64(out, c.ptr, bname)
    return out[1]
end

function lookup(::Type{String}, c::Config, name::String)
    @assert c.ptr != C_NULL
    ptr = Array(Ptr{Cchar}, 1)
    bname = bytestring(name)
    @check api.git_config_get_string(ptr, c.ptr, bname)
    @check_null ptr
    return bytestring(ptr)
end

function set!(::Type{String}, c::Config, name::String, value::String)
    @assert c.ptr != C_NULL
    bname  = bytestring(name)
    bvalue = bytestring(value)
    @check api.git_config_set_string(c.ptr, bname, bvalue)
    return nothing
end
