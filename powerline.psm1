#!/usr/bin/env powershell

# from https://gist.github.com/Jaykul/2388b845cca0ef219b434d8c5e2c26ea
# Also needs fonts from https://github.com/powerline/fonts/
# Also maybe http://poshcode.org/6338

using namespace System.Collections.Generic

class PowerLineOutput {
    [Nullable[ConsoleColor]]$BackgroundColor   
    [Nullable[ConsoleColor]]$ForegroundColor
    [Object]$Content
    [bool]$Clear = $false

    PowerLineOutput() {}

    PowerLineOutput([hashtable]$values) {
        foreach($key in $values.Keys) {
            if("bg" -eq $key -or "BackgroundColor" -match "^$key") {
                $this.BackgroundColor = $values.$key
            }
            elseif("fg" -eq $key -or "ForegroundColor" -match "^$key") {
                $this.ForegroundColor = $values.$key
            }
            elseif("fg" -eq $key -or "ForegroundColor" -match "^$key") {
                $this.ForegroundColor = $values.$key
            }
            elseif("text" -match "^$key" -or "Content" -match "^$key") {
                $this.Content = $values.$key
            }
            elseif("Clear" -match "^$key") {
                $this.Clear = $values.$key
            }
            else {
                throw "Unknown key '$key' in hashtable. Allowed values are BackgroundColor, ForegroundColor, Content, and Clear"
            }
        }
   }

   [string] GetText() {
      if($this.Content -is [scriptblock]) {
         return & $this.Content
      } else {
         return $this.Content
      }
   }

   [string] ToString() {
      return $(
         if($this.BackgroundColor) {
            [PowerLineOutput]::EscapeCodes.bg."$($this.BackgroundColor)"
         } else {
            [PowerLineOutput]::EscapeCodes.bg.Clear
         }
      ) + $(
         if($this.ForegroundColor) {
            [PowerLineOutput]::EscapeCodes.fg."$($this.ForegroundColor)"
         } else {
            [PowerLineOutput]::EscapeCodes.fg.Clear
         }
      ) + $this.GetText() + $(
         if($this.Clear) {
            [PowerLineOutput]::EscapeCodes.bg.Clear
            [PowerLineOutput]::EscapeCodes.fg.Clear
         }
      )
   }

   static [PowerLineOutput] $NewLine = [PowerLineOutput]@{Content="`n"}
   static [PowerLineOutput] $ShiftRight = [PowerLineOutput]@{Content="`t"}
   static [hashtable] $EscapeCodes = @{
      ESC = ([char]27) + "["
      CSI = [char]155
      Clear = ([char]27) + "[0m"
      fg = @{
         Clear       = ([char]27) + "[39m"
         Black       = ([char]27) + "[30m";  DarkGray    = ([char]27) + "[90m"
         DarkRed     = ([char]27) + "[31m";  Red         = ([char]27) + "[91m"
         DarkGreen   = ([char]27) + "[32m";  Green       = ([char]27) + "[92m"
         DarkYellow  = ([char]27) + "[33m";  Yellow      = ([char]27) + "[93m"
         DarkBlue    = ([char]27) + "[34m";  Blue        = ([char]27) + "[94m"
         DarkMagenta = ([char]27) + "[35m";  Magenta     = ([char]27) + "[95m"
         DarkCyan    = ([char]27) + "[36m";  Cyan        = ([char]27) + "[96m"
         Gray        = ([char]27) + "[37m";  White       = ([char]27) + "[97m"
      }
      bg = @{
         Clear       = ([char]27) + "[49m"
         Black       = ([char]27) + "[40m"; DarkGray    = ([char]27) + "[100m"
         DarkRed     = ([char]27) + "[41m"; Red         = ([char]27) + "[101m"
         DarkGreen   = ([char]27) + "[42m"; Green       = ([char]27) + "[102m"
         DarkYellow  = ([char]27) + "[43m"; Yellow      = ([char]27) + "[103m"
         DarkBlue    = ([char]27) + "[44m"; Blue        = ([char]27) + "[104m"
         DarkMagenta = ([char]27) + "[45m"; Magenta     = ([char]27) + "[105m"
         DarkCyan    = ([char]27) + "[46m"; Cyan        = ([char]27) + "[106m"
         Gray        = ([char]27) + "[47m"; White       = ([char]27) + "[107m"
      }
   }
}

