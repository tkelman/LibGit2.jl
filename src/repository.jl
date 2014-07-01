export repo_isbare, repo_isempty, repo_workdir, repo_path, path,
       repo_open, repo_init, repo_index, head, set_head!, tags, tag!, commits, references,
       repo_lookup, lookup_tree, lookup_commit, commit, ref_names,
       repo_revparse_single, create_ref, create_sym_ref, lookup_ref,
       repo_odb, iter_refs, config,  GitTreeBuilder,
       insert!, write!, close, lookup, rev_parse, rev_parse_oid, remotes,
       ahead_behind, merge_base, merge_commits,  blob_at, is_shallow, hash_data,
       default_signature, repo_discover, is_bare, is_empty, namespace, set_namespace!,
       notes, create_note!, remove_note!, each_note, note_default_ref, iter_notes,
       blob_from_buffer, blob_from_workdir, blob_from_disk, blob_from_stream,
       branch_names, lookup_branch, create_branch, lookup_remote, iter_branches,
       remote_names, remote_add!, checkout_tree!, checkout_head!, checkout!, 
       is_head_detached, GitCredential, CredDefault, CredPlainText, CredSSHKey, 
       repo_clone

GitRepo(path::String; alternates::Vector{String}=String[]) = begin
    repo_ptr = Ptr{Void}[0]
    err = ccall((:git_repository_open, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Uint8}), repo_ptr, path)
    if err != api.GIT_OK
        if repo_ptr[1] != C_NULL
            ccall((:git_repository_free, :libgit2), Void,
                  (Ptr{Void},), repo_ptr[1])
        end
        throw(LibGitError(err))
    end
    repo = GitRepo(repo_ptr[1])
    if !isempty(alternates)
        odb = Odb(repo)
        for path in alternates
            if !isdir(path)
                throw(ArgumentError("alternate $path is not a valid directory"))
            end
            @check ccall((:git_odb_add_disk_alternate, :libgit2), Cint,
                         (Ptr{Void}, Ptr{Uint8}), odb, path)
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
        return api.GIT_OK
    catch err
        return api.ERROR
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
    if err == api.ENOTFOUND
        return false
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    return true
end
exists(r::GitRepo, id::Oid) = id in r 

function is_bare(r::GitRepo)
    return bool(ccall((:git_repository_is_bare, :libgit2), Cint, (Ptr{Void},), r))
end

#TODO: this is a function in base isempty
function is_empty(r::GitRepo)
    return bool(ccall((:git_repository_is_empty, :libgit2), Cint, (Ptr{Void},), r))
end

function is_shallow(r::GitRepo)
    return bool(ccall((:git_repository_is_shallow, :libgit2), Cint, (Ptr{Void},), r))
end

function repo_workdir(r::GitRepo)
    dir = ccall((:git_repository_workdir, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    if dir == C_NULL
        return nothing
    end
    # remove trailing slash
    return bytestring(dir)[1:end-1]
end

function path(r::GitRepo)
    cpath = ccall((:git_repository_path, :libgit2), Ptr{Uint8}, (Ptr{Void},), r)
    if cpath == C_NULL
        return nothing
    end
    # remove trailing slash
    return bytestring(cpath)[1:end-1]
end

function hash_data{T<:GitObject}(::Type{T}, content::String)
    id = Oid()
    @check ccall((:git_odb_hash, :libgit2), Cint,
                 (Ptr{Oid}, Ptr{Uint8}, Csize_t, Cint),
                 &id, content, length(content), git_otype(T))
    return id
end

#=
function hash_data{T<:GitObject}(::Type{T}, content::String)
    out = Oid()
    bcontent = bytestring(content)
    @check api.git_odb_hash(out.oid, bcontent, length(bcontent), git_otype(T))
    return out
end
=#

#TODO: remove this
function default_signature(r::GitRepo)
    sig_ptr = Array(Ptr{api.GitSignature}, 1)
    err = api.git_signature_default(sig_ptr, r.ptr)
    if err == api.ENOTFOUND
        return nothing
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    gsig = unsafe_load(sig_ptr[1])
    sig = Signature(gsig)
    api.free!(gsig)
    return sig
end

function is_head_detached(r::GitRepo)
    return bool(ccall((:git_repository_head_detached, :libgit2), Cint, (Ptr{Void},), r))
end

function repo_init(path::String; bare::Bool=false)
    repo_ptr = Ptr{Void}[0]
    err = ccall((:git_repository_init, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Uint8}, Cint), repo_ptr, path, bare? 1 : 0)
    if err != api.GIT_OK
        if repo_ptr[1] != C_NULL
            ccall((:git_repository_free, :libgit2), Void, (Ptr{Void},), repo_ptr[1])
        end
        throw(LibGitError(err))
    end
    return GitRepo(repo_ptr[1])
end
#=
function repo_init(path::String; bare::Bool=false)
    bpath = bytestring(path)
    repo_ptr = Array(Ptr{Void}, 1)
    err_code = api.git_repository_init(repo_ptr, bpath, bare? 1 : 0)
    if err_code < 0
        if repo_ptr[1] != C_NULL
            api.git_repository_free(repo_ptr[1])
        end
        throw(LibGitError(err_code))
    end
    return GitRepo(repo_ptr[1])
end
=#

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
    if ns_ptr == C_NULL
        return nothing
    end
    return bytestring(ns_ptr)
end

function head(r::GitRepo)
    head_ptr = Ptr{Void}[0]
    err = ccall((:git_repository_head, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}), head_ptr, r)
    if err == api.ENOTFOUND || err == api.EUNBORNBRANCH
        return nothing
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end 
    return GitReference(head_ptr[1])
end

Oid(r::GitRepo, val::GitObject) = Oid(val)
Oid(r::GitRepo, val::Oid) = val

function Oid(r::GitRepo, val::String)
    if length(val) == api.OID_HEXSZ
        try
            return Oid(val)
        end
    end
    return Oid(rev_parse(r, val))
end

