
@inline UNITLESS_ABS2(x) = real(abs2(x))
@inline DEFAULT_NORM(u::Union{AbstractFloat, Complex}) = @fastmath abs(u)
@inline function DEFAULT_NORM(u::Array{T}) where {T <: Union{AbstractFloat, Complex}}
    return sqrt(real(sum(abs2, u)) / length(u))
end
@inline function DEFAULT_NORM(u::StaticArray{<:Union{AbstractFloat, Complex}})
    return sqrt(real(sum(abs2, u)) / length(u))
end
@inline function DEFAULT_NORM(u::AbstractVectorOfArray)
    return sum(sqrt(real(sum(UNITLESS_ABS2, _u)) / length(_u)) for _u in u.u)
end
@inline DEFAULT_NORM(u::AbstractArray) = sqrt(real(sum(UNITLESS_ABS2, u)) / length(u))
@inline DEFAULT_NORM(u) = norm(u)

alg_autodiff(alg::AbstractNewtonAlgorithm{<:AbstractFiniteDifferencesMode}) = false
alg_autodiff(alg::AbstractNewtonAlgorithm) = true
alg_autodiff(alg) = false

"""
    default_adargs_to_adtype(; chunk_size = Val{0}(), autodiff = Val{true}(),
        standardtag = Val{true}(), diff_type = Val{:forward})

Construct the AD type from the arguments. This is mostly needed for compatibility with older
code.
"""
function default_adargs_to_adtype(; chunk_size = Val{0}(), autodiff = Val{true}(),
    standardtag = Val{true}(), diff_type = Val{:forward}())
    ad = _unwrap_val(autodiff)
    # Old API
    if ad isa Bool
        # FIXME: standardtag is not the Tag
        ad && return AutoForwardDiff(; chunksize = _unwrap_val(chunk_size),
            tag = _unwrap_val(standardtag))
        return AutoFiniteDiff(; fdtype = diff_type)
    end
    return ad
end

# """
# value_derivative(f, x)

# Compute `f(x), d/dx f(x)` in the most efficient way.
# """
# function value_derivative(f::F, x::R) where {F, R}
#     T = typeof(ForwardDiff.Tag(f, R))
#     out = f(ForwardDiff.Dual{T}(x, one(x)))
#     ForwardDiff.value(out), ForwardDiff.extract_derivative(T, out)
# end

# # Todo: improve this dispatch
# function value_derivative(f::F, x::StaticArraysCore.SVector) where {F}
#     f(x), ForwardDiff.jacobian(f, x)
# end

@inline value(x) = x
@inline value(x::Dual) = ForwardDiff.value(x)
@inline value(x::AbstractArray{<:Dual}) = map(ForwardDiff.value, x)

@inline _vec(v) = vec(v)
@inline _vec(v::Number) = v
@inline _vec(v::AbstractVector) = v

DEFAULT_PRECS(W, du, u, p, t, newW, Plprev, Prprev, cachedata) = nothing, nothing

function dolinsolve(precs::P, linsolve; A = nothing, linu = nothing, b = nothing,
    du = nothing, u = nothing, p = nothing, t = nothing, weight = nothing,
    cachedata = nothing, reltol = nothing) where {P}
    A !== nothing && (linsolve.A = A)
    b !== nothing && (linsolve.b = b)
    linu !== nothing && (linsolve.u = linu)

    Plprev = linsolve.Pl isa ComposePreconditioner ? linsolve.Pl.outer : linsolve.Pl
    Prprev = linsolve.Pr isa ComposePreconditioner ? linsolve.Pr.outer : linsolve.Pr

    _Pl, _Pr = precs(linsolve.A, du, u, p, nothing, A !== nothing, Plprev, Prprev,
        cachedata)
    if (_Pl !== nothing || _Pr !== nothing)
        _weight = weight === nothing ?
                  (linsolve.Pr isa Diagonal ? linsolve.Pr.diag : linsolve.Pr.inner.diag) :
                  weight
        Pl, Pr = wrapprecs(_Pl, _Pr, _weight)
        linsolve.Pl = Pl
        linsolve.Pr = Pr
    end

    linres = reltol === nothing ? solve!(linsolve) : solve!(linsolve; reltol)

    return linres
end

function wrapprecs(_Pl, _Pr, weight)
    if _Pl !== nothing
        Pl = ComposePreconditioner(InvPreconditioner(Diagonal(_vec(weight))), _Pl)
    else
        Pl = InvPreconditioner(Diagonal(_vec(weight)))
    end

    if _Pr !== nothing
        Pr = ComposePreconditioner(Diagonal(_vec(weight)), _Pr)
    else
        Pr = Diagonal(_vec(weight))
    end

    return Pl, Pr
end

function _nfcount(N, ::Type{diff_type}) where {diff_type}
    if diff_type === Val{:complex}
        tmp = N
    elseif diff_type === Val{:forward}
        tmp = N + 1
    else
        tmp = 2N
    end
    return tmp
end

get_loss(fu) = norm(fu)^2 / 2

function rfunc(r::R, c2::R, M::R, γ1::R, γ2::R, β::R) where {R <: Real} # R-function for adaptive trust region method
    if (r ≥ c2)
        return (2 * (M - 1 - γ2) * atan(r - c2) + (1 + γ2)) / π
    else
        return (1 - γ1 - β) * (exp(r - c2) + β / (1 - γ1 - β))
    end
end

concrete_jac(_) = nothing
concrete_jac(::AbstractNewtonAlgorithm{CJ}) where {CJ} = CJ
