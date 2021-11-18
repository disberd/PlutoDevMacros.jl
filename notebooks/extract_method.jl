### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# ╔═╡ e3b54b66-d8cd-430f-af1a-5258b8cdc4ba
using Base: SimpleVector, show_can_elide, isgensym, unwrap_unionall

# ╔═╡ 802efc8b-b2db-4c93-b850-bffa4669d0a5
md"""
# \_toexpr
"""

# ╔═╡ 323ec4bb-cf56-46dc-89ab-2cb985a3dc58
md"""
The function `_toexpr` is used to process the components of a method signature to reconstruct an expression that could be used to bring the method into scope from the parent module (loaded with `@plutoinclude`) to the current module 
"""

# ╔═╡ b90d4ebb-a52c-4e48-8e0c-b6b50aa1909f
# This function is basicaly copied and adapted from https://github.com/JuliaLang/julia/blob/743a37898d447d047002efcc19ce59825ef63cc1/base/show.jl#L604-L648
function _toexpr(v::Val, env::SimpleVector, orig::SimpleVector, wheres::Vector; to::Module, from::Module)
	ex = Expr(:curly)
	n = length(env)
    elide = length(wheres)
    function egal_var(p::TypeVar, @nospecialize o)
        return o isa TypeVar &&
            ccall(:jl_types_egal, Cint, (Any, Any), p.ub, o.ub) != 0 &&
            ccall(:jl_types_egal, Cint, (Any, Any), p.lb, o.lb) != 0
    end
    for i = n:-1:1
        p = env[i]
        if p isa TypeVar
            if i == n && egal_var(p, orig[i]) && show_can_elide(p, wheres, elide, env, i)
                n -= 1
                elide -= 1
            elseif p.lb === Union{} && isgensym(p.name) && show_can_elide(p, wheres, elide, env, i)
                elide -= 1
            elseif p.ub === Any && isgensym(p.name) && show_can_elide(p, wheres, elide, env, i)
                elide -= 1
            end
        end
    end
	if n > 0
        for i = 1:n
            p = env[i]
            if p isa TypeVar
                if p.lb === Union{} && something(findfirst(@nospecialize(w) -> w === p, wheres), 0) > elide
                    push!(ex.args, Expr(:(<:), _toexpr(v, p.ub;to, from)))
                elseif p.ub === Any && something(findfirst(@nospecialize(w) -> w === p, wheres), 0) > elide
                    push!(ex.args, Expr(:(>:), _toexpr(v, p.lb; to, from)))
                else
                    push!(ex.args, _toexpr(v, p; to, from))
                end
            else
               push!(ex.args, _toexpr(v, p; to, from))
            end
        end
    end
    resize!(wheres, elide)
    ex
end

# ╔═╡ cd1dc6b3-fe80-4757-b21d-522e7d107208
function _toexpr(v::Val, x::DataType, wheres::Vector = TypeVar[]; to::Module, from::Module)
	parameters = x.parameters::SimpleVector
    name = x.name.wrapper |> Symbol
	val = isdefined(to,name) ? name : x.name.wrapper
	if isempty(parameters)
		return val
	end
	ex = _toexpr(v, parameters, unwrap_unionall(x.name.wrapper).parameters, wheres; to, from)
	if isempty(ex.args)
		return val
	else
		pushfirst!(ex.args, val)
	end
	return ex
end

# ╔═╡ 178025f7-87e0-4632-995c-42ab241e7c6e
function _toexpr(v::Val, x::UnionAll; to::Module, from::Module)
	wheres = TypeVar[]
	while x isa UnionAll
		push!(wheres,x.var)
		x = x.body
	end
	ex = _toexpr(v, x, wheres; to, from)
end

# ╔═╡ a73e589d-aa61-4cad-b1d5-bcbece9b7b1f
function _toexpr(v::Val, x; to::Module, from::Module)
	return x
end

# ╔═╡ 4f06c9f6-eeb1-4d5e-a44c-0e3f67b848fe
function _toexpr(v::Val{:types},x::TypeVar; to::Module, from::Module)
	# If this has a name, return the name
	isgensym(x.name) || return x.name
end	

