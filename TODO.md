# TODO

## Notes:

- Currently only shows diffs for the working tree vs staged
- TODO: Do I want to show other kinds of diffs in the current file?

## Diffview

- Support all of the following

| vs →                 | Staged                                 | Committed (HEAD)                                 | Remote                                                      |
| -------------------- | -------------------------------------- | ------------------------------------------------ | ----------------------------------------------------------- |
| **Working tree**     | `cat filename` vs `git show :filename` | `cat filename` vs `git show HEAD:filename`       | `cat filename` vs `git show origin/main:filename`           |
| **Staged**           | —                                      | `git show :filename` vs `git show HEAD:filename` | `git show :filename` vs `git show origin/main:filename`     |
| **Committed (HEAD)** |                                        | —                                                | `git show HEAD:filename` vs `git show origin/main:filename` |
| **Remote**           |                                        |                                                  | —                                                           |

- TODO: how should resetting hunks work when neither left nor right is the current buffer
- TODO: what would it look like to stage hunks?
