
// === CONFIGURATION

CLEAR_AT_EXIT=true
CLEAR_AT_STARTUP=true
DISPLAY_NR=1

COLORS = [color.orange, color.fuchsia, color.lime, color.aqua]

// Map key to color index
KEY_COLOR_MAP = {
"o": 0,
"g": 2,
"l": 2,
"f": 1,
"a": 3}

// Color menu items (normal / selected)
COLOR_MENU_ITEMS = {
color.orange: ["$(W:O)$(O:rng)", "$(WW:O)$(OO:rng)"],
color.fuchsia: ["$(W:F)$(F:chsia)", "$(WW:F)$(FF:chsia)"],
color.lime: ["$(W:L)$(L:ime)", "$(WW:L)$(LL:ime)"],
color.aqua: ["$(W:A)$(A:qua)", "$(WW:A)$(AA:qua)"]}

// Map for building the menu's colored-string
// (null for "default")
COLORED_STRING_MAPPING = {
// Normal colors
"W": [color.white, null],
"O": [color.orange, null],
"F": [color.fuchsia, null],
"L": [color.lime, null],
"A": [color.aqua, null],
"G": [color.gray, null],
// Inverted colors
"SS": [color.black, color.silver],
"WW": [color.black, color.white],
"OO": [color.black, color.orange],
"FF": [color.black, color.fuchsia],
"LL": [color.black, color.lime],
"AA": [color.black, color.aqua]}


// === PUBLIC API - DRAW INTERACTIVELY

draw = function
	Overlay.setup
	Overlay.draw
end function

// === PUBLIC API - DRAW EMBEDDED

// Use this withing your programs if you want
// to invoke this tool from within them, while
// retaining your own update cycle (your animations, etc.)
//
// Be sure to call "setup" first and then upon each of 
// your iterations the "update" function.

setup = function
	Overlay.setup DISPLAY_NR
end function

update = function
	Overlay.update
end function

// === CONSTANTS

K_ESC = "escape"
K_BACKSPACE = "backspace"

TOOL_MARKER = "marker"
TOOL_BRUSH = "brush"
TOOL_ERASER = "eraser"

// === OVERLAY

Overlay = {}
Overlay.dsp = null
Overlay.canvas = null
Overlay.canvasSprite = null
Overlay.colorIdx = 0
Overlay.colors = COLORS
Overlay.thickness = 2
Overlay.lastX = -1
Overlay.lastY = -1
Overlay.mouseDown = false
Overlay.tool = TOOL_MARKER
Overlay.isInteractive = false
Overlay.isRunning = false
Overlay.menuRow = null

// === OVERLAY: SETUP / CLEAN

Overlay.setup = function(displayNr)
	// Setup display
	freshSetup = true
	if display(displayNr).mode == displayMode.pixel then
		freshSetup = false
	end if
	display(displayNr).mode = displayMode.pixel
	self.dsp = display(displayNr)
	// Clear
	if CLEAR_AT_STARTUP or freshSetup then 
		self.clear
	end if
	// Init
	self.lastX = -1
	self.lastY = -1
	self.mouseDown = false
	self.keyHandler = new DiscreteEventHandler
	// Show menu
	self.showMenu
end function

Overlay.clear = function
	self.dsp.clear color.clear
end function

Overlay.getCurrentImage = function
	image = self.dsp.getImage(0,0,960,640)
	return image
end function

// === OVERLAY: DRAWING OPERATIONS

Overlay.drawLine = function(x0,y0,x1,y1,c,t)
	if self.tool == TOOL_BRUSH then
		self.dsp.line x0,y0,x1,y1,c,t
	else
		r = t / 2
		for p in linePoints([x0,y0],[x1,y1])
			self.dsp.fillEllipse p[0]-r,p[1]-r,t,t,c
		end for	
	end if
end function

Overlay.clearRect = function(x,y,w,h)
	self.dsp.fillRect x,y,w,h,color.clear
end function

Overlay.drawImage = function(img,x,y)
	self.dsp.drawImage img,x,y
end function

// === OVERLAY: COLORS

