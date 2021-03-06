local SoundMng = require('app.helpers.SoundMng')
local ShowWaiting = require('app.helpers.ShowWaiting')
local tools = require('app.helpers.tools')
local GameLogic = require('app.libs.sangong.SGGameLogic')

local CreateRoomSGView = {}
local LocalSettings = require('app.models.LocalSettings')
local roomType = {
    ['zsOption'] = 3, 
    ['msOption'] = 4, 
    ['dcxOption'] = 5, 
    ['slOption'] = 9, 
}
local typeOptions = {
    ['base'] = 1, 
    ['round'] = 2,
    ['roomPrice'] = 3, 
    ['multiply'] = 4, 
    ['special'] = 5, 
    ['advanced'] = 6, 
    ['qzMax'] = 7, 
    ['putmoney'] = 8,
    ['startMode'] = 9,
    ['wanglai'] = 10,
    ['peopleSelect'] = 10,
    ['putLimit'] = 11,
    ['szSelect'] = 12,
}
local tabs = {
    ['zs'] = 3, -- 自由抢庄
    ['ms'] = 4, -- 明牌抢庄
    ['dcx'] = 5, -- 大吃小
    ['sl'] = 9, -- 三公轮庄
}

local BASE = {
    [1] = '1/2/4',
    [2] = '2/4/8',
    [3] = '3/6/12',
    [4] = '4/8/16',
    [5] = '5/10/20',
    [6] = '10/20/40',
}

local BASE_DCX = {
    [1] = '10',
    [2] = '20',
    [3] = '30',
    [4] = '40',
    [5] = '50',
    [6] = '100',
}

local ROUND = {
    [1] = 10,
    [2] = 15,
    [3] = 20,
}

local QZ_ROUND = {
    [1] = 10,
    [2] = 15,
    [3] = 20,
}

local scoreOption = {
    choushui = 10,
    join = 400,
    qiang = 400,
    tui = 400,
}

local costList = {
    Option11 = 4,
    Option12 = 5,
    Option13 = 6,
    Option21 = 6,
    Option22 = 8,
    Option23 = 10,
    Option31 = 9,
    Option32 = 12,
    Option33 = 15,
}

local setVersion = 25

function CreateRoomSGView:initialize()
    self:enableNodeEvents()
    self.options = {}
    self.paymode = 1
    local setPath = cc.FileUtils:getInstance():getWritablePath() .. '.CreateRoomConfig'

    if io.exists(setPath) then
        local ver = LocalSettings:getRoomSGConfig('setVersion')
        if (not ver) or ver < setVersion then
            cc.FileUtils:getInstance():removeFile(setPath)
        end
    end

    print("getincreateroom")

    self.options['zsOption'] = { msg = {
        ['gameplay'] = 3,  ['base'] = 1,   ['round'] = 1,
        ['roomPrice'] = 1, ['multiply'] = 1, ['special'] = { 1, 2, 3, 4},
        ['advanced'] = { 1, 0, 0, 0, 0, 0, 0, 0, 0},
        ['qzMax'] = 1,
        ['putmoney'] = 1,
        ['startMode'] = 1,
        ['wanglai'] = 1,
        ['peopleSelect'] = 1,
        ['putLimit'] = 1,
        ['szSelect'] = 1,
    } }

    self.options['msOption'] = { msg = {
        ['gameplay'] = 4,  ['base'] = 1,   ['round'] = 1,
        ['roomPrice'] = 1, ['multiply'] = 1, ['special'] = { 1, 2, 3, 4},
        ['advanced'] = { 1, 0, 0, 0, 0, 0, 0, 0, 0},
        ['qzMax'] = 1,
        ['putmoney'] = 1,
        ['startMode'] = 1,
        ['wanglai'] = 1,
        ['peopleSelect'] = 1,
        ['putLimit'] = 1,
        ['szSelect'] = 1,
    } }
    
    self.options['dcxOption'] = { msg = {
        ['gameplay'] = 5,  ['base'] = 1,   ['round'] = 1,
        ['roomPrice'] = 1, ['multiply'] = 1, ['special'] = { 1, 2, 3, 4},
        ['advanced'] = { 1, 0, 0, 0, 0, 0, 0, 0, 0},
        ['qzMax'] = 1,
        ['putmoney'] = 1,
        ['startMode'] = 1,
        ['wanglai'] = 1,
        ['peopleSelect'] = 1,
        ['putLimit'] = 1,
        ['szSelect'] = 1,
    } }

    self.options['slOption'] = { msg = {
        ['gameplay'] = 9,  ['base'] = 1,   ['round'] = 1,
        ['roomPrice'] = 1, ['multiply'] = 1, ['special'] = { 1, 2, 3, 4},
        ['advanced'] = { 1, 0, 0, 0, 0, 0, 0, 0, 0},
        ['qzMax'] = 1,
        ['putmoney'] = 1,
        ['startMode'] = 1,
        ['wanglai'] = 1,
        ['peopleSelect'] = 1,
        ['putLimit'] = 1,
        ['szSelect'] = 1,
    } }
    
    if not io.exists(cc.FileUtils:getInstance():getWritablePath() .. '.CreateRoomConfig')  then

        print(LocalSettings:getRoomSGConfig('msOptionbase'))

        for i,v in pairs(roomType) do
            for j,n in pairs(typeOptions) do
                LocalSettings:setRoomSGConfig(i..j, self.options[i]['msg'][j])
            end
        end

        LocalSettings:setRoomSGConfig('setVersion', setVersion)

    else
        print(" LocalSettings:getRoomSGConfig(v..n) is not == nil")
    end

    local MainPanel = self.ui:getChildByName('MainPanel')
    local bg = MainPanel:getChildByName('bg')
    self.bg = bg

    for i,v in pairs(roomType) do 
        for j, n in pairs(typeOptions) do 
            local data =  LocalSettings:getRoomSGConfig(i..j)
            if data then 
                self.options[i]['msg'][j] = data
            end
        end
    end

    self:freshAllItem()
