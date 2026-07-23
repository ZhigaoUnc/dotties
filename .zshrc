eval "$(starship init zsh)"
bindkey -v
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=5000
SAVEHIST=5000
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/unc/.zshrc'

alias cfg="cd ~/.config"
alias kvim="env NVIM_APPNAME=nvim-kickstart nvim"
alias yay="paru"
alias zed="zeditor"
alias ta="tmux attach"
alias balls="~/.config/scripts/aniw-3"
alias nodepad="cd ~/nodepad "
alias shared="cd /mnt/shared/ "
autoload -Uz compinit
compinit
export EDITOR="nvim"
export VISUAL="nvim"
alias vim="nvim"
alias v="nvim"
export PATH="$HOME/.config/emacs/bin:$PATH"
alias emacs="doom emacs"
alias def='dict'
alias viu="viu-media"
alias ani="anipy-cli"
# End of lines added by compinstall
eval "$(zoxide init zsh)"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.config/scripts:$PATH"
export QT_QPA_PLATFORMTHEME=qt6ct
export PATH="/home/unc/.bun/bin:$PATH"

# my keys are in .zshrc.local (should be backed up somewhere)
# 1. GCAL_ORG_SYNC_CLIENT_ID=
# 2. GCAL_ORG_SYNC_CLIENT_SECRET
# 3. TOGGL_API_TOKEN
# 4. export FIREBASE_URL=
# 5. MY_KEY="rediah"

[ -f ~/.zshrc.local ] && source ~/.zshrc.local
