pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

--------------------------------------------------------------------------------
actor={x=0, y=0, width=8, height=8, grav=0, spd=0, max_spd=2, acc=0, dcc=1}

function actor:new(a)
	self.__index=self
	return setmetatable(a or {}, self)
end

function actor:update()

end

function actor:draw()
	if self.s then
		spr(self.s, self.x, self.y, 1, 1, self.f)
	end
	if draw_bounding_boxes then
		rect(self.x,self.y, self.x+self.width-1, self.y+self.height-1,7)
	end
	if self.slaves then
		for s in all(self.slaves) do
			s:draw()
		end
	end
end

function actor:on_ground()
	return is_solid(self.x, self.y+self.height+1)
		or is_solid(self.x+self.width, self.y+self.height+1)
end

function actor:clip_above_block()
	local feet_y = self.y+self.height
	feet_y = flr(feet_y/8)*8
	self.y=feet_y-self.height
end

function actor:clip_below_block()
	self.y = flr(self.y/8)*8+8
end

function actor:gravity()
	self.y+=self.grav
	if self.grav>terminal_velocity then
		self.grav = terminal_velocity
	end
	self.grav+=grav_acc
	if self:is_in_wall() then
		if self.grav>0 then
			self:clip_above_block()
		else
			self:clip_below_block()
		end
		self.grav = self.grav * -0.2
		if abs(self.grav)<1 then
			self.grav = 0
		end
	end
end

function actor:is_in_wall(part)
	xs = {}
	for i=self.x, self.x+self.width-1, 8 do
		add(xs, i)
	end
	add(xs, self.x+self.width-1)
	ys = {}
	for i=self.y, self.y+self.height-1, 8 do
		add(ys, i)
	end
	add(ys, self.y+self.height-1)

	if part == "ceil" then
		ys = {self.y}
	elseif part == "floor" then
		ys = {self.y+self.height-1}
	end

	for i in all(xs) do
		for j in all(ys) do
			if is_solid(i, j) then
				return true
			end
		end
		if is_solid(i, self.y+self.height-1) then
			return true
		end
	end
	return false
end

function actor:momentum()
	--accelerate
	self.spd+=self.acc
	--decelerate
	self.spd=move_towards(0, self.spd, self.dcc)
	if self.spd>self.max_spd then
		self.spd=self.max_spd
	elseif self.spd<-self.max_spd then
		self.spd=-self.max_spd
	end
	self.x+=self.spd
	--when this moves us into a wall:
	if self:is_in_wall() then
		--position exactly on pixel.
		self.x=flr(self.x)
		--move out of the wall.
		while self:is_in_wall() do
			if self.spd>0 then
				self.x-=1
			else
				self.x+=1
			end
		end
		self.spd=0
	end
end

function actor:use_slaves()
	self.slaves = {}
end

function actor:update_slaves()
	if not self.slaves then return end
	for s in all(self.slaves) do
		s:update()
	end
end

function actor:add_slave(a)
	if not self.slaves then return end
	add(self.slaves, a)
	a.master = self
end

function actor:goto_master()
	if not self.master then return end
	self.x = self.master.x
	self.y = self.master.y
end

--------------------------------------------------------------------------------

cam = actor:new({speed=2})

function cam:update()
	if not player.stairs then
		self.goal_x = player.x-60
	end
	self.x = move_towards(self.goal_x, self.x, self.speed)
	if self.x<=0 then
		self.x=0
	end
end

function cam:set_position()
	camera(self.x, self.y)
end

--------------------------------------------------------------------------------

player = actor:new({s=0, height=14, dcc=0.5, max_spd=1, animation = 0, stairs = false, stair_timer=0, stair_dir = false, ducking = false})

function player:update()
	--movement inputs
	if not self.stairs then
		if btn(3) and (self:on_ground() or self.ducking) then
			if not self.ducking then
				self.y+=2
			end
			self.ducking = true
			-- self.spd=0
			self.acc=0
		else
			self.ducking = false
			if btn(1) and not btn(0) then
				self.acc=1
				self.f = false
			elseif btn(0) and not btn(1) then
				self.acc=-1
				self.f = true
			else
				self.acc=0
			end
		end

		if self.ducking then
			self.height=12
		else
			self.height=14
			if self:is_in_wall() then
				self.y-=2
			end
			if self:on_ground() and btnp(4) then
				self.grav=-player_jump_height
			end
		end
		self:momentum()
		self:gravity()
		if abs(self.spd)<0.1 then
			self.animation = 1.9
		end
		if self:on_ground() and btn(2) then
			self:mount_stairs_up()
		elseif self:on_ground() and btn(3) then
			self:mount_stairs_down()
		end
	end
	if self.stairs then
		self.ducking = false
		self.spd=0
		if btn(2) and not btn(3) then
			self.stair_timer+=1
			self.f = self.stair_dir
		elseif btn(3) and not btn(2) then
			self.stair_timer-=1
			self.f = not self.stair_dir
		end
		if self.stair_timer>=6 then
			self.stair_timer=0
			self.y-=2
			if self.f then
				self.x-=2
			else
				self.x+=2
			end
			self.animation+=1
		elseif self.stair_timer<=-6 then
			self.stair_timer=0
			self.y+=2
			if self.f then
				self.x-=2
			else
				self.x+=2
			end
			self.animation+=1
		end
		self:dismount_stairs()
	end
	if self:on_ground() then
		self.animation += abs(self.spd)/10
	end
	self.animation = self.animation%4
	self.s = flr(self.animation)
	if self.s == 3 then
		self.s = 1
	end

	self:update_slaves()
