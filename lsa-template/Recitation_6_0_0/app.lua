local util = require 'xlua.util'
local style = require 'style'
local config = require 'config'
local unity = CS.UnityEngine
local ugui = CS.UnityEngine.UI
local g_archiveReader = G_API_PROXY.archiveReader
local g_preReadSequence = G_API_PROXY.preReadSequence
local g_coroutineRunner = G_RUNNER_COROUTINE

local uiReference = {
    objToolbar = nil, -- 工具栏
    objPlayButton = nil, -- 播放按钮
    objPauseButton = nil, -- 暂停按钮
    objVolumeButton = nul, -- 音量按钮
    objVolumePanel = nil, -- 音量控制面板
    sliderProgress = nil, -- 进度条
    textTime = nil, -- 时间显示
    loadingTip = nil, -- 加载显示
    audioSource = nil, -- 音频源
    svContent = nil, -- 内容的滚动视图
}
local isPlaying = false
local isDraging = false
-- 是否处理了进度条点击事件
local isClickHandled = true
local subtitles = {}
local volumeClickTimestamp = 0
-- 解绑事件的数组
local unbindFunctions = {}
-- 最近一次音频的播放时间
local lastestAudioPlayTime = 0

-- 获取剩余时间的字符串
local function getLeftTime()
    local left = uiReference.audioSource.clip.length - uiReference.audioSource.time
    local m = string.format("%02.0f", left/60)
    local s = string.format("%02s", left%60)
    return string.format("%02.0f:%02.0f", left/60, left%60)
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
    uiReference.objPlayButton:SetActive(false)
    uiReference.objPauseButton:SetActive(true)
    uiReference.audioSource:Play()
    isPlaying = true
end

local function pause()
    isPlaying = false
    uiReference.audioSource:Pause()
    uiReference.objPlayButton:SetActive(true)
    uiReference.objPauseButton:SetActive(false)
end

local function stop()
    isPlaying = false
    uiReference.audioSource.time = 0
    lastestAudioPlayTime = 0
    uiReference.audioSource:Stop()
    uiReference.objPlayButton:SetActive(true)
    uiReference.objPauseButton:SetActive(false)
end

-- 构建slider组件
local function buildSlider(_target)
    local slider = _target:AddComponent(typeof(ugui.Slider))

    local objBackground = unity.GameObject("Background")
    objBackground.transform:SetParent(slider.transform)
    local imgBg = objBackground:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objBackground, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5, 0.5))

    local objFillArea = unity.GameObject("Fill Area")
    objFillArea.transform:SetParent(slider.transform)
    objFillArea:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(objFillArea, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(10, 11), unity.Vector2(0.5, 0.5))

    local objFill = unity.GameObject("Fill")
    objFill.transform:SetParent(objFillArea.transform)
    local imgFill = objFill:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objFill, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))

    local objHandleSlideArea = unity.GameObject("Handle Slide Area")
    objHandleSlideArea.transform:SetParent(slider.transform)
    objHandleSlideArea:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(objHandleSlideArea, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))

    local objHandle = unity.GameObject("Handle")
    objHandle.transform:SetParent(objHandleSlideArea.transform)
    local imgHandle= objHandle:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objHandle, unity.Vector2(0, 0), unity.Vector2(0, 1), unity.Vector2(0, 0), unity.Vector2(35, 25), unity.Vector2(0.5,0.5))

    slider.targetGraphic = imgHandle
    slider.fillRect = objFill:GetComponent(typeof(unity.RectTransform))
    slider.handleRect = objHandle:GetComponent(typeof(unity.RectTransform))

    return slider
end

local function buildScrollView(_target)
    local scrollRect = _target:AddComponent(typeof(ugui.ScrollRect))
    local viewport = unity.GameObject("Viewport")
    viewport.transform:SetParent(scrollRect.transform)
    viewport:AddComponent(typeof(ugui.Image))
    local mask = viewport:AddComponent(typeof(ugui.Mask))
    mask.showMaskGraphic = false
    resetRectTransform(viewport, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))
    local content = unity.GameObject("Content")
    content.transform:SetParent(viewport.transform)
    content:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(content, unity.Vector2(0, 1), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 300), unity.Vector2(0,1))
    scrollRect.content = content:GetComponent(typeof(unity.RectTransform))
    return scrollRect
