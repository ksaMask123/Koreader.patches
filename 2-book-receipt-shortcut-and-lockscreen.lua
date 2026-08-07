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
--   v2.4.11 内容全面扩容：诗词板块替换为 诗词第二版.txt（40→100 条，内嵌 + parsePoemText
--           运行时解析，兼容无朝代/括号式作品名/卷次标注）；名言板块追加 名言第二版.txt
--           （40→200 条，中外各 100 条）；菜谱板块追加 菜谱第二版.txt（60→250 道，
--           主菜100/汤菜50/饮品50/甜点50）；菜单样式右上角标题"菜单"→"菜单：5份"
--   v2.4.12 诗词板块再次扩容：追加 诗词第三版.txt（100→200 条）。第三版 104 条剔除 3 条
--           与第二版完全重复项 + 1 条与既有同诗句重复句（苏轼《定风波》），净增 100 条，
--           总量精确 200 条；保留李贺《金铜仙人辞汉歌》独立短句「天若有情天亦老」
--   v2.4.13 修复菜单样式左上角"点单设备：设备："双前缀：getDeviceInfoString 增加 prefix
--           入参（墨痕默认「设备：」，菜单传入「点单设备：」），消除调用点二次拼接
--   v2.5.0  手势/锁屏样式独立配置（非对称解耦）：手势沿用全局键（零改动零回归），
--           锁屏新增 book_receipt_lockscreen_{mode,style,toggle_state} 独立键，
--           首次锁屏从旧全局键单向迁移（修复旧版仅开随机开关时迁移后随机偏好丢失的隐患）；
--           菜单拆分"手势调出样式/锁屏壁纸样式"双通道子菜单；
--           墨痕统计周期/书单数量、诗句轮换、内容与背景保持两通道共享（已在菜单帮助注明）
--   v2.5.1  修复手势/锁屏样式分离未生效：Screensaver.show 的 buildReceipt 调用漏传
--           context 导致锁屏固定显示手势样式（锁屏"轮流出现"失效）；buildReceipt 改为
--           调用方解析一次 style 后直接传入，同时根治轮流模式被 is_stat_based 预检与
--           渲染双重推进跳样式的隐患（锁屏轮流由跳档修复为顺序推进）
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
        -- 修改：v2.5.0 手势/锁屏样式独立设置入口文案
        ["Gesture style"] = "手势调出样式",
        ["Lockscreen style"] = "锁屏壁纸样式",
        ["Gesture and lockscreen styles are configured independently. Ink stain stats period/book list size, poem rotation, content and background are shared between the two."] = "手势与锁屏样式可独立配置；墨痕统计周期/书单数量、诗句轮换、内容与背景为两通道共享设置。",
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
    STYLE_TOGGLE_STATE = "book_receipt_style_toggle_state",  -- 轮流模式当前状态（上次展示的样式，手势专用；锁屏见下）
    -- 修改：v2.5.0 锁屏样式独立键——手势沿用上方 book_receipt_style* 全局键（语义不变），
    --       锁屏使用独立键（首次锁屏时从旧全局键单向迁移，见 migrateLockscreenStyle）。
    --       这样手势侧零改动、零回归，锁屏侧获得完全独立的样式/轮换配置。
    LOCKSCREEN_MODE_SETTING  = "book_receipt_lockscreen_mode",
    LOCKSCREEN_STYLE_SETTING = "book_receipt_lockscreen_style",
    LOCKSCREEN_TOGGLE_STATE  = "book_receipt_lockscreen_toggle_state",
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

-- 归一化样式出现方式：仅接受 fixed/random/alternate，非法值回退旧版随机开关再回退 fixed
-- 修改：v2.5.0 抽取。手势（getStyleMode）与锁屏（getLockscreenEffectiveStyle）共用同一
--       合法性校验，保证两套键的非法值行为一致（与 v2.4.x 语义完全兼容）
local function normalizeStyleMode(mode, legacy_random_flag)
    if mode == "random" or mode == "alternate" or mode == "fixed" then
        return mode
    end
    if legacy_random_flag then
        return "random"
    end
    return "fixed"
end

-- 读取手势样式出现方式（fixed 固定 / random 随机 / alternate 轮流）
-- 修改：v2.5.0 改为复用 normalizeStyleMode，行为不变（含旧版随机开关回退）
local function getStyleMode()
    return normalizeStyleMode(
        G_reader_settings:readSetting(K.STYLE_MODE_SETTING),
        G_reader_settings:isTrue(K.RANDOM_STYLE))
end

-- 轮流模式：返回当前应展示的样式，并将轮换状态推进到下一个
-- 状态持久化于 G_reader_settings；手势与锁屏各用各的 toggle 键，互不消耗（-- 修改：v2.5.0）
-- （-- 修改：v2.4.5 由「首尾二样式互切」泛化为「N 个样式顺序循环」，支持 3 样式）
-- @param toggle_key string 轮流序号持久化键（手势用 K.STYLE_TOGGLE_STATE，锁屏用 K.LOCKSCREEN_TOGGLE_STATE）
local function getAlternateStyleAndAdvance(toggle_key)
    local styles = getAllStyles()
    local cur = G_reader_settings:readSetting(toggle_key)
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
    G_reader_settings:saveSetting(toggle_key, next_style)
    return cur
end

