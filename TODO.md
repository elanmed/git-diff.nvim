# TODO

## Notes:

- Highlights: do I want to show other kinds of diffs via highlight in the current file?
  - Yes, but only make sense to be able to reset diffs if the base file is the working tree

## Diffview

- Support all of the following

| vs ->        | index                                  | head                                             | upstream                                                    |
| ------------ | -------------------------------------- | ------------------------------------------------ | ----------------------------------------------------------- |
| **worktree** | `cat filename` vs `git show :filename` | `cat filename` vs `git show HEAD:filename`       | `cat filename` vs `git show origin/main:filename`           |
| **index**    | —                                      | `git show :filename` vs `git show HEAD:filename` | `git show :filename` vs `git show origin/main:filename`     |
| **head**     |                                        | —                                                | `git show HEAD:filename` vs `git show origin/main:filename` |
| **upstream** |                                        |                                                  | —                                                           |

| vs ->        | index                  | head                            | upstream                                    |
| ------------ | ---------------------- | ------------------------------- | ------------------------------------------- |
| **worktree** | `git diff --name-only` | `git diff --name-only HEAD`     | `git diff --name-only origin/main`          |
| **index**    | —                      | `git diff --name-only --cached` | `git diff --name-only --cached origin/main` |
| **head**     |                        | —                               | `git diff --name-only HEAD origin/main`     |
| **upstream** |                        |                                 | —                                           |

- TODO: how should resetting hunks work when neither left nor right is the current buffer
  - Diff highlights shouldn't show?
- TODO: what would it look like to stage hunks?
  - Need to create a patch and apply it, can generate a patch from a file
    - Either generate a patch from the current file, parse the string, and only keep the hunk you want
    - Or edit the file to only have the hunk you want, then generate a patch, then undo the changes
