Try Code
========

Try Code is an online interactive coding tutorial for those with absolutely no programming experience. It includes a web-based Racket REPL, and the tutorial itself is condensed from Chapter 2 of Realm of Racket.

Try Code was forked from John Berry's [try-racket](https://github.com/jarcane/try-racket), and is written in Racket and JavaScript with Chris Done's [jquery-console](https://github.com/chrisdone/jquery-console).

Please note that the REPL and its server are still to some extent a work in progress, and community contribution is vigorously encouraged.

## Online host

Try Code is hosted online at http://trycode.io

## How to run it locally

```sh
$ racket trycode/main.rkt
```

Open http://localhost:8080 in your browser

*NOTE:* Currently Try Code does not work properly on Windows/Mac platforms. It should run, but hosting is not recommended as surprising behaviors continue to be discovered.

## Contribute

trycode.io uses a [Fork and Pull](https://help.github.com/articles/fork-a-repo) model of collaborative development.  Follow this link to learn how to [submit a pull request](https://help.github.com/articles/using-pull-requests).

1. **Point your browser at https://github.com/arguello/trycode.io and click "Fork".**
2. **From shell/prompt:**

```sh
> git clone https://github.com/username/trycode.io.git
# Clones your fork of the repository into the current directory

> cd trycode.io
# Changes the active directory to the newly cloned "trycode.io" directory

> git remote add upstream https://github.com/arguello/trycode.io.git
# Assigns the original repository to a remote called "upstream"

> git fetch upstream
# Pulls in changes not present in your local repository, without modifying your files
```

## File a Bug
Bugs can be filed using Github Issues within this repository
