$scriptDir = $PSScriptRoot

$Env:XDG_CONFIG_HOME = $Env:XDG_CONFIG_HOME ?? "$Env:USERPROFILE/.config"
$Env:EDITOR = "nvim"

# Configure Yazi to open files correctly on Windows.
# See:
#   https://yazi-rs.github.io/docs/installation#windows
$Env:YAZI_FILE_ONE = "C:\Program Files\Git\usr\bin\file.exe"
$Env:YAZI_CONFIG_HOME="$Env:XDG_CONFIG_HOME/yazi"

# FZF configurations
$Env:FZF_DEFAULT_COMMAND = 'es count:100' # Use Everything CLI by default
$Env:FZF_DEFAULT_OPTS = '--height 40% --layout=reverse --border' # Set fzf UI options
$Env:FZF_CUSTOM_PREVIEW = 'pwsh -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -Command "if (Test-Path -Path "{}" -PathType Container) { eza --tree --level=1 --colour=always --icons=always "{}" } else { bat --color=always --style=numbers --line-range=:500 "{}" }"'

$Env:BAT_PAGER = "less" # On Windows, see: https://github.com/jftuga/less-Windows
$Env:BAT_THEME = "gruvbox-light"

# Escape " with "". As fzf on Windows uses cmd by default
$Env:ZOXIDE_FZF_CUSTOM_PREVIEW = 'pwsh -NoProfile -NonInteractive -NoLogo -ExecutionPolicy Bypass -Command "eza --tree --level=1 --colour=always --icons=always ("{}" -replace ""[^\t]+\t"", """")"'
$Env:_ZO_FZF_OPTS = "--preview='$Env:ZOXIDE_FZF_CUSTOM_PREVIEW'"

$Env:RIPGREP_CONFIG_PATH = "$Env:XDG_CONFIG_HOME/.ripgreprc"

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

function Invoke-Eza {
    & eza --oneline --tree --level 1 -A @args
}
Set-Alias -Name ls -Value Invoke-Eza

function Invoke-Bat {
    & bat --color=always --style=numbers @args
}
Set-Alias -Name cat -Value Invoke-Bat

Import-Module "$scriptDir/Modules/LeaderMenu"

Import-Module Terminal-Icons

Invoke-Expression (&starship init powershell)

# Hook into Starship so that when spawning Wezterm panes, it'd automatically
# navigate to the current working directory that Powershell was in.
# See:
#   https://wezterm.org/shell-integration.html#osc-7-on-windows-with-powershell-with-starship
$prompt = ""
function Invoke-Starship-PreCommand {
    $current_location = $executionContext.SessionState.Path.CurrentLocation
    if ($current_location.Provider.Name -eq "FileSystem") {
        $ansi_escape = [char]27
        $provider_path = $current_location.ProviderPath -replace "\\", "/"
        $prompt = "$ansi_escape]7;file://${env:COMPUTERNAME}/${provider_path}$ansi_escape\"

        # See:
        #   https://www.reddit.com/r/wezterm/comments/1fztaj8/comment/lr97ry9/?utm_source=share&utm_medium=web3x&utm_name=web3xcss&utm_term=1&utm_content=share_button
        $title = GetCurrentDir($current_location)
        $title = "📂 " + $title
        wezterm cli set-tab-title $title;
    }
    $host.ui.Write($prompt)
}

function GetCurrentDir {
    param (
      [string]$path = ""
    )
    if ($path -eq "") {
      $path = Get-Location
    }

    if ($path -eq "$env:USERPROFILE") {
      return "~"
    }

    return Split-Path ($path) -Leaf 
}


# Yazi File Manager
# See:
#   https://yazi-rs.github.io/docs/quick-start#shell-wrapper
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    $cwd = Get-Content -Path $tmp -Encoding UTF8
    if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
        Set-Location -LiteralPath ([System.IO.Path]::GetFullPath($cwd))
    }
    Remove-Item -Path $tmp
}

Invoke-Expression (& { (zoxide init powershell | Out-String) })

# [S]earching globally

function Search-ZoxideDirectories {
  zoxide query --interactive
}
# Usage example:
#   nvim (sz)
#   explorer (sz)
#   cd (sz)
Set-Alias -Name sz -Value Search-ZoxideDirectories
Set-Alias -Name qq -Value Search-ZoxideDirectories

function Search-Query {
    # Pipe null to disable the initial unnecessary search upon entering fzf
    $null | fzf --bind "change:reload(es -sort date-modified-descending count:100 {q:1} {q:2} {q:3} {q:4} {q:5} {q:6} {q:7} {q:8} {q:9})" --phony --query "" --header="Search - Query"
}
Set-Alias -Name ss -Value Search-Query
Set-Alias -Name sq -Value Search-Query

function Search-ObsidianNotes {
    fd . "$Env:USERPROFILE\Documents\Note Taking" | fzf --header="Search - Obsidian Notes" --preview $Env:FZF_CUSTOM_PREVIEW
}
Set-Alias -Name so -Value Search-ObsidianNotes

function Search-GitRepositories {
    es -r folder:^\.git$ !"*RECYCLE*\*" !"C:\Program*\*" | ForEach-Object { Split-Path $_ -Parent } | fzf --header="Search - Git Repositories" --preview $Env:FZF_CUSTOM_PREVIEW
}
Set-Alias -Name sg -Value Search-GitRepositories

