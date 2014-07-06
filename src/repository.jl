export isbare, isempty, workdir, path,
       repo_open, repo_init, head, set_head!, tags, tag!, commits, references,
       repo_lookup, lookup_tree, lookup_commit, commit, ref_names,
       repo_revparse_single, create_ref, create_sym_ref, lookup_ref,
       repo_odb, iter_refs, config,  GitTreeBuilder,
       insert!, write!, close, lookup, rev_parse, rev_parse_oid, remotes,
       ahead_behind, merge_base, merge_commits,  blob_at, isshallow, hash_data,
       default_signature, repo_discover, isbare, isempty, namespace, set_namespace!,
       notes, create_note!, remove_note!, each_note, note_default_ref, iter_notes,
       blob_from_buffer, blob_from_workdir, blob_from_disk, blob_from_stream,
       branch_names, lookup_branch, create_branch, lookup_remote, iter_branches,
       remote_names, remote_add!, checkout_tree!, checkout_head!, checkout!, 
       is_head_detached, GitCredential, CredDefault, CredPlainText, CredSSHKey, 
       repo_clone

typealias MaybeOid Union(Nothing, Oid)
typealias MaybeString Union(Nothing, String)
typealias MaybeSignature Union(Nothing, Signature)

GitRepo(path::String; alternates={}) = begin
    repo_ptr = Ptr{Void}[0]
    err = ccall((:git_repository_open, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Uint8}), repo_ptr, path)
    if err != GitErrorConst.GIT_OK
        if repo_ptr[1] != C_NULL
            ccall((:git_repository_free, :libgit2), Void, (Ptr{Void},), repo_ptr[1])
        end
        throw(LibGitError(err))
    end
    repo = GitRepo(repo_ptr[1])
    if !isempty(alternates)
        odb = Odb(repo)
        for pth in alternates
            if !isdir(pth)
                throw(ArgumentError("alternate $path is not a valid directory"))
            end
            @check ccall((:git_odb_add_disk_alternate, :libgit2), Cint,
                         (Ptr{Void}, Ptr{Uint8}), odb, pth)
        end
    end
    return repo
end

Base.close(r::GitRepo) = begin
    if r.ptr != C_NULL
        ccall((:git_repository__cleanup, :libgit2), Void, (Ptr{Void},), r.ptr)
    end
end

Base.in(id::Oid, r::GitRepo) = exists(Odb(r), id)::Bool

function cb_iter_oids(idptr::Ptr{Uint8}, o::Ptr{Void})
    try
        produce(Oid(idptr))
        return GitErrorConst.GIT_OK
    catch err
        return GitErrorConst.ERROR
    end
end

const c_cb_iter_oids = cfunction(cb_iter_oids, Cint, (Ptr{Uint8}, Ptr{Void}))

#TODO: better error handling
Base.start(r::GitRepo) = begin
    odb = Odb(r)
    t = @task ccall((:git_odb_foreach, :libgit2), Cint,
                    (Ptr{Void}, Ptr{Void}, Ptr{Cint}), odb, c_cb_iter_oids, C_NULL)
    return (consume(t), t)
end

Base.done(r::GitRepo, state) = istaskdone(state[2])

Base.next(r::GitRepo, state) = begin
    v = consume(state[2])
    return (state[1], (v, state[2]))
end

Base.read(r::GitRepo, id::Oid) = begin
    odb = Odb(r)
    obj_ptr = Ptr{Void}[0]
    @check ccall((:git_odb_read, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}), obj_ptr, odb, &id)
    return OdbObject(obj_ptr[1])
end

Base.delete!(r::GitRepo, ref::GitReference) = begin
    @check ccall((:git_reference_delete, :libgit2), Cint, (Ptr{Void}, Ptr{Void}), r, ref)
    return r
end

Base.delete!(r::GitRepo, t::GitTag) = begin
    @check ccall((:git_tag_delete, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), r, name(t))
    return r
end

Base.getindex(r::GitRepo, o) = lookup(r, o)

read_header(r::GitRepo, id::Oid) = read_header(Odb(r), id)

exists(r::GitRepo, ref::String) = begin
    ref_ptr = Ptr{Void}[0]
    err = ccall((:git_reference_lookup, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), ref_ptr, r, ref)
    ccall((:git_reference_free, :libgit2), Void, (Ptr{Void},), ref_ptr[1])
    if err == GitErrorConst.ENOTFOUND
        return false
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return true
end
exists(r::GitRepo, id::Oid) = id in r 

function isbare(r::GitRepo)
    return bool(ccall((:git_repository_is_bare, :libgit2), Cint, (Ptr{Void},), r))
end

Base.isempty(r::GitRepo) = begin
    return bool(ccall((:git_repository_is_empty, :libgit2), Cint, (Ptr{Void},), r))
end

function isshallow(r::GitRepo)
    return bool(ccall((:git_repository_is_shallow, :libgit2), Cint, (Ptr{Void},), r))
end