Overlay.color = function
	if self.tool == TOOL_ERASER then
		return color.clear
	else
		return self.colors[self.colorIdx]
	end if
end function

Overlay.shiftColor = function(offset=1)
	self.colorIdx = (self.colorIdx + self.colors.len + offset) % self.colors.len
end function

// === OVERLAY: MENU

Overlay.showMenu = function
	// Backup row
	self.menuRow = backupRow(0)
	// Show menu
	self.updateMenu
end function

Overlay.hideMenu = function
	restoreRow self.menuRow,0
end function

Overlay.updateMenu = function
	cs = new ColorString
	
	for mapping in COLORED_STRING_MAPPING
		colorKey = mapping.key
		fgColor = mapping.value[0]
		bgColor = mapping.value[1]
		cs.mapChar colorKey,fgColor,bgColor
	end for
	
	colorIdx = self.colorIdx
	
	fs = ""
	
	// Marker
	if self.tool == TOOL_MARKER then
		fs = fs + "$(WW:M)$(SS:arker) "
	else
		fs = fs + "$(W:M)arker "
	end if
	// Brush
	if self.tool == TOOL_BRUSH then
		fs = fs + "$(WW:B)$(SS:rush) "
	else
		fs = fs + "$(W:B)rush "
	end if
	// Erase
	if self.tool == TOOL_ERASER then
		fs = fs + "$(WW:E)$(SS:rasr) "
	else
		fs = fs + "$(W:E)rasr "
	end if
	// Pen Size
	fs = fs + "$(G:[)"
	for ps in range(1,9)
		if ps == self.thickness then
			fs = fs + "$(WW:" + ps + ")"
		else
			fs = fs + ps
		end if
	end for
	fs = fs + "$(G:])"
	fs = fs + " "
	// Colors
	for penColor in COLORS
		entry = COLOR_MENU_ITEMS[penColor]
		normal = entry[0]
		selected = entry[1]
		if self.color == penColor then
			fs = fs + selected + " "
		else
			fs = fs + normal + " "
		end if
	end for
	// Undo + Clear
	fs = fs + "$(W:Z):Undo $(W:BkSp):Clr"
	
	cs.renderString(0, fs)
	
end function

// === OVERLAY: DRAWING

Overlay.draw = function
	self.isInteractive = true
	self.isRunning = true
	ensureNoKeysPressed
	while self.isRunning
		self.update
		yield
	end while
	self.exitProgram
end function

Overlay.update = function
	self.processMouseEvents
	self.processKeyEvents	
end function

Overlay.processMouseEvents = function
	if mouse.button then
		if not self.mouseDown then
			self.mouseDown = true
			UndoManager.drawingStarted
		end if
		x = mouse.x
		y = mouse.y
		if self.lastX > 0 then
			lx = self.lastX
			ly = self.lastY
			c = self.color
			t = self.thickness
			self.drawLine x,y,lx,ly,c,t
			UndoManager.lineDrawn x,y,lx,ly,t
		end if
		self.lastX = x
		self.lastY = y
	else
		// Done drawing lines
		// Reset the "last" point coordinate
		self.lastX = -1
		self.lastY = -1
		if self.mouseDown then
			self.mouseDown = false
			UndoManager.drawingDone
		end if
	end if
end function

Overlay.processKeyEvents = function
	self.keyHandler.update
	
	if self.keyHandler.isKeyDown(K_BACKSPACE) then
		self.clear
		UndoManager.reset
	else if self.keyHandler.isKeyDown("c") then
		self.shiftColor
		self.updateMenu
	else if self.keyHandler.isKeyDown("e") then
		self.tool = TOOL_ERASER
		self.updateMenu
	else if self.keyHandler.isKeyDown("m") then
		self.tool = TOOL_MARKER
		self.updateMenu
	else if self.keyHandler.isKeyDown("b") then
		self.tool = TOOL_BRUSH
		self.updateMenu
	else if self.keyHandler.isKeyDown("z") then
		UndoManager.performUndo
	end if
	
	// Process color change (from map)
	for entry in KEY_COLOR_MAP
		if self.keyHandler.isKeyDown(entry.key) then
			self.colorIdx = entry.value
			self.updateMenu
		end if
	end for
	
	// Process thickness change
	for thickness in range(1,9)
		keyName = str(thickness)
		if self.keyHandler.isKeyDown(keyName) then
			self.thickness = thickness
			self.updateMenu
		end if
	end for
	
	// Only exit if in interactive mode
	if self.isInteractive then
		if self.keyHandler.isKeyDown(K_ESC) or self.keyHandler.isKeyDown("q") then
			self.isRunning = false
		end if
	end if
	
