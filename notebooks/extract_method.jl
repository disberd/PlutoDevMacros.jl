### A Pluto.jl notebook ###
# v0.17.1

using Markdown
using InteractiveUtils

# ╔═╡ e3b54b66-d8cd-430f-af1a-5258b8cdc4ba
using Base: SimpleVector, show_can_elide, isgensym, unwrap_unionall

# ╔═╡ c6955676-657f-4413-81cc-e0e2fc8dc6d8
function stripmodules(s::Symbol)
	split(string(s),'.')[end]  |> Symbol
end

# ╔═╡ 2ae5b44c-678a-42da-934f-7ff057704381
md"""
# \_toexpr
"""

# ╔═╡ 69c2a190-0a1b-4b87-a143-ab9b890a065b
md"""
The function `_toexpr` is used to process the components of a method signature to reconstruct an expression that could be used to bring the method into scope from the parent module (loaded with `@plutoinclude`) to the current module 
"""

# ╔═╡ 4fcb74bc-f9ed-4969-b9cb-44c0991a2788
# This function is basicaly copied and adapted from https://github.com/JuliaLang/julia/blob/743a37898d447d047002efcc19ce59825ef63cc1/base/show.jl#L604-L648
function _toexpr(v::Val, env::SimpleVector, orig::SimpleVector, wheres::Vector; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	ex = Expr(:curly)
	n = length(env)
    elide = length(wheres)
    function egal_var(p::TypeVar, @nospecialize o)
        return o isa TypeVar &&
            ccall(:jl_types_egal, Cint, (Any, Any), p.ub, o.ub) != 0 &&
            ccall(:jl_types_egal, Cint, (Any, Any), p.lb, o.lb) != 0
    end
	println("n = $n")
    for i = n:-1:1
        p = env[i]
		println("p = $p")
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
                    push!(ex.args, Expr(:(<:), _toexpr(v, p.ub;to, from, importedlist, fromname)))
                elseif p.ub === Any && something(findfirst(@nospecialize(w) -> w === p, wheres), 0) > elide
                    push!(ex.args, Expr(:(>:), _toexpr(v, p.lb; to, from, importedlist, fromname)))
                else
                    push!(ex.args, _toexpr(v, p; to, from, importedlist, fromname))
                end
            else
               push!(ex.args, _toexpr(v, p; to, from, importedlist, fromname))
            end
        end
    end
    resize!(wheres, elide)
    ex
end

# ╔═╡ bc123a56-31b7-4599-8acb-19cdd2934f30
# function _toexpr(v::Val, x::Type; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
# 	alias = Base.make_typealias(x)
# 	if alias === nothing
# 		# This is not an alias
# 	else
# 		wheres = Base.make_wheres()
# 	end
# end

# ╔═╡ 6d20a40c-7407-4bbe-ba97-b05a541efb46
# function _toexpr(v::Val, x::DataType, wheres::Vector = TypeVar[]; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
# 	parameters = x.parameters::SimpleVector
#     name = x.name.wrapper |> Symbol |> stripmodules
# 	# println("name = $name, stripped = $(stripmodules(name))")
# 	val = (isdefined(to,name) || name ∈ importedlist) ? name : :($fromname.$name)
# 	if isempty(parameters)
# 		return val
# 	end
# 	orig = if v isa Val{:wheres}
# 		unwrap_unionall(x.name.wrapper).parameters
# 	elseif v isa Val{:types}
# 		parameters
# 	else
# 		error("Unsupported Val direction")
# 	end
# 	ex = _toexpr(v, parameters, orig, wheres; to, from, importedlist, fromname)
# 	if isempty(ex.args)
# 		return val
# 	else
# 		pushfirst!(ex.args, val)
# 	end
# 	return ex
# end

# ╔═╡ 3b18e1ce-9b6a-4c81-b78c-d1618a2fd4cb
# function _toexpr(v::Val, x::UnionAll; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
# 	wheres = TypeVar[]
# 	while x isa UnionAll
# 		push!(wheres,x.var)
# 		x = x.body
# 	end
# 	ex = _toexpr(v, x, wheres; to, from, importedlist, fromname)
# end

# ╔═╡ 94b3e64c-fd50-410e-9619-9122e6ef35cd
function _toexpr(v::Val, x; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	return x
end

# ╔═╡ 72481e47-60cc-4e86-8cbd-9bbb7576c995
function _toexpr(v::Val{:types},x::TypeVar; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	# If this has a name, return the name
	isgensym(x.name) || return x.name
end

# ╔═╡ 99336a92-3510-467d-a2cb-5cd4d3758406
function _toexpr(v::Val{:wheres},x::TypeVar; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	if isgensym(x.name)
		if x.lb === Union{}
			ex = Expr(:(<:), _toexpr(v,x.ub; to, from, importedlist, fromname))
		elseif x.ub === Any
			ex = Expr(:(:>), _toexpr(v,x.lb; to, from, importedlist, fromname))
		else
			ex = ()
		end
	else
		if x.lb === Union{} && x.ub === Any
			ex = x.name
		elseif x.lb === Union{}
			ex = Expr(:(<:), x.name, _toexpr(v,x.ub; to, from, importedlist, fromname))
		elseif x.ub === Any
			ex = Expr(:(:>), x.name, _toexpr(v,x.lb; to, from, importedlist, fromname))
		else
			ex = Expr(:comparison,_toexpr(v,x.lb; to, from, importedlist, fromname),:(<:),x.name,:(<:),_toexpr(v,x.ub; to, from, importedlist, fromname))
		end
	end
	return ex
end

# ╔═╡ 782a1a5d-b04f-43d5-94ac-71e4b91b0222
function _toexpr(v::Val,u::Union; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	ex = Expr(:curly)
	push!(ex.args,:Union)
	push!(ex.args, _toexpr(v,u.a; to, from, importedlist, fromname))
	push!(ex.args, _toexpr(v,u.b; to, from, importedlist, fromname))
	ex
end

# ╔═╡ b59e74e6-f2d9-4548-872d-e53b33031f01
_toexpr(Val(:types), StaticVector{2}; to = @__MODULE__, from = @__MODULE__, importedlist = Symbol[], fromname = :asd)

# ╔═╡ 6c270dd6-4f9d-49cb-8b09-ff30d1dc4bd6
md"""
# Other Helper Funcs
"""

# ╔═╡ d895c070-d923-4f01-bfd8-e9129b5f290d
function _method_expr(mtd::Method; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
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
		push!(lhs.args, Expr(:(::),_toexpr(Val(:types), nm; to, from, importedlist, fromname),_toexpr(Val(:types), sig; to, from, importedlist, fromname)))
	end
	if !isempty(tv)
		lhs = Expr(:where,lhs,map(x -> _toexpr(Val(:wheres),x; to, from, importedlist, fromname),tv)...)
		# lhs = Expr(:where,lhs,tv...)
	end
	lhs
	# Add the function call
	rhs = :($fromname.$s())
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

# ╔═╡ 3381acd4-4d69-45d2-95c9-b555339161c0
function _copymethods!(ex::Expr, s::Symbol; to::Module, from::Module, importedlist::Vector{Symbol}, fromname::Symbol)
	f = getfield(from,s)
	ml = methods(f,from)
	for mtd ∈ ml
		push!(ex.args, _method_expr(mtd; to, from, importedlist, fromname))
	end
	ex
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.0-rc2"
manifest_format = "2.0"

[deps]
"""

# ╔═╡ Cell order:
# ╠═e3b54b66-d8cd-430f-af1a-5258b8cdc4ba
# ╠═c6955676-657f-4413-81cc-e0e2fc8dc6d8
# ╠═2ae5b44c-678a-42da-934f-7ff057704381
# ╠═69c2a190-0a1b-4b87-a143-ab9b890a065b
# ╠═4fcb74bc-f9ed-4969-b9cb-44c0991a2788
# ╠═b59e74e6-f2d9-4548-872d-e53b33031f01
# ╠═bc123a56-31b7-4599-8acb-19cdd2934f30
# ╠═6d20a40c-7407-4bbe-ba97-b05a541efb46
# ╠═3b18e1ce-9b6a-4c81-b78c-d1618a2fd4cb
# ╠═94b3e64c-fd50-410e-9619-9122e6ef35cd
# ╠═72481e47-60cc-4e86-8cbd-9bbb7576c995
# ╠═99336a92-3510-467d-a2cb-5cd4d3758406
# ╠═782a1a5d-b04f-43d5-94ac-71e4b91b0222
# ╠═6c270dd6-4f9d-49cb-8b09-ff30d1dc4bd6
# ╠═3381acd4-4d69-45d2-95c9-b555339161c0
# ╠═d895c070-d923-4f01-bfd8-e9129b5f290d
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