end

function player:mount_stairs_down()
	local pos_x=self.x+6
	if self.f then
		pos_x-=4
	end
	local pos_y=self.y+16
	local is_stairs = get_flag_at(pos_x, pos_y, 1)
	local facing_left = get_flag_at(pos_x, pos_y, 2)
	if is_stairs then
		self.stairs = true
		self.x = flr(pos_x/8)*8+2
		if facing_left then
			self.x-=4
		end
		self.y = flr(pos_y/8)*8-14
		self.animation = 1
		self.stair_dir = facing_left
		self.f = not facing_left
		self.stair_timer=-10
	end
end

function player:mount_stairs_up()
	local pos_x = self.x+10
	if self.f then
		pos_x = self.x-2
	end
	local pos_y = self.y+8
	local is_stairs = get_flag_at(pos_x, pos_y, 1)
	local facing_left = get_flag_at(pos_x, pos_y, 2)
	if is_stairs and ((facing_left and pos_x%8>=4) or (not facing_left and pos_x%8<4)) then
		self.stairs = true
		self.x = flr(pos_x/8)*8
		self.y = flr(pos_y/8)*8-6
		if facing_left then
			self.x+=6
		else
			self.x-=6
		end
		self.animation = 1
		self.stair_dir = facing_left
		self.f = facing_left
		self.stair_timer=10
	end
end

function player:dismount_stairs()
	if self.y%8 != 2 then return end
	local pos_x, pos_y = self.x+4, self.y+8
	if self.stair_dir == self.f then
		if not self.stair_dir then
			pos_x+=8
		else
			pos_x-=8
		end
	else
		pos_y+=8
	end
	if not get_flag_at(pos_x, pos_y, 1) then
		self.stairs = false
	end
end

player_legs = actor:new({s=16, height=0})

function player_legs:update()
	self:goto_master()
	self.y+=8
	self.f = self.master.f
	self.s = 16 + self.master.s%2
	if self.s == 16 and self.master.stairs then
		self.s +=2
		if self.master.f != self.master.stair_dir then
			self.s +=1
		end
	end
	if not self.master:on_ground() and not self.master.stairs or self.master.ducking then
		self.s = 20
	end
end

--------------------------------------------------------------------------------

function _init()
	actors = {}

	player:use_slaves()
	add_actor(player)
	player:add_slave(player_legs)
	add_actor(cam)

	terminal_velocity=4
	grav_acc = 0.15
	player_jump_height=2.5

	draw_bounding_boxes = false
end

--------------------------------------------------------------------------------

function _update60()
	for a in all(actors) do
		a:update()
		if a.dead then
			del(actors, a)
		end
	end
end

function add_actor(a)
	add(actors, a)
end

function is_solid(x,y)
	return get_flag_at(x,y,0)
end

function get_flag_at(x,y,flag)
	x/=8
	y/=8
	return fget(mget(x,y),flag)
end

function move_towards(goal, current, speed)
	if goal+speed<current then
		return current-speed
	elseif goal-speed>current then
		return current+speed
	else
		return goal
	end
end

--------------------------------------------------------------------------------

function _draw()
	cls()
	cam:set_position()
	map(0,0,0,0,128,32)
	for a in all(actors) do
		a:draw()
	end
	camera()
	draw_hud()
end

function draw_hud()
	rectfill(0,112,127,127,0)
	line(0,112,127,112,5)
	print("player", 1, 114, 7)
	print("enemy", 108, 114, 7)
end

