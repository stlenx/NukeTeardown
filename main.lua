function init()
	--Register the tool
  RegisterTool("nuke", "Nuke", "MOD/vox/stole.vox")
  SetBool("game.tool.nuke.enabled", true)

  --Values for how the explosion behaves
  nukeRange = 200;
  nukeRadius = 5;
  maxNukeExplosions = 150;
  shockwaveRadius = 30;
  fakeShockWaveRadius = 30;
  nukeActive = false;

  explodingFrameCount = 69;
  explosionSound = LoadSound("sounds/explosion.ogg")

  --Precalculate values
  goldenRatio = (1 + math.sqrt(5)) / 2;
  angleIncrement = math.pi * 2 * goldenRatio;
end

function GetAimPos(range)
	local ct = GetCameraTransform()
	local forwardPos = TransformToParentPoint(ct, Vec(0, 0, -range))
    local direction = VecSub(forwardPos, ct.pos)
    local distance = VecLength(direction)
	local direction = VecNormalize(direction)
	local hit, hitDistance = QueryRaycast(ct.pos, direction, distance)
	if hit then
		forwardPos = TransformToParentPoint(ct, Vec(0, 0, -hitDistance))
	end
	return forwardPos, hit
end

function MyMainGoalIsToBlowUp(dt)
	aimpos, hit = GetAimPos(nukeRange)

	if not hit then return end

	for a = 0, 6.2831853072, 0.3490658504 do
		-- float x = r*cos(t) + h;
        -- float y = r*sin(t) + k;

		local x = math.cos(a) * nukeRadius + aimpos[1];
		local y = math.sin(a) * nukeRadius + aimpos[3];

		local pos = Vec(x, aimpos[2], y)
		MakeHole(pos, 500, 500, 500, false)
		Explosion(pos, 4)
		SpawnFire(pos)

		SpawnParticle("darksmoke", pos, Vec(0, 1.0+math.random(1,10)*0.1, 0), 100, 100)
		SpawnParticle("smoke", pos, Vec(0, 1.0+math.random(1,10)*0.1, 0), 150, 150)
		SpawnParticle("fire", pos, Vec(0, 1.0+math.random(1,10)*0.1, 0), 0.3, 0.1)

		PointLight(pos, 255, 255, 255, 50)
	end

	Explosion(aimpos, 4)
	Particles()
	forceBodies(dt)

	explodingFrameCount = 0;
	nukeActive = true;
end

function tick(dt)
	if GetString("game.player.tool") == "nuke" and GetPlayerVehicle() == 0 then
		if InputPressed("lmb") then
			PlaySound(explosionSound)
			MyMainGoalIsToBlowUp(dt)
			-- DebugPrint(GetFloatParam("game.player.tool"))
		end

		if InputDown("rmb") then
			local aimpos, hit = GetAimPos(nukeRange)
			if not hit then return end
			MakeHole(aimpos, 500, 500, 500, false)
		end

		if InputDown("k") then --Decrease
			fakeShockWaveRadius = fakeShockWaveRadius - 0.1
			shockwaveRadius = math.floor(fakeShockWaveRadius)
			if shockwaveRadius < 1 then 
				shockwaveRadius = 1 
				fakeShockWaveRadius = 1
			end
		end

		if InputDown("l") then --Increase
			fakeShockWaveRadius = fakeShockWaveRadius + 0.1
			shockwaveRadius = math.floor(fakeShockWaveRadius)
		end

		if InputDown("o") then --Decrease
			maxNukeExplosions = maxNukeExplosions - 1
			if maxNukeExplosions < 1 then maxNukeExplosions = 1 end
		end

		if InputDown("p") then --Increase
			maxNukeExplosions = maxNukeExplosions + 1
		end
	end

	if explodingFrameCount < shockwaveRadius and nukeActive then
		
		forceBodies(dt)
		local explosionAmount = Remap(explodingFrameCount, 0, shockwaveRadius, 10, maxNukeExplosions)
		local randomnessAmount = Remap(explodingFrameCount, 0, shockwaveRadius, 10, 1)
		for i = 0, explosionAmount, 1 do
            local t = i / explosionAmount;
            local inclination = math.acos(1 - 2 * t);
            local azimuth = angleIncrement * i;

            local x = math.sin(inclination) * math.cos (azimuth);
            local y = math.sin(inclination) * math.sin (azimuth);
            local z = math.cos(inclination);

			-- Add some spice
			local randomX = GetRandom(-randomnessAmount, randomnessAmount)
			local randomY = GetRandom(-randomnessAmount, randomnessAmount)
			local randomZ = GetRandom(-randomnessAmount, randomnessAmount)
            local dir = VecNormalize(Vec(x + randomX, y + randomY, z + randomZ));
			
			local r = nukeRadius + explodingFrameCount * 1.2;
			local dir = VecScale(dir, r);

			local pos = VecAdd(aimpos, dir)
			MakeHole(pos, 500, 500, 500, false)
			SpawnParticle("smoke", pos, Vec(0, 1.0+math.random(1,10)*0.1, 0), 150, 150)
			SpawnParticle("fire", pos, Vec(0, 1.0+math.random(1,10)*0.1, 0), 0.3, 0.1)

			local color  = Remap(explodingFrameCount, 0, shockwaveRadius, 1, 0)
			PointLight(pos, 1, 0.68235294117647, color, 15)
        end

		explodingFrameCount = explodingFrameCount + 1;
	else
		nukeActive = false;
	end