#TODO: need to add tests for sig/logmsg
#TODO: get rid of api.GitSignature
function set_head!(r::GitRepo, ref::String; sig=nothing, logmsg=nothing)
    bref = bytestring(ref)
    bmsg = logmsg != nothing ? bytestring(logmsg) : C_NULL
    if sig == nothing
        @check ccall((:git_repository_set_head, :libgit2), Cint,
                     (Ptr{Void}, Ptr{Uint8}, Ptr{api.SignatureStruct}, Ptr{Uint8}),
                     r, bref, C_NULL, bmsg)
    else
        @assert isa(sig, Signature)
        gsig = git_signature(sig)
        @check ccall((:git_repository_set_head, api.libgit2), Cint,
                     (Ptr{Void}, Ptr{Uint8}, Ptr{api.GitSignature}, Ptr{Uint8}),
                     r, bref, &gsig, bmsg)
    end
    return r
end

#TODO: this needs to be implemented
function commits(r::GitRepo)
    return nothing 
end

function remotes(r::GitRepo)
    rs = StrArrayStruct()
    @check ccall((:git_remote_list, api.libgit2), Cint, (Ptr{StrArrayStruct}, Ptr{Void}), &rs, r)
    if rs.count == 0 
        return nothing 
    end
    remote_ptr = Ptr{Void}[0]
    out = Array(GitRemote, rs.count)
    for i in 1:rs.count 
        rstr = bytestring(unsafe_load(rs.strings, i))
        @check ccall((:git_remote_load, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), remote_ptr, r, rstr)
        out[i] = GitRemote(remote_ptr[1])
    end
    return out
end

function remote_names(r::GitRepo)
    rs = StrArrayStruct()
    @check ccall((:git_remote_list, api.libgit2), Cint,
                  (Ptr{StrArrayStruct}, Ptr{Void}), &rs, r)
    ns = Array(UTF8String, rs.count)
    for i in 1:rs.count
        ns[i] = utf8(bytestring(unsafe_load(rs.strings, i)))
    end
    return ns
end

function remote_add!(r::GitRepo, name::String, url::String)
    @assert r.ptr != C_NULL
    check_valid_url(url)
    remote_ptr = Array(Ptr{Void}, 1)
    @check api.git_remote_create(remote_ptr, r.ptr, bytestring(name), bytestring(url))
    return GitRemote(remote_ptr[1])
end

function cb_push_status(ref_ptr::Ptr{Uint8}, msg_ptr::Ptr{Uint8}, payload::Ptr{Void})
    if msg_ptr != C_NULL 
        result = unsafe_pointer_to_objref(payload)::Dict{UTF8String,UTF8String}
        result[utf8(bytestring(ref_ptr))] = utf8(bytestring(msg_ptr))
    end
    return api.GIT_OK
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
    if err != api.GIT_OK
        if p != C_NULL
            ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        end
        throw(LibGitError(err))
    end
    @assert p != C_NULL
    for ref in refs
        err = ccall((:git_push_add_refspec, :libgit2), Cint, (Ptr{Void}, Ptr{Uint8}), p, ref)
    end
    if err != api.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        throw(LibGitError(err))
    end
    err = ccall((:git_push_finish, :libgit2), Cint, (Ptr{Void},), p)
    if err != api.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        if err == api.ENONFASTFORWARD
            error("non-fast-forward upate rejected")
        #TODO: error constant
        elseif err == -8
            error("could not push to repo (check for non-bare repo)")
        end
    end
    err = ccall((:git_push_unpack_ok, :libgit2), Cint, (Ptr{Void},), p)
    if err == api.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        error("remote side did not unpack successfully")
    end
    result = (UTF8String=>UTF8String)[]
    err = ccall((:git_push_status_foreach, :libgit2), Cint,
                (Ptr{Void}, Ptr{Void}, Any), p, c_cb_push_status, &result)
    if err != api.GIT_OK
        ccall((:git_push_free, :libgit2), Void, (Ptr{Void},), p)
        throw(LibGitError(err))
    end
    err = ccall((:git_push_update_tips, :libgit2), Cint,
                (Ptr{Void}, Ptr{api.GitSignature}, Ptr{Uint8}), p, C_NULL, C_NULL)
    if err != api.GIT_OK
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
    remote_ptr =  Ptr{Void}[0]
    err = ccall((:git_remote_load, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), remote_ptr, r, remote_name)
    if err == api.ENOTFOUND
        return nothing
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    return GitRemote(remote_ptr[1])
end

lookup_remote(r::GitRepo, remote_name::String) = lookup(GitRemote, r, remote_name)
lookup_tag(r::GitRepo, id::Oid) = lookup(GitTag, r, id)

function tags(r::GitRepo, glob::String="")
    gittags = StrArrayStruct()
    @check ccall((:git_tag_list_match, :libgit2), Cint,
                 (Ptr{StrArrayStruct}, Ptr{Uint8}, Ptr{Void}), &gittags, glob, r)
    if gittags.count == 0
        return nothing
    end
    out = Array(UTF8String, gittags.count)
    for i in 1:gittags.count
        out[i] = utf8(bytestring(unsafe_load(gittags.strings, i)))
    end
    return out
end

function tag!(r::GitRepo;
              name::String="",
              message::String="",
              target::Union(Nothing,Oid)=nothing,
              tagger::Union(Nothing,Signature)=nothing,
              force::Bool=false)
   tid = Oid()
   #TODO: this is not correct
   target != nothing && (obj = lookup(r, target))
   if !isempty(message)
       gsig = tagger != nothing ? git_signature(tagger) :
                                  git_signature(default_signature(r))

       @check ccall((:git_tag_create, :libgit2), Cint,
                    (Ptr{Oid}, Ptr{Void}, Ptr{Uint8},
                     Ptr{Void}, Ptr{api.GitSignature}, Ptr{Uint8}, Cint),
                     &tid, r.ptr, name, obj, &gsig, message, force? 1:0)
   else
       @check ccall((:git_tag_create_lightweight, :libgit2), Cint,
                    (Ptr{Oid}, Ptr{Void}, Ptr{Uint8}, Ptr{Void}, Cint),
                    &tid, r, name, obj, force? 1:0)
   end
   return tid
end