end function

// === OVERLAY: EXITING

Overlay.exitProgram = function
	if CLEAR_AT_EXIT then self.clear
	ensureTextDoesNotScroll
	ensureNoKeysPressed
	self.hideMenu
end function

ensureTextDoesNotScroll = function
	text.row = max(text.row, 1)
	for c in range(0,67)
		text.setCell c,text.row," "
	end for
end function

ensureNoKeysPressed = function
	// Consume keys in buffer
	while key.available
		key.get
	end while
	// Wait for key-presses to be released (key-ups)
	// Set flag initially to "true" to simulate a do-while loop
	anyKeyPressed = true
	while anyKeyPressed
		anyKeyPressed = false
		for keyName in key.keyNames
			if key.pressed(keyName) then
				anyKeyPressed = true
				break
			end if
		end for
		yield
	end while
end function

// == DISCRETE EVENT HANDLER

DiscreteEventHandler = {}
DiscreteEventHandler.downKeys = []
DiscreteEventHandler.upKeys = []
DiscreteEventHandler.heldDownKeys = []

// Call on each cycle of your processing loop
DiscreteEventHandler.update = function
	
	// Reset on each update
	self.downKeys = []
	self.upKeys = []
	
	for keyName in key.keyNames
		isDown = key.pressed(keyName)
		heldDownIdx = self.heldDownKeys.indexOf(keyName)
		
		// Process "downs"
		if isDown and heldDownIdx == null then
			self.downKeys.push keyName
			self.heldDownKeys.push keyName			
		end if
		
		// Process "ups"
		if not isDown and heldDownIdx != null then
			self.upKeys.push keyName
			self.heldDownKeys.remove heldDownIdx
		end if	
	end for
	
end function

// Returns "true" if the key was "down" during the current cycle
DiscreteEventHandler.isKeyDown = function(keyName)
	return self.downKeys.indexOf(keyName) != null
end function

// Returns "true" if the key is currently being "held down".
// This will probably be true across many cycles.
DiscreteEventHandler.isKeyHeldDown = function(keyName)
	if keyName == "shift" then
		return self.isKeyHeldDown("left shift") or self.isKeyHeldDown("right shift")
	else if keyName == "cmd" then
		return self.isKeyHeldDown("left cmd") or self.isKeyHeldDown("right cmd")
	else if keyName == "alt" then
		return self.isKeyHeldDown("left alt") or self.isKeyHeldDown("right alt")
	else	
		return self.heldDownKeys.indexOf(keyName) != null
	end if
end function

// === UNDO-MANAGER

UndoManager = {}
UndoManager.minX = null
UndoManager.minY = null
UndoManager.maxX = null
UndoManager.maxY = null
UndoManager.imgBeforeDrawing = null
UndoManager.undoImages = []

UndoManager.reset = function
	self.undoImages = []
end function

UndoManager.drawingStarted = function
	self.minX = 960
	self.minY = 640
	self.maxX = 0
	self.maxY = 0
	self.imgBeforeDrawing = Overlay.getCurrentImage
end function

UndoManager.lineDrawn = function(x0,y0,x1,y1,thickness)
	minX = min(x0,x1) - thickness
	minY = min(y0,y1) - thickness
	maxX = max(x0,x1) + thickness
	maxY = max(y0,y1) + thickness
	self.maxX = max(self.maxX,maxX)
	self.maxY = max(self.maxY,maxY)
	self.minX = min(self.minX,minX)
	self.minY = min(self.minY,minY)
end function

