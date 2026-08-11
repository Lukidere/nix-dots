# Modern CLI tool integrations + aliases.
# conf.d loads before config.fish, so atuin (config.fish) reclaims Ctrl-R after
# fzf's keybindings are installed here.

# ── shell integrations (guarded so a missing binary is silent) ──
if command -q fzf
    fzf --fish | source          # Ctrl-T files, Alt-C cd (Ctrl-R goes to atuin)
end
if command -q direnv
    direnv hook fish | source     # auto-load .envrc per directory
end

# ── aliases (only the syntax-compatible ones shadow originals) ──
alias df 'duf'          # disk usage
alias dig 'doggo'       # DNS lookup
alias http 'xh'         # HTTP client
alias help 'tldr'       # cheat-sheet man pages
alias loc 'tokei'       # count lines of code
alias unpack 'ouch d'   # extract any archive
alias pack 'ouch c'     # compress to any archive
alias j 'just'          # command runner
alias zj 'zellij'       # terminal multiplexer
alias pp 'procs'        # processes (ps kept native)
alias gp 'gping'        # ping with a graph
alias f 'fzf'           # fuzzy finder

# ── yazi: cd into the directory you quit in ──
function y --wraps yazi --description "yazi, cd on exit"
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file="$tmp"
    if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# ── broot: navigate and cd on exit ──
function br --wraps broot --description "broot, cd on exit"
    set -l cmd_file (mktemp)
    if broot --outcmd "$cmd_file" $argv
        read --local --null cmd <"$cmd_file"
        rm -f "$cmd_file"
        eval "$cmd"
    else
        set -l code $status
        rm -f "$cmd_file"
        return $code
    end
end
