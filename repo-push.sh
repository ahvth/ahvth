# Add changes to git.
git add .

# Commit changes.
msg="rebuilding site $(date)"
if [ -n "$*" ]; then
	msg="$*"
fi
git commit -m "$msg"

# Push source and build repos
GIT_SSH_COMMAND='ssh -i /home/andrew/.ssh/ahvth -o IdentitiesOnly=yes' git push origin master

