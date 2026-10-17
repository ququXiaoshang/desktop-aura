' Launch Desktop Aura independently (no console window, independent of DeepSeek Harness).
Set fso = CreateObject("Scripting.FileSystemObject")
Set ws = CreateObject("Wscript.Shell")

' Remove environment variables that would force Electron to run as plain Node.
Set env = ws.Environment("Process")
env.Remove("ELECTRON_RUN_AS_NODE")
env.Remove("ELECTRON_NO_ATTACH_CONSOLE")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
exe = scriptDir & "\node_modules\electron\dist\electron.exe"
ws.Run """" & exe & """ """ & scriptDir & """", 0, False