function create_note!(
               obj::GitObject, msg::String; 
               committer::Union(Nothing, Signature)=nothing,
               author::Union(Nothing, Signature)=nothing,
               ref::Union(Nothing, String)=nothing,
               force::Bool=false)
    repo_ptr  = ccall((:git_object_owner, :libgit2), Ptr{Void}, (Ptr{Void},), obj)
    target_id = Oid(obj)
    bref = ref != nothing ? bytestring(ref) : convert(Ptr{Uint8}, C_NULL)
    local committer_ptr::Ptr{api.GitSignature}
    if committer != nothing
        committer_ptr = git_signature_ptr(committer)
    else
        # gcommitter = git_signature(default_signature(repo))
        sig_ptr = Ptr{api.GitSignature}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{api.GitSignature}}, Ptr{Void}), sig_ptr, repo_ptr)
        committer_ptr = sig_ptr[1]
 
    end
    local author_ptr::Ptr{api.GitSignature}
    if author != nothing
        author_ptr = git_signature_ptr(author)
    else
        #TODO: we can avoid having to lookup the default signature twice
        # gauthor = git_signature(default_signature(repo))
        sig_ptr = Ptr{api.GitSignature}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{api.GitSignature}}, Ptr{Void}), sig_ptr, repo_ptr)
        author_ptr = sig_ptr[1]
    end
    note_id = Oid()
    @check ccall((:git_note_create, :libgit2), Cint,
                 (Ptr{Uint8}, Ptr{Void}, Ptr{api.GitSignature},
                  Ptr{api.GitSignature}, Ptr{Cchar}, Ptr{Uint8},
                  Ptr{Cchar}, Cint),
                 &note_id, repo_ptr, committer_ptr, author_ptr,
                 bref, &tid, bytestring(msg), force? 1:0)
    return note_id
end

function remove_note!(obj::GitObject;
                      committer::Union(Nothing,Signature)=nothing,
                      author::Union(Nothing,Signature)=nothing,
                      ref::Union(Nothing,String)=nothing)
    target_id = Oid(obj)
    repo_ptr  = ccall((:git_object_owner, :libgit2), Ptr{Void}, (Ptr{Void},), obj)
    notes_ref = ref != nothing ? bytestring(ref) : bytestring("refs/notes/commits")
    local committer_ptr::Ptr{api.GitSignature}
    if committer != nothing
        committer_ptr = git_signature_ptr(committer)
    else
        sig_ptr = Ptr{api.GitSignature}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{api.GitSignature}}, Ptr{Void}), sig_ptr, repo_ptr)
        committer_ptr = sig_ptr[1]
        #gcommitter = git_signature(default_signature(repo))
    end
    local author_ptr::Ptr{api.GitSignature}
    if author != nothing
        author_ptr = git_signature_ptr(author)
    else
        #gauthor = git_signature(default_signature(repo))
        sig_ptr = Ptr{api.GitSignature}[0]
        @check ccall((:git_signature_default, :libgit2), Cint,
                     (Ptr{Ptr{api.GitSignature}}, Ptr{Void}), sig_ptr, repo_ptr)
        author_ptr = sig_ptr[1]
    end 
    err = ccall((:git_note_remove, :libgit2), Cint,
                (Ptr{Void}, Ptr{Cchar}, 
                 Ptr{api.GitSignature}, Ptr{api.GitSignature}, Ptr{Oid}),
                 repo_ptr, notes_ref, author_ptr, committer_ptr, &target_id)
    if err == api.ENOTFOUND
        return false
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    return true
end

function note_default_ref(r::GitRepo)
    refname_ptr = Ptr{Void}[0]
    @check ccall((:git_note_default_ref, :libgit2), Cint, 
                 (Ptr{Ptr{Void}}, Ptr{Void}), refname_ptr, r)
    return bytestring(refname_ptr[1])
end

