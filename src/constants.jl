cint(i)  = convert(Cint, i)
cuint(i) = convert(Cuint, i)

module GitConst
    import ..cint
    import ..cuint

    const OBJ_ANY    = cint(-2)
    const OBJ_BAD    = cint(-1)
    const OBJ_COMMIT = cint(1)
    const OBJ_TREE   = cint(2)
    const OBJ_BLOB   = cint(3)
    const OBJ_TAG    = cint(4)

    const SORT_NONE = cint(0)
    const SORT_TOPOLOGICAL = cint(1) << cint(0)
    const SORT_TIME = cint(1) << cint(1)
    const SORT_REVERSE = cint(1) << cint(2)

    const REF_INVALID = cint(0)
    const REF_OID = cint(1)
    const REF_SYMBOLIC = cint(2)
    const REF_LISTALL = REF_OID | REF_SYMBOLIC

    const BRANCH_LOCAL = cint(1)
    const BRANCH_REMOTE = cint(2)

    const FILEMODE_NEW             = cint(00000)
    const FILEMODE_TREE            = cint(16384)
    const FILEMODE_BLOB            = cint(33188)
    const FILEMODE_BLOB_EXECUTABLE = cint(33261)
    const FILEMODE_LINK            = cint(40960)
    const FILEMODE_COMMIT          = cint(57344)

    const CHECKOUT_NONE                    = cint(0)
    const CHECKOUT_SAFE                    = cuint(1) << cint(0)
    const CHECKOUT_SAFE_CREATE             = cuint(1) << cint(1)
    const CHECKOUT_FORCE                   = cuint(1) << cint(2)
    const CHECKOUT_ALLOW_CONFLICTS         = cuint(1) << cint(4)
    const CHECKOUT_REMOVE_UNTRACKED        = cuint(1) << cint(5)
    const CHECKOUT_REMOVE_IGNORED          = cuint(1) << cint(6)
    const CHECKOUT_UPDATE_ONLY             = cuint(1) << cint(7)
    const CHECKOUT_DONT_UPDATE_INDEX       = cuint(1) << cint(8)
    const CHECKOUT_NO_REFRESH              = cuint(1) << cint(9)
    const CHECKOUT_SKIP_UNMERGED           = cuint(1) << cint(10)
    const CHECKOUT_USE_OURS                = cuint(1) << cint(11)
    const CHECKOUT_USE_THEIRS              = cuint(1) << cint(12)
    const CHECKOUT_DISABLE_PATHSPEC_MATCH  = cuint(1) << cint(13)
    const CHECKOUT_SKIP_LOCKED_DIRECTORIES = cuint(1) << cint(18)
    const CHECKOUT_DONT_OVERWRITE_IGNORED  = cuint(1) << cint(19)

    const CHECKOUT_UPDATE_SUBMODULES       = cuint(1) << cint(16)
    const CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED = cuint(1) << cint(17)

    const CHECKOUT_NOTIFY_NONE      = cint(0)
    const CHECKOUT_NOTIFY_CONFLICT  = cuint(1) << cint(0)
    const CHECKOUT_NOTIFY_DIRTY     = cuint(1) << cint(1)
    const CHECKOUT_NOTIFY_UPDATED   = cuint(1) << cint(2)
    const CHECKOUT_NOTIFY_UNTRACKED = cuint(1) << cint(3)
    const CHECKOUT_NOTIFY_IGNORED   = cuint(1) << cint(4)
    const CHECKOUT_NOTIFY_ALL       = 0x0FFFF

    const SUBMODULE_UPDATE_RESET    = cint(-1)
    const SUBMODULE_UPDATE_CHECKOUT = cint(1)
    const SUBMODULE_UPDATE_REBASE   = cint(2)
    const SUBMODULE_UPDATE_MERGE    = cint(3)
    const SUBMODULE_UPDATE_NONE     = cint(4)
    const SUBMODULE_UPDATE_DEFAULT  = cint(0)

    # git_submodule_ignore_t
    const SUBMODULE_IGNORE_RESET     = cint(-1)
    const SUBMODULE_IGNORE_NONE      = cint(1)
    const SUBMODULE_IGNORE_UNTRACKED = cint(2)
    const SUBMODULE_IGNORE_DIRTY     = cint(3)
    const SUBMODULE_IGNORE_ALL       = cint(4)
    const SUBMODULE_IGNORE_DEFAULT   = cint(0)

    const TREEWALK_PRE  = cint(0)
    const TREEWALK_POST = cint(1)

    const GIT_PATH_MAX = cint(4096)

    const DIFF_OPTIONS_VERSION = cint(1)

    const DIFF_NORMAL  = cint(0)
    const DIFF_REVERSE = cuint(1) << cint(0)
    const DIFF_INCLUDE_IGNORED = cuint(1) << cint(1)
    const DIFF_RECURSE_IGNORED_DIRS = cuint(1) << cint(2)
    const DIFF_INCLUDE_UNTRACKED = cuint(1) << cint(3)
    const DIFF_RECURSE_UNTRACKED_DIRS = cuint(1) << cint(4)
    const DIFF_INCLUDE_UNMODIFIED = cuint(1) << cint(5)
    const DIFF_INCLUDE_TYPECHANGE = cuint(1) << cint(6)
    const DIFF_INCLUDE_TYPECHANGE_TREES = cuint(1) << cint(7)
    const DIFF_IGNORE_FILEMODE = cuint(1) << cint(8)
    const DIFF_IGNORE_SUBMODULES = cuint(1) << cint(9)
    const DIFF_IGNORE_CASE = cuint(1) << cint(10)
    const DIFF_DISABLE_PATHSPEC_MATCH = cuint(1) << cint(12)
    const DIFF_SKIP_BINARY_CHECK = cuint(1) << cint(13)
    const DIFF_ENABLE_FAST_UNTRACKED_DIRS = cuint(1) << cint(14)

    const DIFF_FORCE_TEXT = cuint(1) << cint(20)
    const DIFF_FORCE_BINARY = cuint(1) << cint(21)
    const DIFF_IGNORE_WHITESPACE = cuint(1) << cint(22)
    const DIFF_IGNORE_WHITESPACE_CHANGE = cuint(1) << cint(23)
    const DIFF_IGNORE_WHITESPACE_EOL = cuint(1) << cint(24)
    const DIFF_SHOW_UNTRACKED_CONTENT = cuint(1) << cint(25)
    const DIFF_SHOW_UNMODIFIED = cuint(1) << cint(26)
    const DIFF_PATIENCE = cuint(1) << cint(28)
    const DIFF_MINIMAL = cuint(1) << cint(29)

    const DIFF_FLAG_BINARY     = cuint(1) << cint(0)
    const DIFF_FLAG_NOT_BINARY = cuint(1) << cint(1)
    const DIFF_FLAG_VALID_OID  = cuint(1) << cint(2)

    const DIFF_FORMAT_PATCH = cuint(1)
    const DIFF_FORMAT_PATCH_HEADER = cuint(2)
    const DIFF_FORMAT_RAW = cuint(3)
    const DIFF_FORMAT_NAME_ONLY = cuint(4)
    const DIFF_FORMAT_NAME_STATUS = cuint(5)

    const DELTA_UNMODIFIED = cint(0)
    const DELTA_ADDED      = cint(1)
    const DELTA_DELETED    = cint(2)
    const DELTA_MODIFIED   = cint(3)
    const DELTA_RENAMED    = cint(4)
    const DELTA_COPIED     = cint(5)
    const DELTA_IGNORED    = cint(6)
    const DELTA_UNTRACKED  = cint(7)
    const DELTA_TYPECHANGE = cint(8)

    cchar(c::Char) = convert(Cchar, c)

    const DIFF_LINE_CONTEXT   = cchar(' ')
    const DIFF_LINE_ADDITION  = cchar('+')
    const DIFF_LINE_DELETION  = cchar('-')

    const DIFF_LINE_CONTEXT_EOFNL = cchar('=')
    const DIFF_LINE_ADD_EOFNL = cchar('>')
    const DIFF_LINE_DEL_EOFNL = cchar('<')

    const DIFF_LINE_FILE_HDR  = cchar('F')
    const DIFF_LINE_HUNK_HDR  = cchar('H')
    const DIFF_LINE_BINARY    = cchar('B')

    # index
    const IDXENTRY_NAMEMASK   = (0x0fff)
    const IDXENTRY_STAGEMASK  = (0x3000)
    const IDXENTRY_EXTENDED   = (0x4000)
    const IDXENTRY_VALID      = (0x8000)
    const IDXENTRY_STAGESHIFT = cint(12)

    const IDXENTRY_UPDATE            = cint(1) << cint(0)
    const IDXENTRY_REMOVE            = cint(1) << cint(1)
    const IDXENTRY_UPTODATE          = cint(1) << cint(2)
    const IDXENTRY_ADDED             = cint(1) << cint(3)

    const IDXENTRY_HASHED            = cint(1) << cint(4)
    const IDXENTRY_UNHASHED          = cint(1) << cint(5)
    const IDXENTRY_WT_REMOVE         = cint(1) << cint(6)
    const IDXENTRY_CONFLICTED        = cint(1) << cint(7)

    const IDXENTRY_UNPACKED          = cint(1) << cint(8)
    const IDXENTRY_NEW_SKIP_WORKTREE = cint(1) << cint(9)

    const INDEXCAP_IGNORE_CASE = cuint(1)
    const INDEXCAP_NO_FILEMODE = cuint(2)
    const INDEXCAP_NO_SYMLINKS = cuint(4)
    const INDEXCAP_FROM_OWNER  = ~(cuint(0))

    const INDEX_ADD_DEFAULT = cint(0)
    const INDEX_ADD_FORCE   = cuint(1) << cint(0)
    const INDEX_ADD_DISABLE_PATHSPEC_MATCH = cuint(1) << cint(1)
    const INDEX_ADD_CHECK_PATHSPEC = cuint(1) << cint(2)

    const INDEX_STAGE_ANY = cint(-1)

    const MERGE_TREE_FIND_RENAMES = cint(1) << cint(0)

    const MERGE_AUTOMERGE_NORMAL  = cint(0)
    const MERGE_AUTOMERGE_FAVOR_OURS = cint(1)
    const MERGE_AUTOMERGE_FAVOR_THEIRS = cint(2)
    const MERGE_AUTOMERGE_FAVOR_UNION  = cint(3)

    const MERGE_NO_FASTFORWARD = cint(1)
    const MERGE_FASTFORWARD_ONLY = cint(2)

    const GIT_MERGE_ANALYSIS_NONE = 0,
	const GIT_MERGE_ANALYSIS_NORMAL = (1 << 0)
	const GIT_MERGE_ANALYSIS_UP_TO_DATE = (1 << 1)
	const GIT_MERGE_ANALYSIS_FASTFORWARD = (1 << 2)
	const GIT_MERGE_ANALYSIS_UNBORN = (1 << 3)

    const GIT_MERGE_PREFERENCE_NONE = 0
	const GIT_MERGE_PREFERENCE_NO_FASTFORWARD = (1 << 0)
	const GIT_MERGE_PREFERENCE_FASTFORWARD_ONLY = (1 << 1)

    const DIRECTION_FETCH = cint(0)
    const DIRECTION_PUSH  = cint(1)

    const BLAME_NORMAL = cint(0)

    const CREDTYPE_USERPASS_PLAINTEXT = cuint(1) << cint(0)
    const CREDTYPE_SSH_KEY = cuint(1) << cint(1)
    const CREDTYPE_SSH_CUSTOM = cuint(1) << cint(2)
    const CREDTYPE_DEFAULT = cuint(1) << cint(3)

	const GIT_REPOSITORY_STATE_NONE = cint(0)
	const GIT_REPOSITORY_STATE_MERGE = cint(1)
	const GIT_REPOSITORY_STATE_REVERT = cint(2)
	const GIT_REPOSITORY_STATE_CHERRY_PICK = cint(3)
	const GIT_REPOSITORY_STATE_BISECT = cint(4)
	const GIT_REPOSITORY_STATE_REBASE = cint(5)
	const GIT_REPOSITORY_STATE_REBASE_INTERACTIVE = cint(6)
	const GIT_REPOSITORY_STATE_REBASE_MERGE = cint(7)
	const GIT_REPOSITORY_STATE_APPLY_MAILBOX = cint(8)
	const GIT_REPOSITORY_STATE_APPLY_MAILBOX_OR_REBASE = cint(9)
end
