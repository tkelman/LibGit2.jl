macro get_oid_fieldnames(arr, obj, fieldname)
    args = {}
    for i in 1:api.OID_RAWSZ
        push!(args, :($arr[$i] = $obj.$(symbol(string(fieldname, i)))))
    end
    return Expr(:block, args...)
end

macro get_header_fieldnames(arr, obj)
    args = {}
    for i in 1:128
        push!(args, :($arr[$i] = $obj.$(symbol(string("header", i)))))
    end
    return Expr(:block, args...)
end