function workdir(r::GitRepo)
    dir = ccall((:git_repository_workdir, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    dir == C_NULL && return nothing
    # remove trailing slash
    return bytestring(dir)[1:end-1]
end

function path(r::GitRepo)
    cpath = ccall((:git_repository_path, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    cpath == C_NULL && return nothing
    # remove trailing slash
    return bytestring(cpath)[1:end-1]
end

function hash_data{T<:GitObject}(::Type{T}, content::String)
    id_ptr = [Oid()]
    @check ccall((:git_odb_hash, :libgit2), Cint,
                 (Ptr{Oid}, Ptr{Uint8}, Csize_t, Cint),
                 id_ptr, content, length(content), git_otype(T))
    return id_ptr[1]
end

function default_signature(r::GitRepo)
    sig_ptr = Ptr{SignatureStruct}[0]
    @check ccall((:git_signature_default, :libgit2), Cint,
                 (Ptr{Ptr{SignatureStruct}}, Ptr{Void}), sig_ptr, r)
    sig = Signature(sig_ptr[1])
    ccall((:git_signature_free, :libgit2), Void, (Ptr{SignatureStruct},), sig_ptr[1])
    return sig
end

function is_head_detached(r::GitRepo)
    return bool(ccall((:git_repository_head_detached, :libgit2), Cint, (Ptr{Void},), r))
end

function repo_init(path::String; bare::Bool=false)
    repo_ptr = Ptr{Void}[0]
    err = ccall((:git_repository_init, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Uint8}, Cint), repo_ptr, path, bare? 1 : 0)
    if err != GitErrorConst.GIT_OK
        if repo_ptr[1] != C_NULL
            ccall((:git_repository_free, :libgit2), Void, (Ptr{Void},), repo_ptr[1])
        end
        throw(LibGitError(err))
    end
    return GitRepo(repo_ptr[1])
end

function set_namespace!(r::GitRepo, ns)
    if ns == nothing || isempty(ns)
        @check ccall((:git_repository_set_namespace, :libgit2), Cint,
                     (Ptr{Void}, Ptr{Uint8}), r, C_NULL)
    else
        @check ccall((:git_repository_set_namespace, :libgit2), Cint,
                     (Ptr{Void}, Ptr{Uint8}), r, ns)
    end
    return r
end

function namespace(r::GitRepo)
    ns_ptr = ccall((:git_repository_get_namespace, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    ns_ptr == C_NULL && return nothing
    return bytestring(ns_ptr)
end

function head(r::GitRepo)
    head_ptr = Ptr{Void}[0]
    err = ccall((:git_repository_head, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}), head_ptr, r)
    if err == GitErrorConst.ENOTFOUND || err == GitErrorConst.EUNBORNBRANCH
        return nothing
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end 
    return GitReference(head_ptr[1])
end

Oid(r::GitRepo, val::GitObject) = Oid(val)
Oid(r::GitRepo, val::Oid) = val

function Oid(r::GitRepo, val::String)
    if length(val) == OID_HEXSZ
        try
            return Oid(val)
        end
    end
    return Oid(rev_parse(r, val))
end

function set_head!(r::GitRepo, ref::String; 
                   sig::MaybeSignature=nothing, 
                   logmsg::MaybeString=nothing)
    @check ccall((:git_repository_set_head, :libgit2), Cint,
                 (Ptr{Void}, Ptr{Uint8}, Ptr{SignatureStruct}, Ptr{Uint8}),
                 r, ref, sig != nothing ? sig : C_NULL, logmsg != nothing ? logmsg : C_NULL)
    return r
end

#TODO: this needs to be implemented
function commits(r::GitRepo)
    return nothing 
end

function remotes(r::GitRepo)
    sa_ptr = [StrArrayStruct()]
    @check ccall((:git_remote_list, :libgit2), Cint,
                 (Ptr{StrArrayStruct}, Ptr{Void}), sa_ptr, r)
    sa = sa_ptr[1]
    sa.count == 0 && return nothing 
    remote_ptr = Ptr{Void}[0]
    out = Array(GitRemote, sa.count)
    for i in 1:sa.count 
        rstr_ptr = unsafe_load(sa.strings, i)
        @check ccall((:git_remote_load, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), remote_ptr, r, rstr_ptr)
        out[i] = GitRemote(remote_ptr[1])
    end
    return out
end

function remote_names(r::GitRepo)
    sa_ptr = [StrArrayStruct()]
    @check ccall((:git_remote_list, :libgit2), Cint,
                  (Ptr{StrArrayStruct}, Ptr{Void}), sa_ptr, r)
    sa = sa_ptr[1]
    ns = Array(UTF8String, sa.count)
    for i in 1:sa.count
        ns[i] = utf8(bytestring(unsafe_load(sa.strings, i)))
    end
    return ns
end

function remote_add!(r::GitRepo, name::String, url::String)
    check_valid_url(url)
    remote_ptr = Ptr{Void}[0]
    @check ccall((:git_remote_create, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8}), remote_ptr, r, name, url)
    return GitRemote(remote_ptr[1])
end

function cb_push_status(ref_ptr::Ptr{Uint8}, msg_ptr::Ptr{Uint8}, payload::Ptr{Void})
    if msg_ptr != C_NULL 
        result = unsafe_pointer_to_objref(payload)::Dict{UTF8String,UTF8String}
        result[utf8(bytestring(ref_ptr))] = utf8(bytestring(msg_ptr))
    end
    return GitErrorConst.GIT_OK
end

const c_cb_push_status = cfunction(cb_push_status, Cint,
                                   (Ptr{Uint8}, Ptr{Uint8}, Ptr{Void}))

#TODO: git push update tips takes a signature and message
#TODO: better error messages
Base.push!{T<:String}(r::GitRepo, remote::GitRemote, refs::Vector{T}) = begin
    push_ptr = Ptr{Void}[0]
    err = ccall((:git_push_new, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}), push_ptr, remote)
    p = push_ptr[1]
    if err != GitErrorConst.GIT_OK
        if p != C_NULL
            ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        end
        throw(LibGitError(err))
    end
    @assert p != C_NULL
    for ref in refs
        err = ccall((:git_push_add_refspec, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), p, ref)
    end
    if err != GitErrorConst.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        throw(LibGitError(err))
    end
    err = ccall((:git_push_finish, :libgit2), Cint, (Ptr{Void},), p)
    if err != GitErrorConst.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        if err == GitErrorConst.ENONFASTFORWARD
            error("non-fast-forward upate rejected")
        #TODO: error constant
        elseif err == -8
            error("could not push to repo (check for non-bare repo)")
        end
    end
    err = ccall((:git_push_unpack_ok, :libgit2), Cint, (Ptr{Void},), p)
    if err == GitErrorConst.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        error("remote side did not unpack successfully")
    end
    result = Dict{UTF8String, UTF8String}()
    err = ccall((:git_push_status_foreach, :libgit2), Cint,
                (Ptr{Void}, Ptr{Void}, Any), p, c_cb_push_status, &result)
    if err != GitErrorConst.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        throw(LibGitError(err))
    end
    err = ccall((:git_push_update_tips, :libgit2), Cint,
                (Ptr{Void}, Ptr{SignatureStruct}, Ptr{Uint8}), p, C_NULL, C_NULL)
    if err != GitErrorConst.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        throw(LibGitError(err))
    end
    return result
end

Base.push!{T<:String}(r::GitRepo, remote::String, refs::Vector{T}) = begin
    remote_ptr = Ptr{Void}[0]
    @check ccall((:git_remote_load, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), remote_ptr, r, remote)
    return push!(r, GitRemote(remote_ptr[1]), refs)
end

function lookup(::Type{GitRemote}, r::GitRepo, remote_name::String)
    remote_ptr = Ptr{Void}[0]
    err = ccall((:git_remote_load, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), remote_ptr, r, remote_name)
    if err == GitErrorConst.ENOTFOUND
        return nothing
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return GitRemote(remote_ptr[1])
end

lookup_remote(r::GitRepo, remote_name::String) = lookup(GitRemote, r, remote_name)
lookup_tag(r::GitRepo, id::Oid) = lookup(GitTag, r, id)

function tags(r::GitRepo, glob::String="")
    sa_ptr = [StrArrayStruct()]
    @check ccall((:git_tag_list_match, :libgit2), Cint,
                 (Ptr{StrArrayStruct}, Ptr{Uint8}, Ptr{Void}), sa_ptr, glob, r)
    sa = sa_ptr[1]
    sa.count == 0 && return nothing
    out = Array(UTF8String, sa.count)
    for i in 1:sa.count
        out[i] = utf8(bytestring(unsafe_load(sa.strings, i)))
    end
    return out
end

function tag!(r::GitRepo;
              name::String="",
              message::String="",
              target::MaybeOid=nothing,
              tagger::MaybeSignature=nothing,
              force::Bool=false)
   id_ptr = [Oid()]
   target != nothing && (obj = lookup(r, target))
   if !isempty(message)
       sig = tagger != nothing ? tagger : default_signature(r)
       @check ccall((:git_tag_create, :libgit2), Cint,
                    (Ptr{Oid}, Ptr{Void}, Ptr{Uint8},
                     Ptr{Void}, Ptr{SignatureStruct}, Ptr{Uint8}, Cint),
                    id_ptr, r, name, obj, sig, message, force? 1:0)
   else
       @check ccall((:git_tag_create_lightweight, :libgit2), Cint,
                    (Ptr{Oid}, Ptr{Void}, Ptr{Uint8}, Ptr{Void}, Cint),
                    id_ptr, r, name, obj, force? 1:0)
   end
   return id_ptr[1]
end

function create_note!(
               obj::GitObject, msg::String; 
               committer::MaybeSignature=nothing,
               author::MaybeSignature=nothing,
               ref::MaybeString=nothing,
               force::Bool=false)
    repo_ptr  = ccall((:git_object_owner, :libgit2), Ptr{Void}, (Ptr{Void},), obj)
    bref = ref != nothing ? bytestring(ref) : convert(Ptr{Uint8}, C_NULL)
    #TODO: we can avoid having to lookup the default signature twice
    local committer_ptr::Ptr{SignatureStruct}
    if committer != nothing
        committer_ptr = convert(Ptr{SignatureStruct}, committer)
    else
        sig_ptr = Ptr{SignatureStruct}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{SignatureStruct}}, Ptr{Void}), sig_ptr, repo_ptr)
        committer_ptr = sig_ptr[1]
 
    end
    local author_ptr::Ptr{SignatureStruct}
    if author != nothing
        author_ptr = convert(Ptr{SignatureStruct}, author)
    else
        sig_ptr = Ptr{SignatureStruct}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{SignatureStruct}}, Ptr{Void}), sig_ptr, repo_ptr)
        author_ptr = sig_ptr[1]
    end
    tid = Oid(obj)
    nid_ptr = [Oid()]
    @check ccall((:git_note_create, :libgit2), Cint,
                 (Ptr{Oid}, Ptr{Void}, Ptr{SignatureStruct},
                  Ptr{SignatureStruct}, Ptr{Uint8}, Ptr{Oid}, Ptr{Uint8}, Cint),
                  nid_ptr, repo_ptr, committer_ptr, author_ptr, bref, &tid, msg, force? 1:0)
    return nid_ptr[1]
