![Deimos splash](https://i.postimg.cc/zfsnyt8s/deimos-splash.png)

# Deimos

Deimos is a script for Entry Poin with a more than 65 commands which allows you to do impossible things, simplify the missions playthrough and use the vulnerabilities of this game as much as possible.

## Script
```luau
loadstring(game:HttpGet("https://raw.githubusercontent.com/deimos-ep/deimos/refs/heads/main/compiled.luau"))()
```

## Build
DarkLua is used to develop Deimos. More info about DarkLua: <https://https://darklua.com/>

To compile all modules into a single file, run this command from the project's root directory:
```powershell
./darklua.exe process ./source/main/core.luau compiled.luau
```

## Development enviroment
The script is developed in VS Code with the [Luau language server](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp) extension.
