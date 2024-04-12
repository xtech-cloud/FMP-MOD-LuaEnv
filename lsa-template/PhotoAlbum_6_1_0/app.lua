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
    objDescription = nil,
    imgViewer = nil,
    rtCellSelected = nil,
    slider = nil,
    rtContainerContent = nil,
    rtCellSelected = nil,
    tgDescription = nil,
}
-- 解绑事件的数组
local unbindFunctions = {}
-- 加载的协程
local loadCoroutine = nil
-- 浏览器原始尺寸
local viewerOriginSize = unity.Vector2.zero

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

local function viewPhoto(_texture, _cell, _index)
    uiReference.imgViewer.texture = _texture
    -- 适配图片大小到控件内
    local fitWidth = _texture.width
    local fitHeight = _texture.height
    local rtParent =  uiReference.imgViewer.transform.parent:GetComponent(typeof(unity.RectTransform))
    -- 以宽高比作为比较
    if rtParent.rect.width/rtParent.rect.height > _texture.width/_texture.height then
        -- 控件的宽高比大于图片的宽高比，适配高度，并且不处理比控件小的图片
        if rtParent.rect.height < _texture.height then
            fitHeight = rtParent.rect.height
            fitWidth = _texture.width/_texture.height * fitHeight
        end
    else
        -- 控件的宽高比小于图片的宽高比，适配宽度，并且不处理比控件小的图片
        if rtParent.rect.width < _texture.width then
            fitWidth = rtParent.rect.width
            fitHeight = _texture.height/_texture.width * fitWidth
        end
    end
    unityUtilities.ResetRectTransform(uiReference.imgViewer.gameObject, unity.Vector2(0.5, 0.5), unity.Vector2(0.5,0.5), unity.Vector2(0, 0), unity.Vector2(fitWidth, fitHeight), unity.Vector2(0.5,0.5))
    viewerOriginSize = unity.Vector2(fitWidth, fitHeight)
    -- 显示选中提示
    local rtCell = _cell:GetComponent(typeof(unity.RectTransform))
    uiReference.rtCellSelected.anchoredPosition = rtCell.anchoredPosition
    uiReference.rtCellSelected.sizeDelta = unity.Vector2( rtCell.sizeDelta.x + style.cell_selected_border_size*2, rtCell.sizeDelta.y + style.cell_selected_border_size*2)
    -- 重置缩放条
    uiReference.slider.value = 1
    -- 显示描述
    local textDescription = config.Desc["img#".._index..".jpg"]["en_US"]
    uiReference.objDescription.transform:Find("Text"):GetComponent(typeof(ugui.Text)).text = textDescription
    uiReference.objDescription:SetActive(uiReference.tgDescription.isOn and "" ~= textDescription)
    uiReference.tgDescription.gameObject:SetActive(""~=textDescription)
end

-- 创建背景
local function addBackground()
    local obj = unity.GameObject("background")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local img = obj:AddComponent(typeof(ugui.RawImage))
    unityUtilities.ResetRectTransform(obj, unity.Vector2.zero, unity.Vector2.one, unity.Vector2.zero, unity.Vector2.zero, unity.Vector2(0.5,0.5))
    img.color = unity.Color(style.background_color_r, style.background_color_g, style.background_color_b, style.background_color_a)
end

