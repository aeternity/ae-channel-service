ExUnit.start()

require Logger

# need to be started using: elixir --sname foo -S mix test
# :erlang.set_cookie(:erlang.node(), :aeternity_cookie)
# rpc_cover = :rpc.call(:aeternity@localhost, :cover, :compile_beam, [[:aesc_fsm]])
# Logger.error("ONCE #{inspect(rpc_cover)}")
# rpc_cover_start = :rpc.call(:aeternity@localhost, :cover, :start, [])
# Logger.error("ONCE #{inspect(rpc_cover_start)}")

# ExUnit.after_suite(fn _ignore ->
#   dir = File.cwd!
#   Logger.info "output folder is: #{inspect dir}"
#   Logger.info("coverage #{inspect(:rpc.call(:aeternity@localhost, :cover, :analyse_to_file, [[:aesc_fsm], [:html, {:outdir, dir}]]))}")
# end)