UndoManager.drawingDone = function
	// Extract affected portion
	x = self.minX
	y = self.minY
	w = self.maxX - self.minX
	h = self.maxY - self.minY
	img = self.imgBeforeDrawing.getImage(x,y,w,h)
	// Construct new undoImg
	undoImg = newUndoImage(img,x,y)
	// Push image
	self.undoImages.push undoImg
end function

UndoManager.performUndo = function
	if self.undoImages.len > 0 then
		undoImg = self.undoImages.pop
		undoImg.draw
	else
		// print "No undo levels"
	end if
end function

// === UNDO-IMAGE

newUndoImage = function(img,x,y)
	i = new UndoImage
	i.init img,x,y
	return i
end function

UndoImage = {}
UndoImage.pos = null
UndoImage.img = null

UndoImage.init = function(img,x,y)
	self.img = img
	self.x = x
	self.y = y
end function

UndoImage.draw = function
	img = self.img
	x = self.x
	y = self.y
	w = img.width
	h = img.height
	Overlay.clearRect x,y,w,h
	Overlay.drawImage img,x,y
end function

// === POSITION

newPos = function(x,y)
	p = new Position
	p.x = x
	p.y = y
	return p
end function

Position = {}
Position.x = 0
Position.y = 0

Position.plusDelta = function(d)
	np = newPos(self.x + d, self.y + d)
	return np
end function

Position.lessThan = function(other)
	ox = other.x
	oy = other.y
	x = self.x
	y = self.y
	return x < ox or y < oy
end function

Position.greaterThan = function(other)
	ox = other.x
	oy = other.y
	x = self.x
	y = self.y
	return x > ox or y > oy	
end function

// === MATH FUNCTIONS

min = function(a,b)
	if a < b then
		return a
	else 
		return b
	end if
end function

max = function(a,b)
	if a > b then
		return a
	else 
		return b
	end if
end function

signFactor = function(n)
	if n >= 0 then
		return 1
	else
		return -1
	end if
end function

linePoints = function(p0,p1)
	points = []
	// Get values
	if p0 isa map then
		x0 = p0.x
		y0 = p0.y
	else
		x0 = p0[0]
		y0 = p0[1]
	end if
	if p1 isa map then
		x1 = p1.x
		y1 = p1.y
	else
		x1 = p1[0]
		y1 = p1[1]
	end if
	// Calculate deltas and distances
	dx = x1 - x0
	dy = y1 - y0
	lenX = abs(dx)
	lenY = abs(dy)
	// Choose strategy depending on longer length
	if lenX >= lenY then
		step = signFactor(dx)
		for x in range(x0,x1,step)
			f = (x - x0) / dx
			y = y0 + (dy * f)
			points.push [x,y]
		end for
	else
		step = signFactor(dy)
		for y in range(y0,y1,step)
			f = (y - y0) / dy
			x = x0 + (dx * f)
			points.push [x,y]
		end for
	end if
	// Return points
	return points
end function

// === COLOR-STRING

ColorString = {}
ColorString.chars = []
ColorString.defaultFgColor = color.silver
ColorString.defaultBgColor = color.clear
ColorString.colorMap = {}
ColorString.format = "$(:)"

ColorString.fgColor = function(colorKey)
	entry = self.colorMap[colorKey]
	return entry.fgColor
end function

ColorString.bgColor = function(colorKey)
	entry = self.colorMap[colorKey]
	return entry.bgColor
end function

ColorString.mapChar = function(ch,fgColor,bgColor=null)
	entry = {"fgColor": fgColor, "bgColor": bgColor}
	self.colorMap[ch] = entry
end function

ColorString.renderString = function(rowNr, formatString)
	textRuns = self.parse(formatString)
	for txtRun in textRuns
		fgColor = txtRun.fgColor
		bgColor = txtRun.bgColor
		colNr = txtRun.colNr
		for ch in txtRun.text
			text.setCell colNr,rowNr,ch
			text.setCellColor colNr,rowNr,fgColor
			text.setCellBackColor colNr,rowNr,bgColor
			colNr = colNr + 1
		end for
	end for
end function

