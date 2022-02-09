include("test_utilities.jl")

data, evts = loadtestdata("test_case_3a") #

data_r = reshape(data, (1, :))
data_e, times = Unfold.epoch(data = data_r, tbl = evts, τ = (0, 0.05), sfreq = 10) # cut the data into epochs

f = @formula 0 ~ 1 + conditionA + continuousA # 1
m_mul = fit(Unfold.UnfoldModel, Dict(Any=>(f,times)), evts, data_e)
##
@testset "Mass Univariate, all specified" begin


	# test simple case
	eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[0]),m_mul)
	@test size(eff,1) == 2 # we specified 2 levels @ 1 time point
	@test eff.conditionA ≈ [0.,1.] # we want to different levels
	@test eff.yhat ≈ [2.0,5.0] # these are the perfect predicted values

	# combination 2 levels /  6 values
	eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[-2,0,2]),m_mul)
	@test size(eff,1) == 6 # we want 6 values
	@test eff.conditionA ≈ [0.,0.,0.,1.,1.,1.] 
	@test eff.continuousA ≈ [-2,0,2,-2,0,2.] 
end
@testset "Mass Univariate, typified" begin
# testing typical value
	eff_man = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[mean(evts.continuousA)]),m_mul)
	eff_typ = Unfold.effects(Dict(:conditionA => [0,1]),m_mul)
	@test eff_man.yhat ≈ eff_typ.yhat
end

## Testing Splines
f_spl = @formula 0 ~ 1 + conditionA + spl(continuousA, 3) # 1
m_mul_spl = fit(UnfoldModel, f_spl, evts, data_e, times)

@testset "Mass Univariate, splines" begin

eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[0]),m_mul_spl)
@test size(eff,1) == 2 # we specified 2 levels @ 1 time point
@test eff.conditionA ≈ [0.,1.] # we want to different levels
@test eff.yhat ≈ [2.0,5.0] # these are the perfect predicted values

# combination 2 levels /  6 values
eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[-0.5,0,0.5]),m_mul_spl)
@test size(eff,1) == 6 # we want 6 values
@test eff.conditionA ≈ [0.,0.,0.,1.,1.,1.] 
@test eff.continuousA ≈ [-0.5,0,0.5,-0.5,0,0.5] 
@test eff.yhat ≈ [0,2,4,3,5,7]

# testing for safe predictions
eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[2]),m_mul_spl)
@test all(ismissing.(eff.yhat ))
end

## Timeexpansion
data, evts = loadtestdata("test_case_3a") #
f = @formula 0 ~ 1 + conditionA + continuousA # 1

@testset "Time Expansion, one event" begin

uf = fit(Unfold.UnfoldModel, Dict(Any=>(f,firbasis([0,0.1],10))), evts, data)
eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[0]),uf)
@test nrow(eff) == 4
@test eff.yhat ≈ [2., 2., 5., 5.]
@test eff.conditionA ≈ [0.,0.,1.,1.]
@test eff.continuousA ≈ [0.,0.,0.,0.]
end

data, evts = loadtestdata("test_case_4a") #
b1 = firbasis(τ = (0.0, 0.95), sfreq = 20, name = "basisA")
b2 = firbasis(τ = (0.0, 0.95), sfreq = 20, name = "basisB")
f = @formula 0 ~ 1 # 1
m_tul = fit(UnfoldModel, Dict("eventA"=>(f,b1),"eventB"=>(f,b2)), evts, data,eventcolumn="type")

@testset "Time Expansion, two events" begin

eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[0]),m_tul)
@test unique(eff.basisname)==["basisA","basisB"]
@test unique(eff.yhat) ≈ [2,3]
@test size(eff,1) == 2*2*20 # 2 basisfunctions, 2x conditionA, 1s a 20Hz

eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[-1,0,1]),m_tul)
@test size(eff,1) == 2*6*20

end

@testset "Time Expansion, two events different size + different formulas" begin

## Different sized events + different Formulas
data, evts = loadtestdata("test_case_4a") #
evts[!,:continuousA] = rand(MersenneTwister(42),nrow(evts))
b1 = firbasis(τ = (0.0, 0.95), sfreq = 20, name = "basisA")
b2 = firbasis(τ = (0.0, 0.5), sfreq = 20, name = "basisB")
f1 = @formula 0 ~ 1 # 1
f2 = @formula 0 ~ 1+continuousA # 1
m_tul = fit(UnfoldModel, Dict("eventA"=>(f1,b1),"eventB"=>(f2,b2)), evts, data,eventcolumn="type")
eff = Unfold.effects(Dict(:conditionA => [0,1],:continuousA =>[-1,0,1]),m_tul)
@test nrow(eff) == (length(b1.times)+length(b2.times))*6
@test sum(eff.basisname .== "basisA") == 120
@test sum(eff.basisname .== "basisB") == 66

