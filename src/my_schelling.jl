using Agents

@agent SchellingAgent GridAgent{2} begin
    mood:: Bool
    group::Int
end

using Random

function initialize(; numagents = 320, griddims = (20, 20), min_to_be_happy = 3, seed = 125)
    space = GridSpaceSingle(griddims, periodic = false)
    properties = Dict(:min_to_be_happy => min_to_be_happy)
    rng = Random.MersenneTwister(seed)
    model = ABM(
        SchellingAgent, space;
        properties, rng, scheduler = Schedulers.Randomly()
    )

    for n in 1:numagents
        agent = SchellingAgent(n, (1, 1), false, n < numagents / 2 ? 1 : 2)
        add_agent_single!(agent, model)
    end
    return model
end

function agent_step!(agent, model)
    minhappy = model.min_to_be_happy
    count_neighbors_same_group = 0
    for neighbor in nearby_agents(agent, model)
        if agent.group == neighbor.group
            count_neighbors_same_group += 1
        end
    end

    if count_neighbors_same_group >= minhappy
        agent.mood = true
    else
        agent.mood = false
        move_agent_single!(agent, model)
    end
    return
end

model = initialize()
step!(model, agent_step!, 7)

using InteractiveDynamics
using CairoMakie

groupcolor(a) = a.group == 1 ? :blue : :green
groupmarker(a) = a.group == 1 ? :circle : :rect

figure, _ = abmplot(model; ac = groupcolor, am = groupmarker, as = 10)

abmvideo(
    "schelling.mp4", model, agent_step!;
    ac = groupcolor, am = groupmarker, as = 10,
    framerate = 4, frames = 20,
    title = "Schelling's segregation model"
)

println("End of programme!!! ")
