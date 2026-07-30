# Steam Auto-Update Optimizer (GUI Version)

A fast, visual tool that configures all your installed Steam games to your preferred update settings in just one click. 

Built entirely in PowerShell so it runs natively on Windows with no extra installations required.

## Features
- **Graphical User Interface (GUI):** A clean, dark-themed visual interface makes it incredibly easy to use.
- **Customizable Settings:** Choose exactly how you want your games to behave using intuitive dropdown menus that match Steam's exact options (Auto-updates & Background downloads).
- **One-Click Revert:** Made a mistake or want to go back? The built-in Revert button safely sets your entire library back to Steam's default settings instantly.
- **Modern Folder Picker:** Utilizes native Windows APIs to provide the modern Windows 11 Explorer interface for selecting your Steam folder.
- **100% Transparent & Safe:** This script only edits two specific text values (`AutoUpdateBehavior` and `AllowOtherDownloadsWhileRunning`) inside your `.acf` files. It does NOT delete anything, does not touch your actual game data, and does not require an internet connection.
- **Live Logging:** See exactly which games are being updated in real-time within the app.
- **Smart Steam Detection:** The app automatically detects if Steam is running in the background. It will pause execution in a "waiting room" until Steam is completely closed, ensuring no files get corrupted.

## How to use
1. Download the release and extract the files.
2. Double-click the **`Start_Optimizer.bat`** file.
3. If Steam is running, the console will ask you to close it first.
4. Once open, click **Browse...** to select your `steamapps` folder (or leave the default if correct).
5. Select your preferred behavior from the **Automatic Updates** and **Background Downloads** dropdown menus.
6. Click **APPLY SETTINGS**. *(Alternatively, click **REVERT TO DEFAULTS** to undo all changes).*
7. Close the tool and start Steam!