end

local function bindProgressSliderEvents(_slider)
    local eventTrigger = _slider.gameObject:AddComponent(typeof(unity.EventSystems.EventTrigger))
    -- 创建开始拖拽事件
    local entryBeginDrag = unity.EventSystems.EventTrigger.Entry()
    entryBeginDrag.eventID = unity.EventSystems.EventTriggerType.BeginDrag
    local onBeginDrag = function(_e)
        isDraging = true
        pause()
    end
    entryBeginDrag.callback:AddListener(onBeginDrag)
    eventTrigger.triggers:Add(entryBeginDrag)

    -- 创建结束拖拽事件
    local entryEndDrag = unity.EventSystems.EventTrigger.Entry()
    entryEndDrag.eventID = unity.EventSystems.EventTriggerType.EndDrag
    local onEndDrag = function(_e)
        play()
        isDraging = false
    end
    entryEndDrag.callback:AddListener(onEndDrag)
    eventTrigger.triggers:Add(entryEndDrag)

    -- 创建拖拽时事件
    local entryDrag = unity.EventSystems.EventTrigger.Entry()
    entryDrag.eventID = unity.EventSystems.EventTriggerType.Drag
    local onDrag = function(_e)
        uiReference.audioSource.time = uiReference.audioSource.clip.length * uiReference.sliderProgress.value
        lastestAudioPlayTime = uiReference.audioSource.time
        uiReference.textTime.text = getLeftTime()
    end
    entryDrag.callback:AddListener(onDrag)
    eventTrigger.triggers:Add(entryDrag)

    -- 创建按下事件
    -- 不能使用PointerClick，PointerClick是在按键松开后才触发，无法在Update前执行
    local entryDown = unity.EventSystems.EventTrigger.Entry()
    entryDown.eventID = unity.EventSystems.EventTriggerType.PointerDown
    local onDown = function(_e)
        isClickHandled = false
    end
    entryDown.callback:AddListener(onDown)
    eventTrigger.triggers:Add(entryDown)
end

local function unbindProgressSliderEvents(_slider)
    local eventTrigger = _slider.gameObject:GetComponent(typeof(unity.EventSystems.EventTrigger))
    eventTrigger.triggers:Clear()
end

local function addAudioSource()
    local obj = unity.GameObject("audio")
    obj.transform:SetParent(G_SLOT_UI.transform)
    obj:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))
    local source = obj:AddComponent(typeof(unity.AudioSource))
    source.playOnAwake = false
    uiReference.audioSource = source
end

local function addHeader()
    local txtTitle = unity.GameObject("txtTitle"):AddComponent(typeof(ugui.Text))
    txtTitle.transform:SetParent(G_SLOT_UI.transform)
    resetRectTransform(txtTitle.gameObject, unity.Vector2(0.5, 1), unity.Vector2(0.5, 1), unity.Vector2(0, -208), unity.Vector2(960, 120), unity.Vector2(0.5,0.5))
    txtTitle.fontSize = 58
    txtTitle.alignment = unity.TextAnchor.MiddleCenter
    txtTitle.text = config.Title
    txtTitle.font = G_FONT_MAIN
    local result, color = unity.ColorUtility.TryParseHtmlString(style.header_font_color)
    txtTitle.color = color

    local txtAuthor = unity.GameObject("txtAuthor"):AddComponent(typeof(ugui.Text))
    txtAuthor.transform:SetParent(G_SLOT_UI.transform)
    resetRectTransform(txtAuthor.gameObject, unity.Vector2(0.5, 1), unity.Vector2(0.5, 1), unity.Vector2(-370, -280), unity.Vector2(240, 60), unity.Vector2(0, 0.5))
    txtAuthor.fontSize = 28
    txtAuthor.alignment = unity.TextAnchor.MiddleLeft
    txtAuthor.text = config.Author
    txtAuthor.font = G_FONT_MAIN
    local result, color = unity.ColorUtility.TryParseHtmlString(style.header_font_color)
    txtAuthor.color = color

    local txtReciter= unity.GameObject("txtReciter"):AddComponent(typeof(ugui.Text))
    txtReciter.transform:SetParent(G_SLOT_UI.transform)
    resetRectTransform(txtReciter.gameObject, unity.Vector2(0.5, 1), unity.Vector2(0.5, 1), unity.Vector2(370, -280), unity.Vector2(240, 60), unity.Vector2(1, 0.5))
    txtReciter.fontSize = 28
    txtReciter.alignment = unity.TextAnchor.MiddleRight
    txtReciter.text = config.Reciter
    txtReciter.font = G_FONT_MAIN
    local result, color = unity.ColorUtility.TryParseHtmlString(style.header_font_color)
    txtReciter.color = color