function cb_iter_notes(blob_id::Ptr{Oid}, ann_obj_id::Ptr{Oid}, repo_ptr::Ptr{Void})
    ann_obj_ptr = Ptr{Void}[0]
    blob_ptr    = Ptr{Void}[0]
    err = ccall((:git_object_lookup, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                ann_obj_ptr, repo_ptr, ann_obj_id, api.OBJ_BLOB)
    err |= ccall((:git_object_lookup, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                 blob_ptr, repo_ptr, blob_id, api.OBJ_BLOB)
    if err == api.GIT_OK
        res = (gitobj_from_ptr(ann_obj_id[1]), gitobj_from_ptr(blob_ptr[1]))
        produce(res)
    end
    return err
end

const c_cb_iter_notes = cfunction(cb_iter_notes, Cint, (Ptr{Oid}, Ptr{Oid}, Ptr{Void}))

function iter_notes(r::GitRepo, notes_ref::Union(Nothing, String)=nothing)
    bnotes_ref = ref != nothing ? bytestring(notes_ref) : C_NULL
    return @task ccall((:git_note_foreach, :libgit2), Cint, 
                       (Ptr{Void}, Ptr{Uint8}, Ptr{Void}, Ptr{Void}),
                       r, notes_ref, c_cb_iter_notes, r)
end

function ahead_behind(r::GitRepo, lcommit::GitCommit, ucommit::GitCommit)
    return ahead_behind(r, Oid(lcommit), Oid(ucommit))
end

function ahead_behind(r::GitRepo, lid::Oid, uid::Oid)
    ahead, behind  = Csize_t[0], Csize_t[0]
    @check ccall((:git_graph_ahead_behind, :libgit2), Cint,
                 (Ptr{Csize_t}, Ptr{Csize_t}, Ptr{Void}, Ptr{Oid}, Ptr{Oid}),
                 ahead, behind, r, &lid, &uid)
    return (int(ahead[1]), int(behind[1]))
end

function blob_at(r::GitRepo, rev::Oid, p::String)
    tree = GitTree(lookup_commit(r, rev))
    local blob_entry::GitTreeEntry
    try
        blob_entry = GitTreeEntry(tree, p)
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
    gty = git_otype(T)
    stream_ptr = Ptr{Void}[0]
    @check ccall((:git_odb_open_wstream, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Csize_t, Cint),
                 stream_ptr, odb, length(buf), gty)
    err = ccall((:git_odb_stream_write, :libgit2), Cint,
                (Ptr{Void}, Ptr{Uint8}, Csize_t), stream_ptr[1], buf, length(buf))
    out = Oid()
    if err == api.GIT_OK
        err = ccall((:git_odb_stream_finalize_write, :libgit2), Cint,
                    (Ptr{Oid}, Ptr{Void}), &out, stream_ptr[1])
    end
    ccall((:git_odb_stream_free, :libgit2), Void, (Ptr{Void},), stream_ptr[1])
    if err != api.GIT_OK
        throw(LibGitError(err))
    end
    return out
end

#TODO: implement
function references(r::GitRepo)
    return nothing
end

function repo_discover(p::String="", acrossfs::Bool=true)
    if isempty(p); p = pwd(); end
    brepo = Array(Uint8, api.GIT_PATH_MAX)
    bp = bytestring(p)
    buf = api.GitBuffer()
    @check ccall((:git_repository_discover, :libgit2), Cint,
                 (Ptr{api.GitBuffer}, Ptr{Uint8}, Cint, Ptr{Uint8}),
                  &buf, bp, acrossfs? 1 : 0, C_NULL)
    return GitRepo(bytestring(buf.ptr))
end

function rev_parse(r::GitRepo, rev::String)
    odj_ptr = Ptr{Void}[0]
    @check ccall((:git_revparse_single, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), obj_ptr, r, brev)
    return gitobj_from_ptr(obj_ptr[1])
end
rev_parse(r::GitRepo, rev::Oid) = rev_parse(r, string(rev))

function merge_base(r::GitRepo, args...)
    if length(args) < 2
        throw(ArgumentError("merge_base needs 2+ commits"))
    end
    arg_oids = vcat([raw(Oid(r, a)) for a in args]...)
    @assert length(arg_oids) == length(args) * api.OID_RAWSZ
    len = convert(Csize_t, length(args))
    id = Oid()
    err = ccall((:git_merge_base_many, :libgit2), Cint, 
                (Ptr{Oid}, Ptr{Void}, Csize_t, Ptr{Uint8}), &id, r, len, arg_oids)
    if err == api.ENOTFOUND
        return nothing
    elseif err != api.GIT_OK
        throw(LibGitError(err))
    end
    return id
end
#TODO: this could be more efficient
rev_parse_oid(r::GitRepo, rev::Oid) = Oid(rev_parse(r, string(rev)))
rev_parse_oid(r::GitRepo, rev::String) = Oid(rev_parse(r, rev))

function config(r::GitRepo)
    cfg_ptr = Ptr{Void}[0]
    @check ccall((:git_repository_config, :libgit2), Cint, 
                 (Ptr{Ptr{Void}}, Ptr{Void}), cfg_ptr, r)
    return GitConfig(config_ptr[1])
end

Odb(r::GitRepo) = begin
    odb_ptr = Ptr{Void}[0]
    @check ccall((:git_repository_odb, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), odb_ptr, r)
    return Odb(odb_ptr[1])
end

#TODO: remove
repo_odb(r::GitRepo) = Odb(r)

#TODO: remove
function repo_index(r::GitRepo)
    idx_ptr = Ptr{Void}[0]
    @check ccall((:git_repository_index, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}), idx_ptr, r)
    return GitIndex(idx_ptr[1])
end

function lookup{T<:GitObject}(::Type{T}, r::GitRepo, id::Oid)
    obj_ptr = Ptr{Void}[0]
    @check ccall((:git_object_lookup, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                 objptr, r, &id, git_otype(T))
    return T(objptr[1])
end

function lookup{T<:GitObject}(::Type{T}, r::GitRepo, id::String)
    oid = Oid()
    len = length(bid)
    obj_ptr = Ptr{Void}[0]
    @check ccall((:git_oid_fromstrn, api.libgit2), Cint,
                 (Ptr{Oid}, Ptr{Uint8}, Csize_t), &oid, id, len) 
    if len < OID_HEXSZ
        @check ccall((:git_object_lookup_prefix, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Csize_t, Cint),
                     obj_ptr, r, &oid, len, git_otype(T))
    else
        @check ccall((:git_object_lookup, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Oid}, Cint),
                     obj_ptr, r, &oid, git_otype(T)) 
    end
    return T(objptr[1]) 
end

lookup(r::GitRepo, id::Oid) = lookup(GitAnyObject, r, id)
lookup_tree(r::GitRepo, id) = lookup(GitTree, r, id)
lookup_blob(r::GitRepo, id) = lookup(GitBlob, r, id)
lookup_commit(r::GitRepo, id) = lookup(GitCommit, r, id)

function lookup_ref(r::GitRepo, refname::String)
    ref_ptr = Ptr{Void}[0]
    err = ccall((:git_reference_lookup, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}), ref_ptr, r, refname)
    if err == api.ENOTFOUND
        return nothing
    elseif err != api.GIT_OK
        return LibGitError(err)
    end
    return GitReference(ref_ptr[1])
end

function create_ref(r::GitRepo, refname::String, id::Oid; 
                    force::Bool=false, sig=nothing, msg=nothing)
    bname = bytestring(refname)
    bmsg  = msg != nothing ? bytestring(msg) : C_NULL
    ref_ptr = Ptr{Void}[0]
    if sig != nothing
        @assert isa(sig, Signature)
        gsig = git_signature(sig)
        @check ccall((:git_reference_create, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8},
                      Cint, Ptr{api.GitSignature}, Ptr{Uint8}),
                      ref_ptr, r, bname, &id, force? 1:0, &gsig, bmsg)
    else
        @check ccall((:git_reference_create, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8},
                      Cint, Ptr{api.GitSignature}, Ptr{Uint8}),
                      ref_ptr, r, bname, &id, force? 1:0, C_NULL, bmsg)
    end
    return GitReference(ref_ptr[1])
end

function create_ref(r::GitRepo, refname::String, target::String; 
                    force::Bool=false, sig=nothing, logmsg=nothing)
    create_sym_ref(r, refname, target; force=force, sig=sig, logmsg=logmsg)
end

