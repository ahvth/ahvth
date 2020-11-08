---
title: "Managing Multiple Git SSH Identities"
date: 2020-11-08T23:29:52+01:00
draft: false
tags: ["git", "ssh", "quickguide"]
---

When working with Git in a POSIX / Linux environment (as you should), it's easy to lose track of your SSH keys if you're working with more than just your default identity. This is a pretty common problem when you are working with several Git repos via SSH concurrently and don't have a [machine user](https://developer.github.com/v3/guides/managing-deploy-keys/#machine-users) set up to authenticate with multiple repos using a single key.

For the lazy ones, or those who like to keep things simple and quick, or perhaps those who don't manage their own repos, I'll share a solution for juggling your Git SSH keys without making any changes on the repo end.

The key here is that we will set an environment variable before issuing any Git command like so:

```
GIT_SSH_COMMAND='ssh -i /home/user/.ssh/associated_private_key -o IdentitiesOnly=yes' git push origin master
```

You can make this even easier by adding an alias to your `.bashrc` or `.zshrc`:

```
echo 'alias hugo-repo-push="GIT_SSH_COMMAND='ssh -i /home/user/.ssh/hugo_private_key -o IdentitiesOnly=yes' git push origin master"'
```

Or make a script that you can freely add to .gitignore in the repo itself, such as this one:

```
repo $ cat repo-push.sh
# Add changes to git.
git add .

# Commit changes.
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos
GIT_SSH_COMMAND='ssh -i /home/user/.ssh/associated_private_key -o IdentitiesOnly=yes' git push origin master
```

This lets you issue `./repo-push.sh "optional commit message"` instead of your usual `git push` and can even be further parameterized to accept a different git command, remote, or branch.

Hope this helps even just a little!
