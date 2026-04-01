Option Explicit

Dim fso, shellApp, root, backgroundExe, backgroundArg, launcherExe, launcherDir
Set fso = CreateObject("Scripting.FileSystemObject")
Set shellApp = CreateObject("Shell.Application")

root = fso.GetParentFolderName(fso.GetParentFolderName(WScript.ScriptFullName))
backgroundExe = root & "\dist\background\Navi Background.exe"
backgroundArg = ""
launcherExe = root & "\dist\launcher\voice_navigator.exe"
launcherDir = root & "\dist\launcher"

If Not IsBackgroundRunning() Then
  If fso.FileExists(backgroundExe) Then
    shellApp.ShellExecute backgroundExe, backgroundArg, root, "open", 0
  Else
    backgroundExe = root & "\.venv-background\Scripts\Navi Background.exe"
    backgroundArg = Chr(34) & root & "\background_service\src\main.py" & Chr(34)
    If fso.FileExists(backgroundExe) Then
      shellApp.ShellExecute backgroundExe, backgroundArg, root, "open", 0
    End If
  End If
End If

If fso.FileExists(launcherExe) Then
  shellApp.ShellExecute launcherExe, "", launcherDir, "open", 1
Else
  MsgBox "Built launcher executable was not found." & vbCrLf & _
         "Run build_release_bundle.bat or scripts\build_flutter_launcher.ps1 first.", _
         vbOKOnly + vbInformation, "Navi: Voice Navigator"
End If

Function IsBackgroundRunning()
  Dim service, processes
  On Error Resume Next
  Set service = GetObject("winmgmts:\\.\root\cimv2")
  Set processes = service.ExecQuery("SELECT * FROM Win32_Process WHERE Name='Navi Background.exe'")
  If Err.Number <> 0 Then
    IsBackgroundRunning = False
    Err.Clear
    Exit Function
  End If

  IsBackgroundRunning = (processes.Count > 0)
End Function
