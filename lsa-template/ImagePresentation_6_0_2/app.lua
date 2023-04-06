local util = require 'xlua.util'
local style = require 'style'
local config = require 'config'
local unityUtilities = require 'unityUtilities'
local unity = CS.UnityEngine
local ugui = CS.UnityEngine.UI
local g_archiveReader = G_API_PROXY.archiveReader
local g_preReadSequence = G_API_PROXY.preReadSequence
local g_coroutineRunner = G_RUNNER_COROUTINE

local uiReference = {
    rtSlot = nil,
    rtContainerRoot = nil, -- 图片的容器的根对象
    rtContainerContent = nil, -- 图片的容器的内容
    imgViewer = nil, -- 图片浏览器
    rtToolbar = nil, -- 工具栏
    cellToggles = {}, -- 图片按钮列表
    objButtonList = nil, -- 列表按钮
}
-- 解绑事件的数组
local unbindFunctions = {}
-- 加载的协程
local loadCoroutine = nil
-- 当前的图片序号
local currentIndex = 1
-- 边栏容器的原始大小
local originContainerSizeDelta = nil
-- 自动隐藏列表的时间戳
local listClickTimestamp = 0

local function resetScale(_target)
    _target.transform.localScale = unity.Vector3.one
end

local function viewImage(_texture, _cell, _index)
    uiReference.imgViewer.texture = _texture
    -- 适配图片大小与控件等高或等宽
    local fitWidth = _texture.width
    local fitHeight = _texture.height
    local rtParent =  uiReference.imgViewer.transform.parent:GetComponent(typeof(unity.RectTransform))
    -- 以宽高比作为比较
    if rtParent.rect.width/rtParent.rect.height > _texture.width/_texture.height then
        -- 控件的宽高比大于图片的宽高比，适配高度
        fitHeight = rtParent.rect.height
        fitWidth = _texture.width/_texture.height * fitHeight
    else
        -- 控件的宽高比小于图片的宽高比，适配宽度
        fitWidth = rtParent.rect.width
        fitHeight = _texture.height/_texture.width * fitWidth
    end
    unityUtilities.ResetRectTransform(uiReference.imgViewer.gameObject, unity.Vector2(0.5, 0.5), unity.Vector2(0.5,0.5), unity.Vector2(0, 0), unity.Vector2(fitWidth, fitHeight), unity.Vector2(0.5,0.5))
end

-- 创建背景
local function addBackground()
    local obj = unity.GameObject("background")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    unityUtilities.ResetRectTransform(obj, unity.Vector2.zero, unity.Vector2.one, unity.Vector2.zero, unity.Vector2.zero, unity.Vector2(0.5,0.5))
    -- 加载图片
    img.color = unity.Color(style.background_color_r, style.background_color_g, style.background_color_b, style.background_color_a)
end