function create_sym_ref(r::GitRepo, refname::String, target::String; 
                        force::Bool=false, sig=sig, logmsg=logmsg)
    bname   = bytestring(refname)
    btarget = bytestring(target)
    bmsg    = logmsg != nothing ? bytestring(logmsg) : C_NULL
    ref_ptr = Ptr{Void}[0]
    if sig != nothing
        @assert isa(sig, Signature)
        gsig = git_signature(sig)
        @check ccall((:git_reference_symbolic_create, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Uint8},
                      Cint, Ptr{api.GitSignature}, Ptr{Uint8}),
                      ref_ptr, r, bname, btarget, force? 1:0, &gsig, bmsg)
    else
        @check ccall((:git_reference_symbolic_create, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Cchar}, Ptr{Uint8},
                      Cint, Ptr{api.GitSignature}, Ptr{Uint8}),
                      ref_ptr, r, bname, btarget, force? 1:0, C_NULL, bmsg)
    end
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
    cid  = Oid()
    nparents   = length(parents)
    parentptrs = Ptr{Void}[c.ptr for c in parents]
    gauthor    = git_signature(author)
    gcommitter = git_signature(committer)
    #TODO: encoding?
    @check ccall((:git_commit_create, :libgit2), Cint,
                 (Ptr{Oid}, Ptr{Void}, Ptr{Uint8},
                  Ptr{api.GitSignature}, Ptr{api.GitSignature}, 
                  Ptr{Uint8}, Ptr{Uint8}, Ptr{Void},
                  Csize_t, Ptr{Ptr{Void}}),
                 &cid, r, refname,
                 &gauthor, &gcommitter,
                 C_NULL, msg, tree, 
                 nparents, nparents > 0 ? parentptrs : C_NULL)
    return cid
end

function repo_set_workdir(r::GitRepo, dir::String, update::Bool)
end

# filter can be :all, :local, :remote
function branch_names(r::GitRepo, filter::Symbol=:all)
    local git_filter::Cint 
    if filter == :all
        git_filter = api.BRANCH_LOCAL | api.BRANCH_REMOTE
    elseif filter == :local
        git_filter = api.BRANCH_LOCAL
    elseif filter == :remote
        git_filter = api.BRANCH_REMOTE
    else
        throw(ArgumentError("filter can be :all, :local, or :remote"))
    end
    iter_ptr = Ptr{Void}[0]
    @check ccall((:git_branch_iterator_new, :libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Cint), iter_ptr, r, git_filter)
    branch_ptr  = Ptr{Void}[0]
    branch_type = Cint[0] 
    names = UTF8String[]
    while true
        err = ccall((:git_branch_next, :libgit2), Cint,
                    (Ptr{Ptr{Void}}, Ptr{Cint}, Ptr{Void}), branch_ptr, branch_type, iter_ptr[1])
        if err == api.ITEROVER
            break
        end
        if err != api.GIT_OK
            if iter_ptr[1] != C_NULL
                ccall((:git_branch_iterator_free, :libgit2), Void, (Ptr{Void},), iter_ptr[1])
            end
            throw(LibGitError(err))
        end
        name_ptr = ccall((:git_reference_shorthand, :libgit2), Ptr{Uint8}, (Ptr{Void},), branch_ptr[1])
        push!(names, utf8(bytestring(name_ptr)))
    end
    ccall((:git_branch_free, :libgit2), Void, (Ptr{Void},), iter_ptr[1])
    return names
end

# branch type can be :local or :remote
function lookup(::Type{GitBranch}, r::GitRepo, branch_name::String, branch_type::Symbol=:local)
    local git_branch_type::Cint
    if branch_type == :local
        git_branch_type = api.BRANCH_LOCAL
    elseif branch_type == :remote 
        git_branch_type = api.BRANCH_REMOTE
    else
        throw(ArgumentError("branch_type can be :local or :remote"))
    end
    branch_ptr = Ptr{Void}[0]
    err = ccall((:git_branch_lookup, :libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Cint), branch_ptr, r, branch_name, git_branch_type)
    if err == api.GIT_OK
        return GitBranch(branch_ptr[1])
    elseif err == api.ENOTFOUND
        return nothing
    else
        throw(LibGitError(err))
    end
end

lookup_branch(r::GitRepo, branch_name::String, branch_type=:local) = 
        lookup(GitBranch, r, branch_name, branch_type)

lookup_branch(r::Repository, branch_id::Oid, branch_type=:local) = 
        lookup(GitBranch, r, string(branch_id), branch_type)


function create_branch(r::GitRepo, n::String, target::Oid;
                       force::Bool=false, sig=nothing, logmsg=nothing)
    #TODO: give intelligent error msg when target
    # does not exist
    c = lookup_commit(r, target)
    bmsg = logmsg != nothing ? bytestring(logmsg) : C_NULL
    branch_ptr = Ptr{Void}[0]
    if sig != nothing
        @assert(isa(sig, Signature))
        gsig = git_signature(sig)
        @check ccall((:git_branch_create, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Void},
                      Cint, Ptr{api.GitSignature}, Ptr{Uint8}),
                     branch_ptr, r.ptr, bytestring(n), c.ptr, force? 1:0, &gsig, bmsg)
    else
        @check ccall((:git_branch_create, :libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Uint8}, Ptr{Void},
                      Cint, Ptr{api.GitSignature}, Ptr{Uint8}),
                     branch_ptr, r.ptr, bytestring(n), c.ptr, force? 1:0, C_NULL, bmsg)
    end
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
    ptr::Ptr{Void}
    repo::GitRepo

    function BranchIterator(ptr::Ptr{Void}, r::GitRepo)
        @assert ptr != C_NULL
        bi = new(ptr, r)
        finalizer(bi, free!)
        return bi
    end
end

free!(b::BranchIterator) = begin
    if b.ptr != C_NULL
        api.git_branch_iterator_free(b.ptr)
        b.ptr = C_NULL
    end
end

function iter_branches(r::GitRepo, filter=:all)
    @assert r.ptr != C_NULL
    local git_filter::Cint
    if filter == :all
        git_filter = api.BRANCH_LOCAL | api.BRANCH_REMOTE
    elseif filter == :local
        git_filter = api.BRANCH_LOCAL
    elseif filter == :remote
        git_filter == api.BRANCH_REMOTE
    else
        throw(ArgumentError("filter can be :all, :local, or :remote"))
    end 
    iter_ptr = Array(Ptr{Void}, 1)
    @check api.git_branch_iterator_new(iter_ptr, r.ptr, git_filter)
    return BranchIterator(iter_ptr[1], r)