ColorString.parse = function(formatString)
	special = self.format[0]
	open = self.format[1]
	switch = self.format[2]
	close = self.format[3]
	
	colNr = 0
	
	p = new Parser
	p.input = formatString
	
	colorStringSelf = self
	newTextRun = @outer.newTextRun
	
	parseFormattedOrText = function
		if p.ch == special then
			node = parseFormatted
		else
			node = parseText
		end if
		return node
	end function
	
	parseFormatted = function
		initialColNr = colNr
		
		p.consume(special)
		p.consume(open)
		colorKey = p.parseUntil(switch)
		p.consume(switch)
		txt = p.parseUntil(close)
		p.consume(close)
		
		fgColor = colorStringSelf.fgColor(colorKey)
		bgColor = colorStringSelf.bgColor(colorKey)
		
		outer.colNr = outer.colNr + txt.len
		
		return newTextRun(initialColNr,fgColor,bgColor,txt)
	end function
	
	parseText = function
		initialColNr = colNr
		
		txt = p.parseUntil(special)
		
		fgColor = colorStringSelf.defaultFgColor
		bgColor = colorStringSelf.defaultBgColor
		
		outer.colNr = outer.colNr + txt.len
		
		return newTextRun(initialColNr,fgColor,bgColor,txt)
	end function
	
	result = p.parse(@parseFormattedOrText)
	
	return result
	
end function

// === TEXT-RUNS

newTextRun = function(colNr,fgColor,bgColor,txt)
	tr = new TextRun
	tr.colNr = colNr
	tr.fgColor = fgColor
	tr.bgColor = bgColor
	tr.text = txt
	return tr
end function

TextRun = {}
TextRun.colNr = 0
TextRun.fgColor = null
TextRun.bgColor = null
TextRun.text = null

// === PARSER

Parser = {}
Parser.input = ""
Parser.idx = 0

Parser.ch = function
	return self.input[self.idx]
end function

Parser.isDone = function
	return self.idx >= self.input.len
end function

Parser.parse = function(rootParser)
	nodes = []
	while not self.isDone
		node = rootParser
		nodes.push node
	end while
	return nodes
end function

Parser.advance = function
	self.advanceBy 1
end function

Parser.advanceBy = function(amount)
	self.idx = self.idx + amount
end function

Parser.consume = function(token)
	if self.peekEquals(token) then
		self.advanceBy(token.len)
	else
		msg = "Token """ + token + """ not found "
		msg = msg + "at idx " + self.idx + ". "
		msg = msg + "Found: """ + self.peekN(10) + """"
		print msg
		exit
	end if
end function

Parser.peekEquals = function(token)
	return self.peekN(token.len) == token
end function

Parser.peekN = function(n)
	startIdx = self.idx
	endIdx = self.idx + n
	return self.input[startIdx:endIdx]
end function

Parser.parseUntil = function(token)
	result = ""
	while not self.isDone
		if self.peekEquals(token) then
			break
		end if
		result = result + self.ch
		self.advance
	end while
	return result
end function

// === TEXT BACKUP / RESTORE

Cell = {}
Cell.char = null
Cell.color = null
Cell.bgColor = null

backupRow = function(rowNr)
	rowCells = []
	for colNr in range(0,67)
		cell = getCell(colNr,rowNr)
		rowCells.push cell
	end for
	return rowCells	
end function

getCell = function(colNr, rowNr)
	c = new Cell
	c.char = text.cell(colNr,rowNr)
	c.color = text.cellColor(colNr,rowNr)
	c.bgColor = text.cellBackColor(colNr,rowNr)
	return c
end function

setCell = function(cell, colNr, rowNr)
	text.setCell colNr,rowNr,cell.char
	text.setCellColor colNr,rowNr,cell.color
	text.setCellBackColor colNr,rowNr,cell.bgColor
end function

restoreRow = function(rowCells,rowNr)
	colNr = 0
	for cell in rowCells
		setCell cell,colNr,rowNr
		colNr = colNr + 1
	end for
end function

// === MAIN INVOCATION

if globals == locals then
	draw
end if
