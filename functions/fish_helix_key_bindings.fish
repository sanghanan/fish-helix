# IMPORTANT!!!
#
# When defining your own bindings using fish_helix_command, be aware that it can break
# stuff sometimes.
#
# It is safe to define a binding consisting of a lone call to fish_helix_command.
# Calls to other functions and executables are allowed along with it, granted they don't mess
# with fish's commandline buffer.
#
# Mixing multiple fish_helix_commandline and commandline calls in one binding MAY trigger issues.
# Nothing serious, but don't be surprised. Just test it.

function fish_helix_key_bindings --description 'helix-like key bindings for fish'
    if contains -- -h $argv
        or contains -- --help $argv
        echo "Sorry but this function doesn't support -h or --help"
        return 1
    end

    # Erase all bindings if not explicitly requested otherwise to
    # allow for hybrid bindings.
    # This needs to be checked here because if we are called again
    # via the variable handler the argument will be gone.
    set -l rebind true
    if test "$argv[1]" = --no-erase
        set rebind false
        set -e argv[1]
    else
        bind --erase --all --preset # clear earlier bindings, if any
    end

    # Allow just calling this function to correctly set the bindings.
    # Because it's a rather discoverable name, users will execute it
    # and without this would then have subtly broken bindings.
    if test "$fish_key_bindings" != fish_helix_key_bindings
        and test "$rebind" = true
        # Allow the user to set the variable universally.
        set -q fish_key_bindings
        or set -g fish_key_bindings
        # This triggers the handler, which calls us again and ensures the user_key_bindings
        # are executed.
        set fish_key_bindings fish_helix_key_bindings
        return
    end

    set -l init_mode insert

    if contains -- $argv[1] insert default visual
        set init_mode $argv[1]
    else if set -q argv[1]
        # We should still go on so the bindings still get set.
        echo "Unknown argument $argv" >&2
    end

    # Inherit shared key bindings.
    # Do this first so helix-bindings win over default.
    for mode in insert default visual
        __fish_shared_key_bindings -s -M $mode
    end

    bind -s --preset -M insert enter execute

    bind -s --preset -M insert "" self-insert

    # Space and other command terminators expand abbrs _and_ inserts itself.
    bind -s --preset -M insert " " self-insert expand-abbr
    bind -s --preset -M insert ";" self-insert expand-abbr
    bind -s --preset -M insert "|" self-insert expand-abbr
    bind -s --preset -M insert "&" self-insert expand-abbr
    bind -s --preset -M insert "^" self-insert expand-abbr
    bind -s --preset -M insert ">" self-insert expand-abbr
    bind -s --preset -M insert "<" self-insert expand-abbr
    # Closing a command substitution expands abbreviations
    bind -s --preset -M insert ")" self-insert expand-abbr
    # Ctrl-space inserts space without expanding abbrs
    bind -s --preset -M insert ctrl-space 'commandline -i " "'

    # Switching to insert mode
    for mode in default visual
        bind -s --preset -M $mode -m insert \cc end-selection cancel-commandline repaint-mode
        bind -s --preset -M $mode -m insert enter end-selection execute
        bind -s --preset -M $mode -m insert o end-selection insert-line-under repaint-mode
        bind -s --preset -M $mode -m insert O end-selection insert-line-over repaint-mode
        # FIXME i/a should keep selection, maybe
        bind -s --preset -M $mode i "fish_helix_command insert_mode"
        bind -s --preset -M $mode I "fish_helix_command prepend_to_line"
        bind -s --preset -M $mode a "fish_helix_command append_mode"
        bind -s --preset -M $mode A "fish_helix_command append_to_line"
    end

    # Mode switching commands - simplified based on fish_vi_key_bindings
    # Insert -> Normal: Escape
    set -l on_escape '
        if commandline -P
            commandline -f cancel
        else
            set fish_bind_mode default
            if test (count (commandline --cut-at-cursor | tail -c2)) != 2
                commandline -f backward-char
            end
            commandline -f repaint-mode
        end
    '
    bind -s --preset -M insert escape $on_escape
    bind -s --preset -M insert ctrl-\[ $on_escape

    # Normal -> Visual: v
    bind -s --preset -M default -m visual v repaint-mode

    # Normal: escape to clear selection
    bind -s --preset -M default escape end-selection repaint-mode
    bind -s --preset -M default ctrl-\[ end-selection repaint-mode

    # Visual -> Normal: v or escape
    bind -s --preset -M visual -m default v repaint-mode
    bind -s --preset -M visual -m default escape repaint-mode
    bind -s --preset -M visual -m default ctrl-\[ repaint-mode


    # Motion and actions in normal/select mode
    for mode in default visual
        # Set up mode-dependent variables
        set -l extend_selection ""
        if test $mode = default
            # In normal mode, we need to explicitly begin selection
            set -l extend_selection begin-selection
        end

        # Numbers for count
        for key in (seq 0 9)
            bind -s --preset -M $mode $key "fish_bind_count $key"
        end

        # Directional movement with selection in normal mode
        if test $mode = default
            # For normal mode - include begin-selection to show highlight
            bind -s --preset -M $mode h begin-selection backward-char
            bind -s --preset -M $mode left begin-selection backward-char
            bind -s --preset -M $mode l begin-selection forward-char
            bind -s --preset -M $mode right begin-selection forward-char
            bind -s --preset -M $mode k begin-selection up-or-search
            bind -s --preset -M $mode j begin-selection down-or-search
            bind -s --preset -M $mode up begin-selection up-or-search
            bind -s --preset -M $mode down begin-selection down-or-search
        else
            # For visual mode - selection already active
            bind -s --preset -M $mode h backward-char
            bind -s --preset -M $mode left backward-char
            bind -s --preset -M $mode l forward-char
            bind -s --preset -M $mode right forward-char
            bind -s --preset -M $mode k up-line
            bind -s --preset -M $mode j down-line
            bind -s --preset -M $mode up up-line
            bind -s --preset -M $mode down down-line
        end

        # Word movement bindings with selection in normal mode
        if test $mode = default
            # In normal mode, begin selection before moving
            # w - forward to next word start
            bind -s --preset -M $mode w begin-selection forward-word forward-single-char
            # b - backward to start of word
            bind -s --preset -M $mode b begin-selection backward-word
            # e - forward to end of word
            bind -s --preset -M $mode e begin-selection forward-single-char forward-word backward-char

            # Capital variants for "big" words
            bind -s --preset -M $mode W begin-selection forward-bigword forward-single-char
            bind -s --preset -M $mode B begin-selection backward-bigword
            bind -s --preset -M $mode E begin-selection forward-single-char forward-bigword backward-char
        else
            # In visual mode, just move with selection active
            bind -s --preset -M $mode w forward-word forward-single-char
            bind -s --preset -M $mode b backward-word
            bind -s --preset -M $mode e forward-single-char forward-word backward-char

            # Capital variants for "big" words
            bind -s --preset -M $mode W forward-bigword forward-single-char
            bind -s --preset -M $mode B backward-bigword
            bind -s --preset -M $mode E forward-single-char forward-bigword backward-char
        end

        # Character finding commands - using fish's built-in jump commands (same as vi mode)
        bind -s --preset -M $mode f forward-jump
        bind -s --preset -M $mode F backward-jump
        bind -s --preset -M $mode t forward-jump-till
        bind -s --preset -M $mode T backward-jump-till
        bind -s --preset -M $mode ';' repeat-jump
        bind -s --preset -M $mode , repeat-jump-reverse

        # Bindings for newline navigation - more consistent with fish's approach
        bind -s --preset -M $mode "f,enter" "commandline -f forward-jump -- \\n"
        bind -s --preset -M $mode "t,enter" "commandline -f forward-jump-till -- \\n"
        bind -s --preset -M $mode "F,enter" "commandline -f backward-jump -- \\n"
        bind -s --preset -M $mode "T,enter" "commandline -f backward-jump-till -- \\n"

        # Home and end key bindings using direct commands
        if test $mode = default
            # In normal mode we need selection
            # gh, home - goto beginning of line
            bind -s --preset -M $mode gh begin-selection beginning-of-line
            bind -s --preset -M $mode home begin-selection beginning-of-line

            # gl, end - goto end of line
            bind -s --preset -M $mode gl begin-selection end-of-line
            bind -s --preset -M $mode end begin-selection end-of-line

            # gs - goto first non-whitespace character
            bind -s --preset -M $mode gs begin-selection beginning-of-line forward-bigword backward-bigword

            # gg - goto beginning of buffer
            bind -s --preset -M $mode gg begin-selection beginning-of-buffer

            # G - goto end of buffer
            bind -s --preset -M $mode G begin-selection end-of-buffer

            # ge - goto last line
            bind -s --preset -M $mode ge begin-selection end-of-buffer beginning-of-line
        else
            # In visual mode, selection is already active
            bind -s --preset -M $mode gh beginning-of-line
            bind -s --preset -M $mode home beginning-of-line

            bind -s --preset -M $mode gl end-of-line
            bind -s --preset -M $mode end end-of-line

            bind -s --preset -M $mode gs beginning-of-line forward-bigword backward-bigword

            bind -s --preset -M $mode gg beginning-of-buffer

            bind -s --preset -M $mode G end-of-buffer

            bind -s --preset -M $mode ge end-of-buffer beginning-of-line
        end

        # FIXME alt-. doesn't work with t/T
        # FIXME alt-. doesn't work with [ftFT][enter]
        bind -s --preset -M $mode "alt-." repeat-jump

        # FIXME reselect after undo/redo
        bind -s --preset -M $mode u undo begin-selection
        bind -s --preset -M $mode U redo begin-selection

        bind -s --preset -M $mode -m replace_one r repaint-mode

        # FIXME registers
        # bind -s --preset -M $mode y fish_clipboard_copy
        # bind -s --preset -M $mode P fish_clipboard_paste
        # bind -s --preset -M $mode R kill-selection begin-selection yank-pop yank

        # Delete, yank, and paste operations - simplified
        # d - delete selection
        bind -s --preset -M $mode -m default d kill-selection repaint-mode

        # c - change: delete and enter insert mode
        bind -s --preset -M $mode -m insert c kill-selection repaint-mode

        # y - yank (copy)
        bind -s --preset -M $mode -m default y kill-selection yank end-selection repaint-mode

        # p/P - paste after/before cursor
        bind -s --preset -M $mode p forward-char yank
        bind -s --preset -M $mode P yank

        # Clipboard operations
        bind -s --preset -M $mode -m default " y" fish_clipboard_copy repaint-mode
        bind -s --preset -M $mode " p" forward-char fish_clipboard_paste
        bind -s --preset -M $mode " P" fish_clipboard_paste

        # R - replace selection
        bind -s --preset -M $mode -m replace_one R repaint-mode

        # FIXME keep selection
        bind -s --preset -M $mode '~' togglecase-selection
        # FIXME ` and escape,`

        # FIXME .
        # FIXME < and >
        # FIXME =

        # FIXME ctrl-a ctrl-x
        # FIXME Qq

        ## Shell
        # FIXME

        ## Selection manipulation
        # FIXME & _

        bind -s --preset -M $mode \; begin-selection
        bind -s --preset -M $mode "escape,;" swap-selection-start-stop
        # FIXME escape:

        bind -s --preset -M $mode % "fish_helix_command select_all"
        bind -s --preset -M $mode x "fish_helix_command select_line"

        # FIXME X alt-x
        # FIXME J
        # FIXME ctrl-c

        ## Search
        # History
        bind -s --preset -M $mode / history-pager repaint-mode

        ## FIXME minor modes: g, m, space

        ## FIXME [ and ] motions
    end

    # FIXME should replace the whole selection
    # FIXME should be able to go back to visual mode
    bind -s --preset -M replace_one -m default '' delete-char self-insert backward-char repaint-mode
    bind -s --preset -M replace_one -m default enter 'commandline -f delete-char; commandline -i \n; commandline -f backward-char; commandline -f repaint-mode'
    bind -s --preset -M replace_one -m default escape cancel repaint-mode


    ## FIXME Insert mode keys

    ## Old config from vi:

    # Vi moves the cursor back if, after deleting, it is at EOL.
    # To emulate that, move forward, then backward, which will be a NOP
    # if there is something to move forward to.
    bind -s --preset -M insert delete delete-char forward-single-char backward-char
    bind -s --preset -M default delete delete-char forward-single-char backward-char

    # Backspace deletes a char in insert mode, but not in normal/default mode.
    bind -s --preset -M insert backspace backward-delete-char
    bind -s --preset -M default backspace backward-char
    bind -s --preset -M insert \ch backward-delete-char
    bind -s --preset -M default \ch backward-char
    bind -s --preset -M insert \x7f backward-delete-char
    bind -s --preset -M default \x7f backward-char
    bind -s --preset -M insert shift-delete backward-delete-char # shifted delete
    bind -s --preset -M default shift-delete backward-delete-char # shifted delete


#    bind -s --preset '~' togglecase-char forward-single-char
#    bind -s --preset gu downcase-word
#    bind -s --preset gU upcase-word
#
#    bind -s --preset J end-of-line delete-char
#    bind -s --preset K 'man (commandline -t) 2>/dev/null; or echo -n \a'
#



    # same vim 'pasting' note as upper
    bind -s --preset '"*p' forward-char "commandline -i ( xsel -p; echo )[1]"
    bind -s --preset '"*P' "commandline -i ( xsel -p; echo )[1]"



    #
    # visual mode
    #



    # bind -s --preset -M visual -m insert c kill-selection end-selection repaint-mode
    # bind -s --preset -M visual -m insert s kill-selection end-selection repaint-mode
    bind -s --preset -M visual -m default '"*y' "fish_clipboard_copy; commandline -f end-selection repaint-mode"
    bind -s --preset -M visual -m default '~' togglecase-selection end-selection repaint-mode



    # Set the cursor shape - uses similar approach to fish_vi_key_bindings
    # After executing once, this will have defined functions listening for the variable.
    # Therefore it needs to be before setting fish_bind_mode.
    fish_vi_cursor

    # Configure specific cursor shapes for each mode
    set -g fish_cursor_default block       # Normal mode: block
    set -g fish_cursor_insert line         # Insert mode: line
    set -g fish_cursor_replace_one underscore
    set -g fish_cursor_replace underscore
    set -g fish_cursor_visual underscore   # Visual mode: underscore

    # Set the cursor selection mode
    set -g fish_cursor_selection_mode inclusive

    # Add handlers for cursor end mode changes
    function __fish_helix_key_bindings_on_mode_change --on-variable fish_bind_mode
        switch $fish_bind_mode
            case insert replace
                set -g fish_cursor_end_mode exclusive
            case '*'
                set -g fish_cursor_end_mode inclusive
        end
    end

    # Function to clean up handlers when bindings change
    function __fish_helix_key_bindings_remove_handlers --on-variable __fish_active_key_bindings
        functions --erase __fish_helix_key_bindings_remove_handlers
        functions --erase __fish_helix_key_bindings_on_mode_change
        if type -q __fish_vi_cursor
            __fish_vi_cursor fish_cursor_default
        end
        set -e -g fish_cursor_end_mode
        set -e -g fish_cursor_selection_mode
    end

    set fish_bind_mode $init_mode

end
