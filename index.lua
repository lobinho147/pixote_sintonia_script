--// Serviços
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

--// Variáveis e tabelas
local keys, deviceKeys = {}, {}
local tempoExpira = {diaria = 86400, semanal = 604800, permanente = math.huge}
local espTags = {}
local hitboxExpandidaAtiva, hitboxScaleValue, hitboxOriginalSizes = false, 5, {}
local aimbotPC, aimbotMobile, aimbotLocked = false, false, false
local aimFOV = 100
local puxarItensToggle, revistarToggle = false, false
local teleportAutoAtivo, teleportou, noclip = false, false, false
local autoFarmGari, autoFarmMineracao, autoFarmFazenda, autoFarmPecas, autoFarmGas = false, false, false, false, false
local autoClick, injetarFarms = false, false
local SavedPosition = nil
local isMinimized = false
local autoKickHealth = 10
local antiStaffEnabled = false
local detectados = {}
local ultimoMortoPorVoce = nil

local itens = {
    "AK47","Uzi","Fuzil","Glock","IA2","G3","Dinamite","Hi Power",
    "Natalina","HK416","Lockpick","Escudo","Skate","Saco de lixo","Peça de Arma",
    "Tratamento","AR-15","PS5","C4","USP"
}

--// Keys Setup
for i = 1, 1000 do
    keys["dailykey"..i] = {tipo = "diaria", criada = os.time(), deviceId = nil}
    keys["weeklykey"..i] = {tipo = "semanal", criada = os.time(), deviceId = nil}
    keys["permkey"..i] = {tipo = "permanente", criada = os.time(), deviceId = nil}
end

--// Painel: donos, admins e banidos
local donos = {8239853870, 87654321} -- UserIds donos
local admins = {9077646480, 98765432} -- UserIds admins
local banidos = {} -- UserIds banidos do painel

--// Função webhook logs
local webhookURL = "https://discord.com/api/webhooks/1431115296625786950/FVY8U-wI1hWV48VK1K5Lp05f_pr2hBsaIU7jWizTSYeWq4ZG5ETa_cyMBdgTQUMsyRU7"
local function enviarLog(msg)
    if webhookURL == "" then return end
    task.spawn(function()
        local data = {
            ["content"] = msg
        }
        HttpService:PostAsync(webhookURL, HttpService:JSONEncode(data))
    end)
end

--// Função de notificação
local function notificar(titulo, mensagem, duracao)
    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name = "NotifyGui"
    
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 250, 0, 90)
    frame.Position = UDim2.new(0.5, -125, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(0, 50, 100)
    frame.BorderSizePixel = 0
    local uicorner = Instance.new("UICorner", frame)
    uicorner.CornerRadius = UDim.new(0, 6)

    local titleLabel = Instance.new("TextLabel", frame)
    titleLabel.Size = UDim2.new(1, 0, 0, 20)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = titulo
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 14

    local messageLabel = Instance.new("TextLabel", frame)
    messageLabel.Size = UDim2.new(1, 0, 0, 60)
    messageLabel.Position = UDim2.new(0, 0, 0, 20)
    messageLabel.BackgroundTransparency = 1
    messageLabel.Text = mensagem
    messageLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    messageLabel.Font = Enum.Font.Gotham
    messageLabel.TextSize = 12
    messageLabel.TextWrapped = true

    task.delay(duracao, function() gui:Destroy() end)
end

--// Permissões
local function temPermissao(userId, tipo)
    if banidos[userId] then return false end
    if tipo == "dono" then
        return table.find(donos, userId) ~= nil
    elseif tipo == "admin" then
        return table.find(donos, userId) ~= nil or table.find(admins, userId) ~= nil
    end
    return false
end

--// Gerar Key
local function gerarKey(userId, tipo)
    if not temPermissao(userId, "admin") then
        notificar("Painel", "Você não pode gerar keys!", 3)
        return
    end
    local key = HttpService:GenerateGUID(false):gsub("-", ""):upper()
    keys[key] = {tipo = tipo, criada = os.time(), deviceId = nil}
    enviarLog("UserId "..userId.." gerou key: "..key.." Tipo: "..tipo)
    return key
end

--// Banir usuário
local function banirUsuario(userId, motivo, executorId)
    if not temPermissao(executorId, "dono") then
        notificar("Painel","Você não pode banir usuários!",3)
        return
    end
    banidos[userId] = {motivo = motivo, por = executorId, hora = os.time()}
    enviarLog("UserId "..userId.." foi banido do painel pelo UserId "..executorId.." Motivo: "..motivo)
    notificar("Painel","Usuário banido com sucesso!",3)
end

--// Validar key
local function validarKey(inputKey, userId)
    if banidos[userId] then
        return false,"❌ Você está banido do painel!"
    end
    local data = keys[inputKey]
    if not data then return false,"❌ Key inválida!" end
    if data.deviceId and data.deviceId ~= tostring(userId) then
        return false,"❌ Key já usada em outro dispositivo!"
    end
    local agora = os.time()
    if (agora - data.criada) > tempoExpira[data.tipo] then
        return false,"⏳ Key expirada ("..data.tipo..")"
    end
    if not data.deviceId then
        data.deviceId = tostring(userId)
        deviceKeys[userId] = inputKey
        enviarLog(LocalPlayer.Name.." resgatou key: "..inputKey.." UserId: "..userId)
    end
    notificar("Painel","✅ Key resgatada! Comandos !gate, !staff, !civil liberados!", 4)
    return true,"✅ Key resgatada! Comandos liberados!"
end

--// Comandos para trocar de equipe
local Teams = game:GetService("Teams")
game.Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(msg)
		if deviceKeys[player.UserId] then
			if msg:lower() == "!gate" then
				player.Team = Teams:WaitForChild("Gate")
			elseif msg:lower() == "!staff" then
				player.Team = Teams:WaitForChild("Staff")
			elseif msg:lower() == "!civil" then
				player.Team = Teams:WaitForChild("Civil")
			end
		else
			notificar("Painel","Você precisa resgatar uma key para usar comandos!",3)
		end
	end)
end)

--// Funções extras (Velocidade, FOV, ESP)
local cheatConfig = {
    velocidade = 16, -- padrão
    fov = 100,
    tamanhoESP = 5,
    viewNick = true
}

--// A aba do painel GUI deve permitir:
-- Resgatar key
-- Configurar cheat (velocidade, FOV, ESP, view)
-- Logs / Histórico via webhook
-- Gerenciar usuários (donos/admins, banir)
