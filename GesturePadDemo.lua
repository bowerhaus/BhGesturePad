
--[[
BhGesturePadDemo.lua
A demo of the touch gesture recognition pad by Andy Bower, Bowerhaus LLP

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

require "BhGesturePad"

GesturePadDemo=Core.class(Sprite)

function GesturePadDemo:onRecognized(event)
	self.pad:setMessage(event.symbol)
end

function GesturePadDemo:addNewGesture(name)
	self.pad:addGesture(name)
end

function GesturePadDemo:addAlnum()
	local letters= "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz1234567890"
	for each in string.gmatch(letters, "[%a]") do
		self.pad:addSymbol(each)
	end
end

function GesturePadDemo:addShapes()
	local letters= "house cat boat teddy flower leaf tear oval foot boy girl hand car train trousers skirt shirt tree fish butterfly"
	for each in string.gmatch(letters, "[^%s]+") do
		self.pad:addSymbol(each)
	end
end

function GesturePadDemo:addFun()
	local letters= "rectangle circle triangle pentagon hexagon octagon star diamond"
	for each in string.gmatch(letters, "[^%s]+") do
		self.pad:addSymbol(each)
	end
end

function GesturePadDemo:init()
	self:addChild(Bitmap.new(Texture.new(pathto("Images/BhDesk.png"), true)))
	
	local pad=BhGesturePad.new()
	pad:setPosition(stage:bhGetCenter())
	pad:setRotation(-5)
	pad:setScale(2)
	pad:addEventListener("recognized", self.onRecognized, self)	
	self:addChild(pad)
	self.pad=pad
	
	-- These symbols will be added as empty into the recognizer. They can then be trained
	-- by clicking the "Train" button
	self:addShapes()
	self:addAlnum()
	
	-- Example of loading predefined symbol gestures into the pad
--pad:addSymbols(loadfile("Letters.lua")())
	pad:beEditMode(true)
	
	stage:addChild(self)
end