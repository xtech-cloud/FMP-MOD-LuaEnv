local description = {}
local count = 4


for i=1,count
do
    description["img#" .. i .. ".jpg"] = {}
end

-- description["img#1.jpg"]["en_US"] = 'this is description.'

description["img#1.jpg"]["en_US"] = "图片1的描述"
description["img#2.jpg"]["en_US"] = "图片2的描述"
description["img#3.jpg"]["en_US"] = "图片3的描述"
description["img#4.jpg"]["en_US"] = "图片4的描述"

return {
    Desc = description,
    Count = count,
}
