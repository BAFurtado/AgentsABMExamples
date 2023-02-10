using Agents
using Random

@agent Zombie OSMAgent begin
    infected::Bool
    speed::Float64
end

using LightOSM
using OSMMakie
using CairoMakie

function initialise(; seed = 0)
    map_path = "plots/bh_min.json"
    properties = Dict(:dt => 1 / 60)
    model = ABM(
        Zombie,
        OpenStreetMapSpace(map_path);
        properties = properties,
        rng = Random.MersenneTwister(seed)
    )

    for id in 1:100
        start = random_position(model) # At an intersection
        speed = rand(model.rng) * 5.0 + 2.0 # Random speed from 2-7kmph
        human = Zombie(id, start, false, speed)
        add_agent_pos!(human, model)
        OSM.plan_random_route!(human, model; limit = 50) # try 50 times to find a random route
    end
    # We'll add patient zero at a specific (longitude, latitude)
    start = OSM.nearest_road((-44.05, -19.92), model)
    finish = OSM.nearest_node((-44.05, -19.92), model)

    speed = rand(model.rng) * 5.0 + 2.0 # Random speed from 2-7kmph
    zombie = add_agent!(start, model, true, speed)
    plan_route!(zombie, finish, model)
    # This function call creates & adds an agent, see `add_agent!`
    return model
end

function agent_step!(agent, model)
    # Each agent will progress along their route
    # Keep track of distance left to move this step, in case the agent reaches its
    # destination early
    distance_left = move_along_route!(agent, model, agent.speed * model.dt)

    if is_stationary(agent, model) && rand(model.rng) < 0.1
        # When stationary, give the agent a 10% chance of going somewhere else
        OSM.plan_random_route!(agent, model; limit = 50)
        # Start on new route, moving the remaining distance
        move_along_route!(agent, model, distance_left)
    end

    if agent.infected
        # Agents will be infected if they get too close (within 10m) to a zombie.
        map(i -> model[i].infected = true, nearby_ids(agent, model, 0.02))
    end
    return
end

using InteractiveDynamics
using CairoMakie

ac(agent) = agent.infected ? :green : :black
as(agent) = agent.infected ? 10 : 8
model = initialise()

abmvideo("plots/outbreak.gif", model, agent_step!;
title = "Zombie outbreak", framerate = 15, frames = 400, as, ac)

abmvideo("plots/outbreak.mp4", model, agent_step!;
title = "Zombie outbreak", framerate = 15, frames = 400, as, ac)