-- 创建图片滚动容器
local function addScrollContainer()
    local obj = unity.GameObject("ScrollView")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local scrollView = unityUtilities.BuildScrollView(obj)
    uiReference.rtContainerRoot = obj:GetComponent(typeof(unity.RectTransform))
    -- 设置背景
    local imgBackground = scrollView.gameObject:AddComponent(typeof(ugui.RawImage))
    imgBackground.color = unity.Color(style.container_background_color_r
    , style.container_background_color_g
    , style.container_background_color_b
    , style.container_background_color_a
    )
    -- 设置togglegroup
    uiReference.rtContainerContent  = obj.transform:Find("Viewport/Content"):GetComponent(typeof(unity.RectTransform))
    uiReference.rtContainerContent.gameObject:AddComponent(typeof(ugui.ToggleGroup))

    -- BEGIN 进度提示 [[
    local progressPanel = unity.GameObject("Progress")
    local imgProgress = progressPanel:AddComponent(typeof(ugui.RawImage))
    progressPanel.transform:SetParent(G_SLOT_UI.transform)
    unityUtilities.ResetRectTransform(progressPanel, unity.Vector2(1,0), unity.Vector2(1,0), unity.Vector2(-12,12), unity.Vector2(100,100), unity.Vector2(1,0))
    local texture = g_archiveReader:ReadTexture("progress.png",unity.TextureFormat.RGBA32)
    imgProgress.texture = texture
    local progressText = unity.GameObject("Text")
    local textProgress = progressText:AddComponent(typeof(ugui.Text))
    textProgress.font = G_FONT_MAIN
    textProgress.lineSpacing = 1.2
    textProgress.fontSize = style.progress_font_size
    textProgress.alignment = unity.TextAnchor.MiddleCenter
    progressText.transform:SetParent(progressPanel.transform)
    unityUtilities.ResetRectTransform(progressText
    , unity.Vector2(0,0)
    , unity.Vector2(1,1)
    , unity.Vector2(0,0)
    , unity.Vector2(0,0)
    , unity.Vector2(1,0.5)
    )
    -- ]] END 进度提示

    -- 适配图片的函数
    local fitImageSizeFunc = nil

    -- 横竖屏处理
    local slotSize = unityUtilities.GetUiSlotSize()
    if  slotSize.x > slotSize.y then -- 横屏
        scrollView.horizontal = false
        scrollView.vertical = true
        -- 设置Content的布局
        local objContent = obj.transform:Find("Viewport/Content").gameObject
        unityUtilities.ResetRectTransform(obj, unity.Vector2(1,0), unity.Vector2(1,1), unity.Vector2(0,0), unity.Vector2(style.container_width,0), unity.Vector2(1,0.5))
        unityUtilities.ResetRectTransform(objContent, unity.Vector2(0,1), unity.Vector2(1,1), unity.Vector2(0,0), unity.Vector2(0,0), unity.Vector2(0,1))
        local sizeFitter = objContent:AddComponent(typeof(ugui.ContentSizeFitter))
        sizeFitter.verticalFit = ugui.ContentSizeFitter.FitMode.PreferredSize
        local vlg = uiReference.rtContainerContent.gameObject:AddComponent(typeof(ugui.VerticalLayoutGroup))
        vlg.childForceExpandWidth = false
        vlg.childForceExpandHeight = false
        vlg.childControlWidth = false
        vlg.childControlHeight = false
        vlg.childAlignment = unity.TextAnchor.UpperCenter
        vlg.spacing = style.container_layout_spacing
        vlg.padding = unity.RectOffset(style.container_layout_padding_left
        , style.container_layout_padding_right
        , style.container_layout_padding_top
        , style.container_layout_padding_bottom
        )
        -- 实现图片适配函数
        fitImageSizeFunc = function(_cell, _width, _height)
            local fitWidth = style.container_width - style.container_layout_padding_left - style.container_layout_padding_right
            local fitHeight = _height/_width*fitWidth
            -- 缩放图片
            _cell:GetComponent(typeof(unity.RectTransform)).sizeDelta = unity.Vector2(fitWidth, fitHeight)
        end
    else -- 竖屏
        scrollView.horizontal = true
        scrollView.vertical = false
        -- 设置Content的布局
        local objContent = obj.transform:Find("Viewport/Content").gameObject
        unityUtilities.ResetRectTransform(obj, unity.Vector2(0, 0), unity.Vector2(1,0), unity.Vector2(0,0), unity.Vector2(0, style.container_height), unity.Vector2(0.5, 0))
        unityUtilities.ResetRectTransform(objContent, unity.Vector2(0, 0), unity.Vector2(0,1), unity.Vector2(0,0), unity.Vector2(0,0), unity.Vector2(0,0))
        local sizeFitter = objContent:AddComponent(typeof(ugui.ContentSizeFitter))
        sizeFitter.horizontalFit = ugui.ContentSizeFitter.FitMode.PreferredSize
        local hlg = uiReference.rtContainerContent.gameObject:AddComponent(typeof(ugui.HorizontalLayoutGroup))
        hlg.childForceExpandWidth = false
        hlg.childForceExpandHeight = false
        hlg.childControlWidth = false
        hlg.childControlHeight = false
        hlg.childAlignment = unity.TextAnchor.UpperCenter
        hlg.spacing = style.container_layout_spacing
        hlg.padding = unity.RectOffset(style.container_layout_padding_left
        , style.container_layout_padding_right
        , style.container_layout_padding_top
        , style.container_layout_padding_bottom
        )
        -- 实现图片适配函数
        fitImageSizeFunc = function(_cell, _width, _height)
            local fitHeight = style.container_height - style.container_layout_padding_top - style.container_layout_padding_bottom
            local fitWidth = _width/_height*fitHeight
            -- 缩放图片
            _cell:GetComponent(typeof(unity.RectTransform)).sizeDelta = unity.Vector2(fitWidth, fitHeight)
        end
    end

    loadCoroutine = util.cs_generator(function()
        progressPanel:SetActive(true)
        for i = 1,config.Count do
            coroutine.yield(unity.WaitForEndOfFrame())
            -- 创建相片节点
            local cell = unity.GameObject("cell")
            local toggle = unityUtilities.BuildToggle(cell)
            table.insert(uiReference.cellToggles, toggle)
            cell.transform:SetParent(uiReference.rtContainerContent.transform)
            resetScale(cell)
            -- 读取图片
            local texture = g_archiveReader:ReadTexture("images/img#"..i..".jpg", unity.TextureFormat.RGB24)
            local tBackground = cell.transform:Find("Background")
            -- 将背景提到Mark上层
            tBackground:SetAsLastSibling()
            tBackground:GetComponent(typeof(ugui.RawImage)).texture = texture
            fitImageSizeFunc(cell, texture.width, texture.height)
            textProgress.text = i .. "\n" .. config.Count
            -- 应用节点颜色和边框粗细
            local tCheckmark = cell.transform:Find("Checkmark")
            tCheckmark:GetComponent(typeof(unity.RectTransform)).sizeDelta = unity.Vector2(style.cell_selected_border_size*2, style.cell_selected_border_size*2)
            tCheckmark:GetComponent(typeof(ugui.RawImage)).color = unity.Color(style.cell_selected_color_r
            , style.cell_selected_color_g
            , style.cell_selected_color_b
            , style.cell_selected_color_a
            )
            -- 点击事件
            toggle.group = uiReference.rtContainerContent:GetComponent(typeof(ugui.ToggleGroup))
            local onValueChanged = function(_toggled)
                if not _toggled then
                    return
                end
                currentIndex = i
                viewImage(texture, cell, i)
            end
            toggle.onValueChanged:AddListener(onValueChanged)
            table.insert(unbindFunctions, 1, function()
                toggle.onValueChanged:RemoveAllListeners()
            end)
            if nil == uiReference.imgViewer.texture then
                toggle.isOn = true
            end
        end
        progressPanel:SetActive(false)
        loadCoroutine = nil
    end)


    originContainerSizeDelta = uiReference.rtContainerRoot.sizeDelta
    -- 使用缩放代替SetActive，避免toggle不处理事件
    uiReference.rtContainerRoot.sizeDelta = unity.Vector2(0, 0)
    -- 执行协程，开始加载
    g_coroutineRunner:StartCoroutine(loadCoroutine)