end

function remove_note!(obj::GitObject;
                      committer::MaybeSignature=nothing,
                      author::MaybeSignature=nothing,
                      ref::MaybeString=nothing)
    repo_ptr  = ccall((:git_object_owner, :libgit2), Ptr{Void}, (Ptr{Void},), obj)
    notes_ref = ref != nothing ? bytestring(ref) :
                                 bytestring("refs/notes/commits")
    local committer_ptr::Ptr{SignatureStruct}
    if committer != nothing
        committer_ptr = convert(Ptr{SignatureStruct}, committer)
    else
        sig_ptr = Ptr{SignatureStruct}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{SignatureStruct}}, Ptr{Void}), sig_ptr, repo_ptr)
        committer_ptr = sig_ptr[1]
    end
    local author_ptr::Ptr{SignatureStruct}
    if author != nothing
        author_ptr = convert(Ptr{SignatureStruct}, committer)
    else
        sig_ptr = Ptr{SignatureStruct}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{SignatureStruct}}, Ptr{Void}), sig_ptr, repo_ptr)
        author_ptr = sig_ptr[1]
    end 
    tid = Oid(obj)
    err = ccall((:git_note_remove, :libgit2), Cint,
                (Ptr{Void}, Ptr{Cchar}, 
                 Ptr{SignatureStruct}, Ptr{SignatureStruct}, Ptr{Oid}),
                 repo_ptr, notes_ref, author_ptr, committer_ptr, &tid)
    if err == GitErrorConst.ENOTFOUND
        return false
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return true
end

function note_default_ref(r::GitRepo)
    refname_ptr = Ptr{Uint8}[0]
    @check ccall((:git_note_default_ref, :libgit2), Cint, 
                 (Ptr{Ptr{Uint8}}, Ptr{Void}), refname_ptr, r)
    return utf8(bytestring(refname_ptr[1]))
end

