--[[
BhWritingSurface.lua
A ink writing surafce by Andy Bower, Bowerhaus LLP

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
BhWritingSurface=Core.class(Shape)

function BhWritingSurface:init(width, height, penwidth, pencolor)	
	self.pencolor=pencolor or 0
	self.penwidth=penwidth or 1
	self.width=width
	self.height=height
	self.finishedTimer=Timer.new(0, 0)
	self:erase()
	self:addEventListener(Event.ADDED_TO_STAGE, self.onAddedToStage, self)
	self:addEventListener(Event.REMOVED_FROM_STAGE, self.onRemovedFromStage, self)
	self.writingTimeout=1
end

function BhWritingSurface:erase()	
	self:clear()
	local x, y=self:getPosition()
	self:beginPath()
	self:setLineStyle(0, 0)
	self:moveTo(0, 0)
	self:lineTo(self.width, 0)
	self:lineTo(self.width, self.height)
	self:lineTo(0, self.height)
	self:lineTo(0, 0)
	self:endPath()
	self:setLineStyle(self.penwidth, self.pencolor)
	self.glyphSet={}
	self.allGlyphs={}
	self.finishedTimer:stop()
end

function BhWritingSurface:drawGlyph(glyph)
	self:beginPath()
	self:moveTo(self:lastGlyphPointPosition())
	for i,p in ipairs(glyph) do
		if self.inkFunc then 
			self:inkfunc(p.velocity)
		end
		self:lineTo(p.x, p.y)
	end
	self:endPath()
end

function BhWritingSurface:clearGlyph()	
	self.glyph={}
end

function BhWritingSurface:lastGlyphPointPosition()	
	local pt=self.glyph[#self.glyph]
	return pt.x, pt.y
end

function BhWritingSurface:onAddedToStage()
	self:addEventListener(Event.MOUSE_DOWN, self.onMouseDown, self)
	self:addEventListener(Event.MOUSE_MOVE, self.onMouseMove, self)
    self:addEventListener(Event.MOUSE_UP, self.onMouseUp, self)
	self:addEventListener(Event.TOUCHES_BEGIN, self.onIgnoreTouches, self)
	self:addEventListener(Event.TOUCHES_MOVE, self.onIgnoreTouches, self)
	self:addEventListener(Event.TOUCHES_END, self.onIgnoreTouches, self)
	self:addEventListener(Event.TOUCHES_CANCEL, self.onIgnoreTouches, self)
end
 
function BhWritingSurface:onRemovedFromStage()
	self:removeEventListener(Event.MOUSE_DOWN, self.onMouseDown, self)
	self:removeEventListener(Event.MOUSE_MOVE, self.onMouseMove, self)
    self:removeEventListener(Event.MOUSE_UP, self.onMouseUp, self)
	self:removeEventListener(Event.TOUCHES_BEGIN, self.onIgnoreTouches, self)
	self:removeEventListener(Event.TOUCHES_MOVE, self.onIgnoreTouches, self)
	self:removeEventListener(Event.TOUCHES_END, self.onIgnoreTouches, self)
	self:removeEventListener(Event.TOUCHES_CANCEL, self.onIgnoreTouches, self)	
	self.finishedTimer:stop()
end 

function BhWritingSurface:onMouseDown(event)
	if self:isVisibleDeeply() and self:hitTestPoint(event.x, event.y) then
		self.finishedTimer:stop()
		self.focus=self
		self:clearGlyph()
		local lx, ly=self:globalToLocal(event.x, event.y)		
		
		self.glyphStartTime=os.timer()
		self.lastGlyphTime=self.glyphStartTime
		self.recentVelocities={0}
		local point = { x=lx, y=ly, velocity=0}
	
		-- Draw a dot
		self:beginPath()
		self:moveTo(lx, ly)
		self:lineTo(lx, ly)
		self:endPath()
		table.insert(self.glyph, point)	
		
		if #self.glyphSet==0 then
			local newEvent=Event.new("startWriting")
			self:dispatchEvent(newEvent)
		end
		
		local newEvent=Event.new("startGlyph")
		newEvent.x=event.x
		newEvent.y=event.y
		self:dispatchEvent(newEvent)
		
		event:stopPropagation()
	end
end 

local function movingMedian(values, count, newValue)
	if #values>=count then 
		table.remove(values, count) 
	end
	table.insert(values, 1, newValue)
	local medianCopy=table.copy(values)
	table.sort(medianCopy)
	return medianCopy[math.ceil(#medianCopy/2)]
end

function BhWritingSurface:onMouseMove(event)
	if self.focus and self:hitTestPoint(event.x, event.y) then	
		local lx, ly=self:globalToLocal(event.x, event.y)
		local timeNow=os.timer()
		local lastPoint=self.glyph[#self.glyph]
		
		-- Compute median velocity over 8 recent points
		local dist=math.pt2dDistance(lastPoint.x, lastPoint.y, lx, ly)
		local timeDelta=timeNow-self.lastGlyphTime
		local velocity=movingMedian(self.recentVelocities, 32, dist/(timeDelta)/1000)
		
		self.lastGlyphTime=timeNow
		local point = { x=lx, y=ly, velocity=velocity}
		
		-- Echo this segment
		self:beginPath()
		--self:setLineStyle(velocity*10, self.pencolor)
		self:moveTo(self:lastGlyphPointPosition())	
		self:lineTo(lx, ly)
		self:endPath()
		table.insert(self.glyph, point)		

		event:stopPropagation()
	end
end 

function BhWritingSurface:createFinishedTimer(onTimeoutFunc)
	self.finishedTimer:stop()
	self.finishedTimer=Timer.new(self.writingTimeout*1000, 1)
	collectgarbage()
	self.finishedTimer:addEventListener(Event.TIMER_COMPLETE, onTimeoutFunc, self)		
	self.finishedTimer:start()	
end

function BhWritingSurface:onMouseUp(event)
	if self.focus then
		self.focus = nil
		self.lastGlyphTime = nil
		table.insert(self.glyphSet, self.glyph)
		table.insert(self.allGlyphs, self.glyph)

		local e=Event.new("newGlyph")
		e.glyph=self.glyph
		e.glyphTime=os.timer()-self.glyphStartTime
		self:dispatchEvent(e)	
		
		self:createFinishedTimer(function() 
			local event=Event.new("endWriting")
			event.glyphSet=self.glyphSet
			self:dispatchEvent(event)
			self.glyphSet={}
			end)
		event:stopPropagation()
	end
end 

function BhWritingSurface:onIgnoreTouches(event)
	if self.focus then
		event:stopPropagation()
	end
end