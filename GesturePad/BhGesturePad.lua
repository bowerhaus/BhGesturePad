--[[
BhGesturePad.lua
A touch gesture recognition pad by Andy Bower, Bowerhaus LLP

This software is an extension of the Lua implementation of Protractor unistroke gesture 
recognition by Arturs Sosins (http://appcodingeasy.com). The original Gesture.lua has been
included untouched but the stroke capture and drawing component is not used. This version
extends the algorithm to include multistroke gestures with my version of n-Protractor:

http://depts.washington.edu/aimgroup/proj/dollar/ndollar-protractor.pdf

The BhGesturePad runs in two modes; user mode and training mode. 

(a) In user mode it waits for gestures to be drawn on the pad and then triggers a "recognized" 
indicating what symbol was recognized. 

(b) In training mode, the pad will prompt for a symbol and the gesture that is drawn on the pad
will be learnt for that symbol. Several gestures can be learnt for each symbol. Symbols definitions 
must have been added to the pad using addSymbol() prior to training. In this mode the pad presents a 
training UI that allows you to move between symbols. The Save/SaveAll buttons saves the gestures for the 
current symbol (or all symbols) by printing a JSON representation to stdout. This can then by copied and
pasted into a file or into Lua code.

MIT License
(C) 2010 - 2011 Gideros Mobile 
Copyright (C) 2012. Andy Bower, Bowerhaus LLP (http://bowerhaus.eu)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software
and associated documentation files (the "Software"), to deal in the Software without restriction,
including without limitation the rights to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or
substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

This code is MIT licensed, see http://www.opensource.org/licenses/mit-license.php
]]
require "BhWritingSurface"
require "BhButton"
require "DataDumper"

BhGesturePad=Core.class(Sprite)

local DEBUG=false -- Set to true for debug printing

--
-- Permuation iterator so we can implement a version of n_Protractor to add multiple glyphs in any order
-- From Programming in Lua 2nd Edition p80
--
local function permgen (a, n)
	n = n or #a	
	if n == 0 then
        coroutine.yield(a)
    else
        for i=1, n do
			-- put i-th element as the last one
			a[n], a[i] = a[i], a[n]
    
			-- generate all permutations of the other elements
			permgen(a, n - 1)
    
			-- restore i-th element
			a[n], a[i] = a[i], a[n]   
        end
	end
end

local function permutations (a)
	local n = table.getn(a)
	local co = coroutine.create(function () permgen(a, n) end)
		return function ()   -- iterator
	local code, res = coroutine.resume(co)
    return res
	end
end

local function debug(text)
	if DEBUG then
		print(text)
	end
end
	
function BhGesturePad:init(optSkinName, optPack, optFont)
	-- The following are exterallysettable configuration options thatt can be set
	-- following instance creation.
	
	-- START OPTIONS	
	-- Indicate whether rotation is allowed in the lookup
	self.allowRotation=false
	
	-- Put a limit on the number of glyphs that can be added in permutation mode
	self.permutationGlyphLimit = 4 -- 24 combinations
	
	-- Put a limit on the number of glyphs where we should use inverse shape mode.
	-- It is unlikely that beyound a certain number of strokes that the user
	-- would draw the reverse shpaes anyway
	self.inverseShapeGlyphLimit = 3 
	
	-- This is the number of points that the recognizer will store internally for each glyph set it is given
	self.numRecognizerPoints=33
	
	-- This is the number of points we store (and serialize) for each glyph we are given
	self.maxGlyphPoints=15
	
	-- We alway store glyph points as integers to reduce the size of our serialization format. This is
	-- the scale factor used for the coordinates before rounding.
	self.glyphScaleFactor=1	
	
	-- Default prompt message for training mode
	self.trainMessage="Train %s"
	-- END OPTIONS

	if optPack==nil then
		optPack=TexturePack.bhLoad("Images/BhGesturePad")
	end
	self.assetPack=optPack
	if optSkinName==nil then
		optSkinName="Crumpled"
	end
	self.skin=optSkinName
	self.background=Bitmap.new(self.assetPack:getTextureRegion(self.skin..".png"))
	self.background:setAnchorPoint(0.5, 0.5)
	self:addChild(self.background)
	
	local font = optFont or TTFont.new(pathto("Fonts/Tahoma.ttf"), 20)
	self.message=TextField.new(font, "")
	self:addChild(self.message)

	self.recognizer=Gestures.new({
		draw=false,
		autoTrack=false,
		scope = self,
		debug=DEBUG,
		allowRotation = self.allowRotation,
		inverseShape = true,
		points = self.numRecognizerPoints})

	local w, h=self:getWidth(), self:getHeight()
	self.paper=BhWritingSurface.new(w, h, 3, 0x606060)
	self:addChild(self.paper)
	self.paper:setPosition(-w/2, -h/2)
	self.symbols={}
	self.trainingIndex=0
	
	self:createButtons()
	self.paper:addEventListener("startWriting", self.onStartWriting, self)
	self.paper:addEventListener("newGlyph", self.onNewGlyph, self)
	self.paper:addEventListener("endWriting", self.onEndWriting, self)
	
	self:beTrainMode(false)
end

function BhGesturePad:getCurrentTrainingSymbol()
	return self.symbols[self.trainingIndex].name
end

function BhGesturePad:showTrainMessage()
	if self.trainingIndex then
		self:setMessage(string.format(self.trainMessage, self:getCurrentTrainingSymbol()))
	end
end

function BhGesturePad:beEditMode(tf)
	-- Puts the pad into edit mode rather than user mode. This shows the Train button.
	self.isEditMode=tf
end

function BhGesturePad:beTrainMode(tf)
	-- Puts the pad into train mode rather than user mode. 
	self.isTraining=tf
	if tf then 
		self:showTrainMessage() 
	else
		self:setMessage("")
	end	
end

function BhGesturePad:addGlyphSet(name, glyphSet)
	-- Adds a glyph set to our recognizer and to our local symbols
	self:trainGlyphSet(name, glyphSet)
			
	-- Add the set to our raw gestures
	local nameSets=self:getGlyphSetsFor(name)
	nameSets.sets[#nameSets.sets+1]=glyphSet
end

function BhGesturePad:addSymbol(name, optGlyphSets)
	-- Adds a new symbol for (name). Optionally the glyphSets can be provided in (optGlyphSets)
	local nameSets=self:getGlyphSetsFor(name)

	if nameSets==nil then
		nameSets={name=name, sets={}}
		self.symbols[#self.symbols+1]=nameSets
	end
	if optGlyphSets then
		for i,gs in ipairs(optGlyphSets) do
			debug(string.format("training %d sets of glyphs for %s", #gs, name))
			self:addGlyphSet(name, gs)
		end
	end
	
	self.trainingIndex=math.max(1, self.trainingIndex)
end

function BhGesturePad:addSymbols(symbols)
	for k,symbol in pairs(symbols) do
		self:addSymbol(symbol.name, symbol.sets)
	end
end

function BhGesturePad:cmdTrain()
	self:beTrainMode(not(self.isTraining))
end

function BhGesturePad:cmdTrainQuery(queryEvent)
	queryEvent.isEnabled=self.isEditMode
	queryEvent.isLatched=self.isTraining
end

function BhGesturePad:cmdNext()
	self.trainingIndex=self.trainingIndex+1
	if self.trainingIndex>#self.symbols then
		self.trainingIndex=1
	end
	self:showTrainMessage()
end

function BhGesturePad:cmdNextQuery(queryEvent)
	queryEvent.isEnabled=self.isTraining  and #self.symbols>0
end

function BhGesturePad:cmdPrevious()
	self.trainingIndex=self.trainingIndex-1
	if self.trainingIndex<=0 then
		self.trainingIndex=#self.symbols
	end
	self:showTrainMessage()
end

function BhGesturePad:cmdPreviousQuery(queryEvent)
	queryEvent.isEnabled=self.isTraining and #self.symbols>0
end

function BhGesturePad:cmdSaveAll()
	local copyGestures=table.copy(self.symbols)
	for k,gs in pairs(copyGestures) do
		-- Drop null sets
		if #gs.sets==0 then copyGestures[k]=nil end
	end
--	local s=Json.Encode(copyGestures)
	local s=DataDumper(copyGestures)
	print(s)
end

function BhGesturePad:cmdSaveAllQuery(queryEvent)
	queryEvent.isEnabled=self.isTraining and #self.symbols>0
end

function BhGesturePad:cmdSave()
	local symbol=self:getCurrentTrainingSymbol()
--	local s=Json.Encode(self:getGestureSetsFor())
	local s=DataDumper(self:getGlyphSetsFor(symbol))
	print(s)
end

function BhGesturePad:cmdSaveQuery(queryEvent)
	queryEvent.isEnabled=self.isTraining and #self.symbols>0
end

--[[
function BhGesturePad:loadSymbolsFromJson(filename)
	local filename = filename..".json"
	local contents
	local newSymbols
	local file = io.open(filename, "r")
	if file then
		contents = file:read("*a")
		io.close( file )
		newSymbols=Json.Decode(contents)
	end
	self:addSymbols(newSymbols)
end
--]]

function BhGesturePad:cmdHelp()
	-- Not yet implemented
end

function BhGesturePad:cmdHelpQuery(queryEvent)
	queryEvent.isEnabled=false
end

function BhGesturePad:createButton(name, downName, optBottomLeftX, optBottomLeftY)
	if optBottomLeftX then self.buttonX=optBottomLeftX end
	if optBottomLeftY then self.buttonY=optBottomLeftY end
	local button=BhButton.new(name, downName, self.assetPack)
	
	self[name.."Cmd"]=button
	button.disabledAlpha=0
	self:addChild(button)
	button:registerCommand(self, "cmd"..name)
	button:setPosition(self.buttonX+button:getWidth()/2, self.buttonY-button:getHeight()/2)
	self.buttonX=self.buttonX+49
	return button
end

function BhGesturePad:createButtons()
	local bottomLeftX=-self:getWidth()/2+10
	local bottomLeftY=self:getHeight()/2-10

	self.buttonMode=self:createButton("Train", "Exit", bottomLeftX, bottomLeftY)
	self:createButton("Previous")
	self:createButton("Next")
	self:createButton("Save")
	self:createButton("SaveAll")
	
	local topRightX, topRightY=self:getWidth()/2-40, -self:getHeight()/2+60
	self:createButton("Help", nil, topRightX, topRightY)
	
	--[[
	local topLeftX, topLeftY=10-self:getWidth()/2, -self:getHeight()/2+60
	self.buttonNew=self:createButton("New", nil, topLeftX, topLeftY)
	self.buttonDelete=self:createButton("Delete")
	-]]
end

function BhGesturePad:onRecognized(gestureName, score)
	self.paper:erase() 
	local event=Event.new("recognized")
	event.symbol=gestureName
	self:dispatchEvent(event)
end

function BhGesturePad:onStartWriting(event)
	self.paper:erase()
	self:setMessage("")
end

function BhGesturePad:onNewGlyph(event)
	debug(string.format("New glyph with %d points", #event.glyph))
end

function BhGesturePad:compactGlyphSet(glyphSet)
	-- Compact each glyph in the supplied set so that there are no more than 
	-- maxGlyphs in the set. At the same time we scale and round the coordinates so that
	-- our serialization to Json will be smaller.
	local result={}
	for i,eachGlyph in ipairs(glyphSet) do
		if #eachGlyph>self.maxGlyphPoints then
			eachGlyph=resample(eachGlyph, #eachGlyph, {points=self.maxGlyphPoints})
		else	
			eachGlyph=table.copy(eachGlyph)
		end
		table.insert(result, eachGlyph)
		debug(string.format("compacting glyph to %d pts", #eachGlyph))
		for j,eachPt in ipairs(eachGlyph) do	
			eachPt.x=math.round(eachPt.x*self.glyphScaleFactor)
			eachPt.y=math.round(eachPt.y*self.glyphScaleFactor)
		end
	end
	return result
end

function BhGesturePad:getPointsFromGlyphSet(glyphSet)
	local points={}
	for i,eachGlyph in ipairs(glyphSet) do
		for j,eachPt in ipairs(eachGlyph) do
			table.insert(points, eachPt)
		end
	end
	return points
end

function BhGesturePad:getGlyphSetsFor(name)
	for i,gs in ipairs(self.symbols) do
		if gs.name==name then
			return gs
		end
	end
	return nil
end

function BhGesturePad:trainGlyphSet(name, glyphSet)
	-- Adds a glyphset to the recognizer. Optionally permutates all 
	-- arrangmenents, which is effectively the heart of the N-Protractor enhancement
	
	-- Set the recogniser options
	local conf=self.recognizer.conf
	conf.inverseShape=#glyphSet<=self.inverseShapeGlyphLimit
	conf.allowRotation=self.allowRotation
	conf.points=self.numRecognizerPoints

	debug(string.format("Training symbol from glyph set with %d glyphs", #glyphSet))

	if #glyphSet<=self.permutationGlyphLimit then
		-- N-Protractor - train all glyphset permutations
		for each in permutations(glyphSet) do
			local points=self:getPointsFromGlyphSet(each)
			self.recognizer:addGesture(name, points, 
				function(name, score) 
					self:onRecognized(name, score) 
				end)
		end
	else
		-- If there are too many permutations just train the single one
		local points=self:getPointsFromGlyphSet(glyphSet)
		self.recognizer:addGesture(name, points, 
			function(name, score) 
				self:onRecognized(name, score) 
			end)
	end
	
	local points=self:getPointsFromGlyphSet(glyphSet)
	self.recognizer:addGesture(name, points, 
		function(name, score) 
			self:onRecognized(name, score) 
		end)
end

function BhGesturePad:onEndWriting(event)
	debug(string.format("New glyph set with %d glyphs", #event.glyphSet))
	
	if self.isTraining then
		local compactSet=self:compactGlyphSet(event.glyphSet)
--		compactSet=event.glyphSet
		self:addGlyphSet(self:getCurrentTrainingSymbol(), compactSet)
		self:showTrainMessage()
	else
		-- Set the recogniser options
		local conf=self.recognizer.conf
		conf.allowRotation=self.allowRotation
		conf.points=self.numRecognizerPoints
		self.recognizer:resolve(self:getPointsFromGlyphSet(event.glyphSet))
	end
end

function BhGesturePad:setMessage(text)
	self.paper:erase()
	self.message:setText(text)
	local mw, mh=self.message:getWidth(), self.message:getHeight()
	self.message:setPosition((-mw)/2, (-mh)/2+15)
end