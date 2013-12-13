const git_error_code = (Int => Symbol)[
      0 => :GIT_OK,
    -01 => :GIT_ERROR, 
    -03 => :GIT_ENOTFOUND,
    -04 => :GIT_EEXISTS,
    -05 => :GIT_EAMBIGUOUS,
    -06 => :GIT_EBUFS,
    -07 => :GIT_EUSER,
    -08 => :GIT_EBAREREPO,
    -09 => :GIT_EUNBORNBRANCH,
    -10 => :GIT_EUNMERGED,
    -11 => :GIT_ENONFASTFORWARD,
    -12 => :GIT_EINVALIDSPEC,
    -13 => :GIT_EMERGECONFLICT,
    -14 => :GIT_ELOCKED,
    -30 => :GIT_PASSTHROUGH,
    -31 => :GIT_ITEROVER
]

const git_error_class = (Int => Symbol)[
    0 => :GITERR_NONE,
    1 => :GITERR_NOMEMORY,
    2 => :GITERR_OS,
    3 => :GITERR_INVALID,
    4 => :GITERR_REFERENCE,
    5 => :GITERR_ZLIB,
    6 => :GITERR_REPOSITORY,
    7 => :GITERR_CONFIG,
    8 => :GITERR_REGEX,
    9 => :GITERR_ODB,
    10 => :GITERR_INDEX,
    11 => :GITERR_OBJECT,
    12 => :GITERR_NET,
    13 => :GITERR_TAG,
    14 => :GITERR_TREE,
    15 => :GITERR_INDEXER,
    16 => :GITERR_SSL,
    17 => :GITERR_SUBMODULE,
    18 => :GITERR_THREAD,
    19 => :GITERR_STASH,
    20 => :GITERR_CHECKOUT,
    21 => :GITERR_FETCHHEAD,
    22 => :GITERR_MERGE,
    23 => :GITERR_SSH,
    24 => :GITERR_FILTER,
    25 => :GITERR_REVERT,
]

immutable CGitError
    message::Ptr{Cchar}
    class::Cint
end

immutable GitError
    code::Symbol
    mesg::String
end

GitError(code::Integer) = begin
    err_code = git_error_code[int(code)]
    class, msg = last_error()
    GitError(err_code, msg)
end

function last_error()
    err = ccall((:giterr_last, :libgit2), 
                       Ptr{CGitError}, ())
    err_obj = unsafe_load(err)
    (err_obj.class, bytestring(err_obj.message))
end

macro check(git_func)
    quote
        local err::Cint
        err = $git_func
        if err < 0
            throw(GitError(err))
        end
        err
    end
end

macro check_null(boxed_ptr)
    local err_msg = "$boxed_ptr is NULL"
    quote
        if $boxed_ptr[1] == C_NULL
            error($err_msg)
        end
    end
end

