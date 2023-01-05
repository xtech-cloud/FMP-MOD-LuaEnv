local style = require 'style'

local unity = CS.UnityEngine
local ugui = CS.UnityEngine.UI
local uiReference = {}
local isPlaying = false

--- 重置RectTransform
local function resetRectTransform(_target, _anchorMin, _anchorMax, _anchoredPosition, _sizeDelta)
    _target.transform.localPosition = unity.Vector3.zero
    _target.transform.localRotation = unity.Quaternion.identity
    _target.transform.localScale = unity.Vector3.one
    local rectTransform = _target:GetComponent(typeof(unity.RectTransform))
    rectTransform.anchorMin = _anchorMin
    rectTransform.anchorMax = _anchorMax
    rectTransform.anchoredPosition = _anchoredPosition
    rectTransform.sizeDelta = _sizeDelta
end

local function buildSlider(_target)
    local slider = _target:AddComponent(typeof(ugui.Slider))

    local objBackground = unity.GameObject("Background")
    objBackground.transform:SetParent(slider.transform)
    local imgBg = objBackground:AddComponent(typeof(ugui.Image))
    resetRectTransform(objBackground, unity.Vector2(0, 0.25), unity.Vector2(1, 0.75), unity.Vector2(0, 0), unity.Vector2(0, 0))

    local objFillArea = unity.GameObject("Fill Area")
    objFillArea.transform:SetParent(slider.transform)
    objFillArea:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(objFillArea, unity.Vector2(0, 0.25), unity.Vector2(1, 0.75), unity.Vector2(-10, 0), unity.Vector2(-40, 0))

    local objFill = unity.GameObject("Fill")
    objFill.transform:SetParent(objFillArea.transform)
    local imgFill = objFill:AddComponent(typeof(ugui.Image))
    resetRectTransform(objFill, unity.Vector2(0, 0), unity.Vector2(0, 1), unity.Vector2(0, 0), unity.Vector2(20, 0))

    local objHandleSlideArea = unity.GameObject("Handle Slide Area")
    objHandleSlideArea.transform:SetParent(slider.transform)
    objHandleSlideArea:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(objHandleSlideArea, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(-40, 0))

    local objHandle = unity.GameObject("Handle")
    objHandle.transform:SetParent(objHandleSlideArea.transform)
    local imgHandle= objHandle:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objHandle, unity.Vector2(0, 0), unity.Vector2(0, 1), unity.Vector2(0, 0), unity.Vector2(40, 0))

    slider.targetGraphic = imgHandle
    slider.fillRect = objFill:GetComponent(typeof(unity.RectTransform))
    slider.handleRect = objHandle:GetComponent(typeof(unity.RectTransform))

    return slider
end

-- 创建背景
local function addBackground()
    local obj = unity.GameObject("background")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local imgBg = obj:AddComponent(typeof(ugui.Image))
    resetRectTransform(obj, unity.Vector2.zero, unity.Vector2.one, unity.Vector2.zero, unity.Vector2.zero)
    local bytes = G_ARCHIVE_READER:Read("bg.jpg")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGB24, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    local border = unity.Vector4(style.background_border_left, style.background_border_bottom, style.background_border_right, style.background_border_top)
    local sprite = unity.Sprite.Create(texture, unity.Rect(0, 0, texture.width, texture.height), unity.Vector2(0.5, 0.5), 100, 1, unity.SpriteMeshType.Tight, border)
    imgBg.sprite = sprite
end

