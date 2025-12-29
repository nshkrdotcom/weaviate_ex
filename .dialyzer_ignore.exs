# Dialyzer ignore file for false positives
# Mix functions are compile-time/dev tools not available in the runtime PLT

[
  # Mix.Task callback info - Mix is not in runtime PLT
  {"lib/mix/tasks/weaviate.logs.ex", :callback_info_missing},
  {"lib/mix/tasks/weaviate.start.ex", :callback_info_missing},
  {"lib/mix/tasks/weaviate.status.ex", :callback_info_missing},
  {"lib/mix/tasks/weaviate.stop.ex", :callback_info_missing},

  # Mix.shell/0 and Mix.raise/1 - dev-only functions
  ~r/lib\/mix\/tasks\/.*:unknown_function.*Mix\.(shell|raise|env)/,

  # Mix.env/0 in application.ex - compile-time check
  {"lib/weaviate_ex/application.ex", :unknown_function, "Function Mix.env/0 does not exist."}
]
