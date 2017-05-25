-- Browse through patterns in a folder (and optionally subfolders)
-- Page Up/Page Down to cycle through patterns
-- Home to select a new folder to browse
-- O to display options
-- Esc to exit at current pattern
-- Author: Chris Rowett (crowett@gmail.com)
-- Build 14

local g = golly()
local gp = require "gplus"
local floor = math.floor
local op = require "oplus"
-- require "gplus.strict"

-- overlay
local ov = g.overlay
local viewwd, viewht = g.getview(g.getlayer())
local overlaycreated = false

local pathsep = g.getdir("app"):sub(-1)
local busy = "Finding patterns, please wait..."
local controls = "[Page Up] previous, [Page Down] next, [Home] select folder, [O] options, [Esc] exit."

-- pattern list
local patterns = {}           -- Array of patterns
local numpatterns = 0         -- Number of patterns
local numsubs = 0             -- Number of subdirectories
local whichpattern = 1        -- Current pattern index

-- settings are saved in this file
local settingsfile = g.getdir("data").."browse-patterns.ini"

-- gui buttons
local prevbutton      -- Previous button
local nextbutton      -- Next button
local folderbutton    -- Folder button
local exitbutton      -- Exit button
local startcheck      -- AutoStart checkbox
local fitcheck        -- AutoFit checkbox
local speedslider     -- AutoAdvance speed slider
local optionsbutton   -- Options button
local subdircheck     -- Include subdirectories checkbox
local keepspeedcheck  -- Keep speed checkbox
local loopcheck       -- Loop checkbox
local infocheck       -- Show Info checkbox

-- position
local guiht        = 32    -- height of toolbar
local guiwd        = 0     -- computed width of toolbar (from control widths)
local optht        = 0     -- height of options panel
local gapx         = 10    -- horitzonal gap between controls
local gapy         = 4     -- vertical gap between controls
local slidertextx  = 0     -- text position following slider
local maxsliderval = 22    -- maxmimum slider value
local sliderpower  = 1.32  -- slider power

-- style
local toolbarbgcolor = "rgba 0 0 0 192"

-- flags
local loadnew     = false  -- whether to load a new pattern
local exitnow     = false  -- whether to exit
local showoptions = false  -- whether options are displayed
local refreshgui  = true   -- whether the gui needs to be refreshed

-- settings
local autostart    = 0   -- whether to autostart playback on pattern load
local autofit      = 0   -- whether to switch on autofit on pattern load
local keepspeed    = 0   -- whether to maintain speed between patterns
local subdirs      = 1   -- whether to include subdirectories
local looping      = 1   -- whether to loop pattern list
local advancespeed = 0   -- advance speed (0 for manual)
local showinfo     = 0   -- show info if present

local currentstep     = g.getstep()  -- current step
local patternloadtime = 0            -- pattern load time (ms)

-- pattern information
local infonum     = 0       -- number of info clips
local infowd      = {}      -- width of pattern info clips
local infoht      = {}      -- height of pattern info clips
local infox       = 0       -- info text x coordinate
local infoclip    = "info"  -- info clip prefix name
local infotime    = 0       -- time last information frame drawn
local infochunk   = 256     -- number of characters per info clip
local infowdtotal = 0       -- total width of info clips
local infospeed   = 9       -- scrolling speed (ms to move one pixel)

-- file extensions to load
local matchlist = { rle = true, mcl = true, mc = true, lif = true, gz = true }

-- remaining time before auto advance
local remaintime = 0

--------------------------------------------------------------------------------

local function savesettings()
    local f = io.open(settingsfile, "w")
    if f then
        f:write(tostring(autostart).."\n")
        f:write(tostring(autofit).."\n")
        f:write(tostring(keepspeed).."\n")
        f:write(tostring(subdirs).."\n")
        f:write(tostring(looping).."\n")
        f:write(tostring(advancespeed).."\n")
        f:write(tostring(showinfo).."\n")
        f:close()
    end
end