end

-- 创建背景
local function addBackground()
    local obj = unity.GameObject("background")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2.zero, unity.Vector2.one, unity.Vector2.zero, unity.Vector2.zero, unity.Vector2(0.5,0.5))
    -- 加载图片
    local rectSlot = G_SLOT_UI:GetComponent(typeof(unity.RectTransform)).rect
    if rectSlot.width < rectSlot.height then
        img.texture = g_archiveReader:ReadTexture("bg_portrait.jpg", unity.TextureFormat.RGB24)
    else
        img.texture = g_archiveReader:ReadTexture("bg_landscape.jpg", unity.TextureFormat.RGB24)
    end

    local objFrame = unity.GameObject("frame")
    objFrame.transform:SetParent(obj.transform)
    local img = objFrame:AddComponent(typeof(ugui.Image))
    img.type = ugui.Image.Type.Sliced
    resetRectTransform(objFrame, unity.Vector2(0.5, 0), unity.Vector2(0.5, 1), unity.Vector2.zero, unity.Vector2(1080, 0), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("frame.png", unity.TextureFormat.RGBA32)
    local rect = unity.Rect(0, 0, texture.width, texture.height)
    local border = unity.Vector4(style.frame_border_left, style.frame_border_bottom, style.frame_border_right, style.frame_border_top)
    img.sprite = g_archiveReader:CreateSprite(texture, rect, border)
end

local function addToolbar()
    local obj = unity.GameObject("toolbar")
    obj.transform:SetParent(G_SLOT_UI.transform)
    obj:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(obj, unity.Vector2(0.5, 0), unity.Vector2(0.5, 0), unity.Vector2(0, 117), unity.Vector2(864, 60), unity.Vector2(0.5, 0.5))
    local img = obj:AddComponent(typeof(ugui.RawImage))
    img.texture = g_archiveReader:ReadTexture("toolbar-bg.png", unity.TextureFormat.RGBA32)

    uiReference.objToolbar = obj
end


-- 创建播放按钮
local function addPlayButton()
    local obj = unity.GameObject("btnPlay")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(0, 0.5), unity.Vector2(0, 0.5), unity.Vector2(64, 0), unity.Vector2(42, 42), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-play.png", unity.TextureFormat.RGBA32)
    imgBg.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    local onClick = function()
        play()
    end
    button.onClick:AddListener(onClick)
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
    resetRectTransform(obj, unity.Vector2(0, 0.5), unity.Vector2(0, 0.5), unity.Vector2(64, 0), unity.Vector2(42, 42), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-pause.png", unity.TextureFormat.RGBA32)
    imgBg.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    local onClick = function()
        pause()
    end
    button.onClick:AddListener(onClick)
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
    resetRectTransform(obj, unity.Vector2(1, 0.5), unity.Vector2(1, 0.5), unity.Vector2(-54, 0), unity.Vector2(42, 42), unity.Vector2(0.5,0.5))
    -- 加载图片
    local texture = g_archiveReader:ReadTexture("icon-volume.png", unity.TextureFormat.RGBA32)
    imgBg.texture= texture

    local button = obj:AddComponent(typeof(ugui.Button))
    local onClick = function()
        uiReference.objVolumePanel:SetActive(not uiReference.objVolumePanel.activeSelf)
        volumeClickTimestamp = CS.System.DateTime.UtcNow.Second
    end
    button.onClick:AddListener(onClick)
    table.insert(unbindFunctions, 1, function()
        button.onClick:RemoveAllListeners()
    end)

    uiReference.objVolumeButton = obj
end

-- 创建播放进度
local function addProgressBar()
    local obj = unity.GameObject("sdProgress")
    obj.transform:SetParent(uiReference.objToolbar.transform)
    local slider = buildSlider(obj)
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(-46, 0), unity.Vector2(490, 10), unity.Vector2(0.5,0.5))

    local imgBackground = slider.transform:Find("Background"):GetComponent(typeof(ugui.RawImage))
    imgBackground.texture = g_archiveReader:ReadTexture("progress-bg.png", unity.TextureFormat.RGBA32)
    local imgFill= slider.transform:Find("Fill Area/Fill"):GetComponent(typeof(ugui.RawImage))
    imgFill.texture = g_archiveReader:ReadTexture("progress-fill.png", unity.TextureFormat.RGBA32)
    local imgHandle= slider.transform:Find("Handle Slide Area/Handle"):GetComponent(typeof(ugui.RawImage))
    imgHandle.texture = g_archiveReader:ReadTexture("progress-handle.png", unity.TextureFormat.RGBA32)

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
    resetRectTransform(objPanel, unity.Vector2(1, 0), unity.Vector2(1, 0), unity.Vector2(-586, 230), unity.Vector2(40, 140), unity.Vector2(0.5,0.5))

    -- 加载图片
    local texturePanel = g_archiveReader:ReadTexture("volume-bg.png", unity.TextureFormat.RGBA32)
    imgPanel.texture= texturePanel

    local obj = unity.GameObject("sdVolume")
    obj.transform:SetParent(objPanel.transform)
    local slider = buildSlider(obj)
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(100, 15), unity.Vector2(0.5,0.5))
    local imgBackground = slider.transform:Find("Background"):GetComponent(typeof(ugui.RawImage))
    _, imgBackground.color = unity.ColorUtility.TryParseHtmlString("#656565FF")
    local imgFill= slider.transform:Find("Fill Area/Fill"):GetComponent(typeof(ugui.RawImage))
    _, imgFill.color = unity.ColorUtility.TryParseHtmlString("#EEBD86FF")
    local imgHandle= slider.transform:Find("Handle Slide Area/Handle"):GetComponent(typeof(ugui.RawImage))
    imgHandle.texture = g_archiveReader:ReadTexture("volume-handle.png", unity.TextureFormat.RGBA32)
    resetRectTransform(obj.transform:Find("Fill Area"), unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))

    obj.transform.localRotation = unity.Quaternion.Euler(0,0,90)
    objPanel:SetActive(false)
    slider.value = 1
    local onValueChanged = function(_value)
        uiReference.audioSource.volume = _value
        volumeClickTimestamp = CS.System.DateTime.UtcNow.Second
    end
    slider.onValueChanged:AddListener(onValueChanged)
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
    resetRectTransform(obj, unity.Vector2(1, 0.5), unity.Vector2(1, 0.5), unity.Vector2(-184, 0), unity.Vector2(96, 64), unity.Vector2(0,0.5))
    text.font = G_FONT_MAIN
    text.fontSize = 26
    text.alignment = unity.TextAnchor.MiddleLeft
    text.text = "00:00"
    uiReference.textTime = text
