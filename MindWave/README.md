# NeuroSky Windows Developer Tools Mirror

This directory keeps the extracted runtime files that are needed by the repository from NeuroSky Windows Developer Tools 3.2.

## Official source

There is no known official direct download URL for `Windows-Developer-Tools-3.2.zip`.

The official way to obtain that archive is the NeuroSky store/cart flow at:

`https://store.neurosky.com/collections/developer-tools-3`

## Preferred repository flow

`scripts\win_sdk_download.bat` first tries the GitHub release mirror in `Keksov/VendorsCore`.

When that mirror is available, the script also uses the digest published in GitHub release metadata.

## Manual fallback if the GitHub mirror is removed

If `Windows-Developer-Tools-3.2.zip` is no longer present in the GitHub releases, obtain the ZIP manually from the NeuroSky store flow above.

Do not unpack the archive yourself.

Place the original ZIP at:

`scripts\downloads\Windows-Developer-Tools-3.2.zip`

Then rerun:

`scripts\win_sdk_download.bat`

The committed fallback digest file:

`scripts\downloads\Windows-Developer-Tools-3.2.zip.digest`

is only used for that missing-release fallback path. It is not the primary digest source while the GitHub mirror is still available.