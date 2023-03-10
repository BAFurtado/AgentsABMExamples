using DrWatson
@quickactivate "AgentsABMExamples"

using Agents, Random
using Agents.DataFrames, Agents.Graphs
using Distributions: Poisson, DiscreteNonParametric
using CairoMakie
using DrWatson: @dict

@agent PoorSoul GraphAgent begin
    days_infected::Int
    status::Symbol
end

function model_initiation(; 
    Ns,
    migration_rates,
    beta_und,
    beta_det,
    infection_period = 30,
    reinfection_probability = 0.05,
    detection_time = 14,
    death_rate = 0.02,
    Is = [zeros(Int, length(Ns) - 1)..., 1],
    seed = 0
    )

    rng = MersenneTwister(seed)
    @assert length(Ns) == 
    length(Is) == 
    length(beta_und) == 
    length(beta_det) == 
    size(migration_rates, 1)
    # Migration rate is square matrix
    @assert size(migration_rates, 1) == size(migration_rates, 2)

    C = length(Ns)

    # Normalize migration rates
    migration_rates_sum = sum(migration_rates, dims = 2)
    for c in 1:C
        migration_rates[c, :] ./ migration_rates_sum[c]
    end

    properties = @dict(
        Ns,
        Is,
        beta_und,
        beta_det,
        migration_rates,
        infection_period,
        reinfection_probability,
        detection_time,
        C,
        death_rate
    )
    space = GraphSpace(complete_digraph(C))
    model = ABM(PoorSoul, space; properties, rng)

    # Add agents
    for city in 1:C, n in 1:Ns[city]
        ind = add_agent!(city, model, 0, :S)
    end

    # Add infected
    for city in 1:C
        inds = ids_in_position(city, model)
        for n in 1:Is[city]
            agent = model[inds[n]]
            agent.status = :I
            agent.days_infected = 1
        end
    end
    return model
end

using LinearAlgebra: diagind

function create_params(;
    C,
    max_travel_rate,
    infection_period = 30,
    reinfection_probability = 0.05,
    detection_time = 14,
    death_rate = 0.02,
    Is = [zeros(Int, C - 1)..., 1],
    seed = 19,
)

    Random.seed!(seed)
    Ns = rand(50:5000, C)
    beta_und = rand(0.38:0.02:0.6, C)
    beta_det = beta_und ./ 10

    Random.seed!(seed)
    migration_rates = zeros(C, C)
    for c in 1:C
        for c2 in 1:C
            migration_rates[c, c2] = (Ns[c] + Ns[c2]) / Ns[c]
        end
    end
    maxM = maximum(migration_rates)
    migration_rates = (migration_rates .* max_travel_rate) ./ maxM
    migration_rates[diagind(migration_rates)] .= 1.0

    params = @dict(
        Ns,
        beta_und,
        beta_det,
        migration_rates,
        infection_period,
        reinfection_probability,
        detection_time,
        death_rate,
        Is
    )

    return params
end

function agent_step!(agent, model)
    migrate!(agent, model)
    transmit!(agent, model)
    update!(agent, model)
    recover_or_die!(agent, model)
end

function migrate!(agent, model)
    pid = agent.pos
    d = DiscreteNonParametric(1:(model.C), model.migration_rates[pid, :])
    m = rand(model.rng, d)
    if m != pid
        move_agent!(agent, m, model)
    end
end

function transmit!(agent, model)
    agent.status == :S && return
    rate = if agent.days_infected < model.detection_time
        model.beta_und[agent.pos]
    else
        model.beta_det[agent.pos]
    end

    d = Poisson(rate)
    n = rand(model.rng, d)
    n == 0 && return

    for contactID in ids_in_position(agent, model)
        contact = model[contactID]
        if contact.status == :S ||
            (contact.status == :R && rand(model.rng) <= model.reinfection_probability)
            contact.status = :I
            n -= 1
            n == 0 && return
        end
    end
end

update!(agent, model) = agent.status == :I && (agent.days_infected += 1)

function recover_or_die!(agent, model)
    if agent.days_infected >= model.infection_period
        if rand(model.rng) <= model.death_rate
            kill_agent!(agent, model)
        else
            agent.status :R
            agent.days_infected = 0
        end
    end
end

# params = create_params(C = 8, max_travel_rate = 0.01)
# model = model_initiation(; params...)

using InteractiveDynamics
using CairoMakie
abmobs = ABMObservable(model; agent_step!)

infected_fraction(m, x) = count(m[id].status == :I for id in x) / length(x)
infected_fractions(m) = [infected_fraction(m, ids_in_position(p, m)) for p in positions(m)]
fracs = lift(infected_fractions, abmobs.model)
color = lift(fs -> [cgrad(:inferno)[f] for f in fs], fracs)
title = lift(
    (s, m) -> "step = $(s), infected = $(round(Int, 100infected_fraction(m, allids(m))))%",
    abmobs.s, abmobs.model
)

fig = Figure(resolution = (600, 400))
ax = Axis(fig[1, 1]; title, xlabel = "City", ylabel = "Population")
barplot!(ax, model.Ns; strokecolor = :black, strokewidth = 1, color)

record(fig, "plots/covid_evolution.mp4"; framerate = 5) do io
    for j in 1:30
        recordframe!(io)
        Agents.step!(abmobs, 1)
    end
    recordframe!(io)
end

println("___________________________________________________________---Done!")