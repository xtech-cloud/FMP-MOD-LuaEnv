local style = require 'style'
local lrc = require 'lrc'
local unity = CS.UnityEngine
local ugui = CS.UnityEngine.UI
local g_archiveReader = G_API_PROXY.archiveReader
local g_preReadSequence = G_API_PROXY.preReadSequence

local uiReference = {
    sliderProgress = nil,
    audioChannel = nil,
    musicSource = nil,
    accompanimentSource = nil,
    textSubtitle = nil,
    textTime = nil,
}
local isPlaying = false
local subtitles = {}
local volumeClickTimestamp = 0
-- 解绑事件的数组
local unbindFunctions = {}

-- 字符切割函数
local function split(str, split_char)      
    local sub_str_tab = {}
    while true do          
        local pos = string.find(str, split_char) 
        if not pos then              
            table.insert(sub_str_tab,str)
            break
        end  
        local sub_str = string.sub(str, 1, pos - 1)              
        table.insert(sub_str_tab,sub_str)
        str = string.sub(str, pos + 1, string.len(str))
    end      
    return sub_str_tab
end


-- 获取剩余时间的字符串
local function getLeftTime()
    local left = uiReference.audioChannel.clip.length - uiReference.audioChannel.time
    local m = string.format("%02.0f", left/60)
    local s = string.format("%02s", left%60)
    return string.format("%02.0f:%02.0f", left/60, left%60)
end


-- 解析歌词
local function parseLRC(_lrc)
    local lines = {}
    -- 按行分割
    lines = split(_lrc, '\n')

    -- 遍历每行，将时间转换为毫秒单位的时间戳
    for k, v in pairs(lines)
    do
        if "" ~= v
        then
            local min = tonumber(string.sub(v, 2, 3))
            local sec = tonumber(string.sub(v, 5, 6))
            local ms = tonumber(string.sub(v, 8, 9))
            local txt = string.sub(v, 11)
            local subtitle = {}
            subtitle["timestamp"] = min * 60 * 1000 + sec * 1000 + ms * 10
            subtitle["txt"] = txt
            table.insert(subtitles,subtitle)
        end
    end
end


--- 重置RectTransform
local function resetRectTransform(_target, _anchorMin, _anchorMax, _anchoredPosition, _sizeDelta, _pivot)
    _target.transform.localPosition = unity.Vector3.zero
    _target.transform.localRotation = unity.Quaternion.identity
    _target.transform.localScale = unity.Vector3.one
    local rectTransform = _target:GetComponent(typeof(unity.RectTransform))
    rectTransform.anchorMin = _anchorMin
    rectTransform.anchorMax = _anchorMax
    rectTransform.anchoredPosition = _anchoredPosition
    rectTransform.sizeDelta = _sizeDelta
    rectTransform.pivot = _pivot
end

local function play()
    uiReference.animationCover:Play("rotation")
    uiReference.objPlayButton:SetActive(false)
    uiReference.objPauseButton:SetActive(true)
    uiReference.audioChannel:Play()
    isPlaying = true
end

local function pause()
    isPlaying = false
    uiReference.animationCover:Stop()
    uiReference.audioChannel:Pause()
    uiReference.objPlayButton:SetActive(true)
    uiReference.objPauseButton:SetActive(false)
end

-- 构建slider组件
local function buildSlider(_target)
    local slider = _target:AddComponent(typeof(ugui.Slider))

    local objBackground = unity.GameObject("Background")
    objBackground.transform:SetParent(slider.transform)
    local imgBg = objBackground:AddComponent(typeof(ugui.Image))
    resetRectTransform(objBackground, unity.Vector2(0, 0.25), unity.Vector2(1, 0.75), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5, 0.5))

    local objFillArea = unity.GameObject("Fill Area")
    objFillArea.transform:SetParent(slider.transform)
    objFillArea:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(objFillArea, unity.Vector2(0, 0.25), unity.Vector2(1, 0.75), unity.Vector2(-10, 0), unity.Vector2(-40, 0), unity.Vector2(0.5, 0.5))

    local objFill = unity.GameObject("Fill")
    objFill.transform:SetParent(objFillArea.transform)
    local imgFill = objFill:AddComponent(typeof(ugui.Image))
    resetRectTransform(objFill, unity.Vector2(0, 0), unity.Vector2(0, 1), unity.Vector2(0, 0), unity.Vector2(20, 0), unity.Vector2(0.5,0.5))

    local objHandleSlideArea = unity.GameObject("Handle Slide Area")
    objHandleSlideArea.transform:SetParent(slider.transform)
    objHandleSlideArea:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(objHandleSlideArea, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(-40, 0), unity.Vector2(0.5,0.5))

    local objHandle = unity.GameObject("Handle")
    objHandle.transform:SetParent(objHandleSlideArea.transform)
    local imgHandle= objHandle:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objHandle, unity.Vector2(0, 0), unity.Vector2(0, 1), unity.Vector2(0, 0), unity.Vector2(40, 0), unity.Vector2(0.5,0.5))

    slider.targetGraphic = imgHandle
    slider.fillRect = objFill:GetComponent(typeof(unity.RectTransform))
    slider.handleRect = objHandle:GetComponent(typeof(unity.RectTransform))

    return slider