end

Base.start(b::BranchIterator) = begin
    @assert b != C_NULL
    branch_ptr = Array(Ptr{Void}, 1)
    btype_ptr  = Array(Cint, 1)
    ret = api.git_branch_next(branch_ptr, btype_ptr, b.ptr)
    if ret == api.ITEROVER
        return nothing
    elseif ret != api.GIT_OK
        throw(LibGitError(ret))
    end
    return GitBranch(branch_ptr[1])
end

Base.done(b::BranchIterator, state) = begin
    state == nothing
end

Base.next(b::BranchIterator, state) = begin
    @assert b.ptr != C_NULL
    branch_ptr = Array(Ptr{Void}, 1)
    btype_ptr  = Array(Cint, 1)
    ret = api.git_branch_next(branch_ptr, btype_ptr, b.ptr)
    if ret == api.ITEROVER
        return (state, nothing)
    elseif ret != api.GIT_OK
        throw(LibGitError(ret))
    end
    return (state, GitBranch(branch_ptr[1]))
end

#------- Tree merge ---------
function parse_merge_options(opts::Nothing)
    return api.GitMergeTreeOpts()
end

function parse_merge_options(opts::Dict)
    merge_opts = api.GitMergeTreeOpts()
    if isempty(opts)
        return merge_opts
    end
    if haskey(opts, :rename_threshold)
        merge_opts.rename_threshold = convert(Cuint, opts[:rename_threshold])
    end
    if haskey(opts, :target_limit)
        merge_opts.target_limit = convert(Cuint, opts[:target_limit])
    end
    if haskey(opts, :automerge)
        a = opts[:automerge]
        if a == :normal
            merge_opts.flags = api.MERGE_AUTOMERGE_NORMAL
        elseif a == :none
            merge_opts.flags = api.MERGE_AUTOMERGE_NONE
        elseif a == :favor_ours
            merge_opts.flags = api.MERGE_AUTOMERGE_FAVOR_OURS
        elseif a == :favor_theirs
            merge_opts.flags = api.MERGE_AUTOMERGE_FAVOR_THEIRS
        else
            error("Unknown automerge option :$a")
        end
    end
    if get(opts, :renames, false)
        merge_opts.flags |= MERGE_TREE_FIND_RENAMES
    end
    return merge_opts
end

#TODO: tree's should reference owning repository
Base.merge!(r::GitRepo, t1::GitTree, t2::GitTree, opts=nothing) = begin
    @assert r.ptr != C_NULL t1.ptr != C_NULL && t2.ptr != C_NULL 
    gopts = parse_merge_options(opts)
    idx_ptr = Array(Ptr{Void}, 1)
    @check ccall((:git_merge_trees, api.libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{api.GitMergeTreeOpts}),
                 idx_ptr, r.ptr, C_NULL, t1.ptr, t2.ptr, &gopts)
    return GitIndex(idx_ptr[1])
end

Base.merge!(r::GitRepo, t1::GitTree, t2::GitTree, ancestor::GitTree, opts=nothing) = begin
    @assert r.ptr != C_NULL t1.ptr != C_NULL && t2.ptr != C_NULL && ancestor.ptr != C_NULL
    gopts = parse_merge_options(opts)
    idx_ptr = Array(Ptr{Void}, 1)
    @check ccall((:git_merge_trees, api.libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{Void}, Ptr{api.GitMergeTreeOpts}),
                 idx_ptr, r.ptr, ancestor.ptr, t1.ptr, t2.ptr, &gopts)
    return GitIndex(idx_ptr[1])
end

#------- Merge Commits -----
function merge_commits(r::GitRepo, 
                       ours::Union(GitCommit, Oid), 
                       theirs::Union(GitCommit, Oid), 
                       opts=nothing)
    @assert r.ptr != C_NULL && ours.ptr != C_NULL && theirs.ptr != C_NULL
    gopts = parse_merge_options(opts)
    if isa(ours, Oid)
        ours = lookup_commit(r, ours)
    end
    if isa(theirs, Oid)
        theirs = lookup_commit(r, theirs)
    end
    index_ptr = Array(Ptr{Void}, 1)
    @check ccall((:git_merge_commits, api.libgit2), Cint,
                 (Ptr{Ptr{Void}}, Ptr{Void}, Ptr{Void},
                  Ptr{Void}, Ptr{api.GitMergeTreeOpts}),
                  index_ptr, r.ptr, ours.ptr, theirs.ptr, &gopts)
    return GitIndex(index_ptr[1])
end

#------- Repo Checkout -------
function cb_checkout_progress(path_ptr::Ptr{Cchar}, 
                              completed_steps::Csize_t,
                              total_steps::Csize_t,
                              payload::Ptr{Void})
    callback = unsafe_pointer_to_objref(payload)::Function
    path = path_ptr != C_NULL ? bytestring(path_ptr) : nothing
    callback(path, completed_steps, total_steps)
    return
end

const c_cb_checkout_progress = cfunction(cb_checkout_progress, Void,
                                         (Ptr{Cchar}, Csize_t, Csize_t, Ptr{Void}))

function cb_checkout_notify(why::Cint, 
                            path_ptr::Ptr{Cchar}, 
                            baseline::Ptr{api.GitDiffFile}, 
                            target::Ptr{api.GitDiffFile},
                            workdir::Ptr{api.GitDiffFile},
                            payload::Ptr{Void})
    callback = unsafe_pointer_to_objref(payload)::Function
    path = path_ptr != C_NULL ? bytestring(path_ptr) : nothing
    local reason::Symbol
    if why == api.CHECKOUT_NOTIFY_CONFLICT
        reason = :conflict
    elseif why == api.CHECKOUT_NOTIFY_DIRTY
        reason = :dirty
    elseif why == api.CHECKOUT_NOTIFY_UPDATED
        reason = :updated
    elseif why == api.CHECKOUT_NOTIFY_UNTRACKED
        reason = :untracked
    elseif why == api.CHECKOUT_NOTIFY_IGNORED
        reason = :ignored
    else
        reason = :unknown
    end
    try
        callback(why, path, 
                 DiffFile(baseline),
                 DiffFile(target), 
                 DiffFile(workdir))
        return api.GIT_OK
    catch
        return api.ERROR
    end