-- 创建相片滚动容器
local function addScrollContainer()
    local obj = unity.GameObject("ScrollView")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local scrollView = unityUtilities.BuildScrollView(obj)
    uiReference.rtContainerContent  = obj.transform:Find("Viewport/Content"):GetComponent(typeof(unity.RectTransform))
    uiReference.rtContainerContent.gameObject:AddComponent(typeof(ugui.ToggleGroup))

    -- 进度提示
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

    -- 选中提示
    local cellSelected = unity.GameObject("selected")
    local imageSelected = cellSelected:AddComponent(typeof(ugui.RawImage))
    cellSelected.transform:SetParent(uiReference.rtContainerContent.transform)
    imageSelected.color = unity.Color(style.cell_selected_color_r
    , style.cell_selected_color_g
    , style.cell_selected_color_b
    , style.cell_selected_color_a
    )
    uiReference.rtCellSelected = cellSelected:GetComponent(typeof(unity.RectTransform))

    -- 节点的矫正函数
    local adjustCellFunc = nil
    -- 节点的定位器
    local anchor = {
        pipeCenter = {}, -- 流道的中心坐标
        pipeEdge = {}, -- 流道的边缘坐标
        pipeMinIndex = 0,  -- 流道边缘坐标最小的序号
        pipeMaxIndex = 0,  -- 流道边缘坐标最大的序号
        cellIndex = 0, -- 节点的序号，从0开始
        textureWidth = 0, -- 纹理的宽度
        textureHeight = 0, -- 纹理的高度
        cellObject = nil, -- 节点的对象
    }

    -- 横竖屏处理
    local slotSize = unityUtilities.GetUiSlotSize()
    if  slotSize.x > slotSize.y then -- 横屏
        scrollView.horizontal = false
        scrollView.vertical = true
        unityUtilities.ResetRectTransform(obj, unity.Vector2(1,0), unity.Vector2(1,1), unity.Vector2(0,0), unity.Vector2(style.container_width,0), unity.Vector2(1,0.5))
        unityUtilities.ResetRectTransform(obj.transform:Find("Viewport/Content").gameObject, unity.Vector2(0,1), unity.Vector2(1,1), unity.Vector2(0,0), unity.Vector2(0,0), unity.Vector2(0,1))
        unityUtilities.ResetRectTransform(uiReference.rtCellSelected.gameObject, unity.Vector2(0.5, 1), unity.Vector2(0.5, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5,0.5))
        -- 计算流道的宽度
        anchor.pipeSize = (style.container_width - style.cell_margin*2 - (style.cell_roworcolumn-1) * style.cell_spacing) / style.cell_roworcolumn
        for i = 0, style.cell_roworcolumn-1 do
            anchor.pipeCenter[i] =  style.cell_margin + i*style.cell_spacing + i*anchor.pipeSize + anchor.pipeSize/2 - style.container_width/2
            anchor.pipeEdge[i] = -style.cell_margin
        end
        adjustCellFunc = function(_anchor)
            local cell_width = _anchor.pipeSize
            local cell_height = _anchor.textureHeight/_anchor.textureWidth*cell_width
            local posX = _anchor.pipeCenter[_anchor.pipeMinIndex]
            local posY = _anchor.pipeEdge[_anchor.pipeMinIndex] - cell_height/2
            unityUtilities.ResetRectTransform(_anchor.cellObject, unity.Vector2(0.5, 1), unity.Vector2(0.5, 1), unity.Vector2(posX, posY), unity.Vector2(cell_width, cell_height), unity.Vector2(0.5,0.5))
            _anchor.pipeEdge[_anchor.pipeMinIndex] = _anchor.pipeEdge[_anchor.pipeMinIndex] - cell_height - style.cell_spacing
            -- 重新计算最小和最大边缘序号
            for i = 0, style.cell_roworcolumn-1 do
                if math.abs(_anchor.pipeEdge[i]) < math.abs(_anchor.pipeEdge[_anchor.pipeMinIndex]) then
                    _anchor.pipeMinIndex = i
                end
                if math.abs(_anchor.pipeEdge[i]) > math.abs(_anchor.pipeEdge[_anchor.pipeMaxIndex]) then
                    _anchor.pipeMaxIndex = i
                end
            end
            uiReference.rtContainerContent.sizeDelta = unity.Vector2(0, math.abs(_anchor.pipeEdge[_anchor.pipeMaxIndex]))
        end
    else -- 竖屏
        scrollView.horizontal = true
        scrollView.vertical = false
        unityUtilities.ResetRectTransform(obj, unity.Vector2(0,0), unity.Vector2(1,0), unity.Vector2(0,0), unity.Vector2(0, style.container_height), unity.Vector2(0.5, 0))
        unityUtilities.ResetRectTransform(obj.transform:Find("Viewport/Content").gameObject, unity.Vector2(0,0), unity.Vector2(0,1), unity.Vector2(0,0), unity.Vector2(0,0), unity.Vector2(0,1))
        unityUtilities.ResetRectTransform(uiReference.rtCellSelected.gameObject, unity.Vector2(0, 0.5), unity.Vector2(0, 0.5), unity.Vector2(0, 0), unity.Vector2(0,0), unity.Vector2(0.5,0.5))
        -- 计算流道的高度
        anchor.pipeSize = (style.container_height - style.cell_margin*2 - (style.cell_roworcolumn-1) * style.cell_spacing) / style.cell_roworcolumn
        for i = 0, style.cell_roworcolumn-1 do
            anchor.pipeCenter[i] =  style.cell_margin + i*style.cell_spacing + i*anchor.pipeSize + anchor.pipeSize/2 - style.container_height/2
            anchor.pipeEdge[i] = style.cell_margin
        end
        adjustCellFunc = function(_anchor)
            local cell_height = _anchor.pipeSize
            local cell_width = _anchor.textureWidth/_anchor.textureHeight * cell_height
            local posX = _anchor.pipeEdge[_anchor.pipeMinIndex] + cell_width/2
            local posY = _anchor.pipeCenter[_anchor.pipeMinIndex]
            unityUtilities.ResetRectTransform(_anchor.cellObject, unity.Vector2(0, 0.5), unity.Vector2(0, 0.5), unity.Vector2(posX, posY), unity.Vector2(cell_width, cell_height), unity.Vector2(0.5,0.5))
            _anchor.pipeEdge[_anchor.pipeMinIndex] = _anchor.pipeEdge[_anchor.pipeMinIndex] + cell_width + style.cell_spacing
            -- 重新计算最小和最大边缘序号
            for i = 0, style.cell_roworcolumn-1 do
                if math.abs(_anchor.pipeEdge[i]) < math.abs(_anchor.pipeEdge[_anchor.pipeMinIndex]) then
                    _anchor.pipeMinIndex = i
                end
                if math.abs(_anchor.pipeEdge[i]) > math.abs(_anchor.pipeEdge[_anchor.pipeMaxIndex]) then
                    _anchor.pipeMaxIndex = i
                end
            end
            uiReference.rtContainerContent.sizeDelta = unity.Vector2(math.abs(_anchor.pipeEdge[_anchor.pipeMaxIndex]), 0)
        end
    end

    loadCoroutine = util.cs_generator(function()
        progressPanel:SetActive(true)
        for i = 1,config.Count do
            coroutine.yield(unity.WaitForEndOfFrame())
            anchor.cellIndex = i-1
            -- 创建相片节点
            local cell = unity.GameObject("cell")
            local image = cell:AddComponent(typeof(ugui.RawImage))
            cell.transform:SetParent(uiReference.rtContainerContent.transform)
            anchor.cellObject = cell
            -- 读取图片
            local texture = g_archiveReader:ReadTexture("images/img#"..i..".jpg", unity.TextureFormat.RGB24)
            image.texture = texture
            anchor.textureWidth = texture.width
            anchor.textureHeight = texture.height
            adjustCellFunc(anchor)
            textProgress.text = i .. "\n" .. config.Count
            -- 点击事件
            local toggle = cell:AddComponent(typeof(ugui.Toggle))
            toggle.group = uiReference.rtContainerContent:GetComponent(typeof(ugui.ToggleGroup))
            local onToggleValueChanged = function(_toggled)
                if not _toggled then
                    return
                end
                viewPhoto(texture, cell, i)
            end
            toggle.onValueChanged:AddListener(onToggleValueChanged)
            table.insert(unbindFunctions, 1, function()
                toggle.onValueChanged:RemoveAllListeners()
            end)
            if nil == uiReference.imgViewer.texture then
                viewPhoto(texture, cell, i)
            end
        end
        progressPanel:SetActive(false)
        loadCoroutine = nil
    end)

    -- 执行协程，开始加载
    g_coroutineRunner:StartCoroutine(loadCoroutine)
