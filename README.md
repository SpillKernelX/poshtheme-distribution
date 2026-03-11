# PoshTheme Distribution

Public distribution channel for `poshtheme`.

This repository is intentionally minimal:

- it contains the public bootstrap installer
- it contains release metadata and release assets
- it does not contain the private source repository tree

## Install

```powershell
irm "https://raw.githubusercontent.com/SpillKernelX/poshtheme-distribution/main/install.ps1" | iex
```

That installer downloads the latest public release asset, extracts it into:

```text
$HOME\My Coding Projects\posh-theme-browser
```

and then runs the packaged installer locally.

## Options

If you need to pass options, use the scriptblock form:

```powershell
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/SpillKernelX/poshtheme-distribution/main/install.ps1"))) `
  -InstallRoot "$HOME\\My Coding Projects\\posh-theme-browser" `
  -SkipProfileUpdate `
  -AllowMissingFzf
```

## Notes

- The packaged install still requires `oh-my-posh`, Python 3, and `fzf`.
- Re-running the public installer updates an existing managed install in place.
- The public installer refuses to overwrite unrelated folders unless `-Force` is passed.