function cb_iter_notes(blob_id::Ptr{Oid}, ann_obj_id::Ptr{Oid}, repo_ptr::Ptr{Void})
    blob_ptr    = Ptr{Void}[0]
    ann_obj_ptr = Ptr{Void}[0]
    err = ccall((:git_object_lookup, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                ann_obj_ptr, repo_ptr, ann_obj_id, GitConst.OBJ_BLOB)
    err |= ccall((:git_object_lookup, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                 blob_ptr, repo_ptr, blob_id, GitConst.OBJ_BLOB)
    if err == GitErrorConst.GIT_OK
        res = (gitobj_from_ptr(ann_obj_id[1]), gitobj_from_ptr(blob_ptr[1]))
        produce(res)
    end
    return err
end

const c_cb_iter_notes = cfunction(cb_iter_notes, Cint, (Ptr{Oid}, Ptr{Oid}, Ptr{Void}))

function iter_notes(r::GitRepo, notes_ref::MaybeString=nothing)
    bnotes_ref = ref != nothing ? bytestring(notes_ref) : C_NULL
    return @task ccall((:git_note_foreach, :libgit2), Cint, 
                       (Ptr{Void}, Ptr{Uint8}, Ptr{Void}, Ptr{Void}),
                       r, notes_ref, c_cb_iter_notes, r)
end

function ahead_behind(r::GitRepo, lcommit::GitCommit, ucommit::GitCommit)
    return ahead_behind(r, Oid(lcommit), Oid(ucommit))
end

function ahead_behind(r::GitRepo, lid::Oid, uid::Oid)
    ahead, behind = Csize_t[0], Csize_t[0]
    @check ccall((:git_graph_ahead_behind, :libgit2), Cint,
                 (Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Void}, Ptr{Oid}, Ptr{Oid}),
                 ahead, behind, r, &lid, &uid)
    return (int(ahead[1]), int(behind[1]))
end

function blob_at(r::GitRepo, rev::Oid, pth::String)
    tree = GitTree(lookup_commit(r, rev))
    local blob_entry::GitTreeEntry
    try
        blob_entry = entry_bypath(tree, pth)
        @assert isa(blob_entry, GitTreeEntry{GitBlob})
    catch
        return nothing
    end
    blob = lookup_blob(r, Oid(blob_entry))
    return blob
end

#TODO: consolidate with odb
function write!{T<:GitObject}(::Type{T}, r::GitRepo, buf::ByteString)
    odb = Odb(r)
    stream_ptr = Ptr{Void}[0]
    @check ccall((:git_odb_open_wstream, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Csize_t, Cint),
                 stream_ptr, odb, length(buf), git_otype(T))
    @assert stream_ptr[1] != C_NULL
    err = ccall((:git_odb_stream_write, :libgit2), Cint,
                (Ptr{Void}, Ptr{Uint8}, Csize_t), stream_ptr[1], buf, length(buf))
    id_ptr = [Oid()]
    if err == GitErrorConst.GIT_OK
        err = ccall((:git_odb_stream_finalize_write, :libgit2), Cint,
                    (Ptr{Oid}, Ptr{Void}), id_ptr, stream_ptr[1])
    end
    ccall((:git_odb_stream_free, :libgit2), Void, (Ptr{Void},), stream_ptr[1])
    if err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return id_ptr[1]
end

#TODO: implement
function references(r::GitRepo)
    return nothing
end

function repo_discover(pth::String="", acrossfs::Bool=true)
    isempty(pth) && (pth = pwd())
    brepo = zeros(Uint8, GitConst.GIT_PATH_MAX)
    #TODO: do we have to free the buffer?
    buf_ptr = [BufferStruct()]
    @check ccall((:git_repository_discover, :libgit2), Cint,
                 (Ptr{BufferStruct}, Ptr{Uint8}, Cint, Ptr{Uint8}), 
                 buf_ptr, pth, acrossfs? 1:0, C_NULL)
    return GitRepo(bytestring(buf_ptr[1]))
end

function rev_parse(r::GitRepo, rev::String)
    obj_ptr = Ptr{Void}[0]
    @check ccall((:git_revparse_single, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), obj_ptr, r, rev)
    return gitobj_from_ptr(obj_ptr[1])
end
rev_parse(r::GitRepo, rev::Oid) = rev_parse(r, string(rev))

function merge_base(r::GitRepo, args...)
    if length(args) < 2
        throw(ArgumentError("merge_base needs 2+ commits"))
    end
    arg_oids = vcat([raw(Oid(r, a)) for a in args]...)
    @assert length(arg_oids) == length(args) * OID_RAWSZ
    len = convert(Csize_t, length(args))
    id_ptr = [Oid()]
    err = ccall((:git_merge_base_many, :libgit2), Cint, 
                (Ptr{Oid}, Ptr{Void}, Csize_t, Ptr{Uint8}), id_ptr, r, len, arg_oids)
    if err == GitErrorConst.ENOTFOUND
        return nothing
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return id_ptr[1]
end
rev_parse_oid(r::GitRepo, rev::Oid) = Oid(rev_parse(r, string(rev)))
rev_parse_oid(r::GitRepo, rev::String) = Oid(rev_parse(r, rev))

Odb(r::GitRepo) = begin
    odb_ptr = Ptr{Void}[0]
    @check ccall((:git_repository_odb, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), odb_ptr, r)
    return Odb(odb_ptr[1])
end

GitIndex(r::GitRepo) = begin
    idx_ptr = Ptr{Void}[0]
    @check ccall((:git_repository_index, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), idx_ptr, r)
    return GitIndex(idx_ptr[1])
end

function lookup{T<:GitObject}(::Type{T}, r::GitRepo, id::Oid)
    obj_ptr = Ptr{Void}[0]
    @check ccall((:git_object_lookup, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                 obj_ptr, r, &id, git_otype(T))
    return T(obj_ptr[1])
end

function lookup{T<:GitObject}(::Type{T}, r::GitRepo, oid::String)
    len = length(oid)
    id_ptr  = [Oid()]
    obj_ptr = Ptr{Void}[0]
    @check ccall((:git_oid_fromstrn, :libgit2), Cint,
                 (Ptr{Oid}, Ptr{Uint8}, Csize_t), id_ptr, oid, len) 
    if len < OID_HEXSZ
        @check ccall((:git_object_lookup_prefix, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Csize_t, Cint),
                     obj_ptr, r, id_ptr, len, git_otype(T))
    else
        @check ccall((:git_object_lookup, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                     obj_ptr, r, id_ptr, git_otype(T)) 
    end
    return T(obj_ptr[1]) 
end

lookup(r::GitRepo, id::String) = lookup(GitAnyObject, r, id)
lookup(r::GitRepo, id::Oid)    = lookup(GitAnyObject, r, id)
lookup_tree(r::GitRepo, id)    = lookup(GitTree, r, id)
lookup_blob(r::GitRepo, id)    = lookup(GitBlob, r, id)
lookup_commit(r::GitRepo, id)  = lookup(GitCommit, r, id)

function lookup_ref(r::GitRepo, refname::String)
    ref_ptr = Ptr{Void}[0]
    err = ccall((:git_reference_lookup, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), ref_ptr, r, refname)
    if err == GitErrorConst.ENOTFOUND
        return nothing
    elseif err != GitErrorConst.GIT_OK
        return LibGitError(err)
    end
    return GitReference(ref_ptr[1])
end

function create_ref(r::GitRepo, refname::String, id::Oid; 
                    force::Bool=false, 
                    sig::Union(Nothing,Signature)=nothing, 
                    logmsg::Union(Nothing,String)=nothing)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_create, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Oid},
                  Cint, Ptr{SignatureStruct}, Ptr{Uint8}),
                 ref_ptr, r, refname, &id, force? 1:0,
                 sig != nothing ? sig : C_NULL,
                 logmsg != nothing ? logmsg : C_NULL)
    return GitReference(ref_ptr[1])
end

function create_ref(r::GitRepo, refname::String, target::String; 
                    force::Bool=false, sig=nothing, logmsg=nothing)
    create_sym_ref(r, refname, target; force=force, sig=sig, logmsg=logmsg)
end

function create_sym_ref(r::GitRepo, refname::String, target::String; 
                        force::Bool=false, sig=sig, logmsg=logmsg)
    ref_ptr = Ptr{Void}[0]
    @check ccall((:git_reference_symbolic_create, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8},
                 Cint, Ptr{SignatureStruct}, Ptr{Uint8}),
                 ref_ptr, r, refname, target, force? 1:0, 
                 sig != nothing ? sig : C_NULL,
                 logmsg != nothing ? logmsg : C_NULL)
    return GitReference(ref_ptr[1])
end

function repo_revparse_single(r::GitRepo, spec::String)
    obj_ptr = Ptr{Void}[0]
    @check ccall((:git_revparse_single, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), obj_ptr, r, spec)
    return gitobj_from_ptr(obj_ptr[1])
end

function commit(r::GitRepo,
                refname::String,
                author::Signature,
                committer::Signature,
                msg::String,
                tree::GitTree,
                parents::GitCommit...)
    id_ptr = [Oid()]
    nparents = length(parents)
    parentptrs = Ptr{Void}[c.ptr for c in parents]
    @check ccall((:git_commit_create, :libgit2), Cint,
                 (Ptr{Oid}, Ptr{Void}, Ptr{Uint8},
                  Ptr{SignatureStruct}, Ptr{SignatureStruct}, 
                  Ptr{Uint8}, Ptr{Uint8}, Ptr{Void},
                  Csize_t, Ptr{Ptr{Void}}),
                 id_ptr, r, refname, author, committer, C_NULL, msg, tree, 
                 nparents, nparents > 0 ? parentptrs : C_NULL)
    return id_ptr[1]
end

function repo_set_workdir(r::GitRepo, dir::String, update::Bool)
end