end

const c_cb_checkout_notify = cfunction(cb_checkout_notify, Cint,
                                       (Cint,
                                        Ptr{Cchar}, 
                                        Ptr{api.GitDiffFile}, 
                                        Ptr{api.GitDiffFile}, 
                                        Ptr{api.GitDiffFile},
                                        Ptr{Void}))

function parse_checkout_options(opts::Nothing)
    return api.GitCheckoutOpts()
end

function parse_checkout_options(opts::Dict)
    gopts = api.GitCheckoutOpts()
    if isempty(opts)
        return gopts
    end
    if haskey(opts, :progress)
        if !isa(opts[:progress], Function)
            throw(ArgumentError("opts[:progress] must be a Function object"))
        end
        gopts.progress_payload = pointer_from_objref(opts[:progress])
        gopts.progress_cb = c_cb_checkout_progress
    end
    if haskey(opts, :notify)
        if !isa(opts[:notify], Function)
            throw(ArgumentError("opts[:notify] must be a Function object"))
        end
        gopts.notify_payload = pointer_from_objref(opts[:notify])
        gopts.notify_cb = c_cb_checkout_notify
    end
    if haskey(opts, :strategy)
        local strategy::Vector{Symbol}
        if isa(opts[:strategy], Symbol)
            strategy = [opts[:strategy]]
        else
            strategy = opts[:strategy]
        end
        for s in strategy
            if s == :safe
                gopts.checkout_strategy |= api.CHECKOUT_SAFE
            elseif s == :safe_create
                gopts.checkout_strategy |= api.CHECKOUT_SAFE_CREATE
            elseif s == :force
                gopts.checkout_strategy |= api.CHECKOUT_FORCE
            elseif s == :allow_conflicts
                gopts.checkout_strategy |= api.CHECKOUT_ALLOW_CONFLICTS
            elseif s == :remove_untracked
                gopts.checkout_strategy |= api.CHECKOUT_REMOVE_UNTRACKED
            elseif s == :remove_ignored
                gopts.checkout_strategy |= api.CHECKOUT_REMOVE_IGNORED
            elseif s == :update_only
                gopts.checkout_strategy |= api.CHECKOUT_UPDATE_ONLY
            elseif s == :dont_update_index
                gopts.checkout_strategy |= api.CHECKOUT_DONT_UPDATE_INDEX
            elseif s == :no_refresh
                gopts.checkout_strategy |= api.CHECKOUT_NO_REFRESH
            elseif s == :disable_pathspec_match
                gopts.checkout_strategy |= api.CHECKOUT_DISABLE_PATHSPEC_MATCH
            elseif s == :skip_locked_directories
                gopts.checkout_strategy |= api.CHECKOUT_SKIP_LOCKED_DIRECTORIES
            elseif s == :skip_unmerged
                gopts.checkout_strategy |= api.CHECKOUT_SKIP_UNMERGED
            elseif s == :use_ours
                gopts.checkout_strategy |= api.CHECKOUT_USE_OURS
            elseif s == :use_theirs
                gopts.checkout_strategy |= api.CHECKOUT_USE_THEIRS
            elseif s == :update_submodules
                gopts.checkout_strategy |= api.CHECKOUT_UPDATE_SUBMODULES
            elseif s == :update_submodules_if_changed
                gopts.checkout_strategy |= api.CHECKOUT_UPDATE_SUBMODULES_IF_CHANGED
            else
                throw(ArgumentError("unknown checkout strategy flag :$s"))
            end
        end
    end

    if haskey(opts, :notify_flags)
        local flags::Vector{Symbol}
        if isa(opts[:notify_flags], Symbol)
            flags = [opts[:notify_flags]]
        else
            flags = opts[:notify_flags]
        end
        for f in flags
            if f == :conflict
                gopts.notify_flags |= api.CHECKOUT_NOTIFY_CONFLICT
            elseif f == :dirty
                gopts.notify_flags |= api.CHECKOUT_NOTIFY_DIRTY
            elseif f == :updated
                gopts.notify_flags |= api.CHECKOUT_NOTIFY_UPDATED
            elseif f == :untracked
                gopts.notify_flags |= api.CHECKOUT_NOTIFY_UNTRACKED
            elseif f == :ignored
                gopts.notify_flags |= api.CHECKOUT_NOTIFY_IGNORED
            elseif f == :all
                gopts.notify_flags |= api.CHECKOUT_NOTIFY_ALL
            else
                throw(ArgumentError("unknown checkout notify flag :$f"))
            end
        end
    end

    gopts.disable_filters = convert(Cint, get(opts, :disable_filters, false) ? 1 : 0)
    
    if haskey(opts, :dir_mode)
        gopts.dir_mode = convert(Cuint, opts[:dir_mode])
    end
    if haskey(opts, :file_mode)
        gopts.file_mode = convert(Cuint, opts[:file_mode])
    end
    if haskey(opts, :file_open_flags)
        gopts.file_open_flags = convert(Cint, opts[:file_open_flags])
    end
    if haskey(opts, :target_directory)
        gopts.target_directory = convert(Ptr{Cchar}, 
					 pointer(bytestring(opts[:target_directory])))
    end
    if haskey(opts, :baseline)
        if isa(opts[:baseline], GitTree)
            gopts.baseline = opts[:baseline].ptr
        else
            throw(ArgumentError("checkout options :baseline should be a GitTree"))
        end
    end
    if haskey(opts, :paths)
        paths = opts[:paths]
        if isa(paths, String)
            paths = [paths]
        end
        npaths = length(paths)
        cpaths = Array(Ptr{Cchar}, npaths)
        gopts.paths_count = convert(Csize_t, npaths)
        for i in 1:npaths
            cpaths[i] = convert(Ptr{Cchar}, pointer(paths[i]))
        end
        gopts.paths_strings = convert(Ptr{Ptr{Cchar}}, cpaths)
    end
    return gopts
end

