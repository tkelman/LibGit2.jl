immutable GitError
    code::Int
    mesg::String
end

GitError(code::Integer) = begin
    GitError(code, "git err msg")
end

function last_error()
end

macro check(git_func)
    quote
        local err::Cint
        err = $git_func
        if err < 0
            throw(GitError(err))
        end
    end
    err
end


