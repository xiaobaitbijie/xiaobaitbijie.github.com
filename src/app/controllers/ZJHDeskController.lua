local class = require('middleclass')
local Controller = require('mvc.Controller')
local HasSignals = require('HasSignals')
local ZJHDeskController = class("ZJHDeskController", Controller):include(HasSignals)
local SoundMng = require('app.helpers.SoundMng')
local tools = require('app.helpers.tools')
local GameLogic = require('app.libs.zhajinhua.ZJHGameLogic')
local TranslateView = require('app.helpers.TranslateView')
local Scheduler = require('app.helpers.Scheduler')
local config = require('config')
local HOST = config.host .. ':1990'
local app = require("app.App"):instance()

function ZJHDeskController:initialize(deskName)
    Controller.initialize(self)
    HasSignals.initialize(self)

    self.deskName = deskName
    self.desk = app.session[self.deskName]
    self.desk.deskName = deskName
    self.desk.info = self.desk:getDeskInfo()
    self.voiceQueue = {}


    self.isPlayingGame = false
    self.bCheatFlag = false                 -- 作弊标志
    self.bettingMsg = nil


    -- 声音控制
    self.isPausedBGM = nil
    self.lstBgmFlg = nil
    self.lstSfxFlg = nil
    self.lstBgmVol = nil
    self.lstSfxVol = nil

    -- 定时器
    self.timerUpt = nil
    self.time = nil

    -- 重置界面锁
    self.lockReload = false

    -- 总结算
    self.isDeskSummary = false

    --初始格林时间值
    self.gelinshijian = 1

    --定位
    -- self:setLocationInfo()
end

function ZJHDeskController:finalize()
    for i = 1, #self.listener do
        self.listener[i]:dispose()
    end

    if self.timerUpt then
        Scheduler.delete(self.timerUpt)
        self.timerUpt = nil
    end
end