typealias Treeish Union(GitCommit, GitTag, GitTree)

function checkout_tree!(r::GitRepo, tree::String, opts=nothing)
    t = rev_parse(r, tree)
    return checkout_tree!(r, t, opts)
end

function checkout_tree!(r::GitRepo, tree::Treeish, opts=nothing)
    gopts = parse_checkout_options(opts)
    err = ccall((:git_checkout_tree, api.libgit2), Cint,
                (Ptr{Void}, Ptr{Void}, Ptr{api.GitCheckoutOpts}),
                r.ptr, tree.ptr, &gopts)
    #TODO: memory leak with option strings
    if err != api.GIT_OK
        throw(LibGitError(err))
    end
    return r 
end

function checkout_head!(r::GitRepo, opts=nothing)
    @assert r.ptr != C_NULL
    gopts = parse_checkout_options(opts)
    err = ccall((:git_checkout_head, api.libgit2), Cint,
                (Ptr{Void}, Ptr{api.GitCheckoutOpts}),
                r.ptr, &gopts)
    #TODO: memory leak with option strings??, cleanup on exceptions, etc...
    if err != api.GIT_OK
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


#------- Repo Clone -------
abstract GitCredential

type CredDefault <: GitCredential end

type CredPlainText <: GitCredential
    username::String
    password::String
end

type CredSSHKey <: GitCredential
    username::Union(Nothing, String)
    publickey::Union(Nothing, String)
    privatekey::String
    passphrase::Union(Nothing, String)
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
        return api.GIT_OK
    catch err
        payload[:exception] = err
        return api.ERROR
    end
end

const c_cb_remote_transfer = cfunction(cb_remote_transfer, Cint,
                                       (Ptr{api.GitTransferProgress}, Ptr{Void}))

function extract_cred!(cred::GitCredential, cred_ptr::Ptr{Ptr{Void}}, allowed_types::Cuint)
    if isa(cred, CredPlainText)
        if !bool(allowed_types & api.CREDTYPE_USERPASS_PLAINTEXT)
            error("invalid credential type")
        end
        @check ccall((:git_cred_userpass_plaintext_new, api.libgit2), Cint,
                      (Ptr{Ptr{Void}}, Ptr{Cchar}, Ptr{Cchar}),
                       cred_ptr,
                       bytestring(cred.username),
                       bytestring(cred.password))
    elseif isa(cred, CredSSHKey)
        if !bool(allowed_types & api.CREDTYPE_SSH_KEY)
            error("invalid credential type")
        end
        @check ccall((:git_cred_ssh_key_new, api.libgit2), Cint,
                     (Ptr{Ptr{Void}}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}, Ptr{Cchar}),
                     cred_ptr,
                     cred.username != nothing ? cred.username : C_NULL,
                     cred.publickey != nothing ? cred.publickey : C_NULL,
                     cred.privatekey != nothing ? cred.privatekey : C_NULL,
                     cred.passphrase != nothing ? cred.passphrase : C_NULL)
    elseif (cred, CredDefault)
        if !bool(allowed_types & api.CREDTYPE_SSH_KEY)
            error("invalid credential type")
        end
        @check ccall((:git_cred_default_new, api.libgit2), Cint,
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
        return api.GIT_OK
    catch err
        payload[:exception] = err
        return api.ERROR
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
    if bool(allowed_types & api.CREDTYPE_USERPASS_PLAINTEXT)
        push!(types, :plaintext)
    end
    if bool(allowed_types & api.CREDTYPE_SSH_KEY)
        push!(types, :sshkey)
    end
    if bool(allowed_types & api.CREDTYPE_DEFAULT)
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
        return api.GIT_OK
    catch err
        payload[:exception] = err
        return api.ERROR
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
    repo_ptr = Array(Ptr{Void}, 1)
    err = ccall((:git_clone, api.libgit2), Cint,
                (Ptr{Ptr{Void}}, Ptr{Cchar}, Ptr{Cchar}, Ptr{api.GitCloneOpts}),
                 repo_ptr, bytestring(url), bytestring(path), &gopts)
    if err != api.GIT_OK
        payload = unsafe_pointer_to_objref(gopts.remote_payload)::Dict
        if haskey(payload, :exception)
            throw(payload[:exception])
        else
            throw(LibGitError(err))
        end
    end
    return GitRepo(repo_ptr[1])
end


#-------- Reference Iterator --------
#TODO: handle error's when iterating (see branch)
type ReferenceIterator
    ptr::Ptr{Void}
    repo::GitRepo

    function ReferenceIterator(ptr::Ptr{Void}, r::GitRepo)
        @assert ptr != C_NULL
        ri = new(ptr, r)
        finalizer(ri, free!)
        return ri
    end
end

free!(r::ReferenceIterator) = begin
    if r.ptr != C_NULL
        api.git_reference_iterator_free(r.ptr)
        r.ptr = C_NULL
    end
end

function ref_names(r::GitRepo, glob=nothing)
    rnames = String[]
    for r in iter_refs(r, glob)
        push!(rnames, name(r))
    end
    return rnames
end

function iter_refs(r::GitRepo, glob=nothing)
    @assert r.ptr != C_NULL
    iter_ptr = Array(Ptr{Void}, 1)
    if glob == nothing
        @check api.git_reference_iterator_new(iter_ptr, r.ptr)
    else
        bglob = bytestring(glob)
        @check api.git_reference_iterator_glob_new(iter_ptr, r.ptr, bglob)
    end
    return ReferenceIterator(iter_ptr[1], r)
end

Base.start(r::ReferenceIterator) = begin
    @assert r != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    ret = api.git_reference_next(ref_ptr, r.ptr)
    if ret == api.ITEROVER
        return nothing
    end
    return GitReference(ref_ptr[1])
end

Base.done(r::ReferenceIterator, state) = begin
    state == nothing
end

Base.next(r::ReferenceIterator, state) = begin
    @assert r.ptr != C_NULL
    ref_ptr = Array(Ptr{Void}, 1)
    ret = api.git_reference_next(ref_ptr, r.ptr)
    if ret == api.ITEROVER
        return (state, nothing)
    end
    return (state, GitReference(ref_ptr[1]))
end
