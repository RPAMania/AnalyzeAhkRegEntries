/************************************************************************
 * @description Analyzes Windows Registry for certain AHK v1/v2 entries, 
 *              including those that enable AHK-related Explorer context
 *              menu items.
 * @file AnalyzeAhkRegEntries.ahk
 * @author TJay🐦
 * @date 2023/03/28
 * @version 0.0.1
 ***********************************************************************/

#Requires AutoHotkey v2
#Include lib
#Include Reg.ahk
#Include RegSettings.ahk
#Include RegError.ahk
#Include RegWarning.ahk
#Include RegNote.ahk
#Include RegSuccess.ahk

if (!A_IsAdmin)
{
  Run "*RunAs `"" A_ScriptFullPath "`""
  ExitApp
}

installedVersions := Reg.InstalledAHKVersions

mainGui := Gui("-MinimizeBox -MaximizeBox", "AHK Registry Analysis Tool")
mainGui.Add("Text", "", "Choose AHK version for registry analysis")
mainGui.Add("DropDownList", "vGUIAhkVersion wp y+5 choose" (installedVersions.Length ? 1 : ""), 
    installedVersions)
mainGui.Add("Button", "vGUIStartAnalysis wp y+10 h30 default disabled" 
    (installedVersions.Length == 0), "Analyze").OnEvent("Click", (*) => (
        mainGui["GUIStartAnalysis"].Enabled := false,
        Reg.Analyze(
            mainGui["GUIAhkVersion"].Text, 
            (dotAhkBranch, dotAhkResults, ahkScriptBranch, ahkScriptResults) => (
                DisplayResults(dotAhkBranch, dotAhkResults, ahkScriptBranch, ahkScriptResults), 
                mainGui["GUIStartAnalysis"].Enabled := true))))
mainGui.Show("Autosize")



DisplayResults(dotAhkBranch, dotAhkResults, ahkScriptBranch, ahkScriptResults)
{
  resultsGui := Gui("+SysMenu +AlwaysOnTop +Resize +LastFound Owner " mainGui.Hwnd 
      " -MinimizeBox", "Registry Verification Results – AHK "
      RegexReplace(mainGui["GUIAhkVersion"].Text, ".*?(\w+$)", "$1"))
  
  imageList := IL_Create(4)
  
  MonitorGet(, &monitorLeft, , &monitorRight)
  
  listView := resultsGui.Add("ListView", "vGUIListView NoSortHdr Grid NoSort -LV0x10 w" 
      Min(monitorRight - monitorLeft, 1040) " r20", 
      [ "", "Notification", "Key Name", "Current Value", "Expected/Initial Value", "Branch" ])
  
  listView.SetImageList(imageList)
  
  IL_Add(imageList, "shell32.dll", 297) ; OK – Green checkmark
  IL_Add(imageList, "shell32.dll", 278) ; Note – White speech bubble with blue "i" character
  IL_Add(imageList, "shell32.dll",  78) ; Warning – Yellow triangle with black exclamation point
  IL_Add(imageList, "shell32.dll", 132) ; Error – Red X

  for regBranchName, regBranchResults in Map(
      dotAhkBranch, dotAhkResults, 
      ahkScriptBranch, ahkScriptResults)
  {
    for (result in regBranchResults)
    {
      notificationText := RegExReplace(result.__Class, "^Reg")

      switch (result.Base)
      {
        case RegSuccess.Prototype:
          iconIndex := 1
        case RegNote.Prototype: 
          iconIndex := 2
          notificationText .= ": " (result.branch.isMissing 
              ? "Branch removed" : "Value modified") . " (possibly by AHK v2)"
        case RegWarning.Prototype: 
          iconIndex := 3
          notificationText .= ": Value modified"
        case RegError.Prototype:
          iconIndex := 4
          notificationText .= ": " (result.branch.isMissing ? "Branch" : "Value") " missing"
        default: throw Error(Format("Unknown registry result class.", , Type(result)))
      }

      
      listView.Add("Icon" iconIndex, , notificationText,
          result.value.name, result.value.found, result.value.expected, result.branch.name)
    }
  }
  
  listView.ModifyCol(2, 140)

  loop listView.GetCount("Col")
  {
    if (A_Index <= 2)
    {
      continue
    }

    if (A_Index == 4 || A_Index == 5)
    {
      listView.ModifyCol(A_Index, 200)
      continue
    }

    listView.ModifyCol(A_Index, "AutoHdr")
  }

  resultsGui.Show("AutoSize")

  mainGui.Opt("+Disabled")
  listView.GetPos(, , &lvWidth, &lvHeight)
  WinGetClientPos(, , &guiWidth, &guiHeight, WinExist())

  guiMargin := { hori: (guiWidth - lvWidth) // 2, vert: (guiHeight - lvHeight) // 2 }

  resultsGui.OnEvent("Size", (resultsGui, minmax, clientWidth, clientHeight) =>
    listView.Move(, , clientWidth - 2 * guiMargin.hori, clientHeight - 2 * guiMargin.vert)
  )

  resultsGui.OnEvent("Close", (*) => mainGui.Opt("-Disabled"))
}