end

local function bindProgressSliderEvents(_slider)
    local eventTrigger = _slider.gameObject:AddComponent(typeof(unity.EventSystems.EventTrigger))
    -- 创建开始拖拽事件
    local entryBeginDrag = unity.EventSystems.EventTrigger.Entry()
    entryBeginDrag.eventID = unity.EventSystems.EventTriggerType.BeginDrag
    entryBeginDrag.callback:AddListener(function(_e)
        pause()
    end)
    eventTrigger.triggers:Add(entryBeginDrag)

    -- 创建结束拖拽事件
    local entryEndDrag = unity.EventSystems.EventTrigger.Entry()
    entryEndDrag.eventID = unity.EventSystems.EventTriggerType.EndDrag
    entryEndDrag.callback:AddListener(function(_e)
        play()
    end)
    eventTrigger.triggers:Add(entryEndDrag)

    -- 创建拖拽时事件
    local entryDrag = unity.EventSystems.EventTrigger.Entry()
    entryDrag.eventID = unity.EventSystems.EventTriggerType.Drag
    entryDrag.callback:AddListener(function(_e)
        uiReference.audioChannel.time = uiReference.audioChannel.clip.length * uiReference.sliderProgress.value
        uiReference.textTime.text = getLeftTime()
    end)
    eventTrigger.triggers:Add(entryDrag)

      -- 创建点击事件
    local entryClick = unity.EventSystems.EventTrigger.Entry()
    entryClick.eventID = unity.EventSystems.EventTriggerType.PointerClick
    entryClick.callback:AddListener(function(_e)
        uiReference.audioChannel.time = uiReference.audioChannel.clip.length * uiReference.sliderProgress.value
        uiReference.textTime.text = getLeftTime()
    end)
    eventTrigger.triggers:Add(entryClick)
end

local function unbindProgressSliderEvents(_slider)
    local eventTrigger = _slider.gameObject:GetComponent(typeof(unity.EventSystems.EventTrigger))
    eventTrigger.triggers:Clear()
end

-- 创建背景
local function addBackground()
    local obj = unity.GameObject("background")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2.zero, unity.Vector2.one, unity.Vector2.zero, unity.Vector2.zero, unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("bg.jpg", unity.TextureFormat.RGB24)
    img.texture = texture

    local objFrame = unity.GameObject("frame")
    objFrame.transform:SetParent(obj.transform)
    local img = objFrame:AddComponent(typeof(ugui.Image))
    img.type = ugui.Image.Type.Sliced
    resetRectTransform(objFrame, unity.Vector2.zero, unity.Vector2.one, unity.Vector2.zero, unity.Vector2.zero, unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("frame.png", unity.TextureFormat.RGBA32)
    local rect = unity.Rect(0, 0, texture.width, texture.height)
    local border = unity.Vector4(style.frame_border_left, style.frame_border_bottom, style.frame_border_right, style.frame_border_top)
    local sprite = g_archiveReader:CreateSprite(texture, rect, border)
    img.sprite = sprite
end

-- 创建封面
local function addCover()
    local obj = unity.GameObject("cover")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 106), unity.Vector2(512, 512), unity.Vector2(0.5,0.5))

    -- 加载图片
    local texture = g_archiveReader:ReadTexture("cover.png", unity.TextureFormat.RGBA32)
    imgBg.texture= texture

    -- 创建Z轴动画
    local animation = obj:AddComponent(typeof(unity.Animation))
    local clip = unity.AnimationClip()
    clip.name = "rotation"
    clip.legacy = true
    clip.wrapMode = unity.WrapMode.Loop
    -- 从0秒0度到15秒360度的曲线
    local curve = unity.AnimationCurve.Linear(0,0,15,-360)
    clip:SetCurve("", typeof(unity.Transform), "localEulerAngles.z", curve)
    animation:AddClip(clip, clip.name)

    uiReference.objCover = obj
    uiReference.animationCover = animation