# ╔═╡ 98d1d4b2-1a09-443d-a178-4c57af8f4eac
function _toexpr(v::Val{:wheres},x::TypeVar; to::Module, from::Module)
	if isgensym(x.name)
		if x.lb === Union{}
			ex = Expr(:(<:), _toexpr(v,x.ub; to, from))
		elseif x.ub === Any
			ex = Expr(:(:>), _toexpr(v,x.lb; to, from))
		else
			ex = ()
		end
	else
		if x.lb === Union{} && x.ub === Any
			ex = x.name
		elseif x.lb === Union{}
			ex = Expr(:(<:), x.name, _toexpr(v,x.ub; to, from))
		elseif x.ub === Any
			ex = Expr(:(:>), x.name, _toexpr(v,x.lb; to, from))
		else
			ex = Expr(:comparison,_toexpr(v,x.lb; to, from),:(<:),x.name,:(<:),_toexpr(v,x.ub; to, from))
		end
	end
	return ex
end	

# ╔═╡ 55a3275d-5c6d-4c56-984b-c4215a23cbd2
function _toexpr(v::Val,u::Union; to::Module, from::Module)
	ex = Expr(:curly)
	push!(ex.args,:Union)
	push!(ex.args, _toexpr(v,u.a; to, from))
	push!(ex.args, _toexpr(v,u.b; to, from))
	ex
end

# ╔═╡ 5037a0b0-4788-11ec-3681-339f2de45d6a
function signature_expression(mtd::Method; to::Module, from::Module)
	s = mtd.name
	lhs = Expr(:call)
	# Add the method name
	# push!(lhs.args,mtd.name)
	push!(lhs.args,s)
	nms = map(Base.method_argnames(mtd)[2:end]) do nm
		nm === Symbol("#unused#") ? gensym() : nm
	end
	tv = Any[]
    sig = mtd.sig
    while isa(sig, UnionAll)
        push!(tv, sig.var)
        sig = sig.body
    end
	# Get the argument types, stripped from TypeVars
	tps = sig.parameters[2:end]
	for (nm,sig) ∈ zip(nms,tps)
		push!(lhs.args, Expr(:(::),_toexpr(Val(:types), nm; to, from),_toexpr(Val(:types), sig; to, from)))
	end
	if !isempty(tv)
		lhs = Expr(:where,lhs,map(x -> _toexpr(Val(:wheres),x; to, from),tv)...)
		# lhs = Expr(:where,lhs,tv...)
	end
	lhs
	# Add the function call
	rhs = :($(getfield(from,s))())
	# Push the variables
	for (nm,sig) ∈ zip(nms,tps)
		if sig isa Core.TypeofVararg
			push!(rhs.args, Expr(:(...),nm))
		else
			push!(rhs.args, nm)
		end
	end
	rhs = Expr(:block, rhs)
	Expr(:(=), lhs, rhs)
end

# ╔═╡ 665e4da8-56b6-480a-b07d-89454f0561c0
[collect(1:5);ones(3);collect(10:20)]

# ╔═╡ 015fa311-68c8-4474-ae48-fcceb6c3648e
#=╠═╡ notebook_exclusive
function plutodump(x::Union{Symbol, Expr})
	i = IOBuffer()
	Meta.dump(i, x)
	String(take!(i)) |> Text
end
  ╠═╡ notebook_exclusive =#

# ╔═╡ Cell order:
# ╠═e3b54b66-d8cd-430f-af1a-5258b8cdc4ba
# ╟─802efc8b-b2db-4c93-b850-bffa4669d0a5
# ╟─323ec4bb-cf56-46dc-89ab-2cb985a3dc58
# ╠═b90d4ebb-a52c-4e48-8e0c-b6b50aa1909f
# ╠═cd1dc6b3-fe80-4757-b21d-522e7d107208
# ╠═178025f7-87e0-4632-995c-42ab241e7c6e
# ╠═a73e589d-aa61-4cad-b1d5-bcbece9b7b1f
# ╠═4f06c9f6-eeb1-4d5e-a44c-0e3f67b848fe
# ╠═98d1d4b2-1a09-443d-a178-4c57af8f4eac
# ╠═55a3275d-5c6d-4c56-984b-c4215a23cbd2
# ╠═5037a0b0-4788-11ec-3681-339f2de45d6a
# ╠═665e4da8-56b6-480a-b07d-89454f0561c0
# ╠═015fa311-68c8-4474-ae48-fcceb6c3648e