end

local function addViewer()
    local obj = unity.GameObject("Viewer")
    obj.transform:SetParent(G_SLOT_UI.transform)
    local scrollView = unityUtilities.BuildScrollView(obj)
    local slotSize = unityUtilities.GetUiSlotSize()
    -- 横竖屏处理
    if  slotSize.x > slotSize.y then -- 横屏
        unityUtilities.ResetRectTransform(obj, unity.Vector2.zero, unity.Vector2.one, unity.Vector2(-style.container_width/2, 0), unity.Vector2(-style.container_width, 0), unity.Vector2(0.5,0.5))
    else
        unityUtilities.ResetRectTransform(obj, unity.Vector2.zero, unity.Vector2.one, unity.Vector2(0, style.container_height/2), unity.Vector2(0, -style.container_height), unity.Vector2(0.5,0.5))
    end

    uiReference.imgViewer = obj.transform:Find("Viewport/Content").gameObject:AddComponent(typeof(ugui.RawImage))
end

local function addDescription()
    local objDescription = unity.GameObject("Description")
    uiReference.objDescription = objDescription
    objDescription.transform:SetParent(G_SLOT_UI.transform)
    local img = objDescription:AddComponent(typeof(ugui.Image))
    img.color = unity.Color(style.description_background_color_r
    , style.description_background_color_g
    , style.description_background_color_b
    , style.description_background_color_a
    )
    local vlg = objDescription:AddComponent(typeof(ugui.VerticalLayoutGroup))
    vlg.padding = unity.RectOffset(style.description_font_padding
    , style.description_font_size
    , style.description_font_padding
    , style.description_font_padding
    )
    local csf = objDescription:AddComponent(typeof(ugui.ContentSizeFitter))
    csf.verticalFit = ugui.ContentSizeFitter.FitMode.PreferredSize

    local objText = unity.GameObject("Text")
    objText.transform:SetParent(objDescription.transform)
    local text = objText:AddComponent(typeof(ugui.Text))
    text.fontSize = style.description_font_size
    text.font = G_FONT_MAIN

    local slotSize = unityUtilities.GetUiSlotSize()
    local anchoredPosition = unity.Vector2.zero
    local sizeDelta = unity.Vector2.zero
    -- 横竖屏处理
    if  slotSize.x > slotSize.y then -- 横屏
        sizeDelta.x = -(style.container_width+style.toolbar_margin_x+style.toolbar_width+style.description_margin_x*2)
        sizeDelta.y = 0 -- 布局自动计算
        anchoredPosition.x = style.description_margin_x
        anchoredPosition.y = style.description_margin_y
    else
        sizeDelta.x = -(style.container_width+style.toolbar_margin_x+style.toolbar_width+style.description_margin_x*2)
        sizeDelta.y = 0 -- 布局自动计算
        anchoredPosition.x = -style.toolbar_margin_x
        anchoredPosition.y = style.toolbar_margin_y + style.container_height
    end
    unityUtilities.ResetRectTransform(objDescription
    ,unity.Vector2(0,0)
    ,unity.Vector2(1,0)
    ,anchoredPosition
    ,sizeDelta
    ,unity.Vector2(0,0)
    )

