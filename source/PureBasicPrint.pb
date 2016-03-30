;------------------------------------------------------------------------------------------
; 
; Project :      PureBasicPrint
; Version :      1.0 (Beta 2), 2009-08-02.
; Purpose :      A PureBasic IDE Tool to print syntax colored code sources.
; 
; Author :       Flype, flype(at)gmail(dot)com
; 
; Homepage :     http://www.purebasic.fr/english/viewtopic.php?t=38375
;                http://www.purebasic.fr/french/viewtopic.php?t=9626
; 
; Requirements : Need <SyntaxHilighting.dll> in the executable folder.
;                This library is provided in the PureBasic package.
;                At the moment this library is not available for Linux/MacOS :(
; 
;                In order to use your IDE settings, the program try to load 
;                the file <PureBasic.prefs> in the executable folder or
;                if not found it try <%APPDATA/PureBasic/PureBasic.prefs>.
; 
;                And of course a printer, or even a virtual printer (Ex: PDFCreator).
; 
;------------------------------------------------------------------------------------------
; 
; TODO :
; 
; [ ] Add       : Implements Line Spacing.
; [ ] Add       : Graphical User Interface (?).
; [ ] Add       : Installer (Copy files, ToolMenu, ToolBar, Shortcuts).
; [ ] Add       : Do not prints IDE Options at the bottom of the .PB file.
; [x] Add       : [ADDED] Better language support (English, Deutsch, Francais, Spanish).
; [ ] Add       : Linux/MacOS Compatible.
;                 Should be but the Syntax Hilighting SDK 
;                 is not available on Linux/MacOS at the moment.
; 
; [ ] Optimize  : Some redundant calculations can be optimized.
; [ ] Optimize  : Read IDE Options starting from end of .PB file.
;                 This should increase a bit the loading part especially with big files.
; 
; [ ] Known Bug : Line Wrapping do not works on large comments at the moment.
; [x] Known Bug : [FIXED] Color mistake when wrapping a line which is inside %CURSOR.
; [x] Known Bug : [FIXED] PageBreaks were processed even if outside of the %SELECTION.
; [x] Known Bug : [FIXED] Some problems with non-fixed fonts (line numbers).
; 
;------------------------------------------------------------------------------------------

EnableExplicit

#TITLE = "PureBasicPrint v1.0 (Beta 2)"

Enumeration 0 ; Tokens
	#PB_Token_Text
	#PB_Token_Keyword
	#PB_Token_Comment
	#PB_Token_Constant
	#PB_Token_String
	#PB_Token_Function
	#PB_Token_Asm
	#PB_Token_Operator
	#PB_Token_Structure
	#PB_Token_Number
	#PB_Token_Pointer
	#PB_Token_Separator
	#PB_Token_Label
	#PB_Token_Max
EndEnumeration

CompilerIf #PB_Compiler_OS = #PB_OS_Windows
	Import #PB_Compiler_Home + "SDK/Syntax Highlighting/SyntaxHilighting.lib"
		SyntaxHighlight(*Buffer, Length.l, *Callback, bEnableASM.l)
	EndImport
CompilerElse
	CompilerError "At the moment, <SyntaxHilighting.lib> is only available on Windows."
CompilerEndIf

CompilerIf #PB_Compiler_OS = #PB_OS_Windows

Procedure.s GetSpecialFolderLocation(folder)
	
	Protected pid, path.s
	
	If SHGetSpecialFolderLocation_(#Null, folder, @pid) = #S_OK
		
		path = Space(#MAX_PATH)
		
		If ( SHGetPathFromIDList_(pid, @path) = #True ) And ( Right(path, 1) <> "\" )
			path + "\"
		EndIf
		
	EndIf
	
	ProcedureReturn path
	
EndProcedure 

CompilerEndIf

;------------------------------------------------------------------------------------------
;--- Structures
;------------------------------------------------------------------------------------------

Structure OPTIONS
	BuildCount.s
	CompileCount.s
	Markers.s
EndStructure

Structure ARGUMENTS
	ColorMode.s
	CursorX.l
	CursorY.l
	Filename.s
	Magnification.f
	MarginLeft.l
	MarginRight.l
	MarginTop.l
	MarginBottom.l
	PageBreaks.l
	Requester.l
	SelectionLineStart.l
	SelectionLineEnd.l
EndStructure

Structure PREFERENCES
	CurrentLanguage.s
	TabLength.l
	RealTab.l
	EnableColoring.l
	EnableKeywordBolding.l
	EnableLineNumbers.l
	DisplayFullPath.l
	EditorFontName.s
	EditorFontSize.l
	EditorFontStyle.l
	BackgroundColor.l
	ProcedureBackColor.l
	LineNumberColor.l
	LineNumberBackColor.l
	CurrentLineColor.l
	SelectionColor.l
	TokenColor.l[13]
EndStructure

;------------------------------------------------------------------------------------------
;--- Globals
;------------------------------------------------------------------------------------------

Global Args.ARGUMENTS
Global Options.OPTIONS
Global Prefs.PREFERENCES

Global InsideProcedure
Global DrawingX, DrawingY
Global FontNormal, FontBold
Global LineNumber, LineHeight
Global PageWidth, PageHeight, PageNumber

;------------------------------------------------------------------------------------------
;--- Procedures
;------------------------------------------------------------------------------------------

Procedure ReadPreferences()
	
	Protected Filename.s = "PureBasic.prefs"
	
	CompilerIf #PB_Compiler_OS = #PB_OS_Windows
		If FileSize(Filename) = -1
			Filename = GetSpecialFolderLocation(#CSIDL_APPDATA) + "PureBasic\PureBasic.prefs"
		EndIf
	CompilerEndIf
	
	OpenPreferences(Filename)
	
	PreferenceGroup("Global")
	
	Prefs\CurrentLanguage      = ReadPreferenceString("CurrentLanguage",      "English")
	Prefs\TabLength            = ReadPreferenceLong  ("TabLength",            2)
	Prefs\RealTab              = ReadPreferenceLong  ("RealTab",              #False)
	Prefs\EnableColoring       = ReadPreferenceLong  ("EnableColoring",       #False)
	Prefs\EnableKeywordBolding = ReadPreferenceLong  ("EnableKeywordBolding", #False)
	Prefs\EnableLineNumbers    = ReadPreferenceLong  ("EnableLineNumbers",    #False)
	Prefs\DisplayFullPath      = ReadPreferenceLong  ("DisplayFullPath",      #False)
	
	PreferenceGroup("Editor")
	
	Prefs\EditorFontName       = ReadPreferenceString("EditorFontName",  "Courier")
	Prefs\EditorFontSize       = ReadPreferenceLong  ("EditorFontSize",  10)
	Prefs\EditorFontStyle      = ReadPreferenceLong  ("EditorFontStyle",  0)
	
	Prefs\BackgroundColor      = ReadPreferenceLong  ("BackgroundColor",     $FFFFFF)
	Prefs\ProcedureBackColor   = ReadPreferenceLong  ("ProcedureBackColor",  $FFFFFF)
	Prefs\LineNumberColor      = ReadPreferenceLong  ("LineNumberColor",     $000000)
	Prefs\LineNumberBackColor  = ReadPreferenceLong  ("LineNumberBackColor", $FFFFFF)
	Prefs\CurrentLineColor     = ReadPreferenceLong  ("CurrentLineColor",    $00FFFF)
	Prefs\SelectionColor       = ReadPreferenceLong  ("SelectionColor",      $808080)
	
	Prefs\TokenColor[#PB_Token_Text     ] = ReadPreferenceLong("NormalTextColor",   $000000)
	Prefs\TokenColor[#PB_Token_Keyword  ] = ReadPreferenceLong("BasicKeywordColor", $000000)
	Prefs\TokenColor[#PB_Token_Comment  ] = ReadPreferenceLong("CommentColor",      $000000)
	Prefs\TokenColor[#PB_Token_Constant ] = ReadPreferenceLong("ConstantColor",     $000000)
	Prefs\TokenColor[#PB_Token_String   ] = ReadPreferenceLong("StringColor",       $000000)
	Prefs\TokenColor[#PB_Token_Function ] = ReadPreferenceLong("PureKeywordColor",  $000000)
	Prefs\TokenColor[#PB_Token_Asm      ] = ReadPreferenceLong("ASMKeywordColor",   $000000)
	Prefs\TokenColor[#PB_Token_Operator ] = ReadPreferenceLong("OperatorColor",     $000000)
	Prefs\TokenColor[#PB_Token_Structure] = ReadPreferenceLong("StructureColor",    $000000)
	Prefs\TokenColor[#PB_Token_Number   ] = ReadPreferenceLong("NumberColor",       $000000)
	Prefs\TokenColor[#PB_Token_Pointer  ] = ReadPreferenceLong("PointerColor",      $000000)
	Prefs\TokenColor[#PB_Token_Separator] = ReadPreferenceLong("SeparatorColor",    $000000)
	Prefs\TokenColor[#PB_Token_Label    ] = ReadPreferenceLong("LabelColor",        $000000)
	
	ClosePreferences()
	
EndProcedure

Procedure ReadArguments()
	
	Protected index, argument.s, name.s, value.s
	
	Args\MarginLeft   = -1
	Args\MarginRight  = -1
	Args\MarginTop    = -1
	Args\MarginBottom = -1	
	
	For index = 0 To 9
		
		argument = ProgramParameter(index)
		name     = UCase(StringField(argument, 1, "="))
		value    = StringField(argument, 2, "=")
		
		If Left(value, 1) = Chr(34)
			value = Mid(value, 2)
		EndIf
		
		If Right(value, 1) = Chr(34)
			value = Left(value, Len(value) - 1)
		EndIf
		
		Select name
			
			Case ""
				
			Case "COLORMODE"
				
				Args\ColorMode = UCase(value)
				
				Select value
					
					Case "IDE"
						
					Case "IDEONWHITE"
						
						Prefs\BackgroundColor     = $FFFFFF
						Prefs\ProcedureBackColor  = $FFFFFF
						Prefs\LineNumberBackColor = $FFFFFF
						
					Case "BLACKONWHITE"
						
						Prefs\LineNumberColor     = $000000
						Prefs\LineNumberBackColor = $FFFFFF
						Prefs\CurrentLineColor    = $FFFFFF
						Prefs\SelectionColor      = $FFFFFF
						Prefs\BackgroundColor     = $FFFFFF
						Prefs\ProcedureBackColor  = $FFFFFF
						
						Prefs\TokenColor[#PB_Token_Text     ] = $000000
						Prefs\TokenColor[#PB_Token_Keyword  ] = $000000
						Prefs\TokenColor[#PB_Token_Comment  ] = $000000
						Prefs\TokenColor[#PB_Token_Constant ] = $000000
						Prefs\TokenColor[#PB_Token_String   ] = $000000
						Prefs\TokenColor[#PB_Token_Function ] = $000000
						Prefs\TokenColor[#PB_Token_Asm      ] = $000000
						Prefs\TokenColor[#PB_Token_Operator ] = $000000
						Prefs\TokenColor[#PB_Token_Structure] = $000000
						Prefs\TokenColor[#PB_Token_Number   ] = $000000
						Prefs\TokenColor[#PB_Token_Pointer  ] = $000000
						Prefs\TokenColor[#PB_Token_Separator] = $000000
						Prefs\TokenColor[#PB_Token_Label    ] = $000000
						
				EndSelect
				
			Case "CURSOR"
				
				Args\CursorY = Val(StringField(value, 1, "x"))
				Args\CursorX = Val(StringField(value, 2, "x"))
				
			Case "MAGNIFICATION"
				
				Args\Magnification = ValF(value)
				
			Case "MARGINS"
				
				Args\MarginLeft   = Val(StringField(value, 1, "x"))
				Args\MarginRight  = Val(StringField(value, 2, "x"))
				Args\MarginTop    = Val(StringField(value, 3, "x"))
				Args\MarginBottom = Val(StringField(value, 4, "x"))
				
			Case "PAGEBREAKS"
				
				If Val(value) = #True
					Args\PageBreaks = #True
				EndIf
				
			Case "REQUESTER"
				
				If Val(value) = #True
					Args\Requester = #True
				EndIf
				
			Case "SELECTION"
				
				Args\SelectionLineStart = Val(StringField(value, 1, "x"))
				Args\SelectionLineEnd   = Val(StringField(value, 3, "x"))
				
			Default
				
				If Args\Filename = ""
					Args\Filename = argument
				EndIf
				
		EndSelect
		
	Next
	
EndProcedure

Procedure ReadOptions()
	
	Protected file, line.s, option.s
	
	file = ReadFile(#PB_Any, Args\Filename)
	
	If file
		
		While Not Eof(file)
			
			line = ReadString(file)
			
			If line
				
				option = Trim(StringField(line, 1, "="))
				
				Select option
					
					Case "; Markers"
						
						Options\Markers = Trim(StringField(line, 2, "="))
						
					Case "; EnableCompileCount"
						
						Options\CompileCount = Trim(StringField(line, 2, "="))
						
					Case "; EnableBuildCount"
						
						Options\BuildCount = Trim(StringField(line, 2, "="))
						
				EndSelect
				
			EndIf
			
		Wend
		
		CloseFile(file)
		
	EndIf
	
EndProcedure

Procedure GetNextMarker()
	
	Static index = 1
	
	Protected marker = Val(StringField(Options\Markers, index, ","))
	
	index + 1
	
	Debug "Marker: " + Str(marker)
	
	ProcedureReturn marker
	
EndProcedure

Procedure DrawHeader()
	
	;--- Draw BackgroundColor
	
	Box(Args\MarginLeft, Args\MarginTop, PageWidth - Args\MarginLeft - Args\MarginRight, PageHeight - Args\MarginTop - Args\MarginBottom, Prefs\BackgroundColor)
	
	;--- Draw Current Filename
	
	DrawingFont(FontNormal)
	
	If Prefs\DisplayFullPath
		DrawText(Args\MarginLeft, Args\MarginTop - LineHeight, Args\Filename)
	Else
		DrawText(Args\MarginLeft, Args\MarginTop - LineHeight, GetFilePart(Args\Filename))
	EndIf
	
	;--- Draw Build Count
	
	If Options\BuildCount 
		Protected text.s = "Build #" + Options\BuildCount
		DrawText(PageWidth - Args\MarginRight - TextWidth(text), Args\MarginTop - LineHeight, text)
	EndIf
	
	;--- Draw MarginTop Line
	
	Line(Args\MarginLeft, Args\MarginTop, PageWidth - Args\MarginLeft - Args\MarginRight, 0)
	
	;--- Draw the gutter (LineNumber Background)
	
	Protected y = Args\MarginTop + LineHeight
	Protected h = PageHeight - Args\MarginTop - Args\MarginBottom - LineHeight * 2
	
	If Prefs\EnableLineNumbers
		Box(Args\MarginLeft, y, TextWidth("99999"), h, Prefs\LineNumberBackColor)
	EndIf
	
	Box(PageWidth - Args\MarginRight, y, 1, h, Prefs\LineNumberBackColor)
	
EndProcedure

Procedure DrawFooter(size)
	
	Protected text.s
	
	;--- Draw Current File Size
	
	text = Str(size)
	
	Select Prefs\CurrentLanguage 
		Case "English"
			text + " bytes"
		Case "Francais"
			text + " octets"
		Case "Deutsch"
			text + " bytes"
		Case "Spanish"
			text + " octetos"
		Default
			text + " bytes"
	EndSelect
	
	DrawingFont(FontNormal)
	DrawText(Args\MarginLeft, PageHeight - Args\MarginBottom + 10, text)
	
	;--- Draw Current Page Number
	
	Select Prefs\CurrentLanguage
		Case "English"
			text = "- Page "
		Case "Francais"
			text = "- Page "
		Case "Deutsch"
			text = "- Seite "
		Case "Spanish"
			text = "- Página "
		Default
			text = "- Page "
	EndSelect
	
	text + Str(PageNumber) + " -"
	
	DrawText((PageWidth - TextWidth(text)) / 2, PageHeight - Args\MarginBottom + 10, text)
	
	;--- Draw Current Date
	
	Select Prefs\CurrentLanguage
		Case "English"
			text = FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Date()) 
		Case "Francais"
			text = FormatDate("%dd/%mm/%yyyy %hh:%ii:%ss", Date()) 
		Case "Deutsch"
			text = FormatDate("%dd/%mm/%yyyy %hh:%ii:%ss", Date()) 
		Case "Spanish"
			text = FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Date()) 
		Default
			text = FormatDate("%yyyy-%mm-%dd %hh:%ii:%ss", Date()) 
	EndSelect
	
	DrawText(PageWidth - Args\MarginRight - TextWidth(text), PageHeight - Args\MarginBottom + 10, text)
	
	;--- Draw MarginBottom Line
	
	Line(Args\MarginLeft, PageHeight - Args\MarginBottom, PageWidth - Args\MarginLeft - Args\MarginRight, 0)
	
EndProcedure

Procedure DrawLineBackground()
	
	If LineNumber = Args\CursorY
		Box(DrawingX + 4, DrawingY, PageWidth - DrawingX - Args\MarginRight - 8, LineHeight, Prefs\CurrentLineColor)
	ElseIf InsideProcedure
		Box(DrawingX + 4, DrawingY, PageWidth - DrawingX - Args\MarginRight - 8, LineHeight, Prefs\ProcedureBackColor)
	EndIf
	
EndProcedure

Procedure DrawLineNumber(bDrawLine)
	
	If Prefs\EnableLineNumbers
		
		;--- Draw Line Number
		
		DrawingFont(FontNormal)
		
		Protected text.s = Str(LineNumber) 
		Protected width = TextWidth("99999")
		
		DrawingX + width
		
		If bDrawLine
			DrawText(DrawingX - TextWidth(text) - (width / 6), DrawingY, text, Prefs\LineNumberColor)
		EndIf
		
	EndIf
	
	DrawLineBackground()
	
EndProcedure

Procedure DrawLineCallback(*position, length, type)
	
	Protected text.s = PeekS(*position, length)
	
	;--- Check if Inside Procedure
	
	If Left(text, 9) = "Procedure"
		InsideProcedure = #True
	EndIf
	
	DrawLineBackground()
	
	;--- Keyword Bolding
	
	If type = #PB_Token_Keyword And Prefs\EnableKeywordBolding
		DrawingFont(FontBold)
	Else
		DrawingFont(FontNormal)
	EndIf
	
	;--- Wrap Line
	
	If type <> #PB_Token_Comment And ( DrawingX + TextWidth(text) ) > ( PageWidth - Args\MarginRight )
		Debug "Wrap Line : " + Str(LineNumber)
		DrawingX = Args\MarginLeft
		DrawingY + LineHeight
		DrawLineNumber(#False)
		DrawLineBackground()
	EndIf
	
	;--- Keyword Bolding
	
	If type = #PB_Token_Keyword And Prefs\EnableKeywordBolding
		DrawingFont(FontBold)
	Else
		DrawingFont(FontNormal)
	EndIf
	
	;--- Draw Token
	
	If Prefs\EnableColoring
		DrawText(DrawingX, DrawingY, text, Prefs\TokenColor[type])
	Else
		DrawText(DrawingX, DrawingY, text, $000000)
	EndIf
	
	;--- Check if Outside Procedure
	
	If Left(text, 12) = "EndProcedure"
		InsideProcedure = #False
	EndIf
	
	;--- Move Drawing Position
	
	DrawingX + TextWidth(text)
	
EndProcedure

Procedure DrawFile(Filename.s)
	
	Protected FileID, Marker, NewPage, LineText.s
	Protected JobName.s, TabSpaces.s = Space(Prefs\TabLength)
	
	;--- Opens files to print
	
	FileID = ReadFile(#PB_Any, Filename)
	
	If FileID
		
		;--- Initializes printer
		
		If Args\Requester
			If Not PrintRequester()
				End
			EndIf
		Else
			If Not DefaultPrinter()
				MessageRequester(#TITLE, "DefaultPrinter() failed !")
				End
			EndIf
		EndIf
		
		;--- Retrieves the printer JobName
		
		JobName = GetFilePart(Filename)
		
		If GetExtensionPart(Filename)
			JobName = Left(JobName, Len(GetExtensionPart(Filename)) - 1)
		EndIf
		
		;--- Loads NORMAL and BOLD Editor IDE font.
		
		FontNormal = FontID(LoadFont(#PB_Any, Prefs\EditorFontName, Prefs\EditorFontSize * Args\Magnification, Prefs\EditorFontStyle))
		FontBold   = FontID(LoadFont(#PB_Any, Prefs\EditorFontName, Prefs\EditorFontSize * Args\Magnification, Prefs\EditorFontStyle | #PB_Font_Bold)) 
		
		;--- Starts drawing.
		
		If StartPrinting(JobName)
			
			If StartDrawing(PrinterOutput())
				
				DrawingFont(FontBold)
				DrawingMode(#PB_2DDrawing_Transparent)
				
				LineNumber = 1
				LineHeight = TextHeight("^/\|_[({})]123456789aApPqQgG")
				
				PageNumber = 1
				PageWidth  = PrinterPageWidth()
				PageHeight = PrinterPageHeight()
				
				If Args\MarginLeft   < 0 : Args\MarginLeft   = 10 : EndIf
				If Args\MarginRight  < 0 : Args\MarginRight  = 10 : EndIf
				If Args\MarginTop    < 0 : Args\MarginTop    = LineHeight * 2 : EndIf
				If Args\MarginBottom < 0 : Args\MarginBottom = LineHeight * 2 : EndIf
				
				DrawHeader()
				DrawFooter(Lof(FileID))
				DrawingFont(FontNormal)
				
				Marker = GetNextMarker()
				
				DrawingY = Args\MarginTop
				
				While Not Eof(FileID)
					
					;--- New Line
					
					LineText = ReadString(FileID)
					
					If ( Args\SelectionLineStart = Args\SelectionLineEnd ) Or ( LineNumber >= Args\SelectionLineStart And LineNumber < Args\SelectionLineEnd )
						
						If LineText
							LineText = ReplaceString(LineText, #TAB$, TabSpaces)
						EndIf
						
						DrawingX = Args\MarginLeft
						DrawingY + LineHeight
						
						DrawLineNumber(#True)
						
						SyntaxHighlight(@LineText, Len(LineText), @DrawLineCallback(), #True)
						
						;--- Page Break
						
						If Args\PageBreaks And Marker = LineNumber + 1
							NewPage = #True
						EndIf
						
					EndIf
					
					;--- Get Next Page Break
					
					If Args\PageBreaks And Marker = LineNumber + 1
						Marker = GetNextMarker()
					EndIf
					
					LineNumber + 1
					
					;--- New Page
					
					If DrawingY > ( PageHeight - Args\MarginBottom - LineHeight - LineHeight - LineHeight)
						NewPage = #True
					EndIf
					
					If NewPage 
						DrawingY = Args\MarginTop
						PageNumber + 1
						NewPage = #False
						NewPrinterPage()
						DrawingFont(FontBold)
						DrawHeader()
						DrawFooter(Lof(FileID))
						DrawingFont(FontNormal)
					EndIf
					
				Wend
				
				StopDrawing()
				
			Else
				
				MessageRequester(#TITLE, "StartDrawing(PrinterOutput()) failed !")
				
			EndIf
			
			StopPrinting()
			
		Else
			
			MessageRequester(#TITLE, "StartPrinting(" + Chr(34) + JobName + Chr(34) + ") failed !")
			
		EndIf
		
		CloseFile(FileID)
		
	Else
		
		MessageRequester(#TITLE, "ReadFile(" + Chr(34) + Filename + Chr(34) + ") failed !")
		
	EndIf
	
EndProcedure

;------------------------------------------------------------------------------------------
;--- Main part
;------------------------------------------------------------------------------------------

ReadPreferences()
ReadArguments()
ReadOptions()

CompilerIf #PB_Compiler_Debugger
	XIncludeFile "PureBasicPrint_DEBUG.pb"
CompilerEndIf

DrawFile(Args\Filename)

End

;------------------------------------------------------------------------------------------
;--- End of file
;------------------------------------------------------------------------------------------
; IDE Options = PureBasic 5.42 LTS (Windows - x86)
; Folding = ---
; Executable = ..\build\PureBasicPrint.exe
; CommandLine = purebasicprint.pb magnification=1.5
; EnableCompileCount = 13
; EnableBuildCount = 5
; EnableExeConstant