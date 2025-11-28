# enable command auto-correction
setopt CORRECT

# enable command history
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# use emacs keybindings in the command line
bindkey -e

# initialize Starship prompt
eval "$(starship init zsh)"

# general
alias h='history' # shortcut for history
alias c='clear' # shortcut to clear your terminal
alias gzip=pigz
alias search='find . -maxdepth 1 -type f | xargs grep -in --color=always '
alias wget='wget2'
alias top='htop'

# tmux
alias t="tmux"
alias tn="tmux new-session -s"
alias ta="tmux attach-session -t"
alias tls="tmux list-sessions"
alias tk="tmux kill-session -t"
alias td="tmux detach"

# directory movement
alias ..='cd ..'
alias ...='cd ../../'
alias ....='cd ../../../'

# ls
alias ls='eza --group-directories-first --icons'
alias ll='eza --group-directories-first --icons -lh'
alias la='eza --group-directories-first --icons -a'
alias lla='eza --group-directories-first --icons -lah'
alias lsa='eza --group-directories-first --icons -lah'
alias l='eza'
alias lt='eza --tree'
alias lm='eza --long --sort=modified'
alias lsize='eza --long --sort=size'
alias lext='eza --long --sort=extension'
alias ldot='eza -a | grep "^\."'
alias ldir='eza -D'
alias lfile='eza -f'

# ip addresses
alias ip='echo "\nLocal IPs:" && ifconfig | grep "inet " | awk '\''{printf "\t%s\n", $2}'\'' && echo "External IP:" && curl -s ipinfo.io/ip | awk '\''{printf "\t%s\n", $0}'\'';'
alias whois="whois -h whois-servers.net"

# docker (using podman)
alias docker="podman"
alias docker-compose="podman-compose"

# podman
alias pd="podman"
alias pdi="podman images"
alias pdps="podman ps"
alias pdpsa="podman ps -a"
alias pdrm="podman rm"
alias pdrmi="podman rmi"
alias pdp="podman pull"
alias pdr="podman run"
alias pde="podman exec"
alias pdl="podman logs"
alias pdb="podman build"
alias pdc="podman-compose"

# path
export PATH=$HOME/bin:/usr/local/bin:$PATH

# automatically attach to tmux session on SSH login
if [[ -z "$TMUX" ]] && [ "$SSH_CONNECTION" != "" ]; then
    # define the name of the tmux session
    SESSION_NAME="default"

    # try to attach to the session, or create it if it doesn't exist
    tmux attach-session -t $SESSION_NAME || tmux new-session -s $SESSION_NAME
fi

# shell configuration
setopt promptsubst

# initialize and load Zsh autocompletion
autoload -Uz +X compinit && compinit

# case-insensitive path-completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# enable menu-based selection of completion options
zstyle ':completion:*' menu select