end

function draw()
	if GetString("game.player.tool") == "nuke" and GetPlayerVehicle() == 0 then
		UiTranslate(0, UiHeight() - 100)
		UiAlign("left bottom")
		UiFont("bold.ttf", 24)

		local text = ""
		text = text .. "Shockwave radius:  " .. shockwaveRadius .. "\n"
		text = text .. "Press K/L to increase/decrease radius \n"
		text = text .. "\n"
		text = text .. "Shockwave strength:  " .. maxNukeExplosions .. "\n"
		text = text .. "Press O/P to increase/decrease strength"
		UiText(text)
	end
end

function forceBodies(dt)
    QueryRequire("physical dynamic")
	local vertReps = 5
	local vertStep = 5
    local radius = 150
    local off1 = Vec(-radius, 0, -radius)
    local off2 = Vec(radius, vertReps * vertStep, radius)
    local bodies = QueryAabbBodies(VecAdd(aimpos,off1),VecAdd(aimpos,off2))

    for i=1, #bodies do
        local body = bodies[i]
        local bodyTransform = GetBodyTransform(body)
        local t = Transform(aimpos, QuatLookAt(aimpos,bodyTransform.pos))
        local force = VecScale(TransformToParentVec(t,Vec(0,0,-1)),nukeForce)
        local vel = VecAdd(VecScale(force,dt/GetBodyMass(body)),GetBodyVelocity(body))

        SetBodyVelocity(body,vel)
    end
end

function Particles()
	cloudRadius = 5
	inRadius = 4
    for i=0,200 do
        local rad = math.random() * math.pi * 2
        local dist = (math.random() * (cloudRadius - inRadius)) + inRadius

        local offset = VecScale(Vec(math.sin(rad),0,math.cos(rad)),dist)
        local pos = VecAdd(aimpos,offset)

        ParticleReset()
        ParticleTile(5)
        ParticleColor(1,0.5,0,1,0.3,0)
        ParticleEmissive(0.3,0.1)
        ParticleRadius(1)
        ParticleCollide(0)
        SpawnParticle(pos,Vec(0,30,0),0.75)

        ParticleReset()
        ParticleType("smoke")
        ParticleColor(0.3, 0.2, 0.1)
        ParticleRadius(1)
        ParticleDrag(0,1000,"linear",0.25)
        ParticleStretch(0,100000,"linear",0.25)
        ParticleCollide(0)
        SpawnParticle(pos,Vec(0,20,0),5)
    end
end

function Remap(value, from1, to1, from2, to2)
	return (value - from1) / (to1 - from1) * (to2 - from2) + from2;
end

function GetRandom(min, max)
	return math.random() * (max - min) + min
end