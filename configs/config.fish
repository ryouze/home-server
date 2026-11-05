# ~/.config/fish/config.fish

if status is-interactive
    # Commands to run in interactive sessions can go here
    if status is-login
        fastfetch
    end
    alias cat 'batcat --style=plain --paging=never'
end