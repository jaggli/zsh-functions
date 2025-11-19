# zsh-functions

zsh utilities

## Installation

Clone the repo

```bash
mkdir -p "~/.config/zsh" && git clone git@github.com:jaggli/zsh-functions.git ~/.config/zsh/zsh-functions
```

Add this to `~/.zshrc`

```bash
# include all custom zsh functions
for f in ~/.config/zsh/zsh-functions/*.zsh; do
  source "$f"
done
```
