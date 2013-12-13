export Index

type Index
    ptr::Ptr{Void}
end


free!(i::Index) = begin
    if i.ptr != C_NULL
        #@check ccall((:git_index_free, :libgit2), Cint,
        #             (Ptr{Void},), i.ptr)
        @check api.git_index_free(i.ptr)
        i.ptr = C_NULL
    end
end