class PowerLineOutputCache : PowerLineOutput {
    [string]$Content
    [int]$Length

    PowerLineOutputCache([PowerLineOutput] $output) {

        $this.BackgroundColor = $output.BackgroundColor
        $this.ForegroundColor = $output.ForegroundColor
        $this.Content = $output.GetText()
        $this.Length = $this.Content.Length
    }
}

class PowerLine {
   [bool]$SetTitle = $true
   [bool]$SetCwd = $true
   [List[PowerLineOutput]]$Prompt = @(
        [PowerLineOutput]@{ bg = "blue";     fg = "white"; text = { $MyInvocation.HistoryId } }
        [PowerLineOutput]@{ bg = "cyan";     fg = "white"; text = { "$GEAR" * $NestedPromptLevel } }
        [PowerLineOutput]@{ bg = "darkblue"; fg = "white"; text = { $pwd.Drive.Name } }
        [PowerLineOutput]@{ bg = "darkblue"; fg = "white"; text = { Split-Path $pwd -leaf } }
    )
}

$global:PowerLine = [PowerLine]::new()

[PowerLineOutput]::EscapeCodes.fg.Default = [PowerLineOutput]::EscapeCodes.fg."$($Host.UI.RawUI.ForegroundColor)"
[PowerLineOutput]::EscapeCodes.fg.Background = [PowerLineOutput]::EscapeCodes.fg."$($Host.UI.RawUI.BackgroundColor)"
[PowerLineOutput]::EscapeCodes.bg.Default = [PowerLineOutput]::EscapeCodes.bg."$($Host.UI.RawUI.BackgroundColor)"


function Get-Elapsed {
   [CmdletBinding()]
   param(
      [Parameter()]
      [int]$Id,

      [Parameter()]
      [string]$Format = "{0:h\:mm\:ss\.ffff}"
   )
   $LastCommand = Get-History -Count 1 @PSBoundParameters
   if(!$LastCommand) { return "" }
   $Duration = $LastCommand.EndExecutionTime - $LastCommand.StartExecutionTime
   $Format -f $Duration
}

function ConvertTo-ANSI {
   [CmdletBinding(DefaultParameterSetName="ConsoleColor")]
   param(
      [Parameter(ValueFromPipelineByPropertyName, ParameterSetName="ConsoleColor")]
      [Alias("fg")]
      [ConsoleColor]$ForegroundColor,
      
      [Parameter(ValueFromPipelineByPropertyName, ParameterSetName="ConsoleColor")]
      [Alias("bg")]
      [ConsoleColor]$BackgroundColor,

      [Parameter(Position=0)]
      [Alias("text")]
      $text,

      [Alias("length")]
      $ignored,

      [switch]$Clear
   )

   if($BackgroundColor) {
      [PowerLineOutput]::EscapeCodes.bg."$BackgroundColor"
   } else {
      [PowerLineOutput]::EscapeCodes.bg.Clear
   }
   
   if($ForegroundColor) {
      [PowerLineOutput]::EscapeCodes.fg."$ForegroundColor"
   } else {
      [PowerLineOutput]::EscapeCodes.fg.Clear
   }

   # Output the actual text
   if($text -is [scriptblock]) {
      & $text
   } else {
      $text
   }
   if($Clear) {
      [PowerLineOutput]::EscapeCodes.bg.Clear
      [PowerLineOutput]::EscapeCodes.fg.Clear
   }
}

function Set-PowerLinePrompt {
    # Here is an example of a prompt which needs access to a global value
    # Get-Location -Stack in the module would never return anything ...
    $function:global:prompt = {
        Write-PowerLine $global:PowerLine
    }
}