end

function CreateRoomSGView:freshAllItem() 

    if LocalSettings:getRoomSGConfig("gameplay") then
        self.focus = LocalSettings:getRoomSGConfig("gameplay")
    else
        self.focus = 'ms'
    end

    local bg = self.bg
    local option_type = self.focus .. 'Option'
    local option = bg:getChildByName(option_type)
    for j, n in pairs(typeOptions) do 
        local data =  LocalSettings:getRoomSGConfig(option_type..j)
        if data then 
            local sender = nil
            if j == 'multiply' then 
                sender = option:getChildByName(j):getChildByName('opt'):getChildByName(tostring(data))
            elseif j == 'special' or j == 'advanced' then
                sender = nil 
            elseif j == 'base' or j == 'round' or j == 'startMode' or j == 'putmoney' then
                sender = nil
            else
                sender =  option:getChildByName(j):getChildByName(tostring(data))
            end 
            local fun = 'fresh'..j
            if self[fun] then 
                self[fun](self,data,sender)
            end
        end
    end
end

--------------------------------------------------------------------------------------------
--左边选择模式点击事件
function CreateRoomSGView:freshTab(data)
    for i, v in pairs(tabs) do 
        local tab = self.isShow and self.typeList:getItem(2) or self.bg:getChildByName('tab')
        local currentItem = tab:getChildByName(i)
        local currentOpt = self.bg:getChildByName(i .. 'Option')
        if data then 
            self.focus = data
        end
        if self.focus == i then
            currentItem:getChildByName('active'):setVisible(true)
            currentOpt:setVisible(true)
        else
            currentItem:getChildByName('active'):setVisible(false)
            currentOpt:setVisible(false)
        end
    end
    -- if self.isgroup then 
    --     self.bg:getChildByName('tb'):setVisible(false)
    --     self.bg:getChildByName('gz'):setVisible(false)
    -- end
    LocalSettings:setRoomSGConfig("gameplay", self.focus)
    self:freshAllItem()

    local app = require("app.App"):instance()
    app.session.room:setCurrentSGType(self.focus)
end

--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------
--刷新左边模式是否已配
function CreateRoomSGView:freshHasSave(data)
    for i, v in pairs(tabs) do 
        local tab = self.isShow and self.typeList:getItem(2) or self.bg:getChildByName('tab')
        local currentItem = tab:getChildByName(i)
        local hassaveImage = currentItem:getChildByName('Image')
        if data[v] == 1 then
            hassaveImage:setVisible(true)
        else
            hassaveImage:setVisible(false)
        end
    end
    -- LocalSettings:setRoomSGConfig("gameplay", self.focus)
end

