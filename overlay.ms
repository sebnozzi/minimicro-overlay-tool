
// === CONFIGURATION

CLEAR_AT_EXIT=true
CLEAR_AT_STARTUP=true
DISPLAY_NR=1

COLORS = [color.orange, color.lime, color.fuchsia, color.aqua]
// Map key to color index
KEY_COLOR_MAP = {
"o": 0,
"g": 1,
"l": 1,
"f": 2,
"a": 3,
"b": 3}

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

MODE_PENCIL = "drawing"
MODE_ERASER = "erasing"

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
Overlay.mode = MODE_PENCIL
Overlay.isInteractive = false
Overlay.isRunning = false

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
		self.dsp.clear
	end if
	// Init
	self.lastX = -1
	self.lastY = -1
	self.mouseDown = false
	self.keyHandler = new DiscreteEventHandler
end function

Overlay.clear = function
	self.dsp.fillRect 0,0,960,640,color.clear
end function

// === OVERLAY: COLORS

Overlay.color = function
	if self.mode == MODE_PENCIL then
		return self.colors[self.colorIdx]
	else
		return color.clear
	end if
end function

Overlay.shiftColor = function(offset=1)
	self.colorIdx = (self.colorIdx + self.colors.len + offset) % self.colors.len
end function

// === OVERLAY: MODES

toggleMode = function
	if self.mode == MODE_PENCIL then 
		self.mode = MODE_ERASER
	else
		self.mode = MODE_PENCIL
	end if
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
	else if self.keyHandler.isKeyDown("e") then
		self.mode = MODE_ERASER
	else if self.keyHandler.isKeyDown("d") then
		self.mode = MODE_PENCIL
	else if self.keyHandler.isKeyDown("z") then
		UndoManager.performUndo
	else 
		// print key.pressed
	end if
	
	// Process color change (from map)
	for entry in KEY_COLOR_MAP
		if self.keyHandler.isKeyDown(entry.key) then
			self.colorIdx = entry.value
		end if
	end for
	
	// Process thickness change
	for thickness in range(1,9)
		keyName = str(thickness)
		if self.keyHandler.isKeyDown(keyName) then
			self.thickness = thickness
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

// === UndoImage

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

// === MAIN INVOCATION

if globals == locals then
	draw
end if