function Write-PowerLine {
    [CmdletBinding()]
    param([PowerLine]$PowerLine)

    # FIRST, make a note if there was an error in the previous command
    $err = !$?
    $e = ([char]27) + "["
    # PowerLine font characters
    $RIGHT  = [char]0xe0b0 # Solid, right facing triangle
    $GT     = [char]0xe0b1 # right facing triangle
    $LEFT   = [char]0xe0b2 # Solid, right facing triangle
    $LT     = [char]0xe0b3 # right facing triangle
    $BRANCH = [char]0xe0a0 # Branch symbol
    $LOCK   = [char]0xe0a2 # Padlock
    $RAQUO  = [char]0x203a # Single right-pointing angle quote ?
    $GEAR   = [char]0x2699 # The settings icon, I use it for debug
    $EX     = [char]0x27a6 # The X that looks like a checkbox.
    $POWER  = [char]0x26a1 # The Power lightning-bolt icon
    $MID    = [char]0xB7   # Mid dot (I used to use this for pushd counters)

    try {
        if($PowerLine.SetTitle) {
            # Put the path in the title ... (don't restrict this to the FileSystem)
            $Host.UI.RawUI.WindowTitle = "{0} - {1} ({2})" -f $global:WindowTitlePrefix, (Convert-Path $pwd),  $pwd.Provider.Name
        }
        if($PowerLine.SetCwd) {
             # Make sure Windows & .Net know where we are
             # They can only handle the FileSystem, and not in .Net Core
             [Environment]::CurrentDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
        }
    } catch {}

    # Initialize things that need to be ...
    $width = [Console]::BufferWidth
    $leftLength = 0
    $rightLength = 0
    $lineCount = 0
    $anchored = $false

    # Precalculate all the text and remove empty blocks
    $blocks = ([PowerLineOutputCache[]]$PowerLine.Prompt) | Where Length

    if($Host.UI.SupportsVirtualTerminal) {
        $(&{
            # If we can use advanced ANSI sequences, we can do more
            # Like output on the previous line(s)
            if($blocks[0] -is [int] -and $blocks[0] -lt 0)
            {
                $lineCount = $blocks[0]
                "${e}1A" * [Math]::Abs($lineCount)
                $block, $blocks = $blocks
            }

            # Loop through and output
            # Depends on access to previous and future blocks, so this can't be refactored to a function
            for($l=0; $l -lt $blocks.Length; $l++) {
                $block = $blocks[$l]
                if($block -eq [PowerLineOutput]::NewLine) {
                    $lineCount++
                    $leftLength = 0
                    $rightLength = 0
                    "`n"
                } elseif($block -eq [PowerLineOutput]::ShiftRight) {
                    # the length of the rest of the line
                    $rightLength = ($(for($r=$l+1; $r -lt $blocks.Length -and $blocks[$r] -is [hashtable]; $r++) {
                        $blocks[$r].length + 1
                    }) | Measure-Object -Sum).Sum
              
                    $space = $width - $rightLength

                    # add the caps at the end of the left-side, and beginning of the right side, like: > ... <
                    if($leftLength) {
                        # the left cap uses the Background of the previous block as it's foreground
                        [PowerLineOutput]@{ 
                            ForegroundColor = ($blocks[($l-1)]).BackgroundColor
                            Content = $RIGHT
                            Clear = $true
                        }                 
                    }

                    if($lineCount -eq 0) { 
                        $anchored = $true
                        "${e}s"
                    }
                    "${e}${space}G"

                    # the right cap uses the background of the next block as it's foreground
                    [PowerLineOutput]@{ 
                        ForegroundColor = ($blocks[($l+1)]).BackgroundColor
                        Content = $LEFT
                    }
                } else {
                    if($leftLength -eq 0 -and $rightLength -eq 0) {
                        # On a new line, recalculate the length of the "left-aligned" line
                        $leftLength = ($(for($r=$l; $r -lt $blocks.Length -and $blocks[$r] -ne [PowerLineOutput]::NewLine -and $blocks[$r] -ne [PowerLineOutput]::ShiftRight; $r++) {
                            $blocks[$r].length + 1
                        }) | Measure-Object -Sum).Sum
                    }
        
                    $block
                    # Put out a separator
                    if($blocks[($l+1)] -ne [PowerLineOutput]::NewLine -and $blocks[($l+1)] -ne [PowerLineOutput]::ShiftRight)
                    {
                        if($block.BackgroundColor -eq $blocks[($l+1)].BackgroundColor) {
                            $GT
                        } else {
                            [PowerLineOutput]@{ 
                                ForegroundColor = $block.BackgroundColor
                                BackgroundColor = $blocks[($l+1)].BackgroundColor
                                Content = $RIGHT
                            }
                        }
                    }
                }
            }

            # move the prompt location to the end of output unless it's anchored already
            if($lineCount -le 0 -and !$anchored) { 
               "${e}s"
            }            
             
            # With ANSI VT support, restore the original prompt position      
            if($anchored) {"${e}u"} # RECALL LOCATION
            else {
                [PowerLineOutput]@{ 
                    ForegroundColor = $blocks[-1].BackgroundColor
                    Content = $RIGHT
                }
            }
             [PowerLineOutput]::EscapeCodes.fg.Default
        }) -join ""

   } else {
      for($l=0; $l -lt $blocks.Length; $l++) {
         $block = $blocks[$l]
         if($block -is [string]) {
            if($block -eq "`n") {
               $lineCount++
               $leftLength = 0
               $rightLength = 0
               Write-Host
            } elseif($block -eq "`t") {
               # the length of the rest of the line
               $rightLength = ($(for($r=$l+1; $r -lt $blocks.Length -and $blocks[$r] -is [hashtable]; $r++) {
                  $blocks[$r].length + 1
               }) | Measure-Object -Sum).Sum
               $space = $width - $rightLength - $leftLength

               if($leftLength) {
                  $last = $blocks[($l-1)]
                  $c = @{}
                  if($last.bg) { $c.ForegroundColor = $last.bg }
                  if($last.fg) { $c.BackgroundColor = $last.fg }
                  Write-Host -NoNewLine $RIGHT @c
               }

               Write-Host -NoNewLine (" " * ${space})

               if($rightLength) {
                  $next = $blocks[($l+1)]
                  $c = @{}
                  if($next.bg) { $c.ForegroundColor = $next.bg }
                  if($next.fg) { $c.BackgroundColor = $next.fg }
                  Write-Host -NoNewLine $LEFT @c
               }
            }
         } else {
            if($leftLength -eq 0 -and $rightLength -eq 0) {
               # On a new line, recalculate the length of the "left-aligned" line
               $leftLength = ($(for($r=$l; $r -lt $blocks.Length -and $blocks[$r] -is [hashtable]; $r++) {
                  $blocks[$r].length + 1
               }) | Measure-Object -Sum).Sum
            }

            $c = @{}
            if($block.fg) { $c.ForegroundColor = $block.fg }
            if($block.bg) { $c.BackgroundColor = $block.bg }
            Write-Host -NoNewLine  $block.Text @c
            if($blocks[($l+1)] -is [hashtable])
            {
               if($block.bg -eq $blocks[($l+1)].bg) {
                  Write-Host $GT -NoNewLine @c
               } else {
                  $c = @{}
                  $c.ForegroundColor = if($block.bg) { $block.bg } else { [PowerLineOutput]::EscapeCodes.bg.Default }
                  if($block.bg) { $c.BackgroundColor = $blocks[($l+1)].bg }
                  Write-Host -NoNewLine $RIGHT @c
               }
            }
         }
      }
      # if there's anything on the right and there's no ANSI VT support, put the prompt on the next line
      if($rightLength) {
         Write-Host "`n$RIGHT" -NoNewLine
      }
   }
}