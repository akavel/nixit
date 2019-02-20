{.experimental: "codeReordering".}
import strutils
import os
import patty except match
import gara

type
  FileConfusionError* = object of CatchableError

  Root* = distinct string
  Roots* = tuple
    ## Paths to roots of four directory trees. The same relative path in any of those
    ## describes the same file, but at a different phase of life.
    ## Each Root contains a "del" and "exist" subdirectory, corresponding to FileStatus.
    old_managed: Root   ## contains files carried over from old Nix generation
    new_precond: Root   ## for files intended to become managed, declares their expected pre-assimilation state
    new_managed: Root   ## contains intended state of files after activation of the new (current) Nix generation
    new_disowned: Root  ## contains intended state of files that are to be disowned (unmanaged) in future Nix generations

  Action* = tuple
    kind: ActionKind
    before: Root
    after: Root
  ActionKind* = enum
    Assimilate = "A",
    ModifyManaged = "M",
    Disown = "D",
    ModifyUnmanaged = "X"

  FileStatus = enum
    Deleted, Existing



const
  del = "del"
  exist = "exist"


proc `/`(root: Root, path: string): string =
  return root.string / path

iterator walkRecRelative(dir: string): string =
  const
    yieldFilter = {pcFile, pcLinkToFile}
    followFilter = {pcDir, pcLinkToDir}
  for f in walkDirRec(dir, yieldFilter, followFilter):
    var relpath = f
    relpath.removePrefix(dir)
    yield relpath

iterator walkRec(root: Root): (string, FileStatus) =
  const
    yieldFilter = {pcFile, pcLinkToFile}
    followFilter = {pcDir, pcLinkToDir}
  for f in walkRecRelative(root / del):
  # for f in walkDirRec(root / del, yieldFilter, followFilter, true):
    if existsFile(root / exist / f):
      raise newException(FileConfusionError, "file must not be present in two places: $#/{del,exist}/$#" % [root.string, f])
    yield (f, Deleted)
  for f in walkRecRelative(root / exist):
  # for f in walkDirRec(root / exist, yieldFilter, followFilter, true):
    yield (f, Existing)

proc has(root: Root, file: string): bool =
  let
    hasdel =   existsFile(root / del / file)
    hasexist = existsFile(root / exist / file)
  if hasdel and hasexist:
    raise newException(FileConfusionError, "file must not be present in two places: $#/{del,exist}/$#" % [root.string, file])
  return hasdel or hasexist


iterator walkDistinctRec*(roots: Roots): (string, FileStatus) =
  let rootList = [roots.old_managed, roots.new_precond, roots.new_managed, roots.new_disowned]

  proc alreadyEmitted(file: string, i: int): bool =
    for j in 0 ..< i:
      if rootList[j].has(file):
        return true

  for i, root in rootList:
    for file, status in root.walkRec():
      if not alreadyEmitted(file, i):
        yield (file, status)


proc getAction*(roots: Roots, file: string): Action =
  let status = (
    roots.old_managed.has(file),
    roots.new_precond.has(file),
    roots.new_managed.has(file),
    roots.new_disowned.has(file))
  match status:
    (false, false, false, false): raise newException(FileConfusionError, "file not found in any root: " & file)
    (_, _, true, true):           raise newException(FileConfusionError, "file cannot become both managed and disowned: " & file)
    (_, _, false, false):         raise newException(FileConfusionError, "don't know what to do with file, please specify managed or disowned: " & file)
    (true, true, _, _):           raise newException(FileConfusionError, "for previously managed file, precondition should not be provided: " & file)
    (false, false, _, _):         raise newException(FileConfusionError, "for previously unmanaged file, precondition must be provided: " & file)
    (false, true, true, false): return (Assimilate, roots.new_precond, roots.new_managed)
    (true, false, true, false): return (ModifyManaged, roots.old_managed, roots.new_managed)
    (true, false, false, true): return (Disown, roots.old_managed, roots.new_disowned)
    (false, true, false, true): return (ModifyUnmanaged, roots.new_precond, roots.new_disowned)

# proc precheck(prev, next: FileStatus) =
#   ## Check precondition.


# variant FileStatus:
#   Unmanaged(expectData: string, expectAttrs: uint64)  # External?
#   Deleted                                             # Absent?
#   Existing(data: string, attrs: uint64)               # Managed? Regular? Owned?

#[
sdf
]#

#[
scenarios:

  case old=Missing:
    verify there's no old file on disk; fail otherwise
    return not exists(target file on disk)
  case old=Existing:
    return (hash_contents(target file on disk) == expected hash of file in old generation)
  case old=Unmanaged:
]#

#[

Algorithm inputs:
 - OLD_GEN -> can be: <missing>, Managed_deleted, Managed_existing (+ contents, attrs)
 - DISK    -> Absent, Found (+ contents, attrs)
 - NEW_GEN -> <missing>, Managed_deleted, Managed_existing (+ contents, attrs), Unmanaged_post (+ contents, attrs)
              additionally, may have:
                Unmanaged_pre (+ contents, attrs)

 -> can OLD_GEN also have all variants from NEW_GEN? (i.e. Unmanaged_post, Unmanaged_pre?)
]#

#[
- first, check based on all files in 1st dir
- then, based on files in 2nd dir, but skip files existing in 1st (already checked)
- then, 3rd except 1st & 2nd
- then, 4th except 1st, 2nd, 3rd
]#


