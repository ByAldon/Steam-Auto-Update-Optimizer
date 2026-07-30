<#
.SYNOPSIS
    Steam Game Update Optimizer - GUI Version
#>

Clear-Host
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "          Steam Game Update Optimizer" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host ""

# --- 1. SMART STEAM DETECTION (WAITING ROOM) ---
$steamIsRunning = @(Get-Process -Name "steam" -ErrorAction SilentlyContinue).Count -gt 0
if ($steamIsRunning) {
    Write-Host "[!] WARNING: Steam is currently running." -ForegroundColor Red
    Write-Host "This tool cannot safely modify files while Steam is open." -ForegroundColor Red
    Write-Host "Please close Steam completely (Right-click Steam in your taskbar -> Exit)." -ForegroundColor Yellow
    Write-Host ""
    
    while ($steamIsRunning) {
        Write-Host "Waiting for Steam to close... " -NoNewline -ForegroundColor DarkGray
        Start-Sleep -Seconds 3
        $steamIsRunning = @(Get-Process -Name "steam" -ErrorAction SilentlyContinue).Count -gt 0
        if (-not $steamIsRunning) {
            Write-Host "Closed!" -ForegroundColor Green
        } else {
            Write-Host "Still open." -ForegroundColor Red
        }
    }
    Write-Host ""
}

# --- 2. LOAD .NET FRAMEWORK ---
Write-Host "[*] Loading .NET UI Framework... " -NoNewline
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
Write-Host "Done!" -ForegroundColor Green

# --- 3. COMPILE NATIVE C# APIs ---
Write-Host "[*] Compiling Native Components... " -NoNewline
$csharpCode = @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}

public class ModernFolderPicker {
    [ComImport, Guid("DC1C5A9C-E88A-4dde-B5A1-60F82A20AEF7")]
    private class FileOpenDialog {}

