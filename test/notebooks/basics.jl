### A Pluto.jl notebook ###
# v0.19.27

using Markdown
using InteractiveUtils

# ╔═╡ f32cb55a-cf6d-40cd-8d5a-81445a685b53
begin
	plutodevmacros_project= Base.current_project(normpath(@__DIR__, "../..")) 
	pushfirst!(LOAD_PATH, plutodevmacros_project) # This loads the PlutoDevMacros environment, so we can do import with the latest version
	try
		Base.eval(Main, :(import PlutoDevMacros))
	finally
		popfirst!(LOAD_PATH) # Remove plutodevmacros env
	end
	using Main.PlutoDevMacros
end

# ╔═╡ e3296a1c-9d38-4363-b275-42738d1ebae7
asd(x::Int) = 3

# ╔═╡ 5808997c-0da3-4d1d-8b9a-b0e8965ce4a8
@addmethod asd(x::Float64) = 4.0

# ╔═╡ 65603c9c-5b1b-4cd0-9db2-7216520d1c36
@addmethod asd(x::String) = "LOL" * string(asd(1))

# ╔═╡ 53f8ca75-67f1-47c5-9c1e-a3747b376c3a
asd(3.0) === 4.0 || error("Something went wrong")

# ╔═╡ b4351ff1-65eb-45d8-9262-6811fc0884f1
asd("ASD") === "LOL3" || error("Something went wrong")

# ╔═╡ 18c8788a-0213-43f3-8359-329a0501fc6c
@current_pluto_cell_id() |> string |> typeof

# ╔═╡ 63c5d858-7d51-48d6-b221-50343482044b
@current_pluto_cell_id() === "63c5d858-7d51-48d6-b221-50343482044b" || error("Something went wrong")

# ╔═╡ 00ed0ca3-3b5e-45a8-bf46-55e898c4b923
@current_pluto_notebook_file() === string(first(split(@__FILE__(), "#==#"))) || error("Something went wrong")

# ╔═╡ bda0d273-68f2-4954-bad1-b6c7aef9c1bd
@only_in_nb(asd) === asd

# ╔═╡ 9985d53f-bc97-41b3-ab08-435b75db58d1
let
	pd = plutodump(@macroexpand(@only_in_nb(a)))
	pd isa Text && pd.content === "Symbol a\n" || error("Something went wrong")
end

# ╔═╡ 2647436d-5170-41f8-86de-9bce9acf2f70
@only_out_nb(3) === nothing

# ╔═╡ 5ec03ab5-a3e3-4855-af59-6e589f5b104f
PlutoDevMacros.is_notebook_local() || error("Something went wrong")

# ╔═╡ Cell order:
# ╠═f32cb55a-cf6d-40cd-8d5a-81445a685b53
# ╠═e3296a1c-9d38-4363-b275-42738d1ebae7
# ╠═5808997c-0da3-4d1d-8b9a-b0e8965ce4a8
# ╠═65603c9c-5b1b-4cd0-9db2-7216520d1c36
# ╠═53f8ca75-67f1-47c5-9c1e-a3747b376c3a
# ╠═b4351ff1-65eb-45d8-9262-6811fc0884f1
# ╠═18c8788a-0213-43f3-8359-329a0501fc6c
# ╠═63c5d858-7d51-48d6-b221-50343482044b
# ╠═00ed0ca3-3b5e-45a8-bf46-55e898c4b923
# ╠═bda0d273-68f2-4954-bad1-b6c7aef9c1bd
# ╠═9985d53f-bc97-41b3-ab08-435b75db58d1
# ╠═2647436d-5170-41f8-86de-9bce9acf2f70
# ╠═5ec03ab5-a3e3-4855-af59-6e589f5b104f
