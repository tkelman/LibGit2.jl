# test_to_s
sandboxed_test("diff", "test patch") do test_repo, test_repo_path
    t1 = GitTree(test_repo[Oid("d70d245ed97ed2aa596dd1af6536e4bfdb047b69")])
    t2 = GitTree(test_repo[Oid("7a9e0b02e63179929fed24f0a3e0f19168114d10")])
    d  = diff(test_repo, t1, t2, Dict{Any,Any}(:context_lines => 0))
    s1 = string(patches(d)[1])
    p1 = replace("diff --git a/another.txt b/another.txt
index 3e5bcba..546c735 100644
--- a/another.txt
+++ b/another.txt
@@ -2 +2 @@ Git is fast. With Git, nearly all operations are performed locally, giving
-it a huge speed advantage on centralized systems that constantly have to
+it an huge speed advantage on centralized systems that constantly have to
@@ -11,4 +10,0 @@ from the start.
-Let's see how common operations stack up against Subversion, a common
-centralized version control system that is similar to CVS or
-Perforce. Smaller is faster.
-
@@ -34,0 +31,4 @@ SVN.
+Let's see how common operations stack up against Subversion, a common
+centralized version control system that is similar to CVS or
+Perforce. Smaller is faster.
+
", "\r\n", "\n")
    @test s1 == p1

    s2 = string(patches(d)[2])
    p2 = replace("diff --git a/readme.txt b/readme.txt
index 7b808f7..29ab705 100644
--- a/readme.txt
+++ b/readme.txt
@@ -1 +1 @@
-The Git feature that really makes it stand apart from nearly every other SCM
+The Git feature that r3ally mak3s it stand apart from n3arly 3v3ry other SCM
@@ -10,4 +9,0 @@ This means that you can do things like:
-Frictionless Context Switching. Create a branch to try out an idea, commit a
-few times, switch back to where you branched from, apply a patch, switch
-back to where you are experimenting, and merge it in.
-
@@ -27,3 +22,0 @@ Notably, when you push to a remote repository, you do not have to push all
-of your branches. You can choose to share just one of your branches, a few
-of them, or all of them. This tends to free people to try new ideas without
-worrying about having to plan how and when they are going to merge it in or
@@ -35 +28 @@ incredibly easy and it changes the way most developers work when they learn
-it.
+it.!
\\ No newline at end of file
", "\r\n", "\n")
    @test s2 == p2
end