end

local function addViewer()
    local obj = unity.GameObject("Viewer")
    obj.transform:SetParent(G_SLOT_UI.transform)
    uiReference.imgViewer = obj:AddComponent(typeof(ugui.RawImage))
    local btn = obj:AddComponent(typeof(ugui.Button))

    local onClick = function()
        uiReference.rtToolbar.gameObject:SetActive(not uiReference.rtToolbar.gameObject.activeSelf)
    end
    btn.onClick:AddListener(onClick)
    table.insert(unbindFunctions, 1, function()
        btn.onClick:RemoveAllListeners()
    end)


end

local function addToolbar()
    local objToolbar = unity.GameObject("Toolbar")
    objToolbar.transform:SetParent(G_SLOT_UI.transform)
    uiReference.rtToolbar = objToolbar:AddComponent(typeof(unity.RectTransform))
    unityUtilities.ResetRectTransform(objToolbar
    ,unity.Vector2(0.5 ,0.5)
    ,unity.Vector2(0.5 ,0.5)
    ,unity.Vector2(0, -uiReference.rtSlot.rect.height/2+64)
    ,unity.Vector2(0, 0)
    ,unity.Vector2(0.5, 0.5)
    )

    -- 上一页按钮
    local objPrev = unity.GameObject("btnPrev")
    objPrev.transform:SetParent(objToolbar.transform)
    local imgPrev = objPrev:AddComponent(typeof(ugui.RawImage))
    unityUtilities.ResetRectTransform(objPrev
    ,unity.Vector2(1 ,0.5)
    ,unity.Vector2(1 ,0.5)
    ,unity.Vector2(0, 0)
    ,unity.Vector2(96, 64)
    ,unity.Vector2(1, 0.5)
    )
    local texturePrev = g_archiveReader:ReadTexture("toolbar_prev.png", unity.TextureFormat.RGBA32)
    imgPrev.texture = texturePrev
    -- 绑定事件
    local btnPrev = objPrev:AddComponent(typeof(ugui.Button))
    local onPrevClick = function()
        if currentIndex <= 1 then
            currentIndex = 1
            return
        end
        currentIndex = currentIndex - 1
        uiReference.cellToggles[currentIndex].isOn = true
    end
    btnPrev.onClick:AddListener(onPrevClick)
    table.insert(unbindFunctions, 1, function()
        btnPrev.onClick:RemoveAllListeners()
    end)

    -- 下一页按钮
    local objNext = unity.GameObject("btnNext")
    objNext.transform:SetParent(objToolbar.transform)
    local imgNext = objNext:AddComponent(typeof(ugui.RawImage))
    unityUtilities.ResetRectTransform(objNext
    ,unity.Vector2(0, 0.5)
    ,unity.Vector2(0, 0.5)
    ,unity.Vector2(0, 0)
    ,unity.Vector2(96, 64)
    ,unity.Vector2(0, 0.5)
    )
    local textureNext= g_archiveReader:ReadTexture("toolbar_next.png", unity.TextureFormat.RGBA32)
    imgNext.texture = textureNext
    -- 绑定事件
    local btnNext = objNext:AddComponent(typeof(ugui.Button))
    local onNextClick = function()
        if currentIndex >= config.Count then
            currentIndex = config.Count
            return
        end
        currentIndex = currentIndex + 1
        uiReference.cellToggles[currentIndex].isOn = true
    end
    btnNext.onClick:AddListener(onNextClick)
    table.insert(unbindFunctions, 1, function()
        btnNext.onClick:RemoveAllListeners()
    end)

    -- 列表按钮
    local objList = unity.GameObject("btnList")
    uiReference.objButtonList = objList
    objList:SetActive(false)
    objList.transform:SetParent(objToolbar.transform)
    local imgList = objList:AddComponent(typeof(ugui.RawImage))
    unityUtilities.ResetRectTransform(objList
    ,unity.Vector2(0.5 ,0.5)
    ,unity.Vector2(0.5 ,0.5)
    ,unity.Vector2(0, 60)
    ,unity.Vector2(48, 48)
    ,unity.Vector2(0.5, 0.5)
    )
    local textureList = g_archiveReader:ReadTexture("toolbar_list.png", unity.TextureFormat.RGBA32)
    imgList.texture = textureList
    -- 绑定事件
    local btnList = objList:AddComponent(typeof(ugui.Button))
    local onListClick = function()
        if uiReference.rtContainerRoot.sizeDelta == unity.Vector2.zero then
            uiReference.rtContainerRoot.sizeDelta = originContainerSizeDelta
        else
            uiReference.rtContainerRoot.sizeDelta = unity.Vector2.zero
        end
    end
    btnList.onClick:AddListener(onListClick)
    table.insert(unbindFunctions, 1, function()
        btnList.onClick:RemoveAllListeners()
    end)

    -- 拖动按钮
    local objDrag = unity.GameObject("btnDrag")
    objDrag.transform:SetParent(objToolbar.transform)
    local imgDrag = objDrag:AddComponent(typeof(ugui.RawImage))
    unityUtilities.ResetRectTransform(objDrag
    ,unity.Vector2(0.5 ,0.5)
    ,unity.Vector2(0.5 ,0.5)
    ,unity.Vector2(0, 0)
    ,unity.Vector2(64, 64)
    ,unity.Vector2(0.5, 0.5)
    )
    local textureDrag = g_archiveReader:ReadTexture("toolbar_drag.png", unity.TextureFormat.RGBA32)
    imgDrag.texture = textureDrag

    -- 绑定事件
    local eventTrigger = objDrag:AddComponent(typeof(unity.EventSystems.EventTrigger))
    -- 创建开始拖拽事件
    local entryBeginDrag = unity.EventSystems.EventTrigger.Entry()
    entryBeginDrag.eventID = unity.EventSystems.EventTriggerType.BeginDrag
    local onBegin = function(_e)
        isDraging = true
    end
    entryBeginDrag.callback:AddListener(onBegin)
    table.insert(unbindFunctions, 1, function()
        entryBeginDrag.callback:RemoveAllListeners()
    end)
    eventTrigger.triggers:Add(entryBeginDrag)
    -- 创建结束拖拽事件
    local entryEndDrag = unity.EventSystems.EventTrigger.Entry()
    entryEndDrag.eventID = unity.EventSystems.EventTriggerType.EndDrag
    local onEnd = function(_e)
        isDraging = false
    end
    entryEndDrag.callback:AddListener(onEnd)
    table.insert(unbindFunctions, 1, function()
        entryEndDrag.callback:RemoveAllListeners()
    end)
    eventTrigger.triggers:Add(entryEndDrag)
    -- 创建拖拽时事件
    local entryDrag = unity.EventSystems.EventTrigger.Entry()
    entryDrag.eventID = unity.EventSystems.EventTriggerType.Drag
    local onDrag = function(_e)
        local result, position = unity.RectTransformUtility.ScreenPointToLocalPointInRectangle(uiReference.rtSlot, _e.position, _e.enterEventCamera)
        local slotWidth = uiReference.rtSlot.rect.width
        local slotHeight = uiReference.rtSlot.rect.height
        local isInRect = position.x >= -slotWidth/2 and position.x <= slotWidth/2 and position.y <= slotHeight/2 and position.y >= -slotHeight/2
        if not isInRect then
            return
        end
        uiReference.rtToolbar.anchoredPosition = position
    end
    entryDrag.callback:AddListener(onDrag)
    table.insert(unbindFunctions, 1, function()
        entryDrag.callback:RemoveAllListeners()
    end)
    eventTrigger.triggers:Add(entryDrag)
    -- 创建按下事件
    -- 不能使用PointerClick，PointerClick是在按键松开后才触发，无法在Update前执行
    local entryDown = unity.EventSystems.EventTrigger.Entry()
    entryDown.eventID = unity.EventSystems.EventTriggerType.PointerDown
    local onClick = function(_e)
        uiReference.objButtonList:SetActive(true)
        listClickTimestamp = CS.System.DateTime.UtcNow.Second
    end
    entryDown.callback:AddListener(onClick)
    table.insert(unbindFunctions, 1, function()
        entryDown.callback:RemoveAllListeners()
    end)
    eventTrigger.triggers:Add(entryDown)
end

local function run()
    uiReference.rtSlot = G_SLOT_UI:GetComponent(typeof(unity.RectTransform))
    addBackground()
    addViewer()
    addScrollContainer()
    addToolbar()
end

local function update()
    if listClickTimestamp ~= nil then
        if CS.System.DateTime.UtcNow.Second > listClickTimestamp + 3 then
            uiReference.objButtonList:SetActive(false)
            listClickTimestamp = nil
        end
    end
end

local function stop()
    -- 结束正在加载的协程
    if nil ~= loadCoroutine then
        g_coroutineRunner:StopCoroutine(loadCoroutine)
    end
    -- 注销所有回调，避免抛出异常
    -- 绑定事件时务必使用函数变量
    for i,v in ipairs(unbindFunctions) do
        v()
    end
end

return {
    Run = run,
    Update = update,
    Stop = stop,
}