# filter can be :all, :local, :remote
function branch_names(r::GitRepo, filter::Symbol=:all)
    local git_filter::Cint 
    if filter == :all
        git_filter = GitConst.BRANCH_LOCAL | GitConst.BRANCH_REMOTE
    elseif filter == :local
        git_filter = GitConst.BRANCH_LOCAL
    elseif filter == :remote
        git_filter = GitConst.BRANCH_REMOTE
    else
        throw(ArgumentError("filter can be :all, :local, or :remote"))
    end
    iter_ptr = Ptr{Void}[0]
    @check ccall((:git_branch_iterator_new, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Cint), iter_ptr, r, git_filter)
    branch_ptr = Ptr{Void}[0]
    branch_type = Cint[0] 
    names = UTF8String[]
    while true
        err = ccall((:git_branch_next, :libgit2), Cint,
                    (Ptr{Ptr{Void}}, Ptr{Cint}, Ptr{Void}),
                    branch_ptr, branch_type, iter_ptr[1])
        if err == GitErrorConst.ITEROVER
            break
        end
        if err != GitErrorConst.GIT_OK
            if iter_ptr[1] != C_NULL
                ccall((:git_branch_iterator_free, :libgit2), Void,
                      (Ptr{Void},), iter_ptr[1])
            end
            throw(LibGitError(err))
        end
        name_ptr = ccall((:git_reference_shorthand, :libgit2), Ptr{Uint8}, 
                         (Ptr{Void},), branch_ptr[1])
        push!(names, utf8(bytestring(name_ptr)))
    end
    ccall((:git_branch_iterator_free, :libgit2), Void, (Ptr{Void},), iter_ptr[1])
    return names
end

# branch type can be :local or :remote
function lookup(::Type{GitBranch}, r::GitRepo, branch_name::String, branch_type::Symbol=:local)
    local git_branch_type::Cint
    if branch_type == :local
        git_branch_type = GitConst.BRANCH_LOCAL
    elseif branch_type == :remote 
        git_branch_type = GitConst.BRANCH_REMOTE
    else
        throw(ArgumentError("branch_type can be :local or :remote"))
    end
    branch_ptr = Ptr{Void}[0]
    err = ccall((:git_branch_lookup, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Cint),
                branch_ptr, r, branch_name, git_branch_type)
    if err == GitErrorConst.GIT_OK
        return GitBranch(branch_ptr[1])
    elseif err == GitErrorConst.ENOTFOUND
        return nothing
    else
        throw(LibGitError(err))
    end
end

lookup_branch(r::GitRepo, branch_name::String, branch_type=:local) = 
        lookup(GitBranch, r, branch_name, branch_type)

lookup_branch(r::GitRepo, branch_id::Oid, branch_type=:local) = 
        lookup(GitBranch, r, string(branch_id), branch_type)

#TODO: give intelligent error msg when target does not exist
function create_branch(r::GitRepo, bname::String, target::Oid;
                       force::Bool=false,
                       sig::Union(Nothing,Signature)=nothing, 
                       logmsg::Union(Nothing,String)=nothing)
    commit = lookup_commit(r, target)
    branch_ptr = Ptr{Void}[0]
    @check ccall((:git_branch_create, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Void},
                 Cint, Ptr{SignatureStruct}, Ptr{Uint8}),
                 branch_ptr, r, bname, commit, force? 1:0,
                 sig != nothing ? sig : C_NULL,
                 logmsg != nothing ? logmsg : C_NULL)
    return GitBranch(branch_ptr[1]) 
end

function create_branch(r::GitRepo, n::String, target::String="HEAD"; 
                       force::Bool=false, sig=nothing, logmsg=nothing)
    id = rev_parse_oid(r, target)
    return create_branch(r, n, id, force=force, sig=sig, logmsg=logmsg)
end

function create_branch(r::GitRepo, n::String, target::GitCommit;
                       force::Bool=false, sig=nothing, logmsg=nothing)
    id = Oid(target)
    return create_branch(r, n, id, force=force, sig=sig, logmsg=logmsg)
end

type BranchIterator 
    repo::GitRepo
    ptr::Ptr{Void}

    function BranchIterator(r::GitRepo, ptr::Ptr{Void}) 
        @assert ptr != C_NULL
        bi = new(r, ptr)
        finalizer(bi, free!)
        return bi
    end
end

free!(b::BranchIterator) = begin
    if b.ptr != C_NULL
        ccall((:git_branch_iterator_free, :libgit2), Void, (Ptr{Void},), b.ptr)
        b.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, b::BranchIterator) = b.ptr 

function iter_branches(r::GitRepo, filter::Symbol=:all)
    local git_filter::Cint
    if filter == :all
        git_filter = GitConst.BRANCH_LOCAL | GitConst.BRANCH_REMOTE
    elseif filter == :local
        git_filter = GitConst.BRANCH_LOCAL
    elseif filter == :remote
        git_filter == GitConst.BRANCH_REMOTE
    else
        throw(ArgumentError("filter can be :all, :local, or :remote"))
    end 
    iter_ptr = Ptr{Void}[0]
    @check ccall((:git_branch_iterator_new, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Cint), iter_ptr, r, git_filter)
    return BranchIterator(r, iter_ptr[1])
end

#TODO: branch type?
Base.start(b::BranchIterator) = begin
    branch_ptr  = Ptr{Void}[0]
    branch_type = Cint[0]
    err = ccall((:git_branch_next, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Cint}, Ptr{Void}), branch_ptr, branch_type, b)
    if err == GitErrorConst.ITEROVER
        return nothing
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return GitBranch(branch_ptr[1])
end

Base.done(b::BranchIterator, state) = state == nothing

Base.next(b::BranchIterator, state) = begin
    branch_ptr  = Ptr{Void}[0]
    branch_type = Cint[0] 
    err = ccall((:git_branch_next, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Cint}, Ptr{Void}), branch_ptr, branch_type, b)
    if err == GitErrorConst.ITEROVER
        return (state, nothing)
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return (state, GitBranch(branch_ptr[1]))
end

#------- Tree merge ---------
parse_merge_options(opts::Nothing) = MergeTreeOptsStruct()

function parse_merge_options(opts::Dict)
    if isempty(opts)
        return MergeTreeOptsStruct() 
    end
    local rename_threshold = zero(Cuint) 
    if haskey(opts, :rename_threshold)
        rename_threshold = convert(Cuint, opts[:rename_threshold])
    end
    local target_limit = zero(Cuint) 
    if haskey(opts, :target_limit)
        target_limit = convert(Cuint, opts[:target_limit])
    end
    local automerge_flags = zero(Cint)
    if haskey(opts, :automerge)
        a = opts[:automerge]
        if a == :normal
            flags = GitConst.MERGE_AUTOMERGE_NORMAL
        elseif a == :none
            flags = GitConst.MERGE_AUTOMERGE_NONE
        elseif a == :favor_ours
            flags = GitConst.MERGE_AUTOMERGE_FAVOR_OURS
        elseif a == :favor_theirs
            flags = GitConst.MERGE_AUTOMERGE_FAVOR_THEIRS
        else
            throw(ArgumentError("Unknown automerge option :$a"))
        end
    end
    local flags = zero(Cint)
    if get(opts, :renames, false)
        flags |= MERGE_TREE_FIND_RENAMES
    end
    return MergeTreeOptsStruct(one(Cint), flags, rename_threshold, target_limit, C_NULL, automerge_flags)