end

local function addToolbar()
    local objToolbar = unity.GameObject("Toolbar")
    objToolbar.transform:SetParent(G_SLOT_UI.transform)
    objToolbar:AddComponent(typeof(unity.RectTransform))
    local slotSize = unityUtilities.GetUiSlotSize()
    local anchoredPosition = unity.Vector2.zero
    -- 横竖屏处理
    if  slotSize.x > slotSize.y then -- 横屏
        anchoredPosition.x = -style.toolbar_margin_x - style.container_width
        anchoredPosition.y = style.toolbar_margin_y
    else
        anchoredPosition.x = -style.toolbar_margin_x
        anchoredPosition.y = style.toolbar_margin_y + style.container_height
    end
    unityUtilities.ResetRectTransform(objToolbar
    ,unity.Vector2(1,0)
    ,unity.Vector2(1,0)
    ,anchoredPosition
    ,unity.Vector2(style.toolbar_width, style.toolbar_height)
    ,unity.Vector2(1,0)
    )

    local objSlider = unity.GameObject("Slider")
    objSlider.transform:SetParent(objToolbar.transform)
    local slider = unityUtilities.BuildSlider(objSlider, ugui.Slider.Direction.BottomToTop, style.toolbar_width)
    uiReference.slider = slider
    unityUtilities.ResetRectTransform(objSlider
    ,unity.Vector2(0,0)
    ,unity.Vector2(1,1)
    ,unity.Vector2(0,0)
    ,unity.Vector2(0,-style.toolbar_slider_margin)
    ,unity.Vector2(0.5, 1)
    )
    slider.minValue = 1
    slider.maxValue = style.viewer_zoomin_max

    local imgBackground = objSlider.transform:Find("Background"):GetComponent(typeof(ugui.Image))
    --imgBackground.color = unity.Color(style.slider_background_color_r, style.slider_background_color_g, style.slider_background_color_b, style.slider_background_color_a)
    local texture = g_archiveReader:ReadTexture("slider.png", unity.TextureFormat.RGBA32)
    local rect = unity.Rect(0, 0, texture.width, texture.height)
    local border = unity.Vector4(0,0,0,0)
    local sprite = g_archiveReader:CreateSprite(texture, rect, border)
    imgBackground.sprite = sprite
    objSlider.transform:Find("Fill Area").gameObject:SetActive(false)
    local texture = g_archiveReader:ReadTexture("handler.png", unity.TextureFormat.RGBA32)
    local tHandle = objSlider.transform:Find("Handle Slide Area/Handle")
    --tHandle:GetComponent(typeof(unity.RectTransform)).sizeDelta = unity.Vector2(0, style.toolbar_width)
    tHandle:GetComponent(typeof(ugui.RawImage)).texture = texture

    local onSliderValueChanged = function(_value)
        local rtViewer = uiReference.imgViewer:GetComponent(typeof(unity.RectTransform))
        rtViewer.sizeDelta = _value * viewerOriginSize
    end
    slider.onValueChanged:AddListener(onSliderValueChanged)
    table.insert(unbindFunctions, 1, function()
        slider.onValueChanged:RemoveAllListeners()
    end)

    -- 描述开关
    local objToggle = unity.GameObject("Toggle")
    objToggle.transform:SetParent(objToolbar.transform)
    local toggle = unityUtilities.BuildToggle(objToggle)
    uiReference.tgDescription = toggle
    unityUtilities.ResetRectTransform(objToggle
    ,unity.Vector2(0.5,0)
    ,unity.Vector2(0.5,0)
    ,unity.Vector2(0,0)
    ,unity.Vector2(style.toolbar_toogle_size, style.toolbar_toogle_size)
    ,unity.Vector2(0.5, 0)
    )

    local onToggleValueChanged = function(_toggled)
        uiReference.objDescription:SetActive(_toggled)
    end
    toggle.onValueChanged:AddListener(onToggleValueChanged)
    table.insert(unbindFunctions, 1, function()
        toggle.onValueChanged:RemoveAllListeners()
    end)
    toggle.isOn = true

    local imgBackground = objToggle.transform:Find("Background"):GetComponent(typeof(ugui.RawImage))
    local texture = g_archiveReader:ReadTexture("description_off.png", unity.TextureFormat.RGBA32)
    imgBackground.texture = texture
    local imgCheckmark = objToggle.transform:Find("Checkmark"):GetComponent(typeof(ugui.RawImage))
    local texture = g_archiveReader:ReadTexture("description_on.png", unity.TextureFormat.RGBA32)
    imgCheckmark.texture = texture
end

local function run()
    addBackground()
    addScrollContainer()
    addViewer()
    addDescription()
    addToolbar()
end

local function update()
end

local function stop()
    -- 结束正在加载的协程
    if nil ~= loadCoroutine then
        g_coroutineRunner:StopCoroutine(loadCoroutine)
    end
    -- 注销所有回调，避免抛出异常
    -- InvalidOperationException: try to dispose a LuaEnv with C# callback!
    for i,v in ipairs(unbindFunctions) do
        v()
    end
end

return {
    Run = run,
    Update = update,
    Stop = stop,
}
