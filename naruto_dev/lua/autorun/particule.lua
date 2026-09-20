function SpawnParticles(pos)
    local emitter = ParticleEmitter(pos)

    for i = 1, 200 do
        local p = emitter:Add("narutorp/effects/venom/poison", pos)
        if p then
            p:SetVelocity(VectorRand() * 100)
            p:SetLifeTime(0)
            p:SetDieTime(1.5)
            p:SetStartAlpha(255)
            p:SetEndAlpha(0)
            p:SetStartSize(15)
            p:SetEndSize(0)
            p:SetRoll(math.Rand(0, 360))
            p:SetColor(180, 0, 255)

        end
    end

    emitter:Finish()
end