end

#TODO: tree's should reference owning repository
Base.merge!(r::GitRepo, t1::GitTree, t2::GitTree, opts=nothing) = begin
    gopts = parse_merge_options(opts)
    idx_ptr = Ptr{Void}[0]
    @check ccall((:git_merge_trees, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{MergeTreeOptsStruct}),
                 idx_ptr, r, C_NULL, t1, t2, &gopts)
    return GitIndex(idx_ptr[1])
end

Base.merge!(r::GitRepo, t1::GitTree, t2::GitTree, ancestor::GitTree, opts=nothing) = begin
    gopts = parse_merge_options(opts)
    idx_ptr = Ptr{Void}[0]
    @check ccall((:git_merge_trees, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{MergeTreeOptsStruct}),
                 idx_ptr, r.ptr, ancestor.ptr, t1.ptr, t2.ptr, &gopts)
    return GitIndex(idx_ptr[1])
end

#------- Merge Commits -----
function merge_commits(r::GitRepo, ours::Union(GitCommit, Oid), theirs::Union(GitCommit, Oid), opts=nothing)
    gopts = parse_merge_options(opts)
    isa(ours,   Oid) && (ours   = lookup_commit(r, ours))
    isa(theirs, Oid) && (theirs = lookup_commit(r, theirs)) 
    index_ptr = Ptr{Void}[0] 
    @check ccall((:git_merge_commits, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void},
                  Ptr{Void}, Ptr{MergeTreeOptsStruct}),
                 index_ptr, r, ours, theirs, &gopts)
    return GitIndex(index_ptr[1])
end

#------- Repo Checkout -------
function cb_checkout_progress(path_ptr::Ptr{Uint8}, 
                              completed_steps::Csize_t,
                              total_steps::Csize_t,
                              payload::Ptr{Void})
    callback = unsafe_pointer_to_objref(payload)::Function
    path = path_ptr != C_NULL ? bytestring(path_ptr) : nothing
    callback(path, completed_steps, total_steps)
    return
end

const c_cb_checkout_progress = cfunction(cb_checkout_progress, Void,
                                         (Ptr{Uint8}, Csize_t, Csize_t, Ptr{Void}))

function cb_checkout_notify(why::Cint, 
                            path_ptr::Ptr{Uint8}, 
                            baseline::Ptr{DiffFileStruct}, 
                            target::Ptr{DiffFileStruct},
                            workdir::Ptr{DiffFileStruct},
                            payload::Ptr{Void})
    callback = unsafe_pointer_to_objref(payload)::Function
    path = path_ptr != C_NULL ? bytestring(path_ptr) : nothing
    local reason::Symbol
    if why == GitConst.CHECKOUT_NOTIFY_CONFLICT
        reason = :conflict
    elseif why == GitConst.CHECKOUT_NOTIFY_DIRTY
        reason = :dirty
    elseif why == GitConst.CHECKOUT_NOTIFY_UPDATED
        reason = :updated
    elseif why == GitConst.CHECKOUT_NOTIFY_UNTRACKED
        reason = :untracked
    elseif why == GitConst.CHECKOUT_NOTIFY_IGNORED
        reason = :ignored
    else
        reason = :unknown
    end
    try
        callback(why, path, DiffFile(baseline), DiffFile(target), DiffFile(workdir))
        return GitErrorConst.GIT_OK
    catch
        return GitErrorConst.ERROR
    end
end

const c_cb_checkout_notify = cfunction(cb_checkout_notify, Cint,
                                       (Cint,
                                        Ptr{Uint8}, 
                                        Ptr{DiffFileStruct}, 
                                        Ptr{DiffFileStruct}, 
                                        Ptr{DiffFileStruct},
                                        Ptr{Void}))

parse_checkout_options(opts::Nothing) = CheckoutOptionsStruct()

function parse_checkout_options(opts::Dict)
    if isempty(opts)
        return CheckoutOptionsStruct() 
    end
    progress_cb = convert(Ptr{Void}, C_NULL)
    progress_payload = convert(Ptr{Void}, C_NULL)
    if haskey(opts, :progress)
        if !isa(opts[:progress], Function)
            throw(ArgumentError("opts[:progress] must be a Function object"))
        end
        progress_payload = pointer_from_objref(opts[:progress])
        progress_cb = c_cb_checkout_progress
    end
    notify_cb = convert(Ptr{Void}, C_NULL)
    notify_payload = convert(Ptr{Void}, C_NULL)
    if haskey(opts, :notify)
        if !isa(opts[:notify], Function)
            throw(ArgumentError("opts[:notify] must be a Function object"))
        end
        notify_payload = pointer_from_objref(opts[:notify])
        notify_cb = c_cb_checkout_notify
    end
    checkout_strategy = zero(Cuint)
    if haskey(opts, :strategy)
        local strategy::Vector{Symbol}
        if isa(opts[:strategy], Symbol)
            strategy = [opts[:strategy]]
        else
            strategy = opts[:strategy]
        end
        for s in strategy
            if s == :safe
                checkout_strategy |= GitConst.CHECKOUT_SAFE
            elseif s == :safe_create
                checkout_strategy |= GitConst.CHECKOUT_SAFE_CREATE
            elseif s == :force
                checkout_strategy |= GitConst.CHECKOUT_FORCE
            elseif s == :allow_conflicts
                checkout_strategy |= GitConst.CHECKOUT_ALLOW_CONFLICTS
            elseif s == :remove_untracked
                checkout_strategy |= GitConst.CHECKOUT_REMOVE_UNTRACKED
            elseif s == :remove_ignored
                checkout_strategy |= GitConst.CHECKOUT_REMOVE_IGNORED
            elseif s == :update_only
                checkout_strategy |= GitConst.CHECKOUT_UPDATE_ONLY
            elseif s == :dont_update_index
                checkout_strategy |= GitConst.CHECKOUT_DONT_UPDATE_INDEX
            elseif s == :no_refresh
                checkout_strategy |= GitConst.CHECKOUT_NO_REFRESH
            elseif s == :disable_pathspec_match
                checkout_strategy |= GitConst.CHECKOUT_DISABLE_PATHSPEC_MATCH
            elseif s == :skip_locked_directories
                checkout_strategy |= GitConst.CHECKOUT_SKIP_LOCKED_DIRECTORIES
            elseif s == :skip_unmerged
                checkout_strategy |= GitConst.CHECKOUT_SKIP_UNMERGED
            elseif s == :use_ours
                checkout_strategy |= GitConst.CHECKOUT_USE_OURS
            elseif s == :use_theirs
                checkout_strategy |= GitConst.CHECKOUT_USE_THEIRS
            elseif s == :update_submodules
                checkout_strategy |= GitConst.CHECKOUT_UPDATE_SUBMODULES
            elseif s == :update_submodules_if_changed
                checkout_strategy |= GitConst.CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED
            else
                throw(ArgumentError("unknown checkout strategy flag :$s"))
            end
        end
    end
    notify_flags = zero(Cuint)
    if haskey(opts, :notify_flags)
        local flags::Vector{Symbol}
        if isa(opts[:notify_flags], Symbol)
            flags = [opts[:notify_flags]]
        else
            flags = opts[:notify_flags]
        end
        for f in flags
            if f == :conflict
                notify_flags |= GitConst.CHECKOUT_NOTIFY_CONFLICT
            elseif f == :dirty
                notify_flags |= GitConst.CHECKOUT_NOTIFY_DIRTY
            elseif f == :updated
                notify_flags |= GitConst.CHECKOUT_NOTIFY_UPDATED
            elseif f == :untracked
                notify_flags |= GitConst.CHECKOUT_NOTIFY_UNTRACKED
            elseif f == :ignored
                notify_flags |= GitConst.CHECKOUT_NOTIFY_IGNORED
            elseif f == :all
                notify_flags |= GitConst.CHECKOUT_NOTIFY_ALL
            else
                throw(ArgumentError("unknown checkout notify flag :$f"))
            end
        end
    end

    disable_filters = convert(Cint, get(opts, :disable_filters, false) ? 1 : 0)
    
    dir_mode = zero(Cuint)
    if haskey(opts, :dir_mode)
        dir_mode = convert(Cuint, opts[:dir_mode])
    end
    file_mode = zero(Cuint)
    if haskey(opts, :file_mode)
        file_mode = convert(Cuint, opts[:file_mode])
    end
    file_open_flags = zero(Cint)
    if haskey(opts, :file_open_flags)
        file_open_flags = convert(Cint, opts[:file_open_flags])
    end
    target_directory = zero(Ptr{Cchar})
    if haskey(opts, :target_directory)
        target_directory = convert(Ptr{Cchar}, 
					 pointer(bytestring(opts[:target_directory])))
    end
    baseline = zero(Ptr{Void})
    if haskey(opts, :baseline)
        if isa(opts[:baseline], GitTree)
            baseline = convert(Ptr{Void}, opts[:baseline])
        else
            throw(ArgumentError("checkout options :baseline should be a GitTree"))
        end
    end
    paths = StrArrayStruct() 
    if haskey(opts, :paths)
        paths = opts[:paths]
        if isa(paths, String)
            paths = [paths]
        end
        npaths = length(paths)
        cpaths = Array(Ptr{Cchar}, npaths)
        paths_count = convert(Csize_t, npaths)
        for i in 1:npaths
            cpaths[i] = convert(Ptr{Cchar}, pointer(paths[i]))
        end
        paths_strings = convert(Ptr{Ptr{Cchar}}, cpaths)
        paths = StrArrayStruct(paths_strings, paths_count)
    end
    #TODO:
    ancestor_label = C_NULL
    our_label = C_NULL
    their_label = C_NULL
    return CheckoutOptionsStruct(
                          one(Cuint),
                          checkout_strategy,
                          disable_filters, 
                          dir_mode,
                          file_mode,
                          file_open_flags,
                          notify_flags,
                          notify_cb, 
                          notify_payload,
                          progress_cb,
                          progress_payload,
                          paths,
                          baseline,
                          target_directory,
                          ancestor_label,
                          our_label,
                          their_label)
