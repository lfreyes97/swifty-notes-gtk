import Foundation

enum SwiftyNotesCLISeed {
    static let content = """
    # Using Swifty Notes CLI

    *The desktop app and the CLI work with the same file-backed markdown notes.*

    The CLI is handy when you want to script note creation, inspect content from a terminal, or let another tool update notes without touching the GUI.

    ## If You Installed from Flathub

    ```bash
    flatpak run me.spaceinbox.swiftynotes cli list
    flatpak run me.spaceinbox.swiftynotes cli get <note-id>
    flatpak run me.spaceinbox.swiftynotes cli get <note-id> --raw
    flatpak run me.spaceinbox.swiftynotes cli create --content '# Title\n\nBody'
    flatpak run me.spaceinbox.swiftynotes cli update <note-id> --stdin
    ```

    ## Optional Shortcut on the Host

    ```bash
    mkdir -p ~/.local/bin
    cat > ~/.local/bin/swiftynotes <<'EOF'
    #!/bin/sh
    exec flatpak run me.spaceinbox.swiftynotes "$@"
    EOF
    chmod +x ~/.local/bin/swiftynotes
    ```

    After that, you can run:

    ```bash
    swiftynotes cli list
    swiftynotes cli get <note-id>
    swiftynotes cli get <note-id> --raw
    swiftynotes cli create --content '# Title\n\nBody'
    swiftynotes cli update <note-id> --stdin
    ```

    ## Typical Workflow

    1. Run the `list` command to find the note ID you want.
    2. Use `get --raw` when you need the markdown exactly as stored.
    3. Pipe fresh markdown into `update --stdin` to replace a note in one step.
    4. Use `create --content` for quick capture from shell scripts.

    ## Helpful Tips

    - Flathub installs use `flatpak run me.spaceinbox.swiftynotes cli ...`.
    - If you add the optional wrapper above, you can use `swiftynotes cli ...` on the host.
    - Pass `--notes-dir /path/to/notes` to target a custom notes folder.
    - IDs are lowercase UUID strings and stay stable across GUI and CLI usage.
    - `update` replaces the full markdown body, so generate the final document before sending it.

    ## Example

    ```bash
    flatpak run me.spaceinbox.swiftynotes cli list | jq .
    printf '# Release checklist\n\n- [x] Draft screenshots\n- [ ] Publish release notes\n' \\
      | flatpak run me.spaceinbox.swiftynotes cli update 00000000-0000-0000-0000-000000000000 --stdin
    ```

    > If you created the optional wrapper above, replace the `flatpak run me.spaceinbox.swiftynotes` prefix with `swiftynotes`.
    """
}
