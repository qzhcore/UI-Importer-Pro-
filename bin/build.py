import subprocess


def build():
    print("Starting specialized build process...")

    try:
        subprocess.run(
            ["rojo", "build", "default.project.json", "--output", "UIImporterPro.rbxm"],
            check=True,
        )
        print("Build successful: UIImporterPro.rbxm created.")
    except Exception as e:
        print(f"Build failed: {e}")

if __name__ == "__main__":
    build()
