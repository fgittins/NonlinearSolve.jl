module NonlinearSolveBase

using ADTypes: ADTypes, AbstractADType
using Adapt: WrappedArray
using ArrayInterface: ArrayInterface
using CommonSolve: CommonSolve, init
using Compat: @compat
using ConcreteStructs: @concrete
using DifferentiationInterface: DifferentiationInterface
using EnzymeCore: EnzymeCore
using FastClosures: @closure
using FunctionProperties: hasbranching
using LinearAlgebra: Diagonal, norm, ldiv!
using Markdown: @doc_str
using MaybeInplace: @bb
using RecursiveArrayTools: AbstractVectorOfArray, ArrayPartition
using SciMLBase: SciMLBase, ReturnCode, AbstractODEIntegrator, AbstractNonlinearProblem,
                 AbstractNonlinearAlgorithm, AbstractNonlinearFunction,
                 NonlinearProblem, NonlinearLeastSquaresProblem, StandardNonlinearProblem,
                 NullParameters, NLStats, LinearProblem, isinplace, warn_paramtype,
                 @add_kwonly
using SciMLOperators: AbstractSciMLOperator, IdentityOperator
using StaticArraysCore: StaticArray, SMatrix, SArray, MArray

const DI = DifferentiationInterface

include("public.jl")
include("utils.jl")

include("abstract_types.jl")

include("immutable_problem.jl")
include("common_defaults.jl")
include("termination_conditions.jl")

include("autodiff.jl")
include("jacobian.jl")
include("linear_solve.jl")

# Unexported Public API
@compat(public, (L2_NORM, Linf_NORM, NAN_CHECK, UNITLESS_ABS2, get_tolerance))
@compat(public, (nonlinearsolve_forwarddiff_solve, nonlinearsolve_dual_solution))
@compat(public,
    (select_forward_mode_autodiff, select_reverse_mode_autodiff,
        select_jacobian_autodiff))

# public for NonlinearSolve.jl to use
@compat(public, (InternalAPI, supports_line_search, supports_trust_region, set_du!))
@compat(public, (construct_linear_solver, needs_square_A))

export RelTerminationMode, AbsTerminationMode,
       NormTerminationMode, RelNormTerminationMode, AbsNormTerminationMode,
       RelNormSafeTerminationMode, AbsNormSafeTerminationMode,
       RelNormSafeBestTerminationMode, AbsNormSafeBestTerminationMode

end