end

typealias Treeish Union(GitCommit, GitTag, GitTree)

function checkout_tree!(r::GitRepo, tree::String, opts=nothing)
    t = rev_parse(r, tree)
    return checkout_tree!(r, t, opts)
end

function checkout_tree!(r::GitRepo, tree::Treeish, opts=nothing)
    gopts = parse_checkout_options(opts)
    err = ccall((:git_checkout_tree, :libgit2), Cint,
                (Ptr{Void}, Ptr{Void}, Ptr{CheckoutOptionsStruct}),
                r, tree, &gopts)
    #TODO: memory leak with option strings
    if err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return r 
end

function checkout_head!(r::GitRepo, opts=nothing)
    gopts = parse_checkout_options(opts)
    err = ccall((:git_checkout_head, :libgit2), Cint,
                (Ptr{Void}, Ptr{CheckoutOptionsStruct}),r, &gopts)
    #TODO: memory leak with option strings??, cleanup on exceptions, etc...
    if err != GitErrorConst.GIT_OK
        throw(GitError(err))
    end
    return r
end

function checkout!(r::GitRepo, target, opts={})
    if !haskey(opts, :strategy)
        opts[:strategy] = :safe
    end
    delete!(opts, :paths)
    if target == "HEAD"
        return checkout_head!(r, opts)
    end
    local branch
    if isa(target, GitBranch)
        branch = target
    else
        branch = lookup_branch(r, string(target), :local)
        if branch == nothing
            branch = lookup_branch(r, string(target), :remote)
        end
    end
    if branch != nothing
        checkout_tree!(r, tip(branch), opts)
        if isremote(branch)
            create_ref(r, "HEAD", Oid(tip(branch)), force=true)
        else
            create_ref(r, "HEAD", canonical_name(branch), force=true)
        end
    else
        commit = lookup_commit(r, rev_parse_oid(r, target))
        create_ref(r, "HEAD", Oid(commit), force=true)
        checkout_tree!(r, commit, opts)
    end
end

#=
#------- Repo Clone -------
abstract GitCredential

immutable CredDefault <: GitCredential end

immutable CredPlainText <: GitCredential
    username::String
    password::String
end

immutable CredSSHKey <: GitCredential
    username::MaybeString
    publickey::MaybeString
    privatekey::String
    passphrase::MaybeString
end

function cb_remote_transfer(stats_ptr::Ptr{api.GitTransferProgress},
                            payload_ptr::Ptr{Void})
    stats = unsafe_load(stats_ptr)
    payload = unsafe_pointer_to_objref(payload_ptr)::Dict
    callback = payload[:callbacks][:transfer_progress]
    try
        callback(stats.total_objects,
                 stats.indexed_objects,
                 stats.received_objects,
                 stats.received_bytes)
        return GitErrorConst.GIT_OK
    catch err
        payload[:exception] = err
        return GitErrorConst.ERROR
    end
end

const c_cb_remote_transfer = cfunction(cb_remote_transfer, Cint,
                                       (Ptr{api.GitTransferProgress}, Ptr{Void}))

function extract_cred!(cred::GitCredential, cred_ptr::Ptr{Ptr{Void}}, allowed_types::Cuint)
    if isa(cred, CredPlainText)
        if !bool(allowed_types & GitConst.CREDTYPE_USERPASS_PLAINTEXT)
            error("invalid credential type")
        end
        @check ccall((:git_cred_userpass_plaintext_new, :libgit2), Cint,
                      (Ptr{Ptr{Void}}, Ptr{Cchar}, Ptr{Cchar}),
                       cred_ptr,
                       bytestring(cred.username),
                       bytestring(cred.password))
    elseif isa(cred, CredSSHKey)
        if !bool(allowed_types & GitConst.CREDTYPE_SSH_KEY)
            error("invalid credential type")
        end
        @check ccall((:git_cred_ssh_key_new, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}),
                     cred_ptr,
                     cred.username != nothing ? cred.username : C_NULL,
                     cred.publickey != nothing ? cred.publickey : C_NULL,
                     cred.privatekey != nothing ? cred.privatekey : C_NULL,
                     cred.passphrase != nothing ? cred.passphrase : C_NULL)
    elseif (cred, CredDefault)
        if !bool(allowed_types & GitConst.CREDTYPE_SSH_KEY)
            error("invalid credential type")
        end
        @check ccall((:git_cred_default_new, :libgit2), Cint,
                     (Ptr{Ptr{Void}},), cred_ptr)
    else
        error("invalid credential type")
    end
    return nothing
