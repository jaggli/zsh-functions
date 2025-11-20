# zsh-functions

zsh utilities

## Installation

Clone the repo

```bash
mkdir -p "~/.config/zsh" && git clone git@github.com:jaggli/zsh-functions.git ~/.config/zsh/zsh-functions
```

Add this to `~/.zshrc`

```bash
# optional config for zsh functions
ZSH_FUNCTIONS_FEATURE_BRANCH_PREFIX="feature/" # prefix for newly created feature branches
ZSH_FUNCTIONS_GIT_MERGE_COMMAND="fork" # executable, to resolve merge conflicts

# include all custom zsh functions
for f in ~/.config/zsh/zsh-functions/*.zsh; do
  source "$f"
done
```