-- 创建封面
local function addCover()
    local obj = unity.GameObject("cover")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 106), unity.Vector2(512, 512))
    local bytes = G_ARCHIVE_READER:Read("cover.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    imgBg.texture= texture

    uiReference.objCover = obj
end

-- 创建播放按钮
local function addPlayButton()
    local obj = unity.GameObject("btnPlay")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(106, 50), unity.Vector2(64, 64))
    local bytes = G_ARCHIVE_READER:Read("icon-play.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    imgBg.texture= texture
    local button = obj:AddComponent(typeof(ugui.Button))

    button.onClick:AddListener(function()
        uiReference.objPlayButton:SetActive(false)
        uiReference.objPauseButton:SetActive(true)
        isPlaying = true
    end)

    uiReference.objPlayButton = obj
end

-- 创建暂停按钮
local function addPauseButton()
    local obj = unity.GameObject("btnPause")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(106, 50), unity.Vector2(64, 64))
    local bytes = G_ARCHIVE_READER:Read("icon-pause.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    imgBg.texture= texture
    local button = obj:AddComponent(typeof(ugui.Button))

    button.onClick:AddListener(function()
        uiReference.objPlayButton:SetActive(true)
        uiReference.objPauseButton:SetActive(false)
        isPlaying = false
    end)
    obj:SetActive(false)

    uiReference.objPauseButton = obj
end

-- 创建音量按钮
local function addVolumeButton()
    local obj = unity.GameObject("btnVolume")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local imgBg = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(1, 0), unity.Vector2(1, 0), unity.Vector2(-72, 50), unity.Vector2(48, 48))
    local bytes = G_ARCHIVE_READER:Read("icon-volume.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    imgBg.texture= texture
    local button = obj:AddComponent(typeof(ugui.Button))

    button.onClick:AddListener(function()
        uiReference.objVolumePanel:SetActive(not uiReference.objVolumePanel.activeSelf)
    end)

    uiReference.objVolumeButton = obj
end

-- 创建唱按钮
local function addMusicButton()
    local obj = unity.GameObject("btnMusic")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(1, 0), unity.Vector2(1, 0), unity.Vector2(-192, 50), unity.Vector2(98, 38))
    local bytes = G_ARCHIVE_READER:Read("icon-music.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    img.texture= texture
    local button = obj:AddComponent(typeof(ugui.Button))

    button.onClick:AddListener(function()
        uiReference.objMusicButton:SetActive(false)
        uiReference.objAccompanimentButton:SetActive(true)
    end)
    uiReference.objMusicButton = obj
end

-- 创建伴按钮
local function addAccompanimentButton()
    local obj = unity.GameObject("btnAccompaniment")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(obj, unity.Vector2(1, 0), unity.Vector2(1, 0), unity.Vector2(-192, 50), unity.Vector2(98, 38))
    local bytes = G_ARCHIVE_READER:Read("icon-accompaniment.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    img.texture= texture
    local button = obj:AddComponent(typeof(ugui.Button))

    button.onClick:AddListener(function()
        uiReference.objAccompanimentButton:SetActive(false)
        uiReference.objMusicButton:SetActive(true)
    end)

    obj:SetActive(false)
    uiReference.objAccompanimentButton = obj
end

-- 创建播放进度
local function addProgressBar()
    local obj = unity.GameObject("sdProgress")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local slider = buildSlider(obj)
    resetRectTransform(obj, unity.Vector2(0, 0), unity.Vector2(1, 0), unity.Vector2(-120, 53), unity.Vector2(-720, 40))
    local imgBackground = slider.transform:Find("Background"):GetComponent(typeof(ugui.Image))
    imgBackground.color = unity.Color(style.color_primary_dark_r, style.color_primary_dark_g, style.color_primary_dark_b, style.color_primary_dark_a)
    local imgFill= slider.transform:Find("Fill Area/Fill"):GetComponent(typeof(ugui.Image))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    local imgHandle= slider.transform:Find("Handle Slide Area/Handle"):GetComponent(typeof(ugui.RawImage))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    local bytes = G_ARCHIVE_READER:Read("handle.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    imgHandle.texture= texture

    uiReference.objProgressSlider = obj
end

-- 创建音量大小
local function addVolumePanel()
    local objPanel = unity.GameObject("panelVolume")
    objPanel.transform:SetParent(G_SLOT_UI.transform)
    local imgPanel = objPanel:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objPanel, unity.Vector2(1, 0), unity.Vector2(1, 0), unity.Vector2(-72, 240), unity.Vector2(80, 259))
    local bytesPanel = G_ARCHIVE_READER:Read("panel-volume.png")
    local texturePanel = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texturePanel, bytesPanel)
    imgPanel.texture= texturePanel

    local obj = unity.GameObject("sdVolume")
    obj.transform:SetParent(objPanel.transform)
    local slider = buildSlider(obj)
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(240, 40))
    local imgBackground = slider.transform:Find("Background"):GetComponent(typeof(ugui.Image))
    imgBackground.color = unity.Color(style.color_primary_dark_r, style.color_primary_dark_g, style.color_primary_dark_b, style.color_primary_dark_a)
    local imgFill= slider.transform:Find("Fill Area/Fill"):GetComponent(typeof(ugui.Image))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    local imgHandle= slider.transform:Find("Handle Slide Area/Handle"):GetComponent(typeof(ugui.RawImage))
    imgFill.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    local bytes = G_ARCHIVE_READER:Read("handle.png")
    local texture = unity.Texture2D(10, 10, unity.TextureFormat.RGBA32, false)
    unity.ImageConversion.LoadImage(texture, bytes)
    imgHandle.texture= texture

    obj.transform.localRotation = unity.Quaternion.Euler(0,0,90)
    objPanel:SetActive(false)
    uiReference.objVolumePanel = objPanel