end

local function addToolbar()
    local obj = unity.GameObject("toolbar")
    obj.transform:SetParent(G_SLOT_UI.transform)
    obj:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(obj, unity.Vector2(0, 0), unity.Vector2(1, 0), unity.Vector2(0, 0), unity.Vector2(0, 100), unity.Vector2(0.5, 0))

    uiReference.objToolbar = obj
end


-- 创建播放按钮
local function addPlayButton()
    local obj = unity.GameObject("btnPlay")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(0, 0.5), unity.Vector2(0, 0.5), unity.Vector2(106, 0), unity.Vector2(64, 64), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-play.png", unity.TextureFormat.RGBA32)
    imgBg.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    button.onClick:AddListener(function()
        play()
    end)

    table.insert(unbindFunctions, 1, function()
        button.onClick:RemoveAllListeners()
    end)
    uiReference.objPlayButton = obj
end

-- 创建暂停按钮
local function addPauseButton()
    local obj = unity.GameObject("btnPause")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(0, 0.5), unity.Vector2(0, 0.5), unity.Vector2(106, 0), unity.Vector2(64, 64), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-pause.png", unity.TextureFormat.RGBA32)
    imgBg.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    button.onClick:AddListener(function()
        pause()
    end)
    table.insert(unbindFunctions, 1, function()
        button.onClick:RemoveAllListeners()
    end)
    obj:SetActive(false)

    uiReference.objPauseButton = obj
end

-- 创建音量按钮
local function addVolumeButton()
    local obj = unity.GameObject("btnVolume")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(1, 0.5), unity.Vector2(1, 0.5), unity.Vector2(-72, 0), unity.Vector2(48, 48), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-volume.png", unity.TextureFormat.RGBA32)
    imgBg.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    button.onClick:AddListener(function()
        uiReference.objVolumePanel:SetActive(not uiReference.objVolumePanel.activeSelf)
        volumeClickTimestamp = CS.System.DateTime.UtcNow.Second
    end)
    table.insert(unbindFunctions, 1, function()
        button.onClick:RemoveAllListeners()
    end)

    uiReference.objVolumeButton = obj
end

-- 创建唱按钮
local function addMusicButton()
    local obj = unity.GameObject("btnMusic")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(1, 0.5), unity.Vector2(1, 0.5), unity.Vector2(-192, 0), unity.Vector2(98, 38), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-music.png", unity.TextureFormat.RGBA32)
    img.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    button.onClick:AddListener(function()
        uiReference.objMusicButton:SetActive(false)
        uiReference.objAccompanimentButton:SetActive(true)
        uiReference.audioChannel:Pause()
        -- 切换到伴
        uiReference.accompanimentSource.time = uiReference.musicSource.time
        uiReference.audioChannel = uiReference.accompanimentSource
        if isPlaying then
            uiReference.audioChannel:Play()
        end
    end)
    table.insert(unbindFunctions, 1, function()
        button.onClick:RemoveAllListeners()
    end)
    uiReference.objMusicButton = obj
end

-- 创建伴按钮
local function addAccompanimentButton()
    local obj = unity.GameObject("btnAccompaniment")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(1, 0.5), unity.Vector2(1, 0.5), unity.Vector2(-192, 0), unity.Vector2(98, 38), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-accompaniment.png", unity.TextureFormat.RGBA32)
    img.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    button.onClick:AddListener(function()
        uiReference.objAccompanimentButton:SetActive(false)
        uiReference.objMusicButton:SetActive(true)
        uiReference.audioChannel:Pause()
        -- 切换到唱
        uiReference.musicSource.time = uiReference.accompanimentSource.time
        uiReference.audioChannel = uiReference.musicSource
        if isPlaying then
            uiReference.audioChannel:Play()
        end
    end)
    table.insert(unbindFunctions, 1, function()
        button.onClick:RemoveAllListeners()
    end)

    obj:SetActive(false)
    uiReference.objAccompanimentButton = obj
end

