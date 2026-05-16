--[[
    ПАРАД ЖЕРТВ (ФИКСИРОВАННЫЙ)
    - Выстраивает всех игроков в ряд
    - ФИКСИРУЕТ их на этих координатах
    
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

-- Настройки
local paradeActive = false
local paradeConnection = nil
local paradePlayers = {} -- Таблица с игроками и их ЗАФИКСИРОВАННЫМИ позициями

-- Параметры построения
local ROW_DISTANCE = 4 -- Дистанция между игроками
local FRONT_DISTANCE = 5 -- Дистанция перед тобой В МОМЕНТ ПОСТРОЕНИЯ

-- Ждем загрузку
repeat task.wait() until LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")

-- Создаем GUI
local function createGUI()
    local oldGui = LocalPlayer.PlayerGui:FindFirstChild("FixedParade")
    if oldGui then oldGui:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FixedParade"
    gui.Parent = LocalPlayer.PlayerGui
    gui.ResetOnSpawn = false

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 250, 0, 180)
    frame.Position = UDim2.new(0.5, -125, 0.5, -90)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(255, 100, 100)
    frame.Active = true
    frame.Draggable = true
    frame.Parent = gui

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 25)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    title.Text = "ПАРАД (ФИКСИРОВАННЫЙ)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextScaled = true
    title.Parent = frame

    local infoLabel = Instance.new("TextLabel")
    infoLabel.Size = UDim2.new(0.9, 0, 0, 20)
    infoLabel.Position = UDim2.new(0.05, 0, 0.15, 0)
    infoLabel.BackgroundTransparency = 1
    infoLabel.Text = "Игроков: 0"
    infoLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    infoLabel.TextScaled = true
    infoLabel.Parent = frame

    local paradeBtn = Instance.new("TextButton")
    paradeBtn.Size = UDim2.new(0.9, 0, 0, 30)
    paradeBtn.Position = UDim2.new(0.05, 0, 0.3, 0)
    paradeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    paradeBtn.Text = "ПОСТРОИТЬ (ФИКСИРОВАТЬ)"
    paradeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    paradeBtn.TextScaled = true
    paradeBtn.Parent = frame

    local stopBtn = Instance.new("TextButton")
    stopBtn.Size = UDim2.new(0.9, 0, 0, 30)
    stopBtn.Position = UDim2.new(0.05, 0, 0.5, 0)
    stopBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
    stopBtn.Text = "ОТПУСТИТЬ ВСЕХ"
    stopBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    stopBtn.TextScaled = true
    stopBtn.Parent = frame

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(0.9, 0, 0, 20)
    status.Position = UDim2.new(0.05, 0, 0.7, 0)
    status.BackgroundTransparency = 1
    status.Text = "Готов"
    status.TextColor3 = Color3.fromRGB(150, 255, 150)
    status.TextScaled = true
    status.Parent = frame

    local hotkeys = Instance.new("TextLabel")
    hotkeys.Size = UDim2.new(0.9, 0, 0, 30)
    hotkeys.Position = UDim2.new(0.05, 0, 0.8, 0)
    hotkeys.BackgroundTransparency = 1
    hotkeys.Text = "P - парад | O - отпустить"
    hotkeys.TextColor3 = Color3.fromRGB(200, 200, 200)
    hotkeys.TextScaled = true
    hotkeys.Parent = frame

    return {
        gui = gui,
        infoLabel = infoLabel,
        paradeBtn = paradeBtn,
        stopBtn = stopBtn,
        status = status
    }
end

local gui = createGUI()

local function setStatus(text, isError)
    gui.status.Text = text
    gui.status.TextColor3 = isError and Color3.fromRGB(255, 100, 100) or Color3.fromRGB(150, 255, 150)
end

local function updatePlayerCount()
    local count = #Players:GetPlayers() - 1
    gui.infoLabel.Text = "Игроков: " .. count
end

-- Функция получения позиции в ряду (В МОМЕНТ ПОСТРОЕНИЯ)
local function getParadePosition(index, totalCount, myPosition, myLookVector)
    -- Вектор вправо
    local rightVector = Vector3.new(-myLookVector.Z, 0, myLookVector.X).Unit
    
    -- Вычисляем стартовый оффсет
    local startOffset = -((totalCount - 1) * ROW_DISTANCE / 2)
    
    -- Позиция в ряду
    local rowOffset = rightVector * (startOffset + (index * ROW_DISTANCE))
    
    return myPosition + (myLookVector * FRONT_DISTANCE) + rowOffset
end

