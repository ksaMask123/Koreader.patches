-- 2-book-receipt-shortcut-and-lockscreen.lua
-- ============================================================
-- 模块类型：KOReader 运行时补丁（patches）
-- 名称：阅读小票 + 锁屏壁纸（胶片票根 / 墨痕壁纸 二选一随机）
-- 功能：
--   · 手势（QuickLook 分发动作）调出阅读小票，随机 / 轮流展示"胶片票根"或"墨痕壁纸"
--   · 休眠锁屏（screensaver_type = book_receipt）同样支持两样式随机 / 轮流，均可作锁屏壁纸
--   · 小票内小花图标（✿）点击跳转 Reading Insights 阅读洞察插件
--   · 墨痕壁纸引擎整合自 inkstain.koplugin，已彻底剔除 Miuread（觅阅）相关代码，
--     数据源固定为 KOReader 阅读统计，渲染为内存 BlitBuffer（不写盘、无定时器、无网络）
-- 日志 TAG：LOG_TAG = "[BookReceipt]"（全部运行日志写入 crash.log 便于溯源）
-- 依赖：KOReader 核心模块（见 require 列表）+ inkstain.koplugin 的 assets 资源
--       （字体 huiwen_ming.otf、二维码 github_qr.png，缺失时自动降级处理）
-- 适配：Kindle / Kobo / PocketBook / Remarkable / Android 电纸书全系
-- 版本更新：
--   v2.4.5  新增第三种样式「菜单样式」（menu）：UI 布局与墨痕完全一致，表格改为 5 道菜
--           （No.1/2 主菜 + No.3 汤菜 + No.4 饮品 + No.5 甜点，菜谱.txt 全文内嵌解析，
--           分类字样不显示），三行换为 菜名/特色/食材，单价列与合计显示价格并带"元"
--           （合计=5 道菜价格总和）；下单时间（仅当天日期）/点单设备/总计光临本店/用餐时间/
--           菜单/留台单/Order Slip 等文本替换；右下角版权署名统一替换为名人名言三行
--           （名言.txt 全文内嵌，名言/名人/出处，右对齐并与左侧诗句三行水平对齐；
--           内嵌语料解析统一用字面 find/sub 截取，规避 Lua 模式对 UTF-8 的多字节陷阱
--           ——`|` 交替符不生效、`[^...]` 字符类按字节比较会误伤汉字，如“弗”“多”“而”）
--   v2.4.6  菜单样式特色/食材行不再按固定 18/26 字截断：新增 truncateToWidth 按像素宽度
--           截断，充分利用表格右侧空间，同时以 title_w 为硬边界保证不与"数量"栏重叠；
--           右下角名言第一行按标准引用格式显示（中文引号 + 句号"名言。"）
--   v2.4.7  右下角名言出处行统一加书名号《出处》，与左侧诗句作品名行排版一致
--   v2.4.8  右下名言板块字号与左下诗词板块逐行完全一致（名言=诗句 quote_size、
--           名人=朝代·作者 meta_size、出处=作品名 meta_size）；布局测量同步改用
--           实际字号，第一行行距取诗句/名言行较高者，防止长名言行换行压到名人行
--   v2.4.9  墨痕"时长"与菜单"总计光临本店"两处左上角栏位的时间统一换算为以"天"为
--           单位显示（保留 1 位小数，<0.05 天显示"不足1天"，避免"0天/0.0天"歧义）
--   v2.4.10 诗词板块删减：陈毅《梅岭三章（其一）》改为"此去泉台招旧部，旌旗十万斩阎罗。"
--           （其三）改为"取义成仁今日事，人间遍种自由花。"
--   v2.4.5  轮流模式泛化为 N 样式顺序循环（film→inkstain→menu），首次调用回落首样式
--   v2.4.4  墨痕底部布局改为表格锚定：表格区恒按 5 本预留高度（无书/少书时留白、
--           分隔线位置稳定），分隔线紧贴书单底部仅留小缝隙；底部区块整体上移、
--           自顶向下紧凑排列，诗句块不再贴底，屏幕底部自然留白
--   v2.4.3  修复伪二维码成片同色：v2.4.2 的坐标线性哈希使相邻格高度相关，产生
--           一半黑一半白的大色块；改为顺序推进的 Park-Miller 伪随机序列逐格填充，
--           输出天然迷宫状；新增共享生成器 qrDataBitsForGrid 供绘制与测试复用
--   v2.4.2  伪二维码内部迷宫化：以确定性哈希黑白散点取代线性取模斜条纹，
--           并补充真实二维码时序图案（第6行/第6列交替条）；书单序号 NO.→No.
--   v2.4.1  6 寸屏优化：底部边距独立压缩（作品名贴近底边框）、底部区块间距与汇总行间距收紧、
--           表格行高按内容瘦身，墨痕书单在小屏设备上稳定显示 5 本；水平对齐不变、分离机制不变
--   v2.4.0  底部区域响应式重构：二维码/条码行与折线图日期标签行强制分离（先测量后分配，删除事后兜底），
--           图表高度与间距全部随 scale 缩放，大/标准/小屏设备空间占比自适应
--   v2.3.1  版权署名回归右下角，与左下角诗句同一行（同一高度），高于朝代·作者与作品名行
--   v2.3.0  修复墨痕诗句不轮换（改为每次展示顺序推进一首）；尺寸单位"吋"改为"寸"
--   v2.2.0  墨痕页脚诗句库替换为 40 句经典诗词，单行改为三行显示（诗句 / 朝代·作者 / 作品名）
--   v2.1.0  新增样式"轮流出现"模式：与随机并列，手势调出与锁屏共享轮换序列
--   v2.0.2  墨痕样式去除"来源"栏；设备行显示真实设备型号/屏幕尺寸/分辨率/DPI
--   v2.0.1  修复墨痕书单仅显示 4 本（移除 1 分钟门槛）；书名列智能匹配屏幕宽度，书名可显示更长
--   v2.0.0  整合墨痕壁纸引擎，移除 6 种旧卡片样式，保留胶片票根，两样式同池 50% 随机
--   v1.x    原阅读小票（胶片票根 + 6 种卡片样式 + 花朵按钮）
-- ============================================================