-- 创建播放进度
local function addProgressBar()
    local obj = unity.GameObject("sdProgress")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local slider = buildSlider(obj)
    resetRectTransform(obj, unity.Vector2(0, 0.5), unity.Vector2(1, 0.5), unity.Vector2(-120, 0), unity.Vector2(-720, 40), unity.Vector2(0.5,0.5))

    local imgBackground = slider.transform:Find("Background"):GetComponent(typeof(ugui.Image))
    imgBackground.color = unity.Color(style.color_primary_dark_r, style.color_primary_dark_g, style.color_primary_dark_b, style.color_primary_dark_a)
    local imgFill= slider.transform:Find("Fill Area/Fill"):GetComponent(typeof(ugui.Image))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    local imgHandle= slider.transform:Find("Handle Slide Area/Handle"):GetComponent(typeof(ugui.RawImage))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("handle.png", unity.TextureFormat.RGBA32)
    imgHandle.texture= texture

    bindProgressSliderEvents(slider)
    table.insert(unbindFunctions, 1, function()
        unbindProgressSliderEvents(slider)
    end)

    uiReference.sliderProgress = slider 
end

-- 创建音量大小
local function addVolumePanel()
    local objPanel = unity.GameObject("panelVolume")
    objPanel.transform:SetParent(G_SLOT_UI.transform)
    local imgPanel = objPanel:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objPanel, unity.Vector2(1, 0), unity.Vector2(1, 0), unity.Vector2(-72, 240), unity.Vector2(80, 259), unity.Vector2(0.5,0.5))

    -- 加载图片
    local texturePanel = g_archiveReader:ReadTexture("panel-volume.png", unity.TextureFormat.RGBA32)
    imgPanel.texture= texturePanel

    local obj = unity.GameObject("sdVolume")
    obj.transform:SetParent(objPanel.transform)
    local slider = buildSlider(obj)
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(240, 40), unity.Vector2(0.5,0.5))
    local imgBackground = slider.transform:Find("Background"):GetComponent(typeof(ugui.Image))
    imgBackground.color = unity.Color(style.color_primary_dark_r, style.color_primary_dark_g, style.color_primary_dark_b, style.color_primary_dark_a)
    local imgFill= slider.transform:Find("Fill Area/Fill"):GetComponent(typeof(ugui.Image))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    local imgHandle= slider.transform:Find("Handle Slide Area/Handle"):GetComponent(typeof(ugui.RawImage))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("handle.png", unity.TextureFormat.RGBA32)
    imgHandle.texture= texture

    obj.transform.localRotation = unity.Quaternion.Euler(0,0,90)
    objPanel:SetActive(false)
    slider.value = 1
    slider.onValueChanged:AddListener(function(_value)
        uiReference.musicSource.volume = _value
        uiReference.accompanimentSource.volume = _value
        volumeClickTimestamp = CS.System.DateTime.UtcNow.Second
    end)
    table.insert(unbindFunctions, 1, function()
        slider.onValueChanged:RemoveAllListeners()
    end)
    uiReference.objVolumePanel = objPanel
end

-- 创建时间显示
local function addTimeText()
    local obj = unity.GameObject("txtTime")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local text = obj:AddComponent(typeof(ugui.Text))
    resetRectTransform(obj, unity.Vector2(1, 0.5), unity.Vector2(1, 0.5), unity.Vector2(-380, 0), unity.Vector2(140, 64), unity.Vector2(0.5,0.5))
    text.font = G_FONT_MAIN
    text.fontSize = 32
    text.alignment = unity.TextAnchor.MiddleLeft
    text.text = "00:00"
    uiReference.textTime = text
end

-- 创建歌词显示
local function addSubtitleText()
    local obj = unity.GameObject("txtSubtitle")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local text = obj:AddComponent(typeof(ugui.Text))
    resetRectTransform(obj, unity.Vector2(0, 0), unity.Vector2(1, 0), unity.Vector2(0, 243), unity.Vector2(-64, 240), unity.Vector2(0.5,0.5))
    text.font = G_FONT_MAIN
    text.fontSize = 64
    text.alignment = unity.TextAnchor.MiddleCenter
    text.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    uiReference.textSubtitle = text
end

local function addMusicSource()
    local obj = unity.GameObject("music")
    obj.transform:SetParent(G_SLOT_UI.transform)
    obj:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))
    local source = obj:AddComponent(typeof(unity.AudioSource))
    source.playOnAwake = false
    uiReference.musicSource = source
end

local function addAccompanimentSource()
    local obj = unity.GameObject("accompaniment")
    obj.transform:SetParent(G_SLOT_UI.transform)
    obj:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))
    local source = obj:AddComponent(typeof(unity.AudioSource))
    source.playOnAwake = false
    uiReference.accompanimentSource = source
end

