run file="":
    nvim -u tests/init.lua {{ file }}

fmt:
    stylua lua/ --config-path=.stylua.toml
