local unity = CS.UnityEngine
local ugui = CS.UnityEngine.UI

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

-- 构建slider组件
-- 返回一个UnityEngine.UI.Slider
local function buildSlider(_target, _direction, _size)
    local slider = _target:AddComponent(typeof(ugui.Slider))

    local objBackground = unity.GameObject("Background")
    objBackground.transform:SetParent(slider.transform)
    local imgBg = objBackground:AddComponent(typeof(ugui.Image))
    if _direction == ugui.Slider.Direction.BottomToTop then
        resetRectTransform(objBackground, unity.Vector2(0.25, 0), unity.Vector2(0.75, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5, 0.5))
    else
        resetRectTransform(objBackground, unity.Vector2(0, 0.25), unity.Vector2(1, 0.75), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5, 0.5))
    end

    local objFillArea = unity.GameObject("Fill Area")
    objFillArea.transform:SetParent(slider.transform)
    objFillArea:AddComponent(typeof(unity.RectTransform))
    if _direction == ugui.Slider.Direction.BottomToTop then
        resetRectTransform(objFillArea, unity.Vector2(0.25, 0), unity.Vector2(0.75, 1), unity.Vector2(0, -10), unity.Vector2(0, -_size), unity.Vector2(0.5, 0.5))
    else
        resetRectTransform(objFillArea, unity.Vector2(0, 0.25), unity.Vector2(1, 0.75), unity.Vector2(-10, 0), unity.Vector2(-_size, 0), unity.Vector2(0.5, 0.5))
    end

    local objFill = unity.GameObject("Fill")
    objFill.transform:SetParent(objFillArea.transform)
    local imgFill = objFill:AddComponent(typeof(ugui.Image))
    if _direction == ugui.Slider.Direction.BottomToTop then
        resetRectTransform(objFill, unity.Vector2(0, 0), unity.Vector2(1, 0), unity.Vector2(0, 0), unity.Vector2(0, _size/2), unity.Vector2(0.5,0.5))
    else
        resetRectTransform(objFill, unity.Vector2(0, 0), unity.Vector2(0, 1), unity.Vector2(0, 0), unity.Vector2(_size/2, 0), unity.Vector2(0.5,0.5))
    end

    local objHandleSlideArea = unity.GameObject("Handle Slide Area")
    objHandleSlideArea.transform:SetParent(slider.transform)
    objHandleSlideArea:AddComponent(typeof(unity.RectTransform))
    if _direction == ugui.Slider.Direction.BottomToTop then
        resetRectTransform(objHandleSlideArea, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, -_size), unity.Vector2(0.5,0.5))
    else
        resetRectTransform(objHandleSlideArea, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(-_size, 0), unity.Vector2(0.5,0.5))
    end

    local objHandle = unity.GameObject("Handle")
    objHandle.transform:SetParent(objHandleSlideArea.transform)
    local imgHandle= objHandle:AddComponent(typeof(ugui.RawImage))
    if _direction == ugui.Slider.Direction.BottomToTop then
        resetRectTransform(objHandle, unity.Vector2(0, 0), unity.Vector2(1, 0), unity.Vector2(0, 0), unity.Vector2(0, _size), unity.Vector2(0.5,0.5))
    else
        resetRectTransform(objHandle, unity.Vector2(0, 0), unity.Vector2(0, 1), unity.Vector2(0, 0), unity.Vector2(_size, 0), unity.Vector2(0.5,0.5))
    end

    slider.targetGraphic = imgHandle
    slider.fillRect = objFill:GetComponent(typeof(unity.RectTransform))
    slider.handleRect = objHandle:GetComponent(typeof(unity.RectTransform))
    slider.direction = _direction

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

local function buildToggle(_target)
    local toggle = _target:AddComponent(typeof(ugui.Toggle))

    local objBackground = unity.GameObject("Background")
    objBackground.transform:SetParent(toggle.transform)
    local imgBg = objBackground:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objBackground, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5, 0.5))
    toggle.targetGraphic = imgBg

    local objCheckmark= unity.GameObject("Checkmark")
    objCheckmark.transform:SetParent(toggle.transform)
    local imgCheckmark = objCheckmark:AddComponent(typeof(ugui.RawImage))
    resetRectTransform(objCheckmark, unity.Vector2(0, 0), unity.Vector2(1, 1), unity.Vector2(0, 0), unity.Vector2(0, 0), unity.Vector2(0.5, 0.5))
    toggle.graphic = imgCheckmark

    return toggle
end

local function getUiSlotSize()
    local rectTransform = G_SLOT_UI:GetComponent(typeof(unity.RectTransform))
    return rectTransform.rect.size
end

return {
    ResetRectTransform = resetRectTransform,
    GetUiSlotSize = getUiSlotSize,
    BuildSlider = buildSlider,
    BuildScrollView = buildScrollView,
    BuildToggle = buildToggle,
}
