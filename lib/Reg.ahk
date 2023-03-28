class Reg
{
  static AHK_VERSION := { 1: "AutoHotkey v1", 2: "AutoHotkey v2" }
       , InstalledAHKVersions := Reg.__FindInstalledAhkVersions()

  static Analyze(ahkVersion, onCompleteCallback)
  {
    dotAhkErrors := []
    ahkScriptErrors := []
  
    dotAhkErrors.Push(this.__AnalyzeDotAhkPath(ahkVersion)*)
    ahkScriptErrors.Push(this.__AnalyzeAhkScriptPath(ahkVersion)*)

    versionKey := this.__VersionSettingsKey[ahkVersion]

    onCompleteCallback(
        RegSettings.%versionKey%.dotAhk.branch, dotAhkErrors, 
        RegSettings.%versionKey%.ahkScript.branch, ahkScriptErrors)
  }

  static __DoAnalyze(ahkVersion, regObject, accumulatedBranch := "")
  {
    static  hKey := 0
            WINAPI :=
            {
              ERROR_SUCCESS: 0,
              HKEY_CLASSES_ROOT: 0x80000000,
              HKEY_LOCAL_MACHINE: 0x80000002,
              KEY_READ: 0x20019
            }

    regEntries := []
    
    if (regObject.HasOwnProp("branch"))
    {
      accumulatedBranch := regObject.branch
    }
    else if (accumulatedBranch == "")
    {
      throw Error("The provided registry object is missing its branch information", -2)
    }

    if (accumulatedBranch ~= "^HKEY_CLASSES_ROOT")
    {
      pRootKey := WINAPI.HKEY_CLASSES_ROOT
    }
    else if (accumulatedBranch ~= "^HKEY_LOCAL_MACHINE")
    {
      pRootKey := WINAPI.HKEY_LOCAL_MACHINE
    }
    else
    {
      throw Error("Only HKLM and HKCR main registry branches are currently supported.", -2, 
          accumulatedBranch)
    }

    ; Use DllCall to differentiate between following scenarios:
    ; "Key not found" vs "Key found but no default value"
    if (isKeyMissing := 
        WINAPI.ERROR_SUCCESS !== DllCall("advapi32\RegOpenKeyEx", 
            "ptr", pRootKey, 
            "str", RegExReplace(accumulatedBranch, "^[A-Z_]+\\"),
            "int", 0, 
            "int", WINAPI.KEY_READ := 0x20019,
            "ptr*", hKey))
    {
      ; Entire branch missing
      errorType := Reg.__CanBeOverriddenByV2(ahkVersion, regObject) 
          ? RegNote ; Possibly overridden by v2
          : RegError ; v2 || only AHK v1 installed || (v1 && overriding not allowed)

      regEntries.Push(errorType(accumulatedBranch, isBranchMissing := true))
      return regEntries
    }

    if (regObject.shouldHaveDefaultValue)
    {
      try
      {
        registryCurrentDefaultValue := RegRead(accumulatedBranch)
      }
      catch OSError as err
      {
        ; Default value missing
        regEntries.Push(RegError(accumulatedBranch, isBranchMissing := false))
        return regEntries
      }

      isCaseInsensitiveComparison := regObject.HasOwnProp("isCaseSensitive") && 
          !regObject.isCaseSensitive
      
      if (regObject.HasOwnProp("expectedDefaultValue") &&
          !(regObject.expectedDefaultValue ~= (isCaseInsensitiveComparison ? "i)" : "") 
              "^\Q" registryCurrentDefaultValue "\E$"))
      {
        ; Default value given but unequal to expected

        errorType := Reg.__CanBeOverriddenByV2(ahkVersion, regObject) 
            ? RegNote ; Possibly overridden by v2
            : RegError ; v2 || only AHK v1 installed || (v1 && overriding not allowed)
        
        regEntries.Push(errorType(
              accumulatedBranch, isBranchMissing := false, valueName := "", 
              isValueMissing := false, value := registryCurrentDefaultValue, 
              valueExpected := regObject.expectedDefaultValue, isDefaultValue := true))
      }
      else if (regObject.HasOwnProp("originalDefaultValue") &&
          regObject.originalDefaultValue !== registryCurrentDefaultValue)
      {
        ; Default value given but changed

        regEntries.Push(RegWarning(
            accumulatedBranch, isBranchMissing := false, valueName := "", 
            isValueMissing := false, value := registryCurrentDefaultValue, 
            valueExpected := regObject.originalDefaultValue, isDefaultValue := true))
      }
      else 
      {
        ; Having a default value is sufficient, no need to compare?

        regEntries.Push(RegSuccess(
            accumulatedBranch, isBranchMissing := false, valueName := "",
            isValueMissing := false, value := registryCurrentDefaultValue, 
            valueExpected := (regObject.HasOwnProp("expectedDefaultValue")
                ? regObject.expectedDefaultValue : regObject.originalDefaultValue), 
            isDefaultValue := true))
      }
    }

    if (regObject.HasOwnProp("subKeys"))
    {
      for subKey in regObject.subKeys
      {
        for subKeyName, subValue in subKey.OwnProps()
        {
          if (subKeyName == "allowModificationByV2")
          {
            regEntries.Push(RegNote(
                accumulatedBranch, isBranchMissing := false, valueName := "", 
                isValueMissing := false, value := registryCurrentDefaultValue, 
                valueExpected := regObject.expectedDefaultValue, isDefaultValue := true))
            continue
          }

          registryEntryName := subKeyName

          if subValue.HasOwnProp("nonDefaultEntries")
          {
            for nonDefaultEntry in subValue.nonDefaultEntries
            {
              nonDefaultRegistryEntryName := nonDefaultEntry.key
              expectedValue := nonDefaultEntry.value
              
              errorType := Reg.__CanBeOverriddenByV2(ahkVersion, nonDefaultEntry) 
                  ? RegNote ; Possibly overridden by v2
                  : RegError ; v2 || only AHK v1 installed || (v1 && overriding not allowed)
              
              try
              {
                registryValue := RegRead(
                    accumulatedBranch "\" registryEntryName, nonDefaultRegistryEntryName)

                if (registryValue !== expectedValue)
                {
                  ; Value changed
                  
                  regEntries.Push(errorType(accumulatedBranch "\" registryEntryName, 
                      isBranchMissing := false, nonDefaultRegistryEntryName, 
                      isValueMissing := false, registryValue, expectedValue, 
                      isDefault := false))
                }
                else
                {
                  ; OK

                  regEntries.Push(RegSuccess(accumulatedBranch "\" registryEntryName, 
                      isBranchMissing := false, nonDefaultRegistryEntryName, 
                      isValueMissing := false, registryValue, expectedValue, 
                      isDefault := false))
                }
              }
              catch OSError as err
              {
                ; Entry missing

                regEntries.Push(errorType(accumulatedBranch "\" registryEntryName, 
                    isBranchMissing := false, valueName := nonDefaultRegistryEntryName, 
                    isValueMissing := true, value := "", valueExpected := expectedValue, 
                    isDefault := false))
              }
            }
          }
          
          if (IsObject(subValue)) ; Subkey
          {
            registryEntryName := StrReplace(registryEntryName, "_", "-")

            regEntries.Push(this.__DoAnalyze(
                ahkVersion, subValue, accumulatedBranch "\" registryEntryName)*)
          }
        }
      }
    }

    return regEntries
  }

  static __AnalyzeAhkScriptPath(ahkVersion)
  {
    versionKey := this.__VersionSettingsKey[ahkVersion]
    settingsRoot := RegSettings.%versionKey%.ahkScript

    ahkScriptErrors := this.__DoAnalyze(ahkVersion, settingsRoot)

    return ahkScriptErrors
  }

  static __AnalyzeDotAhkPath(ahkVersion)
  {
    versionKey := this.__VersionSettingsKey[ahkVersion]
    settingsRoot := RegSettings.%versionKey%.dotAhk
    dotAhkErrors := this.__DoAnalyze(ahkVersion, settingsRoot)

    return dotAhkErrors
  }

  static __CanBeOverriddenByV2(ahkVersion, registryBranch)
  {
    if (ahkVersion == Reg.AHK_VERSION.1 && 
        Reg.__IsAHKVersionInstalled(Reg.AHK_VERSION.2) &&
        registryBranch.HasOwnProp("allowModificationByV2") &&
        registryBranch.allowModificationByV2)
    {
      return true
    }

    return false
  }

  static __FindInstalledAhkVersions()
  {
    installedVersions := []

    try
    {
      newestInstalledVersion := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\AutoHotkey", "Version")
    }
    catch OSError as err
    {
      return installedVersions
    }

    if (newestInstalledVersion ~= "^1")
    {
      installedVersions.Push(Reg.AHK_VERSION.1)
    }
    else if (newestInstalledVersion ~= "^2")
    {
      installedVersions.Push(Reg.AHK_VERSION.2)
      
      loop reg "HKEY_CURRENT_USER\SOFTWARE\AutoHotkey\Launcher", "K"
      {
        if (A_LoopRegName == "v1")
        {
          installedVersions.Push(Reg.AHK_VERSION.1)
        }
      }
    }
    else
    {
      throw Error("Only AHK v1 and v2 supported.")
    }

    if (installedVersions.Length == 2)
    {
      installedVersions.InsertAt(1, installedVersions.Pop())
    }

    return installedVersions
  }
  
  static __IsAHKVersionInstalled(version)
  {
    for ahkVersion in Reg.InstalledAHKVersions
    {
      if (ahkVersion == version)
      {
        return true
      }
    }

    return false
  }

  static __VersionSettingsKey[ahkVersion]
  {
    get
    {
      switch (ahkVersion)
      {
        case Reg.AHK_VERSION.1:
          return "v1"
        case Reg.AHK_VERSION.2:
          return "v2"
        default:
          recognizedVersions := ""
          installedVersions := Reg.InstalledAHKVersions

          for versionString in installedVersions
          {
            recognizedVersions .= versionString " | "
          }

          recognizedVersions := substr(recognizedVersions, 1, -3)

          throw Error(Format(
                  "Unidentified AHK version requested. Recognized versions: {1}.",
                  recognizedVersions)
              -2, ahkVersion)
      }
    }
  }
}