end

function cb_default_remote_credentials(cred_ptr::Ptr{Ptr{Void}},
                                       url::Ptr{Cchar},
                                       username_from_url::Ptr{Cchar},
                                       allowed_types::Cuint,
                                       payload_ptr::Ptr{Void})
    payload = unsafe_pointer_to_objref(payload_ptr)::Dict
    cred = payload[:credentials]
    try
        extract_cred!(cred, cred_ptr, allowed_types)
        return GitErrorConst.GIT_OK
    catch err
        payload[:exception] = err
        return GitErrorConst.ERROR
    end
end

const c_cb_default_remote_credentials = cfunction(cb_default_remote_credentials, Cint,
                                                  (Ptr{Ptr{Void}}, Ptr{Cchar}, Ptr{Cchar}, Cuint, Ptr{Void}))

function cb_remote_credentials(cred_ptr::Ptr{Ptr{Void}},
                               url::Ptr{Cchar},
                               username::Ptr{Cchar},
                               allowed_types::Cuint,
                               payload_ptr::Ptr{Void})
    payload = unsafe_pointer_to_objref(payload_ptr)::Dict
    cred_func = payload[:credentials]::Function
    types = Symbol[]
    if bool(allowed_types & GitConst.CREDTYPE_USERPASS_PLAINTEXT)
        push!(types, :plaintext)
    end
    if bool(allowed_types & GitConst.CREDTYPE_SSH_KEY)
        push!(types, :sshkey)
    end
    if bool(allowed_types & GitConst.CREDTYPE_DEFAULT)
        push!(types, :default)
    end 
    try
        cred = cred_func(url != C_NULL ? bytestring(url) : nothing,
                         username != C_NULL ? bytestring(username) : nothing,
                         types)
        #TODO: better error msg
        if !(isa(cred, GitCredential))
            error("returned credential is not a git credential subtype")
        end
        extract_cred!(cred, cred_ptr, allowed_types)
        return GitErrorConst.GIT_OK
    catch err
        payload[:exception] = err
        return GitErrorConst.ERROR
    end
end

const c_cb_remote_credential = cfunction(cb_remote_credentials, Cint,
                                         (Ptr{Ptr{Void}}, Ptr{Cchar}, Ptr{Cchar}, Cuint, Ptr{Void}))

function parse_clone_options(opts, payload::Dict)
    gopts = api.GitCloneOpts()
    if opts == nothing || isempty(opts)
        return gopts
    end
    if haskey(opts, :bare)
        gopts.bare = convert(Cint, opts[:bare] ? 1 : 0)
    end
    if haskey(opts, :credentials)
        cred = opts[:credentials]
        if isa(cred, GitCredential)
            payload[:credentials] = cred
            gopts.remote_credentials_cb = convert(Ptr{Void}, c_cb_default_remote_credentials)
        elseif isa(cred, Function)
            payload[:credentials] = cred
            gopts.remote_credentials_cb = convert(Ptr{Void}, c_cb_remote_credential)
        else
            throw(ArgumentError("clone option :credentials must be a GitCredential or Function type"))
        end
    end
    if haskey(opts, :callbacks)
        callbacks = opts[:callbacks]
        if haskey(callbacks, :transfer_progress)
            if !isa(callbacks[:transfer_progress], Function)
                throw(ArgumentError("clone callback :transfer_progress must be a Function"))
            end
            payload[:callbacks] = callbacks
            gopts.remote_transfer_progress_cb = convert(Ptr{Void}, c_cb_remote_transfer)
        end
    end
    gopts.remote_payload = convert(Ptr{Void}, pointer_from_objref(payload))
    return gopts
end

function repo_clone(url::String, path::String, opts=nothing)
    # we initalize the payload here as pointer_from_objref
    # hides the object from julia's gc.  A reference in this
    # function's scope allows the object to be preserved
    # for the lifetime of the function call.
    gpayload = Dict() 
    gopts    = parse_clone_options(opts, gpayload)
    repo_ptr = Ptr{Void}[0]
    err = ccall((:git_clone, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Uint8}, Ptr{Uint8}, Ptr{api.GitCloneOpts}),
                 repo_ptr, url, path, &gopts)
    if err != GitErrorConst.GIT_OK
        payload = unsafe_pointer_to_objref(gopts.remote_payload)::Dict
        if haskey(payload, :exception)
            throw(payload[:exception])
        else
            throw(LibGitError(err))
        end
    end
    return GitRepo(repo_ptr[1])
end
=#

#-------- Reference Iterator --------
#TODO: handle error's when iterating (see branch)
type ReferenceIterator
    repo::GitRepo
    ptr::Ptr{Void}

    function ReferenceIterator(r::GitRepo, ptr::Ptr{Void})
        @assert ptr != C_NULL
        ri = new(r, ptr)
        finalizer(ri, free!)
        return ri
    end
end

free!(r::ReferenceIterator) = begin
    if r.ptr != C_NULL
        ccall((:git_reference_iterator_free, :libgit2), Void, (Ptr{Void},), r.ptr)
        r.ptr = C_NULL
    end
end

Base.convert(::Type{Ptr{Void}}, r::ReferenceIterator) = r.ptr

function ref_names(r::GitRepo, glob::String="")
    rnames = UTF8String[]
    for r in iter_refs(r, glob)
        push!(rnames, utf8(name(r)))
    end
    return rnames
end

function iter_refs(r::GitRepo, glob::String="")
    iter_ptr = Ptr{Void}[0]
    if isempty(glob)
        @check ccall((:git_reference_iterator_new, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}), iter_ptr, r)
    else
        @check ccall((:git_reference_iterator_glob_new, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), iter_ptr, r, glob)
    end
    return ReferenceIterator(r, iter_ptr[1])
end

Base.start(r::ReferenceIterator) = begin
    ref_ptr = Ptr{Void}[0]
    err = ccall((:git_reference_next, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}), ref_ptr, r)
    if err == GitErrorConst.ITEROVER
        return nothing
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return GitReference(ref_ptr[1])
end

Base.done(r::ReferenceIterator, state) = is(state, nothing)

Base.next(r::ReferenceIterator, state) = begin
    ref_ptr = Ptr{Void}[0]
    err = ccall((:git_reference_next, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}), ref_ptr, r)
    if err == GitErrorConst.ITEROVER
        return (state, nothing)
    elseif err != GitErrorConst.GIT_OK
        throw(LibGitError(err))
    end
    return (state, GitReference(ref_ptr[1]))
end
