# Test build: 0.4.0-beta.1

Download [UIImporterPro.rbxm](https://github.com/qzhcore/UI-Importer-Pro-/raw/refs/heads/refactor/studio-import-pipeline/dist/UIImporterPro.rbxm)
from the **refactor/studio-import-pipeline** branch. This build is separate from
the older release shown by GitHub's Latest release link.

1. In Studio, use **Plugins → Plugins Folder** to open your local plugin folder.
2. Move the previous UI Importer plugin file out of that folder so only one copy
   loads, then copy the downloaded UIImporterPro.rbxm into it.
3. Restart Studio and create a **separate empty test place**.
4. Open UI Importer Pro. Start with **Create new**, **Editable layers**,
   **Preserve aspect**, **Session preview**, and **Document background: Excluded**.
5. Download [responsive-menu.json](../examples/responsive-menu.json) and select it
   through **Import Design File**. It uses native shapes and text, with no uploads.
6. Inspect the menu at phone, tablet, 1920×1080, and 3840×2160 sizes. The gray
   document backdrop should be absent. Try Adaptive as a separate new import.
7. Add a LocalScript and a custom attribute to the Title. Change its text/color
   in the JSON without changing its ID or documentId. Select the imported root,
   choose **Update selected import**, and import the modified JSON.
8. Confirm the same Title instance and your script/attribute remain; use Studio
   Undo/Redo once to verify the operation.
9. Test a copy of your PSD/FIG. Review Output and UIImporterWarning attributes.

You can test the core importer now after installing this build. This is **not a
production fidelity sign-off**. Private PSD/FIG visual comparisons previously
showed missing complex effects and font differences. Background removal is
conservative, not image segmentation. Arbitrary desktop layouts do not
automatically become usable portrait designs.

Session preview artwork does not survive restarting Studio. Persistent upload
mode sends assets to Roblox and requires owner access/moderation. End-to-end
persistent upload and Creator Store distribution remain release checks.
See [artwork storage](ARTWORK_STORAGE.md) and [architecture](ARCHITECTURE.md).