-- 依据出现方式返回本次应展示的样式：固定 / 随机 / 轮流（手势语义，沿用全局键）
local function getEffectiveStyle()
    local mode = getStyleMode()
    if mode == "random" then
        local styles = getAllStyles()
        return styles[math.random(#styles)]
    elseif mode == "alternate" then
        return getAlternateStyleAndAdvance(K.STYLE_TOGGLE_STATE)
    else
        return normalizeReceiptStyle(G_reader_settings:readSetting(K.STYLE_SETTING))
    end
end

-- 锁屏样式设置迁移：首次读取锁屏键时，从旧全局键单向复制（幂等）
-- 修改：v2.5.0 新增。关键修复：迁移用的"全局有效模式"必须走 getStyleMode()（含旧版
--       book_receipt_random_style 开关回退），而非裸 readSetting——否则老用户若仅开过
--       旧版随机开关（未设 style_mode 键），迁移会把锁屏误置为 fixed，随机偏好永久丢失
local function migrateLockscreenStyle()
    if G_reader_settings:has(K.LOCKSCREEN_MODE_SETTING) then return end
    local global_mode = getStyleMode()
    G_reader_settings:saveSetting(K.LOCKSCREEN_MODE_SETTING, global_mode)
    if global_mode == "fixed" then
        G_reader_settings:saveSetting(K.LOCKSCREEN_STYLE_SETTING,
            normalizeReceiptStyle(G_reader_settings:readSetting(K.STYLE_SETTING)))
    end
    local global_toggle = G_reader_settings:readSetting(K.STYLE_TOGGLE_STATE)
    if global_toggle then
        G_reader_settings:saveSetting(K.LOCKSCREEN_TOGGLE_STATE, global_toggle)
    end
    logger.info(LOG_TAG, "锁屏样式设置已从旧全局键迁移（mode=", tostring(global_mode), "）")
end

-- 锁屏样式读取：手势与锁屏完全独立（-- 修改：v2.5.0 新增）
-- 首次调用触发 migrateLockscreenStyle 完成平滑升级；锁屏无旧版随机开关语义，legacy 传 false
local function getLockscreenEffectiveStyle()
    migrateLockscreenStyle()
    local mode = normalizeStyleMode(G_reader_settings:readSetting(K.LOCKSCREEN_MODE_SETTING), false)
    if mode == "random" then
        local styles = getAllStyles()
        return styles[math.random(#styles)]
    elseif mode == "alternate" then
        return getAlternateStyleAndAdvance(K.LOCKSCREEN_TOGGLE_STATE)
    else
        return normalizeReceiptStyle(G_reader_settings:readSetting(K.LOCKSCREEN_STYLE_SETTING))
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

-- 诗句候选库：200 条经典诗词（结构化字段，供三行显示：诗句 / 朝代·作者 / 作品名）
-- dynasty 为空串表示无朝代（近现代作者），第 2 行仅显示作者
-- ========== 诗词板块数据源（-- 修改：v2.4.12 追加 诗词第三版.txt，共 200 条） ==========
-- 每行 1 条，格式「诗句。——朝代·作者《作品》」；兼容无朝代条目（毛泽东/鲁迅等）、
-- 括号式作品名（秋瑾（绝命诗））与卷次标注（陈毅《梅岭三章》（其一）），由 parsePoemText 解析
-- 追加口径：诗词第三版 104 条剔除 3 条与第二版完全重复 + 1 条与既有同诗句重复（定风波），
-- 净增 100 条，总量精确 200 条（保留李贺《金铜仙人辞汉歌》独立短句「天若有情天亦老」）
local POEM_TEXT = [[
醉后不知天在水，满船清梦压星河。——元·唐珙《题龙阳县青草湖》
欲买桂花同载酒，终不似，少年游。——宋·刘过《唐多令·芦叶满汀洲》
人生若只如初见，何事秋风悲画扇。——清·纳兰性德《木兰花·拟古决绝词柬友》
疏影横斜水清浅，暗香浮动月黄昏。——宋·林逋《山园小梅》
十年生死两茫茫，不思量，自难忘。——宋·苏轼《江城子·乙卯正月二十日夜记梦》
桃李春风一杯酒，江湖夜雨十年灯。——宋·黄庭坚《寄黄几复》
我见青山多妩媚，料青山见我应如是。——宋·辛弃疾《贺新郎·甚矣吾衰矣》
流光容易把人抛，红了樱桃，绿了芭蕉。——宋·蒋捷《一剪梅·舟过吴江》
试问闲愁几许？一川烟草，满城风絮，梅子黄时雨。——宋·贺铸《青玉案·凌波不过横塘路》
风乍起，吹皱一池春水。——五代·冯延巳《谒金门·风乍起》
自在飞花轻似梦，无边丝雨细如愁。——宋·秦观《浣溪沙》
落霞与孤鹜齐飞，秋水共长天一色。——唐·王勃《滕王阁序》
沧海月明珠有泪，蓝田日暖玉生烟。——唐·李商隐《锦瑟》
年年岁岁花相似，岁岁年年人不同。——唐·刘希夷《代悲白头翁》
林花谢了春红，太匆匆。无奈朝来寒雨晚来风。——五代·李煜《相见欢·林花谢了春红》
日暮酒醒人已远，满天风雨下西楼。——唐·许浑《谢亭送别》
鸡声茅店月，人迹板桥霜。——唐·温庭筠《商山早行》
留得枯荷听雨声。——唐·李商隐《宿骆氏亭寄怀崔雍崔衮》
问君能有几多愁？恰似一江春水向东流。——五代·李煜《虞美人》
衣带渐宽终不悔，为伊消得人憔悴。——宋·柳永《蝶恋花·伫倚危楼风细细》
人生自是有情痴，此恨不关风与月。——宋·欧阳修《玉楼春·尊前拟把归期说》
山有木兮木有枝，心悦君兮君不知。——先秦·佚名《越人歌》
世事一场大梦，人生几度秋凉。——宋·苏轼《西江月·世事一场大梦》
多情自古伤离别，更那堪，冷落清秋节。——宋·柳永《雨霖铃·寒蝉凄切》（补充经典句）
此情可待成追忆，只是当时已惘然。——唐·李商隐《锦瑟》（补充）
问苍茫大地，谁主沉浮？——毛泽东《沁园春·长沙》
雄关漫道真如铁，而今迈步从头越。——毛泽东《忆秦娥·娄山关》
红军不怕远征难，万水千山只等闲。——毛泽东《七律·长征》
为有牺牲多壮志，敢教日月换新天。——毛泽东《七律·到韶山》
俱往矣，数风流人物，还看今朝。——毛泽东《沁园春·雪》
横眉冷对千夫指，俯首甘为孺子牛。——鲁迅《自嘲》
寄意寒星荃不察，我以我血荐轩辕。——鲁迅《自题小像》
不惜千金买宝刀，貂裘换酒也堪豪。——秋瑾《对酒》
身不得，男儿列；心却比，男儿烈！——秋瑾《满江红·小住京华》
秋风秋雨愁煞人。——秋瑾（绝命诗）
此去泉台招旧部，旌旗十万斩阎罗。——陈毅《梅岭三章》（其一）
取义成仁今日事，人间遍种自由花。——陈毅《梅岭三章》（其三）
砍头不要紧，只要主义真。杀了夏明翰，还有后来人。——夏明翰《就义诗》
何当痛饮黄龙府，高筑神州风雨楼。——李大钊《口占一绝》
大江歌罢掉头东，邃密群科济世穷。——周恩来《大江歌罢掉头东》
海上生明月，天涯共此时。——唐·张九龄《望月怀远》
露从今夜白，月是故乡明。——唐·杜甫《月夜忆舍弟》
愿得一心人，白头不相离。——汉·卓文君《白头吟》
曾经沧海难为水，除却巫山不是云。——唐·元稹《离思五首·其四》
两情若是久长时，又岂在朝朝暮暮。——宋·秦观《鹊桥仙·纤云弄巧》
身无彩凤双飞翼，心有灵犀一点通。——唐·李商隐《无题·昨夜星辰昨夜风》
春蚕到死丝方尽，蜡炬成灰泪始干。——唐·李商隐《无题·相见时难别亦难》
问世间，情为何物，直教生死相许？——金·元好问《摸鱼儿·雁丘词》
君问归期未有期，巴山夜雨涨秋池。——唐·李商隐《夜雨寄北》
海上生明月，天涯共此时。——唐·张九龄《望月怀远》
但愿人长久，千里共婵娟。——宋·苏轼《水调歌头·明月几时有》
同是天涯沦落人，相逢何必曾相识。——唐·白居易《琵琶行》
人生到处知何似，应似飞鸿踏雪泥。——宋·苏轼《和子由渑池怀旧》
人生天地间，忽如远行客。——汉·佚名《青青陵上柏》
沉舟侧畔千帆过，病树前头万木春。——唐·刘禹锡《酬乐天扬州初逢席上见赠》
山重水复疑无路，柳暗花明又一村。——宋·陆游《游山西村》
会当凌绝顶，一览众山小。——唐·杜甫《望岳》
不畏浮云遮望眼，只缘身在最高层。——宋·王安石《登飞来峰》
欲穷千里目，更上一层楼。——唐·王之涣《登鹳雀楼》
不识庐山真面目，只缘身在此山中。——宋·苏轼《题西林壁》
纸上得来终觉浅，绝知此事要躬行。——宋·陆游《冬夜读书示子聿》
问渠那得清如许，为有源头活水来。——宋·朱熹《观书有感》
读书破万卷，下笔如有神。——唐·杜甫《奉赠韦左丞丈二十二韵》
近水楼台先得月，向阳花木易为春。——宋·苏麟《断句》
梅须逊雪三分白，雪却输梅一段香。——宋·卢梅坡《雪梅·其一》
人生如逆旅，我亦是行人。——宋·苏轼《临江仙·送钱穆父》
海内存知己，天涯若比邻。——唐·王勃《送杜少府之任蜀州》
劝君更尽一杯酒，西出阳关无故人。——唐·王维《送元二使安西》
莫愁前路无知己，天下谁人不识君。——唐·高适《别董大二首》
桃花潭水深千尺，不及汪伦送我情。——唐·李白《赠汪伦》
浮云游子意，落日故人情。——唐·李白《送友人》
独在异乡为异客，每逢佳节倍思亲。——唐·王维《九月九日忆山东兄弟》
春风又绿江南岸，明月何时照我还？——宋·王安石《泊船瓜洲》
少小离家老大回，乡音无改鬓毛衰。——唐·贺知章《回乡偶书》
月落乌啼霜满天，江枫渔火对愁眠。——唐·张继《枫桥夜泊》
大漠孤烟直，长河落日圆。——唐·王维《使至塞上》
明月松间照，清泉石上流。——唐·王维《山居秋暝》
日出江花红胜火，春来江水绿如蓝。——唐·白居易《忆江南·江南好》
接天莲叶无穷碧，映日荷花别样红。——宋·杨万里《晓出净慈寺送林子方》
春色满园关不住，一枝红杏出墙来。——宋·叶绍翁《游园不值》
沾衣欲湿杏花雨，吹面不寒杨柳风。——宋·志南《绝句》
小楼一夜听春雨，深巷明朝卖杏花。——宋·陆游《临安春雨初霁》
停车坐爱枫林晚，霜叶红于二月花。——唐·杜牧《山行》
千山鸟飞绝，万径人踪灭。——唐·柳宗元《江雪》
举头望明月，低头思故乡。——唐·李白《静夜思》
床前明月光，疑是地上霜。——唐·李白《静夜思》
春眠不觉晓，处处闻啼鸟。——唐·孟浩然《春晓》
谁知盘中餐，粒粒皆辛苦。——唐·李绅《悯农》
但使龙城飞将在，不教胡马度阴山。——唐·王昌龄《出塞》
黄沙百战穿金甲，不破楼兰终不还。——唐·王昌龄《从军行七首·其四》
苟利国家生死以，岂因祸福避趋之。——清·林则徐《赴戍登程口占示家人·其二》
人生自古谁无死，留取丹心照汗青。——宋·文天祥《过零丁洋》
王师北定中原日，家祭无忘告乃翁。——宋·陆游《示儿》
落红不是无情物，化作春泥更护花。——清·龚自珍《己亥杂诗·其五》
安得广厦千万间，大庇天下寒士俱欢颜。——唐·杜甫《茅屋为秋风所破歌》
粉骨碎身浑不怕，要留清白在人间。——明·于谦《石灰吟》
居高声自远，非是藉秋风。——唐·虞世南《蝉》
不知细叶谁裁出，二月春风似剪刀。——唐·贺知章《咏柳》
一蓑烟雨任平生。——宋·苏轼《定风波·莫听穿林打叶声》
大鹏一日同风起，扶摇直上九万里。——唐·李白《上李邕》

只愿君心似我心，定不负相思意。——宋·李之仪《卜算子》
换我心，为你心，始知相忆深。——五代·顾敻《诉衷情》
玲珑骰子安红豆，入骨相思知不知。——唐·温庭筠《南歌子词二首》
相思相见知何日？此时此夜难为情。——唐·李白《三五七言》
直道相思了无益，未妨惆怅是清狂。——唐·李商隐《无题》
相恨不如潮有信，相思始觉海非深。——唐·白居易《浪淘沙》
思君如满月，夜夜减清辉。——唐·张九龄《赋得自君之出矣》
生当复来归，死当长相思。——汉·苏武《留别妻》
结发为夫妻，恩爱两不疑。——汉·苏武《留别妻》
月上柳梢头，人约黄昏后。——宋·欧阳修《生查子·元夕》
天涯地角有穷时，只有相思无尽处。——宋·晏殊《玉楼春·春恨》
无情不似多情苦，一寸还成千万缕。——宋·晏殊《玉楼春·春恨》
春心莫共花争发，一寸相思一寸灰。——唐·李商隐《无题》
深知身在情长在，怅望江头江水声。——唐·李商隐《暮秋独游曲江》
梦后楼台高锁，酒醒帘幕低垂。——宋·晏几道《临江仙》
当时明月在，曾照彩云归。——宋·晏几道《临江仙》
落花人独立，微雨燕双飞。——宋·晏几道《临江仙》
琵琶弦上说相思，当时明月在，曾照彩云归。——宋·晏几道《临江仙》
满目山河空念远，落花风雨更伤春，不如怜取眼前人。——宋·晏殊《浣溪沙》
昨夜西风凋碧树，独上高楼，望尽天涯路。——宋·晏殊《蝶恋花》
欲寄彩笺兼尺素，山长水阔知何处。——宋·晏殊《蝶恋花》
明月楼高休独倚，酒入愁肠，化作相思泪。——宋·范仲淹《苏幕遮》
人不寐，将军白发征夫泪。——宋·范仲淹《渔家傲·秋思》
浊酒一杯家万里，燕然未勒归无计。——宋·范仲淹《渔家傲·秋思》
无可奈何花落去，似曾相识燕归来。——宋·晏殊《浣溪沙》
梨花院落溶溶月，柳絮池塘淡淡风。——宋·晏殊《无题》
春风不解禁杨花，蒙蒙乱扑行人面。——宋·晏殊《踏莎行》
池上碧苔三四点，叶底黄鹂一两声。——宋·晏殊《破阵子》
绿杨烟外晓寒轻，红杏枝头春意闹。——宋·宋祁《玉楼春·春景》
浮生长恨欢娱少，肯爱千金轻一笑。——宋·宋祁《玉楼春·春景》
人生有情泪沾臆，江水江花岂终极。——唐·杜甫《哀江头》
人生不相见，动如参与商。——唐·杜甫《赠卫八处士》
明日隔山岳，世事两茫茫。——唐·杜甫《赠卫八处士》
冠盖满京华，斯人独憔悴。——唐·杜甫《梦李白二首·其二》
千秋万岁名，寂寞身后事。——唐·杜甫《梦李白二首·其二》
文章憎命达，魑魅喜人过。——唐·杜甫《天末怀李白》
凉风起天末，君子意如何。——唐·杜甫《天末怀李白》
星垂平野阔，月涌大江流。——唐·杜甫《旅夜书怀》
飘飘何所似，天地一沙鸥。——唐·杜甫《旅夜书怀》
吴楚东南坼，乾坤日夜浮。——唐·杜甫《登岳阳楼》
戎马关山北，凭轩涕泗流。——唐·杜甫《登岳阳楼》
出师未捷身先死，长使英雄泪满襟。——唐·杜甫《蜀相》
映阶碧草自春色，隔叶黄鹂空好音。——唐·杜甫《蜀相》
白日放歌须纵酒，青春作伴好还乡。——唐·杜甫《闻官军收河南河北》
尔曹身与名俱灭，不废江河万古流。——唐·杜甫《戏为六绝句·其二》
不薄今人爱古人，清词丽句必为邻。——唐·杜甫《戏为六绝句·其五》
别裁伪体亲风雅，转益多师是汝师。——唐·杜甫《戏为六绝句·其六》
为人性僻耽佳句，语不惊人死不休。——唐·杜甫《江上值水如海势聊短述》
天若有情天亦老。——唐·李贺《金铜仙人辞汉歌》
衰兰送客咸阳道，天若有情天亦老。——唐·李贺《金铜仙人辞汉歌》
男儿何不带吴钩，收取关山五十州。——唐·李贺《南园十三首·其五》
我有迷魂招不得，雄鸡一声天下白。——唐·李贺《致酒行》
大漠沙如雪，燕山月似钩。——唐·李贺《马诗二十三首·其五》
黑云压城城欲摧，甲光向日金鳞开。——唐·李贺《雁门太守行》
报君黄金台上意，提携玉龙为君死。——唐·李贺《雁门太守行》
角声满天秋色里，塞上燕脂凝夜紫。——唐·李贺《雁门太守行》
昆山玉碎凤凰叫，芙蓉泣露香兰笑。——唐·李贺《李凭箜篌引》
女娲炼石补天处，石破天惊逗秋雨。——唐·李贺《李凭箜篌引》
天上人间，不知今夕是何年。——宋·苏轼《水调歌头·明月几时有》（“不知天上宫阙，今夕是何年”）
不应有恨，何事长向别时圆。——宋·苏轼《水调歌头·明月几时有》
人有悲欢离合，月有阴晴圆缺，此事古难全。——宋·苏轼《水调歌头·明月几时有》
长恨此身非我有，何时忘却营营。——宋·苏轼《临江仙·夜饮东坡醒复醉》
小舟从此逝，江海寄余生。——宋·苏轼《临江仙·夜饮东坡醒复醉》
归去，也无风雨也无晴。——宋·苏轼《定风波·莫听穿林打叶声》
拣尽寒枝不肯栖，寂寞沙洲冷。——宋·苏轼《卜算子·黄州定慧院寓居作》
细看来不是杨花，点点是离人泪。——宋·苏轼《水龙吟·次韵章质夫杨花词》
春色三分，二分尘土，一分流水。——宋·苏轼《水龙吟·次韵章质夫杨花词》
枝上柳绵吹又少，天涯何处无芳草。——宋·苏轼《蝶恋花·春景》
笑渐不闻声渐悄，多情却被无情恼。——宋·苏轼《蝶恋花·春景》
墙里秋千墙外道，墙外行人，墙里佳人笑。——宋·苏轼《蝶恋花·春景》
欲把西湖比西子，淡妆浓抹总相宜。——宋·苏轼《饮湖上初晴后雨》
竹外桃花三两枝，春江水暖鸭先知。——宋·苏轼《惠崇春江晚景》
蒌蒿满地芦芽短，正是河豚欲上时。——宋·苏轼《惠崇春江晚景》
春江水暖鸭先知。——宋·苏轼《惠崇春江晚景》
一年好景君须记，最是橙黄橘绿时。——宋·苏轼《赠刘景文》
荷尽已无擎雨盖，菊残犹有傲霜枝。——宋·苏轼《赠刘景文》
横看成岭侧成峰，远近高低各不同。——宋·苏轼《题西林壁》
黄河之水天上来，奔流到海不复回。——唐·李白《将进酒》
往日崎岖还记否，路长人困蹇驴嘶。——宋·苏轼《和子由渑池怀旧》
庐山烟雨浙江潮，未到千般恨不消。——宋·苏轼《观潮》
到得还来无别事，庐山烟雨浙江潮。——宋·苏轼《观潮》
东风袅袅泛崇光，香雾空蒙月转廊。——宋·苏轼《海棠》
只恐夜深花睡去，故烧高烛照红妆。——宋·苏轼《海棠》
九死南荒吾不恨，兹游奇绝冠平生。——宋·苏轼《六月二十日夜渡海》
云散月明谁点缀，天容海色本澄清。——宋·苏轼《六月二十日夜渡海》
苦雨终风也解晴，天容海色本澄清。——宋·苏轼《六月二十日夜渡海》
北船不到米如珠，醉饱萧条半月无。——宋·苏轼《六月二十日夜渡海》
空余鲁叟乘桴意，粗识轩辕奏乐声。——宋·苏轼《六月二十日夜渡海》
日啖荔枝三百颗，不辞长作岭南人。——宋·苏轼《惠州一绝》
罗浮山下四时春，卢橘杨梅次第新。——宋·苏轼《惠州一绝》
心似已灰之木，身如不系之舟。——宋·苏轼《自题金山画像》
问汝平生功业，黄州惠州儋州。——宋·苏轼《自题金山画像》
人皆养子望聪明，我被聪明误一生。——宋·苏轼《洗儿》
惟愿孩儿愚且鲁，无灾无难到公卿。——宋·苏轼《洗儿》
冰肌玉骨，自清凉无汗。——宋·苏轼《洞仙歌·冰肌玉骨》
但屈指西风几时来，又不道流年暗中偷换。——宋·苏轼《洞仙歌·冰肌玉骨》
明月如霜，好风如水，清景无限。——宋·苏轼《永遇乐·彭城夜宿燕子楼》
曲港跳鱼，圆荷泻露，寂寞无人见。——宋·苏轼《永遇乐·彭城夜宿燕子楼》
夜饮东坡醒复醉，归来仿佛三更。——宋·苏轼《临江仙·夜饮东坡醒复醉》
家童鼻息已雷鸣，敲门都不应，倚杖听江声。——宋·苏轼《临江仙·夜饮东坡醒复醉》
]]

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

主菜：剁椒鱼头
特色：鱼头铺满剁椒蒸制，辣味渗透，肉质细嫩，鲜辣开胃。
食材：花鲢鱼头1个（约1000克）、剁椒150克、姜末20克、蒜末20克、蒸鱼豉油30毫升、热油30毫升、葱花适量
价格：48元

主菜：小炒肉
特色：五花肉片与青椒、蒜苗同炒，肉片焦香，咸辣下饭。
食材：五花肉300克、青椒200克、蒜苗50克、姜蒜片各10克、生抽15毫升、老抽5毫升、豆豉10克
价格：22元

主菜：啤酒鸭
特色：鸭肉与啤酒同焖，肉质软烂，酱香浓郁，略带酒香。
食材：鸭肉500克、啤酒500毫升、姜片10克、蒜瓣10克、八角2个、桂皮1小块、生抽30毫升、老抽10毫升、冰糖10克
价格：35元

主菜：黄焖鸡
特色：鸡腿肉与干香菇焖制，汤汁浓稠，肉质鲜嫩。
食材：鸡腿肉500克、干香菇30克、土豆200克、青椒100克、姜片10克、生抽30毫升、老抽10毫升、蚝油15克、冰糖10克
价格：28元

主菜：九转大肠
特色：大肠经煮、炸、烧等多道工序，酸甜苦辣咸五味俱全，红润光亮。
食材：猪大肠500克、葱姜各20克、料酒30毫升、生抽20毫升、醋15毫升、白糖20克、胡椒粉5克、肉桂粉3克、砂仁粉3克
价格：45元

主菜：葱烧海参
特色：海参软糯，葱香浓郁，汁浓味厚，为鲁菜经典。
食材：水发海参300克、大葱白100克、蚝油20克、生抽10毫升、老抽5毫升、料酒15毫升、白糖5克、高汤150毫升、水淀粉适量
价格：65元

主菜：糖醋鲤鱼
特色：鲤鱼炸至外酥里嫩，浇上糖醋汁，酸甜适口。
食材：黄河鲤鱼1条约750克、面粉100克、淀粉50克、番茄酱30克、白糖50克、白醋40毫升、生抽10毫升、葱姜蒜各10克
价格：32元

主菜：把子肉
特色：五花肉厚片与鸡蛋、豆制品等一同卤制，肉烂味醇，肥而不腻。
食材：五花肉500克、鸡蛋4个、豆腐皮100克、酱油50毫升、冰糖20克、八角2个、桂皮1小块、姜片10克、葱段10克
价格：22元

主菜：德州扒鸡
特色：整鸡经烧、炸、焖、卤等多道工序，骨酥肉烂，五香脱骨。
食材：三黄鸡1只（约1000克）、蜂蜜20克、酱油30毫升、黄酒30毫升、花椒5克、八角5克、桂皮5克、丁香2克、姜片10克
价格：45元

主菜：糖醋里脊
特色：里脊条炸至金黄酥脆，裹上红亮糖醋汁，外焦里嫩。
食材：猪里脊肉300克、淀粉100克、番茄酱30克、白糖40克、白醋30毫升、生抽10毫升、盐3克、鸡蛋1个
价格：25元

主菜：锅包肉
特色：肉片分两次油炸，外皮酥脆，裹上糖醋汁，酸甜扑鼻。
食材：猪里脊肉300克、土豆淀粉150克、白糖50克、白醋40毫升、生抽10毫升、姜丝5克、葱丝5克、胡萝卜丝10克
价格：28元

主菜：小鸡炖蘑菇
特色：鸡肉与野生榛蘑同炖，汤汁浓郁，菌香与肉香融合。
食材：鸡块500克、干榛蘑50克、粉条100克、葱姜各15克、八角2个、生抽30毫升、老抽10毫升、料酒20毫升、盐5克
价格：38元

主菜：酸菜白肉
特色：五花肉与东北酸菜同煮，肉片肥而不腻，酸菜解腻爽口。
食材：五花肉300克、东北酸菜500克、粉丝50克、姜片10克、八角2个、盐5克、胡椒粉3克
价格：25元

主菜：锅塌豆腐
特色：豆腐裹蛋液煎至金黄，再以高汤煨制，外软里嫩，鲜香入味。
食材：北豆腐300克、鸡蛋2个、面粉30克、高汤200毫升、生抽10毫升、蚝油5克、盐3克、葱花5克
价格：15元

主菜：响油鳝糊
特色：鳝鱼丝滑嫩，浓油赤酱，热油浇于蒜末上，响声四起，香气扑鼻。
食材：鳝鱼丝300克、姜末10克、蒜末20克、葱花5克、生抽20毫升、老抽10毫升、白糖15克、白胡椒粉5克、水淀粉适量
价格：40元

主菜：叫花鸡
特色：整鸡用荷叶包裹，外裹黄泥烤制，肉质酥烂，荷香四溢。
食材：三黄鸡1只（约1000克）、生抽30毫升、黄酒30毫升、蚝油20克、葱姜各20克、鲜荷叶2张、黄泥适量
价格：42元

主菜：无锡排骨
特色：排骨色泽酱红，肉质酥烂，味浓中带甜，为无锡名菜。
食材：猪肋排500克、生抽30毫升、老抽15毫升、黄酒30毫升、白糖50克、八角2个、桂皮1小块、姜片10克
价格：35元

主菜：西湖醋鱼
特色：草鱼水煮后浇上糖醋芡汁，鱼肉鲜嫩，酸甜适口，带有蟹味。
食材：草鱼1条约600克、姜末10克、生抽20毫升、白糖30克、白醋25毫升、水淀粉适量
价格：32元

主菜：干煸四季豆
特色：四季豆炸至表皮起皱，与肉末、芽菜、干辣椒同煸，干香麻辣。
食材：四季豆400克、猪肉末50克、碎米芽菜20克、干辣椒10克、花椒5克、蒜末10克、生抽10毫升、盐3克
价格：18元

主菜：蒜泥白肉
特色：五花肉薄片卷黄瓜片，浇红油蒜泥酱汁，蒜香浓郁，肥瘦相间。
食材：五花肉300克、黄瓜100克、大蒜50克、红油30毫升、复制酱油30毫升、盐2克
价格：20元

主菜：盐煎肉
特色：五花肉片不加淀粉直接煸炒，口感干香，豆瓣味浓郁。
食材：五花肉300克、青蒜100克、郫县豆瓣20克、豆豉10克、生抽10毫升、白糖3克
价格：22元

主菜：水煮牛肉
特色：牛里脊片滑嫩，垫底蔬菜脆爽，干辣椒与花椒经热油激香，汤底麻辣。
食材：牛里脊肉250克、豆芽150克、莴笋尖100克、干辣椒15克、花椒10克、郫县豆瓣50克、蒜末10克、蛋清1个、淀粉15克
价格：35元

主菜：辣子肥肠
特色：肥肠炸至酥脆，与大量干辣椒同炒，麻辣干香，外酥内韧。
食材：猪大肠500克、干辣椒100克、花椒20克、姜蒜片各10克、生抽15毫升、料酒20毫升、面粉50克（清洗用）
价格：32元

主菜：口水鸡
特色：鸡肉煮后斩块，浇麻辣红油料汁，集麻辣鲜香嫩爽于一身。
食材：三黄鸡半只（约500克）、熟花生碎30克、熟白芝麻10克、葱花10克、红油50毫升、花椒粉5克、生抽20毫升、醋10毫升、白糖5克
价格：28元

主菜：樟茶鸭
特色：鸭肉经腌、熏、蒸、炸四道工序，色泽金红，外酥里嫩，带有樟木和茶叶的清香。
食材：鸭子1只（约1500克）、樟木屑50克、茶叶20克、白糖30克、花椒5克、盐15克、姜片10克、葱段10克
价格：48元

主菜：香酥鸭
特色：整鸭腌制后蒸熟，再入油锅炸至皮酥肉烂，蘸椒盐食用。
食材：鸭子1只（约1500克）、花椒5克、盐10克、八角2个、桂皮1小块、姜片10克、葱段10克、料酒20毫升
价格：40元

主菜：酸豆角炒肉末
特色：酸豆角切粒与猪肉末同炒，酸辣咸香，极其开胃下饭。
食材：猪肉末150克、酸豆角250克、干辣椒5个、蒜末10克、生抽10毫升、白糖3克
价格：18元

主菜：永州血鸭
特色：鸭肉斩小块与鸭血同炒，色泽紫红，味道浓香，咸辣鲜美。
食材：鸭肉500克、鸭血100克、青椒50克、红椒50克、姜片10克、蒜瓣10克、酱油15毫升、料酒20毫升
价格：35元

主菜：小炒黄牛肉
特色：牛肉片与泡椒、小米辣、香菜梗猛火快炒，肉质嫩滑，香辣十足。
食材：牛里脊肉300克、小米辣20克、泡椒20克、香菜梗50克、姜蒜末各10克、生抽15毫升、蚝油10克、淀粉10克
价格：32元

主菜：农家一碗香
特色：五花肉、鸡蛋、豆腐等食材一锅同炒，食材丰富，香辣下饭。
食材：五花肉150克、鸡蛋2个、豆腐干100克、青椒50克、红椒50克、蒜苗30克、生抽15毫升、老抽5毫升、豆豉10克
价格：22元

主菜：辣椒炒肉
特色：螺丝椒与五花肉片同炒，辣椒的清香与猪肉的油脂充分融合，咸香微辣。
食材：五花肉200克、螺丝椒250克、蒜片10克、生抽20毫升、老抽5毫升、白糖3克、豆豉5克
价格：20元

主菜：梅菜扣肉
特色：五花肉片与梅菜相间码入碗中蒸制，肉烂味香，梅菜吸饱肉汁。
食材：五花肉500克、梅干菜100克、老抽20毫升、生抽15毫升、蚝油10克、白糖10克、腐乳汁10毫升、姜片5克
价格：28元

主菜：粉蒸肉
特色：五花肉片裹上蒸肉米粉，与红薯同蒸至软糯，米粉油润，肉香扑鼻。
食材：五花肉500克、蒸肉米粉100克、红薯200克、姜末10克、腐乳汁20毫升、生抽15毫升、料酒15毫升、白糖5克
价格：25元

主菜：蚂蚁上树
特色：粉丝与猪肉末同炒，肉末沾在粉丝上，形似蚂蚁爬树，咸鲜微辣。
食材：干粉丝100克、猪肉末100克、郫县豆瓣15克、姜蒜末各5克、生抽10毫升、高汤100毫升
价格：16元

主菜：干锅花菜
特色：花菜与五花肉煸炒，干锅形式，口感干香，微辣爽脆。
食材：花菜300克、五花肉100克、干辣椒5克、蒜片10克、生抽15毫升、蚝油10克
价格：18元

主菜：手撕包菜
特色：包菜用手撕成片，与五花肉、干辣椒大火爆炒，口感爽脆，锅气十足。
食材：包菜300克、五花肉50克、干辣椒5克、蒜片5克、生抽15毫升、醋10毫升、盐3克
价格：15元

主菜：虎皮青椒
特色：青椒煎至表面焦黄呈虎皮状，加料汁焖烧，软烂入味，咸香微辣。
食材：青椒（螺丝椒）400克、蒜末10克、生抽20毫升、醋10毫升、白糖5克、豆豉5克
价格：12元

主菜：鱼香茄子
特色：茄子过油后与鱼香汁同烧，口感软糯，咸甜酸辣兼备。
食材：长茄子300克、肉末50克、郫县豆瓣15克、泡椒10克、姜蒜末各5克、糖15克、醋10毫升、生抽10毫升
价格：18元

主菜：干锅土豆片
特色：土豆片煎至两面金黄，与五花肉、洋葱、干辣椒同炒，干香麻辣。
食材：土豆300克、五花肉50克、洋葱50克、干辣椒5克、蒜片10克、生抽15毫升、郫县豆瓣10克
价格：16元

主菜：葱油鸡
特色：整鸡蒸熟后淋上滚烫葱油，葱香浓郁，鸡肉鲜嫩。
食材：三黄鸡1只（约800克）、小葱100克、姜片20克、盐10克、花生油80毫升
价格：35元

主菜：香辣蟹
特色：螃蟹与干辣椒、花椒、豆瓣酱同炒，蟹肉鲜甜，外壳酥脆，麻辣入味。
食材：梭子蟹3只（约600克）、干辣椒50克、花椒15克、姜蒜片各10克、郫县豆瓣30克、料酒20毫升、淀粉30克
价格：48元

主菜：干锅虾
特色：大虾与土豆、藕片等过油后与香锅底料猛炒，虾壳酥脆，虾肉弹嫩。
食材：大虾300克、土豆150克、藕150克、洋葱50克、干辣椒10克、花椒5克、郫县豆瓣20克、蒜片10克
价格：32元

主菜：避风塘炒蟹
特色：螃蟹裹上蒜蓉面包糠炸炒，蒜香浓郁，酥脆干香。
食材：梭子蟹2只（约500克）、面包糠100克、蒜末50克、干辣椒5克、盐3克、胡椒粉2克、淀粉30克
价格：45元

主菜：白灼菜心
特色：菜心在沸水中快速烫熟，淋上生抽和热油，色泽翠绿，清甜脆嫩。
食材：菜心400克、生抽20毫升、蚝油10克、蒜末5克、食用油20毫升
价格：12元

主菜：上汤娃娃菜
特色：娃娃菜与皮蛋、咸蛋、火腿同煮，汤色金黄，菜叶软嫩，鲜味醇厚。
食材：娃娃菜300克、皮蛋1个、咸蛋1个、火腿20克、蒜片5克、高汤200毫升、盐3克
价格：18元

主菜：干煸牛肉丝
特色：牛肉丝煸至干香，与辣椒、花椒、芹菜同炒，麻辣酥香。
食材：牛里脊肉250克、干辣椒10克、花椒5克、芹菜50克、姜蒜丝各5克、生抽10毫升、料酒10毫升、白糖3克
价格：28元

主菜：水煮牛蛙
特色：牛蛙块滑嫩，配菜垫底，浇滚油激香辣椒花椒，汤底麻辣。
食材：牛蛙500克、豆芽150克、莴笋100克、干辣椒20克、花椒10克、郫县豆瓣40克、姜蒜末各10克、蛋清1个、淀粉15克
价格：38元

主菜：泡椒田鸡
特色：田鸡与泡椒、莴笋同烧，酸辣嫩滑，泡椒风味突出。
食材：田鸡400克、泡椒80克、莴笋100克、姜蒜片各10克、料酒15毫升、生抽10毫升、白糖5克
价格：32元

主菜：酱爆鸡丁
特色：鸡丁与黄瓜丁、甜面酱快速翻炒，酱香浓郁，咸甜适中。
食材：鸡胸肉300克、黄瓜100克、甜面酱30克、白糖10克、料酒10毫升、蛋清1个、淀粉10克
价格：22元

主菜：醋溜白菜
特色：白菜片急火快炒，烹入香醋，口感脆爽，酸香开胃。
食材：大白菜300克、干辣椒3个、蒜片5克、香醋20毫升、生抽10毫升、盐3克、白糖5克
价格：10元

主菜：宫保虾球
特色：虾仁滑炒，加入花生米、干辣椒，宫保汁酸甜微辣，虾仁弹牙。
食材：虾仁300克、花生米50克、干辣椒10克、花椒3克、葱段20克、生抽15毫升、醋10毫升、白糖10克、蛋清1个
价格：35元

主菜：黑椒牛柳
特色：牛柳与洋葱、青椒同炒，黑胡椒碎调味，咸香微辣，肉质嫩滑。
食材：牛里脊肉300克、洋葱50克、青椒50克、黑胡椒碎5克、蚝油15克、生抽10毫升、料酒10毫升、淀粉10克
价格：32元

主菜：铁板牛肉
特色：牛肉片在高温铁板上快速煎熟，配洋葱、青红椒，滋滋作响，焦香扑鼻。
食材：牛里脊肉300克、洋葱100克、青椒50克、红椒50克、黑胡椒碎3克、蚝油20克、生抽10毫升、黄油20克
价格：35元

主菜：尖椒肉丝
特色：猪里脊丝与尖椒丝大火爆炒，尖椒香辣，肉丝嫩滑。
食材：猪里脊肉200克、尖椒200克、姜蒜末各5克、生抽15毫升、料酒10毫升、淀粉5克
价格：18元

主菜：蒜蓉西兰花
特色：西兰花焯水后与蒜蓉、蚝油翻炒，色泽翠绿，清脆爽口。
食材：西兰花400克、蒜末15克、蚝油20克、盐2克、食用油15毫升
价格：12元

主菜：干锅千叶豆腐
特色：千叶豆腐切片与五花肉、辣椒干锅煸炒，豆香浓郁，口感Q弹。
食材：千叶豆腐300克、五花肉50克、青红椒各30克、干辣椒5克、蒜片10克、生抽15毫升、郫县豆瓣10克
价格：18元

主菜：芹菜炒肉丝
特色：芹菜段与肉丝同炒，芹菜清香脆嫩，肉丝咸鲜。
食材：猪里脊肉150克、芹菜300克、姜蒜丝各5克、生抽10毫升、料酒5毫升、盐3克
价格：14元

主菜：西红柿炒蛋
特色：鸡蛋嫩滑，西红柿酸甜，汤汁浓郁，经典家常菜。
食材：鸡蛋3个、西红柿300克、葱花5克、盐3克、白糖10克、食用油20毫升
价格：12元

主菜：酸辣土豆丝
特色：土豆丝快炒，醋与辣椒调味，口感脆爽，酸辣开胃。
食材：土豆400克、干辣椒3个、蒜末5克、香醋15毫升、盐3克、花椒5克
价格：10元

主菜：清炒油麦菜
特色：油麦菜大火快炒，蒜香提味，色泽翠绿，口感脆嫩。
食材：油麦菜500克、蒜末10克、盐3克、食用油20毫升
价格：10元

主菜：龙井虾仁
特色：虾仁以龙井茶汁腌制后滑炒，茶香清幽，虾仁白嫩鲜甜。
食材：虾仁300克、龙井茶叶3克、蛋清1个、淀粉10克、盐3克、料酒5毫升
价格：38元

主菜：松鼠鳜鱼
特色：鳜鱼改刀炸开如松鼠尾，浇番茄酸甜汁，外酥里嫩，造型喜庆。
食材：鳜鱼1条（约600克）、淀粉100克、番茄酱50克、白糖40克、白醋30毫升、松仁10克、姜蒜末各5克
价格：42元

主菜：海鲜大咖
特色：多种海鲜（虾、蟹、花蛤、鱿鱼等）与麻辣汤汁同煮，鲜辣过瘾。
食材：鲜虾200克、花蛤200克、鱿鱼200克、蟹肉棒100克、干辣椒20克、花椒10克、郫县豆瓣40克、姜蒜各10克
价格：55元

主菜：砂锅鱼头
特色：鱼头在砂锅中慢炖，配豆腐、香菇，汤浓味醇，鱼肉细嫩。
食材：鱼头1个（约800克）、嫩豆腐200克、香菇50克、姜片10克、葱段10克、生抽15毫升、料酒20毫升、盐5克
价格：32元

主菜：炖牛腩
特色：牛腩与番茄、胡萝卜同炖至酥烂，汤汁浓稠，咸鲜微酸。
食材：牛腩500克、番茄200克、胡萝卜100克、洋葱50克、八角2个、桂皮1小块、生抽30毫升、老抽10毫升、冰糖10克
价格：38元

主菜：蒜香排骨
特色：排骨用蒜蓉腌制后炸制，蒜香浓郁，外酥里嫩。
食材：猪肋排500克、蒜蓉30克、生抽20毫升、蚝油15克、料酒10毫升、淀粉30克
价格：30元

主菜：蜜汁叉烧
特色：梅花肉腌制蜜汁后烤制，表面焦红油亮，甜咸适口。
食材：猪梅花肉500克、叉烧酱60克、蜂蜜30克、料酒15毫升、姜汁5毫升
价格：28元

主菜：烤羊排
特色：羊排用孜然、辣椒粉腌制后烤至外焦里嫩，香气四溢。
食材：羊排800克、孜然粉15克、辣椒粉10克、盐5克、洋葱丝50克、姜片10克
价格：65元

主菜：葱烧排骨
特色：排骨与大量葱段、酱油烧制，葱香渗入骨髓，咸鲜回甘。
食材：猪肋排500克、大葱100克、姜片10克、生抽30毫升、老抽15毫升、冰糖15克、料酒20毫升
价格：30元

主菜：椒盐虾
特色：大虾炸至虾壳酥脆，撒上椒盐和蒜蓉，咸香酥脆。
食材：大虾400克、椒盐粉10克、蒜末10克、干辣椒5克、淀粉30克、盐3克
价格：35元

汤菜（40道）
汤菜：佛跳墙
特色：汇聚鲍鱼、海参、鱼翅等多种山珍海味，汤汁浓稠如琥珀，醇厚鲜香。
食材：鲍鱼3只、海参2条、干贝20克、蹄筋50克、花菇4朵、鸽子蛋4个、老母鸡块200克、猪蹄块200克、火腿50克、绍兴黄酒50毫升、高汤500毫升
价格：85元

汤菜：广东老火靓汤
特色：猪骨、鸡肉与药材经数小时文火慢煲，汤色清亮，食材鲜味充分融入汤中。
食材：猪脊骨300克、鸡肉200克、五指毛桃30克、枸杞10克、红枣6颗、姜片10克、盐5克
价格：38元

汤菜：江西瓦罐汤
特色：食材入小瓦罐密封，置于大瓦缸中用炭火余温慢煨，汤汁清澈鲜甜。
食材：排骨200克、乌鸡块150克、茶树菇20克、天麻10克、枸杞10克、姜片5克、盐3克
价格：28元

汤菜：开水白菜
特色：以老母鸡、火腿等吊制的高汤，汤色清澈如水，味道鲜醇，白菜心清甜。
食材：白菜心1棵、老母鸡1只、火腿50克、干贝20克、瘦肉100克、盐3克
价格：42元

汤菜：文思豆腐羹
特色：豆腐切成如发丝的细丝，与高汤同烩，口感软嫩，味道清鲜。
食材：嫩豆腐200克、香菇10克、火腿10克、青菜叶10克、高汤300毫升、水淀粉15克、盐3克
价格：18元

汤菜：西湖莼菜汤
特色：莼菜翠绿滑嫩，汤色清亮，味道鲜美，带有江南水乡的清雅风味。
食材：莼菜150克、火腿丝15克、鸡胸肉丝15克、高汤300毫升、盐3克
价格：20元

汤菜：宋嫂鱼羹
特色：鳜鱼或鲈鱼肉丝与火腿丝、香菇丝同煮，勾芡后色泽悦目，鲜嫩滑润。
食材：鳜鱼肉150克、火腿丝15克、香菇丝15克、鸡蛋清1个、高汤300毫升、水淀粉15克、香醋5毫升、胡椒粉2克
价格：22元

汤菜：乌鱼蛋汤
特色：乌鱼蛋薄片经高汤烩制，口感柔韧，汤味清鲜微辣，酸辣适口。
食材：乌鱼蛋50克、高汤300毫升、醋10毫升、胡椒粉3克、水淀粉15克、香菜末5克
价格：28元

汤菜：奶汤蒲菜
特色：蒲菜以奶汤（高汤与牛奶混合）烹制，汤色乳白，口感清脆，味道鲜香。
食材：蒲菜200克、高汤250毫升、牛奶50毫升、火腿片15克、盐3克
价格：18元

汤菜：单县羊肉汤
特色：选用当地青山羊，以白芷、花椒等香料熬煮，汤色乳白，鲜而不膻。
食材：羊肉500克、羊骨500克、白芷5克、花椒5克、姜片15克、盐5克、香菜10克
价格：30元

汤菜：黄山炖鸽
特色：乳鸽与黄山山药、枸杞同炖，汤清味鲜，鸽肉酥烂。
食材：乳鸽1只（约400克）、山药100克、枸杞10克、姜片5克、黄酒20毫升、盐3克
价格：35元

汤菜：武汉排骨藕汤
特色：猪排骨与粉藕一同慢炖，汤色粉红，藕块粉糯，肉香浓郁。
食材：猪排骨300克、粉藕500克、姜片10克、盐5克、胡椒粉2克
价格：22元

汤菜：汽锅鸡
特色：鸡肉入汽锅，利用蒸汽凝成汤汁，汤色清亮，原汁原味，鲜美无比。
食材：鸡半只（约500克）、姜片10克、枸杞10克、盐3克
价格：28元

汤菜：凯里酸汤鱼
特色：鱼片入发酵的米汤酸汤中煮熟，汤底酸辣鲜香，开胃爽口。
食材：草鱼1条约750克、凯里红酸汤200克、木姜子5克、辣椒10克、西红柿50克、姜片10克
价格：35元

汤菜：胡辣汤
特色：以牛羊肉汤为底，加入面筋、木耳、黄花菜等，用大量胡椒调味，汤体浓稠，辛辣驱寒。
食材：牛羊肉汤500毫升、面粉50克（洗面筋用）、木耳10克、黄花菜10克、粉条20克、花生米20克、胡椒粉10克、醋10毫升
价格：8元

汤菜：猪肚鸡
特色：鸡块包入猪肚中炖煮，汤色乳白，猪肚爽脆，鸡肉鲜嫩，汤味醇厚。
食材：猪肚1个（约500克）、三黄鸡半只（约400克）、姜片15克、白胡椒粉5克、枸杞10克、盐5克
价格：45元

汤菜：鲫鱼豆腐汤
特色：鲫鱼煎至两面金黄，与嫩豆腐同煮至汤色奶白，味道鲜甜。
食材：鲫鱼2条（约500克）、嫩豆腐200克、姜片10克、葱花5克、盐5克、料酒15毫升
价格：22元

汤菜：萝卜牛腩汤
特色：牛腩与白萝卜同炖至酥烂，汤色清亮，萝卜清甜，牛腩软糯。
食材：牛腩500克、白萝卜300克、姜片10克、八角2个、桂皮1小块、盐5克、香菜10克
价格：28元

汤菜：莲藕排骨汤
特色：排骨与莲藕同炖，汤色微粉，莲藕粉糯，排骨酥烂，汤味清甜。
食材：排骨300克、莲藕500克、姜片10克、盐5克、胡椒粉2克
价格：22元

汤菜：酸萝卜老鸭汤
特色：老鸭与酸萝卜、泡椒一同炖煮，汤色金黄，酸辣开胃，鸭肉酥烂。
食材：老鸭半只（约750克）、酸萝卜200克、泡椒20克、姜片15克、花椒5克、盐3克
价格：38元

汤菜：海带排骨汤
特色：排骨与海带同炖，汤色清亮，海带软滑，排骨酥烂，味道咸鲜。
食材：排骨300克、干海带100克、姜片5克、盐5克、料酒10毫升
价格：18元

汤菜：苦瓜黄豆排骨汤
特色：排骨与苦瓜、黄豆同炖，汤色微黄，苦瓜回甘，黄豆绵软，清热解暑。
食材：排骨300克、苦瓜200克、黄豆50克、姜片5克、盐5克
价格：20元

汤菜：花生猪蹄汤
特色：猪蹄与花生同炖至软烂，汤色浓白，富含胶质，口感醇厚。
食材：猪蹄500克、花生米100克、姜片10克、盐5克、料酒15毫升
价格：25元

汤菜：当归羊肉汤
特色：羊肉与当归、黄芪等药材同炖，汤色清亮，药香与肉香融合，温补暖身。
食材：羊肉500克、当归15克、黄芪10克、姜片15克、盐5克、料酒15毫升
价格：35元

汤菜：丝瓜蛋汤
特色：丝瓜与鸡蛋同煮，汤色清绿，丝瓜软嫩，蛋花鲜美，清淡爽口。
食材：丝瓜300克、鸡蛋2个、姜片3克、盐3克
价格：10元

汤菜：菠菜猪肝汤
特色：猪肝与菠菜同煮，汤色清亮，猪肝嫩滑，菠菜翠绿，补血养肝。
食材：猪肝150克、菠菜200克、姜片5克、盐3克、料酒10毫升
价格：12元

汤菜：罗宋汤
特色：牛肉与番茄、土豆、洋葱、卷心菜等一同熬煮，汤色红亮，酸甜浓郁。
食材：牛肉200克、番茄200克、土豆150克、洋葱50克、卷心菜100克、番茄酱30克、盐5克、糖10克
价格：18元

汤菜：冬阴功汤
特色：虾与香茅、南姜、柠檬叶、辣椒等香料同煮，汤色红亮，酸辣鲜香，风味独特。
食材：鲜虾200克、草菇50克、香茅2根、南姜10克、柠檬叶5片、小米辣5克、冬阴功酱30克、椰浆50毫升、鱼露10毫升、青柠汁15毫升
价格：28元

汤菜：味噌汤
特色：豆腐、海带与味噌酱同煮，汤体呈浅褐色，口感咸鲜，带有酱香。
食材：嫩豆腐100克、海带芽5克、味噌酱30克、葱花5克、柴鱼花5克
价格：12元

汤菜：奶油蘑菇汤
特色：蘑菇与洋葱炒香后，加入奶油、高汤熬煮并打碎，汤体浓稠，奶香与菌香浓郁。
食材：白蘑菇200克、洋葱50克、黄油20克、面粉20克、淡奶油50毫升、高汤200毫升、盐3克、白胡椒粉2克
价格：18元

汤菜：冬瓜虾仁汤
特色：冬瓜片与虾仁同煮，汤色清亮，冬瓜软糯，虾仁鲜甜，清淡爽口。
食材：冬瓜300克、虾仁100克、姜片5克、盐3克、料酒5毫升
价格：15元

汤菜：豆腐海带汤
特色：豆腐块与海带丝同煮，汤色清澈，豆腐嫩滑，海带鲜美，低脂健康。
食材：嫩豆腐200克、干海带30克、姜片5克、盐3克、香油2毫升
价格：10元

汤菜：紫菜蛋花汤
特色：紫菜与鸡蛋液煮成蛋花，汤色清亮，鲜味清淡，制作简单。
食材：紫菜10克、鸡蛋2个、葱花5克、盐2克、香油2毫升
价格：8元

汤菜：西红柿疙瘩汤
特色：西红柿炒出红油，加入面疙瘩煮熟，汤汁酸甜，面疙瘩软滑。
食材：西红柿200克、面粉100克、鸡蛋1个、盐3克、白糖5克、葱花5克
价格：10元

汤菜：蘑菇蛋花汤
特色：鲜蘑菇切片与蛋花同煮，菌香与蛋香融合，汤体清亮。
食材：鲜蘑菇150克、鸡蛋2个、盐3克、葱花5克、香油2毫升
价格：10元

汤菜：丝瓜蛤蜊汤
特色：丝瓜与蛤蜊同煮，汤色乳白，丝瓜软糯，蛤蜊鲜甜，汤汁鲜美。
食材：丝瓜300克、蛤蜊200克、姜片5克、盐3克、料酒5毫升
价格：18元

汤菜：冬瓜肉丸汤
特色：冬瓜片与猪肉丸同煮，汤色清亮，肉丸弹嫩，冬瓜清甜。
食材：冬瓜300克、猪肉末150克、姜末5克、盐3克、料酒5毫升
价格：15元

汤菜：菠菜粉丝汤
特色：菠菜与粉丝同煮，汤色翠绿，粉丝滑软，菠菜鲜嫩，清淡适口。
食材：菠菜300克、粉丝50克、盐3克、香油2毫升
价格：8元

汤菜：白菜豆腐汤
特色：白菜与豆腐同煮，汤色清浅，白菜软烂，豆腐嫩滑，清淡家常。
食材：大白菜200克、嫩豆腐200克、姜片3克、盐3克
价格：8元

汤菜：萝卜排骨汤
特色：排骨与白萝卜同炖，汤色清亮，萝卜透明，排骨酥烂，味道咸鲜。
食材：排骨300克、白萝卜300克、姜片5克、盐5克、料酒10毫升
价格：18元

饮品（40种）
饮品：杨枝甘露
特色：芒果泥与椰浆、西柚粒、西米混合，酸甜平衡，口感丰富。
食材：芒果肉200g、椰浆100ml、西柚肉30g、西米50g、冰糖浆20ml
价格：22元

饮品：满杯百香果
特色：百香果籽与绿茶、蜂蜜、柠檬调制，酸甜清爽，果香浓郁。
食材：绿茶150ml、百香果2个（约100g）、蜂蜜30ml、青柠片3片、冰块150g
价格：16元

饮品：柠檬茶
特色：港式做法，以浓红茶为底，加入大量柠檬，茶味浓郁，酸甜回甘。
食材：浓红茶汤200ml、柠檬片5片、白糖浆30ml、冰块100g
价格：12元

饮品：茉莉绿茶
特色：茉莉花香与绿茶清雅融合，汤色清亮，口感清爽。
食材：茉莉花茶5g、90℃热水300ml、冰糖浆20ml（可选）、冰块50g
价格：10元

饮品：桂花乌龙茶
特色：桂花香气与乌龙茶醇厚结合，茶汤金黄，香气怡人。
食材：桂花乌龙茶5g、95℃热水300ml、冰糖浆15ml（可选）
价格：15元

饮品：玫瑰普洱
特色：玫瑰花香与普洱陈香交融，茶汤红浓，口感醇和。
食材：普洱茶5g、干玫瑰花5朵、95℃热水300ml
价格：18元

饮品：珍珠奶茶
特色：经典台式奶茶，珍珠Q弹，奶香与茶香平衡。
食材：红茶汤200ml、奶精40g、果糖30g、珍珠50g、冰块100g
价格：10元

饮品：奶盖绿茶
特色：绿茶底清爽，上层奶盖绵密咸香，搭配饮用，层次分明。
食材：绿茶200ml、果糖25g、芝士奶盖60g、冰块100g
价格：16元

饮品：黑糖珍珠鲜奶
特色：黑糖挂壁，珍珠软糯，鲜奶香醇，不添加茶底，风味纯粹。
食材：鲜奶250ml、黑糖珍珠100g、黑糖浆30ml、冰块50g
价格：15元

饮品：抹茶拿铁
特色：抹茶粉与鲜奶融合，茶香清新，口感顺滑，不另加咖啡。
食材：抹茶粉8g、热水50ml、鲜奶250ml、糖浆25g、冰块100g
价格：18元

饮品：芋泥波波茶
特色：手捣芋泥挂壁，搭配波波和鲜奶，口感绵密，芋香浓郁。
食材：芋泥80g、鲜奶250ml、波波50g、糖浆20g
价格：18元

饮品：豆乳奶茶
特色：豆浆粉与奶茶底融合，上层有豆乳奶盖和黄豆粉，豆香与茶香结合。
食材：红茶汤150ml、豆浆粉30g、奶精20g、果糖25g、豆乳奶盖50g、黄豆粉5g
价格：16元

饮品：芒果绿茶
特色：芒果泥与绿茶、冰块打制冰沙，芒果香甜，绿茶清爽。
食材：芒果肉150g、绿茶100ml、果糖20ml、冰块200g
价格：18元

饮品：西瓜汁
特色：西瓜切块后榨汁，清甜解渴，口感清爽。
食材：西瓜500g、白糖10g（可选）、冰块50g
价格：12元

饮品：甘蔗汁
特色：新鲜甘蔗榨汁，清甜纯净，消暑解渴。
食材：甘蔗500g、冰块50g（可选）、柠檬片1片（可选）
价格：8元

饮品：蜂蜜柚子茶
特色：柚子酱与蜂蜜用热水冲泡，酸甜中带有柚子的清香。
食材：柚子酱30g、蜂蜜15ml、热水250ml
价格：12元

饮品：金桔柠檬茶
特色：金桔与柠檬的酸味搭配绿茶，酸甜适中，清香解腻。
食材：绿茶150ml、金桔3颗（对半切开）、青柠片3片、糖浆30ml、冰块100g
价格：14元

饮品：奇异果冰茶
特色：奇异果捣碎与绿茶混合，酸甜清爽，富含维C。
食材：奇异果1个（约80g）、绿茶150ml、糖浆20ml、冰块150g
价格：16元

饮品：草莓多多
特色：草莓果肉与养乐多、绿茶混合，酸甜融合，口感丰富。
食材：草莓4颗（约60g）、养乐多1瓶（100ml）、绿茶50ml、糖浆15ml、冰块100g
价格：15元

饮品：水蜜桃乌龙
特色：水蜜桃果肉与乌龙茶结合，桃香与茶香层次分明。
食材：水蜜桃果肉80g、乌龙茶150ml、糖浆25ml、冰块150g
价格：17元

饮品：青柠薄荷苏打
特色：青柠汁与薄荷叶加入苏打水，口感清爽，气泡感足。
食材：青柠汁20ml、薄荷叶5片、苏打水250ml、糖浆15ml、冰块100g
价格：12元

饮品：咸柠七
特色：咸柠檬与七喜汽水结合，咸甜交织，清爽解腻，港式经典。
食材：咸柠檬半个、七喜汽水250ml、冰块100g
价格：13元

饮品：港式奶茶
特色：锡兰红茶与淡奶、炼乳调制，茶味浓郁，口感丝滑。
食材：锡兰红茶汤200ml、淡奶50ml、炼乳20g、冰块50g（可选）
价格：15元

饮品：鸳鸯奶茶
特色：咖啡与奶茶的混合饮品，兼具咖啡的香气和奶茶的顺滑。
食材：浓缩咖啡30ml、锡兰红茶汤150ml、淡奶50ml、糖浆20ml
价格：18元

饮品：可可奶
特色：可可粉与鲜奶、糖调制，口感醇厚，带有可可的香气。
食材：可可粉15g、鲜奶250ml、糖浆25g、热水50ml
价格：15元

饮品：杏仁茶
特色：南杏仁磨浆后与鲜奶煮制，口感细腻，杏仁香气突出。
食材：南杏仁50g、鲜奶200ml、冰糖20g、水200ml
价格：18元

饮品：姜汁奶茶
特色：生姜汁与红糖、鲜奶、红茶调制，辛辣中带有甜润，驱寒暖身。
食材：红茶汤200ml、鲜奶100ml、红糖20g、姜汁15ml
价格：16元

饮品：桂花酸梅汤
特色：乌梅、山楂、甘草、桂花熬制，酸甜生津，清凉解暑。
食材：乌梅30g、山楂20g、甘草5g、桂花5g、冰糖100g、水1500ml
价格：12元

饮品：绿豆沙牛乳
特色：绿豆熬煮成沙，与鲜奶混合，口感细腻，豆香与奶香融合。
食材：绿豆100g、鲜奶200ml、冰糖30g、水500ml
价格：10元

饮品：红豆沙牛乳
特色：红豆熬煮成沙，与鲜奶混合，口感绵密，甜润暖胃。
食材：红豆100g、鲜奶200ml、冰糖30g、水500ml
价格：12元

饮品：红枣枸杞茶
特色：红枣与枸杞用热水冲泡，茶汤清甜，温补养气。
食材：红枣5颗、枸杞10g、热水300ml、冰糖15g（可选）
价格：8元

饮品：菊花茶
特色：干菊花冲泡，汤色淡黄，清香微苦，清热去火。
食材：干菊花5g、热水300ml、冰糖10g（可选）
价格：6元

饮品：薄荷茶
特色：新鲜薄荷叶与绿茶或热水冲泡，清凉提神，口感清爽。
食材：薄荷叶10g、绿茶5g（可选）、热水300ml、蜂蜜15ml
价格：8元

饮品：玫瑰茶
特色：干玫瑰花与红茶或热水冲泡，花香浓郁，茶汤粉红。
食材：干玫瑰花10g、热水300ml、冰糖10g
价格：10元

饮品：姜茶
特色：生姜切片与红糖熬煮，辛辣暖胃，驱寒发汗。
食材：生姜20g、红糖25g、水300ml
价格：8元

饮品：薏米水
特色：薏米熬煮后取水饮用，口感清淡，利水渗湿。
食材：薏米50g、冰糖20g、水800ml
价格：10元

饮品：红豆薏米水
特色：红豆与薏米同煮，汤汁微稠，清甜利水。
食材：红豆30g、薏米30g、冰糖20g、水800ml
价格：12元

饮品：绿豆汤
特色：绿豆煮至开花，汤色碧绿，清甜解暑。
食材：绿豆100g、冰糖30g、水1000ml
价格：8元

饮品：酸梅汁
特色：乌梅与山楂、甘草熬制，酸甜生津，冰镇更佳。
食材：乌梅40g、山楂30g、甘草5g、冰糖100g、水1500ml
价格：10元

饮品：柠檬水
特色：柠檬片与蜂蜜浸泡，酸甜清爽，简单解渴。
食材：柠檬片5片、蜂蜜20ml、温水300ml、冰块50g
价格：6元

甜点（40种，价格为单个个体整数价格）
甜点：双皮奶
特色：双层奶皮凝结，奶香浓郁，口感细腻顺滑。
食材：全脂牛奶400ml、蛋清2个、白砂糖25g
价格：12元

甜点：姜撞奶
特色：姜汁与热牛奶碰撞凝固，口感滑嫩，姜味辛香，奶味浓郁。
食材：全脂牛奶250ml、老姜汁20ml、白砂糖15g
价格：10元

甜点：椰汁西米露
特色：椰汁香甜，西米Q弹透明，搭配红豆或芋头，口感丰富。
食材：椰浆200ml、西米50g、冰糖20g、水200ml
价格：10元

甜点：芒果布丁
特色：芒果泥与奶油、吉利丁制成，口感嫩滑，果香浓郁。
食材：芒果泥200g、淡奶油100ml、牛奶100ml、吉利丁片10g、细砂糖20g
价格：15元

甜点：榴莲班戟
特色：班戟皮包裹榴莲果肉和奶油，外皮柔韧，内馅香甜软糯。
食材：班戟皮2张、榴莲肉100g、淡奶油100ml、细砂糖10g
价格：20元

甜点：雪媚娘
特色：糯米皮软糯拉丝，内馅为奶油和水果，口感清凉。
食材：糯米粉100g、玉米淀粉30g、牛奶180ml、黄油20g、细砂糖40g、淡奶油150ml、芒果丁50g
价格：10元

甜点：大福
特色：糯米皮包裹饱满的红豆沙馅，外皮软糯，豆沙甜润，经典日式甜点。
食材：糯米粉100g、水180ml、细砂糖50g、红豆沙150g、熟糯米粉（手粉）30g
价格：8元

甜点：铜锣烧
特色：两片松软的蜂蜜饼皮夹着红豆沙馅，香甜可口。
食材：鸡蛋2个、低筋面粉120g、细砂糖80g、蜂蜜20g、泡打粉3g、牛奶50ml、红豆沙150g
价格：7元

甜点：鲷鱼烧
特色：模具烤制的鱼形蛋糕，外皮酥脆，内馅为红豆沙或卡仕达酱。
食材：鸡蛋2个、低筋面粉150g、细砂糖60g、牛奶100ml、泡打粉5g、红豆沙150g
价格：8元

甜点：马卡龙
特色：杏仁蛋白饼外壳酥脆，内馅湿润，色彩缤纷，口感甜腻。
食材：杏仁粉100g、糖粉100g、蛋清75g、细砂糖75g、色素少许
价格：15元

甜点：闪电泡芙
特色：长条形泡芙皮酥脆，内馅为香草奶油，表面淋有巧克力或糖霜。
食材：泡芙皮（水125ml、黄油50g、低筋面粉75g、鸡蛋2个）、香草奶油馅100g、巧克力酱20g
价格：12元

甜点：可丽饼
特色：薄饼皮包裹新鲜水果和奶油，口感柔软，果香清新。
食材：鸡蛋2个、低筋面粉80g、牛奶200ml、白糖20g、黄油10g、鲜奶油100ml、水果（香蕉/草莓）适量
价格：10元

甜点：华夫饼
特色：格子状松饼，外酥内软，搭配水果、奶油或冰淇淋。
食材：鸡蛋2个、低筋面粉150g、牛奶150ml、白糖50g、黄油50g、泡打粉5g
价格：8元

甜点：松饼
特色：厚煎饼口感蓬松绵软，搭配黄油和枫糖浆，早餐经典。
食材：鸡蛋2个、低筋面粉200g、牛奶200ml、白糖30g、泡打粉10g、黄油30g
价格：7元

甜点：戚风蛋糕
特色：蛋清打发，组织细腻，口感轻盈湿润，常作为蛋糕底。
食材：鸡蛋5个、低筋面粉100g、玉米油60g、牛奶70ml、细砂糖80g
价格：12元

甜点：海绵蛋糕
特色：全蛋打发，组织均匀，口感扎实，蛋香浓郁。
食材：鸡蛋4个、低筋面粉120g、细砂糖100g、黄油30g
价格：10元

甜点：芝士蛋糕
特色：奶油奶酪为主要原料，口感绵密，奶香浓郁，分轻乳酪和重乳酪。
食材：奶油奶酪250g、消化饼干底100g、细砂糖80g、鸡蛋3个、淡奶油100ml、柠檬汁10ml
价格：18元

甜点：布朗尼
特色：巧克力蛋糕质地密实，口感湿润，带有坚果碎，巧克力风味浓郁。
食材：黑巧克力150g、黄油100g、细砂糖100g、鸡蛋2个、低筋面粉80g、核桃仁50g
价格：15元

甜点：马芬
特色：纸杯蛋糕，口感介于蛋糕和面包之间，常加入蓝莓、巧克力豆等。
食材：低筋面粉150g、鸡蛋1个、牛奶80ml、玉米油50ml、细砂糖60g、泡打粉5g、蓝莓50g
价格：6元

甜点：曲奇
特色：黄油饼干，口感酥脆，奶香浓郁，可加入巧克力豆或坚果。
食材：黄油150g、低筋面粉250g、糖粉80g、鸡蛋1个
价格：5元

甜点：杏仁饼
特色：以杏仁粉和黄油制作，口感酥松，杏仁香气突出，澳门特色。
食材：杏仁粉100g、低筋面粉50g、糖粉50g、黄油80g、鸡蛋1个
价格：8元

甜点：核桃酥
特色：传统中式点心，口感酥脆，核桃仁香，甜而不腻。
食材：低筋面粉200g、核桃仁80g、黄油100g、糖粉80g、鸡蛋1个、泡打粉3g
价格：5元

甜点：桃酥
特色：传统酥点，口感干酥，表面有裂纹，芝麻点缀，香甜可口。
食材：低筋面粉250g、白糖100g、玉米油120g、鸡蛋1个、小苏打3g、泡打粉3g、芝麻20g
价格：3元

甜点：蛋黄酥
特色：酥皮包裹豆沙和咸蛋黄，咸甜交织，层次分明，口感丰富。
食材：中筋面粉200g、低筋面粉150g、猪油100g、红豆沙200g、咸蛋黄10个、糖粉30g
价格：8元

甜点：老婆饼
特色：酥皮包裹冬瓜蓉馅，外皮酥松，内馅软糯，甜而不腻。
食材：中筋面粉200g、低筋面粉150g、猪油100g、冬瓜蓉200g、白芝麻20g、糖粉30g
价格：6元

甜点：凤梨酥
特色：酥松外皮包裹凤梨馅，酸甜适中，果香浓郁，台湾特色。
食材：低筋面粉200g、黄油150g、糖粉50g、鸡蛋1个、凤梨馅200g
价格：7元

甜点：雪花酥
特色：棉花糖、饼干、坚果和果干混合制成，口感酥脆，甜中带咸。
食材：棉花糖150g、黄油40g、全脂奶粉50g、饼干100g、坚果50g、蔓越莓干30g
价格：6元

甜点：牛轧糖
特色：棉花糖与花生、奶粉混合制成，口感有嚼劲，奶香与坚果香融合。
食材：棉花糖150g、黄油40g、奶粉80g、花生碎100g
价格：4元

甜点：芝麻糖
特色：芝麻与麦芽糖、白糖熬制，口感酥脆，芝麻香气浓郁。
食材：黑芝麻200g、白糖100g、麦芽糖50g、水30ml
价格：5元

甜点：花生糖
特色：花生与麦芽糖、白糖熬制，口感酥脆，花生香味突出。
食材：花生仁200g、白糖100g、麦芽糖50g、水30ml
价格：4元

甜点：焦糖布丁
特色：蛋奶液烤制后表面焦糖脆壳，内里嫩滑，甜中带微苦。
食材：鸡蛋2个、牛奶250ml、细砂糖40g、香草精2滴、焦糖酱（糖50g+水15ml）
价格：10元

甜点：法式可露丽
特色：铜模烤制的外焦里嫩小甜点，外壳焦香，内馅湿润，有朗姆酒和香草味。
食材：牛奶500ml、黄油30g、细砂糖150g、低筋面粉100g、鸡蛋2个、朗姆酒20ml
价格：12元

甜点：甜甜圈
特色：油炸面包圈，表面裹糖霜或巧克力酱，松软甜香。
食材：高筋面粉250g、酵母3g、黄油30g、牛奶120ml、细砂糖30g、鸡蛋1个、糖霜20g
价格：6元

甜点：马卡龙（树莓味）
特色：树莓味马卡龙，外壳酥脆，内馅酸甜，色彩鲜艳。
食材：杏仁粉100g、糖粉100g、蛋清75g、细砂糖75g、树莓酱20g、色素少许
价格：16元

甜点：泡芙（原味奶油）
特色：空心酥皮内注入香草奶油，口感轻盈，奶香浓郁。
食材：泡芙皮（水100ml、黄油50g、低筋面粉60g、鸡蛋2个）、香草奶油馅150g
价格：8元

甜点：千层蛋糕
特色：多层可丽饼与奶油堆叠，口感层次丰富，细腻绵密。
食材：可丽饼（鸡蛋4个、牛奶400ml、低筋面粉150g、黄油30g、糖30g）、淡奶油300ml、糖30g
价格：15元

甜点：毛巾卷
特色：抹茶或可可味可丽饼皮层层卷起，中间夹奶油，外形似毛巾。
食材：可丽饼皮5张（鸡蛋3个、牛奶250ml、低筋面粉100g、抹茶粉8g、糖30g）、淡奶油200ml、糖20g
价格：10元

甜点：半熟芝士
特色：轻乳酪蛋糕，中心呈半流动状，入口即化，芝士味浓郁。
食材：奶油奶酪200g、黄油30g、牛奶100ml、蛋黄3个、蛋白3个、细砂糖50g、低筋面粉20g
价格：12元

甜点：梦龙卷
特色：巧克力蛋糕卷裹上坚果巧克力脆壳，内馅为奶油，外脆内软。
食材：巧克力蛋糕卷（鸡蛋4个、低筋面粉60g、糖50g）、淡奶油150ml、黑巧克力80g、坚果碎30g
价格：18元

甜点：生巧
特色：高纯度黑巧克力与奶油混合，冷藏后切块，口感绵密丝滑，微苦回甘。
食材：黑巧克力（70%）200g、淡奶油100ml、黄油20g、可可粉20g
价格：22元
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

子思：“致中和，天地位焉，万物育焉。”——《中庸》

列子：“欲刚，必以柔守之；欲强，必以弱保之。”——《列子·黄帝》

鬼谷子：“口者，心之门户也。”——《鬼谷子·捭阖》

商鞅：“治世不一道，便国不法古。”——《商君书·更法》

司马迁：“其身正，不令而行；其身不正，虽令不从。”——《史记·李将军列传》

韩愈：“师者，所以传道受业解惑也。”——《师说》

柳宗元：“美不自美，因人而彰。”——《邕州马退山茅亭记》

欧阳修：“君子以同道为朋，小人以同利为朋。”——《朋党论》

苏轼：“天下有大勇者，卒然临之而不惊，无故加之而不怒。”——《留侯论》

王阳明：“知是行之始，行是知之成。”——《传习录》

黄宗羲：“学贵履践，经世致用。”——《明夷待访录》

王夫之：“知行相资以为用。”——《礼记章句》

王安石：“度义而后动，是而不见可悔故也。”——《答司马谏议书》

梁启超：“凡做事，将成功之时，其困难最甚。”——《梁启超文集》

胡适：“大胆假设，小心求证。”——《科学精神与方法》

胡适：“怕什么真理无穷，进一寸有一寸的欢喜。”——《胡适文存》

李大钊：“人生最有趣的事情，就是送旧迎新。”——《李大钊全集》

周恩来：“理想是需要的，是我们前进的方向。”——《周恩来选集》

邓小平：“不管黑猫白猫，抓住老鼠就是好猫。”——《邓小平文选》

袁隆平：“人就像一粒种子，要做一粒好种子。”——《袁隆平口述自传》

闻一多：“人家说了再做，我是做了再说。”——《闻一多全集》

陶行知：“行是知之始，知是行之成。”——《陶行知教育文集》

傅雷：“真诚是第一把艺术的钥匙。”——《傅雷家书》

刘向：“耳闻之不如目见之，目见之不如足践之。”——《说苑·政理》

班固：“绳锯木断，水滴石穿。”——《汉书》

班固：“水至清则无鱼，人至察则无徒。”——《汉书·东方朔传》

诸葛亮：“志当存高远。”——《诫外生书》

诸葛亮：“不傲才以骄人，不以宠而作威。”——《将苑》

顾炎武：“博学于文，行己有耻。”——语本《日知录》

曹丕：“文人相轻，自古而然。”——《典论·论文》

孔子：“知者不惑，仁者不忧，勇者不惧。”——《论语·子罕》

孔子：“士不可以不弘毅，任重而道远。”——《论语·泰伯》

孔子：“岁寒，然后知松柏之后凋也。”——《论语·子罕》

孔子：“君子求诸己，小人求诸人。”——《论语·卫灵公》

孔子：“人无远虑，必有近忧。”——《论语·卫灵公》

孟子：“得道多助，失道寡助。”——《孟子·公孙丑下》

孔子：“三军可夺帅也，匹夫不可夺志也。”——《论语·子罕》

孔子：“君子和而不同，小人同而不和。”——《论语·子路》

孔子：“见贤思齐焉，见不贤而内自省也。”——《论语·里仁》

孔子：“温故而知新，可以为师矣。”——《论语·为政》

孔子：“学而不厌，诲人不倦。”——《论语·述而》

孔子：“三人行，必有我师焉。”——《论语·述而》

孔子：“道不同，不相为谋。”——《论语·卫灵公》

孟子：“富贵不能淫，贫贱不能移，威武不能屈。”——《孟子·滕文公下》

孟子：“穷则独善其身，达则兼济天下。”——《孟子·尽心上》

孟子：“恻隐之心，仁之端也。”——《孟子·公孙丑上》

孟子：“不以规矩，不能成方圆。”——《孟子·离娄上》

老子：“道可道，非常道。”——《道德经》第一章

老子：“上善若水。”——《道德经》第八章

老子：“大音希声，大象无形。”——《道德经》第四十一章

庄子：“天地有大美而不言。”——《庄子·知北游》

庄子：“人生天地之间，若白驹之过隙。”——《庄子·知北游》

庄子：“吾丧我。”——《庄子·齐物论》

韩非子：“千里之堤，溃于蚁穴。”——《韩非子·喻老》

韩非子：“巧诈不如拙诚。”——《韩非子·说林上》

韩非子：“志之难也，不在胜人，在自胜。”——《韩非子·喻老》

孙子：“兵者，诡道也。”——《孙子兵法·计篇》

孙子：“不战而屈人之兵，善之善者也。”——《孙子兵法·谋攻篇》

管子：“一年之计，莫如树谷；十年之计，莫如树木；终身之计，莫如树人。”——《管子·权修》

吕不韦：“竭泽而渔，岂不获得？而明年无鱼。”——《吕氏春秋·义赏》

晏子：“橘生淮南则为橘，生于淮北则为枳。”——《晏子春秋·杂下》

司马迁：“桃李不言，下自成蹊。”——《史记·李将军列传》

司马迁：“燕雀安知鸿鹄之志哉！”——《史记·陈涉世家》

诸葛亮：“非学无以广才，非志无以成学。”——《诫子书》

范仲淹：“不以物喜，不以己悲。”——《岳阳楼记》

顾炎武：“保天下者，匹夫之贱与有责焉耳矣。”——《日知录·正始》

鲁迅：“其实地上本没有路，走的人多了，也便成了路。”——《故乡》

鲁迅：“哪里有天才，我是把别人喝咖啡的工夫都用在工作上的。”——《鲁迅全集》

苏格拉底：“未经审视的人生不值得过。”——柏拉图《申辩篇》

苏格拉底：“我唯一知道的是我一无所知。”——柏拉图《申辩篇》

柏拉图：“尊重人不应该胜于尊重真理。”——《法律篇》

柏拉图：“思想是灵魂的对话。”——《泰阿泰德篇》

亚里士多德：“幸福是把灵魂安放在最适当的位置。”——《尼各马可伦理学》

亚里士多德：“每天反复做的事情造就了我们。”——《尼各马可伦理学》

埃斯库罗斯：“胜利青睐深谋远虑的人。”——《祭奠者》

西塞罗：“没有诚实何来尊严？”——《论义务》

西塞罗：“依照自然而生，一切都会尽善尽美。”——《论生死》

西塞罗：“无知是智慧的黑夜，没有月亮、没有星星的黑夜。”——《论友谊》

塞涅卡：“我们整个人生都催人泪下。”——《论生命的短暂》

贺拉斯：“抓住今天，尽可能少信赖明天。”——《颂歌》

达·芬奇：“智慧是经验之女。”——《达·芬奇笔记》

蒙田：“怀疑是学问的起点。”——《随笔集》

苏格拉底：“美德即知识。”——柏拉图《美诺篇》

笛卡尔：“我思故我在。”——《方法论》

笛卡尔：“无法做出决策的人，或欲望过大，或觉悟不足。”——《方法论》

帕斯卡：“人是一根会思考的芦苇。”——《思想录》

亚里士多德：“人是政治的动物。”——《政治学》

伏尔泰：“判断一个人要看他的问题，而不是他的答案。”——《哲学辞典》

卢梭：“忍耐是苦涩的，但它的果实却是甘甜的。”——《爱弥儿》

卢梭：“人生而自由。”——《社会契约论》

亚里士多德：“哲学起源于惊奇。”——《形而上学》

康德：“三样东西有助于缓解生命的辛劳：希望、睡眠和微笑。”——《实用人类学》

黑格尔：“存在即合理。”——《法哲学原理》

黑格尔：“人是靠思想站立起来的。”——《历史哲学》

叔本华：“孤独是伟人的宿命。”——《人生的智慧》

亚里士多德：“求知是人类的本性。”——《形而上学》

费尔巴哈：“实践是真理的试金石。”——《基督教的本质》

费尔巴哈：“爱就是成就一个人。”——《基督教的本质》

培根：“读史使人明智。”——《培根随笔》

尼采：“谁终将声震人间，必长久深自缄默。”——《查拉图斯特拉如是说》

尼采：“一个人知道自己为什么而活，就可以忍受任何一种生活。”——《偶像的黄昏》

洛克：“知识来自经验。”——《人类理解论》

休谟：“习惯是人生的伟大指南。”——《人性论》

穆勒：“做一个不满足的人，比做一头满足的猪好。”——《功利主义》

克尔凯郭尔：“生命只能倒着被理解，但必须正着被经历。”——《克尔凯郭尔日记》

梭罗：“简朴是智慧的标志。”——《瓦尔登湖》

斯宾诺莎：“自由是认识必然。”——《伦理学》

惠特曼：“大地是永恒的。”——《草叶集》

康德：“人是目的。”——《道德形而上学基础》

雨果：“光明是真理的影子。”——《九三年》

雨果：“哪里有阴影，哪里就有光。”——《海上劳工》

黑格尔：“真理是全体。”——《精神现象学》

托尔斯泰：“爱是生活的全部。”——《战争与和平》

陀思妥耶夫斯基：“要爱具体的人，不要爱抽象的人。”——《卡拉马佐夫兄弟》

契诃夫：“简洁是天才的姐妹。”——《契诃夫书信集》

王尔德：“美是唯一的真理。”——《道林·格雷的画像》

王尔德：“我什么都能抗拒，除了诱惑。”——《理想丈夫》

马克·吐温：“诚实是最好的策略。”——《马克·吐温自传》

马克·吐温：“有时候真实比小说更加荒诞。”——《马克·吐温笔记》

叔本华：“世界是我的表象。”——《作为意志和表象的世界》

尼采：“没有事实，只有解释。”——《权力意志》

乔伊斯：“流亡就是我的美学。”——《一个青年艺术家的画像》

卡夫卡：“一本书必须是一把冰镐，砍碎我们内心的冰海。”——《卡夫卡书信集》

恩格斯：“劳动创造了人本身。”——《自然辩证法》

贝克莱：“存在即被感知。”——《人类知识原理》

海明威：“勇气是压力下的优雅。”——《海明威谈话录》

萨特：“存在先于本质。”——《存在主义是一种人道主义》

萨特：“他人即地狱。”——《禁闭》

加缪：“荒谬是永恒的。”——《西西弗神话》

马尔克斯：“孤独是永恒的。”——《百年孤独》

博尔赫斯：“天堂应该是图书馆的模样。”——《关于天赐的诗》

杜威：“教育即生活。”——《我的教育信条》

威廉·詹姆斯：“思想是行动的先导。”——《心理学原理》

莎士比亚：“智慧是命运的舵手。”——《暴风雨》

莎士比亚：“快乐是健康的源泉。”——《亨利四世》

莎士比亚：“生存还是毁灭，这是个问题。”——《哈姆雷特》

罗素：“三种激情支配我的一生。”——《我为什么而活着》

卢克莱修：“无中不能生有。”——《物性论》

雪莱：“冬天来了，春天还会远吗？”——《西风颂》

海德格尔：“人是被抛入世界的。”——《存在与时间》

泰戈尔：“世界以痛吻我，要我报之以歌。”——《飞鸟集》

马尔库塞：“艺术即否定。”——《审美之维》

华盛顿：“诚实是最好的政策。”——《华盛顿格言》

拿破仑：“不想当将军的士兵不是好士兵。”——《拿破仑格言》

林肯：“自由是上帝的礼物。”——《林肯演讲》

阿多诺：“奥斯维辛之后，诗是野蛮的。”——《文化批评与社会》

丘吉尔：“勇气是保持冷静。”——《二战回忆录》

曼德拉：“知识是自由的基石。”——《曼德拉自传》

甘地：“以眼还眼，世界只会更盲目。”——《甘地自传》

福柯：“知识即权力。”——《性史》

爱因斯坦：“价值在于贡献。”——《爱因斯坦文集》

爱因斯坦：“想象力比知识更重要。”——《爱因斯坦谈人生》

爱迪生：“勤奋是天才的代价。”——《爱迪生自传》

居里夫人：“科学是探索之美。”——《居里夫人自传》

霍金：“记住要仰望星空，不要低头看脚下。”——《时间简史》

波普尔：“科学始于神话。”——《猜想与反驳》

弗洛伊德：“梦是愿望的满足。”——《梦的解析》

达尔文：“物竞天择，适者生存。”——《物种起源》

弗雷格：“思想是客观的。”——《思想》

卢梭：“我们手里的金钱是保持自由的一种工具。”——《忏悔录》
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

-- ========== 诗词板块解析（-- 修改：v2.4.11 取代原 40 条硬编码 QUOTES 表） ==========
-- 解析内嵌 诗词第二版.txt：每行 1 条，结构「诗句。——朝代·作者《作品》」，
-- 产出与旧表同构的 {text, dynasty, author, work} 列表，供 pickQuote 轮换展示。
-- 设计要点（延续代码库字面 find/sub 截取约定，规避 Lua 模式对多字节 UTF-8 的字节级误伤）：
--   1. 字面定位「——」分界诗句与归属段（—— 为 6 字节）；
--   2. 作品名优先字面定位《》（各 3 字节），《》后的卷次标注（如「（其一）」）并入 work，
--      与旧表 work="梅岭三章（其一）" 保持一致；无《》时回退全角括号（秋瑾（绝命诗））；
--   3. 归属段含「·」（U+00B7，2 字节）时按位置拆分朝代/作者，否则视为无朝代条目（dynasty=""）；
--   4. 空行跳过，gmatch("[^\r\n]+") 兼容 CRLF/LF 混合换行。
local poem_cache
local function parsePoemText()
    if poem_cache then return poem_cache end
    local list = {}
    for line in POEM_TEXT:gmatch("[^\r\n]+") do
        line = line:gsub("%s+$", "")
        if line ~= "" then
            local dash = line:find("——", 1, true)
            if dash then
                local text = line:sub(1, dash - 1)
                local work, attrib
                local ws = line:find("《", dash, true)
                local we = line:find("》", dash, true)
                if ws and we and we > ws then
                    work = line:sub(ws + 3, we - 1)
                    local tail = line:sub(we + 3)
                    if tail ~= "" then work = work .. tail end
                    attrib = line:sub(dash + 6, ws - 1)
                else
                    local ps = line:find("（", dash, true)
                    local pe = line:find("）", dash, true)
                    if ps and pe and pe > ps then
                        work = line:sub(ps + 3, pe - 1)
                        attrib = line:sub(dash + 6, ps - 1)
                    else
                        attrib = line:sub(dash + 6)
                    end
                end
                local dynasty, author = "", attrib
                if attrib then
                    local dot = attrib:find("·", 1, true)
                    if dot then
                        dynasty = attrib:sub(1, dot - 1)
                        author = attrib:sub(dot + 2) -- · 为 2 字节（U+00B7）
                    end
                end
                if text ~= "" and author ~= "" and work then
                    table.insert(list, { text = text, dynasty = dynasty, author = author, work = work })
                end
            end
        end
    end
    poem_cache = list
    logger.info(LOG_TAG, "诗词解析完成：共%d条", #list)
    return list
end

-- 诗词候选库：由内嵌文本解析生成（-- 修改：v2.4.11）
local QUOTES = parsePoemText()

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

-- 拼接设备信息字符串：型号 + 屏幕尺寸（英寸）+ 分辨率 + DPI（字段缺失自动省略）
-- 入参：prefix 可选前缀标签（墨痕默认「设备：」；菜单样式传「点单设备：」）
--       -- 修改：v2.4.13 前缀参数化，修复菜单样式"点单设备：设备："双前缀重复
local function getDeviceInfoString(prefix)
    prefix = prefix or "设备："
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
    local parts = { prefix .. truncate(model, 24) }
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
        -- -- 修改：v2.4.13 前缀由 getDeviceInfoString 传入，修复"点单设备：设备："双前缀
        ctx.device_line = getDeviceInfoString("点单设备：")
        -- 需求8："时长"改为"总计光临本店"（-- 修改：v2.4.9 时间统一换算为"天"为单位显示）
        ctx.duration_line = "总计光临本店：" .. formatDurationDays(stats.total_seconds)
        -- 需求4："书单"改为"菜单"（-- 修改：v2.4.11 "菜单"→"菜单：5份"，右上角与"总计光临本店"同行右对齐）
        ctx.list_title = "菜单：5份"
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
-- 修改：v2.5.1 由 v2.5.0 的 context 参数改为直接接收调用方已解析的 style。
--       原因：① 调用方（Screensaver.show）必须先解析一次 style 做 is_stat_based 判定，
--       若本函数再自行解析，轮流模式会被推进两次、跳过一半样式（film→menu→inkstain…）；
--       ② v2.5.0 的 context 参数在 Screensaver.show 调用点漏传后静默回退手势语义，
--       导致锁屏固定显示手势样式（实际事故），style 显式传参可消除该歧义。
--       style 为 nil 时回退手势解析并记 dbg 日志（便于溯源调用点漏传）。
-- @param style string|nil 已解析的样式（film/inkstain/menu），nil 回退手势解析
local function buildReceipt(ui, state, on_close_callback, style)
    if style == nil then
        style = getEffectiveStyle()
        logger.dbg(LOG_TAG, "buildReceipt: style 未传参，回退手势样式解析")
    end
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
    -- 修改：v2.5.1 手势样式解析一次后传入 buildReceipt（轮流模式单次推进，与 v2.4.x 手势语义一致）
    local style = getEffectiveStyle()
    local receipt_widget = buildReceipt(self.ui, self.state, function()
        UIManager:close(self)
    end, style)
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
    -- 修改：v2.5.0 锁屏路径统一读取锁屏独立样式（getLockscreenEffectiveStyle），
    --       与手势样式解耦；此处是报告方案容易遗漏的直接调用点，必须同步替换
    local style = getLockscreenEffectiveStyle()
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
    -- 修改：v2.5.1 复用上方 L4405 已解析的锁屏 style 传入 buildReceipt——
    --       修复 v2.5.0 漏传 context 导致锁屏固定走手势样式的缺陷（锁屏"轮流出现"失效），
    --       同时避免轮流模式被 is_stat_based 预检与渲染双重推进跳样式
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
    end, style)

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

            -- 修改：v2.5.0 锁屏样式菜单生成器——读写 book_receipt_lockscreen_* 独立键。
            -- checked_func 需处理"迁移前回退"：锁屏键尚未迁移时按全局状态显示勾选，
            -- 保证用户未触发首次锁屏迁移前，菜单勾选与实际行为一致。
            local function lockscreenStyleMenuItem(text, value)
                return {
                    text = text,
                    checked_func = function()
                        local mode = G_reader_settings:has(K.LOCKSCREEN_MODE_SETTING)
                            and G_reader_settings:readSetting(K.LOCKSCREEN_MODE_SETTING)
                            or getStyleMode()
                        local fixed = G_reader_settings:has(K.LOCKSCREEN_STYLE_SETTING)
                            and G_reader_settings:readSetting(K.LOCKSCREEN_STYLE_SETTING)
                            or G_reader_settings:readSetting(K.STYLE_SETTING)
                        return mode == "fixed" and normalizeReceiptStyle(fixed) == value
                    end,
                    callback = function()
                        G_reader_settings:saveSetting(K.LOCKSCREEN_STYLE_SETTING, value)
                        G_reader_settings:saveSetting(K.LOCKSCREEN_MODE_SETTING, "fixed")
                    end,
                    radio = true,
                }
            end

            local function lockscreenModeMenuItem(text, mode, help_text)
                return {
                    text = text,
                    checked_func = function()
                        if G_reader_settings:has(K.LOCKSCREEN_MODE_SETTING) then
                            return G_reader_settings:readSetting(K.LOCKSCREEN_MODE_SETTING) == mode
                        end
                        return getStyleMode() == mode  -- 迁移前按全局状态回退
                    end,
                    callback = function()
                        G_reader_settings:saveSetting(K.LOCKSCREEN_MODE_SETTING, mode)
                    end,
                    radio = true,
                    help_text = help_text,
                }
            end

            -- 手势调出样式（沿用既有全局键，逻辑零改动；-- 修改：v2.5.0 更名以与锁屏子菜单区分）
            local style_menu = {
                text = _("Gesture style"),
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

            -- 锁屏壁纸样式（独立键，首次锁屏时从旧全局键单向迁移；-- 修改：v2.5.0 新增）
            local lockscreen_style_menu = {
                text = _("Lockscreen style"),
                sub_item_table = {
                    lockscreenStyleMenuItem(_("Film strip (fixed style)"), K.STYLE_FILM),
                    lockscreenStyleMenuItem(_("Ink stain"), K.STYLE_INKSTAIN),
                    lockscreenStyleMenuItem(_("Order Slip"), K.STYLE_MENU),
                    lockscreenModeMenuItem(_("Randomize style each time"), "random",
                        _("When enabled, a random style will be used each time the receipt is shown (instead of the fixed one).")),
                    lockscreenModeMenuItem(_("Alternate style each time"), "alternate",
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
                help_text = _("Gesture and lockscreen styles are configured independently. Ink stain stats period/book list size, poem rotation, content and background are shared between the two."),
                sub_item_table = {
                    -- 修改：v2.5.0 手势与锁屏样式各自独立配置
                    style_menu,
                    lockscreen_style_menu,
                    content_menu,
                    background_menu,
                    inkstain_settings_menu,
                },
            })
        end
    end

    return result
end

-- ========== 测试钩子（仅供沙箱单测使用，生产环境零影响） ==========
-- 修改：v2.5.0 新增。补丁内样式选择/迁移函数均为 local，无法从外部访问；
-- 当且仅当设置 book_receipt_dev_test 为真时（默认不设置，生产永不触发），
-- 将纯逻辑函数引用暴露到 _G._book_receipt_style_test，供 test_book_receipt_style.lua 断言。
if G_reader_settings and G_reader_settings:isTrue("book_receipt_dev_test") then
    _G._book_receipt_style_test = {
        getEffectiveStyle = getEffectiveStyle,
        getLockscreenEffectiveStyle = getLockscreenEffectiveStyle,
        migrateLockscreenStyle = migrateLockscreenStyle,
        normalizeStyleMode = normalizeStyleMode,
        normalizeReceiptStyle = normalizeReceiptStyle,
        getAllStyles = getAllStyles,
        getStyleMode = getStyleMode,
        getAlternateStyleAndAdvance = getAlternateStyleAndAdvance,
    }
    logger.info(LOG_TAG, "已启用样式解耦测试钩子（book_receipt_dev_test）")
end