function ZJHDeskController:viewDidLoad()

    self.listener = {
        -- ============================ ctrl ============================
        app.conn:on('ping', function()
            -- 心跳包
            self.view:onPing()
        end),

        app.conn:on('playVoice', function(msg)
            -- 语音消息, 放入controller处理
            if self.isPlayingVoice then
                self.voiceQueue[#self.voiceQueue + 1] = msg
            else
                self:playVoice(msg.filename, msg.uid, msg.total)
            end
        end),

        app.session.appEvent:on('didEnterBackground', function(msg)
            self.desk:enterBackground()
        end),

        app.session.appEvent:on('willEnterForeground', function(msg)
            self.desk:reloadData()
        end),

        self.desk:on('reloadData', function()
            if not self.lockReload then
                self.lockReload = true
                print('reload game ============> ')
                self.view:recoveryDesk(self.desk, true)
                self.lockReload = false
            end
        end),

        -- ============================ state ============================
        ------------------------==========
        --Starting
        self.desk:on('StateReady', function(msg)
            self.view:setState('Ready')
        end),

        --Starting
        self.desk:on('StateStarting', function(msg)
            self.view:setState('Starting')
        end),

        ------------------------==========
        ------------------------------------------------
        -- PutMoney
        self.desk:on('StatePutMoney', function(msg)
            self.view:setState('PutMoney')
        end),

        self.desk:on('putMoney', function(msg)
            self.view:onMessageState(msg)
        end),

        -- 刷新押注
        self.desk:on('somebodyPutMoney', function(msg)
            self.view:onMessageState(msg)
        end),

        self.desk:on('somebodySeeCard', function(msg)
            self.view:onMessageState(msg)
        end),

        self.view:on('showCoinFlayActionEnd', function(msg)
            self.view:onMessageState(msg)
        end),

        self.view:on('clickBet', function(msg)
            self:clickJiaZhu(msg)
        end),

        self.desk:on('nextPlayer', function(msg)
            self.view:onMessageState(msg)
        end),

        self.view:on('cpBack', function(msg)
            self.view:onMessageState(msg)
		end),
        ------------------------------------------------
        self.view:on('bettingActionEnd', function(msg)
            self.view:onMessageState(msg)
        end),
        ------------------------==========
        -- Dealing
        self.desk:on('StateDealing', function(msg)
            self.view:setState('Dealing')
        end),

        self.desk:on('dealt', function(msg)
            self.view:onDealMsg()
        end),

        ------------------------==========
        -- Compare
        self.desk:on('StateCompare', function(msg)
            self.view:setState('Compare')
        end),

        self.desk:on('compareResult', function(msg)
            self.view:onMessageState(msg)
        end),
        ------------------------==========
        -- Ending
        self.desk:on('Ending', function(msg)

        end),

        -- ============================ agent ============================
        self.desk:on('somebodySitdown', function(msg)
            local actor = msg.player:getActor()
            local viewKey = msg.viewKey
            self.view:freshHeadInfo(viewKey, actor)
            self.view:freshMoney(viewKey, msg.player:getMoney(), msg.player:getGroupScore())
            self.view:freshSeat(viewKey, true)
            -- 坐下自动准备
            if not self.desk:isGamePlayed() then
                self.view:freshReadyState(viewKey, true)
            end
            self.view:freshDropLine(viewKey, false)
            self.view:freshEnterBackground(viewKey, false)
            self.view:freshTrusteeshipIcon(viewKey, false)
        end),

        self.desk:on('somebodyLeave', function(msg)
            -- 自己为玩家时退出
            if self.isDeskSummary then return end
            local meUid = self.desk:getMeUID()
            if meUid == msg.uid then
                self:onQuitGame()
                return
            end
            -- 别人退出
            self.view:freshSeat(msg.viewKey, false)
            self.view:clearDesk(msg.viewKey)
        end),

        self.desk:on('leaveResult', function(msg)
            -- 自己为旁观者退出
            self:onQuitGame()
        end),

        self.desk:on('somebodyPrepare', function(msg)
            self.view:onMessageState(msg)
        end),

        self.desk:on('dropLine', function(msg)
            self.view:freshDropLine(msg.viewKey, true)
        end),

        self.desk:on('somebodyEnterBackground', function(info, msg)
            self.view:freshEnterBackground(info.viewKey, msg.flag)
        end),

        self.desk:on('somebodyCancelTrusteeship', function(msg)
            if self.desk:isMeInMatch() then
                -- if msg.viewKey == "bottom" then
                --     self.view:freshTrusteeshipLayer(false)
                -- end
            end
            self.view:freshTrusteeshipIcon(msg.viewKey, false)
        end),

        self.desk:on('somebodyTrusteeship', function(msg)
            if self.desk:isMeInMatch() then
                -- if msg.viewKey == "bottom" then
                --     self.view:freshTrusteeshipLayer(true)
                -- end
            end
            self.view:freshTrusteeshipIcon(msg.viewKey, true)
        end),

        -- ============================ cheat ============================
        -- 作弊信息
        self.desk:on('cheatInfo', function(msg)
            self:onCheatInfo(msg)
        end),

        self.desk:on('cheat1', function(flag)
            self.view:freshCheat1View(true, flag)
        end),

        self.desk:on('cheat1Result', function(mode)
            self.view:freshCheat1Result(mode)
        end),



        -- ============================ desk ============================
        self.desk:on("canStart", function(msg)
            -- 客户端可以开始游戏了
            self.view:onMessageState(msg)
        end),

        self.desk:on('waitStart', function(msg)
            -- 等待 xx 开始游戏
            self.view:onMessageState(msg)
        end),

        self.desk:on('autoLeave', function(msg)
            -- 要被退出
            tools.showRemind("您的分数不足，即将退出游戏")
        end),

        self.desk:on('summary', function(msg)
            self.view:onMessageState(msg)
        end),

        self.desk:on('payNextFail', function(msg)
            if msg.code == -1 then
                tools.showRemind("房间基金不足，房间自动解散")
            elseif msg.code == -2 then
                tools.showRemind("房主房卡不足，房间自动解散")
            elseif msg.code == -3 then
                tools.showRemind("房主不在线，房间自动解散")
            end
        end),

        self.desk:on('deskSummary', function(msg)
            --总结算
            self.isDeskSummary = true
            if not self.desk:isGamePlayed() then
                tools.showMsgBox("提示", "房主已经解散房间，牌局未开始未扣钻石。"):next(function(btn)
                    self:onQuitGame(true)
                end)
                return
            end
            -- 隐藏提示文本
            self.view:freshTip(false)

            -- 隐藏设置界面
            self.view:gameSettingAction('Out')

            -- 隐藏解散界面
            self:showApplyController(false)

            -- 总结算界面
            local groupInfo = self.desk:getgroupInfo()
            msg.groupInfo = groupInfo
            self.view:freshSummaryView(true, msg)
        end),

        self.desk:on('responseSitdown', function(msg)
            -- 请求坐下结果
            self.view:onResponseSitdown(msg)
        end),

        self.desk:on('overgame', function(msg)
            -- 解散房间信息
            if msg.code and msg.code == -1 then
                if msg.uid == self.desk:getMeUID() then
                    tools.showRemind("您不能连续两次发起解散")
                end
                return
            end
            self:showApplyController(true)
        end),

        self.desk:on('overgameResult', function(msg)
            -- 解散房间结果
        end),

        self:on("watcherList", function(msg)
            -- 旁观者列表   
            self.clickWatcherList()
        end),

        self.desk:on("getLastVoiceResult", function(msg)
            -- 播放上一次语音信息
            local cache = msg.cache
            if msg.flag then
                if self.isPlayingVoice then
                    self.voiceQueue[#self.voiceQueue + 1] = cache
                else
                    self:playVoice(cache.filename, cache.uid, cache.total)
                end
            else
                tools.showRemind('该玩家没有发送语音信息')
            end
        end),

        self.desk:on('chatInGame', function(msg)
            -- 游戏中聊天
            local info = self.desk:getPlayerInfo(msg.uid)
            local meUid = self.desk:getMeUID()
            if not info then return end
            local viewKey, viewPos = info.player:getViewInfo()
            local msgType, msgData = msg.type, msg.msg

            if msgType == 3 then
                -- 头像表情
                local startUid = msgData.clickSender
                local destUid = msgData.uid
                local flag = msgData.flag
                local dttime = msgData.dt
                local level = msgData.level

                if dttime - self.gelinshijian < 2 then
                    if startUid == meUid then
                        tools.showRemind('房间内表情发送过于频繁')
                    end
                    return
                end
                self.gelinshijian = dttime

                local start = self.desk:getPlayerInfo(startUid)
                if not start then return end
                local dest = self.desk:getPlayerInfo(destUid)
                if not dest then return end
                local playerviewkey = self.view:getPlayerView(startUid)
                if msgData.biaoqingflag then
                    if flag then
                        for i, v in pairs(playerviewkey) do
                            if msgData.idx ~= 15 then
                                self.view:kusoAction(start.viewKey, v, msgData.idx)
                            else
                                self.view:kusoAction_DaQiang(start.viewKey, v, i)
                            end
                        end
                    else
                        if msgData.idx ~= 15 then
                            self.view:kusoAction(start.viewKey, dest.viewKey, msgData.idx)
                        else
                            self.view:kusoAction_DaQiang(start.viewKey, dest.viewKey)
                        end
                    end
                else
                    return
                end
            else
                -- 快捷语 | 自定义聊天 | emoji表情
                local sex = info.player:getSex()
                self.view:freshChatMsg(viewKey, sex, msgType, msgData)
            end
        end),

        self.desk:on('smartTrusteeshipResult', function(msg)
            --智能托管返回结果
            if msg.retCode == 1 and msg.flag then
                self.view:freshTrusteeshipLayer(true)
            elseif not msg.flag then
                self.view:freshTrusteeshipLayer(false)
            end
        end),

        self.desk:on('SomebodyShowCards', function(msg)
            -- 有人亮牌
            local info = self.desk:getPlayerInfo(msg.uid)
            if not info then return end
            info.player:setHandCardData(msg.cards)
            self.view:onSomebodyShowCards(info.player, msg.flag)
        end),

        --[[        self:on("chatList", function(msg)
            -- xychatlist 子界面实现
        end),

        self:on("deskRecord", function(msg)
            -- 子界面实现
        end),
        ]]
        -- ============================ view ============================
        self.view:on('stopTime', function()
            self:timerFinish()
        end),

        self.view:on('clickHead', function(msg)
            self:onClickHead(msg)
        end),

        self.view:on('pressVoice', function(_)
            self:pressVoice()
            self:pauseBGM()
        end),

        self.view:on('releaseVoice', function()
            self:releaseVoice()
            self:resumeBGM()
        end),

        self.view:on('showDismissView', function()
            self:showApplyController(true)
        end),

        self.view:on('clickCompare', function(msg)
            self:onClickCompare(msg)
        end),
    }

    -- 自定义消息监听
    self:postAppendListens()

    self.view:layout(self.desk)

    -- 同步界面
    if not self.lockReload then
        self.lockReload = true
        if self.desk:isGamePlayed() then
            self.view:recoveryDesk(self.desk, true)
        else
            self.view:recoveryDesk(self.desk, false)
        end
        self.lockReload = false
    end

    self:initBGM()

end

-- =================== on syndeskdata ===================
function ZJHDeskController:onReloadData(msg)

end

-- =================== on desk msg ===================
function ZJHDeskController:onBlinds() -- Virtual Function
end

-- 显示作弊信息
function ZJHDeskController:onCheatInfo(msg)
    self.view:freshCheatView(msg)
end

-- =================== on views msg ===================
function ZJHDeskController:clickSitdown(sender)
    self.desk:requestSitdown()
    self.view:freshBtnPos()
end

function ZJHDeskController:clickPrepare()
    self.view:freshPrepareBtn(false)
    self.desk:prepare()
    self.view:freshBtnPos()
end

function ZJHDeskController:clickGameStart()
    self.desk:startGame()
    self.view:freshGameStartBtn(false)
    self.view:freshBtnPos()
end

function ZJHDeskController:clickOut()
    self.view:gameSettingAction('Out')
end

function ZJHDeskController:clickIn()
    self.view:gameSettingAction('In')
end

function ZJHDeskController:clickInfoIn()
    --self.view:freshCuoPaiDisplay(true, {"♥6", "♠2", "♠2","♠2","♠K"})
    self.view:freshGameInfo(true)
end

function ZJHDeskController:clickInfoOut()
    self.view:freshGameInfo(false)
end

function ZJHDeskController:clickLeave()

    repeat
        -- 观战者直接离开
        if not self.desk:isMePlayer() then
            break
        end

        -- 玩家游戏开始之后就不能离开
        if self.desk:isGamePlayed() then
            return
        end
    until true

    self.desk:leaveRoom()
end

function ZJHDeskController:clickDismiss()
    if self.desk:isMeInMatch() or self.desk:isMeOwner() then
        -- if self.desk:isGamePlaying() then
        --     tools.showRemind('牌局未结束不能解散房间...')
        -- else
        --     self.desk:dismiss()
        -- end
        self.desk:dismiss()
    end
end

function ZJHDeskController:clickInviteFriend()
    local invokefriend = require('app.helpers.invokefriend')
    local deskId = self.desk:getDeskId()
    local deskInfo = self.desk:getDeskInfo()
    local groupInfo = self.desk:getgroupInfo()
    invokefriend.invoke(deskId, deskInfo, groupInfo)
end

function ZJHDeskController:clickCopyRoomNum()
    local deskId = self.desk:getDeskId()
    local deskInfo = self.desk:getDeskInfo()

    --支付方式
    local roomprice = GameLogic.getPayModeText(deskInfo) .. '支付'
    -- 玩法
    local gameplayStr = GameLogic.getGameplayText(deskInfo)
    -- 底分
    local baseStr = GameLogic.getBaseText(deskInfo)
    -- 翻倍规则
    local mulStr = GameLogic.getNiuNiuMulText(deskInfo)
    -- 房间规则
    local advanceStr = GameLogic.getAdvanceText(deskInfo)
    -- 特殊牌
    local spStr = GameLogic.getSpecialText(deskInfo, 3, true)
    -- 分享标题
    local title = "相约茶苑【房间号：" .. deskId .. "】"

    -- 分享详情 
    local text = string.format(" 底分：%s, %d局, %s, %s, %s",
    baseStr,
    deskInfo.round,
    roomprice,
    gameplayStr,
    spStr
    )

    local content = title .. text
    if device.platform == 'android' then
        self.view:copyRoomNum(content)
    elseif device.platform == 'ios' then
        local luaoc = require('cocos.cocos2d.luaoc')
        local ok, ret = luaoc.callStaticMethod("AppController", "copyToClipboard", { ww = content })
        if ok then
            tools.showRemind('已复制')
        end
    end
end

function ZJHDeskController:clickAutoGenzhu()
    SoundMng.playEft('btn_click.mp3')
    -- 发送操作选项
    local flag = self.view:freshAutoGenzhuBtn()
    local msg = {
        uid = self.desk:getMeUID(),
        flag = flag,
    }
    self.desk:autoOperation(msg)
end

function ZJHDeskController:clickTrusteeship()
    if self.desk:isMeInMatch() then
        self.desk:requestTrusteeship()
        self.view:freshTrusteeshipLayer(true)
        -- self.view:freshTrusteeshipIcon('bottom', true)
        -- SoundMng.playEft('btn_click.mp3')
        -- self:setWidgetAction(
        --     'SelectTrusteeshipController',
        --     {self.desk}
        -- )
        self.view:gameSettingAction('Out')
    else
        tools.showRemind('游戏开始后才能托管')
    end
end

function ZJHDeskController:clickCancelTrusteeship()
    if self.desk:isMeInMatch() then
        self.desk:cancelTrusteeship()
        self.desk:sendTrusteeshipMsg(false)
    end
end

function ZJHDeskController:clickContinue()
    SoundMng.playEft('btn_click.mp3')
    local deskInfo = self.desk:getDeskInfo()
    local roomMode = deskInfo.roomMode
    local base = deskInfo.base
    local agent = self.desk:getMeAgent()
    if roomMode == 'bisai' then
        if agent then
            local groupScore = agent:getGroupScore()
            if groupScore < tonumber(base) then
                tools.showRemind("您的分数不足，即将退出游戏")
                return
            end
        end
    end
    self.desk:prepare()
end

function ZJHDeskController:clickFanPai()
    SoundMng.playEft('btn_click.mp3')
    self.view:onMessageState({ msgID = 'clickFanPai' })
end

function ZJHDeskController:clickCuoPai()
    SoundMng.playEft('btn_click.mp3')
    -- 闷牌轮数
    if GameLogic.getBlindRound(self.desk:getDeskInfo()) >= self.desk.gameplay:getCompareRound() then
        tools.showRemind("闷牌时不能搓牌")
        return
    end
    if self.desk.gameplay:getCurrentPlayer() ~= self.desk:getMeUID() then
        tools.showRemind("不是你的回合")
        return
    end
    self.view:freshOpBtns(false, false)
    self.view:onMessageState({ msgID = 'clickCuoPai' })
end

function ZJHDeskController:clickTips()
    SoundMng.playEft('btn_click.mp3')
    self.view:onMessageState({ msgID = 'clickTips' })
end

function ZJHDeskController:clickShowCards()
    SoundMng.playEft('btn_click.mp3')
    self.desk:showCard()
end

function ZJHDeskController:onClickHead(uid)
    SoundMng.playEft('btn_click.mp3')
    local info = self.desk:getPlayerInfo(uid)
    if not info then return end

    local pActor = info.player:getActor()
    local actor = clone(pActor)
    actor.clickSender = self.desk:getMeUID()
    actor.location = info.player:getLocationInfo()

    self:widgetAction('PersonalPageController', { actor, self.desk })
end

function ZJHDeskController:onClickCompare(uid)
    local meUid = self.desk:getMeUID()
    if meUid == uid then return end
    self.view:showCompareAni(true)
    self.desk:putmoney(5, 0, uid)
end

function ZJHDeskController:clickMsg()
    SoundMng.playEft('btn_click.mp3')
    self:widgetAction('ZJHChatController', self.desk)
end

function ZJHDeskController:clickGameSetting()
    SoundMng.playEft('btn_click.mp3')
    self:widgetAction('SettingController', { 'gameSetting', self.view })
end

function ZJHDeskController:clickWatcherList()
    SoundMng.playEft('btn_click.mp3')
    self:widgetAction('ZJHWatcherListController', self.desk)
end

function ZJHDeskController:clickPlaybackBtn()
    SoundMng.playEft('btn_click.mp3')
    local deskInfo = self.desk:getDeskInfo()
    if deskInfo.roomMode == 'bisai' then
        tools.showRemind("比赛场不支持该功能")
        return
    end
    self:widgetAction('PlaybackController', self.desk)
end

function ZJHDeskController:clickGenZhu()
    SoundMng.playEft('btn_click.mp3')
    if self.desk:getMeAgent() and self.desk:getMeAgent():getAutoOperation() then
        return
    end
    self.desk:putmoney(1)
end

function ZJHDeskController:clickJiaZhu(value)
    SoundMng.playEft('btn_click.mp3')
    if self.desk:getMeAgent() and self.desk:getMeAgent():getAutoOperation() then
        return
    end
    self.desk:putmoney(2, value)
end

function ZJHDeskController:clickJiaZhuLayer()
    SoundMng.playEft('btn_click.mp3')
    if self.desk:getMeAgent() and self.desk:getMeAgent():getAutoOperation() then
        return
    end
    self.view:freshJiaZhuLayer()
end

function ZJHDeskController:clickSeeCard()
    SoundMng.playEft('btn_click.mp3')
    self.desk:putmoney(3)
end

function ZJHDeskController:clickQiPai()
    SoundMng.playEft('btn_click.mp3')
    self.desk:putmoney(4)
end

function ZJHDeskController:clickCompare()
    SoundMng.playEft('btn_click.mp3')
    if self.desk:getMeAgent() and self.desk:getMeAgent():getAutoOperation() then
        return
    end
    self.view:showCompareAni(true)
end

function ZJHDeskController:clickCloseCuoPai()
    self.view:freshCuoPaiDisplay(false, nil)
    self.view:onMessageState({ msgID = 'cpBack' })
end
-- =================== virtual function ===================
function ZJHDeskController:postAppendListens() -- virtual function
end

-- =================== private ===================
function ZJHDeskController:initBGM()
    local bgmFlag = SoundMng.getEftFlag(SoundMng.type[1])
    local EftFlag = SoundMng.getEftFlag(SoundMng.type[2])
    local bgmVol, sfxVol = SoundMng.getVol()
    SoundMng.setBgmVol(bgmVol)
    SoundMng.setSfxVol(sfxVol)
    SoundMng.setBgmFlag(bgmFlag)
    SoundMng.setEftFlag(EftFlag)
    SoundMng.setPlaying(false)
    if bgmFlag == nil then
        bgmFlag = true
    end
    if EftFlag == nil then
        EftFlag = true
    end
    SoundMng.playBgm('game_bg1.mp3')
end

function ZJHDeskController:pauseBGM()
    if self.isPausedBGM then
        return
    end

    self.isPausedBGM = true

    self.lstBgmFlg = SoundMng.getEftFlag(SoundMng.type[1])
    self.lstSfxFlg = SoundMng.getEftFlag(SoundMng.type[2])

    self.lstBgmVol, self.lstSfxVol = SoundMng.getVol()
    if self.lstBgmFlg == nil then
        self.lstBgmFlg = true
    end
    if self.lstSfxFlg == nil then
        self.lstSfxFlg = true
    end

    SoundMng.setBgmFlag(false)
    SoundMng.setEftFlag(false)
end

function ZJHDeskController:resumeBGM()
    if self.isPausedBGM then
        SoundMng.setBgmFlag(self.lstBgmFlg)
        SoundMng.setEftFlag(self.lstSfxFlg)

        SoundMng.setBgmVol(self.lstBgmVol)
        SoundMng.setSfxVol(self.lstSfxVol)

        self.isPausedBGM = false
    end
end


function ZJHDeskController:playEftNN(name, msg)
    if name == 'bottom' and msg.niuCnt ~= -1 then
        local player = self.desk.players[1]
        local actor = player.actor
        local sex = actor.sex
        --local n = sex == 0 and 'man' or 'woman'
        local path = 'cscompare/' .. tostring('f' .. sex .. "_" .. msg.niuCnt .. '.mp3')
        SoundMng.playEftEx(path)
    end
end

function ZJHDeskController:widgetAction(controllerName, args)

    local ctrl = Controller:load(controllerName, args)
    self:add(ctrl)

    app.layers.ui:addChild(ctrl.view)
    -- ctrl.view:setPositionX(display.width)
    -- TranslateView.fadeIn(ctrl.view, -1)
    ctrl:on('back', function()
        -- TranslateView.fadeOut(ctrl.view, 1, function()
        ctrl:delete()
        -- end)
    end)
end


function ZJHDeskController:timerSyn()
    local info = self.desk.info
    local desk = self.desk

    if desk.curState ~= "" and self.timerUpt and info.gameTick ~= 0 then
        self.time = math.floor(info.gameTick / 1000)
    end

    if self.desk.info.played and not self.desk:isGamePlaying() then
        if info.readyTimerStart then
            self.view:freshGameStateTip(true, 3, math.floor(info.readyTick / 1000))
        end
    end
end

function ZJHDeskController:timerStart(key, countdown, callback)
    if self.timerUpt then
        self:timerFinish()
    end

    -- self.view:freshCDHint(key)
    self.time = countdown
    local delay = 0

    self.timerUpt = Scheduler.new(function(dt)
        delay = delay + dt
        if delay > 1 then
            --delay, self.time = 0, self.time - 1
            delay = 0
            self.time = self.time - 1
        end

        -- self.view:freshTimer(self.time, true)
        if self.time == 0 then
            self:timerFinish()
            if callback then callback() end
        end
    end)


    self.view:freshStateViews()
end


function ZJHDeskController:timerFinish()
    if self.timerUpt then
        self.time = 0
        -- self.view:freshTimer(self.time, false)
        Scheduler.delete(self.timerUpt)
        self.timerUpt = nil
    end
end



function ZJHDeskController:handleVoice()
    local record = require('record.record')

    self.recording = true
    self.view:doVoiceAnimation()
    local writable = cc.FileUtils:getInstance():getWritablePath()
    cc.FileUtils:getInstance():removeFile(writable .. 'record')
    cc.FileUtils:getInstance():removeFile(writable .. 'record.mp3')

    record.go(writable .. 'record')
    self:destroyRecordF()

    local delay = 0
    self.total = 0
    self.recordF = Scheduler.new(function(dt)
        delay = delay + dt
        if delay > 1 then
            delay = 0
            --print('getAmplitude',record.getAmplitude())
        end

        self.total = self.total + dt
        self.view:updateCountdownVoice(self.total)

        if self.total >= 20 then
            self:releaseVoice()
        end
    end)
end

function ZJHDeskController:destroyRecordF()
    if self.recordF then
        Scheduler.delete(self.recordF)
        self.recordF = nil
    end
end

function ZJHDeskController:pressVoice()
    self:handleVoice()
end

function ZJHDeskController:releaseVoice()
    if not self.recording then return end
    local writable = cc.FileUtils:getInstance():getWritablePath()
    self.recording = nil
    self:destroyRecordF()
    self.view:removeVoiceAnimation(self.total < 1)

    local record = require('record.record')

    if self.total < 2 then
        tools.showRemind('录音时间不能少于2秒哦!')
        record.stopRecording(function() end)
        return
    end

    record.stopRecording(function()
        local delayA = cc.DelayTime:create(0.1)
        self.view:runAction(cc.Sequence:create(delayA, cc.CallFunc:create(function()
            local lame = require('lame')
            lame.convert(writable .. 'record', writable .. 'record.mp3', device.platform)
            self:uploadVoice(writable .. 'record.mp3', function(filename)
                self.desk:uploadVoiceSuccess(filename, self.total)
            end)
        end)))
    end)

    self:destroyRecordF()
end

function ZJHDeskController:playVoiceInQueue()
    if #self.voiceQueue == 0 then
        return false
    end

    local msg = self.voiceQueue[1]
    table.remove(self.voiceQueue, 1)

    self:playVoice(msg.filename, msg.uid, msg.total)
    return true
end



function ZJHDeskController:playVoice(filename, uid, total, dontNotifyView) -- luacheck:ignore
    self.isPlayingVoice = true

    -- 获取原本音量
    local bgmVol, sfxVol = SoundMng.getVol()
    print('uid,total is ', uid, total)

    local cache = require('app.helpers.cache')
    cache.get('http://' .. HOST .. '/' .. filename, function(ok, path)
        if not self.view then return end

        if ok then
            self:pauseBGM()
            -- 播放语音聊天时将音量设置为最大
            SoundMng.setBgmVol(1)
            SoundMng.setSfxVol(1)

            if device.platform == 'android' then
                --audio.playMusic(path,false)
                SoundMng.playVoice(path)
            else
                --audio.playSound(path)
                SoundMng.playVoice(path)
            end

            if not dontNotifyView then
                self.view:somebodyVoice(uid, total)
            end

            local delay = cc.DelayTime:create(total)
            self.view:runAction(cc.Sequence:create(delay, cc.CallFunc:create(function()
                self.isPlayingVoice = false

                local flg = self:playVoiceInQueue()
                if not flg then
                    self:resumeBGM()
                    -- 播放背景音乐时设置为用户设置的音量
                    SoundMng.setBgmVol(bgmVol)
                    SoundMng.setSfxVol(sfxVol)
                end
            end)))
        else
            self.isPlayingVoice = false
            self:playVoiceInQueue()
        end
    end, true, nil, nil, nil, '.mp3')
end


function ZJHDeskController:uploadVoice(uploadPath, callback) --luacheck:ignore
    local http = require('http')
    local data = cc.FileUtils:getInstance():getDataFromFile(uploadPath)
    print('#data is ', #data)
    local opt = {
        host = HOST,
        path = '',
        method = 'POST'
    }

    local req = http.request(opt, function(response)
        local cjson = require('cjson')
        local body = response.body
        body = cjson.decode(body)

        if body and body.success then
            local filename = body.filename
            callback(filename)
        end
    end)
    req:write(data)
    req:done()
end

function ZJHDeskController:showApplyController(show)
    -- self:widgetAction('ApplyController', self.desk)
    if (not show) and self.applyCtrl then
        print("=========> ApplyController del")
        self.applyCtrl:delete()
        self.applyCtrl = false
        return
    end

    if show and not self.applyCtrl then
        self.applyCtrl = true

        local ctrl = Controller:load('ApplyController', self.desk)
        self:add(ctrl)

        app.layers.ui:addChild(ctrl.view)
        -- ctrl.view:setPositionX(display.width)
        -- TranslateView.fadeIn(ctrl.view, -1)
        ctrl:on('back', function()
            -- TranslateView.fadeOut(ctrl.view, 1, function()
            print("=========> ApplyController back")
            ctrl:delete()
            self.applyCtrl = false
            -- end)
        end)
        self.applyCtrl = ctrl
    end
end

function ZJHDeskController:onQuitGame(force)
    -- 退出游戏
    if force or (not self.isDeskSummary) then
        app:switch('LobbyController')
    end
end

function ZJHDeskController:setWidgetAction(controllerName, ...)
    local ctrl = Controller:load(controllerName, ...)
    self:add(ctrl)

    local app = require("app.App"):instance()
    app.layers.ui:addChild(ctrl.view)
    ctrl.view:setPositionX(0)

    ctrl:on('back', function()
        ctrl:delete()
    end)
end

function ZJHDeskController:clickDa()
    if self.desk:isMePlayer() then
        self.desk:setCheatData(1)
    end
end

function ZJHDeskController:clickXiao()
    if self.desk:isMePlayer() then
        self.desk:setCheatData(0)
    end
end

function ZJHDeskController:clickWu()
    if self.desk:isMePlayer() then
        self.desk:setCheatData(3)
    end
end

function ZJHDeskController:setLocationInfo()
    local info = tools.getLocationInfo()
    self.desk:setLocationInfo(info)
end

return ZJHDeskController