local Blitbuffer = require("ffi/blitbuffer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Device = require("device")
local Dispatcher = require("dispatcher")
local Font = require("ui/font")
local FontList = require("fontlist")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local DataStorage = require("datastorage")
local DocumentRegistry = require("document/documentregistry")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local ProgressWidget = require("ui/widget/progresswidget")
local ReaderUI = require("apps/reader/readerui")
local RenderImage = require("ui/renderimage")
local OverlapGroup = require("ui/widget/overlapgroup")
local ScreenSaverWidget = require("ui/widget/screensaverwidget")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local Button = require("ui/widget/button")
local InfoMessage = require("ui/widget/infomessage")
local lfs = require("libs/libkoreader-lfs")
local bit = require("bit")
local datetime = require("datetime")
local logger = require("logger")
local util = require("util")
local ffiUtil = require("ffi/util")
local SQ3 = require("lua-ljsqlite3/init")
local _ = require("gettext")

-- 日志溯源专用 TAG：所有日志统一前缀，便于在 crash.log 中检索定位本模块
local LOG_TAG = "[BookReceipt]"

-- ========== 汉化翻译表 ==========
do
    local zh_translations = {
        ["%1 et al."] = "%1 等",
        ["Page %s"] = "第%s页",
        ["Receipt unavailable"] = "无法显示阅读摘要",
        ["Book receipt"] = "阅读摘要",
        ["Show book receipt on sleep screen"] = "在休眠屏幕显示阅读摘要",
        ["Background"] = "背景",
        ["White fill"] = "白色背景",
        ["Transparent"] = "透明",
        ["Black fill"] = "黑色背景",
        ["Random image"] = "随机图片",
        ["Book cover"] = "书籍封面",
        ["Background image placement"] = "背景图片显示方式",
        ["Fit to screen"] = "适应屏幕",
        ["Stretch to screen"] = "拉伸填满屏幕",
        ["Center without scaling"] = "居中（不缩放）",
        ["Content"] = "内容",
        ["Book receipt (default)"] = "阅读摘要（默认）",
        ["Highlight + progress"] = "高亮与进度",
        ["Random"] = "随机",
        ["Cover scale"] = "封面缩放",
        ["Cover scale (default: 1.0)\nSet to 0 to hide cover"] = "封面缩放（默认：1.0）\n设置为0以隐藏封面",
        ["Cancel"] = "取消",
        ["Set"] = "确定",
        ["Sleep message"] = "设置休眠状态显示的文字",
        ["Book receipt settings"] = "阅读摘要设置",
        ["Style"] = "显示风格",
        -- 墨痕壁纸相关（新增）
        ["Ink stain"] = "墨痕壁纸",
        ["Order Slip"] = "留台单", -- 菜单样式名（-- 修改：v2.4.5）
        ["Ink stain settings"] = "墨痕壁纸设置",
        ["Statistics period"] = "统计周期",
        ["Today"] = "今天",
        ["Last 7 days"] = "最近 7 天",
        ["Last 30 days"] = "最近 30 天",
        ["Book list size"] = "书单数量",
        ["Film strip (fixed style)"] = "胶片票根（固定风格）",
        ["BOOK RECEIPT"] = "阅读摘要",
        ["READING PROGRESS"] = "阅读进度",
        ["NOW READING"] = "当前阅读",
        ["calculating time"] = "计算中",
        ["hr"] = "小时",
        ["hrs"] = "小时",
        ["min"] = "分钟",
        ["mins"] = "分钟",
        ["less than a minute"] = "不足一分钟",
        ["Total time spent: %s"] = "累计阅读时间：%s",
        ["Time spent today (%s): %s"] = "今日阅读时间（%s）：%s",
        ["page %s of %s"] = "第%s页 / 共%s页",
        ["Book"] = "书籍",
        ["Chapter"] = "章节",
        ["%s left in %s"] = "%s 剩余 %s",
        ["Monday"] = "周一",
        ["Tuesday"] = "周二",
        ["Wednesday"] = "周三",
        ["Thursday"] = "周四",
        ["Friday"] = "周五",
        ["Saturday"] = "周六",
        ["Sunday"] = "周日",
        ["Randomize style each time"] = "随机出现",
        ["When enabled, a random style will be used each time the receipt is shown (instead of the fixed one)."] = "开启后，每次显示小票时将从所有样式中随机选择一种（取代固定的样式）。",
        ["Alternate style each time"] = "轮流出现",
        ["When enabled, styles will be alternated each time the receipt is shown (instead of a fixed one)."] = "开启后，每次显示小票时将在不同样式中轮流切换（取代固定的样式）。",
        ["Film strip (fixed style)"] = "胶片票根（固定风格）",
        -- 胶片版特有硬编码翻译
        ["CURRENT PAGE"] = "当前页码",
        ["READ"] = "已读",
        ["TODAY"] = "今日",
        ["MIN"] = "分钟",
        ["HR"] = "小时",
        ["BOOK_RECEIPT // SLEEP_MODE"] = "阅读摘要 // 休眠模式",
        ["title: "] = "书名：",
        ["author: "] = "作者：",
        ["chapter: "] = "章节：",
        ["status: reading (%s / %s p)"] = "状态：阅读中（%s / %s 页）",
        ["READING TICKET"] = "阅读票根",
        ["NO. %04d"] = "编号 %04d",
        ["ADMITTED"] = "已入场",
        ["PAGE"] = "页码",
        ["TIME TODAY"] = "今日时间",
        ["KEEP THIS TICKET FOR YOUR NEXT SESSION"] = "请保留此票根，下次继续阅读",
        ["PERCENT"] = "百分比",
    }
    local orig__ = _
    _ = function(s)
        if type(s) == "string" and zh_translations[s] then return zh_translations[s] end
        return orig__(s)
    end
    _G._ = _
end

local Screen = Device.screen
local T = ffiUtil.template

-- ========== 设置项常量 ==========
local K = {
    -- 背景设置（胶片票根 / 墨痕壁纸共用）
    BG_SETTING = "book_receipt_screensaver_background",
    BG_IMAGE_MODE_SETTING = "book_receipt_bg_image_mode",
    -- 胶片票根内容模式
    CONTENT_MODE_SETTING = "book_receipt_content_mode",
    COVER_SCALE_SETTING = "book_receipt_cover_scale",
    -- 显示样式（胶片票根 / 墨痕壁纸）
    STYLE_SETTING = "book_receipt_style",
    RANDOM_STYLE = "book_receipt_random_style",
    STYLE_MODE_SETTING = "book_receipt_style_mode",          -- 出现方式：fixed 固定 / random 随机 / alternate 轮流
    STYLE_TOGGLE_STATE = "book_receipt_style_toggle_state",  -- 轮流模式当前状态（上次展示的样式，跨手势/锁屏共享）
    QUOTE_TOGGLE_STATE = "book_receipt_quote_toggle_state",  -- 诗句轮换当前序号（每次展示推进，手势/锁屏共享）
    SLEEP_TEXT = "book_receipt_sleep_text",   -- 胶片版专用
    -- 墨痕壁纸专属设置（配置键统一带 book_receipt_ 前缀，避免全局键冲突）
    INKSTAIN_DAYS = "book_receipt_inkstain_days",     -- 统计周期（天）
    INKSTAIN_TOP_N = "book_receipt_inkstain_top_n",   -- 书单数量 Top N

    MAX_HIGHLIGHT_SIZE = 500,
    HIDE_COVER_FOR_LARGE_HIGHLIGHTS = 300,

    CONTENT_MODE_BOOK_RECEIPT = "book_receipt",
    CONTENT_MODE_HIGHLIGHT_PROGRESS = "highlight_progress",
    CONTENT_MODE_RANDOM = "random",

    STYLE_FILM = "film",       -- 胶片票根
    STYLE_INKSTAIN = "inkstain", -- 墨痕壁纸（整合自 inkstain.koplugin）
    STYLE_MENU = "menu",       -- 菜单样式（留台单，-- 修改：v2.4.5 新增第三种样式）
}

-- ========== 通用辅助函数 ==========
local function utf8TrimToLength(str, max_chars)
    if not str or max_chars <= 0 then
        return "", 0, str ~= nil and str ~= ""
    end
    local len = #str
    local index = 1
    local char_count = 0
    local cut_index
    while index <= len do
        local byte = string.byte(str, index)
        if not byte then break end
        local char_len = 1
        if byte >= 0xF0 then
            char_len = 4
        elseif byte >= 0xE0 then
            char_len = 3
        elseif byte >= 0xC0 then
            char_len = 2
        end
        char_count = char_count + 1
        index = index + char_len
        if not cut_index and char_count == max_chars + 1 then
            cut_index = index - char_len
        end
    end
    if cut_index then
        return str:sub(1, cut_index - 1), char_count, true
    end
    return str, char_count, false
end

local function getWeightedTruncatedString(str, max_weight)
    if not str or str == "" then return "", false end
    local current_weight = 0
    local len = #str
    local i = 1
    while i <= len do
        local byte = string.byte(str, i)
        local char_len = 1
        local weight = 1
        if byte >= 0xF0 then
            char_len = 4
            weight = 2
        elseif byte >= 0xE0 then
            char_len = 3
            weight = 2
        elseif byte >= 0xC0 then
            char_len = 2
            weight = 2
        end
        if current_weight + weight > max_weight then
            return string.sub(str, 1, i - 1) .. "...", true
        end
        current_weight = current_weight + weight
        i = i + char_len
    end
    return str, false
end

local function getLocalizedDayName(timestamp)
    local day_key = timestamp and os.date("%A", timestamp)
    if not day_key then return "" end
    if datetime and datetime.longDayTranslation and datetime.longDayTranslation[day_key] then
        return datetime.longDayTranslation[day_key]
    end
    return _(day_key)
end

local function getBookTodayDuration(statistics)
    if not statistics then return nil end
    if statistics.isEnabled and not statistics:isEnabled() then return nil end
    if statistics.insertDB then pcall(statistics.insertDB, statistics) end
    local id_book = statistics.id_curr_book
    if (not id_book) and statistics.getIdBookDB then
        local ok, book_id = pcall(statistics.getIdBookDB, statistics)
        if ok then id_book = book_id end
    end
    if not id_book then return nil end
    local STATISTICS_DB_PATH = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    local attrs = lfs.attributes(STATISTICS_DB_PATH, "mode")
    if attrs ~= "file" then return nil end
    local now_stamp = os.time()
    local now_t = os.date("*t", now_stamp)
    local from_begin_day = now_t.hour * 3600 + now_t.min * 60 + now_t.sec
    local start_today_time = now_stamp - from_begin_day
    local ok_conn, conn = pcall(SQ3.open, STATISTICS_DB_PATH)
    if not ok_conn or not conn then return nil end
    local sql_stmt = string.format([[SELECT sum(sum_duration)
        FROM (
            SELECT sum(duration) AS sum_duration
            FROM page_stat
            WHERE start_time >= %d AND id_book = %d
            GROUP BY page
        );
    ]], start_today_time, id_book)
    local ok_row, today_duration = pcall(function() return conn:rowexec(sql_stmt) end)
    conn:close()
    if not ok_row or today_duration == nil then return nil end
    today_duration = tonumber(today_duration)
    if not today_duration then return nil end
    if today_duration < 0 then today_duration = 0 end
    return today_duration
end

local function getRandomHighlightAnnotation(ui)
    if not ui or not ui.annotation or not ui.annotation.annotations then return nil end
    local candidates = {}
    for _, item in ipairs(ui.annotation.annotations) do
        if item.drawer and item.text then
            local trimmed = util.trim(item.text)
            if trimmed ~= "" then table.insert(candidates, item) end
        end
    end
    if #candidates == 0 then return nil end
    return candidates[math.random(#candidates)]
end

local function getBookReceiptBackgroundDir()
    local base_dir = DataStorage:getDataDir()
    if not base_dir or base_dir == "" then return nil end
    return string.format("%s/%s", base_dir, "book_receipt_background")
end

local function pickRandomReceiptBackgroundImage()
    local dir = getBookReceiptBackgroundDir()
    if not dir or lfs.attributes(dir, "mode") ~= "directory" then return nil end
    local files = {}
    util.findFiles(dir, function(file)
        if not util.stringStartsWith(ffiUtil.basename(file), "._") and DocumentRegistry:isImageFile(file) then
            table.insert(files, file)
        end
    end, false, 512)
    if #files == 0 then return nil end
    return files[math.random(#files)]
end

local function buildBackgroundImageWidget(image_source)
    if not image_source then return nil end
    local mode = G_reader_settings:readSetting(K.BG_IMAGE_MODE_SETTING) or "stretch"
    if mode ~= "center" and mode ~= "stretch" and mode ~= "fit" then mode = "stretch" end
    local screen_size = Screen:getSize()
    local screen_w, screen_h = screen_size.w, screen_size.h
    local image_opts = { alpha = true, file_do_cache = false }
    if type(image_source) == "string" then image_opts.file = image_source else image_opts.image = image_source end
    if mode == "stretch" then
        image_opts.width = screen_w; image_opts.height = screen_h
    elseif mode == "fit" then
        image_opts.width = screen_w; image_opts.height = screen_h; image_opts.scale_factor = 0
    end
    local image_widget = ImageWidget:new(image_opts)
    if mode == "center" then
        return CenterContainer:new{ dimen = screen_size, image_widget }
    end
    return image_widget
end

local function getActiveDocumentCover(ui)
    if not ui or not ui.document or not ui.bookinfo then return nil end
    return ui.bookinfo:getCoverImage(ui.document)
end

local function getReceiptBackground(ui)
    local choice = G_reader_settings:readSetting(K.BG_SETTING) or "white"
    if choice == "transparent" then return nil, nil
    elseif choice == "black" then return Blitbuffer.COLOR_BLACK, nil
    elseif choice == "random_image" then
        local image_path = pickRandomReceiptBackgroundImage()
        if image_path then
            local widget = buildBackgroundImageWidget(image_path)
            if widget then return nil, widget end
        end
        return nil, nil
    elseif choice == "book_cover" then
        local cover_bb = getActiveDocumentCover(ui)
        if cover_bb then
            local widget = buildBackgroundImageWidget(cover_bb)
            if widget then return nil, widget end
        end
        return nil, nil
    end
    return Blitbuffer.COLOR_WHITE, nil
end

local function hasActiveDocument(ui)
    return ui and ui.document ~= nil
end

local function getBookReceiptFallbackType()
    local random_dir = G_reader_settings:readSetting("screensaver_dir")
    if random_dir and lfs.attributes(random_dir, "mode") == "directory" then return "random_image" end
    local document_cover = G_reader_settings:readSetting("screensaver_document_cover")
    if document_cover and lfs.attributes(document_cover, "mode") == "file" then return "document_cover" end
    local lastfile = G_reader_settings:readSetting("lastfile")
    if lastfile and lfs.attributes(lastfile, "mode") == "file" then return "cover" end
    return "random_image"
end

local function getEventFromPrefix(prefix)
    if prefix and prefix ~= "" then return prefix:sub(1, -2) end
    return nil
end

local function showFallbackScreensaver(self, orig_show)
    local fallback_type = getBookReceiptFallbackType()
    local original_type = self.screensaver_type
    local event = getEventFromPrefix(self.prefix)
    local settings = G_reader_settings
    local primary_key = "screensaver_type"
    local had_primary = settings:has(primary_key)
    local original_primary = settings:readSetting(primary_key)
    settings:saveSetting(primary_key, fallback_type)
    local prefixed_key = self.prefix and self.prefix ~= "" and (self.prefix .. "screensaver_type") or nil
    local had_prefixed, original_prefixed
    if prefixed_key then
        had_prefixed = settings:has(prefixed_key)
        original_prefixed = settings:readSetting(prefixed_key)
        settings:saveSetting(prefixed_key, fallback_type)
    end
    self:setup(event, self.event_message)
    self.screensaver_type = fallback_type
    orig_show(self)
    if prefixed_key then
        if had_prefixed then settings:saveSetting(prefixed_key, original_prefixed) else settings:delSetting(prefixed_key) end
    end
    if had_primary then settings:saveSetting(primary_key, original_primary) else settings:delSetting(primary_key) end
    self.screensaver_type = original_type
end

-- ========== 样式工具 ==========
-- 历史遗留的样式名（editorial/dashboard/receipt）一律归入胶片票根，
-- 当前支持三种样式：胶片票根 / 墨痕壁纸 / 菜单样式（留台单），三者同池随机。
local function normalizeReceiptStyle(value)
    if value == "editorial" or value == "dashboard" or value == "receipt" then
        -- 旧版卡片样式已移除，统一收敛为胶片票根（film）
        return K.STYLE_FILM
    elseif value == K.STYLE_FILM or value == K.STYLE_INKSTAIN or value == K.STYLE_MENU then
        return value
    end
    -- 未知样式默认回退为胶片票根，保证任何脏配置都不会崩溃
    return K.STYLE_FILM
end

-- 随机池包含胶片票根 + 墨痕壁纸 + 菜单样式（-- 修改：v2.4.5 新增菜单样式）
local function getAllStyles()
    return {
        K.STYLE_FILM,
        K.STYLE_INKSTAIN,
        K.STYLE_MENU,
    }
end

-- 读取样式出现方式（fixed 固定 / random 随机 / alternate 轮流）
local function getStyleMode()
    local mode = G_reader_settings:readSetting(K.STYLE_MODE_SETTING)
    if mode == "random" or mode == "alternate" or mode == "fixed" then
        return mode
    end
    -- 旧版兼容：v2.0.x 的随机开关（book_receipt_random_style）若为开，视为随机模式
    if G_reader_settings:isTrue(K.RANDOM_STYLE) then
        return "random"
    end
    return "fixed"
end

-- 轮流模式：返回当前应展示的样式，并将轮换状态推进到下一个
-- 状态持久化于 G_reader_settings，手势调出与锁屏共享同一轮换序列
-- （-- 修改：v2.4.5 由「首尾二样式互切」泛化为「N 个样式顺序循环」，支持 3 样式）
local function getAlternateStyleAndAdvance()
    local styles = getAllStyles()
    local cur = G_reader_settings:readSetting(K.STYLE_TOGGLE_STATE)
    local idx = 1
    for i, s in ipairs(styles) do
        if s == cur then idx = i break end
    end
    if styles[idx] ~= cur then
        idx = 1 -- 首次使用或脏数据：从胶片票根开始
        cur = styles[1] -- 本次展示回落到首样式（否则首次调用会返回 nil，破坏轮流序列）
    end
    -- 推进到下一个样式（尾元素回绕到首个），保存后返回本次应展示的样式
    local next_style = styles[(idx % #styles) + 1]
    G_reader_settings:saveSetting(K.STYLE_TOGGLE_STATE, next_style)
    return cur
end

-- 依据出现方式返回本次应展示的样式：固定 / 随机 / 轮流
local function getEffectiveStyle()
    local mode = getStyleMode()
    if mode == "random" then
        local styles = getAllStyles()
        return styles[math.random(#styles)]
    elseif mode == "alternate" then
        return getAlternateStyleAndAdvance()
    else
        return normalizeReceiptStyle(G_reader_settings:readSetting(K.STYLE_SETTING))
    end
end

-- ========== 胶片版专用构建函数（独立，不受全局样式设置影响） ==========
local function buildFilmReceipt(ui, state, on_close_callback)
    if not hasActiveDocument(ui) then return nil end

    -- 复用部分数据获取（与主函数保持一致）
    local doc_props = ui.doc_props or {}
    local book_title = doc_props.display_title or ""
    local book_author = doc_props.authors or ""
    if book_author:find("\n") then
        local authors = util.splitToArray(book_author, "\n")
        if authors and authors[1] then
            book_author = T(_("%1 等"), authors[1] .. ",")
        end
    end
    local doc_settings = ui.doc_settings and ui.doc_settings.data or {}
    local doc_page_no = (state and state.page) or 1
    local doc_page_total = doc_settings.doc_pages or 1
    if doc_page_total <= 0 then doc_page_total = 1 end
    if doc_page_no < 1 then doc_page_no = 1 end
    if doc_page_no > doc_page_total then doc_page_no = doc_page_total end
    local page_no_numeric = doc_page_no
    local page_total_numeric = doc_page_total
    local page_no_display = tostring(page_no_numeric)
    local page_total_display = tostring(page_total_numeric)

    if ui.pagemap and ui.pagemap:wantsPageLabels() then
        local label, idx, count = ui.pagemap:getCurrentPageLabel(true)
        local last_label = ui.pagemap:getLastPageLabel(true)
        if idx and count then page_no_numeric = idx; page_total_numeric = count end
        if label and label ~= "" then page_no_display = label else page_no_display = tostring(page_no_numeric) end
        if last_label and last_label ~= "" then page_total_display = last_label else page_total_display = tostring(page_total_numeric) end
    end

    local page_left = math.max(page_total_numeric - page_no_numeric, 0)
    local toc = ui.toc
    local chapter_title = ""; local chapter_total = page_total_numeric; local chapter_left = 0; local chapter_done = 0
    if toc then
        chapter_title = toc:getTocTitleByPage(doc_page_no) or ""
        chapter_total = toc:getChapterPageCount(doc_page_no) or chapter_total
        chapter_left = toc:getChapterPagesLeft(doc_page_no) or 0
        chapter_done = toc:getChapterPagesDone(doc_page_no) or 0
    end
    chapter_total = chapter_total > 0 and chapter_total or page_total_numeric
    chapter_done = math.max(chapter_done + 1, 1)

    local statistics = ui.statistics
    local avg_time_per_page = statistics and statistics.avg_time
    local function secs_to_timestring(secs)
        if not secs then return "正在计算时间" end
        local h = math.floor(secs / 3600); local m = math.floor((secs % 3600) / 60)
        local htext = "小时"; local mtext = "分钟"
        if h == 0 and m > 0 then return string.format("%i%s", m, mtext)
        elseif h > 0 and m == 0 then return string.format("%i%s", h, htext)
        elseif h > 0 and m > 0 then return string.format("%i%s %i%s", h, htext, m, mtext)
        elseif h == 0 and m == 0 then return "少于一分钟" end
        return "正在计算时间"
    end
    local function time_left(pages)
        if not avg_time_per_page then return nil end
        return avg_time_per_page * pages
    end
    local book_time_left = secs_to_timestring(time_left(page_left))
    local chapter_time_left = secs_to_timestring(time_left(chapter_left))
    local current_time = datetime.secondsToHour(os.time(), G_reader_settings:isTrue("twelve_hour_clock")) or ""
    local battery = ""
    if Device:hasBattery() then
        local power_dev = Device:getPowerDevice()
        local batt_lvl = power_dev:getCapacity() or 0
        local is_charging = power_dev:isCharging() or false
        local batt_prefix = power_dev:getBatterySymbol(power_dev:isCharged(), is_charging, batt_lvl) or ""
        battery = batt_prefix .. batt_lvl .. "%"
    end

    -- 胶片版自身参数（与多风格版隔离）
    local widget_width = math.floor(Screen:getWidth() * 0.68)
    local db_font_color = Blitbuffer.COLOR_BLACK
    local db_font_color_lighter = Blitbuffer.COLOR_GRAY_3
    local db_font_color_lightest = Blitbuffer.COLOR_GRAY_9
    local db_font_face = "NotoSans-Regular.ttf"
    local db_font_face_italics = "NotoSans-Italic.ttf"
    local db_font_size_huge = 64; local db_font_size_big = 28; local db_font_size_mid = 21; local db_font_size_small = 16
    local db_padding = 20; local db_padding_internal = 8

    -- 屏保留言
    local message_text
    if Device.screen_saver_mode and G_reader_settings:isTrue("screensaver_show_message") then
        local configured_message = G_reader_settings:readSetting("screensaver_message")
        configured_message = configured_message and util.trim(configured_message)
        if configured_message and configured_message ~= "" then
            if ui and ui.bookinfo and ui.bookinfo.expandString then
                message_text = ui.bookinfo:expandString(configured_message) or configured_message
            else
                message_text = configured_message
            end
            if message_text then message_text = util.trim(message_text); if message_text == "" then message_text = nil end end
        end
    end

    -- 进度数据盒子（与胶片版原有逻辑一致）
    local function databox(typename, itemname, pages_done, pages_total, time_left_text, pages_done_display, pages_total_display, options)
        options = options or {}
        local pages_done_num = tonumber(pages_done) or 0
        local pages_total_num = tonumber(pages_total) or 0
        local denom = pages_total_num > 0 and pages_total_num or 1
        local percentage_value = math.max(math.min(pages_done_num / denom, 1), 0)
        local display_done = pages_done_display or pages_done
        local display_total = pages_total_display or pages_total
        local elements = {}
        local progress_side_padding = Screen:scaleBySize(30)
        local progressbarwidth = widget_width - (progress_side_padding * 2)

        if not options.hide_title then
            local MAX_WEIGHT = 28
            local safe_text, was_truncated = getWeightedTruncatedString(itemname, MAX_WEIGHT)
            local adaptive_size = db_font_size_mid
            if was_truncated then adaptive_size = math.floor(db_font_size_mid * 0.9) end
            local title_widget = TextWidget:new{
                face = Font:getFace(db_font_face, adaptive_size),
                text = safe_text,
                fgcolor = db_font_color,
                align = "left",
            }
            local title_right_w = widget_width - progress_side_padding - title_widget:getSize().w
            if title_right_w < 0 then title_right_w = 0 end
            table.insert(elements, HorizontalGroup:new{
                HorizontalSpan:new{ width = progress_side_padding },
                title_widget,
                HorizontalSpan:new{ width = title_right_w },
            })
            table.insert(elements, VerticalSpan:new{ width = Screen:scaleBySize(4) })
        end

        if not options.hide_time and time_left_text then
            local time_text_widget = TextWidget:new{
                text = string.format("%s还需 %s", typename, time_left_text),
                face = Font:getFace(db_font_face_italics, db_font_size_small),
                bold = false,
                fgcolor = db_font_color_lighter,
                padding = 0,
                align = "left",
            }
            local right_space_w = widget_width - progress_side_padding - time_text_widget:getSize().w
            if right_space_w < 0 then right_space_w = 0 end
            table.insert(elements, HorizontalGroup:new{
                HorizontalSpan:new{ width = progress_side_padding },
                time_text_widget,
                HorizontalSpan:new{ width = right_space_w },
            })
            table.insert(elements, VerticalSpan:new{ width = Screen:scaleBySize(6) })
        end

        local progress_bar = ProgressWidget:new{
            width = progressbarwidth, height = Screen:scaleBySize(6),
            percentage = percentage_value, margin_v = 0, margin_h = 0,
            radius = 20, bordersize = 0,
            bgcolor = db_font_color_lightest, fillcolor = db_font_color,
        }
        table.insert(elements, HorizontalGroup:new{
            HorizontalSpan:new{ width = progress_side_padding },
            progress_bar,
            HorizontalSpan:new{ width = progress_side_padding },
        })
        table.insert(elements, VerticalSpan:new{ width = Screen:scaleBySize(6) })

        local page_progress = TextWidget:new{
            text = string.format("第 %s 页 / 共 %s 页", display_done, display_total),
            face = Font:getFace("cfont", db_font_size_small),
            bold = false, fgcolor = db_font_color_lighter, padding = 0, align = "left",
        }
        local percentage_display = TextWidget:new{
            text = string.format("%i%%", math.floor(percentage_value * 100 + 0.5)),
            face = Font:getFace("cfont", db_font_size_small),
            bold = false, fgcolor = db_font_color_lighter, padding = 0, align = "right",
        }
        table.insert(elements, HorizontalGroup:new{
            HorizontalSpan:new{ width = progress_side_padding },
            page_progress,
            HorizontalSpan:new{ width = progressbarwidth - page_progress:getSize().w - percentage_display:getSize().w },
            percentage_display,
            HorizontalSpan:new{ width = progress_side_padding },
        })
        table.insert(elements, VerticalSpan:new{ width = db_padding_internal })
        return VerticalGroup:new(elements)
    end

    local batt_pct_box = TextWidget:new{ text = battery, face = Font:getFace("cfont", db_font_size_small), bold = false, fgcolor = db_font_color, padding = 0 }
    local glyph_clock = "⌚"
    local time_box = TextWidget:new{ text = string.format("%s%s", glyph_clock, current_time), face = Font:getFace("cfont", db_font_size_small), bold = false, fgcolor = db_font_color, padding = 0 }
    local bottom_bar_inner = HorizontalGroup:new{ batt_pct_box, HorizontalSpan:new{ width = db_padding }, time_box }
    local bottom_bar = CenterContainer:new{ dimen = Geom:new{ w = widget_width, h = bottom_bar_inner:getSize().h }, bottom_bar_inner }

    local bookboxtitle = "总进度"

    local content_mode_setting = G_reader_settings:readSetting(K.CONTENT_MODE_SETTING) or K.CONTENT_MODE_BOOK_RECEIPT
    local content_mode = content_mode_setting
    if content_mode_setting == K.CONTENT_MODE_RANDOM then
        local candidates = { K.CONTENT_MODE_BOOK_RECEIPT, K.CONTENT_MODE_HIGHLIGHT_PROGRESS }
        content_mode = candidates[math.random(#candidates)]
    end

    local book_total_time_text, book_today_time_text
    if statistics and content_mode ~= K.CONTENT_MODE_HIGHLIGHT_PROGRESS then
        book_total_time_text = string.format("全书已阅读：%s", secs_to_timestring(statistics.book_read_time))
        local today_duration = getBookTodayDuration(statistics)
        if today_duration then
            local day_label = getLocalizedDayName(os.time())
            book_today_time_text = string.format("今天阅读 (%s)：%s", day_label, secs_to_timestring(today_duration))
        end
    end

    local bookbox = databox("全书", bookboxtitle, page_no_numeric, page_total_numeric, book_time_left, page_no_display, page_total_display, {
        hide_title = content_mode == K.CONTENT_MODE_HIGHLIGHT_PROGRESS,
        hide_time = content_mode == K.CONTENT_MODE_HIGHLIGHT_PROGRESS,
    })
    local chapterbox = content_mode ~= K.CONTENT_MODE_HIGHLIGHT_PROGRESS and databox("本章", chapter_title, chapter_done, chapter_total, chapter_time_left) or nil

    local bg_choice = G_reader_settings:readSetting(K.BG_SETTING)
    local show_cover = not (Device.screen_saver_mode and bg_choice == "book_cover")
    local top_split_widget = nil

    if show_cover and ui.bookinfo and ui.document then
        local cover_bb = ui.bookinfo:getCoverImage(ui.document)
        if cover_bb then
            local cover_scale = G_reader_settings:readSetting(K.COVER_SCALE_SETTING) or 1
            local cover_width = cover_bb:getWidth(); local cover_height = cover_bb:getHeight()
            local target_width_ratio = 0.25
            local max_width = math.floor(widget_width * target_width_ratio * cover_scale)
            local max_height = math.floor(Screen:getHeight() / 5 * cover_scale)
            local scale = math.min(1, max_width / cover_width, max_height / cover_height)
            if scale < 1 then
                local scaled_w = math.max(1, math.floor(cover_width * scale)); local scaled_h = math.max(1, math.floor(cover_height * scale))
                cover_bb = RenderImage:scaleBlitBuffer(cover_bb, scaled_w, scaled_h, true)
                cover_width = cover_bb:getWidth(); cover_height = cover_bb:getHeight()
            end
            local cover_image_widget = ImageWidget:new{ image = cover_bb, width = cover_width, height = cover_height }
            local framed_cover = FrameContainer:new{ radius = 15, bordersize = 2, padding = 0, background = Blitbuffer.COLOR_WHITE, cover_image_widget }
            local now_t = os.time(); local cal_day = os.date("%d", now_t); local cal_year_month = os.date("%Y.%m", now_t); local cal_weekday = getLocalizedDayName(now_t)
            local font_scale = (cover_scale and cover_scale > 0.1) and cover_scale or 1
            local f_size_small = math.floor(db_font_size_small * font_scale); local f_size_huge = math.floor(db_font_size_huge * font_scale); local f_size_mid = math.floor(db_font_size_mid * font_scale)
            local gap_size = 0
            if Device.screen_saver_mode then
                cal_year_month = os.date("%m.%d", now_t)
                cal_day = G_reader_settings:readSetting(K.SLEEP_TEXT) or "休眠中"
                f_size_huge = math.floor(28 * font_scale); gap_size = math.floor(30 * font_scale)
            end
            local f_size_deco = math.floor(10 * font_scale); local span_deco_h = math.floor(4 * font_scale)
            local calendar_group = VerticalGroup:new{
                align = "center",
                TextWidget:new{ text = cal_year_month, face = Font:getFace("cfont", f_size_small), fgcolor = db_font_color_lighter },
                VerticalSpan:new{ width = gap_size },
                TextWidget:new{ text = cal_day, face = Font:getFace("cfont", f_size_huge), bold = true, fgcolor = db_font_color, padding = 0 },
                VerticalSpan:new{ width = gap_size },
                TextWidget:new{ text = cal_weekday, face = Font:getFace("cfont", f_size_mid), fgcolor = db_font_color },
            }
            local deco_group = nil; local deco_w = 0
            if cover_scale < 2 then
                local deco_elements = {}
                local deco_count = 8
                for i = 1, deco_count do
                    table.insert(deco_elements, TextWidget:new{ text = "|", face = Font:getFace("cfont", f_size_deco), fgcolor = db_font_color_lighter, padding = 0 })
                    if i < deco_count then table.insert(deco_elements, VerticalSpan:new{ width = span_deco_h }) end
                end
                deco_group = VerticalGroup:new(deco_elements); deco_w = deco_group:getSize().w
            end
            local available_side_width = math.floor((widget_width - deco_w) / 2)
            local section_height = math.max(framed_cover:getSize().h, calendar_group:getSize().h)
            local left_area = CenterContainer:new{ dimen = Geom:new{ w = available_side_width, h = section_height }, framed_cover }
            local right_area = CenterContainer:new{ dimen = Geom:new{ w = available_side_width, h = section_height }, calendar_group }
            local top_group_elements = { left_area }
            if deco_group then
                 local center_area = CenterContainer:new{ dimen = Geom:new{ w = deco_w, h = section_height }, deco_group }
                table.insert(top_group_elements, center_area)
            end
            table.insert(top_group_elements, right_area)
            top_split_widget = HorizontalGroup:new(top_group_elements)
        end
    end

    local content_children = {}
    local full_ticket_width = widget_width + (db_padding * 2)
    table.insert(content_children, HorizontalSpan:new{ width = full_ticket_width })

    local highlight_widgets
    local highlight_length = 0
    if content_mode == K.CONTENT_MODE_HIGHLIGHT_PROGRESS then
        local highlight_item = getRandomHighlightAnnotation(ui)
        if highlight_item then
            local highlight_text = util.trim(highlight_item.text or "")
            if highlight_text ~= "" then
                local truncated_text, char_count, was_truncated = utf8TrimToLength(highlight_text, K.MAX_HIGHLIGHT_SIZE)
                highlight_length = char_count
                if was_truncated then truncated_text = truncated_text .. "..." end
                local meta_parts = {}
                if highlight_item.chapter and highlight_item.chapter ~= "" then table.insert(meta_parts, highlight_item.chapter) end
                local highlight_page = highlight_item.pageref or highlight_item.pageno
                if not highlight_page and highlight_item.page and type(highlight_item.page) == "string" and ui.document and ui.document.getPageFromXPointer then
                    local ok, page_from_xp = pcall(ui.document.getPageFromXPointer, ui.document, highlight_item.page)
                    if ok then highlight_page = page_from_xp end
                end
                if highlight_page then
                    local page_label
                    if type(highlight_page) == "number" then page_label = string.format("%s %s", _("页码"), tostring(highlight_page)) else page_label = highlight_page end
                    table.insert(meta_parts, page_label)
                end
                if #meta_parts > 0 then
                    highlight_widgets = {
                        TextBoxWidget:new{ face = Font:getFace("cfont", db_font_size_big), text = truncated_text, width = widget_width, fgcolor = db_font_color, bold = true, alignment = "center" },
                        VerticalSpan:new{ width = db_padding_internal },
                        TextWidget:new{ text = string.format("(%s)", table.concat(meta_parts, ", ")), face = Font:getFace("cfont", db_font_size_small), bold = false, fgcolor = db_font_color_lighter, padding = 0, align = "center" },
                    }
                else
                    highlight_widgets = { TextBoxWidget:new{ face = Font:getFace("cfont", db_font_size_big), text = truncated_text, width = widget_width, fgcolor = db_font_color, bold = true, alignment = "center" } }
                end
            end
        end
        if not highlight_widgets then content_mode = K.CONTENT_MODE_BOOK_RECEIPT end
    end

    if content_mode == K.CONTENT_MODE_BOOK_RECEIPT then
        show_cover = not (Device.screen_saver_mode and bg_choice == "book_cover")
    else
        if bg_choice == "book_cover" or highlight_length > K.HIDE_COVER_FOR_LARGE_HIGHLIGHTS then show_cover = false end
    end

    -- 胶片组件
    local FilmStripTitle = FrameContainer:extend{
        background = Blitbuffer.COLOR_BLACK,
        bordersize = 0,
        padding = 0,
        margin = 0,
        title_text = "READING TICKET",
        title_font_size = 36,
    }
    function FilmStripTitle:init()
        local w = self.width
        local hole_size = Screen:scaleBySize(5)
        local hole_gap = Screen:scaleBySize(5)
        local available_w = w - (hole_gap * 2)
        local num_holes = math.floor((available_w + hole_gap) / (hole_size + hole_gap))
        if num_holes < 1 then num_holes = 1 end
        local function createHole()
            return FrameContainer:new{
                bordersize = 0,
                padding_left = hole_size,
                padding_top = hole_size,
                padding_right = 0,
                padding_bottom = 0,
                background = Blitbuffer.COLOR_WHITE,
                HorizontalSpan:new{ width = 0 }
            }
        end
        local top_holes = {}; local bottom_holes = {}
        table.insert(top_holes, HorizontalSpan:new{ width = hole_gap })
        table.insert(bottom_holes, HorizontalSpan:new{ width = hole_gap })
        for i = 1, num_holes do
            table.insert(top_holes, createHole())
            table.insert(bottom_holes, createHole())
            if i < num_holes then
                table.insert(top_holes, HorizontalSpan:new{ width = hole_gap })
                table.insert(bottom_holes, HorizontalSpan:new{ width = hole_gap })
            end
        end
        table.insert(top_holes, HorizontalSpan:new{ width = hole_gap })
        table.insert(bottom_holes, HorizontalSpan:new{ width = hole_gap })
        local top_row = CenterContainer:new{ dimen = Geom:new{ w = w, h = hole_size }, HorizontalGroup:new(top_holes) }
        local bottom_row = CenterContainer:new{ dimen = Geom:new{ w = w, h = hole_size }, HorizontalGroup:new(bottom_holes) }
        local title_widget = TextWidget:new{
            text = self.title_text,
            face = Font:getFace("cfont", self.title_font_size),
            bold = true,
            fgcolor = Blitbuffer.COLOR_WHITE,
            align = "center"
        }
        self[1] = VerticalGroup:new{
            VerticalSpan:new{ width = hole_gap },
            top_row,
            VerticalSpan:new{ width = Screen:scaleBySize(10) },
            title_widget,
            VerticalSpan:new{ width = Screen:scaleBySize(10) },
            bottom_row,
            VerticalSpan:new{ width = hole_gap },
        }
    end

    if top_split_widget and show_cover then
        table.insert(content_children, top_split_widget)
        table.insert(content_children, VerticalSpan:new{ width = db_padding_internal })
        table.insert(content_children, TextWidget:new{ text = "- - - - - - - - - - - - - - - - - - - - - - - -", face = Font:getFace("cfont", db_font_size_small), fgcolor = db_font_color_lighter, align = "center" })
        table.insert(content_children, VerticalSpan:new{ width = db_padding })

        local file_path = ui.document and ui.document.file or ""
        local raw_file_name = file_path ~= "" and ffiUtil.basename(file_path) or book_title
        local name_no_ext = raw_file_name:match("^(.+)%.[^%.]+$")
        if name_no_ext then raw_file_name = name_no_ext end
        if raw_file_name == "" then raw_file_name = "READING TICKET" end
        local display_file_name = getWeightedTruncatedString(raw_file_name, 24)
        table.insert(content_children, FilmStripTitle:new{
            width = full_ticket_width,
            title_text = display_file_name,
            title_font_size = math.floor(db_font_size_huge * 0.45)
        })
        table.insert(content_children, VerticalSpan:new{ width = db_padding })
    end

    if content_mode ~= K.CONTENT_MODE_HIGHLIGHT_PROGRESS and chapterbox then
        table.insert(content_children, chapterbox)
        table.insert(content_children, VerticalSpan:new{ width = db_padding })
    end
    table.insert(content_children, bookbox)

    if content_mode ~= K.CONTENT_MODE_HIGHLIGHT_PROGRESS then
        table.insert(content_children, VerticalSpan:new{ width = db_padding })

        local badge_size = Screen:scaleBySize(35)
        local badge_btn = Button:new{
            text = "✿", text_face = Font:getFace("cfont", db_font_size_mid), fg_color = db_font_color, background = Blitbuffer.COLOR_WHITE,
            bordersize = 0, padding = 0, width = badge_size, height = badge_size,
            callback = function()
                if on_close_callback then on_close_callback() end
                UIManager:setDirty(nil, "full")
                UIManager:scheduleIn(0.25, function()
                    local Event = require("ui/event")
                    local ok, err = pcall(function()
                        UIManager:broadcastEvent(Event:new("ShowReadingInsightsPopup"))
                    end)
                    if not ok then
                        UIManager:show(InfoMessage:new{ text = _("无法打开阅读洞察，请确认插件已正确安装") })
                        logger.warn("Book receipt: open reading insights failed:", err)
                    end
                end)
            end,
        }
        local separator_row = HorizontalGroup:new{
            align = "center",
            TextWidget:new{ text = "- - - - - - -", face = Font:getFace("cfont", db_font_size_small), fgcolor = db_font_color_lighter, padding = 0, align = "right" },
            HorizontalSpan:new{ width = db_padding_internal },
            badge_btn,
            HorizontalSpan:new{ width = db_padding_internal },
            TextWidget:new{ text = "- - - - - - -", face = Font:getFace("cfont", db_font_size_small), fgcolor = db_font_color_lighter, padding = 0, align = "left" },
        }
        table.insert(content_children, separator_row)
        table.insert(content_children, VerticalSpan:new{ width = db_padding_internal })
        if not Device.screen_saver_mode then
            table.insert(content_children, bottom_bar)
            table.insert(content_children, VerticalSpan:new{ width = db_padding_internal })
        end
        local stats_elements = {}
        if book_total_time_text then table.insert(stats_elements, TextWidget:new{ text = book_total_time_text, face = Font:getFace(db_font_face_italics, db_font_size_small), fgcolor = db_font_color, align = "center" }) end
        if book_total_time_text and book_today_time_text then table.insert(stats_elements, VerticalSpan:new{ width = db_padding_internal }) end
        if book_today_time_text then table.insert(stats_elements, TextWidget:new{ text = book_today_time_text, face = Font:getFace(db_font_face_italics, db_font_size_small), fgcolor = db_font_color, align = "center" }) end
        if #stats_elements > 0 then table.insert(content_children, VerticalGroup:new(stats_elements)) end
    end

    if content_mode == K.CONTENT_MODE_HIGHLIGHT_PROGRESS and highlight_widgets then
        table.insert(content_children, VerticalSpan:new{ width = db_padding_internal })
        util.arrayAppend(content_children, highlight_widgets)
    end

    if message_text then
        table.insert(content_children, VerticalSpan:new{ width = db_padding_internal })
        table.insert(content_children, VerticalGroup:new{
            TextBoxWidget:new{ face = Font:getFace(db_font_face, db_font_size_mid), text = message_text, width = widget_width, fgcolor = db_font_color, bold = true, alignment = "center" },
            VerticalSpan:new{ width = db_padding_internal },
        })
    end

    content_children.align = "center"
    local inner_ticket = FrameContainer:new{
        radius = 25,
        bordersize = 1,
        padding_top = db_padding,
        padding_right = 0,
        padding_bottom = db_padding,
        padding_left = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new(content_children)
    }

    local ticket_size = inner_ticket:getSize()
    local shadow_width_offset = Screen:scaleBySize(10)
    local shadow_shrink_offset = Screen:scaleBySize(20)
    local shadow_rect_w = math.max(1, math.floor(ticket_size.w + shadow_width_offset - shadow_shrink_offset))
    local shadow_rect_h = math.max(1, math.floor(ticket_size.h + shadow_width_offset - shadow_shrink_offset))
    local shadow_rect = FrameContainer:new{
        background = Blitbuffer.COLOR_GRAY_B,
        bordersize = 0,
        radius = 25,
        padding = 0,
        margin = 0,
        CenterContainer:new{
            dimen = Geom:new{ w = shadow_rect_w, h = shadow_rect_h },
            HorizontalSpan:new{ width = 0 }
        }
    }
    local shadow_layer = FrameContainer:new{
        bordersize = 0,
        padding_top = shadow_shrink_offset,
        padding_left = shadow_shrink_offset + shadow_width_offset,
        padding_right = 0,
        padding_bottom = 0,
        shadow_rect
    }
    local ticket_layer = FrameContainer:new{
        bordersize = 0,
        padding_top = 0,
        padding_left = shadow_width_offset,
        padding_right = shadow_width_offset,
        padding_bottom = shadow_width_offset,
        inner_ticket
    }
    local overlap = OverlapGroup:new{
        dimen = Geom:new{ w = math.floor(ticket_size.w + shadow_width_offset * 2), h = math.floor(ticket_size.h + shadow_width_offset) },
        shadow_layer,
        ticket_layer
    }
    return CenterContainer:new{ dimen = Screen:getSize(), overlap }
end

-- ========== 墨痕壁纸模块（整合自 inkstain.koplugin，已剔除 Miuread 与插件生命周期代码） ==========
-- 设计要点：
--   · 全部渲染函数为纯函数：输入统计数据 → 输出内存 BlitBuffer，不写盘、无定时器、无网络
--   · 数据源固定为 KOReader 阅读统计（statistics.sqlite3），Miuread（觅阅）相关代码已彻底移除
--   · 字体（huiwen_ming.otf）在补丁加载时尝试复制到 fonts/，缺失自动回退 cfont
--   · 二维码资源缺失时自动降级为伪二维码（drawPseudoQR）
local PLUGIN_FONT_NAME = "huiwen_ming.otf"

-- 诗句候选库：40 条经典诗词（结构化字段，供三行显示：诗句 / 朝代·作者 / 作品名）
-- dynasty 为空串表示无朝代（近现代作者），第 2 行仅显示作者
local QUOTES = {
    { text = "醉后不知天在水，满船清梦压星河。", dynasty = "元", author = "唐珙", work = "题龙阳县青草湖" },
    { text = "欲买桂花同载酒，终不似，少年游。", dynasty = "宋", author = "刘过", work = "唐多令·芦叶满汀洲" },
    { text = "人生若只如初见，何事秋风悲画扇。", dynasty = "清", author = "纳兰性德", work = "木兰花·拟古决绝词柬友" },
    { text = "疏影横斜水清浅，暗香浮动月黄昏。", dynasty = "宋", author = "林逋", work = "山园小梅" },
    { text = "十年生死两茫茫，不思量，自难忘。", dynasty = "宋", author = "苏轼", work = "江城子·乙卯正月二十日夜记梦" },
    { text = "桃李春风一杯酒，江湖夜雨十年灯。", dynasty = "宋", author = "黄庭坚", work = "寄黄几复" },
    { text = "我见青山多妩媚，料青山见我应如是。", dynasty = "宋", author = "辛弃疾", work = "贺新郎·甚矣吾衰矣" },
    { text = "流光容易把人抛，红了樱桃，绿了芭蕉。", dynasty = "宋", author = "蒋捷", work = "一剪梅·舟过吴江" },
    { text = "试问闲愁几许？一川烟草，满城风絮，梅子黄时雨。", dynasty = "宋", author = "贺铸", work = "青玉案·凌波不过横塘路" },
    { text = "风乍起，吹皱一池春水。", dynasty = "五代", author = "冯延巳", work = "谒金门·风乍起" },
    { text = "自在飞花轻似梦，无边丝雨细如愁。", dynasty = "宋", author = "秦观", work = "浣溪沙" },
    { text = "落霞与孤鹜齐飞，秋水共长天一色。", dynasty = "唐", author = "王勃", work = "滕王阁序" },
    { text = "沧海月明珠有泪，蓝田日暖玉生烟。", dynasty = "唐", author = "李商隐", work = "锦瑟" },
    { text = "年年岁岁花相似，岁岁年年人不同。", dynasty = "唐", author = "刘希夷", work = "代悲白头翁" },
    { text = "林花谢了春红，太匆匆。无奈朝来寒雨晚来风。", dynasty = "五代", author = "李煜", work = "相见欢·林花谢了春红" },
    { text = "日暮酒醒人已远，满天风雨下西楼。", dynasty = "唐", author = "许浑", work = "谢亭送别" },
    { text = "鸡声茅店月，人迹板桥霜。", dynasty = "唐", author = "温庭筠", work = "商山早行" },
    { text = "留得枯荷听雨声。", dynasty = "唐", author = "李商隐", work = "宿骆氏亭寄怀崔雍崔衮" },
    { text = "问君能有几多愁？恰似一江春水向东流。", dynasty = "五代", author = "李煜", work = "虞美人" },
    { text = "衣带渐宽终不悔，为伊消得人憔悴。", dynasty = "宋", author = "柳永", work = "蝶恋花·伫倚危楼风细细" },
    { text = "人生自是有情痴，此恨不关风与月。", dynasty = "宋", author = "欧阳修", work = "玉楼春·尊前拟把归期说" },
    { text = "山有木兮木有枝，心悦君兮君不知。", dynasty = "先秦", author = "佚名", work = "越人歌" },
    { text = "世事一场大梦，人生几度秋凉。", dynasty = "宋", author = "苏轼", work = "西江月·世事一场大梦" },
    { text = "多情自古伤离别，更那堪，冷落清秋节。", dynasty = "宋", author = "柳永", work = "雨霖铃·寒蝉凄切" },
    { text = "此情可待成追忆，只是当时已惘然。", dynasty = "唐", author = "李商隐", work = "锦瑟" },
    { text = "问苍茫大地，谁主沉浮？", dynasty = "", author = "毛泽东", work = "沁园春·长沙" },
    { text = "雄关漫道真如铁，而今迈步从头越。", dynasty = "", author = "毛泽东", work = "忆秦娥·娄山关" },
    { text = "红军不怕远征难，万水千山只等闲。", dynasty = "", author = "毛泽东", work = "七律·长征" },
    { text = "为有牺牲多壮志，敢教日月换新天。", dynasty = "", author = "毛泽东", work = "七律·到韶山" },
    { text = "俱往矣，数风流人物，还看今朝。", dynasty = "", author = "毛泽东", work = "沁园春·雪" },
    { text = "横眉冷对千夫指，俯首甘为孺子牛。", dynasty = "", author = "鲁迅", work = "自嘲" },
    { text = "寄意寒星荃不察，我以我血荐轩辕。", dynasty = "", author = "鲁迅", work = "自题小像" },
    { text = "不惜千金买宝刀，貂裘换酒也堪豪。", dynasty = "", author = "秋瑾", work = "对酒" },
    { text = "身不得，男儿列；心却比，男儿烈！", dynasty = "", author = "秋瑾", work = "满江红·小住京华" },
    { text = "秋风秋雨愁煞人。", dynasty = "", author = "秋瑾", work = "绝命诗" },
    { text = "此去泉台招旧部，旌旗十万斩阎罗。", dynasty = "", author = "陈毅", work = "梅岭三章（其一）" },
    { text = "取义成仁今日事，人间遍种自由花。", dynasty = "", author = "陈毅", work = "梅岭三章（其三）" },
    { text = "砍头不要紧，只要主义真。杀了夏明翰，还有后来人。", dynasty = "", author = "夏明翰", work = "就义诗" },
    { text = "何当痛饮黄龙府，高筑神州风雨楼。", dynasty = "", author = "李大钊", work = "口占一绝" },
    { text = "大江歌罢掉头东，邃密群科济世穷。", dynasty = "", author = "周恩来", work = "大江歌罢掉头东" },
}

-- ========== 菜单样式数据源（-- 修改：v2.4.5 菜谱.txt / 名言.txt 全部内容内嵌） ==========
-- 需求要求两个 .txt 的全文包含在补丁代码内，故以长字符串常量嵌入；
-- 已核对原文不含 Lua 长字符串结束符 "]]"，可直接使用 [[ ]] 定界。
-- 菜谱.txt：四类菜品，每道 4 行（名称/特色/食材/价格），分类标题行如「主菜（30道）」
local RECIPE_TEXT = [[
主菜（30道）
主菜：麻婆豆腐
特色：牛肉末煸至酥香，嫩豆腐浸于红油中，口感麻辣烫嫩，入口即化。
食材：韧豆腐400克、牛肉末50克、郫县豆瓣50克、高汤200毫升、水淀粉（红薯淀粉15克+水30毫升）、花椒粉3克、葱花适量
价格：18元

主菜：回锅肉
特色：五花肉片煸至卷曲呈灯盏窝，蒜苗与豆瓣酱香气融合，肉质肥而不腻。
食材：五花肉240克、青椒90克、蒜苗50克、郫县豆瓣15克、豆豉适量、甜面酱适量、白糖适量
价格：28元

主菜：水煮鱼
特色：鱼片白嫩滑润，热油浇淋干辣椒与花椒后激出麻辣香气，汤底鲜辣。
食材：草鱼1条约1000克、黄豆芽200克、干辣椒适量、花椒适量、蒜末适量、郫县豆瓣2汤匙、蛋清1个、淀粉适量
价格：38元

主菜：毛血旺
特色：鸭血嫩滑，毛肚脆爽，红油汤底麻辣醇厚，配料丰富。
食材：鸭血500克、毛肚100克、午餐肉50克、黄豆芽150克、干辣椒10克、花椒3克、火锅底料750克
价格：30元

主菜：夫妻肺片
特色：牛肉、牛舌、牛心切薄片，淋红油与花椒粉，口感麻辣鲜香，脆韧爽口。
食材：牛肉2500克、牛杂2500克、卤水2500克、红油90克、花椒面15克、花生末90克、酱油90克、芝麻面60克
价格：20元

主菜：辣子鸡
特色：鸡丁炸至外焦里嫩，与大量干辣椒、花椒同炒，焦香麻辣味突出。
食材：仔公鸡400克、干辣椒400克、花椒50克、姜20克、蒜20克、葱25克、白芝麻15克、料酒120克、酱油50克
价格：32元

主菜：宫保鸡丁
特色：鸡丁滑嫩，花生酥脆，宫保汁甜酸微辣，葱香明显。
食材：鸡腿肉300克、油炸花生米80克、干辣椒15克、花椒3克、大葱50克、姜5克、蒜10克、生抽1.5勺、香醋1勺、白糖1勺
价格：25元

主菜：鱼香肉丝
特色：肉丝软嫩，木耳与青笋丝脆爽，泡椒与糖醋调出咸甜酸辣兼备的鱼香味。
食材：猪里脊肉265克、水发木耳100克、冬笋150克、葱30克、蒜25克、姜10克、剁椒20克、郫县豆瓣20克、酱油8毫升、醋8毫升、糖22克
价格：22元

主菜：水煮肉片
特色：猪里脊片滑嫩不柴，配菜垫底，浇滚油激香蒜末与花椒，汤底麻辣。
食材：猪里脊肉250克、白菜适量、干辣椒适量、花椒10克、蒜末适量、郫县豆瓣适量、蛋清1个
价格：30元

主菜：酸菜鱼
特色：黑鱼片白嫩，酸菜脆爽，野山椒提供酸辣味，汤底酸鲜。
食材：草鱼500克、四川泡酸菜200克、泡椒8个、干辣椒适量、花椒10粒、姜1小块、蒜末适量、蛋清1个、淀粉适量
价格：35元

主菜：红烧排骨
特色：猪肋排烧至骨肉易分离，色泽红亮，酱香咸鲜，汤汁浓稠。
食材：猪肋排500克、姜2片、葱1段、冰糖适量、八角1-2个、料酒1-2汤匙、生抽2匙、老抽适量
价格：28元

主菜：京酱肉丝
特色：猪里脊丝滑嫩，裹甜面酱呈酱红色，咸甜适中，配葱丝与豆皮同食。
食材：猪里脊肉250克、豆腐皮2张、大葱1根、甜面酱20克、白糖15克、蛋清1个、淀粉适量
价格：22元

主菜：葱爆羊肉
特色：羊里脊片与大葱猛火快炒，葱香浓郁，肉质鲜嫩，咸鲜味型。
食材：羊肉300克、大葱200克、姜3片、盐3克、白胡椒1克、酱油2勺、料酒2勺
价格：35元

主菜：地三鲜
特色：茄子、土豆、青椒分别过油后炒制，酱汁浓稠，口感软糯，咸鲜回甘。
食材：茄子300克、土豆150克、青椒100克、蒜末10克、生抽适量、糖3克、盐3克、淀粉5克
价格：15元

主菜：猪肉炖粉条
特色：五花肉与红薯粉条、白菜慢炖，肉烂粉滑，汤汁浓稠，咸鲜家常味。
食材：五花肉300克、红薯粉条150克、白菜适量、八角适量、老抽适量、葱姜适量
价格：20元

主菜：白切鸡
特色：三黄鸡浸煮至九成熟，鸡皮爽脆，肉质滑嫩，蘸姜葱油食用。
食材：三黄鸡1只800克、姜40克、葱120克、盐15克、花生油120克
价格：25元

主菜：盐焗鸡
特色：整鸡用盐焗粉腌制后焗熟，鸡皮金黄微焦，肉质紧实咸香。
食材：光鸡1只800克、粗海盐2500克、盐焗鸡粉1包、沙姜粉适量、姜葱适量
价格：30元

主菜：蚝油牛肉
特色：牛里脊片滑油后与蚝油、青椒同炒，肉质滑嫩，蚝油鲜甜味明显。
食材：牛里脊肉300克、蚝油10克、鸡蛋1个、酱油适量、小苏打7.5克、干淀粉25克
价格：28元

主菜：红烧肉
特色：五花肉经炒糖色后慢炖，色泽红润，肥肉部分入口即化，瘦肉酥烂，咸中带甜。
食材：带皮五花肉500克、冰糖20克、生抽3汤匙、老抽1茶匙、料酒1汤匙、八角2颗、姜葱适量
价格：30元

主菜：东坡肉
特色：整块五花肉以黄酒、酱油、冰糖慢焖，酒香浓郁，肉质酥烂，肥而不腻。
食材：猪五花肉500克、黄酒150克、酱油100克、冰糖60克、葱姜适量
价格：30元

主菜：狮子头
特色：猪前腿肉与荸荠制成大肉丸，清炖或红烧，口感松软，汤汁醇厚。
食材：猪前腿肉500克、荸荠200克、鸡蛋1个、淀粉10克、青菜心适量、生抽1勺、料酒1勺
价格：18元

主菜：清蒸鲈鱼
特色：鲈鱼加姜葱蒸制，浇蒸鱼豉油与热油，肉质细嫩，鲜咸回甘。
食材：鲈鱼1条500克、姜丝适量、葱段适量、蒸鱼豉油适量、盐5克、料酒15克、食用油适量
价格：30元

主菜：豉汁蒸排骨
特色：猪肋排与豆豉、蒜末同蒸，排骨软脱骨，豆豉咸香渗入肉中。
食材：猪肋排250克、豆豉15克、蒜末适量、姜末适量、生抽适量、料酒适量、盐2克、糖2克、淀粉10克
价格：25元

主菜：三杯鸡
特色：鸡腿肉以米酒、酱油、麻油各一杯焖煮，九层塔增香，汤汁收浓，咸香微甜。
食材：鸡腿肉500克、米酒80毫升、酱油30毫升、麻油30毫升、姜片5片、蒜瓣5瓣、九层塔适量
价格：28元

主菜：酸汤鱼
特色：黑鱼片入发酵酸汤中烫熟，汤底含木姜子，酸辣味突出，略带清香。
食材：黑鱼1条800克、酸汤250克、木姜子适量、辣椒适量、西红柿适量、泡椒适量
价格：32元

主菜：牛肉泡馍
特色：掰碎的饦饦馍与牛肉、粉丝同煮，吸足肉汤，汤浓肉烂，配香菜。
食材：牛肉1000克、牛棒骨850克、饦饦馍（面粉300克+发面团50克）、粉丝适量、木耳适量、黄花菜适量、蒜苗、香菜适量
价格：25元

主菜：手抓羊肉
特色：羊肋排清水煮透，肉质鲜嫩无膻，蘸椒盐或蒜醋汁食用。
食材：羊肋排1000克、花椒适量、盐8克、姜6片、香菜25克、葱25克
价格：70元

主菜：大盘鸡
特色：鸡肉与土豆、干辣椒炖煮，汤汁浓稠麻辣，配宽面拌食。
食材：鸡肉800克、土豆300克、青椒2个、干辣椒适量、郫县豆瓣50克、皮带面适量、大葱100克、大蒜4瓣
价格：40元

主菜：蒜蓉粉丝蒸虾
特色：开背大虾铺蒜蓉，与粉丝同蒸，虾肉弹嫩，粉丝吸附虾汁与豉油。
食材：鲜虾300克、龙口粉丝1把50克、大蒜1整头、蒸鱼豉油适量、葱花适量
价格：38元

主菜：油焖大虾
特色：大对虾煎至虾壳红亮，加生抽、糖焖烧，虾肉紧实，咸甜鲜香。
食材：大虾350克、姜丝5克、葱丝5克、蒜片5克、白糖20克、料酒15克、生抽1.5汤匙
价格：38元

汤菜（10道）
汤菜：酸辣汤
特色：豆腐丝、木耳丝与蛋花同煮，醋与胡椒粉调出酸辣味，勾薄芡使汤体滑润。
食材：豆腐50克、木耳10克、香菇10克、鸡蛋1个、醋10毫升、胡椒粉2克、水淀粉（淀粉10克+水20毫升）、盐3克
价格：12元

汤菜：西湖牛肉羹
特色：牛肉末与鸡蛋清煮成絮状，香菇粒增鲜，汤色清亮，入口滑润。
食材：牛肉末100克、鸡蛋清2个、香菇50克、盐3克、水淀粉（淀粉10克+水20毫升）、葱花适量
价格：15元

汤菜：冬瓜排骨汤
特色：排骨与冬瓜同炖至酥烂，汤色清浅，冬瓜透明，咸鲜清淡。
食材：排骨300克、冬瓜200克、姜片3片、盐5克、料酒10毫升
价格：18元

汤菜：玉米排骨汤
特色：排骨与甜玉米、胡萝卜同煮，汤色微黄，带有玉米清甜，肉质软烂。
食材：排骨300克、玉米1根（切段）、胡萝卜50克、姜片3片、盐5克、料酒10毫升
价格：18元

汤菜：番茄蛋花汤
特色：番茄煮至软烂出红油，蛋花均匀浮于汤面，酸甜适中。
食材：番茄200克、鸡蛋2个、葱花适量、盐3克、白糖5克、水500毫升
价格：10元

汤菜：紫菜虾皮汤
特色：紫菜与虾皮煮沸，蛋花点缀，鲜味清爽，盐分来自虾皮。
食材：紫菜5克、虾皮10克、鸡蛋1个、盐2克、葱花适量、水400毫升
价格：8元

汤菜：豆腐鱼头汤
特色：鱼头煎至金黄后与豆腐同炖，汤色奶白，鱼肉细嫩，豆腐吸汁。
食材：鱼头1个（约500克）、嫩豆腐200克、姜片5片、盐5克、料酒15毫升、白胡椒粉2克
价格：25元

汤菜：山药鸡汤
特色：鸡块与山药段同炖，汤色金黄微稠，山药绵软，鸡肉脱骨。
食材：鸡半只（约500克）、山药200克、枸杞10克、姜片5片、盐5克、料酒15毫升
价格：28元

汤菜：菌菇豆腐汤
特色：多种菌菇与嫩豆腐同煮，汤体清亮，菌香浓郁，豆腐滑嫩。
食材：鲜菇（金针菇、香菇、白玉菇共100克）、嫩豆腐100克、盐3克、香油2毫升、葱花适量
价格：12元

汤菜：酸菜猪肉粉丝汤
特色：酸菜与猪肉片同煮，粉丝吸饱酸鲜汤汁，汤色微黄，开胃解腻。
食材：酸菜100克、猪瘦肉片100克、粉丝50克、姜片3片、盐3克、胡椒粉1克
价格：16元

饮品（10种）
饮品：烤黑糖波波真乳茶
特色：黑糖波波挂壁焦香，牛乳茶底丝滑醇厚。
食材：红茶汤150ml、真牛乳奶100ml、冰糖糖浆30ml、黑糖波波80g、冰块适量
价格：19元

饮品：豆豆波波茶
特色：豆奶奶盖绵密，豆酪嫩滑，奶茶底清爽。
食材：茉莉绿茶茶汤200ml、奶精40g、果糖30g、豆酪3勺、豆奶奶盖适量、黄豆粉适量
价格：18元

饮品：荔枝玫瑰水牛乳雪顶
特色：玫瑰红茶为底，荔枝果肉清甜，奶油雪顶绵密。
食材：玫瑰红茶150ml、冰糖23ml、咖奶20ml、牛奶70ml、荔枝50g、淡奶油雪顶适量
价格：22元

饮品：双拼奶茶
特色：任选两种小料，奶茶基底香浓，口感层次丰富。
食材：糖浆30g、珍珠2勺、布丁2勺（或任选两种小料各2勺）、奶茶140ml、冰块适量
价格：8元

饮品：芋圆奶茶
特色：芋圆Q弹有嚼劲，奶茶温润。
食材：糖浆30g、芋圆80g、奶茶140ml、冰块适量
价格：7元

饮品：多肉葡萄
特色：葡萄果肉与绿茶冰沙融合，芝士奶盖咸香，酸甜清爽。
食材：绿妍茶底120ml、葡萄汁45ml、糖浆15ml、鲜葡萄果肉1勺、葡萄茶冻1勺、冰块250g、芝士奶盖适量
价格：29元

饮品：满杯红柚
特色：西柚果肉饱满微苦，绿茶底清冽，酸甜回甘。
食材：绿妍茶底200ml、西柚果粒80g、西柚果汁40ml、果糖35g、冰块150g
价格：26元

饮品：霸气橙子
特色：整颗橙子切片浸入绿茶，橙香清新，酸甜平衡。
食材：绿茶225ml、橙子片5片、橙汁70ml、青柠檬2片、糖浆30ml、冰块100g
价格：24元

饮品：霸气芝士草莓
特色：草莓果肉打制冰沙，芝士奶盖绵密，果香浓郁。
食材：茉莉花茶225ml、草莓6个、草莓果泥1平勺、糖浆30ml、冰块100g、芝士奶盖70g
价格：28元

饮品：蜜桃四季春
特色：蜜桃果肉清甜，四季春茶底花香悠长。
食材：四季春茶汤100ml、蜜桃果酱75g、果糖40g、玫果冻120g、冰块适量
价格：7元

甜点（10种，价格为单个个体整数价格）
甜点：提拉米苏
特色：马斯卡彭奶酪糊绵密，咖啡与可可粉带来微苦回甘。
食材：马斯卡彭奶酪250g、淡奶油250g、蛋黄6个、蛋白3个、白砂糖75g、手指饼干15个、浓缩咖啡150ml、可可粉适量
价格：28元

甜点：芒果班戟
特色：班戟皮薄软，奶油馅轻盈，芒果果肉清甜多汁。
食材：班戟皮（鸡蛋3个、牛奶240ml、低筋面粉50g、玉米淀粉30g、白糖18g）、淡奶油250ml、芒果1个
价格：18元

甜点：葡式蛋挞
特色：挞皮酥松多层，蛋奶馅嫩滑，表面焦糖斑诱人。
食材：蛋挞皮10个、蛋黄4个、淡奶油150ml、牛奶50ml、细砂糖40g、炼乳10g
价格：6元

甜点：榴莲酥
特色：酥皮层层分明，榴莲馅甜糯浓郁，外酥内软。
食材：低筋面粉150g、黄油100g、榴莲果肉200g、糖粉30g、蛋液适量
价格：5元

甜点：绿豆糕
特色：绿豆泥细腻绵密，入口即化，清甜不油。
食材：去皮绿豆250g、黄油（或玉米油）80g、细砂糖100g、麦芽糖50g
价格：3元

甜点：驴打滚
特色：糯米皮软糯，豆沙馅甜润，外裹黄豆面，层次分明。
食材：糯米粉200g、水180ml、红豆沙150g、熟黄豆面80g、白糖30g
价格：3元

甜点：豌豆黄
特色：豌豆泥凝制成糕，清凉细腻，入口即化，微甜清爽。
食材：去皮豌豆200g、冰糖100g、琼脂（或吉利丁）适量
价格：4元

甜点：杏仁豆腐
特色：杏仁露凝固成豆腐状，滑嫩清凉，糖水清澈。
食材：杏仁露250ml、牛奶100ml、冰糖20g、琼脂粉5g、糖桂花适量
价格：12元

甜点：桂花糕
特色：糯米粉与粳米粉层叠，嵌桂花蜜，松软清甜，花香怡人。
食材：糯米粉150g、粳米粉150g、白糖80g、糖桂花30g、水适量
价格：3元

甜点：肉松小贝
特色：戚风蛋糕体松软，表面覆盖海苔肉松，夹心沙拉酱，咸甜鲜香。
食材：鸡蛋3个、低筋面粉60g、糖50g、牛奶40g、玉米油35g、海苔肉松100g、沙拉酱80g
价格：8元
]]

-- 名言.txt：每条约 1 行，格式「名人：“名言。”——《出处》」，个别为「——语本《…》」「——演讲《…》」
local QUOTATION_TEXT = [[
孔子：“学而不思则罔，思而不学则殆。”——《论语·为政》

孟子：“民为贵，社稷次之，君为轻。”——《孟子·尽心下》

老子：“治大国若烹小鲜。”——《道德经》第六十章

庄子：“吾生也有涯，而知也无涯。”——《庄子·养生主》

韩非子：“宰相必起于州部，猛将必发于卒伍。”——《韩非子·显学》

墨子：“兼相爱，交相利。”——《墨子·兼爱中》

孙子：“知己知彼，百战不殆。”——《孙子兵法·谋攻篇》

管子：“仓廪实则知礼节，衣食足则知荣辱。”——《管子·牧民》

商鞅：“疑行无名，疑事无功。”——《商君书·更法》

吕不韦：“流水不腐，户枢不蠹。”——《吕氏春秋·尽数》

晏子：“为者常成，行者常至。”——《晏子春秋·内篇杂下》

司马迁：“人固有一死，或重于泰山，或轻于鸿毛。”——《报任安书》

诸葛亮：“非淡泊无以明志，非宁静无以致远。”——《诫子书》

范仲淹：“先天下之忧而忧，后天下之乐而乐。”——《岳阳楼记》

顾炎武：“天下兴亡，匹夫有责。”——语本《日知录·正始》

鲁迅：“惟沉默是最高的轻蔑。”——《半夏小集》

曾子：“吾日三省吾身。”——《论语·学而》

子夏：“博学而笃志，切问而近思。”——《论语·子张》

王阳明：“破山中贼易，破心中贼难。”——《与杨仕德薛尚谦书》

左丘明：“居安思危，思则有备，有备无患。”——《左传·襄公十一年》

董仲舒：“正其义不谋其利，明其道不计其功。”——《春秋繁露》

司马光：“由俭入奢易，由奢入俭难。”——《训俭示康》

朱熹：“读书有三到，谓心到、眼到、口到。”——《训学斋规》

王安石：“天变不足畏，祖宗不足法，人言不足恤。”——《宋史·王安石传》

魏源：“师夷长技以制夷。”——《海国图志》

韩愈：“业精于勤，荒于嬉；行成于思，毁于随。”——《进学解》

刘秀：“有志者事竟成。”——《后汉书·耿弇传》

刘备：“勿以恶小而为之，勿以善小而不为。”——《三国志·蜀书·先主传》裴注

王充：“精诚所至，金石为开。”——《论衡·感虚篇》

魏征：“兼听则明，偏信则暗。”——《新唐书·魏征传》

班固：“临渊羡鱼，不如退而结网。”——《汉书·董仲舒传》

欧阳修：“忧劳可以兴国，逸豫可以亡身。”——《新五代史·伶官传序》

亚里士多德：“优秀是一种习惯。”——《尼各马可伦理学》

弗朗西斯·培根：“知识就是力量。”——《新工具》

拉尔夫·沃尔多·爱默生：“你的善良必须有点锋芒。”——《论补偿》

欧内斯特·海明威：“一个人可以被毁灭，但不能被打败。”——《老人与海》

马丁·路德·金：“做对的事，任何时机都是好时机。”——演讲《我有一个梦想》

马库斯·图利乌斯·西塞罗：“活着就意味着战斗。”——《论老年》

马可·奥勒留：“你人生的幸福取决于你的思想质量。”——《沉思录》

本杰明·富兰克林：“时间就是金钱。”——《给年轻商人的忠告》
]]

-- 解析菜谱文本：按分类（主菜/汤菜/饮品/甜点）组织条目表，首次调用后缓存
-- 注意：分类标题行（含「（」不含「：」）直接跳过；条目行必须以四类前缀开头，
-- 否则「特色/食材/价格」行会被误判为新条目（-- 修改：v2.4.5 用分类前缀精确匹配）
local recipe_cache
-- 识别菜谱条目起始行（分类前缀 + 全角冒号 + 菜名），返回 分类、菜名
-- 为什么不用 `^(主菜|汤菜|饮品|甜点)：(.+)$`：Lua 模式不支持 `|` 交替（`|` 被当作
-- 字面字符处理，永远无法匹配）；且 `[^...]` 字符类对多字节 UTF-8 按字节比较会误伤
-- （如 `[^》]` 会排除所有含 0x80/0x8B/0xE3 字节的汉字），故逐类做字面前缀匹配，字节级可靠
local function matchRecipeCategory(line)
    for _, c in ipairs({ "主菜", "汤菜", "饮品", "甜点" }) do
        if line:match("^" .. c .. "：") then
            return c, line:sub(#c + #"：" + 1) -- 跳过 分类汉字(6字节) + 全角冒号(3字节)
        end
    end
    return nil
end

-- 解析菜谱文本：按 分类标题行 / 条目起始行 / 字段行 三层结构还原为 {分类 = {条目}} 表
local function parseRecipeText()
    if recipe_cache then return recipe_cache end
    local data = { ["主菜"] = {}, ["汤菜"] = {}, ["饮品"] = {}, ["甜点"] = {} }
    local cur -- 当前条目
    for line in RECIPE_TEXT:gmatch("[^\r\n]+") do
        if line:find("（") and not line:find("：") then
            -- 分类标题行（如「主菜（30道）」「甜点（10种，价格为单个个体整数价格）」）：不改 cur
        else
            -- 条目起始行：分类前缀 + ： + 菜名
            local cat, name = matchRecipeCategory(line)
            if cat then
                cur = { category = cat, name = name }
                table.insert(data[cat], cur)
            elseif cur then
                -- 其余字段行（特色/食材/价格）归入当前条目
                local feature = line:match("^特色：(.+)$")
                local ingredients = line:match("^食材：(.+)$")
                local price = line:match("^价格：(%d+)")
                if feature then cur.feature = feature end
                if ingredients then cur.ingredients = ingredients end
                if price then cur.price = tonumber(price) end
            end
        end
    end
    recipe_cache = data
    logger.dbg(LOG_TAG, "菜谱解析完成：主菜%d道/汤菜%d道/饮品%d道/甜点%d道",
        #data["主菜"], #data["汤菜"], #data["饮品"], #data["甜点"])
    return data
end

-- 解析名言文本：拆分为 名言/名人/出处 三字段，去中文引号、去末尾句号、出处去书名号
local quotation_cache
local function parseQuotationText()
    if quotation_cache then return quotation_cache end
    local list = {}
    for line in QUOTATION_TEXT:gmatch("[^\r\n]+") do
        -- 名人：取第一个全角冒号前的全部内容（字面 find 定位）。
        -- 为何不用 `^([^：]+)：`：字符类 `[^：]` 按字节排除全角冒号(U+FF1A)的 EF/BC/9A，
        -- 会误伤含 0xBC/0x9A 字节的汉字（如“弗”E5 BC 97、“多”E5 A4 9A、“亚”E4 BA 9A），
        -- 导致外国人名整段匹配失败；find 定位冒号后 sub 截取完全规避该陷阱。
        local person
        local colon = line:find("：", 1, true)
        if colon then person = line:sub(1, colon - 1) end
        -- 名言与出处：改用字面查找定位中文引号/书名号后截取。
        -- 为何不用 `“[^”]*”` / `《([^》]*)》`：Lua 字符类对多字节 UTF-8 按字节比较，
        -- `[^”]` 会排除所有含 0x80 字节的汉字（如“而”E2 80 8C 的第二个字节 0x80），
        -- 导致含此类汉字的条目整体匹配失败；字面 find + sub 完全规避该陷阱。
        local quote
        local qs = line:find("“", 1, true) -- 起始中文引号首字节位置
        local qe = line:find("”", 1, true) -- 结束中文引号首字节位置
        if qs and qe and qe > qs then
            quote = line:sub(qs + 3, qe - 1) -- 跳过起始引号 3 字节，取引号之间内容
        end
        local source
        local ss = line:find("《", 1, true)
        local se = line:find("》", 1, true)
        if ss and se and se > ss then
            source = line:sub(ss + 3, se - 1)
        end
        if person and quote and source then
            -- 去末尾句号（用字面模式锚定行尾，避免字符类对多字节的字节级误伤）
            quote = quote:gsub("。$", ""):gsub("．$", "")
            table.insert(list, { quote = quote, person = person, source = source })
        end
    end
    quotation_cache = list
    logger.dbg(LOG_TAG, "名言解析完成：共%d条", #list)
    return list
end

-- 随机抽取一条名人名言（-- 修改：v2.4.5）
local function pickRandomQuotation()
    local list = parseQuotationText()
    return list[math.random(#list)]
end

-- 生成菜单样式数据：主菜2道 + 汤菜/饮品/甜点各1道 + 1条名言（-- 修改：v2.4.5）
-- 每类内部随机且去重；category 字段仅供内部逻辑与测试断言，绘制时绝不输出（满足需求2）
local function buildMenuData()
    local recipe = parseRecipeText()
    -- 从指定分类随机抽取 n 道（用 used 表去重，防止同分类重复）
    local function draw_pool(cat, n)
        local pool = recipe[cat]
        local out = {}
        local used = {}
        for _ = 1, n do
            local idx = math.random(#pool)
            local guard = 0
            while used[idx] and guard < 100 do
                idx = math.random(#pool)
                guard = guard + 1
            end
            used[idx] = true
            table.insert(out, {
                category = cat,
                name = pool[idx].name,
                feature = pool[idx].feature,
                ingredients = pool[idx].ingredients,
                price = pool[idx].price,
            })
        end
        return out
    end
    -- 依次：No.1/No.2 主菜 → No.3 汤菜 → No.4 饮品 → No.5 甜点
    local items = {}
    for _, it in ipairs(draw_pool("主菜", 2)) do table.insert(items, it) end
    for _, it in ipairs(draw_pool("汤菜", 1)) do table.insert(items, it) end
    for _, it in ipairs(draw_pool("饮品", 1)) do table.insert(items, it) end
    for _, it in ipairs(draw_pool("甜点", 1)) do table.insert(items, it) end
    -- 合计 = 5 道菜价格总和（需求5：加入计算求和逻辑）
    local total = 0
    for _, it in ipairs(items) do total = total + (it.price or 0) end
    logger.dbg(LOG_TAG, "菜单数据生成完成：5道菜合计%d元", total)
    return { items = items, total = total, quotation = pickRandomQuotation() }
end

local CODE128_PATTERNS = {
    "212222","222122","222221","121223","121322","131222","122213","122312","132212","221213",
    "221312","231212","112232","122132","122231","113222","123122","123221","223211","221132",
    "221231","213212","223112","312131","311222","321122","321221","312212","322112","322211",
    "212123","212321","232121","111323","131123","131321","112313","132113","132311","211313",
    "231113","231311","112133","112331","132131","113123","113321","133121","313121","211331",
    "231131","213113","213311","213131","311123","311321","331121","312113","312311","332111",
    "314111","221411","431111","111224","111422","121124","121421","141122","141221","112214",
    "112412","122114","122411","142112","142211","241211","221114","413111","241112","134111",
    "111242","121142","121241","114212","124112","124211","411212","421112","421211","212141",
    "214121","412121","111143","111341","131141","114113","114311","411113","411311","113141",
    "114131","311141","411131","211412","211214","211232","2331112",
}

-- 截断字符串为指定字符数（中文按字符计），超长尾部追加省略号
local function truncate(value, limit)
    value = tostring(value or "")
    limit = limit or 18
    local ok, chars = pcall(util.splitToChars, value)
    if not ok or type(chars) ~= "table" then
        if #value > limit * 3 then
            return value:sub(1, limit * 3) .. "…"
        end
        return value
    end
    if #chars <= limit then
        return value
    end
    local out = {}
    for i = 1, limit do
        out[i] = chars[i]
    end
    out[#out + 1] = "…"
    return table.concat(out)
end

-- 将秒数格式化为中文"X小时Y分钟 / X分钟"
local function formatDuration(seconds)
    seconds = tonumber(seconds) or 0
    local minutes = math.floor(seconds / 60 + 0.5)
    local hours = math.floor(minutes / 60)
    local mins = minutes % 60
    if hours > 0 then
        return string.format("%d小时%d分钟", hours, mins)
    end
    return string.format("%d分钟", mins)
end

-- 将秒数换算为以"天"为单位的显示文本（保留 1 位小数并带单位"天"）
-- 用于墨痕"时长"与菜单"总计光临本店"两处左上角栏位（-- 修改：v2.4.9）
-- 为何保留 1 位小数：单次/单周阅读时长通常不足 1 天，取整会显示无信息的"0天"；
-- 极短时长（<0.05 天，约 72 分钟）显示"不足1天"，避免"0.0天"这类歧义文本
local function formatDurationDays(seconds)
    seconds = tonumber(seconds) or 0
    local days = seconds / 86400
    if days < 0.05 then
        return "不足1天"
    end
    return string.format("%.1f天", days)
end

-- 返回指定时间戳（默认当前）所在自然日的零点时间戳
local function dayStart(ts)
    local t = os.date("*t", ts or os.time())
    t.hour, t.min, t.sec = 0, 0, 0
    return os.time(t)
end

-- 时间戳 → "YYYY-MM-DD"（统计分组键）
local function dateKey(ts)
    return os.date("%Y-%m-%d", ts)
end

-- 时间戳 → "MM-DD"（图表横轴短标签）
local function shortDate(ts)
    return os.date("%m-%d", ts)
end

-- 获取墨痕字体（优先自定义字体，缺失回退 cfont），并带字号下限保护
local function getFontFace(size)
    local sz = math.max(8, math.floor(size))
    local font_dest = FontList.fontdir .. "/" .. PLUGIN_FONT_NAME
    if lfs.attributes(font_dest, "mode") == "file" then
        local face = Font:getFace(PLUGIN_FONT_NAME, sz)
        if face then return face end
    end
    return Font:getFace("cfont", sz)
end

-- 单行文本直接绘制到 blitbuffer，返回绘制尺寸（供后续布局计算）
local function drawText(bb, text, x, y, size, bold, max_width, align, color)
    local widget = TextWidget:new{
        text = tostring(text or ""),
        face = getFontFace(size),
        bold = bold and true or false,
        fgcolor = color or Blitbuffer.COLOR_BLACK,
        max_width = max_width,
    }
    widget:updateSize()
    local draw_x = math.floor(x)
    if align == "right" then
        draw_x = math.floor(x - widget:getSize().w)
    elseif align == "center" then
        draw_x = math.floor(x - widget:getSize().w / 2)
    end
    widget:paintTo(bb, draw_x, math.floor(y))
    local widget_size = widget:getSize()
    if widget.free then widget:free() end
    return widget_size
end

-- 仅测量文本渲染宽度（不绘制），用于动态布局；字体/字号/粗细与 drawText 保持一致
-- 入参：text 文本、size 字号、bold 是否加粗；返回像素宽度
local function measureText(text, size, bold)
    local widget = TextWidget:new{
        text = tostring(text or ""),
        face = getFontFace(size),
        bold = bold and true or false,
    }
    widget:updateSize()
    local widget_size = widget:getSize()
    if widget.free then widget:free() end
    return widget_size.w
end

-- 按像素宽度截断文本（超宽时尾部追加省略号），用于单行文本在有限列宽内
-- 尽可能展示更多内容。为什么需要它：固定字符数截断（truncate）无法感知实际
-- 列宽——菜单样式特色/食材行原固定 18/26 字，而右侧 title_w 列宽远宽于此，
-- 造成"右侧大量空间闲置"。以像素宽度为预算的截断，既充分利用空间，
-- 又以 max_width 为硬边界，保证不与"数量/单价"栏重叠（TextWidget 超宽会换行，
-- 换行会压到下一行内容，因此必须在绘制前截断到位）。
-- 注意：必须定义在 measureText 之后（函数体内引用须先于定义声明，否则被解析为全局）。
-- 入参：text 原文本、max_width 最大像素宽度、size 字号、bold 是否加粗
local function truncateToWidth(text, max_width, size, bold)
    text = tostring(text or "")
    if text == "" or not max_width or max_width <= 0 then return text end
    -- 完整文本未超宽：直接返回，零额外测量开销
    if measureText(text, size, bold) <= max_width then return text end
    local ellipsis = "…"
    local ellipsis_w = measureText(ellipsis, size, bold)
    local budget = max_width - ellipsis_w
    if budget <= 0 then return ellipsis end -- 极窄列：仅显示省略号
    local out = {}
    local w = 0
    local i = 1
    local len = #text
    while i <= len do
        local byte = string.byte(text, i)
        local clen = 1
        if byte >= 0xF0 then clen = 4
        elseif byte >= 0xE0 then clen = 3
        elseif byte >= 0xC0 then clen = 2
        end
        local ch = text:sub(i, i + clen - 1)
        local cw = measureText(ch, size, bold)
        if w + cw > budget then break end
        table.insert(out, ch)
        w = w + cw
        i = i + clen
    end
    if #out == 0 then return ellipsis end
    return table.concat(out) .. ellipsis
end

-- 仅测量文本渲染高度（不绘制），与 drawText 使用相同字体/字号/粗细/最大宽度
-- 返回像素高度：三行诗句排布依赖实测高度（含自动换行后的实际高度），
-- 从屏幕底部向上精确错位，任何屏幕/字号下均不会发生行间重叠
local function measureTextH(text, size, bold, max_width)
    local widget = TextWidget:new{
        text = tostring(text or ""),
        face = getFontFace(size),
        bold = bold and true or false,
        max_width = max_width,
    }
    widget:updateSize()
    local widget_size = widget:getSize()
    if widget.free then widget:free() end
    return widget_size.h
end

-- 绘制图片资源（失败返回 false，调用方自行降级处理）
local function drawImage(bb, path, x, y, size)
    local ok, image = pcall(RenderImage.renderImageFile, RenderImage, path, false, size, size)
    if ok and image then
        local ok_blit = pcall(bb.blitFrom, bb, image, math.floor(x), math.floor(y), 0, 0, image:getWidth(), image:getHeight())
        if image.free then image:free() end
        return ok_blit
    end
    return false
end

-- 多行文本（自动换行）绘制到 blitbuffer
local function drawBoxText(bb, text, x, y, width, size, bold, align)
    local widget = TextBoxWidget:new{
        text = tostring(text or ""),
        face = getFontFace(size),
        bold = bold and true or false,
        fgcolor = Blitbuffer.COLOR_BLACK,
        bgcolor = Blitbuffer.COLOR_WHITE,
        width = math.floor(width),
        alignment = align or "left",
        height_overflow_show_ellipsis = true,
    }
    widget:paintTo(bb, math.floor(x), math.floor(y))
    if widget.free then widget:free() end
end

-- 实心矩形
local function drawRect(bb, x, y, w, h, color)
    bb:paintRect(math.floor(x), math.floor(y), math.max(1, math.floor(w)), math.max(1, math.floor(h)), color or Blitbuffer.COLOR_BLACK)
end

-- Bresenham 直线算法（用于折线图与分割线，兼容任意斜率）
local function drawLine(bb, x1, y1, x2, y2, width, color)
    x1, y1, x2, y2 = math.floor(x1), math.floor(y1), math.floor(x2), math.floor(y2)
    width = math.max(1, math.floor(width or 1))
    local dx = math.abs(x2 - x1)
    local sx = x1 < x2 and 1 or -1
    local dy = -math.abs(y2 - y1)
    local sy = y1 < y2 and 1 or -1
    local err = dx + dy
    while true do
        drawRect(bb, x1, y1, width, width, color)
        if x1 == x2 and y1 == y2 then break end
        local e2 = 2 * err
        if e2 >= dy then
            err = err + dy
            x1 = x1 + sx
        end
        if e2 <= dx then
            err = err + dx
            y1 = y1 + sy
        end
    end
end

-- 空心矩形边框
local function drawFrame(bb, x, y, w, h, width, color)
    width = math.max(1, math.floor(width or 1))
    drawRect(bb, x, y, w, width, color)
    drawRect(bb, x, y + h - width, w, width, color)
    drawRect(bb, x, y, width, h, color)
    drawRect(bb, x + w - width, y, width, h, color)
end

-- 顺序伪随机发生器：为 21×21 网格按行优先产出数据区单元的黑白位（-- 修改：v2.4.3）
-- 设计意图：v2.4.2 的 qrDataBit 按坐标线性求哈希——(row*A+col*B+seed)*48271 mod M 是
-- 坐标的线性映射（Park-Miller 本身即线性同余），复合仍为线性，同一行相邻列间 h 等差
-- 递增，取第 16 位时进位规律使整行出现成片同色大色块（用户二次投诉"一半黑一半白"）。
-- 本函数改为"顺序推进"：每个数据单元依次推进一次 PRNG 状态，取连续独立随机位，
-- 相邻格之间不存在任何由坐标线性关系引入的相关性，输出为天然迷宫状散点。
-- 确定性：同一种子 → 同一序列 → 同一天同一图案；日期变化种子即变。
-- 全整数运算（乘积 < 2^31，远低于 LuaJIT double 精确上限 2^53），不依赖 bit 库。
-- 返回值：迭代器依次产出 (bit, row, col)，row/col 为 0 基，仅覆盖真实二维码数据区。
-- 说明：排除三个定位角区域与横竖时序条带（row/col==6），与绘制循环共用同一判定，
-- 保证绘制与测试观察到的序列严格一致、无逻辑漂移。
local function qrDataBitsForGrid(seed_num)
    local prng = seed_num
    if prng == 0 then prng = 123456789 end -- 防御：全零种子会令 Park-Miller 恒为 0，无法产出随机位
    local row, col = 0, 0
    return function()
        while true do
            if col >= 21 then
                col = 0
                row = row + 1
            end
            if row >= 21 then return nil end -- 遍历完整个 21×21 网格，迭代结束
            local r, c = row, col
            col = col + 1
            local in_finder = (r < 7 and c < 7) or (r < 7 and c >= 14) or (r >= 14 and c < 7)
            if not in_finder and r ~= 6 and c ~= 6 then
                prng = (prng * 48271) % 2147483647 -- Park-Miller 步进
                -- 与 0.5 阈值比较（等价于取高 15 位组合）：高位随机性好，避开低位周期性
                return prng < 1073741824, r, c
            end
        end
    end
end

-- 伪二维码（二维码资源缺失时的降级方案，含三个定位角）（-- 修改：v2.4.3 数据区改为顺序 PRNG）
local function drawPseudoQR(bb, x, y, size, seed)
    size = math.floor(size)
    local cells = 21
    local cell = math.max(1, math.floor(size / cells))
    local actual = cell * cells
    drawRect(bb, x, y, actual, actual, Blitbuffer.COLOR_WHITE)
    local function finder(fx, fy)
        drawRect(bb, x + fx * cell, y + fy * cell, 7 * cell, 7 * cell)
        drawRect(bb, x + (fx + 1) * cell, y + (fy + 1) * cell, 5 * cell, 5 * cell, Blitbuffer.COLOR_WHITE)
        drawRect(bb, x + (fx + 2) * cell, y + (fy + 2) * cell, 3 * cell, 3 * cell)
    end
    finder(0, 0)
    finder(14, 0)
    finder(0, 14)
    -- 种子数值化：日期字符串字节加权累加（-- 修改：v2.4.2 替代原 seed:byte 逐位取字节）
    -- 设计意图：同一日期（同一统计周期）生成同一图案，日期变化图案即变
    seed = tostring(seed or os.time())
    local seed_num = 0
    for i = 1, #seed do
        seed_num = (seed_num * 31 + (seed:byte(i) or 0)) % 2147483647
    end
    -- 时序图案（-- 修改：v2.4.2 新增）：真实二维码标配——第 6 行 / 第 6 列
    -- 在左右/上下定位角之间各画 5 格黑白交替条（起始与结束均为黑）
    for i = 0, 4 do
        if i % 2 == 0 then
            drawRect(bb, x + (8 + i) * cell, y + 6 * cell, cell, cell) -- 水平时序（row 6）
            drawRect(bb, x + 6 * cell, y + (8 + i) * cell, cell, cell) -- 垂直时序（col 6）
        end
    end
    -- 数据区填充：顺序 PRNG 迷宫状散点（-- 修改：v2.4.3 以顺序推进取代坐标线性哈希）
    -- 每个数据单元依次取一个独立随机位，黑色画格、白色留空，观感接近真实二维码数据区
    for bit, r, c in qrDataBitsForGrid(seed_num) do
        if bit then
            drawRect(bb, x + c * cell, y + r * cell, cell, cell)
        end
    end
end

-- Code128 编码：将数据字节转换为条码符号序列（含起始符/校验位/终止符）
local function code128Patterns(data)
    data = tostring(data or "")
    if data == "" then data = os.date("%Y%m%d") end
    local codes = { 104 } -- Start Code B
    local checksum = 104
    for i = 1, #data do
        local b = data:byte(i)
        if b < 32 or b > 126 then b = 63 end
        local value = b - 32
        codes[#codes + 1] = value
        checksum = checksum + value * i
    end
    codes[#codes + 1] = checksum % 103
    codes[#codes + 1] = 106
    return codes
end

-- 绘制 Code128 条码（按宽度等比换算模块宽度）
local function drawBarcode128(bb, data, x, y, width, height)
    local codes = code128Patterns(data)
    local modules = 0
    for _, code in ipairs(codes) do
        local pattern = CODE128_PATTERNS[code + 1]
        for i = 1, #pattern do
            modules = modules + tonumber(pattern:sub(i, i))
        end
    end
    local module_w = width / modules
    local pos = x
    for _, code in ipairs(codes) do
        local pattern = CODE128_PATTERNS[code + 1]
        local black = true
        for i = 1, #pattern do
            local mw = tonumber(pattern:sub(i, i)) * module_w
            if black then
                drawRect(bb, pos, y, math.max(1, mw), height)
            end
            pos = pos + mw
            black = not black
        end
    end
end

-- 诗句轮换选取：每次展示推进一首（状态持久化，手势调出与锁屏共享同一轮换序列）
-- 修复：v2.3.0 原实现按统计周期确定性取模，同一周期内连续展示诗句不变
-- 入参：无（状态存于 G_reader_settings，序号从 1..#QUOTES 循环推进）
-- 设计意图：G_reader_settings:saveSetting 仅写内存缓存，由 KOReader 统一落盘（休眠/退出时 flush），
--           不会频繁写闪存；序号推进保证连续两次展示必然不同（40 首循环）
local function pickQuote()
    local idx = tonumber(G_reader_settings:readSetting(K.QUOTE_TOGGLE_STATE)) or 0
    idx = (idx % #QUOTES) + 1
    G_reader_settings:saveSetting(K.QUOTE_TOGGLE_STATE, idx)
    return QUOTES[idx]
end

-- 生成“朝代·作者”归属行：有朝代 → "唐·许浑"；无朝代 → 仅显示作者
local function formatAttribution(quote)
    if quote.dynasty and quote.dynasty ~= "" then
        return quote.dynasty .. "·" .. quote.author
    end
    return quote.author
end

-- 自定义标题渲染：中文逐字横排（同字号）+ 英文副标（在最后一个中文字下方左对齐）
-- （-- 修改：v2.4.5 泛化签名，墨痕传 {"墨","痕"} + "ink stain"；菜单传 {"留","台","单"} + "Order Slip"）
-- 入参：cn_chars 中文数组（≥1 个）、en_text 英文副标文本
local function drawCustomTitle(bb, x_right, y, scale, cn_chars, en_text)
    cn_chars = cn_chars or { "墨", "痕" }
    en_text = en_text or "ink stain"
    local cn_size = math.max(32, math.min(48, math.floor(42 * scale)))
    local en_size = math.max(10, math.floor(cn_size * 0.32))
    local gap = math.max(2, math.floor(3 * scale))

    -- 逐个中文字创建 TextWidget 并横排
    local cn_widgets, cn_wh = {}, {}
    local cn_total_w = 0
    for _, ch in ipairs(cn_chars) do
        local w = TextWidget:new{ text = ch, face = getFontFace(cn_size), bold = true }
        w:updateSize()
        local ww, wh = w:getSize().w, w:getSize().h
        table.insert(cn_widgets, w)
        cn_wh[#cn_wh + 1] = { w = ww, h = wh }
        if cn_total_w > 0 then cn_total_w = cn_total_w + gap end
        cn_total_w = cn_total_w + ww
    end
    local first_h = cn_wh[1] and cn_wh[1].h or 0
    local last_w = cn_wh[#cn_wh] and cn_wh[#cn_wh].w or 0

    local en_w = TextWidget:new{ text = en_text, face = getFontFace(en_size), bold = false }
    en_w:updateSize()
    local en_w_w, en_w_h = en_w:getSize().w, en_w:getSize().h

    -- 总宽 = max(中文总宽, 末字左边界起的英文宽)：英文以末字左边界对齐
    -- 末字左边界距起点 = 中文总宽 - 末字宽（含全部字间 gap）
    local total_w = math.max(cn_total_w, cn_total_w - last_w + en_w_w)
    local start_x = math.floor(x_right - total_w)

    -- 中文横排：第一个字在 start_x，后续依次右移
    local pos_x = start_x
    local last_x = start_x -- 最后一个中文字的左边界（英文对齐基准）
    for i, w in ipairs(cn_widgets) do
        w:paintTo(bb, pos_x, y)
        last_x = pos_x
        pos_x = pos_x + cn_wh[i].w + gap
    end
    -- 英文：最后一个中文字下方左对齐
    local en_y = y + first_h + math.max(1, math.floor(2 * scale))
    en_w:paintTo(bb, last_x, en_y)

    for _, w in ipairs(cn_widgets) do
        if w.free then w:free() end
    end
    if en_w.free then en_w:free() end

    local total_h = first_h + math.max(1, math.floor(2 * scale)) + en_w_h
    return { w = total_w, h = total_h }
end

-- 动态定位墨痕插件 assets 目录（兼容插件位于 install/plugins、data/plugins 或 data 上级 plugins 三种部署）
local function getInkStainAssetPath(asset_name)
    local data_dir = DataStorage:getDataDir()
    local candidates = {
        "./plugins/inkstain.koplugin",
        data_dir .. "/plugins/inkstain.koplugin",
        data_dir .. "/../plugins/inkstain.koplugin",
    }
    for _, dir in ipairs(candidates) do
        local p = dir .. "/assets/" .. asset_name
        if lfs.attributes(p, "mode") == "file" then
            return p
        end
    end
    return nil
end

-- 读取 KOReader 阅读统计（纯函数，无副作用）
-- 入参：days 统计周期天数（1-30）、top_n 书单数量（1-5）
-- 返回：stats 统计表（books/daily/total_seconds/book_count/has_db 等）
local function readInkStainStats(days, top_n)
    days = math.max(1, math.min(30, tonumber(days) or 7))
    top_n = math.max(1, math.min(5, tonumber(top_n) or 5))
    local today = dayStart()
    local start_ts = today - (days - 1) * 86400
    local end_ts = today + 86400
    local result = {
        start_ts = start_ts,
        end_ts = end_ts,
        days = days,
        books = {},
        daily = {},
        total_seconds = 0,
        total_pages = 0,
        book_count = 0,
        has_db = false,
    }

    -- 初始化每日占位（无记录的日期补 0，保证折线图连续）
    for i = 1, days do
        local ts = start_ts + (i - 1) * 86400
        result.daily[i] = {
            date = dateKey(ts),
            label = shortDate(ts),
            seconds = 0,
        }
    end

    local db_location = DataStorage:getSettingsDir() .. "/statistics.sqlite3"
    result.has_db = lfs.attributes(db_location, "mode") == "file"
    if not result.has_db then
        return result
    end

    local ok, conn = pcall(SQ3.open, db_location)
    if not ok or not conn then
        result.error = "无法打开统计数据库"
        return result
    end

    -- 三条 SQL 查询（每日汇总 / 周期汇总 / 书单排名）统一放入 pcall，异常不会外泄
    local ok_query, err = pcall(function()
        local daily_sql = string.format([[
            SELECT strftime('%%Y-%%m-%%d', start_time, 'unixepoch', 'localtime') AS day,
                   sum(duration) AS seconds,
                   count(DISTINCT page) AS pages
            FROM page_stat
            WHERE start_time >= %d AND start_time < %d
            GROUP BY day
            ORDER BY day;
        ]], start_ts, end_ts)
        local daily_rows = conn:exec(daily_sql)
        local by_day = {}
        if daily_rows then
            local days_col, seconds_col, pages_col = daily_rows[1] or {}, daily_rows[2] or {}, daily_rows[3] or {}
            for i, day in ipairs(days_col) do
                by_day[day] = {
                    seconds = tonumber(seconds_col[i]) or 0,
                    pages = tonumber(pages_col[i]) or 0,
                }
            end
        end
        for _, item in ipairs(result.daily) do
            if by_day[item.date] then
                item.seconds = by_day[item.date].seconds
                result.total_pages = result.total_pages + by_day[item.date].pages
            end
        end

        local total_sql = string.format([[
            SELECT sum(duration), count(DISTINCT id_book)
            FROM page_stat
            WHERE start_time >= %d AND start_time < %d;
        ]], start_ts, end_ts)
        local total_seconds, book_count = conn:rowexec(total_sql)
        result.total_seconds = tonumber(total_seconds) or 0
        result.book_count = tonumber(book_count) or 0

        -- 书单无最低时长门槛：周期内任何有阅读记录的书都可上榜（与用户“在读”语义一致），
        -- 数量仅由下方 LIMIT top_n 截断（-- 修改：v2.0.1 移除原 1 分钟门槛，修复在读书只显示 4 本）
        local min_seconds = 0
        local books_sql = string.format([[
            SELECT b.title,
                   ifnull(b.authors, ''),
                   sum(p.duration) AS seconds,
                   count(DISTINCT p.page) AS read_pages,
                   max(ifnull(b.pages, 0)) AS pages,
                   max(p.start_time) AS last_time
            FROM page_stat p
            JOIN book b ON b.id = p.id_book
            WHERE p.start_time >= %d AND p.start_time < %d
            GROUP BY p.id_book
            HAVING seconds >= %d
            ORDER BY seconds DESC, last_time DESC
            LIMIT %d;
        ]], start_ts, end_ts, min_seconds, top_n)
        local book_rows = conn:exec(books_sql)
        if book_rows then
            local titles = book_rows[1] or {}
            local authors = book_rows[2] or {}
            local seconds = book_rows[3] or {}
            local read_pages = book_rows[4] or {}
            local pages = book_rows[5] or {}
            for i, title in ipairs(titles) do
                table.insert(result.books, {
                    title = title ~= "" and title or "未命名书籍",
                    authors = authors[i] ~= "" and authors[i] or "未知作者",
                    seconds = tonumber(seconds[i]) or 0,
                    read_pages = tonumber(read_pages[i]) or 0,
                    pages = tonumber(pages[i]) or 0,
                    source = "koreader",
                })
            end
        end
    end)

    conn:close()
    if not ok_query then
        result.error = tostring(err)
        logger.warn(LOG_TAG, "读取墨痕统计数据失败：", err)
    end

    -- 数据源仅 KOReader（Miuread 支持已剔除），此处仅做数量兜底
    while #result.books > top_n do
        table.remove(result.books)
    end

    return result
end

-- 生成设备信息字符串：型号 + 屏幕尺寸（英寸）+ 分辨率 + DPI
-- 示例："Kobo Libra 2  4.9寸  824×1200  300dpi"
-- 全部字段带 pcall/类型保护，任何一项缺失自动省略，绝不让渲染崩溃
local function getDeviceInfoString()
    -- 1) 设备型号：优先 Device.model（各平台均已填充），异常回退 "未知设备"
    local model = "未知设备"
    local ok, m = pcall(function() return Device.model end)
    if ok and type(m) == "string" and m ~= "" then
        model = m
    end

    -- 2) 分辨率：取当前渲染画布的竖屏分辨率（与 buildInkStainPng 的 w/h 口径一致）
    local w, h = Screen:getWidth(), Screen:getHeight()
    if w > h then w, h = h, w end

    -- 3) DPI 与屏幕尺寸（英寸 = 对角线像素 / DPI）
    local dpi, diag_inch = nil, nil
    local ok_dpi, d = pcall(function() return Screen:getDPI() end)
    if ok_dpi and type(d) == "number" and d > 0 then
        dpi = math.floor(d + 0.5)
        if w > 0 and h > 0 then
            diag_inch = math.sqrt(w * w + h * h) / dpi
        end
    end

    -- 4) 拼接：缺失的字段自动省略，不含中文标点，保证小屏/窄栏不溢出
    local parts = { "设备：" .. truncate(model, 24) }
    if diag_inch then
        table.insert(parts, string.format("%.1f寸", diag_inch))
    end
    table.insert(parts, string.format("%d×%d", w, h))
    if dpi then
        table.insert(parts, string.format("%ddpi", dpi))
    end
    return table.concat(parts, "  ")
end

-- 渲染墨痕壁纸到内存 BlitBuffer（纯函数，不写盘）
-- 入参：stats 统计表（readInkStainStats 返回值）、opts={days, top_n, title}
-- 返回：BlitBuffer（全屏白底 + 墨痕账单排版），调用方负责释放
local function buildInkStainPng(stats, opts)
    opts = opts or {}
    local top_n = math.max(1, math.min(5, tonumber(opts.top_n) or 5))
    -- 渲染模式：inkstain 墨痕壁纸 / menu 菜单样式（留台单）（-- 修改：v2.4.5）
    local mode = opts.content_mode or "inkstain"

    local w, h = Screen:getWidth(), Screen:getHeight()
    -- 竖屏优先：横屏时交换宽高（墨痕排版按竖版设计）
    if w > h then
        w, h = h, w
    end
    -- 极端小屏兜底：保证最小画布不至于无法排版
    if w < 300 or h < 300 then
        w, h = 824, 1200
    end

    local bb = Blitbuffer.new(w, h, Screen.bb:getType())
    bb:fill(Blitbuffer.COLOR_WHITE)

    -- 尺寸按基准画布（600x800）等比缩放，保证不同 DPI/尺寸设备上排版一致
    local scale = math.min(w / 600, h / 800)
    local margin_x = math.max(20, math.floor(w * 0.05))
    local margin_y = math.max(18, math.floor(h * 0.035))
    local title_size = math.max(32, math.min(48, math.floor(42 * scale)))
    local large = math.max(20, math.min(30, math.floor(26 * scale)))
    local normal = math.max(11, math.min(15, math.floor(13 * scale)))
    local small = math.max(9, math.min(12, math.floor(10 * scale)))
    local tiny = math.max(8, math.min(10, math.floor(8 * scale)))
    local line_w = 1
    local content_w = w - margin_x * 2

    -- ========== 内容上下文 ctx：两种模式集中产出全部文本与表格行（-- 修改：v2.4.5 模式化） ==========
    -- 墨痕（inkstain）与菜单（menu）共用同一套布局几何，仅文本内容与表格数据不同；
    -- 折线图 / 日期标签数据源（stats.daily）两种模式完全一致，不由 ctx 控制。
    local ctx = {}
    if mode == "menu" then
        local menu = opts.menu or {}
        local items = menu.items or {}
        local total_price = tonumber(menu.total) or 0
        ctx.title_cn = { "留", "台", "单" }
        ctx.title_en = "Order Slip"
        ctx.title_fallback = opts.title or "留台单"
        ctx.order_line = "单号：" .. os.date("%m%d", stats.end_ts - 1)
        -- 需求7：仅显示当天日期（年.月.日），"时间"改为"下单时间"
        ctx.date_line = "下单时间：" .. os.date("%Y.%m.%d")
        -- 需求9："设备"改为"点单设备"，仍显示真实设备信息
        ctx.device_line = "点单设备：" .. getDeviceInfoString()
        -- 需求8："时长"改为"总计光临本店"（-- 修改：v2.4.9 时间统一换算为"天"为单位显示）
        ctx.duration_line = "总计光临本店：" .. formatDurationDays(stats.total_seconds)
        -- 需求4："书单"改为"菜单"
        ctx.list_title = "菜单"
        -- 需求3："单位"改为"单价"
        ctx.header_unit = "单价"
        -- 需求8："日均"改为"用餐时间"（数值与墨痕一致）
        ctx.summary_left = "用餐时间：" .. formatDuration(stats.total_seconds / math.max(1, stats.days))
        -- 需求5：合计 = 5 道菜价格总和（求和逻辑在 buildMenuData）+ "元"
        ctx.summary_right = "合计：" .. tostring(total_price) .. "元"
        -- 条码：日期-总价-菜品数；QR 种子用当天日期
        ctx.qr_seed = os.date("%Y%m%d")
        ctx.barcode = os.date("%Y%m%d") .. "-" .. tostring(total_price) .. "-" .. tostring(#items)
        -- 需求6：名言随菜单数据一并生成（每张单一条，供右下角名言区展示）
        ctx.quotation = menu.quotation
        -- 需求1：三行分别替换为 菜名/特色/食材；需求3：单价列 = 价格 + 元
        ctx.rows = {}
        for i = 1, math.min(#items, 5) do
            ctx.rows[i] = {
                title = truncate(items[i].name or "", 22),
                -- （-- 修改：v2.4.6 特色/食材不再按固定字符数截断，存完整文本，
                -- 绘制时按 title_w 像素宽度截断，充分利用右侧空间且不与数量栏重叠）
                line2 = "特色：" .. (items[i].feature or ""),
                line3 = "食材：" .. (items[i].ingredients or ""),
                qty = "1",
                unit = tostring(items[i].price or 0) .. "元",
            }
        end
        if #ctx.rows == 0 then
            ctx.empty_msg = "菜单数据生成失败，请查看日志。"
        end
    else
        -- 墨痕模式：文本与现有实现保持一致，仅数据源迁移进 ctx（行为零变化）
        ctx.title_cn = { "墨", "痕" }
        ctx.title_en = "ink stain"
        ctx.title_fallback = opts.title or "墨痕"
        ctx.order_line = "单号：" .. os.date("%m%d", stats.end_ts - 1)
        ctx.date_line = "时间：" .. os.date("%Y.%m.%d", stats.start_ts) .. " - " .. os.date("%Y.%m.%d", stats.end_ts - 1)
        ctx.device_line = getDeviceInfoString()
        -- （-- 修改：v2.4.9 墨痕"时长"与菜单"总计光临本店"统一换算为"天"为单位显示）
        ctx.duration_line = "时长：" .. formatDurationDays(stats.total_seconds)
        ctx.list_title = "书单：Top " .. tostring(top_n)
        ctx.header_unit = "单位"
        ctx.summary_left = "日均：" .. formatDuration(stats.total_seconds / math.max(1, stats.days))
        ctx.summary_right = "合计：" .. formatDuration(stats.total_seconds)
        ctx.qr_seed = os.date("%Y%m%d", stats.end_ts - 1)
        ctx.barcode = os.date("%Y%m%d", stats.end_ts - 1) .. "-" .. tostring(math.floor((stats.total_seconds or 0) / 60)) .. "-" .. tostring(stats.book_count or 0)
        ctx.quotation = opts.quotation -- 可注入；未注入时由底部名言区随机抽取
        ctx.rows = {}
        for i, book in ipairs(stats.books or {}) do
            local progress = "—"
            if book.progress then
                progress = string.format("%d%%", math.min(100, math.floor(book.progress + 0.5)))
            elseif book.pages and book.pages > 0 and book.read_pages then
                progress = string.format("%d%%", math.min(100, math.floor(book.read_pages * 100 / book.pages + 0.5)))
            end
            ctx.rows[i] = {
                title = truncate(book.title, 22),
                line2 = "作者：" .. truncate(book.authors, 18),
                line3 = "进度：" .. progress .. "  本期：" .. formatDuration(book.seconds),
                qty = "1",
                unit = "本",
            }
        end
        if #ctx.rows == 0 then
            -- 无记录时的友好提示（区分数据库缺失与空周期）
            if stats.error then
                ctx.empty_msg = "读取统计失败：" .. truncate(stats.error, 28)
            elseif not stats.has_db then
                ctx.empty_msg = "未找到 KOReader 阅读统计数据库，请先启用“阅读统计”。"
            else
                ctx.empty_msg = "本周期暂无可显示的阅读记录。"
            end
        end
    end

    local y = margin_y
    local s
    -- 自定义标题（模式化：墨痕传 墨/痕 + ink stain；菜单传 留/台/单 + Order Slip）
    -- 渲染失败时回退普通标题（-- 修改：v2.4.5 改用 ctx 提供的中英文）
    local ok_title, title_result = pcall(drawCustomTitle, bb, w - margin_x, y, scale, ctx.title_cn, ctx.title_en)
    if ok_title and title_result then
        s = title_result
    else
        logger.warn(LOG_TAG, "自定义标题渲染失败，回退普通标题：", title_result)
        s = drawText(bb, ctx.title_fallback, w - margin_x, y, title_size, true, nil, "right")
    end
    drawText(bb, ctx.order_line, margin_x, y + math.floor(s.h * 0.25), large, true)
    y = y + s.h + math.max(4, math.floor(4 * scale))
    s = drawText(bb, ctx.date_line, margin_x, y, small, false, content_w)
    y = y + s.h + math.max(2, math.floor(2 * scale))
    -- 修改：v2.0.2 去除"来源"栏，设备行改为动态设备信息（型号/屏幕尺寸/分辨率/DPI）
    s = drawText(bb, ctx.device_line, margin_x, y, small, false, content_w)
    y = y + s.h + math.max(4, math.floor(4 * scale))
    drawText(bb, ctx.duration_line, margin_x, y, normal, true, content_w * 0.55)
    s = drawText(bb, ctx.list_title, w - margin_x, y, normal, true, nil, "right")
    y = y + s.h + math.max(8, math.floor(8 * scale))
    drawLine(bb, margin_x, y, w - margin_x, y, line_w)

    -- 表头：品类 / 数量 / 单位
    local table_header_y = y + math.max(8, math.floor(8 * scale))
    local x_no = margin_x
    -- 实测“No.xx”编号列宽度（top_n ≤ 5 恒为两位编号），让书名列起点更靠左、可用宽度更长（-- 修改：v2.0.1 替代固定 76*scale / v2.4.2 NO.→No.）
    local no_label = string.format("No.%02d", math.max(1, top_n or 1))
    local x_title = x_no + measureText(no_label, normal, true) + math.max(10, math.floor(8 * scale))
    local x_qty = w - margin_x - math.floor(68 * scale)
    local x_unit = w - margin_x - math.floor(18 * scale)
    -- 书名列右边界：距“数量”栏数字中心保持美观间距，避免重叠
    local title_w = math.max(120, x_qty - x_title - math.max(14, math.floor(12 * scale)))
    drawText(bb, "品类", x_no, table_header_y, small, false)
    drawText(bb, "数量", x_qty, table_header_y, small, false, nil, "center")
    -- 表头末列：墨痕"单位" / 菜单"单价"（-- 修改：v2.4.5 模式化）
    drawText(bb, ctx.header_unit, x_unit, table_header_y, small, false, nil, "center")
    y = table_header_y + math.max(22, math.floor(22 * scale))
    drawLine(bb, margin_x, y, w - margin_x, y, line_w)

    -- ========== 底部区域预分配（v2.4.4 表格锚定 + 自顶向下）==========
    -- 布局自表格底部向下依次为：表格底分隔线 → 汇总行区 → 折线图 → 日期标签行 →
    -- date_gap → 二维码带（QR+条码，高度 qr_size）→ qr_gap → 诗句三行块
    -- 表格区恒按 5 本预留高度，分隔线紧贴书单底部；底部区块自顶向下紧凑排列，
    -- 屏幕底部自然留白（-- 修改：v2.4.4 取代原屏幕底部反推贴底方案）
    -- 先实测本轮诗句三行真实高度，保证任意屏幕/字号下区块恒分离、恒不出界
    local quote = pickQuote()       -- 每次渲染仅调用一次，与后续绘制使用同一首
    local quote_size = small
    local meta_size = tiny
    local author_line = formatAttribution(quote)
    local work_line = "《" .. quote.work .. "》"
    -- 右侧名人名言（-- 修改：v2.4.5 取代版权署名"Design by Estela-Zelin84"）：
    -- 名言/名人/出处三行，与左侧诗句三行水平对齐；菜单模式取 ctx.quotation（随菜单生成），
    -- 墨痕模式取注入值或随机抽取一条（保证一次渲染仅抽一条）
    local quotation = ctx.quotation or pickRandomQuotation()
    -- 防御：解析异常导致语料缺失时使用空串兜底，避免绘制崩溃
    if not quotation or not quotation.quote then
        quotation = { quote = "", person = "", source = "" }
    end
    -- 名言第一行/出处行提前格式化为标准引用样式（引号句号/书名号），
    -- 使下方宽度/高度预留测量与实际绘制使用同一文本（-- 修改：v2.4.6/v2.4.7）
    local quote_first_line = quotation.quote ~= "" and ("“" .. quotation.quote .. "。”") or ""
    local source_line = quotation.source ~= "" and ("《" .. quotation.source .. "》") or ""
    -- 右侧名言三行：字号与左下诗词板块逐行完全一致（-- 修改：v2.4.8）
    --   名言行 = 诗句行 quote_size；名人行 = 朝代·作者行 meta_size；出处行 = 作品名行 meta_size
    -- size 字段供宽度预留测量按实际字号计算，避免按小字号测量导致预留偏窄
    local right_lines = {
        { text = quote_first_line, size = quote_size, bold = false },
        { text = quotation.person, size = meta_size,  bold = false },
        { text = source_line,      size = meta_size,  bold = false },
    }
    local line_gap = math.max(2, math.floor(2 * scale))
    -- 右侧名言带预留宽度：三行实测宽取最大，限幅不超过内容宽一半，避免挤占诗句
    local right_w = 0
    for _, rl in ipairs(right_lines) do
        local w_i = measureText(rl.text, rl.size, rl.bold)
        if w_i > right_w then right_w = w_i end
    end
    local credit_w = math.min(right_w, content_w * 0.5)
    local credit_gap = math.max(8, math.floor(8 * scale))
    local quote_w_max = math.max(content_w * 0.4, content_w - credit_w - credit_gap)
    local quote_h = measureTextH(quote.text, quote_size, false, quote_w_max)
    local author_h = measureTextH(author_line, meta_size, false, content_w * 0.5)
    local work_h = measureTextH(work_line, meta_size, false, content_w * 0.6)
    -- 右侧名言行与诗句行同字号，但最大宽限更大（content_w*0.55），长文本可能换行更高；
    -- 第一行行距基准取两者较大值，保证与下方"名人"行不重叠（-- 修改：v2.4.8 字号统一）
    local right_quote_h = measureTextH(quote_first_line, quote_size, false, content_w * 0.55)
    local first_line_h = math.max(quote_h, right_quote_h)
    local poem_block_h = first_line_h + line_gap + author_h + line_gap + work_h

    -- 底部各区块间距（全部随 scale 缩放，适配不同屏幕）
    local qr_gap = math.max(8, math.floor(8 * scale))        -- 二维码带与诗句块间距（-- 修改：v2.4.1 收紧）
    local date_gap = math.max(4, math.floor(4 * scale))      -- 日期标签行与二维码带间距（分离保障，-- 修改：v2.4.1 收紧）
    local date_label_h = math.max(10, math.floor(10 * scale)) + measureTextH("日", tiny, false, 100) -- 日期标签行高
    local qr_size = math.max(36, math.floor(42 * scale))      -- 二维码带高度（QR 主导，不压缩保证可扫描）
    local barcode_h = math.max(30, math.floor(34 * scale))    -- 条码带高度
    -- 折线图高度：屏高 11.5% 与缩放下限取大，优先保证数据可视化区域完整（-- 修改：v2.4.0 响应式下限替代硬编码 68）
    local chart_h = math.max(math.floor(60 * scale), math.floor(h * 0.115))
    -- 汇总行区高度：分隔线到图表顶的间距（原 34*scale 语义不变）
    local summary_area = math.max(34, math.floor(34 * scale))

    -- 表格可用高度与可见行数
    local rows_top = y + math.max(8, math.floor(8 * scale))
    -- 行高按内容瘦身（-- 修改：v2.4.1 58*scale→52*scale）：行内内容（书名+作者+进度）实测约 60-65px，新行高仍富余
    local min_row_h = math.max(50, math.floor(52 * scale))
    local row_h = min_row_h
    -- 表格区恒按 5 本预留高度：无书/少书时留白，分隔线位置稳定（-- 修改：v2.4.4 用户要求）
    local table_slots = 5
    -- 分隔线与「第 5 本书」底部的小缝隙（仅美观间距）
    local table_gap = math.max(2, math.floor(3 * scale))

    -- 底部区块总高（不含表格区），用于极端小屏防御
    local bottom_block_h = summary_area + chart_h + date_label_h + date_gap
        + qr_size + qr_gap + poem_block_h
    -- 防御：极端小屏空间不足时削减折线图高度（保底 48*scale），确保诗句块不越界
    -- （真实设备 ≥480x800 均富余，此分支通常不触发）
    local required_h = rows_top + table_slots * row_h + table_gap + bottom_block_h
    if required_h > h then
        chart_h = math.max(math.floor(48 * scale), chart_h - (required_h - h))
    end

    -- 表格底线：恒为「第 5 本书位置」+ 小缝隙（-- 修改：v2.4.4 自顶向下锚定，不再由屏幕底部反推）
    local table_bottom = rows_top + table_slots * row_h + table_gap
    local chart_top = table_bottom + summary_area
    local chart_bottom = chart_top + chart_h
    -- 可见行数：墨痕受数据量与 top_n 约束恒 ≤ 5；菜单恒为全部 5 道菜
    -- （不受"书单数量"设置影响，保证 5 道菜完整展示；-- 修改：v2.4.5）
    local visible_rows = mode == "menu" and #ctx.rows or math.min(#ctx.rows, top_n, 5)

    y = rows_top
    if #ctx.rows == 0 then
        -- 无数据时的友好提示（墨痕区分数据库缺失与空周期；菜单提示数据生成失败）
        drawBoxText(bb, ctx.empty_msg or "暂无数据", margin_x, y + 8 * scale, content_w, normal, true)
    else
        for i = 1, visible_rows do
            local row = ctx.rows[i]
            local no = string.format("No.%02d", i) -- （-- 修改：v2.4.2 NO.→No.，与列宽测量处同口径）
            drawText(bb, no, x_no, y, normal, true)
            s = drawText(bb, row.title, x_title, y, normal, true, title_w)
            local meta_y = y + math.max(s.h, 18)
            -- 菜单模式：特色/食材行按 title_w 像素宽度截断（利用右侧空间且防重叠）；
            -- 墨痕模式保持原固定字符截断（-- 修改：v2.4.6）
            local line2_draw, line3_draw = row.line2, row.line3
            if mode == "menu" then
                line2_draw = truncateToWidth(row.line2, title_w, tiny, false)
                line3_draw = truncateToWidth(row.line3, title_w, tiny, false)
            end
            drawText(bb, line2_draw, x_title, meta_y, tiny, false, title_w)
            drawText(bb, line3_draw, x_title, meta_y + math.max(14, math.floor(14 * scale)), tiny, false, title_w)
            drawText(bb, row.qty, x_qty, y + math.floor(row_h * 0.1), normal, true, nil, "center")
            drawText(bb, row.unit, x_unit, y + math.floor(row_h * 0.1), normal, true, nil, "center")
            y = y + row_h
        end
        -- "另有省略"提示仅墨痕模式有意义（菜单恒 5 道全展示，不触发）
        if mode ~= "menu" and #ctx.rows > visible_rows then
            drawText(bb, "另有 " .. tostring(#ctx.rows - visible_rows) .. " 本因屏幕高度省略", x_title, math.min(y, table_bottom - 18 * scale), tiny, false, title_w)
        end
    end
    drawLine(bb, margin_x, table_bottom, w - margin_x, table_bottom, line_w)

    -- 底部折线图（日均阅读时长趋势）+ 汇总
    local chart_w = content_w - 10 * scale
    local chart_x = margin_x + 5 * scale
    -- 汇总行：墨痕"日均/合计" / 菜单"用餐时间/合计N元"（-- 修改：v2.4.5 模式化）
    drawText(bb, ctx.summary_left, margin_x, chart_top - math.max(24, math.floor(24 * scale)), normal, true)
    drawText(bb, ctx.summary_right, w - margin_x, chart_top - math.max(24, math.floor(24 * scale)), normal, true, nil, "right")
    drawLine(bb, chart_x, chart_top, chart_x, chart_top + chart_h, line_w)
    drawLine(bb, chart_x, chart_top + chart_h, chart_x + chart_w, chart_top + chart_h, line_w)

    local max_seconds = 1
    for _, item in ipairs(stats.daily) do
        if item.seconds > max_seconds then max_seconds = item.seconds end
    end
    local points = {}
    local count = #stats.daily
    local label_step = math.max(1, math.ceil(count / 7))
    for i, item in ipairs(stats.daily) do
        local x = chart_x + (count == 1 and chart_w / 2 or (i - 1) * chart_w / (count - 1))
        local yy = chart_top + chart_h - (item.seconds / max_seconds) * (chart_h - 16 * scale)
        table.insert(points, { x = x, y = yy, label = item.label, seconds = item.seconds, index = i })
    end
    for i = 1, #points - 1 do
        drawLine(bb, points[i].x, points[i].y, points[i + 1].x, points[i + 1].y, 2 * scale)
    end
    for _, p in ipairs(points) do
        drawRect(bb, p.x - 2 * scale, p.y - 2 * scale, 5 * scale, 5 * scale)
        if p.seconds == max_seconds and p.seconds > 0 then
            drawText(bb, tostring(math.floor(p.seconds / 60 + 0.5)) .. "分", p.x, p.y - 18 * scale, tiny, false, nil, "center")
        end
        if count <= 10 or p.index == 1 or p.index == count or (p.index - 1) % label_step == 0 then
            -- 日期标签绘制于 chart_bottom 下方的日期标签行区内（date_label_h），
            -- 其下 date_gap 处即二维码带，两行恒分离（-- 修改：v2.4.0）
            drawText(bb, p.label, p.x, chart_top + chart_h + 10 * scale, tiny, false, nil, "center")
        end
    end

    -- 二维码/条码带：顶部固定位于日期标签行之下 date_gap 处，两行恒分离（-- 修改：v2.4.0）
    local footer_y = chart_bottom + date_label_h + date_gap
    -- 条码在带内垂直居中，与 QR 构成整齐的一行（-- 修改：v2.4.0 替代顶部对齐）
    local barcode_y = footer_y + math.max(0, math.floor((qr_size - barcode_h) / 2))
    local qr_path = getInkStainAssetPath("github_qr.png")
    -- QR 种子：墨痕用周期末日期，菜单用当天日期（-- 修改：v2.4.5 模式化）
    if not drawImage(bb, qr_path, margin_x, footer_y, qr_size) then
        drawPseudoQR(bb, margin_x, footer_y, qr_size, ctx.qr_seed)
    end
    local x = margin_x + qr_size + 18 * scale
    local barcode_right = w - margin_x
    -- 条码数据：墨痕"日期-分钟-书数"；菜单"日期-总价-菜品数"（-- 修改：v2.4.5 模式化）
    local barcode_data = ctx.barcode
    drawBarcode128(bb, barcode_data, x, barcode_y, barcode_right - x, barcode_h)

    -- 诗句三行跟随整体：右侧名言三行与诗句三行同一行右对齐（-- 修改：v2.4.4 不再贴底）
    -- （-- 修改：v2.4.5 版权署名替换为名言三行，与诗句三行水平对齐）
    -- （-- 修改：v2.4.4 自顶向下：位于二维码带下方 qr_gap 处，屏幕底部自然留白）
    local poem_top = footer_y + qr_size + qr_gap
    local y_quote = poem_top
    -- 行距基准用第一行实测高度取大值（诗句行/名言行中较高者），保证两板块行均不重叠
    -- （-- 修改：v2.4.8 名言行与诗句行同字号后，行高可能高于诗句行）
    local y_author = y_quote + first_line_h + line_gap
    local y_work = y_author + author_h + line_gap
    -- 左侧诗句三行
    drawText(bb, quote.text, margin_x, y_quote, quote_size, false, quote_w_max)
    drawText(bb, author_line, margin_x, y_author, meta_size, false, content_w * 0.5)
    drawText(bb, work_line, margin_x, y_work, meta_size, false, content_w * 0.6)
    -- 右侧名言三行（右对齐，与左侧诗句三行同一 y：需求6 水平对齐）
    -- 字号与左下诗词板块逐行完全一致：名言行=诗句行 quote_size，名人行/出处行=meta_size
    -- （-- 修改：v2.4.6 名言第一行加中文引号与句号；v2.4.7 出处行加书名号；v2.4.8 字号统一。
    -- 格式文本已在布局段提前构建（quote_first_line/source_line），此处直接复用）
    drawText(bb, quote_first_line, w - margin_x, y_quote, quote_size, false, content_w * 0.55, "right")
    drawText(bb, quotation.person, w - margin_x, y_author, meta_size, false, content_w * 0.55, "right")
    drawText(bb, source_line, w - margin_x, y_work, meta_size, false, content_w * 0.55, "right")

    return bb
end

-- 墨痕壁纸加载失败的兜底提示组件
local function buildInkStainFallbackWidget(message)
    return CenterContainer:new{
        dimen = Screen:getSize(),
        TextWidget:new{
            text = message,
            face = Font:getFace("cfont", 20),
            fgcolor = Blitbuffer.COLOR_BLACK,
        },
    }
end

-- 构建墨痕壁纸 / 菜单样式 Widget（全屏图 + 底部居中小花按钮）
-- 小花按钮：点击后关闭当前界面并广播 ShowReadingInsightsPopup 跳转阅读洞察
-- 入参：style 当前样式（K.STYLE_INKSTAIN / K.STYLE_MENU；-- 修改：v2.4.5 新增菜单样式）
local function buildInkStainWidget(ui, on_close_callback, style)
    local is_menu = style == K.STYLE_MENU
    local mode_name = is_menu and "菜单" or "墨痕"
    -- 读取墨痕专属设置（统计周期 / 书单数量），非法值自动收敛到安全范围
    local days = math.max(1, math.min(30, tonumber(G_reader_settings:readSetting(K.INKSTAIN_DAYS)) or 7))
    local top_n = math.max(1, math.min(5, tonumber(G_reader_settings:readSetting(K.INKSTAIN_TOP_N)) or 5))

    -- 统计读取与渲染均带 pcall 保护，失败时展示中文提示而非崩溃
    -- 菜单样式同样依赖阅读统计（折线图/用餐时间/总计光临本店的数据来源，用户已确认与墨痕一致）
    local ok_stats, stats = pcall(readInkStainStats, days, top_n)
    if not ok_stats or not stats then
        logger.warn(LOG_TAG, "读取" .. mode_name .. "统计失败：", stats)
        return buildInkStainFallbackWidget(is_menu and _("无法显示留台单，请检查阅读统计数据库") or _("无法显示墨痕壁纸，请检查阅读统计数据库"))
    end
    local opts = { days = days, top_n = top_n, title = is_menu and "留台单" or "墨痕" }
    if is_menu then
        -- 菜单样式：生成 5 道菜 + 名言数据（-- 修改：v2.4.5）
        local ok_menu, menu = pcall(buildMenuData)
        if not ok_menu or not menu then
            logger.warn(LOG_TAG, "生成菜单数据失败：", menu)
            return buildInkStainFallbackWidget(_("菜单数据生成失败，请查看日志"))
        end
        opts.content_mode = "menu"
        opts.menu = menu
    end
    local ok_png, bb = pcall(buildInkStainPng, stats, opts)
    if not ok_png or not bb then
        logger.warn(LOG_TAG, "渲染" .. mode_name .. "失败：", bb)
        return buildInkStainFallbackWidget(is_menu and _("留台单渲染失败，请查看日志") or _("墨痕壁纸渲染失败，请查看日志"))
    end

    -- ImageWidget 直接使用内存 BlitBuffer（不写盘）；关闭时自动 free 释放内存
    local img = ImageWidget:new{
        image = bb,
        alpha = true,
        width = Screen:getWidth(),
        height = Screen:getHeight(),
        scale_factor = 0,
    }

    -- 小花按钮：与胶片票根同款交互（关闭当前界面 + 延迟广播阅读洞察事件）
    local screen_size = Screen:getSize()
    local badge_size = Screen:scaleBySize(40)
    local badge_margin = Screen:scaleBySize(16)
    local badge_btn = Button:new{
        text = "✿",
        text_face = Font:getFace("cfont", Screen:scaleBySize(18)),
        fg_color = Blitbuffer.COLOR_BLACK,
        background = Blitbuffer.COLOR_WHITE,
        bordersize = 0,
        padding = 0,
        width = badge_size,
        height = badge_size,
        callback = function()
            if on_close_callback then on_close_callback() end
            UIManager:setDirty(nil, "full")
            -- 延迟广播，确保当前界面先完成关闭，避免事件被当前 widget 拦截
            UIManager:scheduleIn(0.25, function()
                local Event = require("ui/event")
                local ok, err = pcall(function()
                    UIManager:broadcastEvent(Event:new("ShowReadingInsightsPopup"))
                end)
                if not ok then
                    UIManager:show(InfoMessage:new{ text = _("无法打开阅读洞察，请确认插件已正确安装") })
                    logger.warn(LOG_TAG, "open reading insights failed:", err)
                end
            end)
        end,
    }
    -- 定位小花到底部居中（OverlapGroup 子组件偏移量）
    badge_btn.overlap_offset = {
        math.floor((screen_size.w - badge_size) / 2),
        screen_size.h - badge_size - badge_margin,
    }

    local overlap = OverlapGroup:new{
        dimen = screen_size,
        img,
        badge_btn,
    }
    return overlap
end

-- 补丁加载时尝试将墨痕插件自带字体复制到 koreader/fonts/（失败自动回退 cfont）
do
    local font_src = getInkStainAssetPath(PLUGIN_FONT_NAME)
    local font_dest = FontList.fontdir .. "/" .. PLUGIN_FONT_NAME
    if font_src and lfs.attributes(font_src, "mode") == "file" and not lfs.attributes(font_dest, "mode") then
        local src_f = io.open(font_src, "rb")
        if src_f then
            local content = src_f:read("*a")
            src_f:close()
            local dest_f = io.open(font_dest, "wb")
            if dest_f then
                dest_f:write(content)
                dest_f:close()
                logger.info(LOG_TAG, "已复制墨痕字体到", font_dest)
            else
                logger.warn(LOG_TAG, "墨痕字体写入失败：", font_dest)
            end
        end
    end
end

-- ========== 阅读小票分发器 ==========
-- 依据当前样式设置（或随机结果）分派到对应的构建函数：
--   · inkstain：墨痕壁纸（无需活动文档）
--   · menu：菜单样式（留台单，布局与墨痕一致，-- 修改：v2.4.5）
--   · film：胶片票根（内部含 hasActiveDocument 检查）
local function buildReceipt(ui, state, on_close_callback)
    local style = getEffectiveStyle()
    if style == K.STYLE_INKSTAIN or style == K.STYLE_MENU then
        return buildInkStainWidget(ui, on_close_callback, style)
    end
    return buildFilmReceipt(ui, state, on_close_callback)
end


-- ========== QuickLook 弹窗组件 ==========
local quicklookbox = InputContainer:extend{
    modal = true,
    name = "quick_look_box",
    covers_fullscreen = true,
}

function quicklookbox:init()
    local receipt_widget = buildReceipt(self.ui, self.state, function()
        UIManager:close(self)
    end)
    if receipt_widget then
        self[1] = receipt_widget
    else
        self[1] = CenterContainer:new{
            dimen = Screen:getSize(),
            TextWidget:new{
                text = _("Receipt unavailable"),
                face = Font:getFace("cfont", 20),
            },
        }
    end

    if Device:hasKeys() then
        self.key_events.AnyKeyPressed = { { Device.input.group.Any } }
    end
    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = function() return self.dimen end,
            }
        }
        self.ges_events.Tap = {
            GestureRange:new{
                ges = "tap",
                range = function() return self.dimen end,
            }
        }
        self.ges_events.MultiSwipe = {
            GestureRange:new{
                ges = "multiswipe",
                range = function() return self.dimen end,
            }
        }
    end
end

function quicklookbox:onTap() self:onClose() end
function quicklookbox:onSwipe(arg, ges_ev) self:onClose() end
function quicklookbox:onClose()
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
    return true
end
quicklookbox.onAnyKeyPressed = quicklookbox.onClose
quicklookbox.onMultiSwipe = quicklookbox.onClose

-- 注册分发器动作
Dispatcher:registerAction("quicklookbox_action", {
    category="none",
    event="QuickLook",
    title=_("Book receipt"),
    reader=true,
})

function ReaderUI:onQuickLook()
    local ui = self
    UIManager:nextTick(function()
        if not ui then return end
        local widget = quicklookbox:new{
            ui = ui,
            document = ui.document,
            state = ui.view and ui.view.state,
        }
        UIManager:show(widget)
    end)
end

-- ========== 屏保集成 ==========
local Screensaver = require("ui/screensaver")
local orig_screensaver_show = Screensaver.show

Screensaver.show = function(self)
    if self.screensaver_type ~= "book_receipt" then
        return orig_screensaver_show(self)
    end

    local ui = self.ui or ReaderUI.instance
    -- 墨痕/菜单样式基于 KOReader 全局统计，无需打开书籍即可锁屏；胶片票根必须存在活动文档
    -- （-- 修改：v2.4.5 判断扩展为墨痕 + 菜单两种基于统计的样式）
    local style = getEffectiveStyle()
    local is_stat_based = style == K.STYLE_INKSTAIN or style == K.STYLE_MENU
    if not is_stat_based and not hasActiveDocument(ui) then
        showFallbackScreensaver(self, orig_screensaver_show)
        return
    end

    if self.screensaver_widget then
        UIManager:close(self.screensaver_widget)
        self.screensaver_widget = nil
    end

    Device.screen_saver_mode = true

    local rotation_mode = Screen:getRotationMode()
    Device.orig_rotation_mode = rotation_mode
    if bit.band(rotation_mode, 1) == 1 then
        Screen:setRotationMode(Screen.DEVICE_ROTATED_UPRIGHT)
    else
        Device.orig_rotation_mode = nil
    end

    local state = ui and ui.view and ui.view.state
    local receipt_widget = buildReceipt(ui, state, function()
        if self.close then
            self:close()
        else
            if self.screensaver_widget then
                UIManager:close(self.screensaver_widget)
                self.screensaver_widget = nil
            end
            if Device.screen_saver_mode then
                Device.screen_saver_mode = false
                if Device.orig_rotation_mode then
                    Screen:setRotationMode(Device.orig_rotation_mode)
                    Device.orig_rotation_mode = nil
                end
            end
        end
        UIManager:setDirty(nil, "full")
    end)

    if receipt_widget then
        local background_color, background_widget = getReceiptBackground(ui)
        -- 旧"黑底终端"样式的黑色背景特判已随该样式移除；
        -- 墨痕本身为白底全屏排版，背景设置仅对胶片票根生效，此处无需再按样式特判
        local widget_to_show = receipt_widget

        if background_widget then
            widget_to_show = OverlapGroup:new{
                dimen = Screen:getSize(),
                background_widget,
                receipt_widget,
            }
        end

        self.screensaver_widget = ScreenSaverWidget:new{
            widget = widget_to_show,
            background = background_color,
            covers_fullscreen = true,
        }
        self.screensaver_widget.modal = true
        self.screensaver_widget.dithered = true
        UIManager:show(self.screensaver_widget, "full")
    else
        logger.warn(LOG_TAG, "构建阅读小票/墨痕壁纸失败，回退默认屏保")
        showFallbackScreensaver(self, orig_screensaver_show)
    end
end

-- ========== 菜单挂载 ==========
-- 通过拦截 dofile 解析菜单的机制，把阅读小票选项塞进原生的"屏保"设置菜单中
local orig_dofile = dofile
_G.dofile = function(filepath)
    local result = orig_dofile(filepath)

    if filepath and filepath:match("screensaver_menu%.lua$") then
        if result and result[1] and result[1].sub_item_table then
            local wallpaper_submenu = result[1].sub_item_table

            -- 通用单选菜单项生成器（保存设置键值并显示勾选状态）
            local function genMenuItem(text, setting, value, enabled_func, separator)
                return {
                    text = text,
                    enabled_func = enabled_func,
                    checked_func = function()
                        return G_reader_settings:readSetting(setting) == value
                    end,
                    callback = function()
                        G_reader_settings:saveSetting(setting, value)
                    end,
                    radio = true,
                    separator = separator,
                }
            end

            local function isBookReceiptEnabled()
                return G_reader_settings:readSetting("screensaver_type") == "book_receipt"
            end

            table.insert(wallpaper_submenu, 6,
                genMenuItem(_("Show book receipt on sleep screen"), "screensaver_type", "book_receipt")
            )

            -- 显示风格：固定(胶片/墨痕) / 随机出现 / 轮流出现，四选一 radio
            local function styleMenuItem(text, value)
                return {
                    text = text,
                    checked_func = function()
                        return getStyleMode() == "fixed"
                            and normalizeReceiptStyle(G_reader_settings:readSetting(K.STYLE_SETTING)) == value
                    end,
                    callback = function()
                        G_reader_settings:saveSetting(K.STYLE_SETTING, value)
                        G_reader_settings:saveSetting(K.STYLE_MODE_SETTING, "fixed")
                        G_reader_settings:saveSetting(K.RANDOM_STYLE, false)
                    end,
                    radio = true,
                }
            end

            local function modeMenuItem(text, mode, help_text)
                return {
                    text = text,
                    checked_func = function() return getStyleMode() == mode end,
                    callback = function()
                        G_reader_settings:saveSetting(K.STYLE_MODE_SETTING, mode)
                        -- 同步旧版随机开关键，保证设置兼容一致
                        G_reader_settings:saveSetting(K.RANDOM_STYLE, mode == "random")
                    end,
                    radio = true,
                    help_text = help_text,
                }
            end

            local style_menu = {
                text = _("Style"),
                sub_item_table = {
                    styleMenuItem(_("Film strip (fixed style)"), K.STYLE_FILM),
                    styleMenuItem(_("Ink stain"), K.STYLE_INKSTAIN),
                    styleMenuItem(_("Order Slip"), K.STYLE_MENU), -- 菜单样式（-- 修改：v2.4.5）
                    modeMenuItem(_("Randomize style each time"), "random",
                        _("When enabled, a random style will be used each time the receipt is shown (instead of the fixed one).")),
                    modeMenuItem(_("Alternate style each time"), "alternate",
                        _("When enabled, styles will be alternated each time the receipt is shown (instead of a fixed one).")),
                },
            }

            -- 内容模式（仅胶片票根使用；墨痕壁纸恒为"阅读摘要"内容，不受此设置影响）
            local function isContentMode(value)
                local current = G_reader_settings:readSetting(K.CONTENT_MODE_SETTING) or K.CONTENT_MODE_BOOK_RECEIPT
                return current == value
            end

            local content_menu = {
                text = _("Content"),
                sub_item_table = {
                    {
                        text = _("Book receipt (default)"),
                        checked_func = function() return isContentMode(K.CONTENT_MODE_BOOK_RECEIPT) end,
                        callback = function() G_reader_settings:saveSetting(K.CONTENT_MODE_SETTING, K.CONTENT_MODE_BOOK_RECEIPT) end,
                        radio = true,
                    },
                    {
                        text = _("Highlight + progress"),
                        checked_func = function() return isContentMode(K.CONTENT_MODE_HIGHLIGHT_PROGRESS) end,
                        callback = function() G_reader_settings:saveSetting(K.CONTENT_MODE_SETTING, K.CONTENT_MODE_HIGHLIGHT_PROGRESS) end,
                        radio = true,
                    },
                    {
                        text = _("Random"),
                        checked_func = function() return isContentMode(K.CONTENT_MODE_RANDOM) end,
                        callback = function() G_reader_settings:saveSetting(K.CONTENT_MODE_SETTING, K.CONTENT_MODE_RANDOM) end,
                        radio = true,
                    },
                    {
                        -- 封面缩放（仅胶片封面模式生效）
                        text = _("Cover scale"),
                        keep_menu_open = true,
                        callback = function(touchmenu_instance)
                            local current_value = G_reader_settings:readSetting(K.COVER_SCALE_SETTING) or 1
                            local input_dialog
                            input_dialog = InputDialog:new{
                                title = _("Cover scale (default: 1.0)\nSet to 0 to hide cover"),
                                input = tostring(current_value),
                                input_type = "number",
                                buttons = {
                                    {
                                        {
                                            text = _("Cancel"),
                                            id = "close",
                                            callback = function()
                                                UIManager:close(input_dialog)
                                            end,
                                        },
                                        {
                                            text = _("Set"),
                                            is_enter_default = true,
                                            callback = function()
                                                local input_text = input_dialog:getInputText()
                                                input_text = input_text:gsub(",", ".")
                                                local new_value = tonumber(input_text)
                                                if new_value and new_value >= 0 then
                                                    G_reader_settings:saveSetting(K.COVER_SCALE_SETTING, new_value)
                                                    UIManager:close(input_dialog)
                                                end
                                            end,
                                        },
                                    },
                                },
                            }
                            UIManager:show(input_dialog)
                            input_dialog:onShowKeyboard()
                        end,
                    },
                    {
                        -- 自定义休眠文字（胶片版休眠模式下显示的提示文案）
                        text = _("Sleep message"),
                        keep_menu_open = true,
                        callback = function(touchmenu_instance)
                            local current_text = G_reader_settings:readSetting(K.SLEEP_TEXT) or "休眠中"
                            local input_dialog
                            input_dialog = InputDialog:new{
                                title = _("Sleep message"),
                                input = current_text,
                                buttons = {
                                    {
                                        {
                                            text = _("Cancel"),
                                            id = "close",
                                            callback = function()
                                                UIManager:close(input_dialog)
                                            end,
                                        },
                                        {
                                            text = _("Set"),
                                            is_enter_default = true,
                                            callback = function()
                                                local new_text = input_dialog:getInputText()
                                                if not new_text or new_text == "" then
                                                    G_reader_settings:delSetting(K.SLEEP_TEXT)
                                                else
                                                    G_reader_settings:saveSetting(K.SLEEP_TEXT, new_text)
                                                end
                                                UIManager:close(input_dialog)
                                            end,
                                        },
                                    },
                                },
                            }
                            UIManager:show(input_dialog)
                            input_dialog:onShowKeyboard()
                        end,
                    },
                },
            }

            -- 背景（胶片票根使用；墨痕壁纸自带白底全屏排版）
            local background_menu = {
                text = _("Background"),
                sub_item_table = {
                    genMenuItem(_("White fill"), K.BG_SETTING, "white"),
                    genMenuItem(_("Transparent"), K.BG_SETTING, "transparent"),
                    genMenuItem(_("Black fill"), K.BG_SETTING, "black"),
                    genMenuItem(_("Random image"), K.BG_SETTING, "random_image"),
                    genMenuItem(_("Book cover"), K.BG_SETTING, "book_cover"),
                    {
                        text = _("Background image placement"),
                        enabled_func = function()
                            local value = G_reader_settings:readSetting(K.BG_SETTING)
                            return value == "random_image" or value == "book_cover"
                        end,
                        sub_item_table = {
                            genMenuItem(_("Fit to screen"), K.BG_IMAGE_MODE_SETTING, "fit"),
                            genMenuItem(_("Stretch to screen"), K.BG_IMAGE_MODE_SETTING, "stretch"),
                            genMenuItem(_("Center without scaling"), K.BG_IMAGE_MODE_SETTING, "center"),
                        },
                    },
                },
            }

            -- 墨痕壁纸设置（统计周期 / 书单数量），仅墨痕样式生效
            local inkstain_settings_menu = {
                text = _("Ink stain settings"),
                sub_item_table = {
                    {
                        text = _("Statistics period"),
                        sub_item_table = {
                            genMenuItem(_("Today"), K.INKSTAIN_DAYS, 1),
                            genMenuItem(_("Last 7 days"), K.INKSTAIN_DAYS, 7),
                            genMenuItem(_("Last 30 days"), K.INKSTAIN_DAYS, 30),
                        },
                    },
                    {
                        text = _("Book list size"),
                        sub_item_table = {
                            genMenuItem("Top 2", K.INKSTAIN_TOP_N, 2),
                            genMenuItem("Top 3", K.INKSTAIN_TOP_N, 3),
                            genMenuItem("Top 4", K.INKSTAIN_TOP_N, 4),
                            genMenuItem("Top 5", K.INKSTAIN_TOP_N, 5),
                        },
                    },
                },
            }

            table.insert(wallpaper_submenu, 7, {
                text = _("Book receipt settings"),
                enabled_func = isBookReceiptEnabled,
                sub_item_table = {
                    style_menu,
                    content_menu,
                    background_menu,
                    inkstain_settings_menu,
                },
            })
        end
    end

    return result
end
