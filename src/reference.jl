type GitReference
    ptr::Ptr{Void}

    function GitReference(ptr::Ptr{Void})
        @assert ptr != C_NULL
        ref = new(ptr)
        finalizer(ref, free!)
        return ref
    end
end

free!(r::GitReference) = begin
    if r.ptr != C_NULL
        @check api.git_reference_free(r.ptr)
        r.ptr = C_NULL
    end
end

