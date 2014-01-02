export GitDiff

type GitDiff
    ptr::Ptr{Void}
end

free!(d::GitDiff) = begin
    if d.ptr != C_NULL
        api.git_diff_free(d.ptr)
        d.ptr = C_NULL
    end
end



