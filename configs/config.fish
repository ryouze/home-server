# ~/.config/fish/config.fish

if status is-interactive
    # Commands to run in interactive sessions can go here

    if status is-login
        fastfetch
    end
end