--------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
--各个模式的刷新界面逻辑
function CreateRoomSGView:freshbase(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('base')

    local current_value = self.options[option_type]['msg']['base']
    if sender then
        current_value = (current_value + (tonumber(data) == 0 and -1 or 1) - 1) % 6 + 1
    end
    item:getChildByName('text'):setString(GameLogic.getBaseOrder(current_value, self.focus))

    if current_value == 6 then
        option:getChildByName('putLimit'):getChildByName('text'):setString(GameLogic.getPutLimitOrder(2))
        self.options[option_type]['msg']['putLimit'] = 2
    end

    self.options[option_type]['msg']['base'] = current_value
    LocalSettings:setRoomSGConfig(option_type..item:getName(), current_value)

    local info = {
        option =  option_type ,
        item = 'base' ,
        num = 6 ,
    }

    -- self:freshTextColor(info)
end

function CreateRoomSGView:freshround(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('round')

    local current_value = self.options[option_type]['msg']['round']
    if sender then
        current_value = (current_value + (tonumber(data) == 0 and -1 or 1) - 1) % 3 + 1
    end
    item:getChildByName('text'):setString(ROUND[current_value] .. '局')

    self.options[option_type]['msg']['round'] = current_value
    LocalSettings:setRoomSGConfig(option_type..item:getName(), current_value)

    local peopleSelect = self.options[option_type]['msg']['peopleSelect']
    local str = 'Option' .. current_value .. peopleSelect
    --根据局数更改房卡数值
    if self.paymode == 1 then
        if current_value == 1 then
            option:getChildByName('roomPrice'):getChildByName('1'):getChildByName('Text'):setString('房主支付(      ' .. costList[str]..')')
            option:getChildByName('roomPrice'):getChildByName('2'):getChildByName('Text'):setString('AA支付(每人      1)')
        end
        if current_value == 2 then
            option:getChildByName('roomPrice'):getChildByName('1'):getChildByName('Text'):setString('房主支付(      ' .. costList[str]..')')
            option:getChildByName('roomPrice'):getChildByName('2'):getChildByName('Text'):setString('AA支付(每人      2)')
        end
        if current_value == 3 then
            option:getChildByName('roomPrice'):getChildByName('1'):getChildByName('Text'):setString('房主支付(      ' .. costList[str]..')')
            option:getChildByName('roomPrice'):getChildByName('2'):getChildByName('Text'):setString('AA支付(每人      3)')
        end
    elseif self.paymode == 2 then 
        current_value = self:freshGroupCreateRoomview()
        if current_value == 1 then
            option:getChildByName('roomPrice'):getChildByName('paymode'):getChildByName('Text1'):setString('（      ' .. costList[str]..'）俱乐部管理员已设置从俱乐部基金中扣除，无需你支付')
        end
        if current_value == 2 then
            option:getChildByName('roomPrice'):getChildByName('paymode'):getChildByName('Text1'):setString('（      ' .. costList[str]..'）俱乐部管理员已设置从俱乐部基金中扣除，无需你支付')
        end
        if current_value == 3 then
            option:getChildByName('roomPrice'):getChildByName('paymode'):getChildByName('Text1'):setString('（      ' .. costList[str]..'）俱乐部管理员已设置从俱乐部基金中扣除，无需你支付')
        end
    end

    local info = {
        option =  option_type ,
        item = 'round' ,
        num = 3 ,
    }

    -- self:freshTextColor(info)
end

function CreateRoomSGView:freshpeopleSelect(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('peopleSelect')

    local current_value = self.options[option_type]['msg']['peopleSelect']
    if sender then
        current_value = (current_value + (tonumber(data) == 0 and -1 or 1) - 1) % 3 + 1
    end
    item:getChildByName('text'):setString(GameLogic.getPeopleSelectOrder(current_value))

    self.options[option_type]['msg']['peopleSelect'] = current_value
    LocalSettings:setRoomSGConfig(option_type..item:getName(), current_value)

    local round = self.options[option_type]['msg']['round']
    local str = 'Option' .. round .. current_value
    --根据局数更改房卡数值
    if self.paymode == 1 then
        if current_value == 1 then
            option:getChildByName('roomPrice'):getChildByName('1'):getChildByName('Text'):setString('房主支付(      ' .. costList[str]..')')
            -- option:getChildByName('roomPrice'):getChildByName('2'):getChildByName('Text'):setString('AA支付(每人      1)')
        end
        if current_value == 2 then
            option:getChildByName('roomPrice'):getChildByName('1'):getChildByName('Text'):setString('房主支付(      ' .. costList[str]..')')
            -- option:getChildByName('roomPrice'):getChildByName('2'):getChildByName('Text'):setString('AA支付(每人      2)')
        end
        if current_value == 3 then
            option:getChildByName('roomPrice'):getChildByName('1'):getChildByName('Text'):setString('房主支付(      ' .. costList[str]..')')
            -- option:getChildByName('roomPrice'):getChildByName('2'):getChildByName('Text'):setString('AA支付(每人      3)')
        end
    elseif self.paymode == 2 then 
        current_value = self:freshGroupCreateRoomview()
        if current_value == 1 then
            option:getChildByName('roomPrice'):getChildByName('paymode'):getChildByName('Text1'):setString('（      ' .. costList[str]..'）俱乐部管理员已设置从俱乐部基金中扣除，无需你支付')
        end
        if current_value == 2 then
            option:getChildByName('roomPrice'):getChildByName('paymode'):getChildByName('Text1'):setString('（      ' .. costList[str]..'）俱乐部管理员已设置从俱乐部基金中扣除，无需你支付')
        end
        if current_value == 3 then
            option:getChildByName('roomPrice'):getChildByName('paymode'):getChildByName('Text1'):setString('（      ' .. costList[str]..'）俱乐部管理员已设置从俱乐部基金中扣除，无需你支付')
        end
    end

    local info = {
        option =  option_type ,
        item = 'peopleSelect' ,
        num = 3 ,
    }

    -- self:freshTextColor(info)
end

function CreateRoomSGView:freshroomPrice(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('roomPrice')

    item:getChildByName('1'):getChildByName('select'):setVisible(false)
    item:getChildByName('2'):getChildByName('select'):setVisible(false)
    item:getChildByName('paymode'):setVisible(false)
    sender:getChildByName('select'):setVisible(true)

    self.options[option_type]['msg']['roomPrice'] = tonumber(data)
    LocalSettings:setRoomSGConfig(option_type..item:getName(), tonumber(data))

    local info = {
        option =  option_type ,
        item = 'roomPrice' ,
        num = 2 ,
    }

    self:freshTextColor(info)
end

function CreateRoomSGView:freshmultiply(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('multiply')

    for i = 1, 3 do
        item:getChildByName('opt'):getChildByName('' .. i):getChildByName('select'):setVisible(false)
    end
    sender:getChildByName('select'):setVisible(true)
    item:getChildByName('sel'):getChildByName('Text'):setString(sender:getChildByName("Text"):getString())

    self.options[option_type]['msg']['multiply'] = tonumber(data)
    LocalSettings:setRoomSGConfig(option_type..item:getName(), tonumber(data))

    local info = {
        option =  option_type ,
        item = 'multiply' ,
        num = 3 ,
    }

    self:freshTextColor(info)
end

function CreateRoomSGView:freshspecial(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('special')
    self.specialselect = 0

    for i = 1, 4 do
        item:getChildByName('opt'):getChildByName('' .. i):getChildByName('select'):setVisible(false)
    end

    for i = 1, #data do
        if data[i] == i then
            item:getChildByName('opt'):getChildByName(tostring(i)):getChildByName('select'):setVisible(true)
            self.specialselect = self.specialselect + 1
        end
    end
    if self.specialselect == 4 then 
        item:getChildByName('sel'):getChildByName('Text'):setString("全部勾选")
    else
        item:getChildByName('sel'):getChildByName('Text'):setString("部分勾选")
    end

    self.options[option_type]['msg']['special'] = data
    LocalSettings:setRoomSGConfig(option_type..item:getName(), self.options[option_type]['msg']['special'])

    local info = {
        option =  option_type ,
        item = 'special' ,
    }

    self:freshmulTextColor(info)
end

function CreateRoomSGView:freshspecialnow(data,sender)
    local data = tonumber(data)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('special')
    local flag = sender:getChildByName('select'):isVisible()

    sender:getChildByName('select'):setVisible(not flag)

    local specialselect =  self.options[option_type]['msg']['special']
    local specialselectnum = 0

    for i, v in pairs(specialselect) do
        if v == i then
            specialselectnum = specialselectnum + 1
        end
    end

    if flag then
        specialselectnum = specialselectnum - 1
    else
        specialselectnum = specialselectnum + 1
    end

    if specialselectnum == 4 then 
        item:getChildByName('sel'):getChildByName('Text'):setString("全部勾选")
    else
        item:getChildByName('sel'):getChildByName('Text'):setString("部分勾选")
    end
    
    self.options[option_type]['msg']['special'][data] = flag and 0 or data
    LocalSettings:setRoomSGConfig(option_type..item:getName(), self.options[option_type]['msg']['special'])

    local info = {
        option =  option_type ,
        item = 'special' ,
    }

    self:freshmulTextColor(info)
end

function CreateRoomSGView:freshqzMax(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('qzMax')

    item:getChildByName('1'):getChildByName('select'):setVisible(false)
    item:getChildByName('2'):getChildByName('select'):setVisible(false)
    item:getChildByName('3'):getChildByName('select'):setVisible(false)
    item:getChildByName('4'):getChildByName('select'):setVisible(false)
    sender:getChildByName('select'):setVisible(true)

    self.options[option_type]['msg']['qzMax'] = tonumber(data)
    LocalSettings:setRoomSGConfig(option_type..item:getName(), tonumber(data))

    local info = {
        option =  option_type ,
        item = 'qzMax' ,
        num = 4 ,
    }

    self:freshTextColor(info)
end

function CreateRoomSGView:freshszSelect(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('szSelect')

    item:getChildByName('1'):getChildByName('select'):setVisible(false)
    item:getChildByName('2'):getChildByName('select'):setVisible(false)
    item:getChildByName('3'):getChildByName('select'):setVisible(false)
    sender:getChildByName('select'):setVisible(true)

    self.options[option_type]['msg']['szSelect'] = tonumber(data)
    LocalSettings:setRoomSGConfig(option_type..item:getName(), tonumber(data))

    local info = {
        option =  option_type ,
        item = 'szSelect' ,
        num = 3 ,
    }

    self:freshTextColor(info)
end

function CreateRoomSGView:freshstartMode(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('startMode')

    local current_value = self.options[option_type]['msg']['startMode']
    if sender then
        current_value = (current_value + (tonumber(data) == 0 and -1 or 1) - 1) % 4 + 1
    end
    local peopleSelect = self.options[option_type]['msg']['peopleSelect']
    item:getChildByName('text'):setString(GameLogic.getStartModeOrder(current_value, peopleSelect))

    self.options[option_type]['msg']['startMode'] = current_value
    LocalSettings:setRoomSGConfig(option_type..item:getName(), current_value)

    local info = {
        option =  option_type ,
        item = 'startMode' ,
        num = 4 ,
    }

    -- self:freshTextColor(info)
end

function CreateRoomSGView:freshputmoney(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('putmoney')

    local current_value = self.options[option_type]['msg']['putmoney']
    if sender then
        current_value = (current_value + (tonumber(data) == 0 and -1 or 1) - 1) % 6 + 1
    end
    item:getChildByName('text'):setString(GameLogic.getPutMoneyOrder(current_value))

    self.options[option_type]['msg']['putmoney'] = current_value
    LocalSettings:setRoomSGConfig(option_type..item:getName(), current_value)

    local info = {
        option =  option_type ,
        item = 'putmoney' ,
        num = 6 ,
    }

    -- self:freshTextColor(info)
end

function CreateRoomSGView:freshadvanced(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('advanced')

    for i = 1, 9 do
        item:getChildByName('' .. i):getChildByName('select'):setVisible(false)
    end

    -- if option_type == 'msOption' or option_type == 'fkOption' or option_type == 'bmOption' or option_type == 'smOption' then
    --     item:getChildByName('5'):getChildByName('select'):setVisible(false)
    -- end

    for i = 1, #data do
        if data[i] == i then
            item:getChildByName(tostring(i)):getChildByName('select'):setVisible(true)
        end
    end

    self.options[option_type]['msg']['advanced'] = data
    LocalSettings:setRoomSGConfig(option_type..item:getName(), self.options[option_type]['msg']['advanced'])

    local info = {
        option =  option_type ,
        item = 'advanced' ,
    }

    self:freshmulTextColor(info)
end

function CreateRoomSGView:freshadvancednow(data,sender)
    local data = tonumber(data)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('advanced')
    local flag = sender:getChildByName('select'):isVisible()

    sender:getChildByName('select'):setVisible(not flag)
    
    self.options[option_type]['msg']['advanced'][data] = flag and 0 or data
    LocalSettings:setRoomSGConfig(option_type..item:getName(), self.options[option_type]['msg']['advanced'])

    local info = {
        option =  option_type ,
        item = 'advanced' ,
    }

    self:freshmulTextColor(info)
end

function CreateRoomSGView:freshwanglai(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('wanglai')

    item:getChildByName('1'):getChildByName('select'):setVisible(false)
    item:getChildByName('2'):getChildByName('select'):setVisible(false)
    item:getChildByName('3'):getChildByName('select'):setVisible(false)
    sender:getChildByName('select'):setVisible(true)

    self.options[option_type]['msg']['wanglai'] = tonumber(data)
    LocalSettings:setRoomSGConfig(option_type..item:getName(), tonumber(data))

    local info = {
        option =  option_type ,
        item = 'wanglai' ,
        num = 3 ,
    }

    self:freshTextColor(info)
end

function CreateRoomSGView:freshputLimit(data,sender)
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName('putLimit')

    local current_value = self.options[option_type]['msg']['putLimit']
    if sender then
        current_value = (current_value + (tonumber(data) == 0 and -1 or 1) - 1) % 6 + 1
    end

    local base = self.options[option_type]['msg']['base']
    if base == 6 and current_value == 1 then
        current_value = tonumber(data) == 0 and 6 or 2
    end
    item:getChildByName('text'):setString(GameLogic.getPutLimitOrder(current_value))

    self.options[option_type]['msg']['putLimit'] = current_value
    LocalSettings:setRoomSGConfig(option_type..item:getName(), current_value)

    local info = {
        option =  option_type ,
        item = 'putLimit' ,
        num = 6 ,
    }

    -- self:freshTextColor(info)
end

function CreateRoomSGView:freshchoushui()
    self.joinEditBox:setText(scoreOption.join)
    self.qiangEditBox:setText(scoreOption.qiang)
    self.tuiEditBox:setText(scoreOption.tui)
    self.choushuiEditBox:setText(scoreOption.choushui)
    self.choushuiLayer:getChildByName('sel'):getChildByName('Text'):setString('进场:' .. scoreOption.join .. ' 抢:' .. scoreOption.qiang 
    .. ' 推:' .. scoreOption.tui .. ' 抽水比例:' .. scoreOption.choushui .. '%')

    self.joinEditBox:registerScriptEditBoxHandler(function(eventname,sender) self:editboxHandle(eventname,sender) end)
    self.qiangEditBox:registerScriptEditBoxHandler(function(eventname,sender) self:editboxHandle(eventname,sender) end)
    self.tuiEditBox:registerScriptEditBoxHandler(function(eventname,sender) self:editboxHandle(eventname,sender) end)
    self.choushuiEditBox:registerScriptEditBoxHandler(function(eventname,sender) self:editboxHandle(eventname,sender) end)
end

function CreateRoomSGView:editboxHandle(eventname, sender)
    if eventname == "began" then
        --光标进入，选中全部内容
    elseif eventname == "ended" then
        -- 当编辑框失去焦点并且键盘消失的时候被调用
    elseif eventname == "return" then
        -- 当用户点击编辑框的键盘以外的区域，或者键盘的Return按钮被点击时所调用
    elseif eventname == "changed" then
        -- 输入内容改变时调用
        self.choushuiLayer:getChildByName('sel'):getChildByName('Text'):setString('进场:' .. self.joinEditBox:getText() ..
        ' 抢:' .. self.qiangEditBox:getText() .. ' 推:' .. self.tuiEditBox:getText() .. ' 抽水比例:' .. self.choushuiEditBox:getText() .. '%')
    end
end

function CreateRoomSGView:freshWinner(data,sender)
    local item = self.bg:getChildByName('choushui')

    item:getChildByName('opt'):getChildByName('1'):getChildByName('select'):setVisible(false)
    item:getChildByName('opt'):getChildByName('2'):getChildByName('select'):setVisible(false)
    sender:getChildByName('select'):setVisible(true)
    self.winner = tonumber(data)

end
---------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
--刷新字体颜色
function CreateRoomSGView:freshmulTextColor(data) 
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName(data.item)
    if data.item == 'multiply' or data.item == 'special' then 
        item = item:getChildByName('opt')
    end
    local selectdata = self.options[data.option]['msg'][data.item]

    for i = 1, #selectdata do
        if selectdata[i] ~= 0 then
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(255,255,255))
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(246,185,254))
        else
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(255,255,255))
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(184,199,254))
        end
    end
end

function CreateRoomSGView:freshTextColor(data) 
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type)
    local item = option:getChildByName(data.item)
    if data.item == 'multiply' or data.item == 'special' then 
        item = item:getChildByName('opt')
    end
    local selectdata = self.options[data.option]['msg'][data.item]
    
    for i = 1, data.num do
        if i == selectdata then
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(255,255,255))
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(246,185,254))
        else
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(255,255,255))
            item:getChildByName(tostring(i)):getChildByName('Text'):setColor(cc.c3b(184,199,254))
        end
    end
end
------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------
--三个问号提示的点击事件
function CreateRoomSGView:freshPriceLayer(bShow) 
    self.bg:getChildByName('priceLayer'):setVisible(bShow)
end

function CreateRoomSGView:freshTuiZhuLayer(bShow) 
    self.bg:getChildByName('tuizhuLayer'):setVisible(bShow)
    if bShow then
        self.bg:getChildByName('tuizhuLayer'):getChildByName('qz'):setVisible(false)
        self.bg:getChildByName('tuizhuLayer'):getChildByName('sz'):setVisible(false)
        if (self.focus == 'ms') then
            self.bg:getChildByName('tuizhuLayer'):getChildByName('qz'):setVisible(true)
        else
            self.bg:getChildByName('tuizhuLayer'):getChildByName('sz'):setVisible(true)
        end
    end
end

function CreateRoomSGView:freshXiaZhuLayer(bShow) 
    self.bg:getChildByName('xiazhuLayer'):setVisible(bShow)
    if bShow then
        self.bg:getChildByName('xiazhuLayer'):getChildByName('qz'):setVisible(false)
        self.bg:getChildByName('xiazhuLayer'):getChildByName('sz'):setVisible(false)
        if (self.focus == 'ms') then
            self.bg:getChildByName('xiazhuLayer'):getChildByName('qz'):setVisible(true)
        else
            self.bg:getChildByName('xiazhuLayer'):getChildByName('sz'):setVisible(true)
        end
    end
end

function CreateRoomSGView:freshquickLayer(bShow) 
    self.bg:getChildByName('quickLayer'):setVisible(bShow)
end

function CreateRoomSGView:freshWangLaiLayer(bShow, data) 
    self.bg:getChildByName('wanglaiLayer'):setVisible(bShow)
    if bShow then
        self.bg:getChildByName('wanglaiLayer'):getChildByName('bm'):setVisible(true)
        self.bg:getChildByName('wanglaiLayer'):getChildByName('bm'):getChildByName('1'):setVisible(false)
        self.bg:getChildByName('wanglaiLayer'):getChildByName('bm'):getChildByName('2'):setVisible(false)
        self.bg:getChildByName('wanglaiLayer'):getChildByName('bm'):getChildByName(data):setVisible(true)
    end
end

--两个模式的点击事件
function CreateRoomSGView:freshSpecialLayer(bShow,data) 
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type) 
    option:getChildByName('special'):getChildByName('opt'):setVisible(bShow)
    local path = 'res/views/createroom/' .. data.direction ..'.png'
    local bg = option:getChildByName('special'):getChildByName('sel'):getChildByName('bg')
    bg:getChildByName('down'):loadTexture(path)
end

function CreateRoomSGView:freshMultiplyLayer(bShow,data) 
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type) 
    option:getChildByName('multiply'):getChildByName('opt'):setVisible(bShow)
    local path = 'res/views/createroom/' .. data.direction ..'.png'
    local bg = option:getChildByName('multiply'):getChildByName('sel'):getChildByName('bg')
    bg:getChildByName('down'):loadTexture(path)
end

function CreateRoomSGView:freshChoushuiLayer(bShow,data) 
    local choushui = self.bg:getChildByName('choushui') 
    choushui:getChildByName('opt'):setVisible(bShow)
    local path = 'res/views/createroom/' .. data.direction ..'.png'
    local bg = choushui:getChildByName('sel'):getChildByName('bg')
    bg:getChildByName('down'):loadTexture(path)
end
------------------------------------------------------------------------------------------

function CreateRoomSGView:freshGroupCreateRoomview()
    local option_type = self.focus .. 'Option'
    local option = self.bg:getChildByName(option_type) 
    local opView = option:getChildByName('roomPrice')
    opView:getChildByName('1'):getChildByName('select'):setVisible(false)
    opView:getChildByName('2'):getChildByName('select'):setVisible(false)
    opView:getChildByName('paymode'):setVisible(true)
    opView:getChildByName('1'):setVisible(false)
    opView:getChildByName('2'):setVisible(false)
    opView:getChildByName('dm1'):setVisible(false)
    opView:getChildByName('dm2'):setVisible(false)
    opView:getChildByName('why'):setVisible(false)
    local round = LocalSettings:getRoomSGConfig(option_type ..'round')
    return round
end

function CreateRoomSGView:layout(isGroup, createmode, paymode)
    local MainPanel = self.ui:getChildByName('MainPanel')
    MainPanel:setContentSize(cc.size(display.width, display.height))
    MainPanel:setPosition(display.cx, display.cy)
    self.MainPanel = MainPanel

    local bg = MainPanel:getChildByName('bg')
    bg:setPosition(display.cx, display.cy)
    self.bg = bg
    self.isgroup = isGroup
    self.paymode = paymode
    self.isShow = false
    self.typeList = bg:getChildByName('typelist')
    self.tabs = bg:getChildByName('tab')
    self.choushuiLayer = bg:getChildByName('choushui')
    self.choushuiLayer:setVisible(false)
    if self.isgroup then --group
        self.choushuiLayer:setVisible(true)
        if createmode == 1 then
            self.bg:getChildByName('confirm'):setVisible(false)
            self.bg:getChildByName('tips'):setVisible(false)
            self.bg:getChildByName('sureBtn'):setVisible(true)
        elseif createmode == 2 then
            self.bg:getChildByName('confirm'):setVisible(true)
            self.bg:getChildByName('tips'):setVisible(false)
            self.bg:getChildByName('sureBtn'):setVisible(false)
            -- self.bg:getChildByName('quickstart'):setVisible(true)
            -- self:startCsdAnimation(self.bg:getChildByName('quickstart'):getChildByName("PurpleNode"),"PurpleAnimation",true,0.8)
        end
        if paymode == 2 then 
            self.isgroup = true
        end
    else
        -- 正常创建
        self.bg:getChildByName('typelist'):removeItem(2)
        self.bg:getChildByName('confirm'):setVisible(true)
        self.bg:getChildByName('tips'):setVisible(true)
        self.bg:getChildByName('sureBtn'):setVisible(false)    
    end
    
    if LocalSettings:getRoomSGConfig("gameplay") then
        self.focus = LocalSettings:getRoomSGConfig("gameplay")
    else
        self.focus = 'ms'
    end

    --创建editText
    local join = self.choushuiLayer:getChildByName('opt'):getChildByName('joinLayer')
    self.joinEditBox = tools.createEditBox(join, {
        -- holder
        defaultString = 400,
        holderSize = 18,
        holderColor = cc.c3b(185,198,254),

        -- text
        fontColor = cc.c3b(185,198,254),
        size = 18,
        maxCout = 6,
        fontType = 'views/font/Fangzheng.ttf',	
        inputMode = cc.EDITBOX_INPUT_MODE_NUMERIC,
    })

    local qiang = self.choushuiLayer:getChildByName('opt'):getChildByName('qiangLayer')
    self.qiangEditBox = tools.createEditBox(qiang, {
        -- holder
        defaultString = 400,
        holderSize = 18,
        holderColor = cc.c3b(185,198,254),

        -- text
        fontColor = cc.c3b(185,198,254),
        size = 18,
        maxCout = 6,
        fontType = 'views/font/Fangzheng.ttf',	
        inputMode = cc.EDITBOX_INPUT_MODE_NUMERIC,
    })

    local tui = self.choushuiLayer:getChildByName('opt'):getChildByName('tuiLayer')
    self.tuiEditBox = tools.createEditBox(tui, {
        -- holder
        defaultString = 400,
        holderSize = 18,
        holderColor = cc.c3b(185,198,254),

        -- text
        fontColor = cc.c3b(185,198,254),
        size = 18,
        maxCout = 6,
        fontType = 'views/font/Fangzheng.ttf',	
        inputMode = cc.EDITBOX_INPUT_MODE_NUMERIC,
    })

    local choushui = self.choushuiLayer:getChildByName('opt'):getChildByName('rateLayer')
    self.choushuiEditBox = tools.createEditBox(choushui, {
        -- holder
        defaultString = 10,
        holderSize = 18,
        holderColor = cc.c3b(185,198,254),

        -- text
        fontColor = cc.c3b(185,198,254),
        size = 18,
        maxCout = 3,
        fontType = 'views/font/Fangzheng.ttf',	
        inputMode = cc.EDITBOX_INPUT_MODE_NUMERIC,
    })

    self:freshchoushui()

    self:freshTab()

    --启动csd动画
    self:startallAction()
end

function CreateRoomSGView:getOptions()
    SoundMng.playEft('room_dingding.mp3')
    local key = self.focus .. 'Option'
    local savedata = self.options[key].msg
    local msg = clone(savedata)

    if msg.gameplay == 5 then
        msg.base = BASE_DCX[msg.base]
    else
        msg.base = BASE[msg.base]
    end

    msg.cost = 1
    if msg.roomPrice == 1 then
        msg.cost = costList['Option' .. msg.round .. msg.peopleSelect]
    elseif msg.roomPrice == 2 then
        msg.cost = msg.round
    end

    msg.round = QZ_ROUND[msg.round]

    if self.isgroup and self.paymode == 2 then
        msg.roomPrice = 1
    end

    msg.enter = {}
    msg.robot = 1
    msg.enter.buyHorse = 0
    msg.enter.enterOnCreate = 1
    
    msg.maxPeople = 6
    if msg.peopleSelect == 2 then
        msg.maxPeople = 8
    elseif msg.peopleSelect == 3 then
        msg.maxPeople = 10
    end

    if msg.gameplay == 5 then
        msg.qzMax = 1
        msg.multiply = 1
        msg.putmoney = 1
    end

    msg.deskMode = 'sg'

    msg.scoreOption = {
        choushui_sg = tonumber(self.choushuiEditBox:getText()),
        join = tonumber(self.joinEditBox:getText()),
        qiang = tonumber(self.qiangEditBox:getText()),
        tui = tonumber(self.tuiEditBox:getText()),
        rule = self.winner or 1,
    }

    dump(msg)

    return msg
end

function CreateRoomSGView:showWaiting()
    local scheduler = cc.Director:getInstance():getScheduler()
    if not self.schedulerID then

        ShowWaiting.show()
        self.waitingView = true

        self.schedulerID = scheduler:scheduleScriptFunc(function()
            ShowWaiting.delete()
            self.waitingView = false

            cc.Director:getInstance():getScheduler():unscheduleScriptEntry(self.schedulerID)
            self.schedulerID = nil
        end, 3, false)
    end
end

function CreateRoomSGView:delShowWaiting()
    if self.schedulerID then
        cc.Director:getInstance():getScheduler():unscheduleScriptEntry(self.schedulerID)
        self.schedulerID = nil
        if self.waitingView then
            ShowWaiting.delete()
            self.waitingView = false
        end
    end
end

function CreateRoomSGView:onExit()
    self:delShowWaiting()
end

function CreateRoomSGView:startCsdAnimation( node, csbName, isRepeat, timeSpeed)
    local action = cc.CSLoader:createTimeline("views/createroom/"..csbName..".csb")
    action:gotoFrameAndPlay(0,isRepeat)
    if timeSpeed then
    action:setTimeSpeed(timeSpeed)
    end
    node:stopAllActions()
    node:runAction(action)
end

function CreateRoomSGView:startallAction()
    -- for i,v in pairs(tabs) do
    --     self:startCsdAnimation(self.bg:getChildByName(i):getChildByName("active"):getChildByName("blinkingBoxNode"),"blinkingBoxAnimation",true,1.3)
    -- end

    -- self:startCsdAnimation(self.bg:getChildByName("flashBoxNode"),"flashBoxAnimation",true,0.8)  
end

function CreateRoomSGView:setShowList()
    self.isShow = not self.isShow
    if self.isShow then
        local tabsModule = self.tabs:clone()
        self.typeList:insertCustomItem(tabsModule, 2)
    else
        self.typeList:removeItem(2)
    end
end

return CreateRoomSGView