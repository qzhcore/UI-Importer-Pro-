# Artwork storage

The plugin offers two image storage modes, independently of Editable layers versus
Reference image. Native Roblox text and shapes do not need image uploads.

| Mode | Behavior | Intended use |
| --- | --- | --- |
| Session preview (default) | Creates temporary, DataModel-scoped image content. It does not upload image assets. | Inspect an import during the current Studio session. |
| Upload to Roblox | Uploads each unique image tile and assigns an `rbxassetid://` reference. | Prepare persistent artwork for a saved or published experience. |

Roblox documents `CreateDataModelContentAsync` as ephemeral. It is not an embedded
image-file format. `CreateAssetAsync` supports image uploads from EditableImage,
but currently only from **locally loaded plugins**. These are different storage
paths; an upload error never silently falls back to a temporary preview.
See the [official AssetService reference](https://create.roblox.com/docs/reference/engine/classes/AssetService).

## Using persistent images

1. Install the built `.rbxm` in Studio's local Plugins Folder and restart Studio.
2. Choose Editable layers or Reference image.
3. Switch Images to **Upload to Roblox**.
4. Choose **Experience creator** or **My account**. The experience owner requires
   a published place and permission to upload for that user or group.
5. Import the design. This action sends image tiles and layer-derived asset names
   to Roblox. Images over 1024 pixels are split into multiple tiles.
6. Review Output and test moderation, experience permissions, save/reopen, and a
   published client before shipping.

The root's `UIImporterImageStorage` attribute records `Session`, `RobloxAsset`, or
`None`. Uploaded image instances record `UIImporterAssetId`.

## Cancellation and failures

The generated tree is built outside the place and attached only after a successful
import. An import can be cancelled between decoding, building, and image API calls.
An in-flight Roblox API call must finish before cancellation can be processed.

Uploading is a remote operation. Cancelling or undoing the generated UI cannot
delete assets already created on Roblox. The importer records every successful
upload before checking cancellation and reports retained IDs in Output on failure.
Review those assets in Creator Dashboard. Reimporting creates new assets; persistent
cross-import deduplication is not implemented.

## Creator Store release gate

This upload path makes the local-plugin build testable; it does not establish a
supported upload path for a plugin installed from Creator Store. Before distributing
there, implement and validate a supported asset workflow, such as a companion
exporter/uploader with appropriate authentication and ownership controls. Do not
advertise session previews as persistent artwork.
