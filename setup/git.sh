echo "Setting git credentials..."
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_MAIL"
git config --global core.editor nvim
git config --global init.defaultBranch main

echo "Setting git aliases..."
git config --global alias.li "log --oneline --date=short"
git config --global alias.tree "log --pretty=oneline --graph --decorate --all --date=short"
git config --global alias.amend "commit --amend --no-edit"
git config --global alias.redo "commit --amend"
git config --global alias.s "status"
git config --global alias.a "add"
git config --global alias.c "commit"
git config --global alias.cm "commit -m"
git config --global alias.unstage "restore --staged"

echo "Setting merge tool..."
git config --global mergetool.dvnvim.cmd 'nvim -c "DiffviewOpen" '
git config --global merge.tool dvnvim

echo "Installing gh extensions..."
if command -v gh > /dev/null 2>&1; then
	# Installing an extension that is already there is an error, so add only
	# what is missing. gh-dash backs the <leader>gh dashboard in nvim, and
	# gh-stack is what the gh-stack Claude skill drives.
	installed="$(gh extension list 2>/dev/null || true)"
	for ext in dlvhdr/gh-dash github/gh-stack; do
		name="${ext#*/}"
		case "$installed" in
		*"${name}"*) echo "  already installed: ${ext}" ;;
		*) gh extension install "$ext" && echo "  installed: ${ext}" ;;
		esac
	done
else
	echo "  skipped: gh not found, install it and re-run"
fi

echo "Done!"

