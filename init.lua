mobs_api = {
    version = 1,
    path = core.get_modpath("mobs_api"),
    pr = PcgRandom(23647),
    step_time = 0.5
}


--[[
{
    name = <string>,
    title = <string>, -- Optional will default to name if nil
    egg_texture = <texture>,
    on_spawn = function(self),
    life_time = <num>,
    gravity = <num>,
    health_min = <num>, -- Optional
    health_max = <num>, -- Default health if no min
    despawn_distance = <num>, -- Defaults to 32
    chase_distance = <num>, -- Defaults to nil, leave nil if passive
    walk_speed = <num>, -- Default = 1
    on_rightclick = function(self, clicker),
    on_punch = function(self, puncher, time_from_last_punch, tool_capabilities, dir, damage),
    on_chase = function(self, player),
    on_stop = function(self),
    on_idle = function(self),
    on_at_player = function(self, player), -- overrides on_stop call if stop is at player

    hp_max = def.health_max,
    collide_with_objects = def.collide_with_objects, -- Default true
    physical = def.physical, -- Default true
    pointable = def.pointable, -- Default true
    collisionbox = def.collisionbox,
    collisionbox = def.selectionbox,
    textures = def.textures,
    visual = def.visual, -- Default "mesh"
    use_texture_alpha = def.use_texture_alpha,
    is_visible = def.is_visible, -- Default true
    makes_footstep_sound = def.makes_footstep_sound -- Default true
    stepheight = def.stepheight, -- Default 1.2
    visual_size = def.visual_size,
    mesh = def.mesh,
    node = def.node,
    nametag = def.nametag,
    static_save = def.static,
    show_on_minimap = def.show_on_minimap, -- Default false
    glow = def.glow,

    Exlusive or:
        on_death = function(self, killer)
        drops = <table of drops in format `[<itemname>] = {chance = <num>, min_count = <num>, max_count = <num>}` Only 1 entry droped. Internal chance = 1/<chance>. Counts default to 1 if `nil`.

}
]]