end

-- 创建时间显示
local function addTimeText()
    local obj = unity.GameObject("txtTime")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local text = obj:AddComponent(typeof(ugui.Text))
    resetRectTransform(obj, unity.Vector2(1, 0), unity.Vector2(1, 0), unity.Vector2(-400, 52), unity.Vector2(120, 64))
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
    resetRectTransform(obj, unity.Vector2(0, 0), unity.Vector2(1, 0), unity.Vector2(0, 243), unity.Vector2(-64, 240))
    text.font = G_FONT_MAIN
    text.fontSize = 64
    text.alignment = unity.TextAnchor.MiddleCenter
    text.color = unity.Color(style.color_primary_light_r, style.color_primary_light_g, style.color_primary_light_b, style.color_primary_light_a)
    uiReference.textSubtitle = text
end

local function bindPlayEvents(_slider)
    local eventTrigger = _slider.gameObject:AddComponent(typeof(unity.EventSystems.EventTrigger))
    -- 创建开始拖拽事件
    local entryBeginDrag = unity.EventSystems.EventTrigger.Entry()
    entryBeginDrag.eventID = unity.EventSystems.EventTriggerType.BeginDrag
    entryBeginDrag.callback:AddListener(function(_e)
        view.audioSource:Pause()
        play = false
    end)
    eventTrigger.triggers:Add(entryBeginDrag)

    -- 创建结束拖拽事件
    local entryEndDrag = unity.EventSystems.EventTrigger.Entry()
    entryEndDrag.eventID = unity.EventSystems.EventTriggerType.EndDrag
    entryEndDrag.callback:AddListener(function(_e)
        view.audioSource:Play()
        play = true
    end)
    eventTrigger.triggers:Add(entryEndDrag)

    -- 创建拖拽时事件
    local entryDrag = unity.EventSystems.EventTrigger.Entry()
    entryDrag.eventID = unity.EventSystems.EventTriggerType.Drag
    entryDrag.callback:AddListener(function(_e)
        view.audioSource.time = view.audioSource.clip.length * view.progress.value
        view.txtTime.text = getLeftTime()
    end)
    eventTrigger.triggers:Add(entryDrag)

      -- 创建点击事件
    local entryClick = unity.EventSystems.EventTrigger.Entry()
    entryClick.eventID = unity.EventSystems.EventTriggerType.PointerClick
    entryClick.callback:AddListener(function(_e)
        view.audioSource.time = view.audioSource.clip.length * view.progress.value
        view.txtTime.text = getLeftTime()
    end)
    eventTrigger.triggers:Add(entryClick)
end

local function unbindPlayEvents(_slider)
    local eventTrigger = _slider.gameObject:GetComponent(typeof(unity.EventSystems.EventTrigger))
    eventTrigger.triggers:RemoveAll()
end

local function addMusicSource()
    local obj = unity.GameObject("music")
    obj.transform:SetParent(G_SLOT_UI.transform)
    obj:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(0, 0))
    local source = obj:AddComponent(typeof(unity.AudioSource))
    source.playOnAwake = false
    uiReference.musicSource = source
end

local function addAccompanimentSource()
    local obj = unity.GameObject("accompaniment")
    obj.transform:SetParent(G_SLOT_UI.transform)
    obj:AddComponent(typeof(unity.RectTransform))
    resetRectTransform(obj, unity.Vector2(0.5, 0.5), unity.Vector2(0.5, 0.5), unity.Vector2(0, 0), unity.Vector2(0, 0))
    local source = obj:AddComponent(typeof(unity.AudioSource))
    source.playOnAwake = false
    uiReference.accompanimentSource = source
end

local function run()
    addBackground()
    addCover()
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
end

return {
    Run = run,
}
