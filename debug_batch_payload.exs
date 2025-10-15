criteria = %{
  class: "TestClass",
  where: %{
    path: ["category"],
    operator: "Equal",
    valueText: "test_cat"
  }
}

IO.puts("Payload being sent:")
IO.inspect(criteria, pretty: true)

IO.puts("\nJSON encoded:")
IO.puts(Jason.encode!(criteria, pretty: true))

# According to Weaviate docs, batch delete expects:
# {
#   "match": {
#     "class": "...",
#     "where": {...}
#   }
# }

correct_format = %{
  match: %{
    class: "TestClass",
    where: %{
      path: ["category"],
      operator: "Equal",
      valueText: "test_cat"
    }
  }
}

IO.puts("\n\nCorrect format according to docs:")
IO.puts(Jason.encode!(correct_format, pretty: true))
