import urllib.request
import os

def fetch_defs():
    url = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau"
    print("Fetching Roblox Type Definitions...")
    
    try:
        with urllib.request.urlopen(url) as response:
            data = response.read().decode('utf-8')
            with open("globalTypes.d.luau", "w") as f:
                f.write(data)
        print("Successfully generated globalTypes.d.luau")
    except Exception as e:
        print(f"Failed to fetch definitions: {e}")

if __name__ == "__main__":
    fetch_defs()