--------------------------------------------------------------------------------

local function loadsettings()
    local f = io.open(settingsfile, "r")
    if f then
        autostart    = tonumber(f:read("*l")) or 0
        autofit      = tonumber(f:read("*l")) or 0
        keepspeed    = tonumber(f:read("*l")) or 0
        subdirs      = tonumber(f:read("*l")) or 1
        looping      = tonumber(f:read("*l")) or 1
        advancespeed = tonumber(f:read("*l")) or 0
        showinfo     = tonumber(f:read("*l")) or 0
        f:close()
    end
end

--------------------------------------------------------------------------------

local function findpatterns(dir)
    local files = g.getfiles(dir)
    for _, name in ipairs(files) do
        if name:sub(1,1) == "." then
            -- ignore hidden files (like .DS_Store on Mac)
        elseif name:sub(-1) == pathsep then
            -- name is a subdirectory
            numsubs = numsubs + 1
            if subdirs == 1 then
                findpatterns(dir..name)
            end
        else
            -- check the file is the right type to display
            local index = name:match'^.*()%.'
            if index then
                if matchlist[name:sub(index+1)] then
                    -- add to list of patterns
                    numpatterns = numpatterns + 1
                    patterns[numpatterns] = dir..name
                end
            end
        end
    end
end

--------------------------------------------------------------------------------

local function getpatternlist(dir)
    numpatterns = 0
    numsubs = 0
    g.show(busy)
    findpatterns(dir)
    if numpatterns == 0 then
        if numsubs == 0 then
            g.note("No patterns found in:\n\n"..dir)
        else
            g.note("Only subdirectories found in:\n\n"..dir)
        end
    end
end

--------------------------------------------------------------------------------

local function previouspattern()
    local new = whichpattern - 1
    if new < 1 then
        if looping == 1 then
            new = numpatterns
        else
            new = 1
        end
    end
    if new ~= whichpattern then
        whichpattern = new
        loadnew = true
    end
end

--------------------------------------------------------------------------------

local function nextpattern()
    local new = whichpattern + 1
    if new > numpatterns then
        if looping == 1 then
            new = 1
        else
            new = numpatterns
        end
    end
    if new ~= whichpattern then
        whichpattern = new
        loadnew = true
    end
end

--------------------------------------------------------------------------------

local function exitbrowser()
    loadnew = true
    exitnow = true
end

--------------------------------------------------------------------------------

local function toggleautostart()
    autostart = 1 - autostart
    savesettings()
end

--------------------------------------------------------------------------------

local function toggleautofit()
    autofit = 1 - autofit
    savesettings()
end

--------------------------------------------------------------------------------

local function selectfolder()
    -- remove the filename from the supplied path
    local current = patterns[whichpattern]
    local dirname = current:sub(1, current:find(pathsep.."[^"..pathsep.."/]*$"))

    -- ask for a folder
    local dirname = g.opendialog("Choose a folder", "dir", dirname)
    if dirname ~= "" then
        getpatternlist(dirname)
        whichpattern = 1
        loadnew = true
    end
end

--------------------------------------------------------------------------------

local function drawspeed(x, y)
    -- convert speed into labael
    local message = "Manual"
    if advancespeed > 0 then
        -- convert the slider position into minutes and seconds
        local time = sliderpower ^ (maxsliderval - advancespeed)
        if time < 60 then
            if time < 10 then
                message = string.format("%.1f", time).."s"
            else
                message = floor(time).."s"
            end
        else
            message = floor(time / 60).."m"..floor(time % 60).."s"
        end

        -- convert remaining ms into minutes and seconds
        local remain = floor(remaintime / 1000)
        message = message.."  (next in "
        if remain >= 60 then
            message = message..floor(remain / 60).."m"..(remain % 60).."s"
        else
            if remain < 10 then
                remain = remaintime / 1000
                if remain < 0 then remain = 0 end
                message = message..string.format("%.1f", remain).."s"
            else
                if remain < 0 then remain = 0 end
                message = message..remain.."s"
            end
        end
        message = message..")"
    end

    -- update the label
    op.maketext(message, "label", op.white, 2, 2, op.black)
    ov("blend 1")
    op.pastetext(x, y, op.identity, "label")
    ov("blend 0")