function mobs_api.register_mob(def)
    if not def.name then return false, "Needs a name!" end
    if not def.health_max then return false, "Needs `health_max = <num>` field!" end

    local entity = {
        get_staticdata = function(self)
            local table = {}

            for k, v in pairs(self) do
                if not(type(v) == "userdata" or type(v) == "function") then
                    table[k] = v
                end
            end

            return core.write_json(table)
        end,

        on_activate = function(self, staticdata, dtime_s)
            if staticdata and staticdata ~= "" then
                local table = core.parse_json(staticdata) or {}
                for k, v in pairs(table) do
                    self[k] = v
                end

            elseif not self._mobs_api_spawned then
                if self._mobs_api_health_min then
                    self.object:set_hp(mobs_api.pr:next(self._mobs_api_health_min, self._mobs_api_health_max))
                end

                self._mobs_api_spawned = true

                if self._mobs_api_on_spawn then
                    self._mobs_api_on_spawn(self)
                end
            end
        end,

        on_deactivate = function(self, removal)
            if (not removal) and (self._mobs_api_static ~= true) then
                self.object:remove()
                return
            end
        end,

        on_step = function(self, dtime, moveresult)
            if not self._mobs_api_spawned then return end

            self._mobs_api_last_step = self._mobs_api_last_step + dtime

            if self._mobs_api_last_step >= mobs_api.step_time then
                self._mobs_api_age = self._mobs_api_age + self._mobs_api_last_step
                if self._mobs_api_life_time and self._mobs_api_age >= self._mobs_api_life_time then
                    self.object:remove()
                    return
                end

                local m_pos = self.object:get_pos()

                local despawn = true
                for object in core.objects_inside_radius(m_pos, self._mobs_api_despawn_distance) do
                    if object:is_player() then
                        despawn = false
                        break
                    end
                end
                if despawn then
                    self.object:remove()
                    return
                end

                if self._mobs_api_chase_distance ~= nil then
                    local player_to_chase = nil
                    for object in core.objects_inside_radius(self.object:get_pos(), self._mobs_api_chase_distance) do
                        if object:is_player() then
                            player_to_chase = object
                            break
                        end
                    end

                    if player_to_chase ~= nil then
                        local p_pos = player_to_chase:get_pos()
                        local dir = p_pos - m_pos
                        local mag = math.sqrt(dir.x*dir.x + dir.y*dir.y + dir.z*dir.z)

                        if mag > 2 then
                            local v = vector.new(dir.x / mag, dir.y / mag, dir.z / mag)
                            self.object:set_velocity(v * self._mobs_api_walk_speed + vector.new(0, self._mobs_api_gravity, 0))
                            if self._mobs_api_on_chase ~= nil then
                                self._mobs_api_on_chase(self, player_to_chase)
                            end

                        else
                            self.object:set_velocity(vector.new(0, self._mobs_api_gravity, 0))
                            if self._mobs_api_on_at_player ~= nil then
                                self._mobs_api_on_at_player(self, player_to_chase)

                            elseif self._mobs_api_on_stop ~= nil then
                                self._mobs_api_on_stop(self)
                            end
                        end

                    else
                        self.object:set_velocity(vector.new(0, self._mobs_api_gravity, 0))

                        if self._mobs_api_on_idle ~= nil then
                            self._mobs_api_on_idle(self)
                        end
                    end
                end


                if self._mobs_api_on_step ~= nil then
                    self._mobs_api_on_step(self, dtime, moveresult)
                end

                self._mobs_api_last_step = 0
            end
        end,

        on_punched = def.on_punched,
        on_rightclick = def.on_rightclick

        -- Vars
        _mobs_api_health_max = def.health_max,
        _mobs_api_static = def.static,
        _mobs_api_despawn_distance = def.despawn_distance or 32,
        _mobs_api_chase_distance = def.chase_distance,
        _mobs_api_walk_speed = def.walk_speed or 1,
        _mobs_api_gravity = -(def.gravity or 0),
        _mobs_api_spawned = false,
        _mobs_api_last_step = 0,
        _mobs_api_age = 0,

        -- Callbacks
        _mobs_api_on_spawn = def.on_spawn,
        _mobs_api_life_time = def.life_time,
        _mobs_api_on_step = def.on_step,
        _mobs_api_on_chase = def.on_chase,
        _mobs_api_on_stop = def.on_stop,
        _mobs_api_on_at_player = def.on_at_player,
        _mobs_api_on_idle = def.on_idle,


        _mobs_api_spawned = false,
    }

    entity.initial_properties = {
        hp_max = def.health_max,
        collide_with_objects = def.collide_with_objects,
        physical = def.physical,
        pointable = def.pointable,
        collisionbox = def.collisionbox,
        collisionbox = def.selectionbox,
        textures = def.textures,
        visual = def.visual or "mesh",
        use_texture_alpha = def.use_texture_alpha,
        is_visible = def.is_visible,
        makes_footstep_sound = def.makes_footstep_sound,
        stepheight = def.stepheight,
        visual_size = def.visual_size,
        mesh = def.mesh,
        node = def.node,
        nametag = def.nametag,
        static_save = def.static,
        show_on_minimap = def.show_on_minimap,
        glow = def.glow,

        backface_culling = true,
    }
    -- Override defauts
    if entity.initial_properties.physical == nil then
        entity.initial_properties.physical = true
    end
    if entity.initial_properties.use_texture_alpha == nil then
        entity.initial_properties.use_texture_alpha = true
    end
    if entity.initial_properties.makes_footstep_sound == nil then
        entity.initial_properties.makes_footstep_sound = true
    end
    if entity.initial_properties.stepheight == nil then
        entity.initial_properties.stepheight = 1.2
    end

    if def.on_death then
        entity.on_death = def.on_death
    else
        def._mobs_api_drops = def.drops
        entity.on_death = function(self, killer)
            for item, t in pairs(def._mobs_api_drops) do
                if mobs_api.pr:next(1, t.chance) == 1 then
                    local is = ItemStack(itsm)
                    is:set_count(pr:next(t.min_count or 1, t.max_count or 1))
                    core.add_item(self.object:get_pos(), is)
                    break
                end
            end
        end
    end

    if def.health_min then
        entity._mobs_api_health_min = def.health_min
    end

    core.register_entity(":" .. def.name, entity)

    core.register_craftitem(":" .. def.name .. "_egg", {
        description = "Spwans " .. (def.title or def.name),
        inventory_image = def.egg_texture,
        on_place = function(itemstack, user, pointed_thing)
            if pointed_thing.above then
                core.add_entity(pointed_thing.above, def.name)
            end
        end,
    })

    core.register_node(":" .. def.name .. "_spawner", {
        description = "Spwans " .. (def.title or def.name),
        tiles = {def.egg_texture},
        use_texture_alpha = "clip",
        drop = "",

        on_timer = function(pos, elapsed)
            local airs = core.find_nodes_in_area(pos - vector.new(5, 5, 5), pos + vector.new(5, 5, 5), "air")
            local under = vector.new(0, -1, 0)

            while #airs ~= 0 do
                local v = airs[mobs_api.pr:next(1, #airs)]

                local node = core.registered_nodes[core.get_node(v + under).name or ""]
                if node.walkable == true then
                    core.add_entity(v, def.name)
                    break
                end
            end

            local nodetimer = core.get_node_timer(pos)
            nodetimer:start(mobs_api.pr:next(10, 60))
        end,
        on_construct = function(pos)
            local nodetimer = core.get_node_timer(pos)
            nodetimer:start(mobs_api.pr:next(10, 60))
        end,

        groups = {oddly_breakable_by_hand = 1, breakable_by_hand = 1}
    })

    return true, nil
end