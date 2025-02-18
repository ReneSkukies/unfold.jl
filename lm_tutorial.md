---
author: "Benedikt Ehinger, with help Dave Kleinschmidt"
title: "Overlap Correction with Linear Models (aka unfold.jl)"
date: 2020-06-07
---
~~~~{.julia}

using StatsModels, MixedModels, DataFrames
import DSP.conv
import Plots
using unfold
include("../test/test_utilities.jl") # to load the simulated data
~~~~~~~~~~~~~


~~~~
loadtestdata (generic function with 2 methods)
~~~~





In this notebook we will fit regression models to (simulated) EEG data. We will see that we need some type of overlap correction, as the events are close in time to each other, so that the respective brain responses overlap.
If you want more detailed introduction to this topic check out my paper: https://peerj.com/articles/7838/
~~~~{.julia}

data, evts = loadtestdata("testcase2","../test/")
~~~~~~~~~~~~~


~~~~
Error: ArgumentError: "../test/data/testcase2_data.csv" is not a valid file
~~~~



~~~~{.julia}

show(first(evts,6,),allcols=true)
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: evts not defined
~~~~





The data has little noise and the underlying signal is a pos-neg spike pattern
~~~~{.julia}

Plots.plot(range(1/50,length=300,step=1/50),data[1:300])
Plots.vline!(evts[evts.latency.<=300,:latency]./50) # show events
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: data not defined
~~~~






## Traditional Mass Univariate Analysis
In order to demonstrate why overlap correction is important, we will first epoch the data and fit a linear model to each time point.
This is a "traditional mass-univariate analysis".
~~~~{.julia}

# for future multi-channel support (not yet there!)
data_r = reshape(data,(1,:))
# cut the data into epochs
data_epochs,times = unfold.epoch(data=data_r,tbl=evts,τ=(-0.4,0.8),sfreq=50)
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: data not defined
~~~~





We define a formula that we want to apply to each point in time
~~~~{.julia}

f  = @formula 0~1+conditionA+conditionB # 0 as a dummy, we will combine wit data later
~~~~~~~~~~~~~


~~~~
FormulaTerm
Response:
  0
Predictors:
  1
  conditionA(unknown)
  conditionB(unknown)
~~~~





We fit the `UnfoldLinearModel` to the data
~~~~{.julia}

m,results = fit(UnfoldLinearModel,f,evts,data_epochs,times)
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: fit not defined
~~~~




The object has the following fields
~~~~{.julia}

println(typeof(m))
println(fieldnames(typeof(m)))
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: m not defined
~~~~




Which contain the model, the original formula, the original events and returns extra a *tidy*-dataframe with the results
~~~~{.julia}

first(results,6)
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: results not defined
~~~~





We can also plot it:
~~~~{.julia}

Plots.plot(results.time,results.estimate,
        group=results.term,
        layout=1,legend=:outerbottom)
# equivalent: plot(m)
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: results not defined
~~~~




As can be seen a lot is going on here. As we will see later, most of the activity is due to overlap with the next event


## Basis Functions
#### HRF / BOLD
We are now ready to define a basisfunction. There are currently only two basisfunction implemented, so not much choice.
We first have a look at the BOLD-HRF basisfunction:

~~~~{.julia}

TR = 1.5
bold = hrfbasis(TR) # using default SPM parameters
eventonset = 1.3
Plots.plot(bold.kernel(eventonset))
~~~~~~~~~~~~~


![](figures/lm_tutorial_11_1.png)\ 



Classically, we would convolve this HRF function with a impulse-vector, with impulse at the event onsets
~~~~{.julia}

y = zeros(100)
y[[10,30,37,45]] .=1
y_conv = conv(y,bold.kernel(0))
Plots.plot(y_conv)
~~~~~~~~~~~~~


![](figures/lm_tutorial_12_1.png)\ 



Which one would use as a regressor against the recorded BOLD timecourse.

Note that events could fall inbetween TR (the sampling rate). Some packages subsample the time signal, but in `unfold` we can directly call the `bold.kernel` function at a given event-time, which allows for non-TR-multiples to be used.

### FIR Basis Function

Okay, let's have a look at a different basis function: The FIR basisfunction.

~~~~{.julia}

basisfunction = firbasis(τ=(-0.4,.8),sfreq=50)
Plots.plot(basisfunction.kernel(0))
~~~~~~~~~~~~~


~~~~
Error: UndefKeywordError: keyword argument name not assigned
~~~~





Not very clear, better show it in 2D
~~~~{.julia}

basisfunction.kernel(0)[1:10,1:10]
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: basisfunction not defined
~~~~




The FIR basisset consists of multiple basisfunctions. That is, each event will now be *timeexpanded* to multiple predictors, each with a certain time-delay to the event onset.
This allows to model any arbitrary linear overlap shape, and doesn't force us to make assumptions on the convolution kernel (like we had to do in the BOLD case)


## Timeexpanded / Deconvolved ModelFit
Remember our formula from above
~~~~{.julia}

f
~~~~~~~~~~~~~


~~~~
FormulaTerm
Response:
  0
Predictors:
  1
  conditionA(unknown)
  conditionB(unknown)
~~~~





For the left-handside we use "0" as the data is separated from the events. This will in the future allow us to fit multiple channels easily.

And fit a `UnfoldLinearModel`. Not that instead of `times` as in the mass-univariate case, we have a `BasisFunction` object now.
~~~~{.julia}

m,results = fit(UnfoldLinearModel,f,evts,data,basisfunction)
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: fit not defined
~~~~



~~~~{.julia}

Plots.plot(results.time,results.estimate,
        group=results.term,
        layout=1,legend=:outerbottom)
~~~~~~~~~~~~~


~~~~
Error: UndefVarError: results not defined
~~~~




Cool! All overlapping activity has been removed and we recovered the simulated underlying signal.