end

--------------------------------------------------------------------------------

local function togglespeed()
    keepspeed = 1 - keepspeed
    savesettings()
end

--------------------------------------------------------------------------------

local function toggleloop()
    looping = 1 - looping
    savesettings()
end

--------------------------------------------------------------------------------

local function togglesubdirs()
    subdirs = 1 - subdirs
    savesettings()
end

--------------------------------------------------------------------------------

local function toggleoptions()
    showoptions = not showoptions
    if showoptions then
        optionsbutton.setlabel("Close", false)
    else
        optionsbutton.setlabel("Options", false)
    end
    refreshgui = true
end

--------------------------------------------------------------------------------

local function drawinfo()
    -- draw the info background
    ov(toolbarbgcolor)
    ov("fill 0 "..guiht.." "..guiwd.." "..guiht)

    -- compute how far to move the text based on time since last update
    local now = g.millisecs()
    local dx = now - infotime
    infotime = now
    infox = infox - dx / infospeed
    if infox < -infowdtotal then
        infox = guiwd
    end

    -- draw the info text
    ov("blend 1")
    local x = floor(infox)
    local y = infoht[1]
    for i = 1, infonum do
        op.pastetext(x, guiht + floor((guiht - y) / 2), op.identity, infoclip..i)
        x = x + infowd[i] - 2  -- make subsequent clips overlap slightly to remove text gap
    end
    ov("blend 0")
end

--------------------------------------------------------------------------------

local function drawgui()
    -- check whether to draw info
    if showinfo == 1 and infowdtotal ~= 0 then
        drawinfo()
    end

    -- check if the gui needs to be refreshed
    if refreshgui or (showoptions and advancespeed > 0) then
        -- mark gui as refreshed
        refreshgui = false

        -- draw toolbar background
        ov("blend 0")
        ov(toolbarbgcolor)
        ov("fill 0 0 "..guiwd.." "..guiht)
    
        -- draw main buttons
        local y = floor((guiht - prevbutton.ht) / 2)
        local x = gapx
        prevbutton.show(x, y)
        x = x + prevbutton.wd + gapx
        nextbutton.show(x, y)
        x = x + nextbutton.wd + gapx
        folderbutton.show(x, y)
        x = x + folderbutton.wd + gapx
        optionsbutton.show(x, y)
        x = x + optionsbutton.wd + gapx
        exitbutton.show(x, y)

        -- compute offset for options if info is displayed
        local infoy = 0
        if showinfo == 1 and infowdtotal ~= 0 then
            infoy = guiht
        end

        -- check for options
        if showoptions then
            -- draw options background
            ov("fill 0 "..(guiht + infoy).." "..guiwd.." "..optht)
            ov("rgba 0 0 0 0")
            ov("fill 0 "..(guiht + infoy + optht).." "..guiwd.." "..infoy)

            -- draw option controls
            x = gapx
            y = guiht + gapy + infoy
            if autostart == 1 then
                startcheck.show(x, y, true)
            else
                startcheck.show(x, y, false)
            end
            y = y + startcheck.ht + gapy
            if autofit == 1 then
                fitcheck.show(x, y, true)
            else
                fitcheck.show(x, y, false)
            end
            y = y + fitcheck.ht + gapy
            if showinfo == 1 then
                infocheck.show(x, y, true)
            else
                infocheck.show(x, y, false)
            end
            y = y + infocheck.ht + gapy
            if subdirs == 1 then
                subdircheck.show(x, y, true)
            else
                subdircheck.show(x, y, false)
            end
            y = y + subdircheck.ht + gapy
            speedslider.show(x, y, advancespeed)
            x = x + speedslider.wd + gapx
            drawspeed(x, y)
            y = y + speedslider.ht + gapy
            x = gapx
            if looping == 1 then
                loopcheck.show(x, y, true)
            else
                loopcheck.show(x, y, false)
            end
            y = y + loopcheck.ht + gapy
            if keepspeed == 1 then
                keepspeedcheck.show(x, y, true)
            else
                keepspeedcheck.show(x, y, false)
            end
        else
            -- not showing options so clear the area under the toolbar
            local oldrgba = ov("rgba 0 0 0 0")
            ov("fill 0 "..(guiht + infoy).." "..guiwd.." "..optht)
            ov("rgba "..oldrgba)
        end
    end

