export LibGitError

const git_error_code = (Int => Symbol)[
     00 => :OK,
    -01 => :Error, 
    -03 => :NotFound,
    -04 => :Exists,
    -05 => :Ambiguous,
    -06 => :Bufs,
    -07 => :User,
    -08 => :BareRepo,
    -09 => :UnbornBranch,
    -10 => :Unmerged,
    -11 => :NonFastForward,
    -12 => :InvalidSpec,
    -13 => :MergeConflict,
    -14 => :Locked,
    -30 => :PassThrough,
    -31 => :Iterover
]

const git_error_class = (Int => Symbol)[
    0 => :None,
    1 => :NoMemory,
    2 => :OS,
    3 => :Invalid,
    4 => :Ref,
    5 => :Zlib,
    6 => :Repo,
    7 => :Config,
    8 => :Regex,
    9 => :Odb,
    10 => :Index,
    11 => :Object,
    12 => :Net,
    13 => :Tag,
    14 => :Tree,
    15 => :Index,
    16 => :SSL,
    17 => :Submodule,
    18 => :Thread,
    19 => :Stash,
    20 => :Checkout,
    21 => :FetchHead,
    22 => :Merge,
    23 => :SSH,
    24 => :Filter,
    25 => :Revert,
]

immutable ErrorStruct
    message::Ptr{Cchar}
    class::Cint
end

immutable LibGitError{Class, Code} 
    msg::UTF8String
end

function last_error()
    err = ccall((:giterr_last, api.libgit2), Ptr{ErrorStruct}, ())
    err_obj   = unsafe_load(err)
    err_class = git_error_class[int(err_obj.class)] 
    err_msg   = bytestring(err_obj.message)
    return (err_class, err_msg)
end

LibGitError(code::Integer) = begin
    err_code = git_error_code[int(code)]
    err_class, err_msg = last_error()
    LibGitError{err_class, err_code}(err_msg)
end

macro check(git_func)
    quote
        local err::Cint
        err = $(esc(git_func))
        if err < 0
            throw(LibGitError(err))
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