end

## Test two channels
data, evts = loadtestdata("test_case_3a") #

data_r = repeat(reshape(data, (1, :)),3,1)
data_r[2,:] = data_r[2,:] .* 2


data_e, times = Unfold.epoch(data = data_r, tbl = evts, τ = (0, 0.05), sfreq = 10) # cut the data into epochs

#
f = @formula 0 ~ 1 + conditionA + continuousA # 1
m_mul = fit(Unfold.UnfoldModel, Dict(Any=>(f,times)), evts, data_e)
m_tul = fit(Unfold.UnfoldModel, Dict(Any=>(f,firbasis([0,.05],10))), evts, data_r)
@testset "Two channels" begin

# test simple case
eff_m = Unfold.effects(Dict(:conditionA => [0,1,0,1],:continuousA =>[0]),m_mul)
eff_t = Unfold.effects(Dict(:conditionA => [0,1,0,1],:continuousA =>[0]),m_tul)

@test eff_m.yhat ≈ eff_t.yhat
@test length(unique(eff_m.channel)) == 3
@test eff_m[eff_m.channel .==1,:yhat] ≈ eff_m[eff_m.channel .==2,:yhat]./2
@test eff_m[eff_m.channel .==1,:yhat] ≈ [2,5,2,5.] # these are the perfect predicted values - note that we requested them twice

end

@testset "Timeexpansion, two events, typified" begin

data, evts = loadtestdata("test_case_4a") #
evts[!,:continuousA] = rand(MersenneTwister(42),nrow(evts))
evts[!,:continuousB] = rand(MersenneTwister(43),nrow(evts))
ixA = evts.type .== "eventA"
evts.continuousB[ixA] = evts.continuousB[ixA] .-mean(evts.continuousB[ixA]) .-5
evts.continuousB[.!ixA] = evts.continuousB[.!ixA] .-mean(evts.continuousB[.!ixA]) .+ 0.5
b1 = firbasis(τ = (0.0, 0.02), sfreq = 20, name = "basisA")
b2 = firbasis(τ = (1.0, 1.02), sfreq = 20, name = "basisB")
f1 = @formula 0 ~ 1+continuousA # 1
f2 = @formula 0 ~ 1+continuousB # 1
m_tul = fit(UnfoldModel, Dict("eventA"=>(f1,b1),"eventB"=>(f2,b2)), evts, data,eventcolumn="type")

m_tul.modelfit.estimate .= [0 -1 0 6]
eff = Unfold.effects(Dict(:continuousA => [0,1]),m_tul)
eff = Unfold.effects(Dict(:continuousA => [0,1],:continuousB =>[0.5]),m_tul)


@test eff.yhat[3] == eff.yhat[4]
@test eff.yhat[1] == 0.
@test eff.yhat[2] == -1.
@test eff.yhat[3] == 3
end


@testset "timeexpansion, Interactions, two events" begin
	data, evts = loadtestdata("test_case_4a") #
	evts[!,:continuousA] = rand(MersenneTwister(42),nrow(evts))
	evts[!,:continuousB] = ["m","x"][Int.(1 .+ round.(rand(MersenneTwister(43),nrow(evts))))]
	

	b1 = firbasis(τ = (0.0, 0.02), sfreq = 20, name = "basisA")
	b2 = firbasis(τ = (1.0, 1.02), sfreq = 20, name = "basisB")
	f1 = @formula 0 ~ 1+continuousA*continuousB # 1
	f2 = @formula 0 ~ 1+continuousB # 1
	m_tul = fit(UnfoldModel, Dict("eventA"=>(f1,b1),"eventB"=>(f2,b2)), evts, data,eventcolumn="type")

	m_tul.modelfit.estimate .= [0, -1, 0, 2., 0.,0.]'

	eff = Unfold.effects(Dict(:continuousA => [0,1]),m_tul)
	@test size(eff,1) == 4
	@test all(eff.basisname[1:2] .== "basisA")
	@test all(eff.basisname[4:end] .== "basisB")
	@test eff.yhat ≈ [0., mean(evts.continuousB[evts.type .== "eventA"].=="x") * coef(m_tul)[4] + 1*coef(m_tul)[2], 0., 0.]

	eff = Unfold.effects(Dict(:continuousB => ["m","x"]),m_tul)
	@test eff.yhat[1] == -eff.yhat[2]
	@test all(eff.yhat[3:4] .≈ 0.)


	eff = Unfold.effects(Dict(:continuousA => [0,1],:continuousB => ["m","x"]),m_tul)
	@test eff.yhat[3:4] == [-1,1]
	@test all(eff.yhat[1:2, 5:end] .== 0)
end