end

--------------------------------------------------------------------------------

local function toggleinfo()
    showinfo = 1 - showinfo
    savesettings()
    refreshgui = true
    drawgui()

    -- need to refresh again since options panel will move if open
    refreshgui = true
end

--------------------------------------------------------------------------------

local function updatespeed(newval)
    advancespeed = newval
    savesettings()
    refreshgui = true
    drawgui()
end

--------------------------------------------------------------------------------

local function createoverlay()
    -- create overlay for gui
    ov("create "..viewwd.." "..viewht)
    overlaycreated = true
    op.buttonht = 20
    op.textgap = 8

    -- set font
    op.textfont = "font 10 default-bold"
    if g.os() == "Mac" then
        op.yoffset = -1
    end
    if g.os() == "Linux" then
        op.textfont = "font 10 default"
    end
    ov(op.textfont)

    -- create gui buttons
    op.textshadowx = 2
    op.textshadowy = 2
    prevbutton = op.button("Previous", previouspattern)
    nextbutton = op.button("Next", nextpattern)
    exitbutton = op.button("Exit", exitbrowser)
    folderbutton = op.button("Folder", selectfolder)
    startcheck = op.checkbox("Start playback on pattern load", op.white, toggleautostart)
    fitcheck = op.checkbox("Fit pattern to display", op.white, toggleautofit)
    speedslider = op.slider("Advance: ", op.white, 81, 0, maxsliderval, updatespeed)
    optionsbutton = op.button("Options", toggleoptions)
    subdircheck = op.checkbox("Include subdirectories", op.white, togglesubdirs)
    keepspeedcheck = op.checkbox("Maintain step speed across patterns", op.white, togglespeed)
    loopcheck = op.checkbox("Loop pattern list", op.white, toggleloop)
    infocheck = op.checkbox("Show pattern information", op.white, toggleinfo)

    -- resize the overlay to fit the controls
    optht = startcheck.ht + fitcheck.ht + infocheck.ht + subdircheck.ht + speedslider.ht
    optht = optht + loopcheck.ht + keepspeedcheck.ht + 8 * gapy
    guiwd = prevbutton.wd + nextbutton.wd + folderbutton.wd + optionsbutton.wd + exitbutton.wd + 6 * gapx
    ov("resize "..guiwd.." "..(guiht + optht + guiht))

    -- draw the overlay
    drawgui()
end

--------------------------------------------------------------------------------

local function loadinfo()
     -- clear pattern info
     infowdtotal = 0
     refreshgui = true

     -- load pattern info
     local info = g.getinfo()
     if info ~= "" then
         -- format into a single line
         local clean = info:gsub("#CXRLE.-\n", ""):gsub("#C", ""):gsub("#D", ""):gsub("#", ""):gsub("\n", " "):gsub("  *", " ")
         if clean ~= "" then
             -- split into a number of clips due to bitmap width limits
             infonum = floor((clean:len() - 1) / infochunk) + 1

             -- create the text clips
             for i = 1, infonum do
                 local i1 = (i - 1) * infochunk + 1
                 local i2 = i1 + infochunk - 1
                 infowd[i], infoht[i] = op.maketext(clean:sub(i1, i2), infoclip..i, op.white, 2, 2, op.black)
                 infowdtotal = infowdtotal + infowd[i]
             end
             infox = guiwd
         end
     end
     infotime = g.millisecs()