function Search-Recents {
    # Pipe null to disable the initial unnecessary search upon entering fzf
    $null | fzf --bind "change:reload(es -sort date-modified-descending count:100 dm:thisweek {q:1} {q:2} {q:3} {q:4} {q:5} {q:6} {q:7} {q:8} {q:9})" --phony --query "" --header="Search - Recents"
}
# Usage example: nvim (sr)
Set-Alias -Name sr -Value Search-Recents

function Search-History {
    $history = [Microsoft.PowerShell.PSConsoleReadLine]::GetHistoryItems() | 
        ForEach-Object {
            # Clean up all types of line breaks and replace with pipe
            $_.CommandLine -replace "`r`n|`n|`r", " | "
        } | Select-Object -Unique

    $selected = $history | fzf --tac --header="Search - Command History"
    if ($selected) {
        $cleanCommand = $selected -replace " \| ", "`n"
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($cleanCommand)
    }
}
Set-Alias -Name sh -Value Search-History
$searchHistoryScript = { Search-History }
Set-PSReadLineKeyHandler -Key 'Ctrl+r' -ScriptBlock $searchHistoryScript

$global:LeaderSBindings = @(
  @{
    Key = 'z'
    Desc = '[Z]oxide'
    Action = { Search-ZoxideDirectories }
    Openers = $global:Openers.All
  },
  @{
    Key = 's'
    Desc = '[S]earch'
    Action = { Search-Query }
    Openers = $global:Openers.All
  },
  @{
    Key = 'o'
    Desc = '[O]bsidian Notes'
    Action = { Search-ObsidianNotes }
    Openers = $global:Openers.All
  },
  @{
    Key = 'g'
    Desc = '[G]it Repositories'
    Action = { Search-GitRepositories }
    Openers = $global:Openers.All
  },
  @{
    Key = 'r'
    Desc = '[R]ecents'
    Action = { Search-Recents }
    Openers = $global:Openers.All
  },
  @{
    Key = 'h'
    Desc = 'Command [H]istory'
    Action = $searchHistoryScript
  }
)

Set-PSReadLineKeyHandler -Key Ctrl+s -ScriptBlock {
  Show-LeaderMenu -Bindings $global:LeaderSBindings -Title '[S]earch globally'
}

# [F]ind locally

function Find-Files {
    fd | fzf --tac --header="Find - In Current Directory" --preview $Env:FZF_CUSTOM_PREVIEW
}
Set-Alias -Name ff -Value Find-Files

function Find-GitRepositoryFiles {
  $repoRoot = "$((git rev-parse --show-toplevel) -replace '/', '\')"
  $repoFiles = fd "" $repoRoot
  $coloredFiles = $repoFiles | ForEach-Object {
    $fullPath = $_
    $relativePath = $fullPath.Substring($repoRoot.Length).TrimStart('\')
    $coloredRelative = "`e[36m$relativePath`e[0m"
    $displayLine = $fullPath -replace [regex]::Escape($relativePath), $coloredRelative
    return $displayLine
  }
  return $coloredFiles | fzf --tac --header="Find - In Current Repository" --ansi --preview $Env:FZF_CUSTOM_PREVIEW
}
Set-Alias -Name fg -Value Find-GitRepoFiles
Set-Alias -Name fr -Value Find-GitRepoFiles

function Search-CodeLine {
    $RG_PREFIX = "rg --column --line-number --no-heading --color=always --smart-case"

    return fzf --ansi --disabled --query "" `
        --bind "start:reload:$RG_PREFIX {q}" `
        --bind "change:reload:$RG_PREFIX {q}" `
        --delimiter ":" `
        --preview "bat --color=always {1} --highlight-line {2}" `
        --preview-window "up,60%,border-bottom,+{2}+3/3,~3" `
        --header "Open in Neovim"
}

$neovimCodeLineOpener = @{
  Key = 'n'
  Desc = '[N]eovim'
  Command = {
    param($Selection)
    Write-Host "Selection $Selection"
    if ($Selection) {
      $parts = $Selection -split ':'
      $file = $parts[0]
      $line = $parts[1]

      if ($file -and $line) {
        Write-Host "File and Line: $file $line"
        Start-Process -FilePath "nvim" -ArgumentList "+$line", $file -NoNewWindow -Wait
      }
    }
  }
}

$global:LeaderFBindings = @(
  @{
    Key = 'f'
    Desc = '[F]iles'
    Action = { Find-Files }
    Openers = $global:Openers.All
  },
  @{
    Key = 'g'
    Desc = 'Files in [G]it Repository'
    Action = { Find-GitRepositoryFiles }
    Openers = $global:Openers.All
  },
  @{
    Key = 'c'
    Desc = 'File [C]ontent'
    Action = { Search-CodeLine }
    Openers = @($neovimCodeLineOpener)
  }
)

Set-PSReadLineKeyHandler -Key Ctrl+f -ScriptBlock {
  Show-LeaderMenu -Bindings $global:LeaderFBindings -Title '[F]ind locally'
}


# Git branch picker
# E.g:
#   git checkout (gbr)
function Select-GitBranch {
    git branch -a --color=always | fzf --ansi --header="Git - Branches" | ForEach-Object {
        $_.Trim() -replace '^\*\s*', '' -replace '^remotes/', '' -replace '\x1b\[[0-9;]*m', ''
    }
}
$gitBranchScript = {
    $branch = Select-GitBranch
    if ($branch) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($branch) }
}
Set-Alias -Name gb -Value Select-GitBranch