-- 创建加载提示
local function addLoadingTip()
    local objBg = unity.GameObject("loading")
    objBg.transform:SetParent(G_SLOT_UI.transform)
    local imgBg = objBg:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objBg, unity.Vector2.zero, unity.Vector2.one, unity.Vector2.zero, unity.Vector2.zero, unity.Vector2(0.5,0.5))
    imgBg.color = unity.Color(0,0,0,0.9)

    local objIcon = unity.GameObject("icon")
    objIcon.transform:SetParent(objBg.transform)
    local imgIcon = objIcon:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objIcon, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2.zero, unity.Vector2(128, 128), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("loading.png", unity.TextureFormat.RGBA32)
    imgIcon.texture = texture

    -- 创建Z轴动画
    local animation = objIcon:AddComponent(typeof(unity.Animation))
    local clip = unity.AnimationClip()
    clip.name = "rotation"
    clip.legacy = true
    clip.wrapMode = unity.WrapMode.Loop
    -- 从0秒0度到2秒360度的曲线
    local curve = unity.AnimationCurve.EaseInOut(0,0,2,-360)
    clip:SetCurve("", typeof(unity.Transform), "localEulerAngles.z", curve)
    animation:AddClip(clip, clip.name)
    animation:Play(clip.name)

    uiReference.loadingTip = objBg
end

local function run()
    addBackground()
    addCover()
    addToolbar()
    addPlayButton()
    addPauseButton()
    addVolumeButton()
    addMusicButton()
    addAccompanimentButton()
    addProgressBar()
    addTimeText()
    addSubtitleText()
    addVolumePanel()
    addMusicSource()
    addAccompanimentSource()
    addLoadingTip()

    -- 解析歌词
    parseLRC(lrc)
    
    -- 异步预读取
    g_preReadSequence = G_API_PROXY.preReadSequence
    g_preReadSequence.OnFinish = function()
        uiReference.loadingTip:SetActive(false)
        -- 开始播放
        uiReference.audioChannel = uiReference.musicSource
        play()
    end
    g_preReadSequence:Dial()
    g_preReadSequence:Dial()

    -- 预加载音乐
    local preReadMusicCallback = g_archiveReader:NewPreReadCallback()
    preReadMusicCallback.onSuccess = function()
        -- 加载音频
        local audioClip = g_archiveReader:ReadAudioClip("music.mp3")
        uiReference.musicSource.clip = audioClip
        g_preReadSequence:Tick()
    end
    preReadMusicCallback.onFailure = function()
    end
    table.insert(unbindFunctions, 1, function()
        preReadMusicCallback.onSuccess = nil
        preReadMusicCallback.onFailure = nil
    end)
    g_archiveReader:PreReadAudioClipAsync("music.mp3", preReadMusicCallback)

    -- 预加载伴奏
    local preReadAccompanimentCallback = g_archiveReader:NewPreReadCallback()
    preReadAccompanimentCallback.onSuccess = function()
        -- 加载音频
        local audioClip = g_archiveReader:ReadAudioClip("accompaniment.mp3")
        uiReference.accompanimentSource.clip = audioClip
        g_preReadSequence:Tick()
    end
    preReadAccompanimentCallback.onFailure = function()
    end
    table.insert(unbindFunctions, 1, function()
        preReadAccompanimentCallback.onSuccess = nil
        preReadAccompanimentCallback.onFailure = nil
    end)
    g_archiveReader:PreReadAudioClipAsync("accompaniment.mp3", preReadAccompanimentCallback)
end

local function update()
    if CS.System.DateTime.UtcNow.Second > volumeClickTimestamp + 2 then
        if nil ~= uiReference.objVolumePanel then
            uiReference.objVolumePanel:SetActive(false)
        end
    end

    if false == isPlaying
    then
        return
    end

    uiReference.sliderProgress.value = uiReference.audioChannel.time / uiReference.audioChannel.clip.length
    uiReference.textTime.text = getLeftTime()

    local subtitle = ""
    for k, v in pairs(subtitles)
    do
        if v["timestamp"] < uiReference.audioChannel.time* 1000
        then
            subtitle = v["txt"]
        end
    end
    uiReference.textSubtitle.text = subtitle
end

local function stop()
    -- 注销所有回调，避免抛出异常
    -- InvalidOperationException: try to dispose a LuaEnv with C# callback!
    g_preReadSequence.OnFinish = nil
    for i,v in ipairs(unbindFunctions) do
        v()
    end
end

return {
    Run = run,
    Update = update,
    Stop = stop,
}