end

--------------------------------------------------------------------------------

local function browsepatterns(startpattern)
    local generating = 0
    local now = g.millisecs()
    local target = 15
    local delay = target

    -- if start pattern is supplied then find it in the list
    whichpattern = 1
    if startpattern ~= "" then
        local i = 1
        while i <= numpatterns do
            if patterns[i] == startpattern then
                whichpattern = i
                break
            end
            i = i + 1
        end
    end

    -- loop until escape pressed or exit clicked
    exitnow = false
    while not exitnow do
        -- load the pattern
        currentstep = g.getstep()
        g.new("")
        g.setalgo("QuickLife")      -- nicer to start from this algo
        local fullname = patterns[whichpattern]
        g.open(fullname, false)     -- don't add file to Open/Run Recent submenu
        loadinfo()
        g.show("Pattern "..whichpattern.." of "..numpatterns..". "..controls)
        g.update()
        generating = autostart

        -- reset pattern load time
        patternloadtime = g.millisecs()

        -- restore playback speed if requested
        if keepspeed == 1 then
            g.setstep(currentstep)
        end

        -- decode key presses
        loadnew = false
        while not loadnew do
            local event = op.process(g.getevent())
            if event == "key pagedown none" then
                nextpattern()
            elseif event == "key pageup none" then
                previouspattern()
            elseif event == "key home none" then
                selectfolder()
            elseif event == "key enter none" or event == "key return none" then
                generating = 1 - generating
            elseif event == "key o none" then
                toggleoptions()
            elseif event == "key space none" then
                if generating == 1 then
                    generating = 0
                else
                    g.run(1)
                end
            elseif event == "key r ctrl" then
                generating = 0
                g.reset()
            elseif event == "key tab none" then
                if generating == 1 then
                    generating = 0
                else
                    g.step()
                end
            else
               g.doevent(event)
            end

            -- run the pattern
            if generating == 1 then
                currentstep = g.getstep()
                if currentstep < 0 then
                    -- convert negative steps into delays
                    delay = sliderpower ^ -currentstep * 125
                    currentstep = 0
                else
                    delay = 15
                end
                if delay ~= target then
                    target = delay
                end
                local t = g.millisecs()
                if t - now > target then
                    g.run(g.getbase() ^ currentstep)
                    now = t
                    target = delay
                end
            end
            if autofit == 1 then
                -- get pattern bounding box
                local rect = g.getrect()
                if #rect ~= 0 then
                    -- check if entire bounding box is visible in the viewport
                    if not g.visrect(rect) then
                        g.fit()
                    end
                end
            end

            -- check for auto advance
            remaintime = 0
            if advancespeed > 0 then
                local targettime = (sliderpower ^ (maxsliderval - advancespeed)) * 1000
                remaintime = targettime - (g.millisecs() - patternloadtime)
                if remaintime < 0 then
                    nextpattern()
                    patternloadtime = g.millisecs()
                end
            end
            drawgui()
            g.update()
        end
    end
end

--------------------------------------------------------------------------------

function browse()
    -- try to get the current open pattern folder
    local pathname = g.getpath()
    local dirname = ""
    if pathname == "" then
        -- ask for a folder
        dirname = g.opendialog("Choose a folder", "dir", g.getdir("app"))
    else
        -- remove the file name
        dirname = pathname:sub(1, pathname:find(pathsep.."[^"..pathsep.."/]*$"))
    end
    if dirname ~= "" then
        loadsettings()
        getpatternlist(dirname)
        if numpatterns > 0 then
            -- display gui
            createoverlay()

            -- browse patterns
            browsepatterns(pathname)
        end
    end
end

--------------------------------------------------------------------------------

local status, err = xpcall(browse, gp.trace)
if err then g.continue(err) end

-- this code is always executed, even after escape/error;
-- clear message line in case there was no escape/error
g.show("")
if overlaycreated then ov("delete") end