-- Функция остановки парада
local function stopParade()
    paradeActive = false
    if paradeConnection then
        paradeConnection:Disconnect()
        paradeConnection = nil
    end
    
    -- Размораживаем всех
    for _, data in pairs(paradePlayers) do
        if data.player and data.player.Character then
            local humanoid = data.player.Character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.PlatformStand = false
                humanoid.AutoRotate = true
                humanoid.WalkSpeed = 16
            end
        end
    end
    
    paradePlayers = {}
    setStatus("Парад остановлен")
    gui.paradeBtn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
end

-- Функция запуска парада (ФИКСИРОВАННОГО)
local function startParade()
    if not LocalPlayer.Character then
        setStatus("У тебя нет персонажа", true)
        return
    end
    
    local myRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then
        setStatus("Нет RootPart", true)
        return
    end
    
    -- ЗАПОМИНАЕМ позицию и направление В МОМЕНТ НАЖАТИЯ
    local fixedPosition = myRoot.Position
    local fixedLookVector = myRoot.CFrame.LookVector
    
    -- Собираем всех игроков
    local players = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            table.insert(players, p)
        end
    end
    
    if #players == 0 then
        setStatus("Нет других игроков", true)
        return
    end
    
    -- Останавливаем предыдущий парад
    stopParade()
    
    setStatus("Строим " .. #players .. " игроков...")
    gui.paradeBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    
    -- Телепортируем всех на свои места и ЗАПОМИНАЕМ координаты
    for i, player in ipairs(players) do
        if player.Character then
            local targetRoot = player.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                -- Вычисляем позицию в ряду ИСПОЛЬЗУЯ ЗАПОМНЕННЫЕ координаты
                local paradePos = getParadePosition(i - 1, #players, fixedPosition, fixedLookVector)
                
                -- Телепортируем
                targetRoot.CFrame = CFrame.new(paradePos)
                targetRoot.CFrame = CFrame.lookAt(paradePos, fixedPosition) -- Смотрят на точку где я стоял
                
                -- Отключаем их движение
                local humanoid = player.Character:FindFirstChild("Humanoid")
                if humanoid then
                    humanoid.PlatformStand = true
                    humanoid.AutoRotate = false
                    humanoid.WalkSpeed = 0
                end
                
                -- Сохраняем ЗАФИКСИРОВАННУЮ позицию
                paradePlayers[player] = {
                    player = player,
                    position = paradePos, -- Это место где они должны стоять ВСЕГДА
                    lookAt = fixedPosition -- Куда смотреть (где я был)
                }
                
                task.wait(0.1)
            end
        end
    end
    
    paradeActive = true
    
    -- ГЛАВНЫЙ ЦИКЛ УДЕРЖАНИЯ (возвращает на ЗАФИКСИРОВАННЫЕ места)
    if paradeConnection then paradeConnection:Disconnect() end
    
    paradeConnection = RunService.Heartbeat:Connect(function()
        if not paradeActive then return end
        
        -- Удерживаем каждого игрока на его ЗАФИКСИРОВАННОМ месте
        for player, data in pairs(paradePlayers) do
            if player and player.Character then
                local root = player.Character:FindFirstChild("HumanoidRootPart")
                if root then
                    -- ЖЕСТКО возвращаем на ЗАПОМНЕННУЮ позицию
                    root.CFrame = CFrame.new(data.position)
                    root.CFrame = CFrame.lookAt(data.position, data.lookAt)
                    
                    -- Обнуляем скорость
                    root.Velocity = Vector3.new(0, 0, 0)
                    root.RotVelocity = Vector3.new(0, 0, 0)
                    
                    -- Постоянно держим PlatformStand
                    local humanoid = player.Character:FindFirstChild("Humanoid")
                    if humanoid then
                        humanoid.PlatformStand = true
                    end
                else
                    paradePlayers[player] = nil
                end
            else
                paradePlayers[player] = nil
            end
        end
    end)
    
    setStatus("✅ Парад зафиксирован! Они НЕ двигаются за тобой")
end

-- Кнопки
gui.paradeBtn.MouseButton1Click:Connect(startParade)
gui.stopBtn.MouseButton1Click:Connect(stopParade)

-- Горячие клавиши
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    
    if input.KeyCode == Enum.KeyCode.P then
        startParade()
    elseif input.KeyCode == Enum.KeyCode.O then
        stopParade()
    end
end)

-- Обновление счетчика
Players.PlayerAdded:Connect(updatePlayerCount)
Players.PlayerRemoving:Connect(function(player)
    updatePlayerCount()
    if paradePlayers[player] then
        paradePlayers[player] = nil
    end
end)
updatePlayerCount()

print("=== ФИКСИРОВАННЫЙ ПАРАД ===")
print("P - построить (фиксируются)")
print("O - отпустить всех")
print("Ты можешь уходить - они стоят")
print("============================")