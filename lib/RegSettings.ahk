class RegSettings
{
  static installFolder := ""

  static __New()
  {
    static fullPathFromCommandRegexPattern := "^.*?(\b[A-Z]:\\.*?\.exe).*"

    ; ================================================================
    ; Root folder
    ; ================================================================

    ; v1/v2 [HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey] → InstallDir
    RegSettings.ahkRootFolder := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey", 
        "InstallDir", 0)
    
    if (!RegSettings.ahkRootFolder)
    {
      OutputDebug "Detected portable AHK or not installed" "`n"
      ; Portable / not installed
      return
    }

    ; C:\Program Files\AutoHotkey (or similar)
    OutputDebug "AHK root directory found: " RegSettings.ahkRootFolder "`n"


    ; ================================================================
    ; v2 Launcher
    ; ================================================================

    ; v2 [HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey] → InstallCommand
    ahkLauncherFullPath := RegRead(
        "HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey", "InstallCommand", 0)

    if (ahkLauncherFullPath) ; v2 path found
    {
      ; Reduce to "C:\Program Files\AutoHotkey\UX" (or similar)
      ahkLauncherFolder := RegExReplace(ahkLauncherFullPath, 
          fullPathFromCommandRegexPattern, "$1")
      SplitPath(ahkLauncherFolder, , &ahkLauncherFolder)

      OutputDebug "AHK v2 launcher directory found: " ahkLauncherFolder "`n"
    }
    else
    {
      ; v1
      ahkLauncherFolder := ""
    }

    RegSettings.ahkLauncherFolder := ahkLauncherFolder


    ; ================================================================
    ; Primary version folder
    ; ================================================================

    ; v1: "\"C:\\Program Files\\AutoHotkey\\AutoHotkey.exe\" /CP65001 \"%1\" %*"
    ; v2: "\"C:\\Program Files\\AutoHotkey\\v2\\AutoHotkey64.exe\" 
    ;      \"C:\\Program Files\\AutoHotkey\\UX\\launcher.ahk\" \"%1\" %*"
    ahkScriptOpenCommand := RegRead(
        "HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Open\Command", , 0)
    

    if (ahkScriptOpenCommand)
    {
      ; v2 (with or without v1): Reduce to "C:\Program Files\AutoHotkey\v2" (or similar)
      ; v1: Reduce to "C:\Program Files\AutoHotkey" (or similar)
      ahkPrimaryVersionFolder := regexreplace(ahkScriptOpenCommand, 
          fullPathFromCommandRegexPattern, "$1")
      SplitPath(ahkPrimaryVersionFolder, , &ahkPrimaryVersionFolder)
    }
    else ; reg entry missing
    {
      ; No other way to determine the path from the registry → make a guess instead
      if (instr(FileExist(RegSettings.ahkRootFolder "\v2"), "D")) ; v2
      {
        ahkPrimaryVersionFolder := RegSettings.ahkRootFolder "\v2"
      }
      else
      {
        ahkPrimaryVersionFolder := RegSettings.ahkRootFolder ; v1
      }
    }

    RegSettings.ahkPrimaryVersionFolder := ahkPrimaryVersionFolder

    OutputDebug "AHK primary version directory found: " ahkPrimaryVersionFolder "`n"


    ; ================================================================
    ; Ahk2Exe
    ; ================================================================
    
    ; 
    ahkCompilerFullPath := RegRead(
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Ahk2Exe.exe", 
        , "")
    
    if (!ahkCompilerFullPath) ; Not found
    {
      ; Make an educated guess
      if (FileExist(RegSettings.ahkRootFolder "Compiler\Ahk2Exe.exe"))
      {
        ahkCompilerFullPath := RegSettings.ahkRootFolder "Compiler\Ahk2Exe.exe"
      }
      else
      {
        ; Not yet installed
      }
    }

    OutputDebug "AHK Compiler location: " (ahkCompilerFullPath
        ? ahkCompilerFullPath : "Not installed") "`n"
    
    RegSettings.ahkCompilerFullPath := ahkCompilerFullPath



    v1CompileCommand := v1Compile_GuiCommand := v1EditCommand 
        := v1OpenCommand := v1RunAsCommand := 0
    
    for subKey, mainProperty in RegSettings.v1.ahkScript.subKeys[1].Shell.subKeys
    {
      for propertyName, property in mainProperty.OwnProps()
      {
        if (!IsObject(property))
        {
          continue
        }
        
        for subPropertyName, subProperty in property.subKeys[1].OwnProps()
        {
          if (subPropertyName == "Command")
          {
            v1%propertyName subPropertyName% := subProperty
            break
          }
        }
      }
    }

    v2CompileCommand := v2EditCommand := v2LaunchCommand 
        := v2OpenCommand := v2RunAsCommand := v2UIAccessCommand := 0

    for subKey, mainProperty in RegSettings.v2.ahkScript.subKeys[1].Shell.subKeys
    {
      for propertyName, property in mainProperty.OwnProps()
      {
        if (!IsObject(property))
        {
          continue
        }

        for subPropertyName, subProperty in property.subKeys[1].OwnProps()
        {
          if (subPropertyName == "Command")
          {
            v2%propertyName subPropertyName% := subProperty
            break
          }
        }
      }
    }


    ; ================================================================
    ; [HKEY_CLASSES_ROOT\.ahk\ShellNew]
    ; ================================================================

    ; v1 ShellNew is by default a fixed value

    ; v2: '"C:\Program Files\AutoHotkey\UX\AutoHotkeyUX.exe" 
    ;      "C:\Program Files\AutoHotkey\UX\ui-newscript.ahk" "%1"' (or similar)
    
    RegSettings.v2.dotAhk.subKeys[1].ShellNew.nonDefaultEntries[1].value := 
        Format(RegSettings.v2.dotAhk.subKeys[1].ShellNew.nonDefaultEntries[1].value, "`""
            RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe`" `"" . 
            RegSettings.ahkLauncherFolder "\ui-newscript.ahk`" `"%1`"")

    OutputDebug "AHK v2 new script command: " 
        RegSettings.v2.dotAhk.subKeys[1].ShellNew.nonDefaultEntries[1].value "`n"



    ; ================================================================
    ; [HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Compile\Command]
    ; ================================================================

    ; v1: '"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /in "%l" %*'
    v1CompileCommand.expectedDefaultValue :=
        Format(v1CompileCommand.expectedDefaultValue, 
            "`"" RegSettings.ahkCompilerFullPath "`" /in `"%l`" %*")

    ; v2
    v2CompileCommand.expectedDefaultValue :=
        v1CompileCommand.expectedDefaultValue

    OutputDebug "AHK v1/v2 compile command: " .
        v1CompileCommand.expectedDefaultValue "`n"



    ; ================================================================
    ; [HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Compile-Gui\Command]
    ; ================================================================

    ; v1: '"C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" /gui /in "%l" %*'
    v1Compile_GuiCommand.expectedDefaultValue :=
        Format(v1Compile_GuiCommand.expectedDefaultValue, 
            "`"" RegSettings.ahkCompilerFullPath "`" /gui /in `"%l`" %*")

    OutputDebug "AHK v1 GUI compile command: " .
        v1Compile_GuiCommand.expectedDefaultValue "`n"



    ; ================================================================
    ; [HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Edit\Command]
    ; ================================================================



    
    ; ================================================================
    ; [HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Launch\Command]
    ; ================================================================

    ; v2
    if (FileExist(RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe"))
    {
      v2LaunchCommand.expectedDefaultValue :=
          Format(v2LaunchCommand.expectedDefaultValue,
              "`"" RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe`" " .
              "`"" RegSettings.ahkLauncherFolder "\launcher.ahk`" /Launch `"%1`" %*")
      
      OutputDebug "AHK v2 launcher command: " . 
          v2LaunchCommand.expectedDefaultValue "`n"
    }
    else ; Launcher exe missing
    {
      ; v1
    }

    
    ; ================================================================
    ; [HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Open\Command]
    ; ================================================================

    ; v1
    v1OpenCommand.expectedDefaultValue :=
        Format(v1OpenCommand.expectedDefaultValue,
            "`"" RegSettings.ahkRootFolder "\AutoHotkey.exe`" /CP65001 `"%1`" %*")
        ; '"C:\Program Files\AutoHotkey\AutoHotkey.exe" /CP65001 "%1" %*' (or similar)

    ; v2
    if (FileExist(RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe"))
    {
      v2OpenCommand.expectedDefaultValue :=
          Format(v2OpenCommand.expectedDefaultValue,
              "`"" RegSettings.ahkPrimaryVersionFolder "\AutoHotkey64.exe`" " .
              "`"" RegSettings.ahkLauncherFolder "\launcher.ahk`" `"%1`" %*")
        ; '"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" 
        ;  "C:\Program Files\AutoHotkey\UX\launcher.ahk" "%1" %*' (or similar)
    }

    
    ; ================================================================
    ; [HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\RunAs\Command]
    ; ================================================================

    ; v1
    v1RunAsCommand.expectedDefaultValue :=
        Format(v1RunAsCommand.expectedDefaultValue,
            "`"" RegSettings.ahkRootFolder "\AutoHotkey.exe`" `"%1`" %*")
        ; '"C:\Program Files\AutoHotkey\AutoHotkey.exe" "%1" %*' (or similar)

    ; v2
    if (FileExist(RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe"))
    {
      v2RunAsCommand.expectedDefaultValue :=
          Format(v2RunAsCommand.expectedDefaultValue,
              "`"" RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe`" " .
              "`"" RegSettings.ahkLauncherFolder "\launcher.ahk`" `"%1`" %*")
        ; '"C:\Program Files\AutoHotkey\UX\AutoHotkeyUX.exe" 
        ;  "C:\Program Files\AutoHotkey\UX\launcher.ahk" "%1" %*' (or similar)
    }


    ; ================================================================
    ; [HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\UIAccess\Command]
    ; ================================================================

    ; v1 doesn't have one

    ; v2
    if (FileExist(RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe"))
    {
      v2UIAccessCommand.expectedDefaultValue :=
          Format(v2UIAccessCommand.expectedDefaultValue,
              "`"" RegSettings.ahkLauncherFolder "\AutoHotkeyUX.exe`" " .
              "`"" RegSettings.ahkLauncherFolder "\launcher.ahk`" /runwith UIA `"%1`" %*")
        ; '"C:\Program Files\AutoHotkey\UX\AutoHotkeyUX.exe" 
        ;  "C:\Program Files\AutoHotkey\UX\launcher.ahk" /runwith UIA "%1" %*' (or similar)
    }
  }

  static v1 :=
  {
    dotAhk:
    {
      branch: "HKEY_CLASSES_ROOT\.ahk", 
      shouldHaveDefaultValue: true,
      expectedDefaultValue: "AutoHotkeyScript",
      subKeys:
      [
        {
          ShellNew:
          {
            shouldHaveDefaultValue: false,
            nonDefaultEntries:
            [
              {
                key: "FileName",
                value: "Template.ahk",
                allowModificationByV2: true
              }
            ]
          }
        }
      ]
    },
    ahkScript:
    {
      branch: "HKEY_CLASSES_ROOT\AutoHotkeyScript",
      shouldHaveDefaultValue: true,
      expectedDefaultValue: "AutoHotkey Script",
      subKeys:
      [
        {
          Shell:
          {
            shouldHaveDefaultValue: true,
            expectedDefaultValue: "Open",
            allowModificationByV2: true,
            subKeys:
            [
              {
                Compile:
                {
                  shouldHaveDefaultValue: true,
                  expectedDefaultValue: "Compile Script",
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}"
                      }
                    }
                  ]
                }
              },
              {
                allowModificationByV2: true,
                Compile_Gui:
                {
                  allowModificationByV2: true,
                  shouldHaveDefaultValue: true,
                  expectedDefaultValue: "Compile Script (GUI)...",
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}"
                      }
                    }
                  ]
                }
              },
              {
                Edit:
                {
                  shouldHaveDefaultValue: true, 
                  expectedDefaultValue: "Edit Script",
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        originalDefaultValue: "notepad.exe %1"
                      }
                    }
                  ]
                }
              },
              {
                Open:
                {
                  shouldHaveDefaultValue: true,
                  isCaseSensitive: false,
                  expectedDefaultValue: "Run Script",
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}",
                        allowModificationByV2: true
                      }
                    }
                  ]
                }
              },
              {
                RunAs:
                {
                  shouldHaveDefaultValue: false,
                  nonDefaultEntries:
                  [
                    {
                      key: "HasLUAShield",
                      value: "",
                      allowModificationByV2: false
                    }
                  ],
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}",
                        allowModificationByV2: true
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      ]
    }
  }
  
  static v2 :=
  {
    dotAhk:
    {
      branch: "HKEY_CLASSES_ROOT\.ahk", 
      shouldHaveDefaultValue: true,
      expectedDefaultValue: "AutoHotkeyScript",
      subKeys:
      [
        {
          ShellNew:
          {
            shouldHaveDefaultValue: false,
            nonDefaultEntries:
            [
              {
                key: "Command",
                value: "{1}"
              }
            ]
          }
        }
      ]
    },
    ahkScript:
    {
      branch: "HKEY_CLASSES_ROOT\AutoHotkeyScript",
      shouldHaveDefaultValue: true,
      expectedDefaultValue: "AutoHotkey Script",
      nonDefaultEntries:
      [
        {
          key: "AppUserModelID",
          value: "AutoHotkey.AutoHotkey"
        }
      ],
      subKeys:
      [
        {
          Shell:
          {
            shouldHaveDefaultValue: true,
            expectedDefaultValue: "Open runas UIAccess Edit",
            subKeys:
            [
              {
                Compile:
                {
                  shouldHaveDefaultValue: true,
                  expectedDefaultValue: "Compile Script",
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}"
                      }
                    }
                  ]
                }
              },
              {
                Edit:
                {
                  shouldHaveDefaultValue: true, 
                  expectedDefaultValue: "Edit Script",
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        originalDefaultValue: "notepad.exe %1"
                      }
                    }
                  ]
                }
              },
              {
                Launch:
                {
                  shouldHaveDefaultValue: true, 
                  expectedDefaultValue: "Launch",
                  nonDefaultEntries:
                  [
                    {
                      key: "AppUserModelID",
                      value: "AutoHotkey.AutoHotkey"
                    },
                    {
                      key: "ProgrammaticAccessOnly",
                      value: ""
                    }
                  ],
                  subkeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}"
                      }
                    }
                  ]
                }
              },
              {
                Open:
                {
                  shouldHaveDefaultValue: true, 
                  expectedDefaultValue: "Run script",
                  nonDefaultEntries:
                  [
                    {
                      key: "FriendlyAppName",
                      value: "AutoHotkey Launcher"
                    },
                    {
                      key: "AppUserModelID",
                      value: "AutoHotkey.AutoHotkey"
                    }
                  ],
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}"
                      }
                    }
                  ]
                }
              },
              {
                RunAs:
                {
                  shouldHaveDefaultValue: false,
                  nonDefaultEntries:
                  [
                    {
                      key: "HasLUAShield",
                      value: ""
                    },
                    {
                      key: "AppUserModelID",
                      value: "AutoHotkey.AutoHotkey"
                    }
                  ],
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}"
                      }
                    }
                  ]
                }
              },
              {
                UIAccess:
                {
                  shouldHaveDefaultValue: true,
                  expectedDefaultValue: "Run with UI access",
                  nonDefaultEntries:
                  [
                    {
                      key: "AppUserModelID",
                      value: "AutoHotkey.AutoHotkey"
                    }
                  ],
                  subKeys:
                  [
                    {
                      Command:
                      {
                        shouldHaveDefaultValue: true,
                        expectedDefaultValue: "{1}"
                      }
                    }
                  ]
                }
              }
            ]
          }
        }
      ]
    }
  }
}