# Git commit picker
# E.g:
#   git show (gco)
#   git cherry-pick (gco)
function Select-GitCommit {
    git log --color=always --pretty=format:"%C(yellow)%h%C(reset) %C(green)%ad%C(reset) %s %C(blue)(%an)%C(reset)" --date=short | fzf --ansi --header="Git - Commits" | ForEach-Object { 
        ($_ -replace '\x1b\[[0-9;]*m', '').Split(' ')[0]
    }
}
Remove-Alias -Force -Name gc
Set-Alias -Name gc -Value Select-GitCommit
$gitCommitScript = {
    $commit = Select-GitCommit
    if ($commit) { [Microsoft.PowerShell.PSConsoleReadLine]::Insert($commit) }
}

# Git file picker (modified files)
# E.g:
#   git add (gfi)
function Select-GitFile {
    git status --porcelain | fzf --header="Git - Changed Files" | ForEach-Object { $_.Substring(3) }
}
Set-Alias -Name gf -Value Select-GitFile

# Git log
function Show-GitLog {
    git log --pretty=format:"%C(yellow)%h%Creset %C(green)%ad%Creset %C(bold blue)%an%Creset %C(red)%d%Creset %s %C(dim white)%b%Creset" --date=short --color
}
Remove-Alias -Force -Name gl
Set-Alias -Name gl -Value Select-GitFile
$gitLogScript = {
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Show-GitLog')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

$gitEditGitHubGistsScript = {
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert('gh gist edit')
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
}

$global:LeaderGBindings = @(
  @{
    Key = 't'
    Desc = 'LazyGit [T]UI'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('lazygit')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'f'
    Desc = 'Select git [F]ile'
    Action = { Select-GitFile }
    Openers = $global:Openers.All
  },
  @{
    Key = 'b'
    Desc = 'Select git [B]ranch'
    Action = $gitBranchScript
  },
  @{
    Key = 'c'
    Desc = 'Select git [C]ommit'
    Action = $gitCommitScript
  },
  @{
    Key = 'l'
    Desc = 'Show git [L]og'
    Action = $gitLogScript
  },
  @{
    Key = 'g'
    Desc = 'Edit GitHub [G]ists'
    Action = $gitEditGitHubGistsScript
  }
)

Set-PSReadLineKeyHandler -Key Ctrl+g -ScriptBlock {
  Show-LeaderMenu -Bindings $global:LeaderGBindings -Title '[G]it'
}


$global:LeaderTBindings = @(
  @{
    Key = 'g'
    Desc = 'Lazy[G]it'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('lazygit')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'd'
    Desc = 'Lazy[D]ocker'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('lazydocker')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'p'
    Desc = '[P]osting'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('posting')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  }
)

Set-PSReadLineKeyHandler -Key Ctrl+t -ScriptBlock {
  Show-LeaderMenu -Bindings $global:LeaderTBindings -Title '[T]erminal User Interface (TUI)'
}


function Prompt-RoleOption {
    $role = aichat --list-roles | fzf --header "Roles"
    if ($role) {
        return @("--role", $role)
    } else {
        return @()
    }
}

function Prompt-ModelOption {
    $model = aichat --list-models | fzf --header "Models"
    if ($model) {
        return @("--model", $model)
    } else {
        return @()
    }
}

function Invoke-Aichat {
    if ($args.Count -eq 0 -or ($args.Count -eq 1 -and $args[0] -is [string] -and -not $args[0].StartsWith('-'))) {
        $promptArgs = @()
        $promptArgs += Prompt-ModelOption
        $promptArgs += Prompt-RoleOption
        if ($args.Count -eq 0) {
            & aichat --session @promptArgs
        } else {
            & aichat @promptArgs @args
        }
    } else {
        & aichat @args
    }
}
Set-Alias -Name ai -Value Invoke-Aichat

function Invoke-Aichat-Execute {
    $promptArgs = Prompt-ModelOption
    & aichat @promptArgs --execute @args
}
Set-Alias -Name aie -Value Invoke-Aichat-Execute

function Invoke-Aichat-Code {
    $promptArgs = Prompt-ModelOption
    & aichat @promptArgs --code @args
}
Set-Alias -Name aic -Value Invoke-Aichat-Code

function Invoke-Aichat-Sessions {
    & aichat --session (aichat --list-sessions | fzf --header "Sessions") @args
}
Set-Alias -Name ais -Value Invoke-Aichat-Sessions

function Invoke-Aichat-Rags {
    & aichat --rag (aichat --list-rags | fzf --header "RAGs") @args
}
Set-Alias -Name air -Value Invoke-Aichat-Rags

function Invoke-Aichat-Macros {
    & aichat --macro (aichat --list-macros | fzf --header "Macros") @args
}
Set-Alias -Name aim -Value Invoke-Aichat-Macros

function Review-Structure-Aichat {
    & eza --recurse --tree --git-ignore | aichat --model (aichat --list-models | fzf --header "Models") "Analyze this project structure and suggest improvements in the context of software development."
}

function Review-Changes-Aichat {
    param(
        [string]$SessionName = "code-review-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    )

    Write-Host "Session name: $SessionName"

    $initialPrompt += "I will give you code files, and the git diffs. I want you to review the code change in the context of the full file. Consider:
        1. Does the change make sense given the overall file structure?
        2. Are there any potential issues or improvements?
        3. Does it follow the existing code patterns and style?"

    aichat -s $SessionName $initialPrompt
    git diff --name-only | fzf -m --header "Select multiple with [TAB] and [SHIFT-TAB]" | ForEach-Object {
        $file = $_
        $diff = git diff $file

        $prompt = "Here's the git diff for this file:" + [Environment]::NewLine
        $prompt += $diff

        & aichat --session $SessionName --file $file $prompt
    }
}

function Explain-Code-Aichat {
    param(
        [string]$SessionName = "code-explain-$(Get-Date -Format 'yyyy-MM-dd-HHmm')"
    )

    echo "Session name: $SessionName"

    $RG_PREFIX = "rg --column --line-number --no-heading --color=always --smart-case"

    $result = fzf --ansi --disabled --query "" `
        --bind "start:reload:$RG_PREFIX {q}" `
        --bind "change:reload:$RG_PREFIX {q}" `
        --delimiter ":" `
        --preview "bat --color=always {1} --highlight-line {2}" `
        --preview-window "up,60%,border-bottom,+{2}+3/3,~3" `
        --header "Open in Neovim"

    if ($result) {
        $parts = $result -split ':'
        $file = $parts[0]
        $line = $parts[1]

        if ($file -and $line) {
            & aichat --session $SessionName --file $file "Explain the code in line $line of the file I just gave you"
        }
    }
}

$global:LeaderLBindings = @(
  @{
    Key = 'l'
    Desc = '[L]LM'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('ai')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'a'
    Desc = '[A]I'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('ai')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'e'
    Desc = '[E]xecute or copy command from natural language'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('aie')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'c'
    Desc = 'Display [C]ode output from natural language'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('aic')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 's'
    Desc = 'Continue from [S]ession'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('air')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'm'
    Desc = 'Start [M]acro'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('aim')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  }
  @{
    Key = 'S'
    Desc = 'Review Code [S]tructure'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Review-Structure-Aichat')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'C'
    Desc = 'Review Code [C]hanges'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Review-Changes-Aichat')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'E'
    Desc = '[E]xplain Code'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Explain-Code-Aichat')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  }
)

Set-PSReadLineKeyHandler -Key Ctrl+l -ScriptBlock {
  Show-LeaderMenu -Bindings $global:LeaderLBindings -Title '[L]LM AI'
}


function Get-SSHConnections {
    Get-Content "$env:USERPROFILE\.ssh\config" |
        Where-Object { $_ -match '^Host\s+(.+)' } |
        ForEach-Object {
            ($matches[1] -split '\s+') | Where-Object { $_ -notmatch '[*?]' }
        } | Sort-Object -Unique
}
function Connect-SSH {
    $selectedConn = Get-SSHConnections | fzf --tac --header="Connect - SSH"
    ssh $selectedConn
}
Set-Alias -Name cs -Value Connect-SSH

function Open-NetworkDriveWithYazi {
    $networkDrives = net use | Where-Object { $_ -match "sshfs" } | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim("`t `r`n") }
    $selected = $networkDrives | fzf --tac --header="Connect - Unmount Network Drives"
    if ($selected -match '([A-Z]:)') {
        $selectedDrive = $matches[1]
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("y $selectedDrive")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}
Set-Alias -Name cn -Value Open-NetworkDriveWithYazi

function Get-SSHFSCommandsFromConfig {
   $sshConfig = Get-Content ~/.ssh/config
   $hosts = @()
   $currentHost = @{}

   foreach ($line in $sshConfig) {
       $line = $line.Trim()

       if ($line -match '^Host\s+(.+)') {
           if ($currentHost.Count -gt 0) {
               $hosts += $currentHost
           }
           $currentHost = @{
               Host = $matches[1]
               HostName = $null
               User = $null
           }
       }
       elseif ($line -match '^HostName\s+(.+)') {
           $currentHost.HostName = $matches[1]
       }
       elseif ($line -match '^User\s+(.+)') {
           $currentHost.User = $matches[1]
       }
   }

   if ($currentHost.Count -gt 0) {
       $hosts += $currentHost
   }

   $commands = @()
   foreach ($h in $hosts) {
       if ($h.HostName -and $h.User) {
           $commands += "net use \\sshfs.r\$($h.User)@$($h.HostName)"
       }
   }

   return $commands
}
function Mount-NetworkDrives {
    $selected = Get-SSHFSCommandsFromConfig | fzf --tac --header="Connect - Mount Network Drives"
    if ($selected) {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert($selected)
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}
Set-Alias -Name cm -Value Mount-NetworkDrives

function Unmount-NetworkDrives {
    $networkDrives = net use | Where-Object { $_ -match "sshfs" } | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim("`t `r`n") }
    $selected = $networkDrives | fzf --tac --header="Connect - Unmount Network Drives"
    if ($selected -match '([A-Z]:)') {
        $selectedDrive = $matches[1]
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert("net use $selectedDrive /DELETE")
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
}
Set-Alias -Name cu -Value Unmount-NetworkDrives

$global:LeaderNBindings = @(
  @{
    Key = 's'
    Desc = '[S]SH'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Connect-SSH')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'y'
    Desc = '[Y]azi - Open a Network Drive'
    Action = { Open-NetworkDriveWithYazi }
  }
  @{
    Key = 'm'
    Desc = '[M]ount Network Drives'
    Action = { Mount-NetworkDrives }
  },
  @{
    Key = 'u'
    Desc = '[U]nmount Network Drives'
    Action = { Unmount-NetworkDrives }
  }
)

Set-PSReadLineKeyHandler -Key Ctrl+n -ScriptBlock {
  Show-LeaderMenu -Bindings $global:LeaderCBindings -Title '[N]etwork Connections'
}


function Get-CachedJsonFromUrl {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $false)]
        [string]$CacheFilePath = "$env:TEMP\cached_data.json",

        [Parameter(Mandatory = $false)]
        [int]$CacheExpirationHours = 24
    )

    # Create cache metadata file path
    $metadataPath = "$CacheFilePath.metadata"

    # Check if cache file exists and is not expired
    $useCache = $false
    if (Test-Path $CacheFilePath -PathType Leaf) {
        if (Test-Path $metadataPath -PathType Leaf) {
            try {
                $metadata = Get-Content $metadataPath | ConvertFrom-Json

                if ($metadata.timestamp) {
                    # No need to parse - ConvertFrom-Json already converted to DateTime
                    $cacheTime = $metadata.timestamp
                    $expirationTime = $cacheTime.AddHours($CacheExpirationHours)

                    if ([DateTime]::Now -lt $expirationTime) {
                        $useCache = $true
                        Write-Verbose "Using cached data from $CacheFilePath (expires on $expirationTime)"
                    }
                    else {
                        Write-Verbose "Cache expired. Fetching fresh data."
                    }
                }
            }
            catch {
                Write-Warning "Error reading cache metadata: $_"
                # Continue to fetch fresh data
            }
        }
    }

    # Use cached data or fetch fresh data
    if ($useCache) {
        try {
            $data = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Error reading cache data: $_"
            $useCache = $false # Force fetching fresh data
        }
    }

    if (-not $useCache) {
        try {
            # Fetch data from URL - Invoke-RestMethod automatically converts JSON to objects
            $data = Invoke-RestMethod -Uri $Url -Method Get

            # Save data to cache file
            $data | ConvertTo-Json -Depth 100 | Out-File $CacheFilePath -Force

            # Save metadata - PowerShell will automatically convert DateTime to JSON
            @{
                timestamp = [DateTime]::Now
                url = $Url
            } | ConvertTo-Json | Out-File $metadataPath -Force

            Write-Verbose "Fresh data fetched and cached successfully."
        }
        catch {
            # If fetch fails but cache exists, use it regardless of expiration
            if (Test-Path $CacheFilePath -PathType Leaf) {
                Write-Warning "Failed to fetch fresh data. Using expired cache as fallback."
                try {
                    $data = Get-Content $CacheFilePath -Raw | ConvertFrom-Json
                }
                catch {
                    throw "Failed to fetch data and couldn't read cache: $_"
                }
            }
            else {
                throw "Failed to fetch data and no cache available: $_"
            }
        }
    }

    return $data
}

$favoriteCliUri = "https://gist.githubusercontent.com/deltoss/bfe4f567be2f94d217b168058823e372/raw/FavoriteCLICheatsheet.json"
function Get-RandomFavoriteCli {
    try {
        # Fetch the JSON data from the gist
        $response = Get-CachedJsonFromUrl -Url $favoriteCliUri -CacheFilePath "$env:TEMP\FavoriteCLICheatsheet.json" -Verbose

        # Randomly choose between clitools and clicommands
        $choice = Get-Random -InputObject @("clitools", "clicommands")

        if ($choice -eq "clitools") {
            $randomItem = $response.clitools | Get-Random

            Write-Host "`n🔧 Random CLI Tool:" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "Name:        " -NoNewline -ForegroundColor Yellow
            Write-Host $randomItem.name
            Write-Host "Command:     " -NoNewline -ForegroundColor Yellow
            Write-Host $randomItem.command -ForegroundColor Green
            Write-Host "Description: " -NoNewline -ForegroundColor Yellow
            Write-Host $randomItem.description
            if ($randomItem.tags) {
                Write-Host "Tags:        " -NoNewline -ForegroundColor Yellow
                Write-Host ($randomItem.tags -join ", ") -ForegroundColor Magenta
            }
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "`n🔍 Running tldr for: $($randomItem.command)" -ForegroundColor Cyan
            Write-Host ""

            # Run tldr for the selected tool
            tldr --quiet $randomItem.command
        } else {
            $randomItem = $response.clicommands | Get-Random

            Write-Host "`n⚡ Random CLI Command:" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "Name:        " -NoNewline -ForegroundColor Yellow
            Write-Host $randomItem.name
            Write-Host "Command:     " -NoNewline -ForegroundColor Yellow
            Write-Host $randomItem.command -ForegroundColor Green
            Write-Host "Description: " -NoNewline -ForegroundColor Yellow
            Write-Host $randomItem.description
            if ($randomItem.tags) {
                Write-Host "Tags:        " -NoNewline -ForegroundColor Yellow
                Write-Host ($randomItem.tags -join ", ") -ForegroundColor Magenta
            }
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host ""
        }
    } catch {
        Write-Error "Failed to fetch data or run tldr: $($_.Exception.Message)"
        Write-Host "Make sure you have 'tldr' installed and accessible in your PATH" -ForegroundColor Yellow
    }
}

Get-RandomFavoriteCli

function Search-Tldr {
    $selected = tldr --list | fzf --prompt="🔧 Select a CLI tool > " --height=20 --border --preview-window=wrap --preview="echo {}" --header="Use ↑↓ to navigate, Enter to select, Esc to cancel"

    & tldr $selected
}

function Search-FavoriteCliTools {
    try {
        # Fetch the JSON data from the gist
        $response = Get-CachedJsonFromUrl -Url $favoriteCliUri -CacheFilePath "$env:TEMP\FavoriteCLICheatsheet.json" -Verbose

        # Format CLI tools for fzf
        $items = $response.clitools | ForEach-Object {
            if ($_.name -ceq $_.command) {
                "$($_.command) | $($_.description)"
            } else {
                "$($_.name) | $($_.command) | $($_.description)"
            }
        }

        # Use fzf to select a tool
        $selected = $items | fzf --prompt="🔧 Select a CLI tool > " --height=20 --border --preview-window=wrap --preview="echo {}" --header="Use ↑↓ to navigate, Enter to select, Esc to cancel"

        if ($selected) {
            # Parse the selected item
            $parts = $selected -split " \| "
            if ($parts.Count -eq 2) {
                $name = $parts[0]
                $command = $parts[0]  # Same as name
                $description = $parts[1]
            } else {
                $name = $parts[0]
                $command = $parts[1]
                $description = $parts[2]
            }

            Write-Host "`n🔧 Selected CLI Tool:" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "Name:        " -NoNewline -ForegroundColor Yellow
            Write-Host $name
            Write-Host "Command:     " -NoNewline -ForegroundColor Yellow
            Write-Host $command -ForegroundColor Green
            Write-Host "Description: " -NoNewline -ForegroundColor Yellow
            Write-Host $description
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "`n🔍 Running tldr for: $command" -ForegroundColor Cyan
            Write-Host ""

            # Run tldr for the selected tool
            tldr --quiet $command
        } else {
            Write-Host "No selection made." -ForegroundColor Yellow
        }

    } catch {
        Write-Error "Failed to fetch data or run fzf: $($_.Exception.Message)"
        Write-Host "Make sure you have 'fzf' installed and accessible in your PATH" -ForegroundColor Yellow
    }
}

function Search-FavoriteCliCommands {
    try {
        # Fetch the JSON data from the gist
        $response = Get-CachedJsonFromUrl -Url $favoriteCliUri -CacheFilePath "$env:TEMP\FavoriteCLICheatsheet.json" -Verbose

        # Format CLI commands for fzf
        $items = $response.clicommands | ForEach-Object {
            "$($_.name) | $($_.command) | $($_.description)"
        }

        # Use fzf to select a command
        $selected = $items | fzf --prompt="⚡ Select a CLI command > " --height=20 --border --preview-window=wrap --preview="echo {}" --header="Use ↑↓ to navigate, Enter to select, Esc to cancel"

        if ($selected) {
            # Parse the selected item
            $parts = $selected -split " \| "
            $name = $parts[0]
            $command = $parts[1]
            $description = $parts[2]

            # Show command info and copy to clipboard
            Write-Host "`n⚡ Selected CLI Command:" -ForegroundColor Cyan
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray
            Write-Host "Name:        " -NoNewline -ForegroundColor Yellow
            Write-Host $name
            Write-Host "Command:     " -NoNewline -ForegroundColor Yellow
            Write-Host $command -ForegroundColor Green
            Write-Host "Description: " -NoNewline -ForegroundColor Yellow
            Write-Host $description
            Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor DarkGray

            # Copy command to clipboard
            $command | Set-Clipboard
            Write-Host "`n📋 Command copied to clipboard!" -ForegroundColor Green

        } else {
            Write-Host "No selection made." -ForegroundColor Yellow
        }

    } catch {
        Write-Error "Failed to fetch data or run fzf: $($_.Exception.Message)"
        Write-Host "Make sure you have 'fzf' installed and accessible in your PATH" -ForegroundColor Yellow
    }
}

$global:LeaderPBindings = @(
  @{
    Key = 'r'
    Desc = 'Get [R]andom Favorite CLI Tip'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Get-RandomFavoriteCli')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 't'
    Desc = 'Search Favorite CLI [T]ools'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Search-FavoriteCliTools')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'c'
    Desc = 'Search and Copy Favorite CLI [C]ommands'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Search-FavoriteCliCommands')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  },
  @{
    Key = 'T'
    Desc = 'Search [T]ldr'
    Action = {
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert('Search-Tldr')
        [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()
    }
  }
)

Set-PSReadLineKeyHandler -Key Ctrl+p -ScriptBlock {
  Show-LeaderMenu -Bindings $global:LeaderPBindings -Title 'Help [P]ages'
}

# powershell completion for chezmoi                              -*- shell-script -*-

function __chezmoi_debug {
    if ($env:BASH_COMP_DEBUG_FILE) {
        "$args" | Out-File -Append -FilePath "$env:BASH_COMP_DEBUG_FILE"
    }
}

filter __chezmoi_escapeStringWithSpecialChars {
    $_ -replace '\s|#|@|\$|;|,|''|\{|\}|\(|\)|"|`|\||<|>|&','`$&'
}

[scriptblock]${__chezmoiCompleterBlock} = {
    param(
            $WordToComplete,
            $CommandAst,
            $CursorPosition
        )

    # Get the current command line and convert into a string
    $Command = $CommandAst.CommandElements
    $Command = "$Command"

    __chezmoi_debug ""
    __chezmoi_debug "========= starting completion logic =========="
    __chezmoi_debug "WordToComplete: $WordToComplete Command: $Command CursorPosition: $CursorPosition"

    # The user could have moved the cursor backwards on the command-line.
    # We need to trigger completion from the $CursorPosition location, so we need
    # to truncate the command-line ($Command) up to the $CursorPosition location.
    # Make sure the $Command is longer then the $CursorPosition before we truncate.
    # This happens because the $Command does not include the last space.
    if ($Command.Length -gt $CursorPosition) {
        $Command=$Command.Substring(0,$CursorPosition)
    }
    __chezmoi_debug "Truncated command: $Command"

    $ShellCompDirectiveError=1
    $ShellCompDirectiveNoSpace=2
    $ShellCompDirectiveNoFileComp=4
    $ShellCompDirectiveFilterFileExt=8
    $ShellCompDirectiveFilterDirs=16
    $ShellCompDirectiveKeepOrder=32

    # Prepare the command to request completions for the program.
    # Split the command at the first space to separate the program and arguments.
    $Program,$Arguments = $Command.Split(" ",2)

    $RequestComp="$Program __complete $Arguments"
    __chezmoi_debug "RequestComp: $RequestComp"

    # we cannot use $WordToComplete because it
    # has the wrong values if the cursor was moved
    # so use the last argument
    if ($WordToComplete -ne "" ) {
        $WordToComplete = $Arguments.Split(" ")[-1]
    }
    __chezmoi_debug "New WordToComplete: $WordToComplete"


    # Check for flag with equal sign
    $IsEqualFlag = ($WordToComplete -Like "--*=*" )
    if ( $IsEqualFlag ) {
        __chezmoi_debug "Completing equal sign flag"
        # Remove the flag part
        $Flag,$WordToComplete = $WordToComplete.Split("=",2)
    }

    if ( $WordToComplete -eq "" -And ( -Not $IsEqualFlag )) {
        # If the last parameter is complete (there is a space following it)
        # We add an extra empty parameter so we can indicate this to the go method.
        __chezmoi_debug "Adding extra empty parameter"
        # PowerShell 7.2+ changed the way how the arguments are passed to executables,
        # so for pre-7.2 or when Legacy argument passing is enabled we need to use
        # `"`" to pass an empty argument, a "" or '' does not work!!!
        if ($PSVersionTable.PsVersion -lt [version]'7.2.0' -or
            ($PSVersionTable.PsVersion -lt [version]'7.3.0' -and -not [ExperimentalFeature]::IsEnabled("PSNativeCommandArgumentPassing")) -or
            (($PSVersionTable.PsVersion -ge [version]'7.3.0' -or [ExperimentalFeature]::IsEnabled("PSNativeCommandArgumentPassing")) -and
              $PSNativeCommandArgumentPassing -eq 'Legacy')) {
             $RequestComp="$RequestComp" + ' `"`"'
        } else {
             $RequestComp="$RequestComp" + ' ""'
        }
    }

    __chezmoi_debug "Calling $RequestComp"
    # First disable ActiveHelp which is not supported for Powershell
    ${env:CHEZMOI_ACTIVE_HELP}=0

    #call the command store the output in $out and redirect stderr and stdout to null
    # $Out is an array contains each line per element
    Invoke-Expression -OutVariable out "$RequestComp" 2>&1 | Out-Null

    # get directive from last line
    [int]$Directive = $Out[-1].TrimStart(':')
    if ($Directive -eq "") {
        # There is no directive specified
        $Directive = 0
    }
    __chezmoi_debug "The completion directive is: $Directive"

    # remove directive (last element) from out
    $Out = $Out | Where-Object { $_ -ne $Out[-1] }
    __chezmoi_debug "The completions are: $Out"

    if (($Directive -band $ShellCompDirectiveError) -ne 0 ) {
        # Error code.  No completion.
        __chezmoi_debug "Received error from custom completion go code"
        return
    }

    $Longest = 0
    [Array]$Values = $Out | ForEach-Object {
        #Split the output in name and description
        $Name, $Description = $_.Split("`t",2)
        __chezmoi_debug "Name: $Name Description: $Description"

        # Look for the longest completion so that we can format things nicely
        if ($Longest -lt $Name.Length) {
            $Longest = $Name.Length
        }

        # Set the description to a one space string if there is none set.
        # This is needed because the CompletionResult does not accept an empty string as argument
        if (-Not $Description) {
            $Description = " "
        }
        New-Object -TypeName PSCustomObject -Property @{
            Name = "$Name"
            Description = "$Description"
        }
    }


    $Space = " "
    if (($Directive -band $ShellCompDirectiveNoSpace) -ne 0 ) {
        # remove the space here
        __chezmoi_debug "ShellCompDirectiveNoSpace is called"
        $Space = ""
    }

    if ((($Directive -band $ShellCompDirectiveFilterFileExt) -ne 0 ) -or
       (($Directive -band $ShellCompDirectiveFilterDirs) -ne 0 ))  {
        __chezmoi_debug "ShellCompDirectiveFilterFileExt ShellCompDirectiveFilterDirs are not supported"

        # return here to prevent the completion of the extensions
        return
    }

    $Values = $Values | Where-Object {
        # filter the result
        $_.Name -like "$WordToComplete*"

        # Join the flag back if we have an equal sign flag
        if ( $IsEqualFlag ) {
            __chezmoi_debug "Join the equal sign flag back to the completion value"
            $_.Name = $Flag + "=" + $_.Name
        }
    }

    # we sort the values in ascending order by name if keep order isn't passed
    if (($Directive -band $ShellCompDirectiveKeepOrder) -eq 0 ) {
        $Values = $Values | Sort-Object -Property Name
    }

    if (($Directive -band $ShellCompDirectiveNoFileComp) -ne 0 ) {
        __chezmoi_debug "ShellCompDirectiveNoFileComp is called"

        if ($Values.Length -eq 0) {
            # Just print an empty string here so the
            # shell does not start to complete paths.
            # We cannot use CompletionResult here because
            # it does not accept an empty string as argument.
            ""
            return
        }
    }

    # Get the current mode
    $Mode = (Get-PSReadLineKeyHandler | Where-Object {$_.Key -eq "Tab" }).Function
    __chezmoi_debug "Mode: $Mode"

    $Values | ForEach-Object {

        # store temporary because switch will overwrite $_
        $comp = $_

        # PowerShell supports three different completion modes
        # - TabCompleteNext (default windows style - on each key press the next option is displayed)
        # - Complete (works like bash)
        # - MenuComplete (works like zsh)
        # You set the mode with Set-PSReadLineKeyHandler -Key Tab -Function <mode>

        # CompletionResult Arguments:
        # 1) CompletionText text to be used as the auto completion result
        # 2) ListItemText   text to be displayed in the suggestion list
        # 3) ResultType     type of completion result
        # 4) ToolTip        text for the tooltip with details about the object

        switch ($Mode) {

            # bash like
            "Complete" {

                if ($Values.Length -eq 1) {
                    __chezmoi_debug "Only one completion left"

                    # insert space after value
                    $CompletionText = $($comp.Name | __chezmoi_escapeStringWithSpecialChars) + $Space
                    if ($ExecutionContext.SessionState.LanguageMode -eq "FullLanguage"){
                        [System.Management.Automation.CompletionResult]::new($CompletionText, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
                    } else {
                        $CompletionText
                    }

                } else {
                    # Add the proper number of spaces to align the descriptions
                    while($comp.Name.Length -lt $Longest) {
                        $comp.Name = $comp.Name + " "
                    }

                    # Check for empty description and only add parentheses if needed
                    if ($($comp.Description) -eq " " ) {
                        $Description = ""
                    } else {
                        $Description = "  ($($comp.Description))"
                    }

                    $CompletionText = "$($comp.Name)$Description"
                    if ($ExecutionContext.SessionState.LanguageMode -eq "FullLanguage"){
                        [System.Management.Automation.CompletionResult]::new($CompletionText, "$($comp.Name)$Description", 'ParameterValue', "$($comp.Description)")
                    } else {
                        $CompletionText
                    }
                }
             }

            # zsh like
            "MenuComplete" {
                # insert space after value
                # MenuComplete will automatically show the ToolTip of
                # the highlighted value at the bottom of the suggestions.

                $CompletionText = $($comp.Name | __chezmoi_escapeStringWithSpecialChars) + $Space
                if ($ExecutionContext.SessionState.LanguageMode -eq "FullLanguage"){
                    [System.Management.Automation.CompletionResult]::new($CompletionText, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
                } else {
                    $CompletionText
                }
            }

            # TabCompleteNext and in case we get something unknown
            Default {
                # Like MenuComplete but we don't want to add a space here because
                # the user need to press space anyway to get the completion.
                # Description will not be shown because that's not possible with TabCompleteNext

                $CompletionText = $($comp.Name | __chezmoi_escapeStringWithSpecialChars)
                if ($ExecutionContext.SessionState.LanguageMode -eq "FullLanguage"){
                    [System.Management.Automation.CompletionResult]::new($CompletionText, "$($comp.Name)", 'ParameterValue', "$($comp.Description)")
                } else {
                    $CompletionText
                }
            }
        }

    }
}

Register-ArgumentCompleter -CommandName 'chezmoi' -ScriptBlock ${__chezmoiCompleterBlock}