__gfx__
0000dd0d0000dd0d0000dd0d00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000dddd0000dddd0000dddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ddfff000ddfff000dddff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ddfff000ddfff000dddff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d22dd200d22dd200dddddd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
df22222f0df222200ddd222000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
dff2222f0dfff2200dd2fff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0ff11100002ff10000222ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0011110000111100001111000d221100002111100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
002112000002210000221dd0ddd221101d221dd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0d2202200002220000222dd0dd0022101dd00dd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddd00dd0000dd0000dd2011111100220100001110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1d000dd0000dd0000dd0000000000d20000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011001110001110001dd000000000dd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000001d0000000001dd000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000001000000000011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770772777670000555555550000077755555555777000000000000000000000000000000000000000000000000000000000000000000000000000000000
7eeeeee80070007000000666666000007eee06666660eee800000055000000000000000000000000000000000000000000000000000000000000000005022000
7eeeeee82202200200000000000000007eee00000000eee800000000000000000000000000000000000000000000000000000000000000000000000000222200
7eeeeee8822822280000060000600000000006087060000000005505550000000000000000000000000000000000000000000000000000000000000050222200
7eeeee88888888885555000000005555555500087000555500000000000000000000000000000000000000000000000000000000000000000000000000222200
7eeeee8808280820066600000000666006660e887ee0666000550555055500000000000000000000000000000000000000000000000000000000000002222220
7eee8888000000000000000000000000700008887ee0000000000000000000000000000000000000000000000000000000000000000000000000000002222220
08888880000000000600000000000060068888800888806055055505550555000000000000000000000000000000000000000000000000000000000002222220
00000000000000000000000000000000077777700777777000000000000000000000000000000000000000000000000000000000000000000000000002222220
066605550555055506660660000000007eeeeee87eeeeee805550555055500000000000000000000000000000000000000000000000000000000000002222220
000000000000000000000000000000007eeeeee87eeeeee800000000000000000000000000000000000000000000000000000000000000000000000002222220
060666055505550555066600000000007eeeeee00eeeeee800055505550555000000000000000000000000000000000000000000000000000000000002222220
000000000000000000000000000000007eeeee800eeeee8800000000000000000000000000000000000000000000000000000000000000000000000002222220
066605550555055506660660000000007eeeee800eeeee8800000555055500000000000000000000000000000000000000000000000000000000000002222220
000000000000000000000000000000007eee88800888888800000000000000000000000000000000000000000000000000000000000000000000000002222220
06066605550555055506660000000000088000000000088000000005550000000000000000000000000000000000000000000000000000000000000002222220
00000000566555500000000000000030303000303030000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05550555565655500555000000033033000330330003300000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000566555500000000000303030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055505556655005505550000300003303000033030003000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000566555500000000003030330030303300303033000000000000000000000000000000000000000000000000000000000000000000000000000000000
05550555566655500555000000330033003300330033003300000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000566555500000000033003300330033003300330000000000000000000000000000000000000000000000000000000000000000000000000000000000
00055505556655005505550000330003003300030033000300000000000000000000000000000000000000000000000000000000000000000000000000000000
07777770077777777777777000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76666665766666666666666500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76666665766666666666666500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76666655766666666666665500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76666565766666666666656500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
76565655766666565656565500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
75656555766565656565655500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
05555550055555555555555000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222222220022222222222222227777772222222222222000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222222207002222222222222222226777722222222222000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222222077030222222222222222222277772222222222000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222220730733022222222222222222227777222222222000000000000000000000000000000000000000000000000000000000000000000000000
02222222220222207777373702222222222222222226777222222222000000000000000000000000000000000000000000000000000000000000000000000000
30222022207022073773033030222222222222222222777722222222000000000000000000000000000000000000000000000000000000000000000000000000
33020702073000773333303033022222222222222222777722222222000000000000000000000000000000000000000000000000000000000000000000000000
33307330733307733333300333302222222222222222777722222222000000000000000000000000000000000000000000000000000000000000000000000000
00070337033077333300330070030222222222222222777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00733030000773330033000300330022222222222226777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00003003007000000000030000030302722222222227777700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000030000003300030000000003330672222222277777200000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000003300000000000300277222226777777200000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000033227777777777772200000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000030222777777777722200000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000073222227777772222200000000000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222222222222220000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222220020222200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222207307022070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22222077073000770000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22220773733307730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22207733000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22077333000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
20773030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
07730330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
73303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
30373000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
73730000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
03000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001010206030700000000000000000000000000000101000000000000000000000000000000000000000000000000000001010100000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
8686868686868686868686868686404000000000000000004040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8686868686868686868485868686404000000000000000000061626051515162564040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8686868686868686869495868686404000000000000000000061516260626051474040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8686868686868686868686868686404000000000000000000061515151626051624040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
8280818283868686868686a08283404000000000000040404040405444404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
9290919293a182808182a1b09240404000000000000000616260624246514040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000919290919240404040404000000000000000615162424662604040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000506151620000000000000000616242466260514040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000506151620000000000404045554040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6465000000000000000000506151620000000000006147436057515140404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4040455500000000005444404040404040400000006151474346626040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5161474300000000004240404040404040400000006162604743605140404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5161514743636465426340404040404040404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4141414141414141414141414141414140404040404040404040404040404040404040404040404040404040000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000100003005000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
