Attribute VB_Name = "modWindow"
Option Explicit
'modSubclassing - project StealthBot
' authored 7/28/04 andy@stealthbot.net
' updated 4/12/06 to add transparency
' updated 12/24/06 to add hooking for the main send box on frmMain (merry Christmas!)

Private Type NMHDR
    hWndFrom As Long
    idFrom   As Long
    Code     As Long
End Type

Private Type CHARRANGE
    cpMin As Long
    cpMax As Long
End Type

Private Type ENLINK
    hdr    As NMHDR
    Msg    As Long
    wParam As Long
    lParam As Long
    chrg   As CHARRANGE
End Type

Private Type TEXTRANGE
    chrg      As CHARRANGE
    lpstrText As String
End Type

Private Type COPYDATASTRUCT
    dwData As Long
    cbData As Long
    lpData As Long
End Type

Public ID_TASKBARICON       As Integer
Public TASKBARCREATED_MSGID As Long

' windows messages
Private Const WM_SETREDRAW      As Long = &HB
Private Const WM_NOTIFY         As Long = &H4E
Private Const WM_COMMAND        As Long = &H111
Private Const WM_USER           As Long = &H400
Private Const WM_NCDESTROY      As Long = &H82
Private Const WM_COPYDATA       As Long = &H4A
Public Const WM_ICONNOTIFY      As Long = WM_USER + 100
' RTB rich edit control messages
Private Const EM_SETEVENTMASK   As Long = &H445
Private Const EM_GETEVENTMASK   As Long = &H43B
Private Const EM_GETTEXTRANGE   As Long = &H44B
Private Const EM_AUTOURLDETECT  As Long = &H45B
' RTB rich edit notifications
Private Const EN_LINK           As Long = &H70B
' EN_LINK effects
Private Const CFE_LINK          As Long = &H20
' EN_LINK message flag
Private Const ENM_LINK          As Long = &H4000000
' show window function
Private Const SW_SHOW           As Long = 5
' list view notifications
Private Const LVN_FIRST         As Long = -100&
Private Const LVN_BEGINDRAG     As Long = (LVN_FIRST - 9)
' WM_SETREDRAW values
Private Const RDW_INVALIDATE    As Long = &H1
Private Const RDW_ERASE         As Long = &H4
Private Const RDW_ALLCHILDREN   As Long = &H80
'Private Const RDW_ERASENOW      As Long = &H200
'Private Const RDW_UPDATENOW     As Long = &H100
Private Const RDW_FRAME         As Long = &H400

Private hWndSet As New Dictionary
Private hWndRTB As New Dictionary

Public Sub HookWindowProc(ByVal hWnd As Long)

    Dim OldWindowProc As Long
    
    OldWindowProc = SetWindowLong(hWnd, GWL_WNDPROC, AddressOf NewWindowProc)

    hWndSet(hWnd) = OldWindowProc
 
End Sub

Public Sub UnhookWindowProc(ByVal hWnd As Long)

    SetWindowLong hWnd, GWL_WNDPROC, hWndSet(hWnd)

    hWndSet.Remove hWnd

End Sub

Public Sub EnableURLDetect(ByVal hWndTextbox As Long)

    SendMessage hWndTextbox, EM_SETEVENTMASK, 0, ByVal ENM_LINK Or SendMessage(hWndTextbox, EM_GETEVENTMASK, 0, 0)
    SendMessage hWndTextbox, EM_AUTOURLDETECT, 1, ByVal 0

End Sub

Public Sub DisableURLDetect(ByVal hWndTextbox As Long)

    SendMessage hWndTextbox, EM_AUTOURLDETECT, 0, ByVal 0

End Sub

Public Function NewWindowProc(ByVal hWnd As Long, ByVal Msg As Long, ByVal wParam As Long, ByVal lParam As Long) As Long

    Dim Rezult As Long
    Dim uHead  As NMHDR
    Dim eLink  As ENLINK
    Dim eText  As TEXTRANGE
    Dim sText  As String
    Dim lLen   As Long
    Dim cds As COPYDATASTRUCT
    Dim buf(0 To 255) As Byte
    Dim Data As String
    
    If Msg = TASKBARCREATED_MSGID Then
        Shell_NotifyIcon NIM_ADD, nid
    End If
    
    If wParam = ID_TASKBARICON Then
        Select Case lParam
            Case WM_LBUTTONUP
                frmChat.WindowState = vbNormal
                Rezult = SetForegroundWindow(frmChat.hWnd)
                frmChat.Show
            Case WM_RBUTTONUP
                SetForegroundWindow frmChat.hWnd
                frmChat.PopupMenu frmChat.mnuTray
        End Select
    End If
    
    If Msg = WM_NOTIFY Then
        CopyMemory uHead, ByVal lParam, LenB(uHead)
       
        If (uHead.Code = EN_LINK) Then
            CopyMemory eLink, ByVal lParam, LenB(eLink)
       
            With eLink
                If .Msg = WM_LBUTTONDBLCLK Then
                    eText.chrg.cpMin = .chrg.cpMin
                    eText.chrg.cpMax = .chrg.cpMax
                    eText.lpstrText = Space$(1024)
       
                    lLen = SendMessageAny(uHead.hWndFrom, EM_GETTEXTRANGE, 0, eText)
                    sText = Left$(eText.lpstrText, lLen)
       
                    ShellOpenURL sText, , False
                End If
            End With
            
        ' See if this is the start of a drag.
        ElseIf uHead.Code = LVN_BEGINDRAG Then
            ' A drag is beginning. Ignore this event.
            ' Indicate we have handled this.
            NewWindowProc = 1
            ' Do nothing else.
            Exit Function
        End If
    ElseIf Msg = WM_COMMAND Then
        If lParam = 0 Then
            MenuClick hWnd, wParam
        End If
    ElseIf Msg = WM_COPYDATA Then
        Call CopyMemory(cds, ByVal lParam, Len(cds))
        If (cds.cbData < UBound(buf)) Then
            Call CopyMemory(buf(0), ByVal cds.lpData, cds.cbData)
            Data = NTByteArrToString(buf)
            If (StrComp(Data, "-reloadscripts", vbTextCompare) = 0) Then
                SharedScriptSupport.ReloadScript
            End If
        End If
    End If
    
    NewWindowProc = CallWindowProc(hWndSet(hWnd), hWnd, Msg, wParam, lParam)
    
End Function

Public Function DisableWindowRedraw(ByVal hWnd As Long)

    Call SendMessage(hWnd, WM_SETREDRAW, False, 0)

End Function

Public Function EnableWindowRedraw(ByVal hWnd As Long)

    Call SendMessage(hWnd, WM_SETREDRAW, True, 0)
    Call RedrawWindow(hWnd, 0, 0, RDW_ERASE Or RDW_FRAME Or RDW_INVALIDATE Or RDW_ALLCHILDREN)

End Function
