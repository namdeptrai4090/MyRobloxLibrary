--[[
    Infinite Spin - Shindo Life (Multi-Bloodline + Webhook + AutoExec)
    Hướng dẫn:
    1. Thay SCRIPT_URL bên dưới bằng link raw script của bạn (GitHub/Pastebin raw).
    2. Upload script này lên raw URL đó.
    3. Chạy script, vào tab Settings nhập Discord Webhook URL.
    4. Vào tab Main, chọn bloodline (hoặc bấm Select All), bật Auto Spin.
--]]

task.wait(20) -- Đợi 20 giây cho game load xong

local SCRIPT_URL = "https://raw.githubusercontent.com/namdeptrai4090/MyRobloxLibrary/refs/heads/main/script.lua" -- THAY BẰNG LINK RAW CỦA BẠN

local Fluent = loadstring(game:HttpGet("https://raw.githubusercontent.com/namdeptrai4090/MyRobloxLibrary/refs/heads/main/Fluent.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/namdeptrai4090/MyRobloxLibrary/refs/heads/main/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/namdeptrai4090/MyRobloxLibrary/refs/heads/main/InterfaceManager.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Infinite Spin - Shindo Life",
    SubTitle = "Auto spin for bloodlines",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Main = Window:AddTab({ Title = "Main", Icon = "" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

local Options = Fluent.Options
local tpsrv = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local Player = game:GetService("Players").LocalPlayer

local elementwanted = {}   -- danh sách bloodline cần tìm (mảng các tên)
local slots = {"kg1", "kg2", "kg3", "kg4"}
local autoSpinEnabled = false

-- File lưu danh sách còn lại
local REMAIN_FILE = "InfiniteSpin/remaining_elements.json"

-- Load danh sách còn lại từ file nếu có
local function LoadRemainingElements()
    if isfile(REMAIN_FILE) then
        local success, decoded = pcall(HttpService.JSONDecode, HttpService, readfile(REMAIN_FILE))
        if success and type(decoded) == "table" then
            return decoded
        end
    end
    return {}
end

-- Lưu danh sách còn lại vào file
local function SaveRemainingElements(list)
    local data = HttpService:JSONEncode(list)
    writefile(REMAIN_FILE, data)
end

-- Hàm lấy danh sách bloodline từ game
local function getElementNames()
    local bossTab = Player.PlayerGui.Main.ingame.Menu.BossTab
    if bossTab then
        local elements = {}
        for _, frame in pairs(bossTab:GetChildren()) do
            if frame:IsA("Frame") and frame.Name then
                table.insert(elements, frame.Name)
            end
        end
        return elements
    end
    return {"boil", "lightning", "fire", "ice", "sand", "crystal", "explosion"} -- fallback
end

-- Gửi webhook
local WebhookInput -- sẽ tạo sau
local function SendWebhook(elementName, spinLeft)
    local url = WebhookInput and WebhookInput.Value or ""
    if url == "" then return end

    local message = {
        content = "**Auto Spin đã ra:** `" .. elementName .. "`\n" ..
                  "**Số spin còn lại:** " .. tostring(spinLeft)
    }
    local body = HttpService:JSONEncode(message)

    -- Thử nhiều cách gửi
    local success = false
    if syn and syn.request then
        local result = syn.request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = body
        })
        success = true
    else
        success = pcall(function()
            HttpService:PostAsync(url, body)
        end)
    end
    if not success then
        warn("Không gửi được webhook")
    end
end

-- Rejoin game, nếu autoexec thì queue script đồng thời set cờ AutoExecEnabled
local function RejoinGame()
    if getgenv().AutoExecEnabled and queue_on_teleport then
        queue_on_teleport("getgenv().AutoExecEnabled = true; loadstring(game:HttpGet('" .. SCRIPT_URL .. "'))()")
    end
    tpsrv:Teleport(game.PlaceId, Player)
end

-- Hàm start auto spin
local function startAutoSpin()
    print("Auto spin started!")

    repeat task.wait() until game:isLoaded()

    local startevent = Player:WaitForChild("startevent", 9e9)
    startevent:FireServer("band", "\128")

    -- Anti AFK
    task.spawn(function()
        local VIM = game:GetService("VirtualInputManager")
        while autoSpinEnabled do
            task.wait(600)
            if not autoSpinEnabled then break end
            local screenSize = game:GetService("Workspace").CurrentCamera.ViewportSize
            VIM:SendMouseButtonEvent(screenSize.X / 2, screenSize.Y / 2, 0, true, game, 0)
            task.wait(0.1)
            VIM:SendMouseButtonEvent(screenSize.X / 2, screenSize.Y / 2, 0, false, game, 0)
        end
    end)

    while autoSpinEnabled do
        task.wait(0.3)

        local statz = Player:FindFirstChild("statz")
        if statz and statz:FindFirstChild("main") then
            local shouldSpin = false

            for _, slot in ipairs(slots) do
                local slotData = statz.main:FindFirstChild(slot)
                if slotData then
                    local currentElement = slotData.Value

                    local isWanted = false
                    for _, element in ipairs(elementwanted) do
                        if currentElement == element then
                            isWanted = true
                            break
                        end
                    end

                    if isWanted then
                        print("Got " .. currentElement .. " in " .. slot .. "!")
                        startevent:FireServer("band", "Eye")  -- lưu kết quả
                        task.wait(1)

                        -- Xóa khỏi danh sách
                        for i, el in ipairs(elementwanted) do
                            if el == currentElement then
                                table.remove(elementwanted, i)
                                break
                            end
                        end
                        SaveRemainingElements(elementwanted)

                        -- Gửi webhook
                        local spinLeft = statz:FindFirstChild("spins") and statz.spins.Value or 0
                        SendWebhook(currentElement, spinLeft)

                        -- Nếu còn phải săn tiếp thì rejoin
                        if #elementwanted > 0 then
                            Fluent:Notify({
                                Title = "Auto Spin",
                                Content = "Đã ra: " .. currentElement .. ". Rejoin để tiếp tục...",
                                Duration = 3
                            })
                            task.wait(2)
                            RejoinGame()
                        else
                            Fluent:Notify({
                                Title = "Auto Spin",
                                Content = "Đã đủ tất cả bloodline! Kick...",
                                Duration = 5
                            })
                            task.wait(2)
                            Player:Kick("Auto Farm Hoàn Tất! Đã lấy đủ tất cả.")
                        end
                        return
                    end

                    shouldSpin = true
                end
            end

            if shouldSpin then
                local spinCount = statz:FindFirstChild("spins")
                if spinCount and spinCount.Value <= 1 then
                    print("Low spins detected, teleporting...")
                    RejoinGame()
                    return
                end

                for _, slot in ipairs(slots) do
                    startevent:FireServer("spin", slot)
                end
            end
        end
        -- Nếu statz chưa sẵn sàng, vòng lặp tiếp tục chờ
    end
    print("Auto spin stopped!")
end

local function stopAutoSpin()
    autoSpinEnabled = false
    getgenv().atspn = false
    print("Auto spin disabled")
end

-- Khởi tạo UI
do
    local availableElements = getElementNames()

    -- Load danh sách còn lại từ file (nếu có) để mặc định tick
    local savedRemaining = LoadRemainingElements()
    local defaultSelection = {}
    for _, name in ipairs(savedRemaining) do
        defaultSelection[name] = true
    end

    local ElementDropdown = Tabs.Main:AddDropdown("ElementDropdown", {
        Title = "Select Bloodlines",
        Description = "Choose which bloodlines to auto-spin for",
        Values = availableElements,
        Multi = true,
        Default = defaultSelection,
    })

    ElementDropdown:OnChanged(function(Value)
        elementwanted = {}
        for element, state in next, Value do
            if state then
                table.insert(elementwanted, element)
            end
        end
        -- Lưu danh sách cần tìm vào file mỗi khi thay đổi
        SaveRemainingElements(elementwanted)
        print("Selected elements:", table.concat(elementwanted, ", "))
    end)

    -- Kích hoạt OnChanged ban đầu nếu có default
    if next(defaultSelection) ~= nil then
        ElementDropdown:SetValue(defaultSelection)
    end

    -- Nút Select All
    Tabs.Main:AddButton({
        Title = "Select All Bloodlines",
        Description = "Tick chọn tất cả bloodline",
        Callback = function()
            local allValues = {}
            for _, name in ipairs(availableElements) do
                allValues[name] = true
            end
            ElementDropdown:SetValue(allValues)
        end
    })

    local SlotDropdown = Tabs.Main:AddDropdown("SlotDropdown", {
        Title = "Select Slots",
        Description = "Choose which slots to spin",
        Values = slots,
        Multi = true,
        Default = {"kg1", "kg2"},
    })

    SlotDropdown:OnChanged(function(Value)
        slots = {}
        for slot, state in next, Value do
            if state and type(slot) == "string" and string.match(slot, "kg") then
                table.insert(slots, slot)
            end
        end
        print("Selected slots:", table.concat(slots, ", "))
    end)

    -- Đồng bộ slots sau khi tạo
    slots = {"kg1", "kg2"}  -- đúng với Default

    local isUpdatingToggle = false  -- cờ chặn vòng lặp OnChanged

    local AutoSpinToggle = Tabs.Main:AddToggle("AutoSpinToggle", {
        Title = "Auto Spin",
        Description = "Automatically spin for selected bloodlines",
        Default = false
    })

    AutoSpinToggle:OnChanged(function()
        if isUpdatingToggle then return end  -- đang tự sửa giá trị, bỏ qua

        if Options.AutoSpinToggle.Value then
            -- Kiểm tra đã chọn bloodline chưa
            if #elementwanted == 0 then
                Fluent:Notify({
                    Title = "Auto Spin",
                    Content = "⚠️ Bạn chưa chọn bloodline nào! Hãy chọn ít nhất 1 bloodline trước khi bật.",
                    Duration = 5
                })
                isUpdatingToggle = true
                AutoSpinToggle:SetValue(false)
                isUpdatingToggle = false
                return
            end

            -- Đã có bloodline → bật auto spin
            autoSpinEnabled = true
            getgenv().atspn = true
            Fluent:Notify({
                Title = "Auto Spin",
                Content = "Started auto spinning for selected bloodlines",
                Duration = 3
            })
            task.spawn(startAutoSpin)
        else
            stopAutoSpin()
            Fluent:Notify({
                Title = "Auto Spin",
                Content = "Stopped auto spinning",
                Duration = 3
            })
        end
    end)

    Tabs.Main:AddButton({
        Title = "Manual Spin",
        Description = "Spin once manually",
        Callback = function()
            if Player:FindFirstChild("startevent") then
                for _, slot in ipairs(slots) do
                    Player.startevent:FireServer("spin", slot)
                end
                Fluent:Notify({ Title = "Manual Spin", Content = "Spun all selected slots", Duration = 2 })
            else
                Fluent:Notify({ Title = "Error", Content = "Game not loaded yet", Duration = 3 })
            end
        end
    })

    Tabs.Main:AddButton({
        Title = "Save Stats",
        Description = "Save your current stats and progress",
        Callback = function()
            if Player:FindFirstChild("startevent") then
                Player.startevent:FireServer("band", "Eye")
                Fluent:Notify({ Title = "Stats Saved", Content = "Your current stats have been saved!", Duration = 3 })
            else
                Fluent:Notify({ Title = "Error", Content = "Game not loaded yet", Duration = 3 })
            end
        end
    })

    Tabs.Main:AddButton({
        Title = "Refresh Elements",
        Description = "Refresh the list of available bloodlines",
        Callback = function()
            local newElements = getElementNames()
            availableElements = newElements  -- cập nhật biến local để Select All dùng sau này
            ElementDropdown:SetValues(newElements)
            Fluent:Notify({ Title = "Refresh", Content = "Updated bloodline list", Duration = 2 })
        end
    })

    Tabs.Main:AddParagraph({
        Title = "Status",
        Content = "Chọn bloodline, bật Auto Spin. Khi ra 1 con, script lưu, xóa khỏi danh sách, rejoin tiếp tục."
    })
end

-- Settings
SaveManager:SetLibrary(Fluent)
InterfaceManager:SetLibrary(Fluent)
SaveManager:IgnoreThemeSettings()
InterfaceManager:SetFolder("InfiniteSpin")
SaveManager:SetFolder("InfiniteSpin/shindo-life")

InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- Webhook Input
WebhookInput = Tabs.Settings:AddInput("WebhookInput", {
    Title = "Discord Webhook URL",
    Description = "Nhập link webhook để nhận thông báo",
    Default = "",
})

-- AutoExec Toggle
local AutoExecToggle = Tabs.Settings:AddToggle("AutoExecToggle", {
    Title = "Auto Exec on Rejoin",
    Description = "Tự động chạy lại script sau khi rejoin (yêu cầu executor hỗ trợ queue_on_teleport)",
    Default = getgenv().AutoExecEnabled or false
})

AutoExecToggle:OnChanged(function()
    getgenv().AutoExecEnabled = AutoExecToggle.Value
    if AutoExecToggle.Value then
        Fluent:Notify({ Title = "AutoExec", Content = "Đã bật tự động chạy lại script", Duration = 3 })
    else
        Fluent:Notify({ Title = "AutoExec", Content = "Đã tắt tự động chạy lại script", Duration = 3 })
    end
end)

-- Auto Hide Toggle
local AutoHideToggle = Tabs.Settings:AddToggle("AutoHideToggle", {
    Title = "Auto Hide on Start",
    Description = "Automatically minimize the hub when script loads",
    Default = false
})

Window:SelectTab(1)

Fluent:Notify({
    Title = "Infinite Spin",
    Content = "Script loaded successfully! Chọn bloodline và bật spin.",
    Duration = 5
})

SaveManager:LoadAutoloadConfig()

if Options.AutoHideToggle and Options.AutoHideToggle.Value then
    task.wait(1)
    Window:Minimize()
end