end

-- 创建歌词显示
local function addSubtitleText()
    local obj = unity.GameObject("Subtitle")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local scrollView = buildScrollView(obj)
    uiReference.svContent = scrollView
    scrollView.horizontal = false
    scrollView.vertical = false
    resetRectTransform(obj, unity.Vector2(0.5, 0), unity.Vector2(0.5, 1), unity.Vector2(0, -60), unity.Vector2(864, -520), unity.Vector2(0.5,0.5))

    local content = obj.transform:Find("Viewport/Content")
    local sizeFitter = content.gameObject:AddComponent(typeof(ugui.ContentSizeFitter))
    sizeFitter.verticalFit = ugui.ContentSizeFitter.FitMode.PreferredSize
    local vlg = content.gameObject:AddComponent(typeof(ugui.VerticalLayoutGroup))
    vlg.padding = unity.RectOffset(style.mask_border_left, style.mask_border_right, style.mask_border_top, style.mask_border_bottom)
    vlg.childAlignment = unity.TextAnchor.UpperCenter
    vlg.childForceExpandWidth = true
    vlg.childForceExpandHeight = false
    vlg.childControlWidth = true
    vlg.childControlHeight = true

    local text = unity.GameObject("text"):AddComponent(typeof(ugui.Text))
    text.transform:SetParent(content)
    text.font = G_FONT_MAIN
    text.fontSize = 38
    text.alignment = unity.TextAnchor.MiddleCenter
    local result, color = unity.ColorUtility.TryParseHtmlString(style.text_font_color)
    text.color = color
    text.lineSpacing = 1.2
    text.text = config.Content

    -- 遮罩
    local imgMask = unity.GameObject("Mask"):AddComponent(typeof(ugui.Image))
    imgMask.type = ugui.Image.Type.Sliced
    imgMask.transform:SetParent(obj.transform)
    resetRectTransform(imgMask.gameObject, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))
    local texture = g_archiveReader:ReadTexture("mask.png", unity.TextureFormat.RGBA32)
    local rect = unity.Rect(0, 0, texture.width, texture.height)
    local border = unity.Vector4(style.mask_border_left, style.mask_border_bottom, style.mask_border_right, style.mask_border_top)
    local sprite = g_archiveReader:CreateSprite(texture, rect, border)
    imgMask.sprite = sprite

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
    addAudioSource()
    addBackground()
    addHeader()
    addToolbar()
    addPlayButton()
    addPauseButton()
    addVolumeButton()
    addProgressBar()
    addTimeText()
    addSubtitleText()
    addVolumePanel()
    addLoadingTip()

    -- 异步预读取
    g_preReadSequence = G_API_PROXY.preReadSequence
    g_preReadSequence.OnFinish = function()
        -- 延时1秒
        g_coroutineRunner:StartCoroutine(util.cs_generator(function()
            coroutine.yield(CS.UnityEngine.WaitForSeconds(1))
            uiReference.loadingTip:SetActive(false)
            play()
        end))
    end
    g_preReadSequence:Dial()

    -- 预加载音频
    local preReadAudioCallback = g_archiveReader:NewPreReadCallback()
    preReadAudioCallback.onSuccess = function()
        -- 加载音频
        local audioClip = g_archiveReader:ReadAudioClip("audio.ogg")
        uiReference.audioSource.clip = audioClip
        g_preReadSequence:Tick()
    end
    preReadAudioCallback.onFailure = function()
    end
    table.insert(unbindFunctions, 1, function()
        preReadAudioCallback.onSuccess = nil
        preReadAudioCallback.onFailure = nil
    end)
    g_archiveReader:PreReadAudioClipAsync("audio.ogg", preReadAudioCallback)
end

local function update()
    if CS.System.DateTime.UtcNow.Second > volumeClickTimestamp + 2 then
        if nil ~= uiReference.objVolumePanel then
            uiReference.objVolumePanel:SetActive(false)
        end
    end

    if not isClickHandled then
        uiReference.audioSource.time = uiReference.audioSource.clip.length * uiReference.sliderProgress.value
        uiReference.textTime.text = getLeftTime()
        play()
        isClickHandled = true
        lastestAudioPlayTime = uiReference.audioSource.time
        return
    end

    if false == isPlaying
        then
            return
        end

        uiReference.sliderProgress.value = uiReference.audioSource.time / uiReference.audioSource.clip.length
        uiReference.textTime.text = getLeftTime()
        uiReference.svContent.verticalNormalizedPosition = 1.0 - uiReference.sliderProgress.value

        -- 播放结束的判断
        if not isDraging and isPlaying then
            if uiReference.audioSource.time < lastestAudioPlayTime then
                stop()
            end
            lastestAudioPlayTime = uiReference.audioSource.time
        end
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
