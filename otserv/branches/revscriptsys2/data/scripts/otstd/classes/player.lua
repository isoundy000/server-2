
otstd.Player = {}

-- Easier message passing

function Player:sendNote(msg)
	self:sendMessage(MSG_STATUS_CONSOLE_BLUE, msg)
end

function Player:sendWarning(msg)
	self:sendMessage(MSG_STATUS_CONSOLE_RED, msg)
end

function Player:sendInfo(msg)
	self:sendMessage(MSG_INFO_DESCR, msg)
end

function Player:sendCancel(msg)
	self:sendMessage(MSG_STATUS_SMALL, msg)
end

function Player:sendAdvance(msg)
	self:sendMessage(MSG_EVENT_ADVANCE, msg)
end

function Player:pickup(item)
	assert(typeof(item, "Item"))
	
	local parent = item:getParent()
	if not parent or not typeof(parent, "Tile") then
		return false
	end

	local itemPos = item:getPosition()
	local playerPos = self:getPosition()
	
	if(math.abs(itemPos.x - self:getPosition().x) <= 1 and
		  math.abs(itemPos.y - self:getPosition().y) <= 1 and
		  itemPos.z == self:getPosition().z) then
		  return self:internalPickup(item)
	end

	return false
end

function Player:walkTo(to)
	local function isAt(pos)
		return (pos.x == self:getPosition().x and
				pos.y == self:getPosition().y and
				pos.z == self:getPosition().z)
	end

	if isAt(to) then
		return true
	end
	
	if not self:internalWalkTo(to) then
		return false
	end
	
	local start = self:getPosition()
	
	while not isAt(to) do

		if not #self then
			return false
		end

		wait(500)
		
		if not isAt(start) and not self:isAutoWalking() then
			return isAt(to)
		end
	end

	return true
end

-- Fetch some data about the player

function Player:getTimeSinceLogin()
	return os.difftime(os.time(), self:getLastLogin())
end

function Player:getPlayTime()
	local t = self:getStorageValue("__playtime") or 0
	return t + self:getTimeSinceLogin()
end

function Player:isFemale()
	return self:getSex() == FEMALE
end

function Player:isMale()
	return self:getSex() == MALE
end

-- 

function Player:getTown()
	return map:getTown(self:getTownID())
end

--

function Player:addMana(howmuch)
	r = true
	if howmuch < 0 then
		r = self:getMana() < howmuch
	end
	self:setMana(math.max(0, self:getMana() + howmuch))
	return r
end
function Player:removeMana(howmuch) return self:addMana(-howmuch) end

function Player:spendMana(howmuch)
	self:removeMana(howmuch)
	self:addManaSpent(howmuch)
end

--

function Player:addItemOfType(itemid, subtype, count, itemModFunc)
	local item_type = Items[itemid]
	if not item_type then
		error "Attempting to add item of invalid type!"
	end
	
	if (not item_type.hasSpecialType) and subtype and not count then
		count = subtype
	end
	
	if not count then
		count = 1
	end
	if not subtype then
		subtype = 0
	end
	
	if item_type.stackable then
		while count > 0 do
			local item = createItem(itemid, count)
			if itemModFunc then
				itemModFunc(item)
			end
			count = count - 100
			self:addItem(item)
		end
	else
		for i = 1, count do
			local item = createItem(itemid, subtype)
			if itemModFunc then
				itemModFunc(item)
			end
			self:addItem(item)
		end
	end
end

function Player:hasMoney(howmuch)
	return self:countMoney() >= howmuch
end

-- Return contents of both hands
function Player:getHandContents()
	local hands = {}
	local left = self:getInventoryItem(SLOT_LEFT)
	local right = self:getInventoryItem(SLOT_RIGHT)
	if left then table.append(hands, left) end
	if right then table.append(hands, right) end
	return hands
end

-- Bank functions

function Player:getBalance()
	return self:getStorageValue("__balance")
end

function Player:hasBalance(amount)
	return getBalance() >= amount
end

-- Modify contents, does not take 
function Player:setBalance(amount)
	return self:setStorageValue("__balance", amount)
end

function Player:addBalance(amount)
	if amount < 0 then
		return self:removeBalance(amount)
	end
	self:setBalance(self:getBalance() + amount)
	return true
end

function Player:removeBalance(amount)
	if amount < 0 then
		return self:addBalance(amount)
	end
	if self:getBalance() < amount then
		return false
	end
	self:setBalance(self:getBalance() - amount)
end

-- These adds / removes money from the Player
function Player:depositMoney(amount)
	if self:removeMoney(amount) then
		return self:setBalance(self:getBalance() + amount)
	end

	return false
end

function Player:withdrawMoney(amount)
	if self:getBalance() < amount then
		return false
	end

	if self:addMoney(amount) then
		return self:setBalance(self:getBalance() - amount)
	end

	return false
end

-- Flags

function Player:hasInfiniteMana()
	return self:hasGroupFlag(PlayerFlag_HasInfiniteMana)
end

function Player:canUseSpells()
	return not self:hasGroupFlag(PlayerFlag_CannotUseSpells)
end

function Player:ignoreSpellCheck()
	return self:hasGroupFlag(PlayerFlag_IgnoreSpellCheck)
end

function Player:ignoreWeaponCheck()
	return self:hasGroupFlag(PlayerFlag_IgnoreWeaponCheck)
end

function Player:isInvulnerable()
	return self:hasGroupFlag(PlayerFlag_CannotBeAttacked)
end


-- Login / Logout
function otstd.Player.LoginHandler(event)
	local player = event.player
	
	-- Load outfits
	if player.loadOutfits then
		-- Defined in outfits.lua
		player:loadOutfits()
	end
end

function otstd.Player.LogoutHandler(event)
	local player = event.player
	-- This will fook up if a listener aborts the logout! :(
	player:setStorageValue("__lastlogout", os.time())
	
	-- Save playtime
	player:setStorageValue("__playtime", player:getPlayTime())
	
	-- Save outfits
	if player.saveOutfits then
		-- Defined in outfits.lua
		player:saveOutfits()
	end
end

otstd.Player.onLoginListener  = registerOnLogin(otstd.Player.LoginHandler)
otstd.Player.onLogoutListener = registerOnLogout(otstd.Player.LogoutHandler)

-- Advance handlers

function otstd.Player.AdvanceHandler(event)
	local player = event.player
	local message = ""
	
	if event.skill == LEVEL_FIST then
		message = "You advanced in fist fighting."
	elseif event.skill == LEVEL_CLUB then
		message = "You advanced in club fighting."
	elseif event.skill == LEVEL_SWORD then
		message = "You advanced in sword fighting."
	elseif event.skill == LEVEL_AXE then
		message = "You advanced in axe fighting."
	elseif event.skill == LEVEL_DIST then
		message = "You advanced in dist fighting."
	elseif event.skill == LEVEL_SHIELD then
		message = "You advanced in shield fighting."
	elseif event.skill == LEVEL_FISHING then
		message = "You advanced in fishing fighting."
	elseif event.skill == LEVEL_MAGIC then
		message = "You advanced to magic level " .. event.newLevel .. "."
	elseif event.skill == LEVEL_EXPERIENCE then
		message = "You advanced from Level " .. event.oldLevel .. " to Level " .. event.newLevel .. "."
	else
		message = "You advanced, but not in any skill?"
	end
	
	player:sendAdvance(message)
end

otstd.Player.onAdvanceListener = registerOnAdvance(otstd.Player.AdvanceHandler)
