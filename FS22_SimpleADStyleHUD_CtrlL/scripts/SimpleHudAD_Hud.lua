-- FS22 Survey HUD - HUD rendering library
-- v1.0.3.1

-- GIANTS ships a 1x1 pixel texture used by many mods for colored rectangles
local PIXEL = "dataS/scripts/shared/graph_pixel.dds"

local function renderBox(ov, x, y, w, h, c)
    ov:setPosition(x, y)
    ov:setDimension(w, h)
    ov:setColor(c[1], c[2], c[3], c[4])
    ov:render()
end

local function renderTextLine(x, y, size, text, c, align, bold)
    setTextColor(c[1], c[2], c[3], c[4])
    setTextAlignment(align or RenderText.ALIGN_LEFT)
    setTextBold(bold == true)
    renderText(x, y, size, text)
end

local function fmtSigned(v, decimals)
    if v == nil then
        return "--"
    end

    decimals = decimals or 3
    local fmt = string.format("%%+.%df", decimals)
    return string.format(fmt, v)
end

local function getBandColor(self, v)
    if v == nil then
        return self.colMuted
    end

    local av = math.abs(v)
    if av <= 0.02 then
        return self.colGood
    elseif av <= 0.05 then
        return self.colWarn
    end

    return self.colBad
end

function SimpleHudAD:createOverlays()
    if self.bgOv == nil then
        self.bgOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
    if self.headerOv == nil then
        self.headerOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
    if self.lineOv == nil then
        self.lineOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
    if self.cellOv == nil then
        self.cellOv = Overlay.new(PIXEL, 0, 0, 1, 1)
    end
end

function SimpleHudAD:deleteOverlays()
    if self.bgOv ~= nil then self.bgOv:delete(); self.bgOv = nil end
    if self.headerOv ~= nil then self.headerOv:delete(); self.headerOv = nil end
    if self.lineOv ~= nil then self.lineOv:delete(); self.lineOv = nil end
    if self.cellOv ~= nil then self.cellOv:delete(); self.cellOv = nil end
end

function SimpleHudAD:onMissionDraw(mission)
    if not self.isVisible then
        return
    end

    self:createOverlays()

    local w, h = getNormalizedScreenValues(640, 480)
    local marginX, marginY = getNormalizedScreenValues(18, 18)

    local offX = g_safeFrameOffsetX or 0
    local offY = g_safeFrameOffsetY or 0

    local x = 1 - offX - marginX - w
    local y = offY + marginY

    -- background + header + line using overlays (AutoDrive-style)
    renderBox(self.bgOv, x, y, w, h, self.colBg)

    local _, headerH = getNormalizedScreenValues(0, 32)
    renderBox(self.headerOv, x, y + h - headerH, w, headerH, self.colHeader)

    local _, lineH = getNormalizedScreenValues(0, 2)
    renderBox(self.lineOv, x, y, w, lineH, self.colHeader)

    -- text
    local padX, _ = getNormalizedScreenValues(16, 0)
    local _, padY = getNormalizedScreenValues(0, 14)
    local _, titleSize = getNormalizedScreenValues(0, 20)
    local _, headSize  = getNormalizedScreenValues(0, 32)
    local _, valueSize = getNormalizedScreenValues(0, 24)
    local _, rowSize   = getNormalizedScreenValues(0, 16)
    local _, headerOffY = getNormalizedScreenValues(0, 6)

    local headerY = y + h - headerH + headerOffY

    renderTextLine(x + padX, headerY, titleSize, "Survey HUD", self.colText, RenderText.ALIGN_LEFT, true)
    renderTextLine(x + w - padX, headerY, titleSize, "CTRL + L", self.colText, RenderText.ALIGN_RIGHT, true)

    -- get values
    local n = self.data.n
    local e = self.data.e
    local hVal = self.data.h
    local cutFill = self.data.cutFill

    -- headline: CUT / FILL
    local headlineY = y + h - headerH - padY - headSize
    local bandCol = getBandColor(self, cutFill)
    local direction = ""
    if cutFill ~= nil then
        if cutFill > 0 then
            direction = "^"
        elseif cutFill < 0 then
            direction = "v"
        end
    end

    local headlineText = "CUT/FILL"
    if cutFill ~= nil then
        if cutFill > 0 then
            headlineText = "FILL"
        elseif cutFill < 0 then
            headlineText = "CUT"
        else
            headlineText = "LEVEL"
        end
    end

    renderTextLine(x + padX, headlineY, headSize, headlineText, self.colText, RenderText.ALIGN_LEFT, true)
    renderTextLine(x + w - padX, headlineY, headSize, string.format("%s %s", direction, fmtSigned(cutFill, 3)), bandCol, RenderText.ALIGN_RIGHT, true)

    -- band indicator
    local _, bandH = getNormalizedScreenValues(0, 10)
    renderBox(self.lineOv, x + padX, headlineY - padY, w - padX - padX, bandH, bandCol)

    -- N / E / H table (3 columns)
    local _, tableH = getNormalizedScreenValues(0, 120)
    local tableY = y + padY
    local cellW = (w - padX - padX) / 3
    local cellX = x + padX

    -- cell backgrounds
    renderBox(self.cellOv, cellX, tableY, cellW, tableH, self.colCellBg)
    renderBox(self.cellOv, cellX + cellW, tableY, cellW, tableH, self.colCellBg)
    renderBox(self.cellOv, cellX + cellW + cellW, tableY, cellW, tableH, self.colCellBg)

    local _, labelSize = getNormalizedScreenValues(0, 18)
    local _, valOffY = getNormalizedScreenValues(0, 44)

    renderTextLine(cellX + cellW * 0.5, tableY + tableH - padY, labelSize, "N", self.colMuted, RenderText.ALIGN_CENTER, true)
    renderTextLine(cellX + cellW * 0.5, tableY + tableH - valOffY, valueSize, fmtSigned(n, 3), self.colText, RenderText.ALIGN_CENTER, false)

    renderTextLine(cellX + cellW * 1.5, tableY + tableH - padY, labelSize, "E", self.colMuted, RenderText.ALIGN_CENTER, true)
    renderTextLine(cellX + cellW * 1.5, tableY + tableH - valOffY, valueSize, fmtSigned(e, 3), self.colText, RenderText.ALIGN_CENTER, false)

    renderTextLine(cellX + cellW * 2.5, tableY + tableH - padY, labelSize, "H", self.colMuted, RenderText.ALIGN_CENTER, true)
    renderTextLine(cellX + cellW * 2.5, tableY + tableH - valOffY, valueSize, fmtSigned(hVal, 3), self.colText, RenderText.ALIGN_CENTER, false)

    -- footer info
    local footerY = tableY + tableH + padY
    renderTextLine(x + padX, footerY, rowSize, "Input:", self.colMuted, RenderText.ALIGN_LEFT, false)
    renderTextLine(x + w - padX, footerY, rowSize, self.firedOnce and "ActionEvent" or "Raw fallback", self.colText, RenderText.ALIGN_RIGHT, false)
end