    [ComImport, Guid("43826D1E-E718-42EE-BC55-A1E261C37BFE"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IShellItem {
        void BindToHandler([In] IntPtr pbc, [In] ref Guid bhid, [In] ref Guid riid, out IntPtr ppv);
        void GetParent(out IShellItem ppsi);
        void GetDisplayName([In] uint sigdnName, [MarshalAs(UnmanagedType.LPWStr)] out string ppszName);
        void GetAttributes([In] uint sfgaoMask, out uint psfgaoAttribs);
        void Compare([In, MarshalAs(UnmanagedType.Interface)] IShellItem psi, [In] uint hint, out int piOrder);
    }

    [ComImport, Guid("42f85136-db7e-439c-85f1-e4075d135fc8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IFileOpenDialog {
        [PreserveSig] uint Show([In] IntPtr hwndOwner);
        void SetFileTypes([In] uint cFileTypes, [In] IntPtr rgFilterSpec);
        void SetFileTypeIndex([In] uint iFileType);
        void GetFileTypeIndex(out uint piFileType);
        void Advise([In, MarshalAs(UnmanagedType.Interface)] IntPtr pfde, out uint pdwCookie);
        void Unadvise([In] uint dwCookie);
        void SetOptions([In] uint fos);
        void GetOptions(out uint pfos);
        void SetDefaultFolder([In, MarshalAs(UnmanagedType.Interface)] IShellItem psi);
        void SetFolder([In, MarshalAs(UnmanagedType.Interface)] IShellItem psi);
        void GetFolder([MarshalAs(UnmanagedType.Interface)] out IShellItem ppsi);
        void GetCurrentSelection([MarshalAs(UnmanagedType.Interface)] out IShellItem ppsi);
        void SetFileName([In, MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetFileName([MarshalAs(UnmanagedType.LPWStr)] out string pszName);
        void SetTitle([In, MarshalAs(UnmanagedType.LPWStr)] string pszTitle);
        void SetOkButtonLabel([In, MarshalAs(UnmanagedType.LPWStr)] string pszText);
        void SetFileNameLabel([In, MarshalAs(UnmanagedType.LPWStr)] string pszLabel);
        void GetResult([MarshalAs(UnmanagedType.Interface)] out IShellItem ppsi);
        void AddPlace([In, MarshalAs(UnmanagedType.Interface)] IShellItem psi, uint fdap);
        void SetDefaultExtension([In, MarshalAs(UnmanagedType.LPWStr)] string pszDefaultExtension);
        void Close([MarshalAs(UnmanagedType.Error)] int hr);
        void SetClientGuid([In] ref Guid guid);
        void ClearClientData();
        void SetFilter([MarshalAs(UnmanagedType.Interface)] IntPtr pFilter);
        void GetResults([MarshalAs(UnmanagedType.Interface)] out IntPtr ppenum);
        void GetSelectedItems([MarshalAs(UnmanagedType.Interface)] out IntPtr ppsai);
    }

    public static string ShowDialog(IntPtr hwndOwner) {
        try {
            IFileOpenDialog dialog = (IFileOpenDialog)new FileOpenDialog();
            dialog.SetTitle("Select your Steamapps folder");
            dialog.SetOptions(0x00000020 | 0x00000008); // FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM
            uint hr = dialog.Show(hwndOwner);
            if (hr == 0) {
                IShellItem item;
                dialog.GetResult(out item);
                string path;
                item.GetDisplayName(0x80058000, out path); // SIGDN_FILESYSPATH
                return path;
            } else {
                return "CANCEL";
            }
        } catch {
            return "ERROR";
        }
    }
}
"@

$modernPickerLoaded = $false
try {
    Add-Type -TypeDefinition $csharpCode -ErrorAction Stop
    $modernPickerLoaded = $true
} catch {
    # Fallback to older picker if compilation is blocked
}
Write-Host "Done!" -ForegroundColor Green

# --- 4. BUILD INTERFACE ---
Write-Host "[*] Building Graphical Interface... " -NoNewline
$form = New-Object System.Windows.Forms.Form
$form.Text = "Steam Update Optimizer"
$form.Size = New-Object System.Drawing.Size(650, 600)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(255, 36, 40, 47)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$fontTitle = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$fontNormal = New-Object System.Drawing.Font("Segoe UI", 10)
$fontSmall = New-Object System.Drawing.Font("Segoe UI", 9)

$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "Steam Game Update Optimizer"
$lblTitle.Font = $fontTitle
$lblTitle.AutoSize = $true
$lblTitle.Location = New-Object System.Drawing.Point(20, 15)
$form.Controls.Add($lblTitle)

$lblNote = New-Object System.Windows.Forms.Label
$lblNote.Text = "Safely modifies your local Steam settings. Does not delete game data or use the internet."
$lblNote.Font = $fontSmall
$lblNote.ForeColor = [System.Drawing.Color]::LightGray
$lblNote.AutoSize = $true
$lblNote.Location = New-Object System.Drawing.Point(23, 45)
$form.Controls.Add($lblNote)

$lblPath = New-Object System.Windows.Forms.Label
$lblPath.Text = "Steamapps Folder Location:"
$lblPath.Font = $fontNormal
$lblPath.AutoSize = $true
$lblPath.Location = New-Object System.Drawing.Point(20, 80)
$form.Controls.Add($lblPath)

$txtPath = New-Object System.Windows.Forms.TextBox
$txtPath.Location = New-Object System.Drawing.Point(24, 105)
$txtPath.Size = New-Object System.Drawing.Size(480, 25)
$txtPath.Font = $fontNormal
$txtPath.Text = "C:\Program Files (x86)\Steam\steamapps"
$form.Controls.Add($txtPath)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(515, 104)
$btnBrowse.Size = New-Object System.Drawing.Size(95, 27)
$btnBrowse.Font = $fontNormal
$btnBrowse.BackColor = [System.Drawing.Color]::FromArgb(255, 60, 65, 75)
$btnBrowse.FlatStyle = "Flat"
$btnBrowse.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnBrowse)

# --- COMBOBOXES FOR SETTINGS ---
$lblAutoUpdate = New-Object System.Windows.Forms.Label
$lblAutoUpdate.Text = "Automatic Updates:"
$lblAutoUpdate.Font = $fontNormal
$lblAutoUpdate.AutoSize = $true
$lblAutoUpdate.Location = New-Object System.Drawing.Point(20, 145)
$form.Controls.Add($lblAutoUpdate)

$cmbAutoUpdate = New-Object System.Windows.Forms.ComboBox
$cmbAutoUpdate.Location = New-Object System.Drawing.Point(24, 170)
$cmbAutoUpdate.Size = New-Object System.Drawing.Size(280, 25)
$cmbAutoUpdate.Font = $fontNormal
$cmbAutoUpdate.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbAutoUpdate.Items.Add("Let Steam decide when to update (Default)")
$cmbAutoUpdate.Items.Add("Wait until I launch the game")
$cmbAutoUpdate.Items.Add("Immediately download updates (Priority)")
$cmbAutoUpdate.SelectedIndex = 2 # Default to High Priority
$form.Controls.Add($cmbAutoUpdate)

$lblBackground = New-Object System.Windows.Forms.Label
$lblBackground.Text = "Background Downloads:"
$lblBackground.Font = $fontNormal
$lblBackground.AutoSize = $true
$lblBackground.Location = New-Object System.Drawing.Point(326, 145)
$form.Controls.Add($lblBackground)

$cmbBackground = New-Object System.Windows.Forms.ComboBox
$cmbBackground.Location = New-Object System.Drawing.Point(330, 170)
$cmbBackground.Size = New-Object System.Drawing.Size(280, 25)
$cmbBackground.Font = $fontNormal
$cmbBackground.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$cmbBackground.Items.Add("Follow global Steam settings (Default)")
$cmbBackground.Items.Add("Always allow background downloads")
$cmbBackground.Items.Add("Never allow background downloads")
$cmbBackground.SelectedIndex = 1 # Default to Always Allow
$form.Controls.Add($cmbBackground)

# --- LISTBOX ---
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Location = New-Object System.Drawing.Point(24, 215)
$listBox.Size = New-Object System.Drawing.Size(586, 250)
$listBox.Font = New-Object System.Drawing.Font("Consolas", 10)
$listBox.BackColor = [System.Drawing.Color]::FromArgb(255, 20, 20, 25)
$listBox.ForeColor = [System.Drawing.Color]::LightGreen
$listBox.BorderStyle = "FixedSingle"
$form.Controls.Add($listBox)

function Log-Message([string]$Message) {
    $listBox.Items.Add($Message) | Out-Null
    $listBox.TopIndex = $listBox.Items.Count - 1
    $form.Refresh()
}

# --- BUTTONS ---
$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "APPLY SETTINGS"
$btnApply.Location = New-Object System.Drawing.Point(24, 485)
$btnApply.Size = New-Object System.Drawing.Size(280, 45)
$btnApply.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnApply.BackColor = [System.Drawing.Color]::FromArgb(255, 40, 150, 60)
$btnApply.FlatStyle = "Flat"
$btnApply.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnApply)

$btnRevert = New-Object System.Windows.Forms.Button
$btnRevert.Text = "REVERT TO DEFAULTS"
$btnRevert.Location = New-Object System.Drawing.Point(330, 485)
$btnRevert.Size = New-Object System.Drawing.Size(280, 45)
$btnRevert.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$btnRevert.BackColor = [System.Drawing.Color]::FromArgb(255, 180, 100, 30)
$btnRevert.FlatStyle = "Flat"
$btnRevert.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnRevert)


# --- EVENT HANDLERS ---
$btnBrowse.Add_Click({
    $selectedPath = "ERROR"

    # 1. Try Modern Windows 11 Explorer Picker
    if ($modernPickerLoaded) {
        try {
            $selectedPath = [ModernFolderPicker]::ShowDialog($form.Handle)
        } catch {
            $selectedPath = "ERROR"
        }
    }

    # 2. Check Result
    if ($selectedPath -eq "CANCEL") {
        return # User just clicked cancel, do nothing.
    }
    
    if ($selectedPath -ne "ERROR" -and -not [string]::IsNullOrWhiteSpace($selectedPath)) {
        $txtPath.Text = $selectedPath
        return
    }

    # 3. Bulletproof Fallback (Classic Tree Picker) if modern picker failed
    $browser = New-Object System.Windows.Forms.FolderBrowserDialog
    $browser.Description = "Select your Steamapps folder"
    if ($txtPath.Text -and (Test-Path $txtPath.Text)) {
        $browser.SelectedPath = $txtPath.Text
    }
    if ($browser.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtPath.Text = $browser.SelectedPath
    }
})

function Execute-SteamUpdate {
    param(
        [string]$autoUpdateVal,
        [string]$allowBgVal,
        [string]$actionName
    )

    $listBox.Items.Clear()
    $path = $txtPath.Text.Trim()

    if (-not (Test-Path $path)) {
        [System.Windows.Forms.MessageBox]::Show($form, "The selected folder does not exist. Please check the path.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $steamIsRunning = @(Get-Process -Name "steam" -ErrorAction SilentlyContinue).Count -gt 0
    if ($steamIsRunning) {
        $msgResult = [System.Windows.Forms.MessageBox]::Show($form, "Steam is currently running and must be closed to apply updates.`n`nWould you like to close Steam automatically now?", "Steam is Running", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        
        if ($msgResult -eq [System.Windows.Forms.DialogResult]::Yes) {
            Log-Message "Closing Steam cleanly..."
            try {
                Stop-Process -Name "steam" -Force
                Start-Sleep -Seconds 3
                Log-Message "Steam closed."
            } catch {
                [System.Windows.Forms.MessageBox]::Show($form, "Could not close Steam automatically. Please close it via the taskbar.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return
            }
        } else {
            Log-Message "Process cancelled. Steam must be closed."
            return
        }
    }

    Log-Message "Scanning folder for games..."
    $acfFiles = Get-ChildItem -Path $path -Filter "appmanifest_*.acf" -ErrorAction SilentlyContinue

    if (-not $acfFiles -or $acfFiles.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show($form, "No Steam games (.acf files) found in this folder.", "No Games Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }

    $updated = 0
    $failed = 0

    foreach ($file in $acfFiles) {
        try {
            $content = Get-Content $file.FullName -Raw -Encoding UTF8
            $gameName = "Unknown Game ($($file.Name))"
            
            if ($content -match '(?i)"name"\s*"([^"]+)"') {
                $gameName = $matches[1]
            }

            if ($content -match '"AutoUpdateBehavior"\s*"\d+"') {
                $content = $content -replace '"AutoUpdateBehavior"\s*"\d+"', "`"AutoUpdateBehavior`"`t`t`"$autoUpdateVal`""
            } else {
                $content = $content -replace '("StateFlags"[^\n]+\n)', "`$1`t`"AutoUpdateBehavior`"`t`t`"$autoUpdateVal`"`n"
            }

            if ($content -match '"AllowOtherDownloadsWhileRunning"\s*"\d+"') {
                $content = $content -replace '"AllowOtherDownloadsWhileRunning"\s*"\d+"', "`"AllowOtherDownloadsWhileRunning`"`t`t`"$allowBgVal`""
            } else {
                $content = $content -replace '("StateFlags"[^\n]+\n)', "`$1`t`"AllowOtherDownloadsWhileRunning`"`t`t`"$allowBgVal`"`n"
            }

            Set-Content $file.FullName -Value $content -NoNewline -Encoding UTF8 -ErrorAction Stop
            $updated++
            Log-Message " -> $($actionName): $gameName"
        } catch {
            $failed++
            Log-Message " -> [ERROR] Failed to update: $($file.Name)"
        }
    }

    Log-Message "======================================================"
    Log-Message "ALL DONE! Successfully processed $updated games."
    if ($failed -gt 0) { Log-Message "$failed games failed to update." }
    Log-Message "Settings are saved. You can now close this tool and launch Steam."
    
    [System.Windows.Forms.MessageBox]::Show($form, "Successfully processed $updated games.`n`nYou can launch Steam now.", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}

$btnApply.Add_Click({
    $autoVal = $cmbAutoUpdate.SelectedIndex.ToString()
    $bgVal = $cmbBackground.SelectedIndex.ToString()
    Execute-SteamUpdate -autoUpdateVal $autoVal -allowBgVal $bgVal -actionName "Applied"
})

$btnRevert.Add_Click({
    # Reset dropdown menus to visual defaults as well
    $cmbAutoUpdate.SelectedIndex = 0
    $cmbBackground.SelectedIndex = 0
    $form.Refresh()

    # Pass '0' '0' directly
    Execute-SteamUpdate -autoUpdateVal "0" -allowBgVal "0" -actionName "Reverted"
})

Write-Host "Done!" -ForegroundColor Green

Log-Message "Ready. Select your desired settings and click Apply."

# --- 5. LAUNCH GUI ---
Write-Host "`nLaunching UI..." -ForegroundColor Cyan
Start-Sleep -Milliseconds 400

# Completely hide the CMD window just as the GUI opens
if ($modernPickerLoaded) {
    $hwnd = [Win32]::GetConsoleWindow()
    if ($hwnd -ne [IntPtr]::Zero) {
        [Win32]::ShowWindow($hwnd, 0) | Out-Null
    }
}

$form.ShowDialog() | Out-Null
